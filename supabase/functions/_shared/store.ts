// Store logic shared by purchase-verify and play-rtdn: product ids, turning a
// Play purchase into a store_entitlements row, and the player's status in the
// same shape as the store_status() SQL function (times in unix seconds).
// deno-lint-ignore-file no-explicit-any

import { type Db, HttpError, must } from "./http.ts";
import type { PlayApi, ProductPurchase, SubscriptionPurchase } from "./play.ts";

// Product ids: keep in step with scripts/common/config.gd (STORE_*) and
// docs/BILLING.md. Since 2026-11-19 every product is a monthly subscription:
// the hub ($4.99) and one per game ($1). The old ids (hub_all, game_<id>
// one-time) were never live.
export const HUB_PRODUCT = "hub_monthly";
const GAME_PRODUCT = /^game_([a-z0-9_]{1,40})_monthly$/;

/** "game_chess_monthly" -> "chess"; "" for anything that isn't a per-game product. */
export function gameOf(productId: string): string {
  return GAME_PRODUCT.exec(productId)?.[1] ?? "";
}

export function isProduct(productId: string): boolean {
  return productId === HUB_PRODUCT || gameOf(productId) !== "";
}

/** Play's subscriptionState -> our state column. Only active / grace / canceled give access. */
export function subState(s: string | undefined): string {
  switch (s) {
    case "SUBSCRIPTION_STATE_ACTIVE": return "active";
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": return "grace";
    case "SUBSCRIPTION_STATE_CANCELED": return "canceled";   // keeps access until expiry
    case "SUBSCRIPTION_STATE_ON_HOLD":
    case "SUBSCRIPTION_STATE_PAUSED":
    case "SUBSCRIPTION_STATE_PENDING": return "on_hold";
    default: return "expired";                               // EXPIRED, PENDING_PURCHASE_CANCELED, unknown
  }
}

/** The latest expiry across the subscription's line items, as an ISO string (or null). */
export function subExpiry(sub: SubscriptionPurchase): string | null {
  let best = 0;
  for (const li of sub.lineItems ?? []) {
    const t = Date.parse(li.expiryTime ?? "");
    if (!Number.isNaN(t) && t > best) best = t;
  }
  return best ? new Date(best).toISOString() : null;
}

/** Who a token belongs to: the row we already have, else the account id the app tagged it with. */
export async function ownerOf(db: Db, token: string, tagged: string | undefined): Promise<string> {
  const rows = must(await db.from("store_entitlements").select("*").eq("purchase_token", token)) as any[];
  if (rows?.length) return String(rows[0].user_id);
  return tagged ?? "";
}

/** Which of our products a subscription is for ("" = none of ours). */
export function productOf(sub: SubscriptionPurchase): string {
  for (const li of sub.lineItems ?? []) if (li.productId && isProduct(li.productId)) return li.productId;
  return "";
}

export async function saveSubscription(db: Db, play: PlayApi, uid: string, token: string, sub: SubscriptionPurchase): Promise<string> {
  const state = subState(sub.subscriptionState);
  const productId = productOf(sub) || HUB_PRODUCT;
  const game = gameOf(productId);
  if (sub.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING" && (state === "active" || state === "grace")) {
    await play.ackSubscription(productId, token);
  }
  must(await db.from("store_entitlements").upsert({
    user_id: uid, product_id: productId, kind: game ? "game" : "hub", game: game || null, state, expires_at: subExpiry(sub),
    source: "play", purchase_token: token, order_id: sub.latestOrderId ?? null, updated_at: new Date().toISOString(),
  }, { onConflict: "purchase_token" }));
  // A resubscribe or plan change hands out a new token that replaces the old one.
  if (sub.linkedPurchaseToken && sub.linkedPurchaseToken !== token) {
    must(await db.from("store_entitlements").update({ state: "expired", updated_at: new Date().toISOString() })
      .eq("purchase_token", sub.linkedPurchaseToken));
  }
  return state;
}

export async function saveProduct(db: Db, play: PlayApi, uid: string, productId: string, token: string, p: ProductPurchase): Promise<string> {
  const state = p.purchaseState === 0 ? "active" : "revoked";
  if (state === "active" && p.acknowledgementState === 0) await play.ackProduct(productId, token);
  must(await db.from("store_entitlements").upsert({
    user_id: uid, product_id: productId, kind: "game", game: gameOf(productId), state, expires_at: null,
    source: "play", purchase_token: token, order_id: p.orderId ?? null, updated_at: new Date().toISOString(),
  }, { onConflict: "purchase_token" }));
  return state;
}

/** Same rules and shape as store_status() in the migration. */
export async function statusFor(db: Db, uid: string, nowMs = Date.now()): Promise<Record<string, unknown>> {
  const secs = (iso: string) => Math.floor(Date.parse(iso) / 1000);
  const trials: Record<string, number> = {};
  for (const t of must(await db.from("store_trials").select("*").eq("user_id", uid)) as any[] ?? []) {
    trials[t.game] = secs(t.started_at);
  }
  const entitlements = [];
  for (const e of must(await db.from("store_entitlements").select("*").eq("user_id", uid)) as any[] ?? []) {
    const live = e.state === "grace" ||
      ((e.state === "active" || e.state === "canceled") && (e.expires_at == null || Date.parse(e.expires_at) > nowMs));
    if (!live) continue;
    entitlements.push({
      product_id: e.product_id, kind: e.kind, game: e.game ?? null, state: e.state,
      expires: e.expires_at == null ? null : secs(e.expires_at),
    });
  }
  return { now: Math.floor(nowMs / 1000), trials, entitlements };
}

export { HttpError };
