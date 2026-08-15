import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {createHash, randomUUID} from "crypto";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {AnalyzePlantPhotoInput, CauseCode, PossibleCause} from "./types";
import {getCareTemplate} from "./services/diagnosis_template_service";
import {EntitlementService, userIndexCollection, usersCollection} from "./services/entitlement_service";
import {GeminiService} from "./services/gemini_service";
import {verifyGooglePlaySubscription} from "./services/google_play_billing_service";
import {
  appStoreTransactionsCollection,
  verifyAppStoreSubscription,
} from "./services/app_store_billing_service";
import {
  buildPlantActionPlan,
  looksRepeatedOrGeneric,
  personalizePlantActionPlan,
} from "./services/plant_action_plan_service";
import {
  findPlantCareEntry,
  plantCareKind,
  plantCareSummary,
  PlantCareEntry,
  wateringReminderTitle,
  wateringTaskOffsetDays,
} from "./services/plant_care_library_service";

admin.initializeApp();

const db = admin.firestore();
const entitlementService = new EntitlementService(db);
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const publicInvoker = "public";
const careTasksCollection = "care_tasks";
const ownerEmails = new Set(["brounitystudio@gmail.com"]);
const purchaseTokensCollection = "google_play_purchase_tokens";
const analysisGeminiModel =
  process.env.GEMINI_ANALYSIS_MODEL ||
  process.env.GEMINI_MODEL ||
  "gemini-2.5-flash-lite";

export const analyzePlantPhoto = onCall({region: "europe-west1", timeoutSeconds: 90, memory: "1GiB", secrets: [geminiApiKey], invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const input = normalizeInput(request.data);
    const responseLanguage = input.answers?.language === "en" ? "en" : "tr";
    const diagnosisId = input.requestId ?
      createHash("sha256").update(`${userId}:${input.requestId}`).digest("hex").slice(0, 40) :
      db.collection("_").doc().id;
    const diagnosisRef = db.collection(usersCollection).doc(userId).collection("diagnoses").doc(diagnosisId);
    const existingDiagnosis = await diagnosisRef.get();
    if (existingDiagnosis.exists) {
      return storedDiagnosisResponse(existingDiagnosis.data() ?? {});
    }
    await entitlementService.assertCanAnalyze(userId, authProfile(request.auth?.token));
    const analysisTier = analysisGeminiModel.includes("pro") ? "pro" : "standard";
    const diagnosis = await new GeminiService(
      geminiApiKey.value(),
      analysisGeminiModel,
    ).analyzePlantPhoto(input);
    const plantGuess = normalizePlantGuess(diagnosis.plantGuess);
    const plantCare = findPlantCareEntry(plantGuess);
    const possibleCauses = refinePossibleCauses(diagnosis.possibleCauses);
    const primaryCause = [...possibleCauses].sort((a, b) => b.confidence - a.confidence)[0];
    const careTemplate = getCareTemplate(primaryCause?.code ?? "unknown");
    const evidenceFindings = buildVisualFindings(
      diagnosis.visualFindings,
      diagnosis.symptoms,
      plantGuess,
      primaryCause?.code ?? "unknown",
      plantCare,
    );
    const actionContext = {
      plantName: plantGuess,
      cause: primaryCause?.code ?? "unknown",
      answers: input.answers,
      plantCare,
      visualFindings: evidenceFindings,
      possibleCauses,
    };
    const templateActionPlan = buildPlantActionPlan(actionContext);
    const selectedActionPlan = responseLanguage === "en" ? {
      visualFindings: diagnosis.visualFindings,
      symptoms: diagnosis.symptoms,
      quickActions: diagnosis.quickActions,
      sevenDayPlan: diagnosis.sevenDayPlan,
      safetyNote: diagnosis.safetyNote,
      confidenceNote: diagnosis.confidenceNote,
    } : {
      ...templateActionPlan,
      quickActions: looksRepeatedOrGeneric(
        diagnosis.quickActions,
        plantGuess,
        evidenceFindings,
      ) ? templateActionPlan.quickActions : diagnosis.quickActions,
      sevenDayPlan: diagnosis.sevenDayPlan.length === 7 &&
        !looksRepeatedOrGeneric(diagnosis.sevenDayPlan, plantGuess, evidenceFindings) ?
        diagnosis.sevenDayPlan : templateActionPlan.sevenDayPlan,
      confidenceNote: diagnosis.confidenceNote ?? templateActionPlan.confidenceNote,
    };
    const actionPlan = responseLanguage === "tr" ?
      personalizePlantActionPlan(selectedActionPlan, actionContext) :
      selectedActionPlan;

    const storedImage = await uploadDiagnosisImage(userId, diagnosisRef.id, input);
    const response = {
      id: diagnosisRef.id,
      plantId: null,
      imageUrl: storedImage.imageUrl ?? input.imageUrl ?? null,
      storagePath: storedImage.storagePath ?? null,
      plantGuess,
      healthScore: diagnosis.healthScore,
      severity: diagnosis.severity,
      visualFindings: actionPlan.visualFindings,
      symptoms: actionPlan.symptoms,
      possibleCauses,
      quickActions: actionPlan.quickActions,
      sevenDayPlan: actionPlan.sevenDayPlan,
      answers: normalizeAnswers(input.answers),
      template: careTemplate,
      careProfile: plantCare ? plantCareSummary(plantCare) : null,
      needsCloseup: diagnosis.needsCloseup,
      isPlant: diagnosis.isPlant,
      safetyNote: actionPlan.safetyNote || diagnosis.safetyNote || careTemplate.warning,
      confidenceNote: actionPlan.confidenceNote ?? diagnosis.confidenceNote ?? null,
      source: "gemini",
      analysisTier,
      requestId: input.requestId ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const created = await entitlementService.consumeCreditAndCreateDiagnosis(
      userId,
      diagnosisRef,
      response,
    );
    if (!created) {
      const storedDiagnosis = await diagnosisRef.get();
      return storedDiagnosisResponse(storedDiagnosis.data() ?? {});
    }
    await db.collection(usersCollection).doc(userId).set(
      {
        diagnosisCount: FieldValue.increment(1),
        lastDiagnosisAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    await entitlementService.updateAdminIndex(userId, undefined, {
      diagnosisCount: FieldValue.increment(1),
      lastDiagnosisAt: FieldValue.serverTimestamp(),
    });

    return {
      ...response,
      createdAt: new Date().toISOString(),
    };
  } catch (error) {
    console.error("analyzePlantPhoto failed", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    if (isGeminiBillingError(error)) {
      throw new HttpsError(
        "failed-precondition",
        "Gemini API kredisi veya faturalandırması aktif değil. AI Studio billing ayarlarını kontrol edin.",
      );
    }
    throw new HttpsError("internal", "Şu anda analiz tamamlanamadı, lütfen tekrar deneyin.");
  }
});

export const getUserEntitlements = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  return entitlementService.getUserEntitlements(userId, authProfile(request.auth?.token));
});

export const getUserPlants = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  await entitlementService.getUserEntitlements(userId, authProfile(request.auth?.token));
  const snapshot = await db
    .collection(usersCollection)
    .doc(userId)
    .collection("plants")
    .orderBy("updatedAt", "desc")
    .limit(100)
    .get();

  return {
    plants: snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    })),
  };
});

