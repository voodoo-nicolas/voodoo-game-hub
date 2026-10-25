// NATURALIST, second set (2026-10-25; NOT in the prototype): inherit (who's the baby),
// foodweb, idkey (use the key), camo (hide and seek), spotdiff (spot the difference).
// Creatures are the prototype's 7 traits: 0 body, 1 colour, 2 pattern, 3 legs, 4 eyes,
// 5 antennae, 6 tail. Served only to clients that send gv >= 5 (engine.ts secGens).
import { defGen, type Lang, mkItem } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { type Creature, randCreature } from "./nat.ts";

const TRAIT_N = [3, 3, 3, 3, 3, 2, 2];
const same = (a: Creature, b: Creature) => a.every((v, i) => v === b[i]);
const other = (r: Rng, t: number, not: number[]) => r.pick(Array.from({ length: TRAIT_N[t] }, (_, i) => i).filter((v) => !not.includes(v)));

/* ---------------- inherit: each varied trait comes from one parent (4 options) ----------------
   Families show parent 1 + parent 2 -> baby. In every family the parents differ in every
   varied trait, and the babies differ from each other in every varied trait, so the
   examples fix where each trait comes from (and rule out "always this value"). */
defGen({
  id: "inherit", sec: "NAT", a: 1.3, k: 4, minMs: 2500, maxMs: 80000,
  make(d, r) {
    const nv = d <= 3 ? 2 : d <= 6 ? 3 : 4, nf = d >= 9 ? 3 : 2;
    for (let tries = 0; tries < 300; tries++) {
      const traits = r.shuffle([0, 1, 2, 3, 4, 5, 6]).slice(0, nv);
      const from = traits.map(() => r.int(0, 1)); // 0 = parent 1, 1 = parent 2
      const base = randCreature(r);
      const pair = (): [Creature, Creature] => {
        const a = base.slice(), b = base.slice();
        for (const t of traits) { a[t] = r.int(0, TRAIT_N[t] - 1); b[t] = other(r, t, [a[t]]); }
        return [a, b];
      };
      const child = ([a, b]: [Creature, Creature]) => { const c = base.slice(); traits.forEach((t, i) => { c[t] = (from[i] ? b : a)[t]; }); return c; };
      const fams = Array.from({ length: nf }, pair).map((p) => [p[0], p[1], child(p)]);
      if (!traits.every((t) => new Set(fams.map((f) => f[2][t])).size > 1)) continue;
      const q = pair(), ans = child(q);
      const wrong: Creature[] = [];
      for (const i of r.shuffle(traits.map((_, i) => i))) {
        const w = ans.slice(); w[traits[i]] = (from[i] ? q[0] : q[1])[traits[i]];
        if (wrong.length < 3) wrong.push(w);
      }
      if (wrong.length < 3) { const w = ans.slice(); traits.forEach((t, i) => { w[t] = (from[i] ? q[0] : q[1])[t]; }); wrong.push(w); }
      if (wrong.length < 3 || wrong.some((w, i) => same(w, ans) || wrong.slice(0, i).some((o) => same(o, w)))) continue;
      const opts = r.shuffle([ans, ...wrong]);
      return mkItem(this, d, { display: { families: fams, parents: q, options: opts }, key: { t: "idx", v: opts.findIndex((o) => same(o, ans)) }, meta: { traits, from } });
    }
    return null;
  },
});

/* ---------------- foodweb: what happens first? (3 options) ----------------
   A connected piece of one realistic web. Removing an animal's predator: more of it.
   Removing its only food: fewer of it. Two steps: remove a predator -> its prey grow ->
   the prey's food (eaten by nothing else here) shrinks. */
