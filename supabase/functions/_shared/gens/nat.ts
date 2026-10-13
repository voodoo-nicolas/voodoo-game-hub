// NATURALIST: invented "voodoo creatures" — classification, no trivia. Ported 1:1 from the prototype.
// Creature = 7 ints. Ternary features: 0 body, 1 color, 2 pattern, 3 legs, 4 eyes; binary: 5 antennae, 6 tail.
import { defGen, type GenDef, GENS, mkItem } from "./registry.ts";
import type { Rng } from "../rng.ts";

export type Creature = number[];
export function randCreature(r: Rng): Creature { return [r.int(0, 2), r.int(0, 2), r.int(0, 2), r.int(0, 2), r.int(0, 2), r.int(0, 1), r.int(0, 1)]; }
function natCands() {
  const c: { k: string; f: (x: Creature) => number }[] = [];
  for (let f = 0; f < 7; f++) c.push({ k: "s" + f, f: (x) => x[f] });
  for (let f = 0; f < 5; f++) for (let g = f + 1; g < 5; g++) { c.push({ k: `p${f}${g}`, f: (x) => (x[f] + x[g]) % 3 }); c.push({ k: `m${f}${g}`, f: (x) => (x[f] - x[g] + 3) % 3 }); }
  return c;
}
/** every candidate rule (single features and mod-3 sums / differences of two ternary features) */
export const NAT_CANDS = natCands();

defGen({
  id: "natclass", sec: "NAT", a: 1.3, k: 3, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const pair = d >= 7, per = d <= 2 ? 4 : d <= 6 ? 3 : d <= 8 ? 4 : 3;
    for (let tries = 0; tries < 400; tries++) {
      let rule: (x: Creature) => number, ruleKey: string;
      if (!pair) { const f = r.int(0, 4); rule = (x) => x[f]; ruleKey = "s" + f; }
      else { const f = r.int(0, 3), g = r.int(f + 1, 4), op = r.chance(.5); rule = op ? (x) => (x[f] + x[g]) % 3 : (x) => (x[f] - x[g] + 3) % 3; ruleKey = (op ? "p" : "m") + f + g; }
      const perm = r.shuffle([0, 1, 2]);
      const fam = (x: Creature) => perm[rule(x)];
      const ex: Creature[][] = [[], [], []];
      let guard = 0;
      while ((ex[0].length < per || ex[1].length < per || ex[2].length < per) && guard++ < 500) { const c = randCreature(r); const F = fam(c); if (ex[F].length < per) ex[F].push(c); }
      if (guard >= 500) continue;
      let q: Creature;
      do { q = randCreature(r); } while (ex.flat().some((e) => e.join() === q.join()));
      const ans = fam(q);
      // Exactly one candidate rule may explain the examples (2026-10-13: a second trait that
      // happens to split the families the same way is a second thing to notice, and one that
      // disagrees on the new creature made two right answers); it must give the family.
      let ok = true;
      for (const c of NAT_CANDS) {
        const vals = ex.map((list) => new Set(list.map(c.f)));
        if (vals.some((s) => s.size !== 1)) continue;
        const v = vals.map((s) => [...s][0]);
        if (new Set(v).size !== 3) continue;
        if (c.k !== ruleKey || v.indexOf(c.f(q)) !== ans) { ok = false; break; }
      }
      if (!ok) continue;
      return mkItem(this, d, { display: { families: ex, query: q }, key: { t: "idx", v: ans } });
    }
    return GENS.natodd.make(d, r, ctx);
  },
});

/** Which creature (index) each candidate rule singles out as "the one the other four are not":
 *  a value held by exactly one creature, or by exactly four (then the odd one is the other).
 *  A clean puzzle has ONE such creature across every candidate rule. */
export function loneCreatures(all: Creature[]): Set<number> {
  const lone = new Set<number>();
  for (const c of NAT_CANDS) {
    const v = all.map(c.f);
    const cnt: Record<number, number> = {};
    v.forEach((x) => cnt[x] = (cnt[x] || 0) + 1);
    for (const k of Object.keys(cnt)) {
      const n = cnt[Number(k)];
      if (n === 1) lone.add(v.indexOf(Number(k)));
      else if (n === 4) lone.add(v.findIndex((x) => x !== Number(k)));
    }
  }
  return lone;
}

/** One trait's five values with no stray 4-vs-1 in it: all five the same, or a 3 / 2 split of
 *  two values. (A third value would be a lone creature, or a 2-2-1 with a lone one: players
 *  would read "everyone except the striped one" as a rule.) */
function balancedColumn(r: Rng, nvals: number): number[] {
  const vals = r.shuffle(Array.from({ length: nvals }, (_, i) => i));
  if (r.chance(.3)) return [0, 0, 0, 0, 0].map(() => vals[0]);
  return r.shuffle([vals[0], vals[0], vals[0], vals[1], vals[1]]);
}

/** Odd-creature-out item. Deviation from the prototype (2026-10-13, players found puzzles with
 *  several valid answers): exactly one trait splits 4-vs-1; every other trait is the same on all
 *  five or splits 3 / 2, and the whole set is checked against every candidate rule. */
export function natOddItem(g: GenDef, d: number, r: Rng) {
  const pair = d >= 8;
  for (let tries = 0; tries < 800; tries++) {
    const pos = r.int(0, 4);
    const cols: number[][] = [];
    for (let f = 0; f < 7; f++) cols.push(balancedColumn(r, f < 5 ? 3 : 2));
    if (!pair) {
      const f = r.int(0, d <= 3 ? 6 : 4);
      const nv = f < 5 ? 3 : 2;
      const vals = r.shuffle(Array.from({ length: nv }, (_, i) => i));
      cols[f] = [0, 1, 2, 3, 4].map((i) => (i === pos ? vals[1] : vals[0]));
    }
    const all: Creature[] = [0, 1, 2, 3, 4].map((i) => cols.map((c) => c[i]));
    if (new Set(all.map((c) => c.join())).size < 5) continue;
    const lone = loneCreatures(all);
    if (lone.size !== 1 || !lone.has(pos)) continue;
    return mkItem(g, d, { display: { creatures: all }, key: { t: "idx", v: pos } });
  }
  return null;
}
defGen({ id: "natodd", sec: "NAT", a: 1.3, k: 5, minMs: 1200, maxMs: 45000, make(d, r) { return natOddItem(this, d, r) || natOddItem(this, Math.max(1, d - 2), r) || natOddItem(this, 1, r); } });
defGen({ id: "natquick", sec: "NAT", a: 1.1, k: 5, minMs: 600, maxMs: 20000, w: 3, make(_d, r) { return natOddItem(this, r.int(1, 3), r) || natOddItem(this, 1, r); } });