export const getCareTasks = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  await entitlementService.getUserEntitlements(userId, authProfile(request.auth?.token));
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  let snapshot = await db
    .collection(usersCollection)
    .doc(userId)
    .collection(careTasksCollection)
    .where("dueDate", ">=", today.toISOString())
    .orderBy("dueDate", "asc")
    .limit(100)
    .get();

  if (snapshot.empty) {
    await backfillCareTasksFromPlants(userId);
    snapshot = await db
      .collection(usersCollection)
      .doc(userId)
      .collection(careTasksCollection)
      .where("dueDate", ">=", today.toISOString())
      .orderBy("dueDate", "asc")
      .limit(100)
      .get();
  }

  return {
    tasks: snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    })),
  };
});

export const completeCareTask = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const taskId = typeof data.taskId === "string" ? data.taskId : "";
  if (!taskId) {
    throw new HttpsError("invalid-argument", "taskId is required.");
  }

  await db
    .collection(usersCollection)
    .doc(userId)
    .collection(careTasksCollection)
    .doc(taskId)
    .set(
      {
        completed: true,
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

  return {success: true};
});

export const registerDeviceToken = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const token = typeof data.token === "string" ? data.token.trim() : "";
  const platform = typeof data.platform === "string" ? data.platform : "unknown";
  if (!token) {
    throw new HttpsError("invalid-argument", "Device token is required.");
  }

  await entitlementService.getUserEntitlements(userId, authProfile(request.auth?.token));
  const tokenId = Buffer.from(token).toString("base64url").slice(0, 120);
  const userRef = db.collection(usersCollection).doc(userId);
  await userRef.collection("fcm_tokens").doc(tokenId).set(
    {
      token,
      platform,
      enabled: true,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await userRef.set(
    {
      hasPushToken: true,
      lastFcmTokenAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await entitlementService.updateAdminIndex(userId, undefined, {
    hasPushToken: true,
    lastFcmTokenAt: FieldValue.serverTimestamp(),
  });

  return {success: true};
});

export const savePlantFromDiagnosis = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const diagnosis = normalizeDiagnosis(data.diagnosis);
  const entitlements = await entitlementService.getUserEntitlements(userId, authProfile(request.auth?.token));
  const plantsRef = db.collection(usersCollection).doc(userId).collection("plants");
  const existingPlants = await plantsRef.limit(entitlements.maxSavedPlants).get();
  if (existingPlants.size >= entitlements.maxSavedPlants) {
    throw new HttpsError("resource-exhausted", "PLANT_LIMIT_REACHED");
  }

  const plantRef = plantsRef.doc();
  const diagnosisRef = plantRef.collection("diagnoses").doc(diagnosis.id ?? db.collection("_").doc().id);
  const plantCare = findPlantCareEntry(diagnosis.plantName);
  const careTasks = careTasksFor(plantRef.id, diagnosis, plantCare);
  const primaryTask = careTasks[0];
  const nowIso = new Date().toISOString();
  const diagnosisForWrite = nullifyUndefined(diagnosis);
  const careProfile = plantCare ? plantCareSummary(plantCare) : diagnosis.careProfile ?? null;
  const profile = profileFromDiagnosis(diagnosis);
  const plant = {
    name: diagnosis.plantName,
    healthStatus: healthStatus(Number(diagnosis.healthScore)),
    healthScore: diagnosis.healthScore,
    imagePath: diagnosis.imagePath ?? null,
    imageUrl: diagnosis.imageUrl ?? null,
    storagePath: diagnosis.storagePath ?? null,
    location: profile.location,
    lastWatered: profile.lastWatered,
    sunlight: profile.sunlight,
    hasDrainage: profile.hasDrainage,
    notes: null,
    lastDiagnosisAt: diagnosis.createdAt,
    nextTask: primaryTask,
    latestDiagnosis: diagnosisForWrite,
    careProfile,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(plantRef, plant);
  for (const task of careTasks) {
    batch.set(
      db.collection(usersCollection).doc(userId).collection(careTasksCollection).doc(task.id),
      {
        ...task,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    );
  }
  batch.set(diagnosisRef, {
    ...diagnosisForWrite,
    plantId: plantRef.id,
    savedAt: FieldValue.serverTimestamp(),
  });
  if (diagnosis.id) {
    batch.set(
      db.collection(usersCollection).doc(userId).collection("diagnoses").doc(diagnosis.id),
      {
        plantId: plantRef.id,
        savedToPlantsAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  batch.set(
    db.collection(usersCollection).doc(userId),
    {
      updatedAt: FieldValue.serverTimestamp(),
      lastPlantSavedAt: FieldValue.serverTimestamp(),
      plantCount: FieldValue.increment(1),
    },
    {merge: true},
  );
  try {
    await batch.commit();
    await entitlementService.updateAdminIndex(userId, entitlements, {
      plantCount: FieldValue.increment(1),
      lastPlantSavedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Save plant failed", {
      userId,
      diagnosisId: diagnosis.id ?? null,
      plantId: plantRef.id,
      message: error instanceof Error ? error.message : String(error),
    });
    throw new HttpsError("internal", "Bitki kaydedilemedi, lütfen tekrar deneyin.");
  }

  return {
    plant: {
      id: plantRef.id,
      ...plant,
      createdAt: nowIso,
      updatedAt: nowIso,
    },
  };
});

export const deleteUserPlant = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const plantId = typeof data.plantId === "string" ? data.plantId.trim() : "";
  if (!plantId) {
    throw new HttpsError("invalid-argument", "Plant id is required.");
  }

  const userRef = db.collection(usersCollection).doc(userId);
  const plantRef = userRef.collection("plants").doc(plantId);
  const plantSnapshot = await plantRef.get();
  if (!plantSnapshot.exists) {
    throw new HttpsError("not-found", "PLANT_NOT_FOUND");
  }

  const batch = db.batch();
  const diagnosisSnapshot = await plantRef.collection("diagnoses").limit(100).get();
  diagnosisSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

  const tasksSnapshot = await userRef
    .collection(careTasksCollection)
    .where("plantId", "==", plantId)
    .limit(100)
    .get();
  tasksSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

  batch.delete(plantRef);
  batch.set(
    userRef,
    {
      plantCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
      lastPlantDeletedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await batch.commit();
  await entitlementService.updateAdminIndex(userId, undefined, {
    plantCount: FieldValue.increment(-1),
    lastPlantDeletedAt: FieldValue.serverTimestamp(),
  });

  return {success: true, plantId};
});

export const updateUserPlantProfile = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const plantId = typeof data.plantId === "string" ? data.plantId.trim() : "";
  if (!plantId) {
    throw new HttpsError("invalid-argument", "Plant id is required.");
  }

  const plantRef = db.collection(usersCollection).doc(userId).collection("plants").doc(plantId);
  const plantSnapshot = await plantRef.get();
  if (!plantSnapshot.exists) {
    throw new HttpsError("not-found", "PLANT_NOT_FOUND");
  }

  const current = plantSnapshot.data() ?? {};
  const update = {
    name: readableText(data.name, readableText(current.name, "Bitkim")),
    location: readableText(data.location, readableText(current.location, "")),
    lastWatered: readableText(data.lastWatered, readableText(current.lastWatered, "")),
    sunlight: readableText(data.sunlight, readableText(current.sunlight, "")),
    notes: typeof data.notes === "string" ? data.notes.trim().slice(0, 600) : readableText(current.notes, ""),
    updatedAt: FieldValue.serverTimestamp(),
  };

  await plantRef.set(update, {merge: true});
  const updated = await plantRef.get();
  return {
    plant: {
      id: plantId,
      ...updated.data(),
      updatedAt: new Date().toISOString(),
    },
  };
});

export const grantRewardCredit = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const adNetwork = typeof data.adNetwork === "string" ? data.adNetwork : "";
  const placement = typeof data.placement === "string" ? data.placement : "";
  if (adNetwork !== "admob" || placement !== "diagnosis_credit") {
    throw new HttpsError("invalid-argument", "Invalid reward placement.");
  }

  return entitlementService.grantRewardCredit(userId);
});

export const updatePremiumStatus = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "Premium status can only be updated by a trusted backend.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const plan = data.plan === "premium_yearly" || data.plan === "premium_monthly" || data.plan === "free" ? data.plan : "free";
  const subscriptionActive = data.subscriptionActive === true;
  return entitlementService.updatePremiumStatus(userId, plan, subscriptionActive);
});

