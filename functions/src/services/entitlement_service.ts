import {DocumentData, FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

const dailyFormat = new Intl.DateTimeFormat("en-CA", {timeZone: "Europe/Istanbul", year: "numeric", month: "2-digit", day: "2-digit"});
const dailyFreeLimit = 1;
const dailyRewardLimit = 5;
export const usersCollection = "cicek_users";
export const userIndexCollection = "cicek_user_index";

export interface UserEntitlements {
  plan: "free" | "premium_monthly" | "premium_yearly";
  subscriptionActive: boolean;
  dailyFreeUsed: number;
  dailyFreeResetDate: string;
  rewardCredits: number;
  rewardCreditsEarnedToday: number;
  rewardCreditsResetDate: string;
  premiumMonthlyLimit: number;
  premiumUsedThisMonth: number;
  premiumResetMonth: string;
  adsDisabled: boolean;
  maxSavedPlants: number;
  email?: string;
  displayName?: string;
  photoURL?: string;
}

export interface UserProfile {
  email?: string;
  displayName?: string;
  photoURL?: string;
}

export class EntitlementService {
  constructor(private readonly db: Firestore) {}

  async getUserEntitlements(userId: string, profile?: UserProfile): Promise<UserEntitlements> {
    const userRef = this.db.collection(usersCollection).doc(userId);
    const snapshot = await userRef.get();
    const today = currentDay();
    const month = currentMonth();
    const userData = snapshot.data() ?? {};
    const profileUpdate = profileFields(profile, snapshot.exists ? userData : undefined);

    if (!snapshot.exists) {
      const defaults = freeDefaults(today, month);
      await userRef.set({
        ...defaults,
        ...profileUpdate,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
      });
      const created = withProfile(defaults, profileUpdate);
      await this.updateAdminIndex(userId, created);
      return created;
    }

    const normalized = normalizeEntitlements(userData, today, month);
    await userRef.set(
      {
        plan: normalized.plan,
        subscriptionActive: normalized.subscriptionActive,
        dailyFreeUsed: normalized.dailyFreeUsed,
        dailyFreeResetDate: normalized.dailyFreeResetDate,
        rewardCreditsEarnedToday: normalized.rewardCreditsEarnedToday,
        rewardCreditsResetDate: normalized.rewardCreditsResetDate,
        premiumMonthlyLimit: normalized.premiumMonthlyLimit,
        premiumUsedThisMonth: normalized.premiumUsedThisMonth,
        premiumResetMonth: normalized.premiumResetMonth,
        adsDisabled: normalized.adsDisabled,
        maxSavedPlants: normalized.maxSavedPlants,
        ...profileUpdate,
        updatedAt: FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    const result = withProfile(normalized, userData, profileUpdate);
    await this.updateAdminIndex(userId, result);
    return result;
  }

  async assertCanAnalyze(userId: string, profile?: UserProfile): Promise<void> {
    const entitlements = await this.getUserEntitlements(userId, profile);
    if (hasPremiumCredit(entitlements) || hasDailyFreeCredit(entitlements) || entitlements.rewardCredits > 0) {
      return;
    }

    throw new HttpsError("resource-exhausted", "NO_CREDITS");
  }

  async consumeCredit(userId: string): Promise<void> {
    const userRef = this.db.collection(usersCollection).doc(userId);
    await this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);
      const entitlements = normalizeEntitlements(snapshot.data() ?? {}, currentDay(), currentMonth());
      const update: Record<string, unknown> = {
        dailyFreeResetDate: entitlements.dailyFreeResetDate,
        rewardCreditsResetDate: entitlements.rewardCreditsResetDate,
        premiumResetMonth: entitlements.premiumResetMonth,
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (hasPremiumCredit(entitlements)) {
        update.premiumUsedThisMonth = entitlements.premiumUsedThisMonth + 1;
      } else if (hasDailyFreeCredit(entitlements)) {
        update.dailyFreeUsed = entitlements.dailyFreeUsed + 1;
      } else if (entitlements.rewardCredits > 0) {
        update.rewardCredits = FieldValue.increment(-1);
      } else {
        throw new HttpsError("resource-exhausted", "NO_CREDITS");
      }

      if (!snapshot.exists) {
        update.createdAt = Timestamp.now();
      }
      transaction.set(userRef, update, {merge: true});
    });
  }

  async grantRewardCredit(userId: string): Promise<{success: true; rewardCredits: number}> {
    const userRef = this.db.collection(usersCollection).doc(userId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);
      const entitlements = normalizeEntitlements(snapshot.data() ?? {}, currentDay(), currentMonth());

      if (entitlements.rewardCreditsEarnedToday >= dailyRewardLimit) {
        throw new HttpsError("resource-exhausted", "REWARD_LIMIT_REACHED");
      }

      const rewardCredits = entitlements.rewardCredits + 1;
      const update: Record<string, unknown> = {
        ...freeDefaults(entitlements.dailyFreeResetDate, entitlements.premiumResetMonth),
        ...entitlements,
        rewardCredits,
        rewardCreditsEarnedToday: entitlements.rewardCreditsEarnedToday + 1,
        rewardCreditsResetDate: entitlements.rewardCreditsResetDate,
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        update.createdAt = Timestamp.now();
      }
      transaction.set(userRef, update, {merge: true});
      return {success: true, rewardCredits};
    });
  }

  async updatePremiumStatus(userId: string, plan: "free" | "premium_monthly" | "premium_yearly", subscriptionActive: boolean): Promise<UserEntitlements> {
    const today = currentDay();
    const month = currentMonth();
    const userRef = this.db.collection(usersCollection).doc(userId);
    const snapshot = await userRef.get();
    const current = normalizeEntitlements(snapshot.data() ?? {}, today, month);
    const premiumLimit = plan === "premium_yearly" ? 120 : plan === "premium_monthly" ? 100 : 0;
    const update = {
      ...current,
      plan,
      subscriptionActive,
      premiumMonthlyLimit: subscriptionActive ? premiumLimit : 0,
      adsDisabled: subscriptionActive,
      maxSavedPlants: subscriptionActive ? 9999 : 3,
      premiumResetMonth: month,
      updatedAt: FieldValue.serverTimestamp(),
    };
    const createFields = snapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()};
    await userRef.set(
      {
        ...update,
        ...createFields,
      },
      {merge: true},
    );
    return this.getUserEntitlements(userId);
  }

  async updateAdminIndex(userId: string, entitlements?: UserEntitlements, extra: Record<string, unknown> = {}): Promise<void> {
    const userSnapshot = await this.db.collection(usersCollection).doc(userId).get();
    const data = userSnapshot.data() ?? {};
    const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
    if (!email) {
      return;
    }

    const normalized = entitlements ?? normalizeEntitlements(data, currentDay(), currentMonth());
    await this.db.collection(userIndexCollection).doc(email).set(
      {
        uid: userId,
        email,
        displayName: typeof data.displayName === "string" ? data.displayName : null,
        photoURL: typeof data.photoURL === "string" ? data.photoURL : null,
        plan: normalized.plan,
        subscriptionActive: normalized.subscriptionActive,
        dailyFreeUsed: normalized.dailyFreeUsed,
        rewardCredits: normalized.rewardCredits,
        premiumMonthlyLimit: normalized.premiumMonthlyLimit,
        premiumUsedThisMonth: normalized.premiumUsedThisMonth,
        adsDisabled: normalized.adsDisabled,
        maxSavedPlants: normalized.maxSavedPlants,
        lastSeenAt: data.lastSeenAt ?? null,
        updatedAt: FieldValue.serverTimestamp(),
        ...extra,
      },
      {merge: true},
    );
  }
}

