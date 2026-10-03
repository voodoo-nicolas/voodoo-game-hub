// Parity with the reference implementation: the TypeScript port must produce the same
// items, the same adaptive sequence and the same scores as docs/voodoo-iq-prototype.html,
// seed for seed. Each generator is compared on its metadata, on the answer the prototype's
// own check() accepts, and on RNG consumption (the next draw after make() must match,
// which only happens if every random call happened in the same order).
//   deno test --allow-read --allow-env supabase/functions/_tests/
// deno-lint-ignore-file no-explicit-any

import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { loadPrototype, probeDisplay } from "./prototype.ts";
import { hashStr, Rng } from "../_shared/rng.ts";
import * as irt from "../_shared/irt.ts";
import { GENS, type Item, type Key, type Lang } from "../_shared/gens/index.ts";
import { blitzBatch, type Flags, MIXED_POOL, newIqState, nextIqItem, type Resp, scoreIQ, SECS } from "../_shared/engine.ts";
import { SY_POOL, syText } from "../_shared/gens/exi.ts";
import { nineStanding, type ScoreRow, secStanding, viqStanding } from "../_shared/standings.ts";

const SEEDS = Number(Deno.env.get("PARITY_SEEDS") ?? 40);
const P: Record<Lang, any> = { en: await loadPrototype("en"), es: await loadPrototype("es") };

/** A value the TS key says is right, in the form the client would send it. */
function rightValue(key: Key): unknown {
  switch (key.t) {
    case "idx": return key.v;
    case "num": return String(key.v);
    case "str": return key.v;
    case "any": return key.v[0];
    case "hit": return "hit";
    case "tol": return 0;
  }
}

function sameItem(where: string, ts: Item, pi: any) {
  for (const f of ["gid", "sec", "d", "a", "b", "c", "minMs", "maxMs", "w"]) assertEquals(ts[f as keyof Item], pi[f], `${where}: ${f}`);
  assertEquals(!!ts.deferTimer, !!pi.deferTimer, `${where}: deferTimer`);
  assertEquals(ts.display, probeDisplay(pi), `${where}: display`);
  assert(pi.check(rightValue(ts.key)), `${where}: prototype rejects the port's answer ${JSON.stringify(rightValue(ts.key))}`);
  if (ts.key.t === "tol") assert(pi.check(ts.key.v) && pi.check(-ts.key.v) && !pi.check(ts.key.v + 1), `${where}: tolerance`);
  if (ts.key.t === "num") assert(!pi.check(String(ts.key.v + 1)), `${where}: typed answer`);
  if (ts.key.t === "any") for (const w of ts.key.v) assert(pi.check(w), `${where}: anagram ${w}`);
  if (ts.key.t === "idx") {
    for (let i = 0; i < ts.k; i++) if (i !== ts.key.v) assert(!pi.check(i), `${where}: prototype also accepts option ${i}`);
  }
}

Deno.test("generators match the prototype seed for seed (all 27, d = 1..10, en/es)", () => {
  for (const lang of ["en", "es"] as Lang[]) {
    for (const id of Object.keys(GENS)) {
      for (let d = 1; d <= 10; d++) {
        for (let s = 0; s < SEEDS; s++) {
          const seed = hashStr(`${id}-${d}-${s}`);
          for (const blitz of [false, true]) {
            const tr = new Rng(seed), pr = P[lang].RNG(seed);
            const ts = GENS[id].make(d, tr, { lang, used: new Set(), blitz })!;
            const pi = P[lang].GENS[id].make(d, pr, { lang, used: new Set(), blitz });
            const where = `${id} d${d} ${lang} seed ${seed}${blitz ? " blitz" : ""}`;
            sameItem(where, ts, pi);
            assertEquals(tr.n(), pr.n(), `${where}: RNG consumption differs`);
          }
        }
      }
    }
  }
});

Deno.test("syllogism pool and EN/ES sentences match the prototype exactly", () => {
  for (const lang of ["en", "es"] as Lang[]) {
    assertEquals(JSON.stringify(SY_POOL), JSON.stringify(P[lang].SY_POOL));
    const terms = P[lang].SY_TERMS[lang];
    for (const it of SY_POOL) for (const c of [it.p1, it.p2, ...it.valid, ...it.invalid]) {
      for (let i = 0; i + 2 < terms.length; i++) {
        const names = { 1: terms[i], 2: terms[i + 1], 4: terms[i + 2] };
        assertEquals(syText(lang, c, names), P[lang].syText(lang, c, names));
      }
    }
  }
});

