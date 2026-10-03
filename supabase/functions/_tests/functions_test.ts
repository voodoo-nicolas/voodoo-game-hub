// The Edge Function handlers, end to end, against the in-memory FakeDb: profiles,
// ranked eligibility, the adaptive answer loop, finishing, Blitz / Daily / Duel boards.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { FakeDb } from "./fake_db.ts";
import { type Call, HttpError } from "../_shared/http.ts";
import { blitzBatch, blitzBatchSize } from "../_shared/engine.ts";
import { checkAnswer, type Key } from "../_shared/gens/index.ts";
import { monthKey, utcDay } from "../_shared/rng.ts";
import profileSave from "../profile-save/handler.ts";
import sessionStart from "../session-start/handler.ts";
import itemAnswer from "../item-answer/handler.ts";
import sessionFinish from "../session-finish/handler.ts";
import blitzSubmit from "../blitz-submit/handler.ts";

const ME = "11111111-1111-4111-8111-111111111111", OTHER = "22222222-2222-4222-8222-222222222222";
const call = (h: (c: Call) => Promise<unknown>, db: FakeDb, uid: string, body: Record<string, any>) => h({ db: db as any, uid, body }) as Promise<any>;
async function code(p: Promise<unknown>): Promise<Record<string, unknown> | null> { try { await p; } catch (e) { if (e instanceof HttpError) return { code: e.code, ...e.extra }; throw e; } return null; }

const rightValue = (k: Key): unknown => k.t === "any" ? k.v[0] : k.t === "hit" ? "hit" : k.t === "tol" ? 0 : k.t === "num" ? String(k.v) : k.v;

async function newPlayer(db: FakeDb, uid = ME, birth_year = 1990) {
  return (await call(profileSave, db, uid, { nick: "Nico", birth_year, country: "AR", province: "Córdoba", lang: "es" })).profile;
}
/** The pending row, aged as if the player took `ms` to answer. */
function pending(db: FakeDb, sid: string, ms: number) {
  const row = db.tables.responses.filter((r) => r.session_id === sid && !r.answered_at).sort((a, b) => b.seq - a.seq)[0];
  row.served_at = new Date(Date.now() - ms).toISOString();
  return row;
}

Deno.test("profile-save: validates and keeps only the age band", async () => {
  const db = new FakeDb();
  assertEquals(await code(call(profileSave, db, ME, { nick: "x", birth_year: 1990 })), { code: "bad_nick" });
  const p = await newPlayer(db);
  assertEquals([p.nick, p.age_band, p.minor, p.country, p.province, p.lang], ["Nico", "35-44", false, "AR", "Córdoba", "es"]);
  assert(!("birth_year" in db.tables.profiles[0]));
  const kid = await newPlayer(db, OTHER, new Date().getUTCFullYear() - 12);
  assertEquals([kid.age_band, kid.minor], [null, true]);
});

