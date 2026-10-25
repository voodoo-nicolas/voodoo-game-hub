// NATURALIST: invented "voodoo creatures" — classification, no trivia. Ported 1:1 from the prototype.
// Creature = 7 ints. Ternary features: 0 body, 1 color, 2 pattern, 3 legs, 4 eyes; binary: 5 antennae, 6 tail.
import { defGen, type GenDef, GENS, type Lang, mkItem, say } from "./registry.ts";
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

/* ---- words for `why` (client voodoo_iq_art.gd creature(): body round / tall / wide,
   pattern none / spots / stripes, 2 / 4 / 6 legs, 1 / 2 / 3 eyes). Colours are never named:
   colour-blind mode draws other colours. ---- */
const TRAIT: Record<Lang, string[]> = {
  en: ["body shape", "colour", "pattern", "number of legs", "number of eyes", "antennae", "tail"],
  es: ["forma del cuerpo", "color", "dibujo", "cantidad de patas", "cantidad de ojos", "antenas", "cola"],
};
export const traitName = (f: number, lang: Lang) => TRAIT[lang][f];
/** "a round body", "spots", "4 legs"... (colour: "this colour") */
export function traitValue(f: number, v: number, lang: Lang): string {
  const en = [["a round body", "a tall body", "a wide body"], ["this colour", "this colour", "this colour"], ["no pattern", "spots", "stripes"],
    ["2 legs", "4 legs", "6 legs"], ["1 eye", "2 eyes", "3 eyes"], ["no antennae", "antennae"], ["no tail", "a tail"]];
  // ES reads after "con" / "tienen": "el cuerpo liso", not "ningún dibujo"
  const es = [["el cuerpo redondo", "el cuerpo alto", "el cuerpo ancho"], ["ese color", "ese color", "ese color"], ["el cuerpo liso", "manchas", "rayas"],
    ["2 patas", "4 patas", "6 patas"], ["1 ojo", "2 ojos", "3 ojos"], ["la cabeza sin antenas", "antenas"], ["el cuerpo sin cola", "cola"]];
  return (lang === "es" ? es : en)[f][v];
}
/** A two-trait rule in words (p = sum, m = difference, both counted round in threes). */
function pairRule(k: string, lang: Lang): string {
  const f = Number(k[1]), g = Number(k[2]);
  // the scores: 0, 1, 2 in the order traitValue lists them (colours unnamed: colour-blind mode)
  const legend = (t: number) => t === 1 ? say(lang, "the three colours score 0, 1, 2", "los tres colores valen 0, 1, 2")
    : [0, 1, 2].map((v) => `${traitValue(t, v, lang)} = ${v}`).join(", ");
  const scores = `(${legend(f)}; ${legend(g)})`;
  return k[0] === "p"
    ? say(lang, `a mix of ${TRAIT.en[f]} and ${TRAIT.en[g]}: score each one ${scores}, add the two scores and count round in threes (3 is 0 again)`,
      `una mezcla de ${TRAIT.es[f]} y ${TRAIT.es[g]}: puntuá cada uno ${scores}, sumá los dos y contá de a tres (3 vuelve a ser 0)`)
    : say(lang, `a mix of ${TRAIT.en[f]} and ${TRAIT.en[g]}: score each one ${scores}, take the second score from the first and count round in threes (−1 is 2)`,
      `una mezcla de ${TRAIT.es[f]} y ${TRAIT.es[g]}: puntuá cada uno ${scores}, restá el segundo puntaje del primero y contá de a tres (−1 es 2)`);
}

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
      const L = "ABC"[ans], f = Number(ruleKey[1]);
      const why = ruleKey[0] === "s"
        ? (f === 1
          ? say(ctx.lang, `The families are sorted by colour: every creature in a family has the same colour, and the new creature has the colour of family ${L}. Nothing else sorts them.`, `Las familias se separan por color: todas las criaturas de una familia tienen el mismo color, y la nueva tiene el color de la familia ${L}. Ninguna otra cosa las separa.`)
          : say(ctx.lang, `The families are sorted by ${TRAIT.en[f]}: in family ${L} every creature has ${traitValue(f, q[f], "en")}, and so does the new creature. Nothing else sorts them.`, `Las familias se separan por ${TRAIT.es[f]}: en la familia ${L} todas las criaturas tienen ${traitValue(f, q[f], "es")}, y la nueva también. Ninguna otra cosa las separa.`))
        : say(ctx.lang, `No single trait sorts the families. The rule is ${pairRule(ruleKey, "en")}. Every creature in a family gets the same result, and the new creature gets family ${L}'s.`, `Ningún rasgo solo separa las familias. La regla es ${pairRule(ruleKey, "es")}. Todas las criaturas de una familia dan el mismo resultado, y la nueva da el de la familia ${L}.`);
      return mkItem(this, d, { display: { families: ex, query: q }, key: { t: "idx", v: ans }, why });
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
/** Why creature `pos` is the odd one: the one candidate rule that singles it out. */
function natOddWhy(all: Creature[], pos: number, lang: Lang): string {
  for (const c of NAT_CANDS) {
    const v = all.map(c.f);
    if (v.filter((x, i) => i !== pos && x === v[(pos + 1) % 5]).length !== 4 || v[pos] === v[(pos + 1) % 5]) continue;
    if (c.k[0] === "s") {
      const f = Number(c.k[1]);
      if (f === 1) return say(lang, `It is the only one with a different colour; the other four share theirs.`, `Es la única de otro color; las otras cuatro comparten el suyo.`);
      return say(lang, `It is the only one with ${traitValue(f, all[pos][f], "en")}; the other four all have ${traitValue(f, all[(pos + 1) % 5][f], "en")}. Every other trait is shared by at least two.`,
        `Es la única con ${traitValue(f, all[pos][f], "es")}; las otras cuatro tienen ${traitValue(f, all[(pos + 1) % 5][f], "es")}. Todos los demás rasgos los comparten al menos dos.`);
    }
    return say(lang, `No single trait gives it away. The rule is ${pairRule(c.k, "en")}: the other four all get the same result, and this one doesn't.`, `Ningún rasgo solo la delata. La regla es ${pairRule(c.k, "es")}: las otras cuatro dan el mismo resultado y esta no.`);
  }
  return say(lang, "It is the only one that breaks the pattern the other four share.", "Es la única que rompe el patrón que comparten las otras cuatro.");
}

export function natOddItem(g: GenDef, d: number, r: Rng, lang: Lang = "en") {
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
    return mkItem(g, d, { display: { creatures: all }, key: { t: "idx", v: pos }, why: natOddWhy(all, pos, lang) });
  }
  return null;
}
defGen({ id: "natodd", sec: "NAT", a: 1.3, k: 5, minMs: 1200, maxMs: 45000, make(d, r, ctx) { return natOddItem(this, d, r, ctx.lang) || natOddItem(this, Math.max(1, d - 2), r, ctx.lang) || natOddItem(this, 1, r, ctx.lang); } });
defGen({ id: "natquick", sec: "NAT", a: 1.1, k: 5, minMs: 600, maxMs: 20000, w: 3, make(_d, r, ctx) { return natOddItem(this, r.int(1, 3), r, ctx.lang) || natOddItem(this, 1, r, ctx.lang); } });
