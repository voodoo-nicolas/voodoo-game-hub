// Wrongly keyed items (session.ts KEY_REV; topview before 2026-10-25): their answers don't
// count when a test is scored, and tools/iq_rescore.ts rescores finished tests without them.
// deno-lint-ignore-file no-explicit-any

import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { FakeDb } from "./fake_db.ts";
import { finishIq, loadSession, scorable } from "../_shared/session.ts";
import { scoreIQ } from "../_shared/engine.ts";
import { GENS } from "../_shared/gens/index.ts";
import { bOf } from "../_shared/irt.ts";
import { Rng } from "../_shared/rng.ts";
import { rescoreAll } from "../../../tools/iq_rescore.ts";

const ME = "11111111-1111-4111-8111-111111111111";
const at = (min: number) => new Date(Date.UTC(2026, 9, 20, 12, min)).toISOString();

/** A SPA test: rotation answers right up to d 8, old topview answers all wrong (the
 *  mirror-image key) and, if `fixed`, one topview answered under the new key. */
function seed(db: FakeDb, id: string, status: "live" | "done", ranked = true, fixed = false) {
  db.tables.sessions ??= [];
  db.tables.sessions.push({ id, user_id: ME, mode: "iq", kind: "normal", scope: "SPA", dur_s: 0, ranked, seed: 1, lang: "en",
    started_at: at(0), deadline: at(59), status, flags: { hidden: 0, rapid: 0 }, result: status === "done" ? { secs: {}, viq: {} } : null, state: {} });
  db.tables.responses ??= [];
  const rows: [string, number, number, number?][] = [];
  for (let d = 2; d <= 9; d++) rows.push(["rotation", d, d <= 8 ? 1 : 0]);
  for (const d of [3, 4, 5, 6]) rows.push(["topview", d, 0]);
  if (fixed) rows.push(["topview", 7, 1, 3]);
  rows.forEach(([gid, d, u, rev], seq) => db.tables.responses.push({
    session_id: id, seq, sec: "SPA", gid, d, a: GENS[gid].a, b: bOf(d), c: 0.25, u, ms: 9000, conf: null,
    served_at: at(seq), answered_at: at(seq),
    answer_key: { key: rev ? { t: "idx", v: 0, rev } : { t: "idx", v: 0 }, k: gid === "topview" ? 5 : 4, minMs: 0, maxMs: 60000, w: 1 },
  }));
}

/** What the section should score: only the answers that count. */
function expected(db: FakeDb, id: string) {
  const rs = db.tables.responses.filter((r) => r.session_id === id && scorable(r.gid, r.answer_key))
    .map((r) => ({ sec: r.sec, gid: r.gid, d: r.d, a: GENS[r.gid].a, b: bOf(r.d), c: 1 / r.answer_key.k, u: r.u, ms: r.ms }));
  return scoreIQ(rs, { hidden: 0, rapid: 0 }, null).secs.SPA;
}

Deno.test("topview: new items carry the key revision that counts", () => {
  for (let d = 1; d <= 10; d++) {
    const it = GENS.topview.make(d, new Rng(d * 7919), { lang: "en", used: new Set(), blitz: false })!;
    if (it.gid === "topview") assert(scorable(it.gid, { key: it.key }), `d${d}`);
  }
  assert(!scorable("topview", { key: { t: "idx", v: 1 } }));
  assert(scorable("rotation", { key: { t: "idx", v: 1 } }));
});

Deno.test("finishing a test leaves out answers to old topview items", async () => {
  const db = new FakeDb();
  seed(db, "a0000000-0000-4000-8000-000000000001", "live", true, true);
  const s = await loadSession(db as any, "a0000000-0000-4000-8000-000000000001", ME);
  const res = await finishIq(db as any, s, "quit");
  const want = expected(db, s.id);
  assertEquals(res.secs.SPA.n, 9); // 8 rotation + the fixed topview
  assertAlmostEquals(res.secs.SPA.theta, want.theta, 1e-12);
  assertAlmostEquals(db.tables.section_scores[0].theta, want.theta, 1e-12);
});

