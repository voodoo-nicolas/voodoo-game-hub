// LINGUISTIC (ES / EN banks): oddword, oddquick, anagram, analogy. Ported 1:1 from the prototype.
// deno-lint-ignore-file no-explicit-any
import { defGen, type GenDef, type Lang, mkItem } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { ANA, ANALOGIES, CATS, CLOSE, TRICKS } from "./data.ts";

const CATS_: Record<string, { g: string; en: string[]; es: string[] }> = CATS;
const TRICKS_: any[] = TRICKS;
const ANA_: Record<string, Record<number, string[]>> = ANA;
const ANALOGIES_: any[] = ANALOGIES;

function oddWordItem(g: GenDef, d: number, r: Rng, lang: Lang) {
  let four: string[], odd: string;
  if (d >= 9 || (d === 8 && r.chance(.5))) { const tr = r.pick(TRICKS_)[lang]; four = tr[0].slice(); odd = tr[1]; }
  else {
    let A: string, B: string;
    const names = Object.keys(CATS_);
    if (d <= 2) { A = r.pick(names); B = r.pick(names.filter((n) => CATS_[n].g !== CATS_[A].g)); }
    else if (d <= 5) { A = r.pick(names); const same = names.filter((n) => n !== A && CATS_[n].g === CATS_[A].g); B = same.length ? r.pick(same) : r.pick(names.filter((n) => n !== A)); }
    else { const pr = r.shuffle(r.pick(CLOSE)); A = pr[0]; B = pr[1]; }
    four = r.shuffle(CATS_[A][lang]).slice(0, 4);
    odd = r.pick(CATS_[B][lang]);
  }
  const words = r.shuffle([...four, odd]);
  const ansIdx = words.indexOf(odd);
  return mkItem(g, d, { lang, display: { words }, key: { t: "idx", v: ansIdx }, meta: { four, odd } });
}
defGen({ id: "oddword", sec: "LIN", a: 1.3, k: 5, minMs: 1200, maxMs: 30000, make(d, r, ctx) { return oddWordItem(this, d, r, ctx.lang); } });
defGen({ id: "oddquick", sec: "LIN", a: 1.1, k: 5, minMs: 500, maxMs: 15000, w: 2, make(_d, r, ctx) { return oddWordItem(this, r.int(1, 3), r, ctx.lang); } });

/* Anagrams with letter tiles. Word lists chosen to have no common alternative anagram. */
defGen({
  id: "anagram", sec: "LIN", a: 1.4, k: 0, minMs: 1500, maxMs: 60000,
  make(d, r, ctx) {
    const lang = ctx.lang;
    const len = [4, 4, 5, 5, 6, 6, 7, 7, 8, 9][d - 1];
    const word = r.pick(ANA_[lang][len]);
    let sc: string[];
    do { sc = r.shuffle(word.split("")); } while (sc.join("") === word);
    const sig = (w: string) => w.split("").sort().join("");
    const valid = [...new Set(Object.values(ANA_[lang]).flat().filter((w) => sig(w) === sig(word)))];
    return mkItem(this, d, { lang, display: { letters: sc }, key: { t: "any", v: valid }, meta: { word } });
  },
});

/* Analogies — curated, parallel ES/EN, answer is always option 0 before shuffling */
defGen({
  id: "analogy", sec: "LIN", a: 1.4, k: 4, minMs: 1500, maxMs: 45000,
  make(d, r, ctx) {
    const lang = ctx.lang;
    const used = ctx.used || new Set();
    let best: [number, any] | null = null, bd = 99;
    for (const [i, it] of r.shuffle(ANALOGIES_.map((x, i) => [i, x] as [number, any]))) {
      if (used.has("an" + i)) continue;
      const dd = Math.abs(it[0] - d);
      if (dd < bd) { bd = dd; best = [i, it]; }
    }
    if (!best) best = [0, ANALOGIES_[0]];
    used.add("an" + best[0]);
    const [dd, en, es] = best[1];
    const it = lang === "es" ? es : en;
    const order = r.shuffle([0, 1, 2, 3]);
    const ansIdx = order.indexOf(0);
    return mkItem(this, dd, { lang, display: { a: it[0], b: it[1], c: it[2], options: order.map((i) => it[3][i]) }, key: { t: "idx", v: ansIdx } });
  },
});
