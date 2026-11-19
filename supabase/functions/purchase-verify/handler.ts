// purchase-verify: the app just bought something through Google Play (or is
// restoring old purchases); check the token with Google, acknowledge it, and
// record the entitlement for the caller.
//
// POST { product_id: "game_<id>_monthly" | "hub_monthly", token: "<Play purchase token>" }
// (all products are subscriptions since 2026-11-19; docs/BILLING.md)
// -> { state, status }   status = the caller's store_status() (unix seconds)
// Errors: bad_product, bad_token (Google doesn't know it), token_in_use (another
// player already claimed it), wrong_account (bought for another player),
// pending (payment not finished, e.g. cash at a shop), not_purchased.
// Safe to call again with the same token: it just refreshes the row.

import { type Call, HttpError, must } from "../_shared/http.ts";
import { googlePlayApi, type PlayApi, PlayNotFound } from "../_shared/play.ts";
import { HUB_PRODUCT, isProduct, saveProduct, saveSubscription, statusFor } from "../_shared/store.ts";

export function makeHandler(play: () => PlayApi) {
  return async ({ body, uid, db }: Call): Promise<unknown> => {
    const productId = String(body.product_id ?? "");
    const token = String(body.token ?? "");
    if (!isProduct(productId)) throw new HttpError(400, "bad_product");
    if (token.length < 8 || token.length > 4000) throw new HttpError(400, "bad_token");

    const rows = must(await db.from("store_entitlements").select("*").eq("purchase_token", token)) as { user_id: string }[];
    if (rows?.some((r) => r.user_id !== uid)) throw new HttpError(409, "token_in_use");

    const api = play();
    let state: string;
    try {
      if (productId === HUB_PRODUCT || productId.endsWith("_monthly")) {
        const sub = await api.getSubscription(token);
        if (!(sub.lineItems ?? []).some((li) => li.productId === productId)) throw new HttpError(400, "bad_product");
        if (sub.subscriptionState === "SUBSCRIPTION_STATE_PENDING") throw new HttpError(402, "pending");
        checkAccount(sub.externalAccountIdentifiers?.obfuscatedExternalAccountId, uid);
        state = await saveSubscription(db, api, uid, token, sub);
      } else {
        const p = await api.getProduct(productId, token);
        if (p.purchaseState === 2) throw new HttpError(402, "pending");
        if (p.purchaseState !== 0) throw new HttpError(402, "not_purchased");
        checkAccount(p.obfuscatedExternalAccountId, uid);
        state = await saveProduct(db, api, uid, productId, token, p);
      }
    } catch (e) {
      if (e instanceof PlayNotFound) throw new HttpError(400, "bad_token");
      throw e;
    }
    return { state, status: await statusFor(db, uid) };
  };
}

/** The app tags every purchase with the buyer's user id; a different one means someone else's purchase. */
function checkAccount(tagged: string | undefined, uid: string) {
  if (tagged && tagged !== uid) throw new HttpError(403, "wrong_account");
}

export default makeHandler(googlePlayApi);
