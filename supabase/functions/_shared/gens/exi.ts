// EXISTENTIAL: reasoning about big questions (logic, not beliefs). Ported 1:1 from the prototype.
// deno-lint-ignore-file no-explicit-any
import { defGen, type GenDef, type Lang, mkItem } from "./registry.ts";
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
  if (ansIdx < 0) ansIdx = opts.length - 1;
  return mkItem(g, it.d, {
    lang, k: opts.length,
    display: { premises: [syText(lang, it.p1, names), syText(lang, it.p2, names)], options: opts },
    key: { t: "idx", v: ansIdx },
    meta: { p1: it.p1, p2: it.p2, props: [...list, null] },
  });
}
defGen({ id: "syll", sec: "EXI", a: 1.4, k: 5, minMs: 2500, maxMs: 70000, make(d, r, ctx) { return syllogismItem(this, d, r, ctx.lang); } });
defGen({ id: "syllquick", sec: "EXI", a: 1.1, k: 5, minMs: 1200, maxMs: 30000, w: 4, make(_d, r, ctx) { return syllogismItem(this, r.pick([2, 2, 4]), r, ctx.lang); } });

/* Fallacies in arguments about life, meaning, belief, evidence. Options are fallacy keys
   (the client shows fal_<key> text). */
const FALLACIES_: [number, string, string, string][] = FALLACIES as any;
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
    return mkItem(this, dd, { lang: ctx.lang, display: { argument: ctx.lang === "es" ? es : en, options: opts }, key: { t: "idx", v: ansIdx } });
  },
});