export const verifyGooglePlayPurchase = onCall({region: "europe-west1", timeoutSeconds: 30, invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const productId = typeof data.productId === "string" ? data.productId.trim() : "";
  const purchaseToken = typeof data.purchaseToken === "string" ? data.purchaseToken.trim() : "";
  if (!productId || !purchaseToken) {
    throw new HttpsError("invalid-argument", "productId and purchaseToken are required.");
  }

  const verified = await verifyGooglePlaySubscription(productId, purchaseToken);
  const tokenId = createHash("sha256").update(purchaseToken).digest("hex");
  const tokenRef = db.collection(purchaseTokensCollection).doc(tokenId);
  await db.runTransaction(async (transaction) => {
    const tokenSnapshot = await transaction.get(tokenRef);
    const ownerUserId = tokenSnapshot.data()?.userId;
    if (typeof ownerUserId === "string" && ownerUserId !== userId) {
      throw new HttpsError("permission-denied", "This purchase is already linked to another account.");
    }
    transaction.set(tokenRef, {
      userId,
      productId: verified.productId,
      plan: verified.plan,
      subscriptionActive: verified.active,
      subscriptionState: verified.subscriptionState,
      autoRenewEnabled: verified.autoRenewEnabled,
      expiryTime: verified.expiryTime ?? null,
      orderId: verified.orderId ?? null,
      updatedAt: FieldValue.serverTimestamp(),
      ...(!tokenSnapshot.exists ? {createdAt: FieldValue.serverTimestamp()} : {}),
    }, {merge: true});
  });
  const entitlements = await entitlementService.updatePremiumStatus(
    userId,
    verified.plan,
    verified.active,
    verified.expiryTime,
  );
  await entitlementService.updateAdminIndex(userId, entitlements, {
    lastGooglePlayPurchaseAt: FieldValue.serverTimestamp(),
    lastGooglePlayProductId: verified.productId,
    lastGooglePlaySubscriptionState: verified.subscriptionState,
  });

  return {
    success: true,
    entitlements,
    purchase: {
      productId: verified.productId,
      plan: verified.plan,
      subscriptionActive: verified.active,
      subscriptionState: verified.subscriptionState,
      expiryTime: verified.expiryTime ?? null,
      autoRenewEnabled: verified.autoRenewEnabled,
    },
  };
});