export const SPECIES: Record<string, { lvl: number; en: string; es: string }> = {
  grass: { lvl: 0, en: "grass", es: "el pasto" },
  seeds: { lvl: 0, en: "seeds", es: "las semillas" },
  berries: { lvl: 0, en: "berries", es: "las bayas" },
  rabbit: { lvl: 1, en: "rabbits", es: "los conejos" },
  mouse: { lvl: 1, en: "mice", es: "los ratones" },
  deer: { lvl: 1, en: "deer", es: "los ciervos" },
  hopper: { lvl: 1, en: "grasshoppers", es: "los saltamontes" },
  fox: { lvl: 2, en: "foxes", es: "los zorros" },
  owl: { lvl: 2, en: "owls", es: "las lechuzas" },
  frog: { lvl: 2, en: "frogs", es: "las ranas" },
  snake: { lvl: 2, en: "snakes", es: "las serpientes" },
  hawk: { lvl: 3, en: "hawks", es: "los halcones" },
  wolf: { lvl: 3, en: "wolves", es: "los lobos" },
};
export const FOOD: [string, string][] = [ // [food, eater]
  ["grass", "rabbit"], ["grass", "deer"], ["grass", "hopper"], ["seeds", "mouse"], ["berries", "mouse"], ["berries", "deer"],
  ["rabbit", "fox"], ["mouse", "fox"], ["mouse", "owl"], ["mouse", "snake"], ["hopper", "frog"], ["frog", "snake"],
  ["snake", "hawk"], ["rabbit", "hawk"], ["mouse", "hawk"], ["deer", "wolf"], ["rabbit", "wolf"],
];
/** The client's drawing box (600 x 340, rows from y 24 to 316) and node boxes. */
export interface WebNode { id: string; name: string; x: number; y: number }
export function webClear(nodes: WebNode[], edges: [string, string][]): boolean {
  const most = Math.max(...Object.values(nodes.reduce((m: Record<number, number>, n) => ((m[n.y] = (m[n.y] || 0) + 1), m), {})));
  const hw = Math.min(120, 600 / (most + 1) - 14) / 2 + 6, hh = 16 + 6;
  const P = (n: WebNode) => [n.x * 600, 24 + n.y * 292];
  for (let i = 0; i < nodes.length; i++) for (let j = i + 1; j < nodes.length; j++) {
    const [ax, ay] = P(nodes[i]), [bx, by] = P(nodes[j]);
    if (Math.abs(ax - bx) < hw * 2 && Math.abs(ay - by) < hh * 2) return false; // boxes overlap
  }
  for (const [a, b] of edges) {
    const A = nodes.find((n) => n.id === a)!, B = nodes.find((n) => n.id === b)!;
    const [ax, ay] = P(A), [bx, by] = P(B);
    for (const n of nodes) {
      if (n === A || n === B) continue;
      const [cx, cy] = P(n);
      for (let t = 0; t <= 1; t += 0.02) {
        const x = ax + (bx - ax) * t, y = ay + (by - ay) * t;
        if (Math.abs(x - cx) < hw && Math.abs(y - cy) < hh) return false;
      }
    }
  }
  return true;
}
export const NAMES_Q: Record<Lang, (x: string, y: string) => string> = {
  en: (x, y) => `All the ${x} ${x === "grass" ? "disappears" : "disappear"}. What happens to the ${y} first?`,
  // "todo el pasto" / "todos los zorros" / "todas las ranas"
  es: (x, y) => `${x.startsWith("el ") ? "Desaparece todo" : x.startsWith("las ") ? "Desaparecen todas" : "Desaparecen todos"} ${x}. ¿Qué pasa primero con ${y}?`,
};
defGen({
  id: "foodweb", sec: "NAT", a: 1.2, k: 3, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const size = d <= 3 ? 4 : d <= 6 ? 5 : d <= 8 ? 6 : 7;
    for (let tries = 0; tries < 400; tries++) {
      // grow a connected set of species along food links
      const set = new Set([r.pick(Object.keys(SPECIES))]);
      while (set.size < size) {
        const links = FOOD.filter(([a, b]) => set.has(a) !== set.has(b));
        if (!links.length) break;
        const [a, b] = r.pick(links);
        set.add(a); set.add(b);
      }
      if (set.size !== size) continue;
      const edges = FOOD.filter(([a, b]) => set.has(a) && set.has(b));
      const eaters = (s: string) => edges.filter(([a]) => a === s).map(([, b]) => b);
      const foods = (s: string) => edges.filter(([, b]) => b === s).map(([a]) => a);
      const qs: { x: string; y: string; ans: string }[] = [];
      for (const [food, eater] of edges) {
        // predator removed; skipped when it also eats another of `food`'s predators (then
        // that one grows too and the answer could go either way)
        if (!eaters(food).some((e) => e !== eater && foods(eater).includes(e))) qs.push({ x: eater, y: food, ans: "more" });
        if (foods(eater).length === 1) qs.push({ x: food, y: eater, ans: "fewer" }); // only food removed
      }
      const two: { x: string; y: string; ans: string }[] = [];
      // two steps: `pred` is the prey's only predator and the prey is the only eater of `fd`
      for (const [prey, pred] of edges) if (eaters(prey).length === 1) for (const fd of foods(prey)) if (eaters(fd).length === 1) two.push({ x: pred, y: fd, ans: "fewer" });
      const pool = d >= 7 && two.length ? two : d <= 3 ? qs.filter((q) => q.ans === "more") : qs;
      if (!pool.length) continue;
      const q = r.pick(pool);
      const names = [...set];
      const L = (s: string) => SPECIES[s][ctx.lang];
      // layout: one row per food level, top predators at the top; rows shuffled and nudged
      // until no arrow runs behind another animal's box
      const rows = [3, 2, 1, 0].map((l) => names.filter((s) => SPECIES[s].lvl === l)).filter((row) => row.length);
      let nodes: WebNode[] = [];
      for (let lay = 0; lay < 60; lay++) {
        nodes = rows.flatMap((row, ri) => r.shuffle(row).map((s, i) => ({
          id: s, name: L(s).replace(/^(el|la|los|las) /, ""),
          x: Math.round(((i + 1) / (row.length + 1) + (r.n() - .5) * .5 / (row.length + 1)) * 1000) / 1000,
          y: (ri + 0.5) / rows.length,
        })));
        if (webClear(nodes, edges)) break;
        nodes = [];
      }
      if (!nodes.length) continue;
      const text = NAMES_Q[ctx.lang](L(q.x), L(q.y));
      const options = ["more", "fewer", "same"];
      return mkItem(this, d, { display: { nodes, edges, text, options }, key: { t: "idx", v: options.indexOf(q.ans) }, meta: { x: q.x, y: q.y, two: d >= 7 && two.length > 0 } });
    }
    return null;
  },
});

