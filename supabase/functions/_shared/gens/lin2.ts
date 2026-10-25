// LINGUISTIC, second set (2026-10-25; NOT in the prototype): remote (missing link),
// synonym (same meaning / opposite), cloze (finish the sentence), unscramble, proverb,
// inference (read between the lines). Hand-written banks in lin2_data.ts; served only to
// clients that send gv >= 3 (engine.ts secGens).
import { type Ctx, defGen, type GenDef, mkItem, say } from "./registry.ts";
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
function mc(g: GenDef, d: number, r: Rng, ans: string, wrong: string[], display: Record<string, unknown>, why?: string) {
  const options = r.shuffle([ans, ...wrong]);
  return mkItem(g, d, { display: { ...display, options }, key: { t: "idx", v: options.indexOf(ans) }, meta: { ans }, why });
}

defGen({
  id: "remote", sec: "LIN", a: 1.4, k: 4, minMs: 1500, maxMs: 60000,
  make(d, r, ctx) {
    const [a, b, c, ans, wrong] = pickFrom(this, RAT, d, r, ctx);
    const why = say(ctx.lang, `“${ans}” goes with all three: ${a}, ${b} and ${c} each make a word or phrase with it. Each wrong option fits only one or two of them.`, `“${ans}” va con las tres: ${a}, ${b} y ${c} forman una palabra o expresión con ella. Cada opción incorrecta va solo con una o dos.`);
    return mc(this, d, r, ans, wrong, { words: r.shuffle([a, b, c]) }, why);
  },
});
defGen({
  id: "synonym", sec: "LIN", a: 1.3, k: 4, minMs: 1000, maxMs: 40000,
  make(d, r, ctx) {
    const [w, ans, wrong, kind] = pickFrom(this, SYN, d, r, ctx);
    const why = kind === "same"
      ? say(ctx.lang, `“${ans}” means the same as “${w}”. The others are related words with a different meaning.`, `“${ans}” significa lo mismo que “${w}”. Las otras son palabras relacionadas con otro significado.`)
      : say(ctx.lang, `“${ans}” means the opposite of “${w}”. The others are related words, not opposites.`, `“${ans}” significa lo contrario de “${w}”. Las otras son palabras relacionadas, no opuestas.`);
    return mc(this, d, r, ans, wrong, { word: w, kind }, why);
  },
});
defGen({
  id: "cloze", sec: "LIN", a: 1.3, k: 4, minMs: 1500, maxMs: 50000,
  make(d, r, ctx) {
    const [s, ans, wrong] = pickFrom(this, CLOZE, d, r, ctx);
    const why = say(ctx.lang, `“${s.replace("___", ans)}” Only “${ans}” fits both the meaning and the grammar; read the sentence again with each of the others.`, `“${s.replace("___", ans)}” Solo “${ans}” encaja con el sentido y con la gramática; leé la oración con cada una de las otras.`);
    return mc(this, d, r, ans, wrong, { sentence: s }, why);
  },
});
defGen({
  id: "proverb", sec: "LIN", a: 1.2, k: 4, minMs: 2000, maxMs: 60000,
  make(d, r, ctx) {
    const [s, ans, wrong] = pickFrom(this, PROVERB, d, r, ctx);
    const why = say(ctx.lang, `“${s}” means: ${ans} The other options take the words too literally or miss the point.`, `“${s}” significa: ${ans} Las otras opciones toman las palabras al pie de la letra o no captan la idea.`);
    return mc(this, d, r, ans, wrong, { saying: s }, why);
  },
});
defGen({
  id: "inference", sec: "LIN", a: 1.4, k: 4, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const [p, q, ans, wrong] = pickFrom(this, INFER, d, r, ctx);
    const why = say(ctx.lang, `“${ans}” follows from what the text says, with nothing added. The others might be true, but the text doesn't tell us, or it says otherwise.`, `“${ans}” se deduce de lo que dice el texto, sin agregar nada. Las otras podrían ser ciertas, pero el texto no lo dice, o dice lo contrario.`);
    return mc(this, d, r, ans, wrong, { passage: p, q }, why);
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
    const why = say(ctx.lang, `The sentence is: “${s}” ${alts.length ? `Also right: “${alts.join("”, “")}” ` : ""}The capital letter shows the first word and the full stop the last.`, `La oración es: “${s}” ${alts.length ? `También vale: “${alts.join("”, “")}” ` : ""}La mayúscula marca la primera palabra y el punto, la última.`);
    return mkItem(this, d, { display: { tiles }, key: { t: "any", v: [s, ...alts] }, why });
  },
});