Deno.test("ranked IQ test: answer loop, finish, section_scores, one ranked attempt per scope per day", async () => {
  const db = new FakeDb();
  assertEquals((await code(call(sessionStart, db, ME, { mode: "iq", scope: "ALL", dur: 5, ranked: true })))?.code, "no_profile");
  await newPlayer(db);
  const st = await call(sessionStart, db, ME, { mode: "iq", scope: "ALL", dur: 5, ranked: true });
  assert(st.session_id && st.first_item && !("key" in st.first_item) && st.ranked);
  assertEquals(st.first_item.d, 4);
  const sid = st.session_id;

  // wrong order and someone else's session are refused
  assertEquals((await code(call(itemAnswer, db, ME, { session_id: sid, seq: 3, value: 0, client_ms: 4000 })))?.code, "out_of_order");
  await newPlayer(db, OTHER);
  assertEquals((await code(call(itemAnswer, db, OTHER, { session_id: sid, seq: 0, value: 0, client_ms: 4000 })))?.code, "session_not_found");

  let item = st.first_item;
  const secsSeen: string[] = [];
  for (let i = 0; i < 40; i++) {
    const row = pending(db, sid, 4000);
    assertEquals(row.seq, item.seq);
    secsSeen.push(item.sec);
    const value = i % 3 === 2 ? "__wrong__" : rightValue(row.answer_key.key);
    const res = await call(itemAnswer, db, ME, { session_id: sid, seq: item.seq, value, client_ms: 4000 });
    assert(!JSON.stringify(res).includes("answer_key"));
    item = res.next_item;
  }
  assertEquals((await code(call(itemAnswer, db, ME, { session_id: sid, seq: item.seq - 1, value: 0, client_ms: 4000 })))?.code, "out_of_order");
  for (let i = 1; i < secsSeen.length; i++) assert(secsSeen[i] !== secsSeen[i - 1], "mixed scope repeated a section");

  const fin = await call(sessionFinish, db, ME, { session_id: sid, reason: "time" });
  assertEquals(fin.result.n, 40);
  assertEquals(fin.result.flagged, false);
  const rows = db.tables.section_scores.filter((r) => r.session_id === sid);
  assertEquals(rows.length, Object.keys(fin.result.secs).length);
  assertEquals(rows.reduce((t, r) => t + r.n, 0), 40);
  assert(rows.every((r) => r.user_id === ME && r.day === utcDay() && r.lang === "es"));
  // the Voodoo IQ checklist comes back with a ranked result (one session: 1 day, not verified)
  assertEquals(fin.result.viq.verified, false);
  assertEquals(fin.result.viq.checks.days, false);
  assertEquals(fin.result.viq.checks.secs.map((c: any) => c.sec), ["LOG", "SPA", "LIN"]);
  // finishing again returns the stored result and writes nothing new
  assertEquals((await call(sessionFinish, db, ME, { session_id: sid, reason: "quit" })).result.n, 40);
  assertEquals(db.tables.section_scores.length, rows.length);
  assertEquals((await code(call(itemAnswer, db, ME, { session_id: sid, seq: item.seq, value: 0, client_ms: 4000 })))?.code, "session_over");

  assertEquals(await code(call(sessionStart, db, ME, { mode: "iq", scope: "ALL", dur: 5, ranked: true })), { code: "not_eligible", why: "used_today" });
  assert((await call(sessionStart, db, ME, { mode: "iq", scope: "ALL", dur: 5, ranked: false })).session_id, "practice stays open");
  assert((await call(sessionStart, db, ME, { mode: "iq", scope: "LOG", dur: 5, ranked: true })).session_id, "another scope is its own attempt");
});

Deno.test("practice IQ writes no section_scores; minors can't rank", async () => {
  const db = new FakeDb();
  await newPlayer(db, OTHER, new Date().getUTCFullYear() - 14);
  assertEquals(await code(call(sessionStart, db, OTHER, { mode: "iq", scope: "LOG", dur: 15, ranked: true })), { code: "not_eligible", why: "age" });
  const st = await call(sessionStart, db, OTHER, { mode: "iq", scope: "LOG", dur: 15, ranked: false });
  pending(db, st.session_id, 5000);
  await call(itemAnswer, db, OTHER, { session_id: st.session_id, seq: 0, value: 1, client_ms: 5000 });
  await call(sessionFinish, db, OTHER, { session_id: st.session_id, reason: "quit" });
  assertEquals(db.tables.section_scores ?? [], []);
});

Deno.test("rapid correct answers and leaving the app are scored wrong and flag the session", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  const st = await call(sessionStart, db, ME, { mode: "iq", scope: "LOG", dur: 15, ranked: true });
  let item = st.first_item;
  for (let i = 0; i < 6; i++) {
    const row = pending(db, st.session_id, 50);
    const fast = row.answer_key.minMs > 0;
    const value = i < 3 ? "__hidden" : rightValue(row.answer_key.key);
    item = (await call(itemAnswer, db, ME, { session_id: st.session_id, seq: item.seq, value, client_ms: 50 })).next_item;
    const stored = db.tables.responses.find((r) => r.session_id === st.session_id && r.seq === row.seq)!;
    if (i < 3 || fast) assertEquals(stored.u, 0);
  }
  const s = db.tables.sessions.find((x) => x.id === st.session_id)!;
  assertEquals(s.flags.hidden, 3);
  const fin = await call(sessionFinish, db, ME, { session_id: st.session_id, reason: "quit" });
  assert(fin.result.flagged);
  assert(db.tables.section_scores.every((r) => r.flagged));
});

Deno.test("past the deadline, item-answer finishes the session", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  const st = await call(sessionStart, db, ME, { mode: "iq", scope: "SPA", dur: 5, ranked: false });
  db.tables.sessions[0].deadline = new Date(Date.now() - 1000).toISOString();
  const res = await call(itemAnswer, db, ME, { session_id: st.session_id, seq: 0, value: 0, client_ms: 3000 });
  assert(res.done && res.result.n === 0);
});