export const verifyAppStorePurchase = onCall({region: "europe-west1", timeoutSeconds: 30, invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const data = isRecord(request.data) ? request.data : {};
  const productId = typeof data.productId === "string" ? data.productId.trim() : "";
  const signedTransaction = typeof data.signedTransaction === "string" ? data.signedTransaction.trim() : "";
  if (!productId || !signedTransaction) {
    throw new HttpsError("invalid-argument", "productId and signedTransaction are required.");
  }

  const verified = await verifyAppStoreSubscription(productId, signedTransaction);
  const transactionDocumentId = createHash("sha256")
    .update(verified.originalTransactionId)
    .digest("hex");
  const transactionRef = db.collection(appStoreTransactionsCollection).doc(transactionDocumentId);
  await db.runTransaction(async (transaction) => {
    const transactionSnapshot = await transaction.get(transactionRef);
    const ownerUserId = transactionSnapshot.data()?.userId;
    if (typeof ownerUserId === "string" && ownerUserId !== userId) {
      throw new HttpsError("permission-denied", "This App Store purchase is already linked to another account.");
    }
    transaction.set(transactionRef, {
      userId,
      originalTransactionId: verified.originalTransactionId,
      latestTransactionId: verified.transactionId,
      productId: verified.productId,
      plan: verified.plan,
      subscriptionActive: verified.active,
      subscriptionState: verified.subscriptionState,
      expiryTime: verified.expiryTime,
      environment: verified.environment,
      updatedAt: FieldValue.serverTimestamp(),
      ...(!transactionSnapshot.exists ? {createdAt: FieldValue.serverTimestamp()} : {}),
    }, {merge: true});
  });

  const entitlements = await entitlementService.updatePremiumStatus(
    userId,
    verified.plan,
    verified.active,
    verified.expiryTime,
  );
  await entitlementService.updateAdminIndex(userId, entitlements, {
    lastAppStorePurchaseAt: FieldValue.serverTimestamp(),
    lastAppStoreProductId: verified.productId,
    lastAppStoreSubscriptionState: verified.subscriptionState,
  });

  return {
    success: true,
    entitlements,
    purchase: {
      productId: verified.productId,
      plan: verified.plan,
      subscriptionActive: verified.active,
      subscriptionState: verified.subscriptionState,
      expiryTime: verified.expiryTime,
      environment: verified.environment,
    },
  };
});

export const deleteCurrentUserAccount = onCall({region: "europe-west1", timeoutSeconds: 60, memory: "512MiB", invoker: publicInvoker}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const userRef = db.collection(usersCollection).doc(userId);
  const [userSnapshot, authUser] = await Promise.all([
    userRef.get(),
    admin.auth().getUser(userId),
  ]);
  const storedEmail = typeof userSnapshot.data()?.email === "string" ?
    String(userSnapshot.data()?.email).trim().toLowerCase() : "";
  const authEmail = authUser.email?.trim().toLowerCase() ?? "";

  await admin.storage().bucket().deleteFiles({prefix: `users/${userId}/`, force: true});
  await Promise.all([
    deleteDocumentsForUser(purchaseTokensCollection, userId),
    deleteDocumentsForUser(appStoreTransactionsCollection, userId),
  ]);
  for (const email of new Set([storedEmail, authEmail])) {
    if (email) {
      await db.collection(userIndexCollection).doc(email).delete();
    }
  }
  await db.recursiveDelete(userRef);
  await admin.auth().deleteUser(userId);
  return {success: true};
});

export const adminListUsers = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  assertAdmin(request.auth);
  const data = isRecord(request.data) ? request.data : {};
  const queryText = typeof data.query === "string" ? data.query.trim().toLowerCase() : "";
  const limit = Math.min(Math.max(Number(data.limit ?? 50), 1), 100);

  const snapshot = await db
    .collection(userIndexCollection)
    .orderBy("updatedAt", "desc")
    .limit(200)
    .get();
  const users = snapshot.docs
    .map((doc): Record<string, unknown> => ({id: doc.id, ...doc.data()}))
    .filter((user) => {
      if (!queryText) {
        return true;
      }
      const email = String(user.email ?? "").toLowerCase();
      const displayName = String(user.displayName ?? "").toLowerCase();
      const uid = String(user.uid ?? "").toLowerCase();
      return email.includes(queryText) || displayName.includes(queryText) || uid.includes(queryText);
    })
    .slice(0, limit);

  return {users};
});

export const adminSetPremiumByEmail = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  assertAdmin(request.auth);
  const data = isRecord(request.data) ? request.data : {};
  const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
  const plan = data.plan === "premium_yearly" || data.plan === "premium_monthly" || data.plan === "free" ? data.plan : "free";
  const subscriptionActive = data.subscriptionActive === true && plan !== "free";
  const premiumMonthlyLimit = optionalBoundedInt(data.premiumMonthlyLimit, 0, 999999);
  const maxSavedPlants = optionalBoundedInt(data.maxSavedPlants, 3, 999999);
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  const uid = await findUidByEmail(email);
  if (!uid) {
    throw new HttpsError("not-found", "User not found.");
  }

  await entitlementService.updatePremiumStatus(uid, plan, subscriptionActive);
  const override: Record<string, unknown> = {};
  if (subscriptionActive && premiumMonthlyLimit !== undefined) {
    override.premiumMonthlyLimit = premiumMonthlyLimit;
  }
  if (maxSavedPlants !== undefined) {
    override.maxSavedPlants = subscriptionActive ? maxSavedPlants : 3;
  }
  if (Object.keys(override).length > 0) {
    override.updatedAt = FieldValue.serverTimestamp();
    override.manualPremiumLimitUpdatedAt = FieldValue.serverTimestamp();
    override.manualPremiumLimitUpdatedBy = request.auth?.token.email ?? "admin";
    await db.collection(usersCollection).doc(uid).set(override, {merge: true});
  }
  const entitlements = await entitlementService.getUserEntitlements(uid);
  await entitlementService.updateAdminIndex(uid, entitlements, {
    manualPremiumUpdatedAt: FieldValue.serverTimestamp(),
    manualPremiumUpdatedBy: request.auth?.token.email ?? "admin",
  });
  return {success: true, uid, entitlements};
});