Deno.test("IRT math matches the prototype", () => {
  const r = new Rng(12345), PI = P.en.IRT;
  assertEquals(irt.GRID, PI.GRID);
  for (let trial = 0; trial < 300; trial++) {
    const n = r.int(0, 40);
    const resp = Array.from({ length: n }, () => { const d = r.int(1, 10); return { a: 1.1 + r.n() * 0.5, b: irt.bOf(d), c: r.pick([0, 0.125, 0.2, 0.25, 1 / 3, 0.5]), u: r.chance(0.5) ? 1 : 0 }; });
    assertEquals(irt.eap(resp), PI.eap(resp));
    const th = r.n() * 6 - 3;
    assertEquals(irt.lz(resp, th), PI.lz(resp, th));
    assertEquals(irt.dOf(th), PI.dOf(th));
    const sess = Array.from({ length: r.int(1, 4) }, () => ({ theta: r.n() * 4 - 2, se: 0.2 + r.n(), n: r.int(1, 30), hard: r.int(0, 4) }));
    assertEquals(irt.combine(sess), PI.combine(sess));
    assertEquals(irt.composite(sess, 0.3), PI.composite(sess, 0.3));
    const rows = Array.from({ length: r.int(0, 30) }, () => ({ u: r.chance(0.6) ? 1 : 0, conf: r.pick([0.25, 0.5, 0.75, 1]) }));
    assertEquals(irt.auc2(rows), PI.auc2(rows));
  }
});

/** Simulated player: answers right with the 3PL probability at a fixed true theta. */
function simulateIq(lang: Lang, scope: string, seed: number, trueTheta: number, steps: number, selfStart = 0) {
  const proto = P[lang];
  const run = new proto.Runner({ mode: "iq", scope, seed, dur: 5, ranked: false, selfStart });
  const state = newIqState(seed, scope === "SELF" ? { selfStart } : {});
  const resp: Resp[] = [];
  const player = new Rng(seed ^ 0x5bd1e995);
  for (let step = 0; step < steps; step++) {
    const sec = run.self ? "SELF" : run.pickSection();
    run.lastSec = sec;
    const pi = run.makeItem(sec);
    const ts = nextIqItem(scope, lang, resp, state);
    sameItem(`${scope} ${lang} seed ${seed} step ${step}`, ts, pi);
    const u = player.chance(irt.p3(trueTheta, ts.a, ts.b, ts.c)) ? 1 : 0;
    const conf = player.pick([0.25, 0.5, 0.75, 1]);
    const rec = { sec: ts.sec, gid: ts.gid, d: ts.d, a: ts.a, b: ts.b, c: ts.c, u, ms: 4000 };
    if (run.self) { run.selfRows.push({ r: rec, u, conf }); run.resp.push({ ...rec, conf }); resp.push({ ...rec, conf }); }
    else { run.resp.push(rec); resp.push(rec); }
  }
  assertEquals([...run.used].sort(), state.used.slice().sort(), "used analogies / fallacies");
  return { run, resp };
}

Deno.test("adaptive IQ sessions pick the same items as the prototype's Runner", () => {
  for (const lang of ["en", "es"] as Lang[]) {
    for (const scope of ["ALL", ...SECS]) {
      for (let s = 0; s < 6; s++) {
        const seed = hashStr(`iq-${scope}-${lang}-${s}`);
        simulateIq(lang, scope, seed, (s - 2.5) * 0.8, 45, scope === "SELF" ? 0.4 : 0);
      }
    }
  }
});

Deno.test("never the same generator 3x in a row; mixed never repeats a section", () => {
  for (let s = 0; s < 30; s++) {
    for (const scope of ["ALL", "LOG", "SPA", "LIN", "MUS", "EXI"]) {
      const { resp } = simulateIq("en", scope, hashStr(`rep-${scope}-${s}`), 0.5, 60);
      for (const sec of new Set(resp.map((x) => x.sec))) {
        const g = resp.filter((x) => x.sec === sec).map((x) => x.gid);
        for (let i = 2; i < g.length; i++) assert(!(g[i] === g[i - 1] && g[i] === g[i - 2]), `${scope}: ${g[i]} 3x in a row`);
      }
      if (scope === "ALL") for (let i = 1; i < resp.length; i++) assert(resp[i].sec !== resp[i - 1].sec, "mixed repeated a section");
    }
  }
});