Deno.test("SELF: confidence required, prediction kept, scored by AUC", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  const st = await call(sessionStart, db, ME, { mode: "iq", scope: "SELF", dur: 15, ranked: true, pred: 0.7 });
  assertEquals((await code(call(itemAnswer, db, ME, { session_id: st.session_id, seq: 0, value: 0, client_ms: 9000 })))?.code, "bad_conf");
  let item = st.first_item;
  for (let i = 0; i < 24; i++) {
    const row = pending(db, st.session_id, 9000);
    const right = i % 2 === 0;
    const value = right ? rightValue(row.answer_key.key) : "__wrong__";
    item = (await call(itemAnswer, db, ME, { session_id: st.session_id, seq: item.seq, value, client_ms: 9000, conf: right ? 1 : 0.25 })).next_item;
  }
  const fin = await call(sessionFinish, db, ME, { session_id: st.session_id, reason: "time" });
  const self = fin.result.secs.SELF;
  assertEquals(Object.keys(fin.result.secs), ["SELF"]);
  assertEquals(self.auc, 1); // always surer when right
  assertEquals(self.pred, 0.7);
  assert(self.valid);
  assertEquals(db.tables.section_scores.map((r) => r.sec), ["SELF"]);
});

/** Answers for the first `n` items of a Blitz session, using the regenerated keys. */
function blitzAnswers(db: FakeDb, sid: string, n: number, ms = 1500, correctEvery = 1) {
  const s = db.tables.sessions.find((x) => x.id === sid)!;
  const items = blitzBatch(s.seed, s.scope, s.lang, blitzBatchSize(s.dur_s));
  return items.slice(0, n).map((it, seq) => ({ seq, value: seq % correctEvery === 0 ? rightValue(it.key) : "__wrong__", ms: Math.max(ms, it.minMs + 10) }));
}

Deno.test("ranked Blitz: batch without keys, scored on submit, personal bests", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  const st = await call(sessionStart, db, ME, { mode: "blitz", scope: "ALL", dur: 60, ranked: true });
  assertEquals(st.items.length, 200);
  assert(!JSON.stringify(st.items).includes('"key"'));
  db.tables.sessions[0].started_at = new Date(Date.now() - 70_000).toISOString();
  const answers = blitzAnswers(db, st.session_id, 30);
  for (const [i, a] of answers.entries()) assertEquals(a.seq, st.items[i].seq);
  const res = (await call(blitzSubmit, db, ME, { session_id: st.session_id, answers })).result;
  assertEquals([res.correct, res.wrong, res.flagged, res.best, res.monthBest], [30, 0, false, true, true]);
  assertEquals(db.tables.blitz_best.map((r) => r.season).sort(), ["all", monthKey()].sort());
  assertEquals(db.tables.responses.length, 30);
  assertEquals((await code(call(blitzSubmit, db, ME, { session_id: st.session_id, answers })))?.code, "session_over");

  // a worse run doesn't replace the best
  const st2 = await call(sessionStart, db, ME, { mode: "blitz", scope: "ALL", dur: 60, ranked: true });
  db.tables.sessions[1].started_at = new Date(Date.now() - 70_000).toISOString();
  const res2 = (await call(blitzSubmit, db, ME, { session_id: st2.session_id, answers: blitzAnswers(db, st2.session_id, 10) })).result;
  assert(!res2.best);
  assertEquals(db.tables.blitz_best.find((r) => r.season === "all")!.correct, 30);
});

Deno.test("Blitz plausibility: more answer time than the clock allows is flagged and kept off the board", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  const st = await call(sessionStart, db, ME, { mode: "blitz", scope: "LOG", dur: 60, ranked: true });
  db.tables.sessions[0].started_at = new Date(Date.now() - 65_000).toISOString();
  const res = (await call(blitzSubmit, db, ME, { session_id: st.session_id, answers: blitzAnswers(db, st.session_id, 40, 3000) })).result;
  assert(res.flagged && res.flags.implausible);
  assertEquals(db.tables.blitz_best ?? [], []);
  // and answers can't arrive faster than real time
  const st2 = await call(sessionStart, db, ME, { mode: "blitz", scope: "LOG", dur: 120, ranked: true });
  const res2 = (await call(blitzSubmit, db, ME, { session_id: st2.session_id, answers: blitzAnswers(db, st2.session_id, 20, 2000) })).result;
  assert(res2.flagged);
  assertEquals((await code(call(blitzSubmit, db, ME, { session_id: st.session_id, answers: [{ seq: 1, value: 1, ms: 900 }] })))?.code, "session_over");
});