/* ---------------- idkey: follow an identification key (4 options) ---------------- */
export const KEY_TESTS: Record<string, (x: Creature) => boolean> = {
  tail: (x) => x[6] === 1, ant: (x) => x[5] === 1, spots: (x) => x[2] === 1, stripes: (x) => x[2] === 2,
  plain: (x) => x[2] === 0, six: (x) => x[3] === 2, two: (x) => x[3] === 0, oneeye: (x) => x[4] === 0,
  threeeyes: (x) => x[4] === 2, round: (x) => x[0] === 0, tall: (x) => x[0] === 1, box: (x) => x[0] === 2,
  morelegs: (x) => x[3] >= 1, moreeyes: (x) => x[4] >= 1,
};
const KEY_NAMES = ["Zib", "Zab", "Zub", "Zeb", "Bix", "Box", "Bux", "Bex"];
const TEST_TRAIT: Record<string, number> = { tail: 6, ant: 5, spots: 2, stripes: 2, plain: 2, six: 3, two: 3, oneeye: 4, threeeyes: 4, round: 0, tall: 0, box: 0, morelegs: 3, moreeyes: 4 };
export interface Couplet { t: string; y: number | string; n: number | string }
defGen({
  id: "idkey", sec: "NAT", a: 1.2, k: 4, minMs: 2500, maxMs: 70000,
  make(d, r) {
    const depth = d <= 3 ? 2 : 3;
    const pool = d >= 8 ? Object.keys(KEY_TESTS) : Object.keys(KEY_TESTS).filter((t) => t !== "morelegs" && t !== "moreeyes");
    for (let tries = 0; tries < 200; tries++) {
      const names = r.shuffle(KEY_NAMES).slice(0, 2 ** depth);
      const couplets: Couplet[] = [];
      let leaf = 0;
      // couplets numbered in order (yes branch first); a path never tests the same trait twice
      const build = (lvl: number, used: number[]): number | string => {
        if (lvl === depth) return names[leaf++];
        const t = r.pick(pool.filter((k) => !used.includes(TEST_TRAIT[k])));
        const c: Couplet = { t, y: 0, n: 0 };
        couplets.push(c);
        const me = couplets.length;
        c.y = build(lvl + 1, [...used, TEST_TRAIT[t]]);
        c.n = build(lvl + 1, [...used, TEST_TRAIT[t]]);
        return me;
      };
      build(0, []);
      const x = randCreature(r);
      let at: number | string = 1;
      while (typeof at === "number") { const c: Couplet = couplets[at - 1]; at = KEY_TESTS[c.t](x) ? c.y : c.n; }
      const ans = at;
      const wrong = r.shuffle(names.filter((n) => n !== ans)).slice(0, 3);
      const opts = r.shuffle([ans, ...wrong]);
      return mkItem(this, d, { display: { creature: x, couplets, options: opts }, key: { t: "idx", v: opts.indexOf(ans) } });
    }
    return null;
  },
});

