// EXISTENTIAL: reasoning about big questions (logic, not beliefs). Ported 1:1 from the prototype.
// deno-lint-ignore-file no-explicit-any
import { defGen, type GenDef, type Lang, mkItem, say } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { FALLACIES, FALLACY_NAMES, SY_TERMS } from "./data.ts";

/** Option text the client replaces with its own "None of these must be true" (none_follows). */
export const NONE_FOLLOWS = "__none__";

/* Categorical syllogisms verified by brute force over all Venn models.
   Only conclusions that are correct under BOTH modern and traditional (existential import)
   logic are ever shown, so no answer is debatable. */
export type Prop = [string, number, number]; // [form A|E|I|O, subject term bit, predicate term bit]
export function syTrue(form: string, X: number, Y: number, M: number[]) {
  if (form === "A") return M.every((r) => !(r & X) || (r & Y));
  if (form === "E") return !M.some((r) => (r & X) && (r & Y));
  if (form === "I") return M.some((r) => (r & X) && (r & Y));
  return M.some((r) => (r & X) && !(r & Y));
}
export interface SyForm { p1: Prop; p2: Prop; valid: Prop[]; invalid: Prop[]; d: number }
export const SY_POOL: SyForm[] = (() => {
  const A = 1, B = 2, C = 4, forms = ["A", "E", "I", "O"];
  const models: number[][] = [];
  for (let m = 0; m < 128; m++) { const M: number[] = []; for (let r = 1; r < 8; r++) if (m >> (r - 1) & 1) M.push(r); models.push(M); }
  const nonEmpty = (M: number[]) => [A, B, C].every((t) => M.some((r) => r & t));
  const concl: Prop[] = [];
  for (const f of forms) { concl.push([f, A, C]); concl.push([f, C, A]); }
  const pool: SyForm[] = [];
  for (const f1 of forms) for (const f2 of forms) for (const o1 of [0, 1]) for (const o2 of [0, 1]) {
    const p1: Prop = o1 ? [f1, B, A] : [f1, A, B], p2: Prop = o2 ? [f2, C, B] : [f2, B, C];
    const sat = models.filter((M) => syTrue(...p1, M) && syTrue(...p2, M));
    const satI = sat.filter(nonEmpty);
    const valid: Prop[] = [], validI: Prop[] = [], invalid: Prop[] = [];
    for (const c of concl) { const vm = sat.every((M) => syTrue(...c, M)); const vi = satI.every((M) => syTrue(...c, M)); if (vm) valid.push(c); if (vi) validI.push(c); if (!vi) invalid.push(c); }
    let d: number;
    if (valid.some((c) => c[0] === "A")) d = 2; else if (valid.some((c) => c[0] === "E")) d = 4; else if (valid.some((c) => c[0] === "I")) d = 5; else if (valid.length) d = 8;
    else { const part = [f1, f2].filter((f) => f === "I" || f === "O").length; d = part === 2 ? 6 : validI.length ? 9 : 7 + (f1 === "A" || f2 === "A" ? 1 : 0); }
    if (o1 && o2) d = Math.min(10, d + 1);
    pool.push({ p1, p2, valid, invalid, d });
  }
  return pool;
})();
export function syText(lang: Lang, [f, X, Y]: Prop, names: Record<number, any>) {
  const x = names[X], y = names[Y];
  if (lang === "en") return f === "A" ? `All ${x} are ${y}.` : f === "E" ? `No ${x} are ${y}.` : f === "I" ? `Some ${x} are ${y}.` : `Some ${x} are not ${y}.`;
  const [xs, xp, xg] = x, [ys, yp] = y;
  const fem = xg === "f";
  if (f === "A") return `${fem ? "Todas las" : "Todos los"} ${xp} son ${yp}.`;
  if (f === "E") return `${fem ? "Ninguna" : "Ningún"} ${xs} es ${ys}.`;
  if (f === "I") return `${fem ? "Algunas" : "Algunos"} ${xp} son ${yp}.`;
  return `${fem ? "Algunas" : "Algunos"} ${xp} no son ${yp}.`;
}
function syllogismItem(g: GenDef, d: number, r: Rng, lang: Lang) {
  let best = SY_POOL.filter((p) => p.d === d);
  for (let w = 1; !best.length && w < 10; w++) best = SY_POOL.filter((p) => Math.abs(p.d - d) <= w);
  const it = r.pick(best);
  const T = r.shuffle((SY_TERMS as any)[lang]).slice(0, 3);
  const names = { 1: T[0], 2: T[1], 4: T[2] };
  const atmos = (c: Prop) => {
    const neg = [it.p1[0], it.p2[0]].some((f) => f === "E" || f === "O"), part = [it.p1[0], it.p2[0]].some((f) => f === "I" || f === "O");
    const want = part ? (neg ? "O" : "I") : (neg ? "E" : "A");
    return c[0] === want ? 0 : 1;
  };
  const inv = r.shuffle(it.invalid).sort((a, b) => atmos(a) - atmos(b));
  let list: Prop[], ansIdx: number;
  if (it.valid.length) { const ans = r.pick(it.valid); list = r.shuffle([ans, ...inv.slice(0, 3)]); ansIdx = list.indexOf(ans); }
  else { list = r.shuffle(inv.slice(0, 4)); ansIdx = -1; }
  const opts: string[] = list.map((c) => syText(lang, c, names));
  opts.push(NONE_FOLLOWS);
  const none = ansIdx < 0;
  if (ansIdx < 0) ansIdx = opts.length - 1;
  const pr = [syText(lang, it.p1, names), syText(lang, it.p2, names)];
  const why = none
    ? say(lang, `Draw each group as a circle. Both “${pr[0]}” and “${pr[1]}” can be drawn in more than one way, and each option is false in at least one of those drawings. So none of them has to be true.`,
      `Dibujá cada grupo como un círculo. “${pr[0]}” y “${pr[1]}” se pueden dibujar de más de una manera, y cada opción es falsa en al menos uno de esos dibujos. Así que ninguna tiene que ser verdad.`)
    : say(lang, `Draw each group as a circle. However you draw “${pr[0]}” and “${pr[1]}”, “${opts[ansIdx]}” is always true. Each other option is false in at least one drawing that fits both statements.`,
      `Dibujá cada grupo como un círculo. Como sea que dibujes “${pr[0]}” y “${pr[1]}”, “${opts[ansIdx]}” siempre es verdad. Cada una de las otras es falsa en al menos un dibujo que cumple las dos frases.`);
  return mkItem(g, it.d, {
    lang, k: opts.length,
    display: { premises: [syText(lang, it.p1, names), syText(lang, it.p2, names)], options: opts },
    key: { t: "idx", v: ansIdx },
    meta: { p1: it.p1, p2: it.p2, props: [...list, null] },
    why,
  });
}
defGen({ id: "syll", sec: "EXI", a: 1.4, k: 5, minMs: 2500, maxMs: 70000, make(d, r, ctx) { return syllogismItem(this, d, r, ctx.lang); } });
defGen({ id: "syllquick", sec: "EXI", a: 1.1, k: 5, minMs: 1200, maxMs: 30000, w: 4, make(_d, r, ctx) { return syllogismItem(this, r.pick([2, 2, 4]), r, ctx.lang); } });