Deno.test("IQ scoring matches the prototype's scoreIQ (incl. SELF)", () => {
  for (const scope of ["ALL", "LOG", "SELF"]) {
    for (let s = 0; s < 8; s++) {
      const seed = hashStr(`score-${scope}-${s}`);
      const { run, resp } = simulateIq("en", scope, seed, s * 0.4 - 1.4, 50, 0.2);
      const flags: Flags = { hidden: s % 4, rapid: s % 5 };
      const pred = scope === "SELF" ? 0.6 : null;
      const ts = scoreIQ(resp, flags, scope === "SELF" ? { rows: resp.map((x) => ({ u: x.u, conf: x.conf! })), pred } : null);
      const pr = P.en.scoreIQ(run.resp, flags, scope === "SELF" ? { rows: run.selfRows, pred } : null);
      assertEquals(JSON.parse(JSON.stringify(ts.secs)), JSON.parse(JSON.stringify(pr.secs)));
      assertEquals(ts.flagged, pr.flagged);
      assertEquals(ts.composite ?? undefined, pr.composite);
    }
  }
});

Deno.test("Blitz batches match the prototype's Runner (shuffled section bag, d = 4)", () => {
  for (const lang of ["en", "es"] as Lang[]) {
    for (const scope of ["ALL", ...MIXED_POOL]) {
      const seed = scope === "ALL" ? hashStr("voodoo-daily-2026-10-03") : hashStr(`blitz-${scope}-${lang}`);
      const run = new P[lang].Runner({ mode: "blitz", scope, seed, dur: 180 });
      const batch = blitzBatch(seed, scope, lang, 120);
      batch.forEach((ts, i) => sameItem(`blitz ${scope} ${lang} #${i}`, ts, run.makeItem(run.pickSection())));
    }
  }
});

Deno.test("standings and gates match the prototype", () => {
  const r = new Rng(777), now = Date.now(), DAY = 864e5;
  for (let trial = 0; trial < 200; trial++) {
    const p: any = { iq: {} };
    const rows: ScoreRow[] = [];
    for (const sec of SECS) {
      const n = r.int(0, 6);
      const ts = Array.from({ length: n }, () => now - Math.floor(r.n() * 80 * DAY)).sort((a, b) => a - b);
      p.iq[sec] = ts.map((t) => {
        const e = { t, day: new Date(t).toISOString().slice(0, 10), th: r.n() * 4 - 2, se: 0.15 + r.n() * 0.6, n: r.int(5, 40), hard: r.int(0, 5), f: r.chance(0.15) ? 1 : 0, lang: r.pick(["en", "es"]) };
        rows.push({ sec, day: e.day, theta: e.th, se: e.se, n: e.n, hard: e.hard, lang: e.lang, flagged: !!e.f, created_at: new Date(t).toISOString() });
        return e;
      });
    }
    for (const sec of SECS) for (const lang of [null, "en", "es"]) {
      const a = secStanding(rows, sec, lang, now), b = P.en.secStanding(p, sec, lang);
      if (!a || !b) { assertEquals(a, b); continue; }
      for (const f of ["theta", "se", "n", "hard", "consistent", "ranked", "cons", "genius", "score", "needItems", "sessions"]) assertEquals((a as any)[f], b[f], `${sec} ${f}`);
      assertEquals(a.days, b.days);
    }
    for (const lang of [null, "en", "es"]) {
      const a: any = viqStanding(rows, lang, now), b = P.en.viqStanding(p, lang);
      for (const f of ["verified", "theta", "se", "score", "genius"]) assertEquals(a[f], b[f], `viq ${f}`);
      assertEquals(a.checks.days, b.checks.days);
      assertEquals(a.checks.consistent, b.checks.consistent);
    }
    const a: any = nineStanding(rows, now), b = P.en.nineStanding(p);
    for (const f of ["ranked", "ok", "theta", "se", "score"]) {
      if (typeof b[f] === "number" && !Number.isInteger(b[f])) assertAlmostEquals(a[f], b[f], 1e-12);
      else assertEquals(a[f], b[f], `nine ${f}`);
    }
  }
});