Deno.test("iq_rescore: dry run writes nothing; --apply rescores ranked and practice tests in place", async () => {
  const db = new FakeDb();
  const R = "b0000000-0000-4000-8000-000000000001", P = "b0000000-0000-4000-8000-000000000002", OK = "b0000000-0000-4000-8000-000000000003";
  seed(db, R, "done", true);
  seed(db, P, "done", false);
  seed(db, OK, "live", true);
  // the ranked test's row as written before the fix (every answer counted)
  const all = db.tables.responses.filter((r) => r.session_id === R)
    .map((r) => ({ sec: r.sec, gid: r.gid, d: r.d, a: GENS[r.gid].a, b: bOf(r.d), c: 1 / r.answer_key.k, u: r.u, ms: r.ms }));
  const old = scoreIQ(all, { hidden: 0, rapid: 0 }, null).secs.SPA;
  db.tables.section_scores = [{ session_id: R, user_id: ME, sec: "SPA", day: "2026-10-20", theta: old.theta, se: old.se, n: old.n, hard: old.hard,
    lang: "en", flagged: false, auc: null, bias: null, created_at: at(30) }];
  const before = structuredClone(db.tables);

  const lines: string[] = [];
  const dry = await rescoreAll(db as any, false, (l) => lines.push(l));
  assertEquals(dry, { sessions: 2, ranked: 1, users: 1 }); // the live test is scored when it finishes
  assertEquals(db.tables, before);
  assert(lines.some((l) => l.includes("ranked") && l.includes("SPA")));

  await rescoreAll(db as any, true, () => {});
  const want = expected(db, R);
  const row = db.tables.section_scores[0];
  assertEquals([row.n, row.created_at, row.day], [8, at(30), "2026-10-20"]);
  assertAlmostEquals(row.theta, want.theta, 1e-12);
  assert(want.theta > old.theta, "leaving the wrong-keyed answers out raises the score");
  const sr = db.tables.sessions.find((s) => s.id === R)!.result;
  assertAlmostEquals(sr.secs.SPA.theta, want.theta, 1e-12);
  assert(sr.rescored && sr.viq?.checks);
  assertEquals(db.tables.sessions.find((s) => s.id === P)!.result.secs.SPA.n, 8);
  assertEquals(db.tables.sessions.find((s) => s.id === OK)!.result, null);

  // running it again changes nothing but the stamp
  const snap = structuredClone(db.tables.section_scores);
  await rescoreAll(db as any, true, () => {});
  assertEquals(db.tables.section_scores, snap);
});

Deno.test("iq_rescore: a section with only old topview answers loses its row", async () => {
  const db = new FakeDb();
  const id = "c0000000-0000-4000-8000-000000000001";
  seed(db, id, "done", true);
  db.tables.responses = db.tables.responses.filter((r) => r.gid === "topview");
  db.tables.section_scores = [{ session_id: id, user_id: ME, sec: "SPA", day: "2026-10-20", theta: -1, se: 0.8, n: 4, hard: 0, lang: "en", flagged: false, created_at: at(30) }];
  await rescoreAll(db as any, true, () => {});
  assertEquals(db.tables.section_scores, []);
  assertEquals(db.tables.sessions[0].result.secs, {});
});

Deno.test("natclass d 7+ and natodd d 8+: answers keyed by the old mod-3 pair rules don't count", () => {
  const old = { key: { t: "idx", v: 1 } };
  for (const [gid, from] of [["natclass", 7], ["natodd", 8]] as const) {
    assert(scorable(gid, old, from - 1), `${gid} below d ${from} was fine`);
    assert(!scorable(gid, old, from), `${gid} d ${from}`);
    assert(!scorable(gid, old, 10), `${gid} d 10`);
    assert(scorable(gid, { key: { t: "idx", v: 1, rev: 2 } }, 10), `${gid} new key`);
  }
  for (let d = 1; d <= 10; d++) for (const gid of ["natclass", "natodd"]) {
    const it = GENS[gid].make(d, new Rng(d * 31 + 7), { lang: "en", used: new Set(), blitz: false })!;
    assert(scorable(it.gid, { key: it.key }, it.d), `${gid} d${d} new item counts`);
  }
});

/** Intrapersonal (SELF): the Self score is how well confidence tells right from wrong, so
 *  answers to wrongly keyed items must leave it too (players: first on the board -> last). */
Deno.test("iq_rescore: a Self test drops wrongly keyed items from its confidence score", async () => {
  const db = new FakeDb();
  const id = "d0000000-0000-4000-8000-000000000001";
  db.tables.sessions = [{ id, user_id: ME, mode: "iq", kind: "normal", scope: "SELF", dur_s: 0, ranked: true, seed: 1, lang: "en",
    started_at: at(0), deadline: at(59), status: "done", flags: { hidden: 0, rapid: 0 }, result: { secs: {}, viq: {} }, state: { pred: 0.7 } }];
  // good items: confidence tracks correctness; old wrongly keyed items: confident and marked wrong
  const rows: [string, number, number, number, boolean][] = [];
  for (let i = 0; i < 8; i++) rows.push(["matrix", 5, 1, 1, false], ["matrix", 5, 0, 0.25, false]);
  for (let i = 0; i < 8; i++) rows.push(["topview", 6, 0, 1, true], ["natodd", 9, 0, 1, true]);
  db.tables.responses = rows.map(([gid, d, u, conf, old], seq) => ({
    session_id: id, seq, sec: "SELF", gid, d, a: GENS[gid].a, b: bOf(d), c: 0.2, u, ms: 9000, conf,
    served_at: at(seq), answered_at: at(seq), answer_key: { key: { t: "idx", v: 0, ...(old ? {} : {}) }, k: 5, minMs: 0, maxMs: 60000, w: 1 },
  }));
  db.tables.section_scores = [{ session_id: id, user_id: ME, sec: "SELF", day: "2026-10-20", theta: -3, se: 0.5, n: 32, hard: 0, lang: "en", flagged: false, auc: 0.3, bias: 0.3, created_at: at(30) }];
  await rescoreAll(db as any, true, () => {});
  const row = db.tables.section_scores.find((r) => r.sec === "SELF")!;
  assertEquals(row.n, 16); // only the matrix answers count
  assert(row.theta > 0, `confidence now tells right from wrong: theta ${row.theta}`);
});