export const adminUpdateUserProfileByEmail = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  assertAdmin(request.auth);
  const data = isRecord(request.data) ? request.data : {};
  const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
  const displayName = typeof data.displayName === "string" ? data.displayName.trim() : "";
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }
  if (!displayName || displayName.length > 60) {
    throw new HttpsError("invalid-argument", "Display name must be 1-60 characters.");
  }

  const uid = await findUidByEmail(email);
  if (!uid) {
    throw new HttpsError("not-found", "User not found.");
  }

  await db.collection(usersCollection).doc(uid).set(
    {
      displayName,
      updatedAt: FieldValue.serverTimestamp(),
      manualProfileUpdatedAt: FieldValue.serverTimestamp(),
      manualProfileUpdatedBy: request.auth?.token.email ?? "admin",
    },
    {merge: true},
  );
  const entitlements = await entitlementService.getUserEntitlements(uid);
  await entitlementService.updateAdminIndex(uid, entitlements, {
    manualProfileUpdatedAt: FieldValue.serverTimestamp(),
    manualProfileUpdatedBy: request.auth?.token.email ?? "admin",
  });
  return {success: true, uid, entitlements};
});

export const adminSetDiagnosisCreditsByEmail = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  assertAdmin(request.auth);
  const data = isRecord(request.data) ? request.data : {};
  const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
  const credits = Math.floor(Number(data.credits ?? 0));
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }
  if (!Number.isFinite(credits) || credits < 0 || credits > 10000) {
    throw new HttpsError("invalid-argument", "Credits must be between 0 and 10000.");
  }

  const uid = await findUidByEmail(email);
  if (!uid) {
    throw new HttpsError("not-found", "User not found.");
  }

  await db.collection(usersCollection).doc(uid).set(
    {
      rewardCredits: credits,
      updatedAt: FieldValue.serverTimestamp(),
      manualCreditsUpdatedAt: FieldValue.serverTimestamp(),
      manualCreditsUpdatedBy: request.auth?.token.email ?? "admin",
    },
    {merge: true},
  );
  const entitlements = await entitlementService.getUserEntitlements(uid);
  await entitlementService.updateAdminIndex(uid, entitlements, {
    manualCreditsUpdatedAt: FieldValue.serverTimestamp(),
    manualCreditsUpdatedBy: request.auth?.token.email ?? "admin",
  });
  return {success: true, uid, entitlements};
});

export const adminSendPushToEmail = onCall({region: "europe-west1", invoker: publicInvoker}, async (request) => {
  assertAdmin(request.auth);
  const data = isRecord(request.data) ? request.data : {};
  const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
  const title = readableText(data.title, "Çiçek Doktoru");
  const body = readableText(data.body, "Bitkilerin için yeni bir hatırlatma var.");
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  const uid = await findUidByEmail(email);
  if (!uid) {
    throw new HttpsError("not-found", "User not found.");
  }

  const tokensSnapshot = await db
    .collection(usersCollection)
    .doc(uid)
    .collection("fcm_tokens")
    .where("enabled", "==", true)
    .limit(100)
    .get();
  const tokens = tokensSnapshot.docs
    .map((doc) => String(doc.data().token ?? ""))
    .filter((token) => token.length > 0);
  if (tokens.length === 0) {
    throw new HttpsError("failed-precondition", "User has no active push token.");
  }

  const result = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: {source: "admin_panel"},
  });
  return {
    success: true,
    successCount: result.successCount,
    failureCount: result.failureCount,
  };
});

function normalizeInput(data: unknown): AnalyzePlantPhotoInput {
  if (!isRecord(data)) {
    throw new HttpsError("invalid-argument", "Invalid request payload.");
  }

  const imageBase64 = typeof data.imageBase64 === "string" ? data.imageBase64 : undefined;
  const imageBase64List = Array.isArray(data.imageBase64List) ?
    data.imageBase64List.filter((item): item is string => typeof item === "string" && item.length > 0).slice(0, 3) :
    undefined;
  const imageUrl = typeof data.imageUrl === "string" ? data.imageUrl : undefined;
  const imageUrls = Array.isArray(data.imageUrls) ?
    data.imageUrls.filter((item): item is string => typeof item === "string" && item.length > 0).slice(0, 3) :
    undefined;
  const mimeType = typeof data.mimeType === "string" ? data.mimeType : "image/jpeg";
  const requestId = typeof data.requestId === "string" &&
    /^[a-zA-Z0-9-]{16,128}$/.test(data.requestId) ? data.requestId : undefined;
  const answers = isRecord(data.answers) ? data.answers : {};
  const hasImageList = (imageBase64List?.length ?? 0) > 0 || (imageUrls?.length ?? 0) > 0;

  if (!imageBase64 && !imageUrl && !hasImageList) {
    throw new HttpsError("invalid-argument", "imageBase64, imageBase64List, imageUrl or imageUrls is required.");
  }
  if (imageBase64 && imageBase64.length > 7_000_000) {
    throw new HttpsError("invalid-argument", "Image is too large.");
  }
  const totalListSize = imageBase64List?.reduce((total, item) => total + item.length, 0) ?? 0;
  if (totalListSize > 10_500_000) {
    throw new HttpsError("invalid-argument", "Images are too large.");
  }

  return {requestId, imageBase64, imageBase64List, imageUrl, imageUrls, mimeType, answers};
}

