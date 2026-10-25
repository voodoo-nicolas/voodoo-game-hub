// LINGUISTIC, second set (2026-10-25; NOT in the prototype): remote (missing link),
// synonym (same meaning / opposite), cloze (finish the sentence), unscramble, proverb,
// inference (read between the lines). Hand-written banks in lin2_data.ts; served only to
// clients that send gv >= 3 (engine.ts secGens).
import { type Ctx, defGen, type GenDef, mkItem } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { CLOZE, INFER, PROVERB, RAT, SCRAMBLE, SYN, type Tiers } from "./lin2_data.ts";

export const tierOf = (d: number) => (d <= 3 ? 0 : d <= 7 ? 1 : 2);

/** An item of the tier for d that this session hasn't had (any of the tier once all are used). */
function pickFrom<T>(g: GenDef, bank: { en: Tiers<T>; es: Tiers<T> }, d: number, r: Rng, ctx: Ctx): T {
  const t = tierOf(d), list = bank[ctx.lang][t];
  const fresh = list.map((_, i) => i).filter((i) => !ctx.used.has(`${g.id}${t}:${i}`));
  const i = r.pick(fresh.length ? fresh : list.map((_, i) => i));
  ctx.used.add(`${g.id}${t}:${i}`);
  return list[i];
}
function mc(g: GenDef, d: number, r: Rng, ans: string, wrong: string[], display: Record<string, unknown>) {
  const options = r.shuffle([ans, ...wrong]);
  return mkItem(g, d, { display: { ...display, options }, key: { t: "idx", v: options.indexOf(ans) }, meta: { ans } });
}

defGen({
  id: "remote", sec: "LIN", a: 1.4, k: 4, minMs: 1500, maxMs: 60000,
  make(d, r, ctx) {
    const [a, b, c, ans, wrong] = pickFrom(this, RAT, d, r, ctx);
    return mc(this, d, r, ans, wrong, { words: r.shuffle([a, b, c]) });
  },
});
defGen({
  id: "synonym", sec: "LIN", a: 1.3, k: 4, minMs: 1000, maxMs: 40000,
  make(d, r, ctx) {
    const [w, ans, wrong, kind] = pickFrom(this, SYN, d, r, ctx);
    return mc(this, d, r, ans, wrong, { word: w, kind });
  },
});
defGen({
  id: "cloze", sec: "LIN", a: 1.3, k: 4, minMs: 1500, maxMs: 50000,
  make(d, r, ctx) {
    const [s, ans, wrong] = pickFrom(this, CLOZE, d, r, ctx);
    return mc(this, d, r, ans, wrong, { sentence: s });
  },
});
defGen({
  id: "proverb", sec: "LIN", a: 1.2, k: 4, minMs: 2000, maxMs: 60000,
  make(d, r, ctx) {
    const [s, ans, wrong] = pickFrom(this, PROVERB, d, r, ctx);
    return mc(this, d, r, ans, wrong, { saying: s });
  },
});
defGen({
  id: "inference", sec: "LIN", a: 1.4, k: 4, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const [p, q, ans, wrong] = pickFrom(this, INFER, d, r, ctx);
    return mc(this, d, r, ans, wrong, { passage: p, q });
  },
});
/* The player taps the tiles in order; the answer is the tiles joined by single spaces. */
defGen({
  id: "unscramble", sec: "LIN", a: 1.3, k: 0, minMs: 2500, maxMs: 90000,
  make(d, r, ctx) {
    const [s, alts] = pickFrom(this, SCRAMBLE, d, r, ctx);
    const words = s.split(" ");
    let tiles = words;
    for (let k = 0; k < 20 && tiles.join(" ") === s; k++) tiles = r.shuffle(words);
    return mkItem(this, d, { display: { tiles }, key: { t: "any", v: [s, ...alts] } });
  },
});
