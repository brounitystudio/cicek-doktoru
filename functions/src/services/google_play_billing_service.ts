import {GoogleAuth} from "google-auth-library";
import {HttpsError} from "firebase-functions/v2/https";

const androidPublisherScope = "https://www.googleapis.com/auth/androidpublisher";
const packageName = process.env.ANDROID_PACKAGE_NAME || "com.brounitystudio.cicek_doktoru";

export const premiumMonthlyProductId = "premium_monthly_6999";
export const premiumYearlyProductId = "premium_yearly_59999";

export type PremiumPlan = "premium_monthly" | "premium_yearly";

interface SubscriptionPurchaseV2 {
  latestOrderId?: string;
  subscriptionState?: string;
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string;
    autoRenewingPlan?: {
      autoRenewEnabled?: boolean;
    };
  }>;
}

export interface VerifiedGooglePlaySubscription {
  plan: PremiumPlan;
  productId: string;
  orderId?: string;
  expiryTime?: string;
  subscriptionState: string;
  autoRenewEnabled: boolean;
  active: boolean;
  raw: SubscriptionPurchaseV2;
}

const auth = new GoogleAuth({scopes: [androidPublisherScope]});

export async function verifyGooglePlaySubscription(
  productId: string,
  purchaseToken: string,
): Promise<VerifiedGooglePlaySubscription> {
  const plan = planForProduct(productId);
  const token = purchaseToken.trim();
  if (!token) {
    throw new HttpsError("invalid-argument", "Purchase token is required.");
  }

  const client = await auth.getClient();
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;
  const response = await client.request<SubscriptionPurchaseV2>({url, method: "GET"});
  const purchase = response.data;
  const lineItem = purchase.lineItems?.find((item) => item.productId === productId) ?? purchase.lineItems?.[0];
  const verifiedProductId = lineItem?.productId;
  if (verifiedProductId !== productId) {
    throw new HttpsError("permission-denied", "Purchase product does not match requested plan.");
  }

  const subscriptionState = purchase.subscriptionState ?? "SUBSCRIPTION_STATE_UNSPECIFIED";
  const expiryTime = lineItem?.expiryTime;
  const active = isActiveSubscription(subscriptionState, expiryTime);
  return {
    plan,
    productId,
    orderId: purchase.latestOrderId,
    expiryTime,
    subscriptionState,
    autoRenewEnabled: lineItem?.autoRenewingPlan?.autoRenewEnabled === true,
    active,
    raw: purchase,
  };
}

function planForProduct(productId: string): PremiumPlan {
  if (productId === premiumMonthlyProductId) {
    return "premium_monthly";
  }
  if (productId === premiumYearlyProductId) {
    return "premium_yearly";
  }
  throw new HttpsError("invalid-argument", "Unknown Google Play product id.");
}

function isActiveSubscription(subscriptionState: string, expiryTime?: string): boolean {
  const activeState = subscriptionState === "SUBSCRIPTION_STATE_ACTIVE" ||
    subscriptionState === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ||
    subscriptionState === "SUBSCRIPTION_STATE_CANCELED";
  if (!activeState) {
    return false;
  }
  if (!expiryTime) {
    return true;
  }

  const expiry = Date.parse(expiryTime);
  return Number.isFinite(expiry) && expiry > Date.now();
}