/* Fallacies in arguments about life, meaning, belief, evidence. Options are fallacy keys
   (the client shows fal_<key> text). */
const FALLACIES_: [number, string, string, string][] = FALLACIES as any;
/** What each mistake in reasoning does, for `why`. */
const FALLACY_WHY: Record<string, [string, string]> = {
  adhom: ["It attacks the person instead of their argument: failing a class says nothing about whether her idea is right.", "Ataca a la persona en vez de a su argumento: haber reprobado una materia no dice nada sobre si su idea es correcta."],
  dilemma: ["It offers only two choices when many others exist (for example, purposes people choose for themselves).", "Ofrece solo dos opciones cuando hay muchas más (por ejemplo, propósitos que cada uno elige)."],
  slope: ["It claims one small step will lead to a disaster, without showing why each step must follow.", "Dice que un paso chico va a llevar a un desastre, sin mostrar por qué cada paso tiene que seguir al anterior."],
  circular: ["It uses the thing it wants to prove as its own proof: the book is trusted because the book says so.", "Usa lo que quiere probar como su propia prueba: se le cree al libro porque el libro lo dice."],
  posthoc: ["It assumes that because one thing came after another, the first caused it.", "Supone que, como una cosa vino después de otra, la primera la causó."],
  hasty: ["It draws a general rule from far too few cases.", "Saca una regla general de muy pocos casos."],
  bandwagon: ["It says something is true because many people believe it; popularity isn't evidence.", "Dice que algo es verdad porque mucha gente lo cree; que sea popular no es una prueba."],
  nature: ["It assumes that whatever is natural must be good.", "Supone que todo lo natural tiene que ser bueno."],
  straw: ["It twists the person's view into a more extreme one that is easier to attack.", "Deforma lo que piensa la persona en algo más extremo, más fácil de atacar."],
  authority: ["It trusts someone famous on a topic they are not an expert in.", "Le cree a alguien famoso sobre un tema del que no es experto."],
  tradition: ["It says something is true because people have always believed it.", "Dice que algo es verdad porque la gente siempre lo creyó."],
  ignorance: ["It treats a lack of proof against something as proof for it.", "Toma la falta de pruebas en contra como si fuera una prueba a favor."],
  composition: ["It assumes the whole must have the same property as each of its parts.", "Supone que el todo tiene que tener la misma propiedad que cada una de sus partes."],
  tuquoque: ["It dismisses the claim because the person doesn't follow it themselves; that doesn't make the claim wrong.", "Descarta la idea porque la persona no la cumple; eso no la hace falsa."],
  consequent: ["“If wise, then calm” doesn't mean “if calm, then wise”: people can be calm for other reasons.", "“Si es sabio, está tranquilo” no significa “si está tranquilo, es sabio”: se puede estar tranquilo por otras razones."],
  quantifier: ["“Everyone has someone who loves them” doesn't mean one single person loves everyone: the order of “every” and “some” was swapped.", "“Todos tienen a alguien que los ama” no significa que una sola persona ame a todos: se invirtió el orden de “todos” y “alguien”."],
  equivocation: ["It uses “end” in two senses: the goal of something and where it stops.", "Usa “fin” con dos sentidos: el objetivo de algo y el lugar donde termina."],
};
defGen({
  id: "fallacy", sec: "EXI", a: 1.3, k: 4, minMs: 2500, maxMs: 60000,
  make(d, r, ctx) {
    const used = ctx.used || new Set();
    let best: [number, [number, string, string, string]] | null = null, bd = 99;
    for (const [i, f] of r.shuffle(FALLACIES_.map((x, i) => [i, x] as [number, [number, string, string, string]]))) {
      if (used.has("fa" + i)) continue;
      const dd = Math.abs(f[0] - d);
      if (dd < bd) { bd = dd; best = [i, f]; }
    }
    if (!best) best = [0, FALLACIES_[0]];
    used.add("fa" + best[0]);
    const [dd, key, en, es] = best[1];
    const opts = r.shuffle([key, ...r.shuffle(FALLACY_NAMES.filter((n) => n !== key && !(key === "adhom" && n === "tuquoque") && !(key === "tuquoque" && n === "adhom"))).slice(0, 3)]);
    const ansIdx = opts.indexOf(key);
    const fw = FALLACY_WHY[key];
    return mkItem(this, dd, { lang: ctx.lang, display: { argument: ctx.lang === "es" ? es : en, options: opts }, key: { t: "idx", v: ansIdx }, why: fw ? say(ctx.lang, fw[0], fw[1]) : undefined });
  },
});