function storedDiagnosisResponse(data: Record<string, unknown>): Record<string, unknown> {
  const createdAt = data.createdAt;
  return {
    ...data,
    createdAt: createdAt instanceof admin.firestore.Timestamp ?
      createdAt.toDate().toISOString() :
      typeof createdAt === "string" ? createdAt : new Date().toISOString(),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

async function deleteDocumentsForUser(collectionName: string, userId: string): Promise<void> {
  while (true) {
    const snapshot = await db.collection(collectionName).where("userId", "==", userId).limit(400).get();
    if (snapshot.empty) {
      return;
    }
    const batch = db.batch();
    for (const document of snapshot.docs) {
      batch.delete(document.ref);
    }
    await batch.commit();
  }
}

function optionalBoundedInt(value: unknown, min: number, max: number): number | undefined {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }
  const numberValue = Math.floor(Number(value));
  if (!Number.isFinite(numberValue) || numberValue < min || numberValue > max) {
    throw new HttpsError("invalid-argument", `Value must be between ${min} and ${max}.`);
  }
  return numberValue;
}

function assertAdmin(auth: {token: Record<string, unknown>; uid: string} | undefined): void {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const email = typeof auth.token.email === "string" ? auth.token.email.toLowerCase() : "";
  if (auth.token.admin === true || ownerEmails.has(email)) {
    return;
  }

  throw new HttpsError("permission-denied", "Admin access required.");
}

async function findUidByEmail(email: string): Promise<string | null> {
  const indexSnapshot = await db.collection(userIndexCollection).doc(email).get();
  const indexedUid = indexSnapshot.exists ? indexSnapshot.data()?.uid : null;
  if (typeof indexedUid === "string" && indexedUid.length > 0) {
    return indexedUid;
  }

  const userSnapshot = await db
    .collection(usersCollection)
    .where("email", "==", email)
    .limit(1)
    .get();
  if (!userSnapshot.empty) {
    return userSnapshot.docs[0].id;
  }

  try {
    const authUser = await admin.auth().getUserByEmail(email);
    return authUser.uid;
  } catch {
    return null;
  }
}

function normalizeDiagnosis(value: unknown): {
  id?: string;
  plantName: string;
  healthScore: number;
  visualFindings: string[];
  symptoms: string[];
  possibleCauses: unknown[];
  quickActions: string[];
  sevenDayPlan: string[];
  safetyNote: string;
  confidenceNote?: string;
  source: string;
  analysisTier: string;
  careProfile?: unknown;
  imagePath?: string;
  imageUrl?: string;
  storagePath?: string;
  createdAt: string;
  isPlant: boolean;
  needsCloseup: boolean;
  answers: Record<string, string>;
} {
  if (!isRecord(value)) {
    throw new HttpsError("invalid-argument", "Diagnosis payload is required.");
  }

  return {
    id: typeof value.id === "string" ? value.id : undefined,
    plantName: readableText(value.plantName, "Bitkim"),
    healthScore: clampScore(value.healthScore),
    visualFindings: stringArray(value.visualFindings),
    symptoms: stringArray(value.symptoms),
    possibleCauses: Array.isArray(value.possibleCauses) ? value.possibleCauses : [],
    quickActions: stringArray(value.quickActions),
    sevenDayPlan: stringArray(value.sevenDayPlan),
    safetyNote: readableText(value.safetyNote, "Bitki bakımında güvenli ve doğal yöntemleri tercih edin."),
    confidenceNote: typeof value.confidenceNote === "string" ? value.confidenceNote : undefined,
    source: readableText(value.source, "gemini"),
    analysisTier: readableText(value.analysisTier, "standard"),
    careProfile: isRecord(value.careProfile) ? value.careProfile : undefined,
    imagePath: typeof value.imagePath === "string" ? value.imagePath : undefined,
    imageUrl: typeof value.imageUrl === "string" ? value.imageUrl : undefined,
    storagePath: typeof value.storagePath === "string" ? value.storagePath : undefined,
    createdAt: readableText(value.createdAt, new Date().toISOString()),
    isPlant: value.isPlant !== false,
    needsCloseup: value.needsCloseup === true,
    answers: normalizeAnswers(value.answers),
  };
}

function normalizeAnswers(value: unknown): Record<string, string> {
  if (!isRecord(value)) {
    return {};
  }
  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => key.length > 0)
      .map(([key, item]) => [key, typeof item === "string" ? item.trim() : String(item ?? "")]),
  );
}

function profileFromDiagnosis(diagnosis: {answers: Record<string, string>}): {
  location: string;
  lastWatered: string;
  sunlight: string;
  hasDrainage: string;
} {
  const answers = diagnosis.answers;
  return {
    location: displayAnswer(answers.location, {indoor: "İç mekân", outdoor: "Dış mekân"}),
    lastWatered: readableText(answers.lastWatered, ""),
    sunlight: readableText(answers.sunlight, ""),
    hasDrainage: readableText(answers.hasDrainage, ""),
  };
}

function displayAnswer(value: unknown, labels: Record<string, string>): string {
  const text = readableText(value, "");
  return labels[text] ?? text;
}

async function uploadDiagnosisImage(
  userId: string,
  diagnosisId: string,
  input: AnalyzePlantPhotoInput,
): Promise<{imageUrl?: string; storagePath?: string}> {
  const imageBase64 = input.imageBase64 ?? input.imageBase64List?.[0];
  if (!imageBase64) {
    return {};
  }

  const bucketName = admin.app().options.storageBucket || `${process.env.GCLOUD_PROJECT}.firebasestorage.app`;
  const bucket = admin.storage().bucket(bucketName);
  const extension = extensionFromMime(input.mimeType ?? "image/jpeg");
  const storagePath = `${usersCollection}/${userId}/diagnoses/${diagnosisId}/original.${extension}`;
  const token = randomUUID();
  const file = bucket.file(storagePath);

  try {
    await file.save(Buffer.from(imageBase64, "base64"), {
      contentType: input.mimeType ?? "image/jpeg",
      resumable: false,
      metadata: {
        cacheControl: "public, max-age=31536000",
        metadata: {
          firebaseStorageDownloadTokens: token,
        },
      },
    });
  } catch (error) {
    console.warn("Diagnosis image upload skipped", {
      userId,
      diagnosisId,
      bucketName: bucket.name,
      storagePath,
      message: error instanceof Error ? error.message : String(error),
    });
    return {};
  }

  return {
    storagePath,
    imageUrl: `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`,
  };
}

