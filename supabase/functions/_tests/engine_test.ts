// Engine rules the Edge Functions rely on: resuming an adaptive session from stored
// state, the rapid rule, Blitz points and its input checks.
// deno-lint-ignore-file no-explicit-any

import { assert, assertAlmostEquals, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { blitzBatch, type IqState, judge, newIqState, nextIqItem, publicItem, RECALL, type Resp, restyle, scoreBlitz, scoreIQ, SELF_POOL } from "../_shared/engine.ts";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";
import { hashStr, Rng } from "../_shared/rng.ts";

const answerOf = (it: Item): unknown => {
  const k = it.key as any;
  return k.t === "any" ? k.v[0] : k.t === "hit" ? "hit" : k.t === "tol" ? 0 : k.t === "num" ? String(k.v) : k.v;
};
const wrongOf = (it: Item): unknown => {
  const k = it.key as any;
  return k.t === "idx" ? (k.v + 1) % Math.max(2, it.k) : k.t === "num" ? String(k.v + 1) : k.t === "tol" ? 10_000 : "nope";
};

Deno.test("an IQ session resumed from JSON-stored state serves the same items as one continuous run", () => {
  for (const scope of ["ALL", "LIN", "EXI", "SELF"]) {
    const seed = hashStr("resume-" + scope);
    const live = newIqState(seed, { selfStart: 0.3 });
    let stored = JSON.stringify(newIqState(seed, { selfStart: 0.3 }));
    const resp: Resp[] = [];
    const player = new Rng(seed);
    for (let i = 0; i < 40; i++) {
      const a = nextIqItem(scope, "es", resp, live);
      const st = JSON.parse(stored) as IqState; // what item-answer reads back from sessions.state
      const b = nextIqItem(scope, "es", resp, st);
      stored = JSON.stringify(st);
      assertEquals(JSON.stringify(publicItem(b, i)), JSON.stringify(publicItem(a, i)));
      const u = player.chance(0.55) ? 1 : 0;
      resp.push({ sec: a.sec, gid: a.gid, d: a.d, a: a.a, b: a.b, c: a.c, u, ms: 3000, conf: 0.75 });
    }
    assertEquals(stored, JSON.stringify(live));
  }
});

Deno.test("the public item never carries the answer key", () => {
  const items = blitzBatch(1, "ALL", "en", 50);
  const st = newIqState(2);
  items.push(nextIqItem("ALL", "en", [], st));
  for (const it of items) {
    const pub = publicItem(it, 0) as any;
    assert(!("key" in pub) && !("meta" in pub) && !("minMs" in pub));
    assert(!JSON.stringify(pub).includes('"key"'));
  }
});

Deno.test("rapid rule: a correct answer faster than minMs (client or server clock) scores wrong", () => {
  const it = nextIqItem("LOG", "en", [], newIqState(5)); // matrix/series/digits
  const right = answerOf(it);
  if (it.minMs) {
    assertEquals(judge(it, right, it.minMs - 1).u, 0);
    assert(judge(it, right, it.minMs - 1).rapid);
    assertEquals(judge(it, right, it.minMs + 500, it.minMs - 1).u, 0); // client claims slow, server saw fast
    assertEquals(judge(it, right, it.minMs + 500, it.minMs + 500).u, 1);
  }
  assertEquals(judge(it, wrongOf(it), 0).rapid, false); // fast and wrong is just wrong
  assertEquals(judge(it, null, 1000).timeout, true);
  assertEquals(judge(it, right, it.maxMs + 5000).u, 0); // past the item timer
  const h = judge(it, "__hidden", 5000);
  assert(h.hidden && h.u === 0);
});

Deno.test("Blitz points: weight for right, weight/(k-1) off for wrong multiple choice, skips cost 2 s", () => {
  const items = blitzBatch(hashStr("pts"), "ALL", "en", 200);
  const r = new Rng(9);
  let pts = 0, correct = 0, wrong = 0, skipped = 0, total = 0;
  const answers = items.slice(0, 120).map((it, seq) => {
    const roll = r.n();
    const ms = Math.max(it.minMs, 900) + 50;
    if (roll < 0.1) { skipped++; total += ms + 2000; return { seq, skip: true, ms }; }
    total += ms;
    if (roll < 0.15) { skipped++; return { seq, value: null, ms }; }
    const ok = roll < 0.7;
    const value = ok ? answerOf(it) : wrongOf(it);
    if (checkAnswer(it.key, value)) { correct++; pts += it.w; }
    else { wrong++; if (it.k >= 2) pts -= it.w / (it.k - 1); }
    return { seq, value, ms };
  });
  const { result, rows, totalMs } = scoreBlitz(items, answers);
  assertEquals([result.correct, result.wrong, result.skipped], [correct, wrong, skipped]);
  assertAlmostEquals(result.pts, Math.round(pts * 10) / 10, 1e-9);
  assertEquals(totalMs, total);
  assertEquals(rows.length, 120 - answers.filter((a: any) => a.skip).length);
  assertEquals(result.flagged, false);
});

Deno.test("random tapping on Blitz averages about zero points", () => {
  let sum = 0, n = 0;
  for (let s = 0; s < 40; s++) {
    const items = blitzBatch(hashStr("tap" + s), "ALL", "en", 200).filter((it) => it.k >= 2);
    const r = new Rng(s);
    const { result } = scoreBlitz(items, items.map((it, seq) => ({ seq, value: r.int(0, it.k - 1), ms: 5000 })));
    sum += result.pts; n += items.length;
  }
  assert(Math.abs(sum / n) < 0.05, `mean points per random tap ${sum / n}`);
});

Deno.test("Blitz rejects out-of-order answers and flags many rapid ones", () => {
  const items = blitzBatch(3, "LOG", "en", 200);
  assertThrows(() => scoreBlitz(items, [{ seq: 1, value: 1, ms: 900 }]));
  const fast = items.slice(0, 5).map((it, seq) => ({ seq, value: answerOf(it), ms: 10 }));
  const { result } = scoreBlitz(items, fast);
  assertEquals(result.correct, 0);
  assertEquals(result.flags.rapid, 5);
  assert(result.flagged);
});

Deno.test("Blitz batches are deterministic per seed, scope and language", () => {
  const a = blitzBatch(42, "ALL", "es", 200).map((it, i) => publicItem(it, i));
  const b = blitzBatch(42, "ALL", "es", 200).map((it, i) => publicItem(it, i));
  assertEquals(JSON.stringify(a), JSON.stringify(b));
  const secs = new Set(a.slice(0, 8).map((x) => x.sec));
  assertEquals(secs.size, 8); // the section bag deals all 8 before repeating
});

Deno.test("generator version: packs that send no gv never get an added generator; gv 1 gets the LOG set", () => {
  const added = new Set(["symsum", "scales", "ordering", "letters", "funcmachine", "operators", "fraccmp", "wordprob", "dice", "sudoku"]);
  const seen0 = new Set<string>(), seen1 = new Set<string>();
  for (let seed = 1; seed <= 400; seed++) {
    seen0.add(nextIqItem("LOG", "en", [], newIqState(seed)).gid);
    seen1.add(nextIqItem("LOG", "es", [], newIqState(seed, { gv: 1 })).gid);
  }
  assert(![...seen0].some((g) => added.has(g)), `gv 0 got ${[...seen0]}`);
  assert([...added].every((g) => seen1.has(g)), `gv 1 missed some: ${[...seen1]}`);
});

Deno.test("generator version 2 adds the SPA set; gv 1 never gets it", () => {
  const added = new Set(["paperfold", "cubenet", "gears", "mirror", "countshapes", "cubecount", "direction", "pieces"]);
  const seen1 = new Set<string>(), seen2 = new Set<string>();
  for (let seed = 1; seed <= 400; seed++) {
    seen1.add(nextIqItem("SPA", "en", [], newIqState(seed, { gv: 1 })).gid);
    seen2.add(nextIqItem("SPA", "es", [], newIqState(seed, { gv: 2 })).gid);
  }
  assert(![...seen1].some((g) => added.has(g)), `gv 1 got ${[...seen1]}`);
  assert([...added].every((g) => seen2.has(g)), `gv 2 missed some: ${[...seen2]}`);
});

Deno.test("generator version 3 adds the LIN set; gv 2 never gets it", () => {
  const added = new Set(["remote", "synonym", "cloze", "unscramble", "proverb", "inference"]);
  const seen2 = new Set<string>(), seen3 = new Set<string>();
  for (let seed = 1; seed <= 400; seed++) {
    seen2.add(nextIqItem("LIN", "en", [], newIqState(seed, { gv: 2 })).gid);
    seen3.add(nextIqItem("LIN", "es", [], newIqState(seed, { gv: 3 })).gid);
  }
  assert(![...seen2].some((g) => added.has(g)), `gv 2 got ${[...seen2]}`);
  assert([...added].every((g) => seen3.has(g)), `gv 3 missed some: ${[...seen3]}`);
});

Deno.test("generator version 4 adds the MUS set; gv 3 never gets it", () => {
  const added = new Set(["rhythm", "transpose", "beat", "contour", "cadence", "consonance"]);
  const seen3 = new Set<string>(), seen4 = new Set<string>();
  for (let seed = 1; seed <= 400; seed++) {
    seen3.add(nextIqItem("MUS", "en", [], newIqState(seed, { gv: 3 })).gid);
    seen4.add(nextIqItem("MUS", "es", [], newIqState(seed, { gv: 4 })).gid);
  }
  assert(![...seen3].some((g) => added.has(g)), `gv 3 got ${[...seen3]}`);
  assert([...added].every((g) => seen4.has(g)), `gv 4 missed some: ${[...seen4]}`);
});

Deno.test("generator version 5 adds the NAT set; gv 4 never gets it", () => {
  const added = new Set(["inherit", "foodweb", "idkey", "camo", "spotdiff"]);
  const seen4 = new Set<string>(), seen5 = new Set<string>();
  for (let seed = 1; seed <= 400; seed++) {
    seen4.add(nextIqItem("NAT", "en", [], newIqState(seed, { gv: 4 })).gid);
    seen5.add(nextIqItem("NAT", "es", [], newIqState(seed, { gv: 5 })).gid);
  }
  assert(![...seen4].some((g) => added.has(g)), `gv 4 got ${[...seen4]}`);
  assert([...added].every((g) => seen5.has(g)), `gv 5 missed some: ${[...seen5]}`);
});

Deno.test("generator version 6 adds the KIN set; gv 5 never gets it", () => {
  const added = new Set(["gonogo", "pursuit", "trace", "tapbeat", "dragfit"]);
  const seen5 = new Set<string>(), seen6 = new Set<string>();
  for (let seed = 1; seed <= 400; seed++) {
    seen5.add(nextIqItem("KIN", "en", [], newIqState(seed, { gv: 5 })).gid);
    seen6.add(nextIqItem("KIN", "es", [], newIqState(seed, { gv: 6 })).gid);
  }
  assert(![...seen5].some((g) => added.has(g)), `gv 5 got ${[...seen5]}`);
  assert([...added].every((g) => seen6.has(g)), `gv 6 missed some: ${[...seen6]}`);
});

Deno.test("generator version 7 adds the EXI set; gv 6 never gets it", () => {
  const added = new Set(["wason", "necsuf", "assume", "contradict", "crt"]);
  const seen6 = new Set<string>(), seen7 = new Set<string>();
  for (let seed = 1; seed <= 400; seed++) {
    seen6.add(nextIqItem("EXI", "en", [], newIqState(seed, { gv: 6 })).gid);
    seen7.add(nextIqItem("EXI", "es", [], newIqState(seed, { gv: 7 })).gid);
  }
  assert(![...seen6].some((g) => added.has(g)), `gv 6 got ${[...seen6]}`);
  assert([...added].every((g) => seen7.has(g)), `gv 7 missed some: ${[...seen7]}`);
});

Deno.test("generator version 8: the Self test draws the added types and a recall trial every 7th item; gv 7 gets neither", () => {
  const allowed = new Set([...SELF_POOL, "symsum", "scales", "ordering", "letters", "funcmachine", "operators", "fraccmp", "wordprob", "dice", "sudoku",
    "paperfold", "cubenet", "gears", "mirror", "countshapes", "cubecount", "direction", "pieces",
    "remote", "synonym", "cloze", "unscramble", "proverb", "inference", "inherit", "foodweb", "idkey", "camo", "spotdiff",
    "wason", "necsuf", "assume", "contradict", "crt"]);
  const seen8 = new Set<string>();
  for (let seed = 1; seed <= 60; seed++) {
    for (const gv of [7, 8]) {
      const st = newIqState(seed, { gv, selfStart: 0 });
      const resp: Resp[] = [];
      for (let i = 0; i < 18; i++) {
        const it = nextIqItem("SELF", seed % 2 ? "en" : "es", resp, st);
        if (gv === 7) assert(SELF_POOL.includes(it.gid), `gv 7 got ${it.gid}`);
        else {
          seen8.add(it.gid);
          assertEquals(it.gid === RECALL, i % 7 === 3, `seed ${seed} item ${i}: ${it.gid}`);
          if (it.gid !== RECALL) assert(allowed.has(it.gid), `Self served ${it.gid}`);
        }
        resp.push({ sec: it.sec, gid: it.gid, d: it.d, a: it.a, b: it.b, c: it.c, u: i % 2, ms: 5000, conf: 0.5 });
      }
    }
  }
  const missed = [...allowed].filter((g) => !seen8.has(g));
  assertEquals(missed, [], `gv 8 never served ${missed}`);
});

Deno.test("SELF scoring: recall guesses count toward the Self score; without them nothing changes", () => {
  const rows = Array.from({ length: 12 }, (_, i) => ({ u: i % 2, conf: i % 2 ? 1 : 0.25 }));
  const f = { hidden: 0, rapid: 0 };
  const a = scoreIQ([], f, { rows, pred: 0.5 }).secs.SELF;
  const none = scoreIQ([], f, { rows, pred: 0.5, recall: [] }).secs.SELF;
  assertEquals([none.theta, none.se, none.recallN], [a.theta, a.se, undefined]);
  // off by 50% and 0% -> err 0.25 -> recall theta (0.2 - 0.25) / 0.1 = -0.5, se 1.5 / sqrt(2)
  const b = scoreIQ([], f, { rows, pred: 0.5, recall: [{ g: 4, s: 2, n: 4 }, { g: 3, s: 3, n: 5 }] }).secs.SELF;
  assertEquals([b.recallN, b.auc, b.valid, b.confTheta], [2, a.auc, a.valid, a.theta]);
  assertAlmostEquals(b.recallErr!, 0.25);
  assertAlmostEquals(b.recallBias!, 0.25);
  assertAlmostEquals(b.recallTheta!, -0.5);
  const w1 = 1 / a.se ** 2, w2 = 2 / 1.5 ** 2;
  assertAlmostEquals(b.theta, (a.theta * w1 - 0.5 * w2) / (w1 + w2));
  assertAlmostEquals(b.se, 1 / Math.sqrt(w1 + w2));
  assert(b.se < a.se);
  // perfect guesses pull the score up, wild ones down (confidence that tells nothing: AUC 0.5)
  const mid = Array.from({ length: 12 }, (_, i) => ({ u: i % 2, conf: i % 4 < 2 ? 0.75 : 0.5 }));
  const m = scoreIQ([], f, { rows: mid }).secs.SELF;
  const good = scoreIQ([], f, { rows: mid, recall: [{ g: 3, s: 3, n: 3 }, { g: 5, s: 5, n: 5 }, { g: 2, s: 2, n: 4 }] }).secs.SELF;
  const bad = scoreIQ([], f, { rows: mid, recall: [{ g: 3, s: 0, n: 3 }, { g: 0, s: 5, n: 5 }, { g: 4, s: 0, n: 4 }] }).secs.SELF;
  assertAlmostEquals(m.auc!, 0.5);
  assert(good.theta > m.theta && bad.theta < m.theta, `${bad.theta} < ${m.theta} < ${good.theta}`);
  assertEquals([good.recallTheta, bad.recallTheta], [2, -3]);
});

Deno.test("generator version 9 adds the INT set and new hairstyles on every face; gv 8 gets neither", () => {
  const added = new Set(["flash", "smile", "gaze", "intensity", "facemem", "eyes", "tom", "feel", "change", "sarcasm", "fauxpas", "help", "posture"]);
  const seen8 = new Set<string>(), seen9 = new Set<string>();
  const styles = (x: unknown, out: number[] = []): number[] => {
    if (Array.isArray(x)) x.forEach((y) => styles(y, out));
    else if (x && typeof x === "object") { const o = x as any; if (typeof o.style === "number" && typeof o.skin === "number") out.push(o.style); else Object.values(o).forEach((y) => styles(y, out)); }
    return out;
  };
  for (let seed = 1; seed <= 500; seed++) {
    const a = nextIqItem("INT", "en", [], newIqState(seed, { gv: 8 }));
    const b = nextIqItem("INT", "es", [], newIqState(seed, { gv: 9 }));
    seen8.add(a.gid); seen9.add(b.gid);
    assert(styles(a.display).every((s) => s <= 2), `gv 8 drew a new hairstyle (${a.gid})`);
    assert(styles(b.display).every((s) => s >= 3 && s <= 11), `gv 9 drew an old hairstyle (${b.gid})`);
  }
  assert(![...seen8].some((g) => added.has(g)), `gv 8 got ${[...seen8]}`);
  assert([...added].every((g) => seen9.has(g)), `gv 9 missed some: ${[...added].filter((g) => !seen9.has(g))}`);
  // restyling a Blitz face never changes its answer key
  const batch = blitzBatch(7, "INT", "en", 30);
  const keys = JSON.stringify(batch.map((x) => x.key));
  batch.forEach((x) => restyle(x, new Rng(3)));
  assertEquals(JSON.stringify(batch.map((x) => x.key)), keys);
  assert(batch.every((x) => styles(x.display).every((s) => s >= 3)));
});