Deno.test("Daily Brain: same items for everyone today, first ranked attempt only", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  await newPlayer(db, OTHER);
  const a = await call(sessionStart, db, ME, { kind: "daily", mode: "blitz", scope: "LOG", dur: 60, ranked: true, lang: "en" });
  const b = await call(sessionStart, db, OTHER, { kind: "daily", mode: "iq", ranked: true, lang: "en" });
  assertEquals([a.mode, a.scope, a.dur_s], ["blitz", "ALL", 180]);
  assertEquals(JSON.stringify(a.items), JSON.stringify(b.items));
  db.tables.sessions[0].started_at = new Date(Date.now() - 190_000).toISOString();
  const res = (await call(blitzSubmit, db, ME, { session_id: a.session_id, answers: blitzAnswers(db, a.session_id, 20) })).result;
  assertEquals(db.tables.daily, [{ user_id: ME, day: utcDay(), pts: res.pts, correct: 20 }]);
  assertEquals(await code(call(sessionStart, db, ME, { kind: "daily", mode: "blitz", ranked: true })), { code: "not_eligible", why: "daily_done" });
  assert((await call(sessionStart, db, ME, { kind: "daily", mode: "blitz", ranked: false })).session_id, "practice replay");
});

Deno.test("Duel: shared seed, never ranked, one attempt per player", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  await newPlayer(db, OTHER);
  db.tables.duels = [{ code: "ABC234", seed: 987654321, scope: "SPA", dur_s: 120, created_by: OTHER }];
  assertEquals((await code(call(sessionStart, db, ME, { kind: "duel", duel: "ZZZZZZ", mode: "blitz" })))?.code, "duel_not_found");
  const a = await call(sessionStart, db, ME, { kind: "duel", duel: "abc234", mode: "blitz", ranked: true });
  const b = await call(sessionStart, db, OTHER, { kind: "duel", duel: "ABC234", mode: "blitz" });
  assertEquals([a.ranked, a.scope, a.dur_s], [false, "SPA", 120]);
  assertEquals(JSON.stringify(a.items.map((x: any) => x.display)), JSON.stringify(b.items.map((x: any) => x.display)));
  assertEquals((await code(call(sessionStart, db, ME, { kind: "duel", duel: "ABC234", mode: "blitz" })))?.code, "duel_played");
  db.tables.sessions[0].started_at = new Date(Date.now() - 130_000).toISOString();
  await call(blitzSubmit, db, ME, { session_id: a.session_id, answers: blitzAnswers(db, a.session_id, 15, 2000, 3) });
  assertEquals(db.tables.duel_results.map((r) => [r.code, r.user_id, r.correct]), [["ABC234", ME, 5]]);
  assertEquals(db.tables.blitz_best ?? [], []);
});

Deno.test("a Blitz left without submitting is abandoned with no points", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  const st = await call(sessionStart, db, ME, { mode: "blitz", scope: "NAT", dur: 60, ranked: true });
  const fin = await call(sessionFinish, db, ME, { session_id: st.session_id, reason: "quit" });
  assertEquals([fin.result.pts, db.tables.sessions[0].status], [0, "abandoned"]);
  assertEquals((await code(call(sessionStart, db, ME, { mode: "blitz", scope: "SELF", dur: 60 })))?.code, "bad_scope");
  await assertRejects(() => call(sessionStart, db, ME, { mode: "chess", scope: "ALL", dur: 5 }), HttpError);
});

Deno.test("item-answer judges with the stored key exactly like the generator's check", async () => {
  const db = new FakeDb();
  await newPlayer(db);
  for (const scope of ["LIN", "MUS", "NAT", "KIN", "INT", "EXI"]) {
    const st = await call(sessionStart, db, ME, { mode: "iq", scope, dur: 5, ranked: false });
    const row = pending(db, st.session_id, 8000);
    const v = rightValue(row.answer_key.key);
    assert(checkAnswer(row.answer_key.key, v));
    await call(itemAnswer, db, ME, { session_id: st.session_id, seq: 0, value: v, client_ms: 8000 });
    assertEquals(db.tables.responses.find((r) => r.session_id === st.session_id && r.seq === 0)!.u, row.answer_key.maxMs < 8000 ? 0 : 1);
  }
});