/* ---------------- camo: which quarter is it hiding in? (4 options) ----------------
   The client draws `clutter` leaf blobs from `seed` in colours near the creature's
   (closer as d rises) and the creature, smaller, inside quarter `q`. */
defGen({
  id: "camo", sec: "NAT", a: 1.1, k: 4, minMs: 800, maxMs: 40000,
  make(d, r) {
    const q = r.int(0, 3);
    const size = [0.3, 0.28, 0.26, 0.24, 0.22, 0.2, 0.18, 0.17, 0.16, 0.15][d - 1];
    const m = size / 2 + 0.02;
    return mkItem(this, d, {
      display: {
        creature: randCreature(r), q, px: m + r.n() * (0.5 - 2 * m), py: m + r.n() * (0.5 - 2 * m), size,
        clutter: 40 + d * 8, seed: r.int(1, 2147483646), blend: [0.35, 0.45, 0.55, 0.62, 0.68, 0.74, 0.8, 0.85, 0.88, 0.91][d - 1],
      },
      key: { t: "idx", v: q },
    });
  },
});

/* ---------------- spotdiff: what is different? (4 options) ----------------
   d 1-5: one trait differs (options: trait names). d 6-10: two traits differ (options:
   pairs of trait names; the wrong pairs share at most one trait with the right one). */
defGen({
  id: "spotdiff", sec: "NAT", a: 1.1, k: 4, minMs: 1200, maxMs: 40000,
  make(d, r) {
    const a = randCreature(r), b = a.slice();
    const n = d <= 5 ? 1 : 2;
    const diff = r.shuffle([0, 1, 2, 3, 4, 5, 6]).slice(0, n).sort((p, q) => p - q);
    for (const t of diff) b[t] = other(r, t, [a[t]]);
    let ans: number[], wrong: number[][];
    if (n === 1) {
      ans = diff;
      wrong = r.shuffle([0, 1, 2, 3, 4, 5, 6].filter((t) => t !== diff[0])).slice(0, 3).map((t) => [t]);
    } else {
      ans = diff;
      const pairs: number[][] = [];
      for (let i = 0; i < 7; i++) for (let j = i + 1; j < 7; j++) if (!(i === diff[0] && j === diff[1])) pairs.push([i, j]);
      wrong = r.shuffle(pairs.filter((p) => p.includes(diff[0]) || p.includes(diff[1]))).slice(0, 3);
    }
    const opts = r.shuffle([ans, ...wrong]);
    const flip = r.chance(.5);
    return mkItem(this, d, { display: { left: flip ? b : a, right: flip ? a : b, options: opts }, key: { t: "idx", v: opts.indexOf(ans) } });
  },
});