function profileFields(profile?: UserProfile, existing?: DocumentData): Record<string, unknown> {
  const update: Record<string, unknown> = {};
  if (profile?.email) {
    update.email = profile.email;
  }
  if (profile?.displayName && !hasText(existing?.displayName)) {
    update.displayName = profile.displayName;
  }
  if (profile?.photoURL && !hasText(existing?.photoURL)) {
    update.photoURL = profile.photoURL;
  }
  return update;
}

function withProfile(entitlements: UserEntitlements, ...sources: Array<DocumentData | Record<string, unknown>>): UserEntitlements {
  const result: UserEntitlements = {...entitlements};
  for (const source of sources) {
    if (!source) {
      continue;
    }
    if (hasText(source.email)) {
      result.email = String(source.email);
    }
    if (hasText(source.displayName)) {
      result.displayName = String(source.displayName);
    }
    if (hasText(source.photoURL)) {
      result.photoURL = String(source.photoURL);
    }
  }
  return result;
}

function hasText(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function normalizeEntitlements(data: DocumentData, today: string, month: string): UserEntitlements {
  const dailyResetDate = String(data.dailyFreeResetDate ?? today);
  const rewardResetDate = String(data.rewardCreditsResetDate ?? today);
  const premiumResetMonth = String(data.premiumResetMonth ?? month);
  const plan = normalizePlan(data.plan);
  const subscriptionActive = plan !== "free" && data.subscriptionActive === true;

  return {
    plan,
    subscriptionActive,
    dailyFreeUsed: dailyResetDate === today ? Number(data.dailyFreeUsed ?? 0) : 0,
    dailyFreeResetDate: today,
    rewardCredits: Number(data.rewardCredits ?? 0),
    rewardCreditsEarnedToday: rewardResetDate === today ? Number(data.rewardCreditsEarnedToday ?? 0) : 0,
    rewardCreditsResetDate: today,
    premiumMonthlyLimit: subscriptionActive ? Number(data.premiumMonthlyLimit ?? (plan === "premium_yearly" ? 120 : 100)) : 0,
    premiumUsedThisMonth: subscriptionActive && premiumResetMonth === month ? Number(data.premiumUsedThisMonth ?? 0) : 0,
    premiumResetMonth: month,
    adsDisabled: subscriptionActive,
    maxSavedPlants: subscriptionActive ? Number(data.maxSavedPlants ?? 9999) : 3,
  };
}

function freeDefaults(today: string, month: string): UserEntitlements {
  return {
    plan: "free",
    subscriptionActive: false,
    dailyFreeUsed: 0,
    dailyFreeResetDate: today,
    rewardCredits: 0,
    rewardCreditsEarnedToday: 0,
    rewardCreditsResetDate: today,
    premiumMonthlyLimit: 0,
    premiumUsedThisMonth: 0,
    premiumResetMonth: month,
    adsDisabled: false,
    maxSavedPlants: 3,
  };
}

function hasPremiumCredit(entitlements: UserEntitlements): boolean {
  return entitlements.subscriptionActive && entitlements.premiumUsedThisMonth < entitlements.premiumMonthlyLimit;
}

function hasDailyFreeCredit(entitlements: UserEntitlements): boolean {
  return !entitlements.subscriptionActive && entitlements.dailyFreeUsed < dailyFreeLimit;
}

function normalizePlan(value: unknown): UserEntitlements["plan"] {
  if (value === "premium_monthly" || value === "premium_yearly") {
    return value;
  }
  return "free";
}

function currentDay(): string {
  return dailyFormat.format(new Date());
}

function currentMonth(): string {
  return new Date().toISOString().slice(0, 7);
}
