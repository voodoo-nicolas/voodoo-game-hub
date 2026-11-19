// Google Play Developer API, as much of it as the store needs: read a one-time
// purchase or a subscription by its purchase token, and acknowledge it (Play
// refunds anything not acknowledged within 3 days).
//
// Auth is a Google Cloud service account (linked to the Play Console with
// "View financial data" + "Manage orders and subscriptions"): its JSON key is
// the function secret PLAY_SERVICE_ACCOUNT_JSON; we sign a JWT with it
// (RS256, WebCrypto) and trade that for an hour-long OAuth token.
// PLAY_PACKAGE_NAME defaults to com.viral.voodoo.
// Since 2026-11-19 the default is com.viral.gamehub (the Play package; com.viral.voodoo is the sideloaded APK).
//
// Handlers take a PlayApi, so the tests drive them with a fake one.
// deno-lint-ignore-file no-explicit-any

export interface ProductPurchase {
  purchaseState?: number;            // 0 purchased, 1 canceled, 2 pending
  acknowledgementState?: number;     // 0 pending, 1 acknowledged
  obfuscatedExternalAccountId?: string;
  orderId?: string;
}

export interface SubscriptionPurchase {
  subscriptionState?: string;        // SUBSCRIPTION_STATE_ACTIVE, ..._IN_GRACE_PERIOD, ...
  acknowledgementState?: string;     // ACKNOWLEDGEMENT_STATE_PENDING | ..._ACKNOWLEDGED
  lineItems?: { productId?: string; expiryTime?: string }[];
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  linkedPurchaseToken?: string;      // the token this one replaces (resubscribe, plan change)
  latestOrderId?: string;
}

export interface PlayApi {
  getProduct(productId: string, token: string): Promise<ProductPurchase>;
  ackProduct(productId: string, token: string): Promise<void>;
  getSubscription(token: string): Promise<SubscriptionPurchase>;
  ackSubscription(subscriptionId: string, token: string): Promise<void>;
}

/** Play said the token doesn't exist (404/410) -- a bad or foreign token, not an outage. */
export class PlayNotFound extends Error {}

const SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/";

export function googlePlayApi(): PlayApi {
  const pkg = Deno.env.get("PLAY_PACKAGE_NAME") || "com.viral.gamehub";
  const base = API + encodeURIComponent(pkg) + "/purchases/";
  const t = encodeURIComponent;
  return {
    getProduct: (id, token) => call("GET", `${base}products/${t(id)}/tokens/${t(token)}`),
    ackProduct: (id, token) => call("POST", `${base}products/${t(id)}/tokens/${t(token)}:acknowledge`, {}),
    getSubscription: (token) => call("GET", `${base}subscriptionsv2/tokens/${t(token)}`),
    ackSubscription: (id, token) => call("POST", `${base}subscriptions/${t(id)}/tokens/${t(token)}:acknowledge`, {}),
  };
}

async function call(method: string, url: string, body?: unknown): Promise<any> {
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${await accessToken()}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (res.status === 404 || res.status === 410) throw new PlayNotFound(text);
  if (!res.ok) throw new Error(`Play API ${res.status}: ${text}`);
  return text ? JSON.parse(text) : {};
}

let cached: { token: string; until: number } | null = null;

async function accessToken(): Promise<string> {
  if (cached && Date.now() < cached.until) return cached.token;
  const raw = Deno.env.get("PLAY_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("PLAY_SERVICE_ACCOUNT_JSON is not set");
  const sa = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signJwt(sa.private_key, {
    iss: sa.client_email, scope: SCOPE, aud: sa.token_uri || "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
  });
  const res = await fetch(sa.token_uri || "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(`Google OAuth ${res.status}: ${JSON.stringify(data)}`);
  cached = { token: data.access_token, until: Date.now() + (Number(data.expires_in ?? 3600) - 300) * 1000 };
  return cached.token;
}

function b64url(bytes: Uint8Array | string): string {
  const s = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function signJwt(pem: string, claims: Record<string, unknown>): Promise<string> {
  const der = Uint8Array.from(atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const enc = new TextEncoder();
  const head = b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const body = b64url(enc.encode(JSON.stringify(claims)));
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(`${head}.${body}`)));
  return `${head}.${body}.${b64url(sig)}`;
}
