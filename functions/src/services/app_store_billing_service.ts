import {readFileSync} from "fs";
import {join} from "path";
import {
  Environment,
  JWSTransactionDecodedPayload,
  SignedDataVerifier,
} from "@apple/app-store-server-library";
import {HttpsError} from "firebase-functions/v2/https";

const bundleId = "com.cicekdoktoru.cicekDoktoru";
const appAppleId = 6787075776;

export const appStoreMonthlyProductId = "premium_monthly_109";
export const appStoreYearlyProductId = "premium_yearly_999";
export const appStoreTransactionsCollection = "app_store_transactions";

export type AppStorePremiumPlan = "premium_monthly" | "premium_yearly";

export interface VerifiedAppStoreSubscription {
  plan: AppStorePremiumPlan;
  productId: string;
  originalTransactionId: string;
  transactionId: string;
  expiryTime: string;
  environment: string;
  active: boolean;
  subscriptionState: "ACTIVE" | "EXPIRED" | "REVOKED" | "UPGRADED";
}

let rootCertificates: Buffer[] | undefined;

export async function verifyAppStoreSubscription(
  productId: string,
  signedTransaction: string,
): Promise<VerifiedAppStoreSubscription> {
  const plan = planForProduct(productId);
  const signedData = signedTransaction.trim();
  if (!signedData) {
    throw new HttpsError("invalid-argument", "Signed transaction is required.");
  }

  const payload = await verifyTransactionInKnownEnvironment(signedData);
  if (payload.bundleId !== bundleId || payload.productId !== productId) {
    throw new HttpsError("permission-denied", "App Store transaction does not match this app or product.");
  }

  const originalTransactionId = payload.originalTransactionId?.trim() ?? "";
  const transactionId = payload.transactionId?.trim() ?? "";
  const expiresDate = payload.expiresDate;
  if (!originalTransactionId || !transactionId || typeof expiresDate !== "number") {
    throw new HttpsError("failed-precondition", "App Store subscription data is incomplete.");
  }

  const subscriptionState = payload.revocationDate ?
    "REVOKED" :
    payload.isUpgraded === true ?
      "UPGRADED" :
      expiresDate > Date.now() ? "ACTIVE" : "EXPIRED";
  const active = subscriptionState === "ACTIVE";

  return {
    plan,
    productId,
    originalTransactionId,
    transactionId,
    expiryTime: new Date(expiresDate).toISOString(),
    environment: String(payload.environment ?? "Unknown"),
    active,
    subscriptionState,
  };
}

async function verifyTransactionInKnownEnvironment(
  signedTransaction: string,
): Promise<JWSTransactionDecodedPayload> {
  let productionError: unknown;
  try {
    return await verifier(Environment.PRODUCTION).verifyAndDecodeTransaction(signedTransaction);
  } catch (error) {
    productionError = error;
  }

  try {
    return await verifier(Environment.SANDBOX).verifyAndDecodeTransaction(signedTransaction);
  } catch (sandboxError) {
    console.error("App Store transaction verification failed", {
      productionError,
      sandboxError,
    });
    throw new HttpsError("permission-denied", "App Store transaction could not be verified.");
  }
}

function verifier(environment: Environment): SignedDataVerifier {
  return new SignedDataVerifier(
    loadRootCertificates(),
    true,
    environment,
    bundleId,
    environment === Environment.PRODUCTION ? appAppleId : undefined,
  );
}

function loadRootCertificates(): Buffer[] {
  if (rootCertificates) {
    return rootCertificates;
  }

  const certificateDirectory = join(__dirname, "../../certs");
  rootCertificates = [
    "AppleIncRootCertificate.cer",
    "AppleRootCA-G2.cer",
    "AppleRootCA-G3.cer",
  ].map((fileName) => readFileSync(join(certificateDirectory, fileName)));
  return rootCertificates;
}

function planForProduct(productId: string): AppStorePremiumPlan {
  if (productId === appStoreMonthlyProductId) {
    return "premium_monthly";
  }
  if (productId === appStoreYearlyProductId) {
    return "premium_yearly";
  }
  throw new HttpsError("invalid-argument", "Unknown App Store product id.");
}