function extensionFromMime(mimeType: string): "jpg" | "png" | "webp" {
  if (mimeType.includes("png")) {
    return "png";
  }
  if (mimeType.includes("webp")) {
    return "webp";
  }
  return "jpg";
}

function readableText(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

function nullifyUndefined<T>(value: T): T {
  if (value === undefined) {
    return null as T;
  }
  if (Array.isArray(value)) {
    return value.map((item) => nullifyUndefined(item)) as T;
  }
  if (isRecord(value)) {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [key, nullifyUndefined(child)]),
    ) as T;
  }
  return value;
}

function normalizePlantGuess(value: string): string {
  const plantGuess = readableText(value, "Belirsiz");
  const normalized = plantGuess.toLocaleLowerCase("tr");

  if (
    normalized.includes("sansevieria") ||
    normalized.includes("dracaena trifasciata") ||
    normalized.includes("snake plant")
  ) {
    return "Paşa kılıcı (Sansevieria)";
  }

  return plantGuess;
}

function refinePossibleCauses(causes: PossibleCause[]): PossibleCause[] {
  const cleaned = causes
    .filter((cause) => cause.label.trim().length > 0)
    .map((cause) => ({
      ...cause,
      confidence: Math.max(0, Math.min(1, Number(cause.confidence) || 0)),
    }))
    .sort((a, b) => b.confidence - a.confidence);

  const healthy = cleaned.find((cause) => cause.code === "healthy");
  if (healthy && healthy.confidence >= 0.75) {
    const meaningfulRisks = cleaned.filter((cause) => cause.code !== "healthy" && cause.confidence >= 0.55);
    if (meaningfulRisks.length === 0) {
      return [healthy];
    }
    return meaningfulRisks.slice(0, 3);
  }

  return cleaned.filter((cause) => !(cause.code === "healthy" && cleaned.length > 1)).slice(0, 3);
}

function buildVisualFindings(
  aiFindings: string[],
  symptoms: string[],
  plantName: string,
  cause: CauseCode,
  plantCare?: PlantCareEntry,
): string[] {
  const plant = plantTraits(plantName, plantCare);
  const organ = visualOrganTerms(plant, plantCare);
  const cleaned = uniqueStrings([...aiFindings, ...symptoms])
    .filter((item) => !looksTooGenericFinding(item))
    .slice(0, 5);

  if (cleaned.length >= 2) {
    return cleaned;
  }

  const generated = [
    `${plant.shortName} olarak görünen bitkide ${organ.primary} formu analiz edildi; öneriler bu türe göre özelleştirildi.`,
    `${organ.checkArea} bölgesi fotoğraftan değerlendirildi; net seçilemeyen kök/drenaj bilgisi kesin bulgu olarak kabul edilmedi.`,
  ];

  if (cause === "healthy") {
    generated.push(`${plant.shortName} için belirgin hastalık izi seçilmiyor; bakım planı koruma ve takip odaklı hazırlandı.`);
  } else if (cause === "overwatering" || cause === "pot_drainage_issue" || cause === "root_stress") {
    generated.push(`${plant.shortName} için fazla nem/kök stresi riski ayrı değerlendirildi; sulama önerileri bu riske göre kısıtlandı.`);
  } else if (cause === "underwatering") {
    generated.push(`${plant.shortName} için kuruluk stresi riski değerlendirildi; sulama önerisi tek seferde aşırı su vermeyecek şekilde yazıldı.`);
  } else {
    generated.push(`${plant.shortName} için tür, ışık ve sulama hassasiyeti ayrı ayrı hesaba katıldı.`);
  }

  return uniqueStrings([...cleaned, ...generated]).slice(0, 5);
}

function looksTooGenericFinding(value: string): boolean {
  const text = value.toLocaleLowerCase("tr");
  return text.length < 12 ||
    text === "sağlıklı" ||
    text === "belirsiz" ||
    text.includes("genel değerlendirme") ||
    text.includes("genel görünüm") ||
    text.includes("kontrol edin") ||
    text.includes("gözlemleyin") ||
    text.includes("fotoğraf yeterli");
}

function visualOrganTerms(
  plant: {shortName: string; kind: "dry" | "moist" | "default"},
  plantCare?: PlantCareEntry,
): {primary: string; checkArea: string} {
  const category = plantCare?.category.toLocaleLowerCase("tr") ?? "";
  const name = `${plant.shortName} ${plantCare?.latinName ?? ""}`.toLocaleLowerCase("tr");
  if (category.includes("cactus") || name.includes("kaktüs") || name.includes("cactaceae") || name.includes("opuntia")) {
    return {primary: "gövde, diken ve dip bölgesi", checkArea: "gövde yüzeyi ve toprakla birleşen dip"};
  }
  if (plant.kind === "dry" || category.includes("succulent") || name.includes("sukulent") || name.includes("aloe")) {
    return {primary: "etli yaprak/gövde ve dip bölgesi", checkArea: "yaprak dipleri ve toprak yüzeyi"};
  }
  if (category.includes("flower") || name.includes("orkide") || name.includes("çiçeği")) {
    return {primary: "yaprak, çiçek/tomurcuk ve sap formu", checkArea: "yaprak uçları, çiçek sapı ve toprak yüzeyi"};
  }
  return {primary: "yaprak rengi, yaprak ucu ve gövde formu", checkArea: "yaprak altı, yaprak ucu ve toprak yüzeyi"};
}

