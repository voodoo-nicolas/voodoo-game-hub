// play-rtdn: Google Play Real-time Developer Notifications, pushed by a Pub/Sub
// subscription whenever a purchase changes outside the app -- a subscription
// renews, is canceled, goes into grace / on hold, expires, or anything is
// refunded. We never trust the notification's contents: it only says which
// token changed, and we re-read that token from the Play API.
//
// Pub/Sub push body: { message: { data: base64(DeveloperNotification), messageId }, subscription }
// -> { action } (always 200 for anything we understood or chose to skip; a
// thrown error is a 500 and Pub/Sub retries, which is what we want when the
// Play API is briefly down).
//
// Players we don't know yet (the app crashed before purchase-verify) are found
// through the account id the app tags every purchase with, and the purchase
// is acknowledged here so Play doesn't refund it.
// deno-lint-ignore-file no-explicit-any

import { type Db, must } from "../_shared/http.ts";
import { googlePlayApi, type PlayApi, PlayNotFound } from "../_shared/play.ts";
import { isProduct, ownerOf, saveProduct, saveSubscription } from "../_shared/store.ts";

export function decode(body: any): any {
  const data = body?.message?.data;
  if (typeof data !== "string") return null;
  try {
    const bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

export function makeHandler(play: () => PlayApi) {
  return async (body: any, db: Db): Promise<{ action: string }> => {
    const n = decode(body);
    if (!n) return { action: "ignored_bad_message" };
    if (n.testNotification) return { action: "test" };
    const api = play();
    try {
      if (n.subscriptionNotification) {
        const token = String(n.subscriptionNotification.purchaseToken ?? "");
        const sub = await api.getSubscription(token);
        const uid = await ownerOf(db, token, sub.externalAccountIdentifiers?.obfuscatedExternalAccountId);
        if (!uid) return { action: "unknown_player" };
        return { action: "subscription_" + await saveSubscription(db, api, uid, token, sub) };
      }
      if (n.oneTimeProductNotification) {
        const token = String(n.oneTimeProductNotification.purchaseToken ?? "");
        const sku = String(n.oneTimeProductNotification.sku ?? "");
        if (!isProduct(sku)) return { action: "ignored_product" };
        const p = await api.getProduct(sku, token);
        if (p.purchaseState === 2) return { action: "pending" };
        const uid = await ownerOf(db, token, p.obfuscatedExternalAccountId);
        if (!uid) return { action: "unknown_player" };
        return { action: "product_" + await saveProduct(db, api, uid, sku, token, p) };
      }
      if (n.voidedPurchaseNotification) {
        // Refunded or charged back: the purchase stops counting, whatever it was.
        const token = String(n.voidedPurchaseNotification.purchaseToken ?? "");
        must(await db.from("store_entitlements").update({ state: "revoked", updated_at: new Date().toISOString() })
          .eq("purchase_token", token));
        return { action: "revoked" };
      }
    } catch (e) {
      if (e instanceof PlayNotFound) return { action: "unknown_token" };
      throw e;
    }
    return { action: "ignored" };
  };
}

export default makeHandler(googlePlayApi);
