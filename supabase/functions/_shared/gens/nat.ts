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
      let rule: (x: Creature) => number;
      if (!pair) { const f = r.int(0, 4); rule = (x) => x[f]; }
      else { const f = r.int(0, 3), g = r.int(f + 1, 4), op = r.chance(.5); rule = op ? (x) => (x[f] + x[g]) % 3 : (x) => (x[f] - x[g] + 3) % 3; }
      const perm = r.shuffle([0, 1, 2]);
      const fam = (x: Creature) => perm[rule(x)];
      const ex: Creature[][] = [[], [], []];
      let guard = 0;
      while ((ex[0].length < per || ex[1].length < per || ex[2].length < per) && guard++ < 500) { const c = randCreature(r); const F = fam(c); if (ex[F].length < per) ex[F].push(c); }
      if (guard >= 500) continue;
      let q: Creature;
      do { q = randCreature(r); } while (ex.flat().some((e) => e.join() === q.join()));
      const ans = fam(q);
      // every candidate rule that explains all examples must give the same answer
      let ok = true;
      for (const c of NAT_CANDS) {
        const vals = ex.map((list) => new Set(list.map(c.f)));
        if (vals.some((s) => s.size !== 1)) continue;
        const v = vals.map((s) => [...s][0]);
        if (new Set(v).size !== 3) continue;
        if (v.indexOf(c.f(q)) !== ans) { ok = false; break; }
      }
      if (!ok) continue;
      return mkItem(this, d, { display: { families: ex, query: q }, key: { t: "idx", v: ans } });
    }
    return GENS.natodd.make(d, r, ctx);
  },
});

export function natOddItem(g: GenDef, d: number, r: Rng) {
  const pair = d >= 8;
  for (let tries = 0; tries < 600; tries++) {
    let rule: (x: Creature) => number;
    if (!pair) { const f = r.int(0, d <= 3 ? 6 : 4); rule = (x) => x[f]; }
    else { const f = r.int(0, 3), gg = r.int(f + 1, 4); rule = r.chance(.5) ? (x) => (x[f] + x[gg]) % 3 : (x) => (x[f] - x[gg] + 3) % 3; }
    const cs: Creature[] = [];
    let target: number | null = null, guard = 0;
    while (cs.length < 4 && guard++ < 400) { const c = randCreature(r); if (target == null) target = rule(c); if (rule(c) === target && !cs.some((e) => e.join() === c.join())) cs.push(c); }
    if (cs.length < 4) continue;
    let odd: Creature;
    guard = 0;
    do { odd = randCreature(r); } while (rule(odd) === target && guard++ < 200);
    if (rule(odd) === target) continue;
    const pos = r.int(0, 4);
    const all = cs.slice();
    all.splice(pos, 0, odd);
    let ok = true;
    for (const c of NAT_CANDS) {
      const v = all.map(c.f);
      const cnt: Record<string, number> = {};
      v.forEach((x) => cnt[x] = (cnt[x] || 0) + 1);
      const keys = Object.keys(cnt);
      if (keys.length !== 2) continue;
      const lone = keys.find((k) => cnt[k] === 1);
      if (lone == null) continue;
      if (v.indexOf(Number(lone)) !== pos) { ok = false; break; }
    }
    if (!ok) continue;
    return mkItem(g, d, { display: { creatures: all }, key: { t: "idx", v: pos } });
  }
  return null;
}
defGen({ id: "natodd", sec: "NAT", a: 1.3, k: 5, minMs: 1200, maxMs: 45000, make(d, r) { return natOddItem(this, d, r) || natOddItem(this, Math.max(1, d - 2), r) || natOddItem(this, 1, r); } });
defGen({ id: "natquick", sec: "NAT", a: 1.1, k: 5, minMs: 600, maxMs: 20000, w: 3, make(_d, r) { return natOddItem(this, r.int(1, 3), r) || natOddItem(this, 1, r); } });
