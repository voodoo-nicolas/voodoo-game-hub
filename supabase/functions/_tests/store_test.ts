// The store's Edge Functions (purchase-verify, play-rtdn) against the FakeDb and
// a fake Play API: verifying, acknowledging, token ownership, subscription
// states and expiry, renewals / cancels / refunds pushed by RTDN, and that
// statusFor() applies the same access rules as store_status() in the migration.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { FakeDb } from "./fake_db.ts";
import { type Call, HttpError } from "../_shared/http.ts";
import { type PlayApi, PlayNotFound, type ProductPurchase, signJwt, type SubscriptionPurchase } from "../_shared/play.ts";
import { gameOf, statusFor, subState } from "../_shared/store.ts";
import { makeHandler as verifyFor } from "../purchase-verify/handler.ts";
import { decode, makeHandler as rtdnFor } from "../play-rtdn/handler.ts";

const ME = "11111111-1111-4111-8111-111111111111", OTHER = "22222222-2222-4222-8222-222222222222";
const DAY = 86_400_000;

class FakePlay implements PlayApi {
  products: Record<string, ProductPurchase> = {};
  subs: Record<string, SubscriptionPurchase> = {};
  acked: string[] = [];
  async getProduct(id: string, token: string) {
    const p = this.products[id + "|" + token];
    if (!p) throw new PlayNotFound(token);
    return structuredClone(p);
  }
  async ackProduct(id: string, token: string) { this.acked.push(token); this.products[id + "|" + token].acknowledgementState = 1; }
  async getSubscription(token: string) {
    const s = this.subs[token];
    if (!s) throw new PlayNotFound(token);
    return structuredClone(s);
  }
  async ackSubscription(_id: string, token: string) { this.acked.push(token); this.subs[token].acknowledgementState = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"; }
  // Since 2026-11-19 a game is a $1/month subscription too (docs/BILLING.md).
  buyGame(game: string, token: string, uid = ME) {
    this.subscribe(token, 30, uid, "SUBSCRIPTION_STATE_ACTIVE", undefined, `game_${game}_monthly`);
  }
  subscribe(token: string, days: number, uid = ME, state = "SUBSCRIPTION_STATE_ACTIVE", linked?: string, product = "hub_monthly") {
    this.subs[token] = {
      subscriptionState: state, acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
      lineItems: [{ productId: product, expiryTime: new Date(Date.now() + days * DAY).toISOString() }],
      externalAccountIdentifiers: { obfuscatedExternalAccountId: uid }, latestOrderId: "GPA.S." + token,
      linkedPurchaseToken: linked,
    };
  }
}

function setup() {
  const db = new FakeDb(), play = new FakePlay();
  const verify = verifyFor(() => play);
  const rtdn = rtdnFor(() => play);
  const call = (uid: string, body: Record<string, any>) => verify({ db: db as any, uid, body } as Call) as Promise<any>;
  const push = (n: unknown) => rtdn({ message: { data: btoa(JSON.stringify(n)), messageId: "1" } }, db as any);
  return { db, play, call, push };
}

async function code(p: Promise<unknown>): Promise<string | null> {
  try { await p; } catch (e) { if (e instanceof HttpError) return e.code; throw e; }
  return null;
}

Deno.test("product ids and subscription states", () => {
  assertEquals(gameOf("game_chess_monthly"), "chess");
  assertEquals(gameOf("game_voodoo_iq_monthly"), "voodoo_iq");
  assertEquals(gameOf("game_chess_monthly"), "");
  assertEquals(gameOf("hub_monthly"), "");
  assertEquals(gameOf("game_Chess_monthly"), "");
  assertEquals(subState("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"), "grace");
  assertEquals(subState("SUBSCRIPTION_STATE_PAUSED"), "on_hold");
  assertEquals(subState("SUBSCRIPTION_STATE_EXPIRED"), "expired");
  assertEquals(subState(undefined), "expired");
});

Deno.test("purchase-verify: a game purchase is checked, acknowledged and recorded", async () => {
  const { db, play, call } = setup();
  play.buyGame("chess", "tok-chess-1");
  const r = await call(ME, { product_id: "game_chess_monthly", token: "tok-chess-1" });
  assertEquals(r.state, "active");
  assertEquals(play.acked, ["tok-chess-1"]);
  const g = r.status.entitlements[0];
  assertEquals([g.product_id, g.kind, g.game, g.state], ["game_chess_monthly", "game", "chess", "active"]);
  assert(Math.abs(g.expires - (Date.now() + 30 * DAY) / 1000) < 5);
  // Again (restore purchases): same row, no second acknowledgement.
  await call(ME, { product_id: "game_chess_monthly", token: "tok-chess-1" });
  assertEquals(db.tables.store_entitlements.length, 1);
  assertEquals(play.acked.length, 1);
});

Deno.test("purchase-verify: refuses bad, foreign and unfinished purchases", async () => {
  const { play, call } = setup();
  assertEquals(await code(call(ME, { product_id: "chess", token: "tok-xxxxxxxx" })), "bad_product");
  assertEquals(await code(call(ME, { product_id: "game_chess_monthly", token: "short" })), "bad_token");
  assertEquals(await code(call(ME, { product_id: "game_chess_monthly", token: "tok-unknown" })), "bad_token");
  play.buyGame("chess", "tok-theirs-1", OTHER);
  assertEquals(await code(call(ME, { product_id: "game_chess_monthly", token: "tok-theirs-1" })), "wrong_account");
  play.buyGame("snake", "tok-pending", ME);
  play.subs["tok-pending"].subscriptionState = "SUBSCRIPTION_STATE_PENDING";
  assertEquals(await code(call(ME, { product_id: "game_snake_monthly", token: "tok-pending" })), "pending");
  // A token one player claimed can't be claimed by another, even untagged.
  play.buyGame("hex", "tok-untagged", ME);
  delete play.subs["tok-untagged"].externalAccountIdentifiers;
  await call(ME, { product_id: "game_hex_monthly", token: "tok-untagged" });
  assertEquals(await code(call(OTHER, { product_id: "game_hex_monthly", token: "tok-untagged" })), "token_in_use");
  // The token must be for the product claimed.
  assertEquals(await code(call(ME, { product_id: "game_pool_monthly", token: "tok-untagged" })), "bad_product");
});

Deno.test("purchase-verify: the hub subscription carries its expiry", async () => {
  const { play, call } = setup();
  play.subscribe("tok-sub-1", 30);
  const r = await call(ME, { product_id: "hub_monthly", token: "tok-sub-1" });
  assertEquals(r.state, "active");
  assertEquals(play.acked, ["tok-sub-1"]);
  const e = r.status.entitlements[0];
  assertEquals([e.kind, e.product_id, e.state], ["hub", "hub_monthly", "active"]);
  assert(Math.abs(e.expires - (Date.now() + 30 * DAY) / 1000) < 5);
  assertEquals(await code(call(ME, { product_id: "game_chess_monthly", token: "tok-sub-1" })), "bad_product");
});

Deno.test("statusFor: same access rules as store_status()", async () => {
  const db = new FakeDb();
  const iso = (ms: number) => new Date(Date.now() + ms).toISOString();
  db.tables.store_trials = [{ user_id: ME, game: "snake", started_at: "2026-10-01T00:00:00.000Z" }, { user_id: OTHER, game: "hex", started_at: iso(0) }];
  db.tables.store_entitlements = [
    { user_id: ME, product_id: "hub_monthly", kind: "hub", state: "active", expires_at: iso(-DAY) },   // lapsed
    { user_id: ME, product_id: "hub_monthly", kind: "hub", state: "canceled", expires_at: iso(DAY) }, // canceled, still paid up
    { user_id: ME, product_id: "hub_monthly", kind: "hub", state: "grace", expires_at: iso(-DAY) },   // grace: still counts
    { user_id: ME, product_id: "hub_monthly", kind: "hub", state: "on_hold", expires_at: iso(DAY) },  // on hold: doesn't
    { user_id: ME, product_id: "game_chess_monthly", kind: "game", game: "chess", state: "revoked", expires_at: null },
    { user_id: ME, product_id: "grant_all", kind: "hub", state: "active", expires_at: null },
    { user_id: OTHER, product_id: "game_pool_monthly", kind: "game", game: "pool", state: "active", expires_at: null },
  ];
  const s: any = await statusFor(db as any, ME);
  assertEquals(s.trials, { snake: Date.parse("2026-10-01T00:00:00.000Z") / 1000 });
  assertEquals(s.entitlements.map((e: any) => e.state + ":" + e.product_id), ["canceled:hub_monthly", "grace:hub_monthly", "active:grant_all"]);
});

Deno.test("play-rtdn: renewals, lapses, refunds and players we haven't seen", async () => {
  const { db, play, call, push } = setup();
  assertEquals(decode({}), null);
  assertEquals((await push({ testNotification: { version: "1.0" } })).action, "test");

  play.subscribe("tok-sub-2", 30);
  await call(ME, { product_id: "hub_monthly", token: "tok-sub-2" });
  // Renewed: a later expiry.
  play.subs["tok-sub-2"].lineItems![0].expiryTime = new Date(Date.now() + 60 * DAY).toISOString();
  assertEquals((await push({ subscriptionNotification: { notificationType: 2, purchaseToken: "tok-sub-2" } })).action, "subscription_active");
  const row = db.tables.store_entitlements[0];
  assert(Date.parse(row.expires_at) > Date.now() + 59 * DAY);
  // Payment failed past grace: on hold, no access.
  play.subs["tok-sub-2"].subscriptionState = "SUBSCRIPTION_STATE_ON_HOLD";
  await push({ subscriptionNotification: { notificationType: 5, purchaseToken: "tok-sub-2" } });
  assertEquals(((await statusFor(db as any, ME)) as any).entitlements, []);

  // Resubscribed: a new token replaces the old one.
  play.subscribe("tok-sub-3", 30, ME, "SUBSCRIPTION_STATE_ACTIVE", "tok-sub-2");
  await push({ subscriptionNotification: { notificationType: 4, purchaseToken: "tok-sub-3" } });
  assert(play.acked.includes("tok-sub-3"), "RTDN acknowledges a purchase the app never verified");
  assertEquals(db.tables.store_entitlements.find((r) => r.purchase_token === "tok-sub-2")!.state, "expired");
  assertEquals(((await statusFor(db as any, ME)) as any).entitlements.length, 1);

  // A game bought while the app crashed before verifying, then refunded.
  play.buyGame("pool", "tok-pool-1");
  assertEquals((await push({ subscriptionNotification: { notificationType: 4, purchaseToken: "tok-pool-1" } })).action, "subscription_active");
  assertEquals((await push({ voidedPurchaseNotification: { purchaseToken: "tok-pool-1", orderId: "x" } })).action, "revoked");
  assertEquals(((await statusFor(db as any, ME)) as any).entitlements.map((e: any) => e.product_id), ["hub_monthly"]);

  // Unknown tokens and players are skipped, not retried forever.
  assertEquals((await push({ subscriptionNotification: { notificationType: 2, purchaseToken: "nope" } })).action, "unknown_token");
  play.subscribe("tok-anon", 30, "");
  delete play.subs["tok-anon"].externalAccountIdentifiers;
  assertEquals((await push({ subscriptionNotification: { notificationType: 4, purchaseToken: "tok-anon" } })).action, "unknown_player");
  assertEquals((await push({ oneTimeProductNotification: { purchaseToken: "t", sku: "coins_100" } })).action, "ignored_product");
});

Deno.test("signJwt: a well-formed RS256 token", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const pem = "-----BEGIN PRIVATE KEY-----\n" + btoa(String.fromCharCode(...der)).replace(/(.{64})/g, "$1\n") + "\n-----END PRIVATE KEY-----\n";
  const jwt = await signJwt(pem, { iss: "a@b", aud: "x" });
  const [h, b, sig] = jwt.split(".");
  const un = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
  assertEquals(JSON.parse(new TextDecoder().decode(un(h))), { alg: "RS256", typ: "JWT" });
  assertEquals(JSON.parse(new TextDecoder().decode(un(b))).iss, "a@b");
  assert(await crypto.subtle.verify("RSASSA-PKCS1-v1_5", pair.publicKey, un(sig), new TextEncoder().encode(`${h}.${b}`)));
});