function uniqueStrings(items: string[]): string[] {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = item.toLocaleLowerCase("tr");
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

function plantTraits(plantName: string, plantCare?: PlantCareEntry): {shortName: string; kind: "dry" | "moist" | "default"} {
  if (plantCare) {
    return {
      shortName: plantCare.commonNames[0] ?? plantName,
      kind: plantCareKind(plantCare),
    };
  }

  const normalized = plantName.toLocaleLowerCase("tr");
  if (
    normalized.includes("paşa") ||
    normalized.includes("sansevieria") ||
    normalized.includes("kılıç") ||
    normalized.includes("kaktüs") ||
    normalized.includes("sukulent") ||
    normalized.includes("aloe")
  ) {
    return {shortName: plantName, kind: "dry"};
  }
  if (
    normalized.includes("barış") ||
    normalized.includes("spathiphyllum") ||
    normalized.includes("calathea") ||
    normalized.includes("orkide") ||
    normalized.includes("eğrelti")
  ) {
    return {shortName: plantName, kind: "moist"};
  }
  return {shortName: plantName || "Bitkin", kind: "default"};
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function clampScore(value: unknown): number {
  const score = Number(value ?? 60);
  if (!Number.isFinite(score)) {
    return 60;
  }
  return Math.max(0, Math.min(100, Math.round(score)));
}

function healthStatus(score: number): string {
  if (score >= 80) {
    return "İyi";
  }
  if (score >= 50) {
    return "Orta";
  }
  return "Riskli";
}

function careTasksFor(
  plantId: string,
  diagnosis: {plantName: string; quickActions: string[]; sevenDayPlan: string[]; healthScore: number; answers?: Record<string, string>},
  plantCare?: PlantCareEntry,
): Array<{id: string; plantId: string; plantName: string; title: string; type: string; dueDate: string; completed: boolean}> {
  const today = new Date();
  const waterCheckDate = new Date(today);
  waterCheckDate.setDate(today.getDate() + wateringTaskOffsetDays(plantCare, today));
  const daySeven = new Date(today);
  daySeven.setDate(today.getDate() + 7);
  const traits = plantTraits(diagnosis.plantName, plantCare);
  const firstAction = cleanTaskTitle(diagnosis.quickActions[0] ?? diagnosis.sevenDayPlan[0] ?? "İlk bakım adımını uygula");
  const firstTitle = traits.kind === "dry" ?
    `${diagnosis.plantName}: sulama öncesi tam kuruluk kontrolü` :
    `${diagnosis.plantName}: ${firstAction}`;
  const secondTitle = wateringReminderTitle(plantCare, diagnosis.plantName);
  const secondType = plantCare ? "watering" : traits.kind === "moist" ? "watering" : "diseaseCheck";

  return [
    {
      id: randomUUID(),
      plantId,
      plantName: diagnosis.plantName,
      title: firstTitle,
      type: taskTypeFor(diagnosis),
      dueDate: atReminderHour(today).toISOString(),
      completed: false,
    },
    {
      id: randomUUID(),
      plantId,
      plantName: diagnosis.plantName,
      title: secondTitle,
      type: secondType,
      dueDate: atReminderHour(waterCheckDate).toISOString(),
      completed: false,
    },
    {
      id: randomUUID(),
      plantId,
      plantName: diagnosis.plantName,
      title: `${diagnosis.plantName}: gelişimi tekrar değerlendir`,
      type: "diseaseCheck",
      dueDate: atReminderHour(daySeven).toISOString(),
      completed: false,
    },
  ];
}

function cleanTaskTitle(value: string): string {
  const clean = value
    .replace(/^\s*\d+\.\s*Gün:\s*/i, "")
    .replace(/^[^:]{2,48}:\s*/, "")
    .split(";")[0]
    .trim()
    .replace(/[.!?:;,]+$/g, "");
  if (clean.length <= 120) {
    return clean;
  }
  const shortened = clean.slice(0, 117).replace(/\s+\S*$/, "").trim();
  return `${shortened}…`;
}

function taskTypeFor(diagnosis: {quickActions: string[]; healthScore: number}): string {
  const joined = diagnosis.quickActions.join(" ").toLocaleLowerCase("tr");
  if (joined.includes("sula") || joined.includes("nem")) {
    return "watering";
  }
  if (joined.includes("yaprak") || joined.includes("temiz")) {
    return "leafCleaning";
  }
  if (joined.includes("saks") || joined.includes("drenaj") || joined.includes("toprak")) {
    return "potCheck";
  }
  return diagnosis.healthScore >= 80 ? "leafCleaning" : "diseaseCheck";
}

function atReminderHour(date: Date): Date {
  const result = new Date(date);
  result.setHours(10, 0, 0, 0);
  return result;
}

async function backfillCareTasksFromPlants(userId: string): Promise<void> {
  const plantsSnapshot = await db
    .collection(usersCollection)
    .doc(userId)
    .collection("plants")
    .limit(100)
    .get();
  if (plantsSnapshot.empty) {
    return;
  }

  const batch = db.batch();
  for (const plantDoc of plantsSnapshot.docs) {
    const data = plantDoc.data();
    const plantName = readableText(data.name, "Bitkim");
    const nextTask = isRecord(data.nextTask) ? data.nextTask : {};
    const plantCare = findPlantCareEntry(plantName);
    const fallbackDueDate = new Date();
    fallbackDueDate.setDate(fallbackDueDate.getDate() + wateringTaskOffsetDays(plantCare, fallbackDueDate));
    const dueDate = readableText(nextTask.dueDate, atReminderHour(fallbackDueDate).toISOString());
    const task = {
      id: randomUUID(),
      plantId: plantDoc.id,
      plantName,
      title: readableText(nextTask.title, wateringReminderTitle(plantCare, plantName)),
      type: readableText(nextTask.type, plantCare ? "watering" : "diseaseCheck"),
      dueDate,
      completed: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      backfilled: true,
    };
    batch.set(
      db.collection(usersCollection).doc(userId).collection(careTasksCollection).doc(task.id),
      task,
    );
  }
  await batch.commit();
}

function authProfile(token: unknown): {email?: string; displayName?: string; photoURL?: string} {
  if (!isRecord(token)) {
    return {};
  }

  return {
    email: typeof token.email === "string" ? token.email : undefined,
    displayName: typeof token.name === "string" ? token.name : undefined,
    photoURL: typeof token.picture === "string" ? token.picture : undefined,
  };
}

function isGeminiBillingError(error: unknown): boolean {
  if (!isRecord(error)) {
    return false;
  }

  const status = Number(error.status ?? 0);
  const message = String(error.message ?? "");
  return status === 429 && (
    message.includes("prepayment credits are depleted") ||
    message.includes("billing") ||
    message.includes("Too Many Requests")
  );
}
