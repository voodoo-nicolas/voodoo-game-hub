// LOGICAL-MATHEMATICAL, second set (2026-10-25; NOT in the prototype): symsum, scales,
// ordering, letters, funcmachine, operators, fraccmp, wordprob, dice, sudoku.
// Served only to clients that send gv >= 1 (engine.ts secGens), so older packs, which
// can't draw them, never get one. Text the item shows is built here in the player's
// language (display.*), like analogy / fallacy.
import { defGen, type Lang, mkItem } from "./registry.ts";
import type { Rng } from "../rng.ts";

export type Op = "+" | "−" | "×" | "÷";

/** a op b op c ... with × and ÷ before + and −, left to right. */
export function evalOps(nums: number[], ops: Op[]): number {
  const vals = [nums[0]];
  const add: Op[] = [];
  ops.forEach((o, i) => {
    const x = nums[i + 1];
    if (o === "×") vals[vals.length - 1] *= x;
    else if (o === "÷") vals[vals.length - 1] /= x;
    else { add.push(o); vals.push(x); }
  });
  let r = vals[0];
  add.forEach((o, i) => { r = o === "+" ? r + vals[i + 1] : r - vals[i + 1]; });
  return r;
}

/** distinct wrong answers from `pool` (in order, positive, != ans), padded with ans±k */
function wrongs(ans: number, pool: number[], n: number): number[] {
  const out: number[] = [];
  for (const x of pool) if (x > 0 && x !== ans && Number.isInteger(x) && !out.includes(x) && out.length < n) out.push(x);
  for (let k = 1; out.length < n; k++) for (const x of [ans + k, ans - k]) if (x > 0 && !out.includes(x) && out.length < n) out.push(x);
  return out;
}
function withAnswer<T>(r: Rng, ans: T, wrong: T[]) {
  const options = r.shuffle([ans, ...wrong]);
  return { options, ansIdx: options.indexOf(ans) };
}

/* ---------------- symsum: hidden-value equations (typed) ----------------
   Symbols 0..3 are drawn shapes. Each recipe is solvable one equation at a time. */
type Term = (number | Op)[];
const SYM_RECIPES: [Term[], number][] = [
  [[[0, "+", 0], [0, "+", 1]], 1],
  [[[0, "+", 0, "+", 0], [1, "+", 0]], 1],
  [[[0, "+", 1], [0, "+", 0]], 1],
  [[[0, "+", 0], [0, "+", 1], [1, "+", 2]], 2],
  [[[0, "×", 0], [0, "×", 1]], 1],
  [[[0, "+", 1, "+", 1], [1, "+", 1]], 0],
  [[[1, "×", 2], [0, "+", 0], [0, "+", 1]], 2],
  [[[0, "+", 0], [0, "+", 1], [1, "+", 2], [2, "−", 3]], 3],
  [[[0, "+", 1], [1, "+", 2], [0, "+", 2]], 0],
  [[[0, "+", 1, "+", 2], [0, "×", 1], [1, "+", 1]], 2],
];
export function termValue(t: Term, v: number[]): number {
  const nums: number[] = [], ops: Op[] = [];
  t.forEach((x, i) => (i % 2 ? ops.push(x as Op) : nums.push(v[x as number])));
  return evalOps(nums, ops);
}
defGen({
  id: "symsum", sec: "LOG", a: 1.5, k: 0, minMs: 2500, maxMs: 70000,
  make(d, r) {
    const [terms, ask] = SYM_RECIPES[d - 1];
    const v = [0, 1, 2, 3].map(() => r.int(2, 9));
    if (d === 8) v[3] = r.int(1, v[2] - 1);
    const shape = r.shuffle([0, 1, 2, 3]);
    let eqs = terms.map((t) => ({ t: t.map((x, i) => (i % 2 ? x : shape[x as number])), r: termValue(t, v) }));
    if (d >= 6) eqs = r.shuffle(eqs);
    const byShape: number[] = [];
    shape.forEach((s, i) => { byShape[s] = v[i]; });
    return mkItem(this, d, { display: { eqs, ask: shape[ask] }, key: { t: "num", v: v[ask] }, meta: { v: byShape } });
  },
});

/* ---------------- scales: balance puzzles (4 options) ----------------
   Shapes on each pan weigh the same. Ask: how many `unit` balance n of `sym`. */
const gcd = (a: number, b: number): number => (b ? gcd(b, a % b) : a);
defGen({
  id: "scales", sec: "LOG", a: 1.4, k: 4, minMs: 3000, maxMs: 80000,
  make(d, r) {
    const S = r.shuffle([0, 1, 2, 3]);
    const rep = (s: number, n: number) => Array(n).fill(s);
    let scales: { l: number[]; r: number[] }[], n: number, ans: number, unit: number, naive: number;
    if (d <= 3) {
      const k = r.int(2, 3), m = r.int(2, 3);
      n = d === 1 ? 1 : r.int(2, 3);
      scales = [{ l: [S[0]], r: rep(S[1], k) }, { l: [S[1]], r: rep(S[2], m) }];
      ans = n * k * m; unit = S[2]; naive = n * k;
    } else if (d <= 6) {
      const pA = r.int(2, 3);
      const pB = r.pick([2, 3, 4].filter((x) => x > pA - 1 && x !== pA && gcd(x, pA) === 1));
      n = r.int(2, d === 6 ? 4 : 3);
      // weights: B = pA (in C), A = pB
      scales = [{ l: rep(S[0], pA), r: rep(S[1], pB) }, { l: [S[1]], r: rep(S[2], pA) }];
      ans = n * pB; unit = S[2]; naive = n * pA;
    } else if (d <= 8) {
      const u = r.int(2, 3), q = r.int(2, 3), wB = q * u;
      const pA = r.pick([2, 3].filter((x) => wB % x === 0));
      const pB = r.pick([1, 2, 3, 4].filter((x) => x !== pA && gcd(x, pA) === 1));
      const wA = pB * wB / pA;
      n = r.int(1, 3);
      scales = [{ l: rep(S[0], pA), r: rep(S[1], pB) }, { l: [S[1]], r: rep(S[2], q) }, { l: [S[2]], r: rep(S[3], u) }];
      ans = n * wA; unit = S[3]; naive = n * pB * q;
    } else {
      const m = r.int(2, 4), j = r.int(1, 3);
      n = r.int(2, 3);
      scales = [{ l: [S[0]], r: [S[1], ...rep(S[2], j)] }, { l: [S[1]], r: rep(S[2], m) }];
      ans = n * (m + j); unit = S[2]; naive = n * m;
    }
    if (d >= 5) scales = r.shuffle(scales.map((s) => (r.chance(.5) ? { l: s.r, r: s.l } : s)));
    const { options, ansIdx } = withAnswer(r, ans, wrongs(ans, [naive, ans + n, ans - n, ans * 2], 3));
    return mkItem(this, d, { display: { scales, n, sym: S[0], unit, options }, key: { t: "idx", v: ansIdx }, meta: { ans } });
  },
});

/* ---------------- ordering: who is k-th oldest (k = number of people options) ---------------- */
const NAMES: Record<Lang, string[]> = { en: ["Ana", "Ben", "Cleo", "Dev", "Eli", "Fay"], es: ["Ana", "Beto", "Clara", "Dani", "Eva", "Fran"] };
const ORD_TXT = {
  en: {
    older: "{a} is older than {b}.", younger: "{a} is younger than {b}.", notolder: "{a} is not older than {b}.",
    same: "No two of them are the same age.",
    q: ["", "Who is the {o}oldest?", "Who is the {o}youngest?"], ord: ["", "", "second ", "third "],
  },
  es: {
    older: "{a} es mayor que {b}.", younger: "{a} es menor que {b}.", notolder: "{a} no es mayor que {b}.",
    same: "No hay dos con la misma edad.",
    q: ["", "¿Quién es la {o}persona de más edad?", "¿Quién es la {o}persona más joven?"], ord: ["", "", "segunda ", "tercera "],
  },
};
defGen({
  id: "ordering", sec: "LOG", a: 1.4, k: 4, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const T = ORD_TXT[ctx.lang];
    const k = d <= 3 ? 3 : d <= 6 ? 4 : 5;
    const names = NAMES[ctx.lang].slice(0, k);
    const order = r.shuffle(names); // oldest first
    const facts: [string, string][] = []; // [older, younger]
    for (let i = 0; i < k - 1; i++) facts.push([order[i], order[i + 1]]);
    if (d >= 9) { const i = r.int(0, k - 3); facts.push([order[i], order[i + 2]]); }
    const text = r.shuffle(facts).map(([o, y]) => {
      const form = d >= 7 ? r.pick(["older", "younger", "notolder"]) : d >= 2 ? r.pick(["older", "younger"]) : "older";
      if (form === "older") return T.older.replace("{a}", o).replace("{b}", y);
      if (form === "younger") return T.younger.replace("{a}", y).replace("{b}", o);
      return T.notolder.replace("{a}", y).replace("{b}", o);
    });
    const pos = d <= 3 ? 1 : d <= 6 ? 2 : r.int(2, 3);
    const young = d >= 3 && r.chance(.5);
    const who = young ? order[k - pos] : order[pos - 1];
    const q = T.q[young ? 2 : 1].replace("{o}", T.ord[pos]);
    const ansIdx = names.indexOf(who);
    return mkItem(this, d, { k, display: { facts: text, note: T.same, q, options: names }, key: { t: "idx", v: ansIdx }, meta: { facts, pos, young } });
  },
});

/* ---------------- letters: letter / letter-number series (4 options) ---------------- */
const L = (n: number) => String.fromCharCode(64 + n);
defGen({
  id: "letters", sec: "LOG", a: 1.4, k: 4, minMs: 2000, maxMs: 60000,
  make(d, r) {
    let seq: number[] = [], pairs: number[] | null = null, ans: number;
    const grow = (x0: number, gaps: number[]) => gaps.reduce((s, g) => (s.push(s[s.length - 1] + g), s), [x0]);
    switch (d) {
      case 1: { const s = r.int(1, 2); seq = grow(r.int(1, 26 - 5 * s), [s, s, s, s, s]); break; }
      case 2: { const s = r.int(1, 3); seq = grow(r.int(1 + 5 * s, 26), [-s, -s, -s, -s, -s]); break; }
      case 3: { const s = r.int(3, 4); seq = grow(r.int(1, 26 - 5 * s), [s, s, s, s, s]); break; }
      case 4: seq = grow(r.int(1, 11), [1, 2, 3, 4, 5]); break;
      case 5: { const a = r.int(1, 2), b = a + r.int(1, 2); seq = grow(r.int(1, 26 - 3 * a - 3 * b), [a, b, a, b, a, b]); break; }
      case 6: { const a = r.int(1, 3), b = r.int(1, 3), s1 = r.int(1, 26 - 3 * a), s2 = r.int(1 + 3 * b, 26);
        seq = Array.from({ length: 7 }, (_, i) => (i % 2 ? s2 - ((i - 1) / 2) * b : s1 + (i / 2) * a)); break; }
      case 7: { const a = r.int(2, 4), b = r.int(2, 5), s = r.int(1, 26 - 4 * a), m = r.int(1, 9);
        seq = Array.from({ length: 5 }, (_, i) => s + i * a); pairs = Array.from({ length: 5 }, (_, i) => m + i * b); break; }
      case 8: seq = grow(r.int(16, 26), [-1, -2, -3, -4, -5]); break;
      case 9: seq = grow(r.int(1, 11), [1, 2, 4, 8]); break;
      default: { const s1 = r.int(1, 6), s2 = r.int(16, 26), b = r.int(1, 2);
        seq = Array.from({ length: 7 }, (_, i) => (i % 2 ? s2 - ((i - 1) / 2) * b : s1 + [0, 1, 3, 6][i / 2])); }
    }
    ans = seq.pop()!;
    let ansStr: string, wrong: string[];
    if (pairs) {
      const an = pairs.pop()!;
      ansStr = L(ans) + an;
      const cand = [L(ans) + (an + 1), L(ans + 1) + an, L(ans - 1) + an, L(ans) + (an - 1), L(ans + 2) + an];
      wrong = [...new Set(cand.filter((c) => c !== ansStr && /^[A-Z]\d+$/.test(c)))].slice(0, 3);
    } else {
      ansStr = L(ans);
      wrong = [ans + 1, ans - 1, ans + 2, ans - 2, ans + 3, ans - 3].filter((x) => x >= 1 && x <= 26).slice(0, 3).map(L);
    }
    const { options, ansIdx } = withAnswer(r, ansStr, wrong);
    const shown = seq.map((x, i) => L(x) + (pairs ? pairs[i] : ""));
    return mkItem(this, d, { display: { seq: shown, options }, key: { t: "idx", v: ansIdx }, meta: { ans: ansStr } });
  },
});

/* ---------------- funcmachine: find the rule (typed) ----------------
   Every rule is a polynomial of degree <= 2; the test interpolates. */
const RULES: ((r: Rng) => { f: (x: number) => number; n: number; lo: number })[] = [
  (r) => { const b = r.int(2, 9); return { f: (x) => x + b, n: 3, lo: 1 }; },
  (r) => { const a = r.int(2, 5); return { f: (x) => a * x, n: 3, lo: 1 }; },
  (r) => { const a = r.int(2, 4), b = r.int(1, 7); return { f: (x) => a * x + b, n: 3, lo: 1 }; },
  (r) => { const a = r.int(2, 5), b = r.int(1, a - 1); return { f: (x) => a * x - b, n: 3, lo: 1 }; },
  () => ({ f: (x) => x * x, n: 3, lo: 1 }),
  (r) => { const b = r.int(1, 9); return { f: (x) => x * x + b, n: 3, lo: 1 }; },
  (r) => { const a = r.int(2, 3), b = r.int(1, 4); return { f: (x) => (x + b) * a, n: 3, lo: 1 }; },
  () => ({ f: (x) => x * (x + 1), n: 4, lo: 1 }),
  (r) => { const b = r.int(1, 3); return { f: (x) => x * x - b * x, n: 4, lo: b + 1 }; },
  (r) => { const a = r.int(2, 3), b = r.int(1, 5); return { f: (x) => a * x * x + b, n: 4, lo: 1 }; },
];
defGen({
  id: "funcmachine", sec: "LOG", a: 1.5, k: 0, minMs: 2500, maxMs: 70000,
  make(d, r) {
    const { f, n, lo } = RULES[d - 1](r);
    const xs = r.shuffle(Array.from({ length: 10 - lo + 1 }, (_, i) => lo + i)).slice(0, n + 1);
    const ex = xs.slice(0, n).sort((a, b) => a - b).map((x) => [x, f(x)]);
    const qx = xs[n];
    return mkItem(this, d, { display: { ex, x: qx }, key: { t: "num", v: f(qx) } });
  },
});

/* ---------------- operators: fill the gaps (4 options) ---------------- */
function combos(ops: Op[], n: number): Op[][] {
  let out: Op[][] = [[]];
  for (let i = 0; i < n; i++) out = out.flatMap((c) => ops.map((o) => [...c, o]));
  return out;
}
defGen({
  id: "operators", sec: "LOG", a: 1.3, k: 4, minMs: 2000, maxMs: 60000,
  make(d, r) {
    const gaps = d <= 5 ? 2 : 3;
    const ops: Op[] = d <= 3 ? ["+", "−", "×"].slice(0, d === 1 ? 2 : 3) as Op[] : d <= 7 ? ["+", "−", "×"] : ["+", "−", "×", "÷"];
    for (let tries = 0; tries < 500; tries++) {
      const nums = Array.from({ length: gaps + 1 }, () => r.int(1, d >= 6 ? 12 : 9));
      const all = combos(ops, gaps);
      const res = all.map((c) => evalOps(nums, c));
      const good = all.map((_, i) => i).filter((i) => Number.isInteger(res[i]) && res[i] >= 0 && res.filter((x) => Math.abs(x - res[i]) < 1e-9).length === 1);
      if (good.length < 1 || all.length < 4) continue;
      const pick = r.pick(good);
      const others = r.shuffle(all.map((_, i) => i).filter((i) => i !== pick)).slice(0, 3);
      const order = r.shuffle([pick, ...others]);
      return mkItem(this, d, { display: { nums, r: res[pick], options: order.map((i) => all[i]) }, key: { t: "idx", v: order.indexOf(pick) } });
    }
    return null;
  },
});

/* ---------------- fraccmp: which is bigger (2 options) ---------------- */
interface Num { p: number; q: number; s: string } // value p/q, shown as s
function frac(p: number, q: number): Num { return { p, q, s: `${p}/${q}` }; }
function dec(p: number, q: number, lang: Lang): Num { const s = (p / q).toFixed(q === 100 ? 2 : 3).replace(/0+$/, "").replace(/\.$/, ""); return { p, q, s: lang === "es" ? s.replace(".", ",") : s }; }
function pct(p: number): Num { return { p, q: 100, s: `${p}%` }; }
defGen({
  id: "fraccmp", sec: "LOG", a: 1.1, k: 2, minMs: 800, maxMs: 30000,
  make(d, r, ctx) {
    const gap = [.3, .2, .12, .08, .05, .05, .04, .02, .02, .01][d - 1];
    for (let tries = 0; tries < 2000; tries++) {
      let a: Num, b: Num;
      const q1 = r.int(2, d >= 8 ? 20 : 12), p1 = r.int(1, q1 - 1);
      if (d === 1) { a = frac(p1, q1); b = frac(r.int(1, q1 - 1), q1); }
      else if (d === 2) { const p = r.int(1, 5); a = frac(p, r.int(p + 1, 12)); b = frac(p, r.int(p + 1, 12)); }
      else if (d === 6 || d === 9) { a = frac(p1, q1); const v = r.int(1, 999); b = dec(v, 1000, ctx.lang); }
      else if (d === 7) { a = frac(p1, q1); b = pct(r.int(1, 99)); }
      else { const q2 = r.int(2, d >= 8 ? 20 : 12); a = frac(p1, q1); b = frac(r.int(1, q2 - 1), q2); }
      const va = a.p / a.q, vb = b.p / b.q, diff = Math.abs(va - vb);
      if (a.p * b.q === b.p * a.q || a.s === b.s) continue;
      if (diff > gap * 2.5 || (d >= 3 && diff < gap / 3)) continue;
      const opts = r.chance(.5) ? [a, b] : [b, a];
      const big = opts[0].p * opts[1].q > opts[1].p * opts[0].q ? 0 : 1;
      return mkItem(this, d, { display: { options: opts.map((o) => o.s) }, key: { t: "idx", v: big } });
    }
    return null;
  },
});

/* ---------------- wordprob: word problems (typed) ---------------- */
type WP = { en: string; es: string; ans: number };
const WORD: ((r: Rng) => WP | null)[] = [
  (r) => { const a = r.int(3, 12), n = r.int(3, 9); return { en: `A box holds ${a} pencils. How many pencils are in ${n} boxes?`, es: `Una caja trae ${a} lápices. ¿Cuántos lápices hay en ${n} cajas?`, ans: a * n }; },
  (r) => { const n = r.int(2, 6), p = r.int(3, 15), m = r.pick([50, 100]); if (n * p >= m) return null; return { en: `You buy ${n} stickers at ${p} coins each and pay with ${m} coins. How many coins do you get back?`, es: `Comprás ${n} figuritas a ${p} monedas cada una y pagás con ${m} monedas. ¿Cuántas monedas te devuelven?`, ans: m - n * p }; },
  (r) => { const v = r.int(4, 12) * 10, t = r.int(2, 4), t2 = r.int(2, 6); if (t2 === t) return null; return { en: `A train travels ${v * t} km in ${t} hours. At the same speed, how many km does it travel in ${t2} hours?`, es: `Un tren recorre ${v * t} km en ${t} horas. A la misma velocidad, ¿cuántos km recorre en ${t2} horas?`, ans: v * t2 }; },
  (r) => { const p = r.int(2, 12) * 20, k = r.pick([10, 20, 25, 50]); return { en: `A jacket costs ${p} coins. In the sale it is ${k}% off. What does it cost now?`, es: `Una campera cuesta ${p} monedas. En la oferta tiene ${k}% de descuento. ¿Cuánto cuesta ahora?`, ans: p * (100 - k) / 100 }; },
  (r) => { const a = r.int(1, 4), b = r.int(a + 1, 6), u = r.int(3, 9); return { en: `Mia and Leo share ${(a + b) * u} marbles in the ratio ${a}:${b}. How many marbles does Leo get?`, es: `Mía y Leo se reparten ${(a + b) * u} bolitas en proporción ${a}:${b}. ¿Cuántas bolitas recibe Leo?`, ans: b * u }; },
  (r) => { const xs = [r.int(50, 90), r.int(50, 90), r.int(50, 90)], m = r.int(70, 85), need = 4 * m - xs[0] - xs[1] - xs[2]; if (need < 40 || need > 100) return null; return { en: `Your first three test scores are ${xs.join(", ")}. What must you score on the fourth test for an average of ${m}?`, es: `Tus tres primeras notas son ${xs.join(", ")}. ¿Cuánto tenés que sacar en la cuarta para tener un promedio de ${m}?`, ans: need }; },
  (r) => { const [a, b] = r.pick([[2, 3], [3, 6], [2, 6], [4, 12], [3, 12], [6, 12]]); return { en: `One tap fills a tank in ${a} hours; another fills it in ${b} hours. With both taps on, how many minutes does it take?`, es: `Una canilla llena un tanque en ${a} horas; otra lo llena en ${b} horas. Con las dos abiertas, ¿cuántos minutos tarda?`, ans: 60 * a * b / (a + b) }; },
  (r) => { const p = r.pick([100, 200, 400, 500]), a = r.pick([10, 20, 25, 50]), b = r.pick([10, 20, 25, 50]); const f = p * (100 + a) / 100 * (100 - b) / 100; if (!Number.isInteger(f) || a === b) return null; return { en: `A price of ${p} coins goes up ${a}%, then the new price goes down ${b}%. What is the final price?`, es: `Un precio de ${p} monedas sube un ${a}% y después el nuevo precio baja un ${b}%. ¿Cuál es el precio final?`, ans: f }; },
  (r) => { const v1 = r.int(4, 12) * 10, v2 = r.int(4, 12) * 10, t = r.pick([30, 45, 60, 90, 120]); const D = (v1 + v2) * t / 60; if (!Number.isInteger(D)) return null; return { en: `Two trains are ${D} km apart and head toward each other at ${v1} km/h and ${v2} km/h. In how many minutes do they meet?`, es: `Dos trenes están a ${D} km y van uno hacia el otro a ${v1} km/h y ${v2} km/h. ¿En cuántos minutos se cruzan?`, ans: t }; },
  (r) => { const B = r.int(3, 9), k = r.int(3, 4), n = B * (k - 2); return { en: `Sara is ${k} times as old as her brother. In ${n} years she will be twice his age. How old is her brother now?`, es: `Sara tiene ${k} veces la edad de su hermano. Dentro de ${n} años va a tener el doble de su edad. ¿Cuántos años tiene su hermano ahora?`, ans: B }; },
];
defGen({
  id: "wordprob", sec: "LOG", a: 1.4, k: 0, minMs: 3000, maxMs: 90000,
  make(d, r, ctx) {
    for (let tries = 0; tries < 200; tries++) {
      const w = WORD[d - 1](r);
      if (!w || !Number.isInteger(w.ans) || w.ans <= 0) continue;
      return mkItem(this, d, { display: { text: w[ctx.lang] }, key: { t: "num", v: w.ans }, meta: { ans: w.ans } });
    }
    return null;
  },
});

/* ---------------- dice: probability by counting (4 options) ---------------- */
const DIE = [1, 2, 3, 4, 5, 6];
function outcomes(dice: number, coins: number): number[][] {
  let o: number[][] = [[]];
  for (let i = 0; i < dice; i++) o = o.flatMap((x) => DIE.map((v) => [...x, v]));
  for (let i = 0; i < coins; i++) o = o.flatMap((x) => [[...x, 1], [...x, 0]]);
  return o;
}
export interface DiceQ { dice: number; coins: number; f: (o: number[]) => boolean; en: string; es: string }
export const DICE_Q: ((r: Rng) => DiceQ)[] = [
  (r) => { const k = r.int(2, 5); return { dice: 1, coins: 0, f: (o) => o[0] > k, en: `You roll a die. What is the chance of a number greater than ${k}?`, es: `Tirás un dado. ¿Qué probabilidad hay de sacar un número mayor que ${k}?` }; },
  () => ({ dice: 1, coins: 0, f: (o) => o[0] % 2 === 0, en: "You roll a die. What is the chance of an even number?", es: "Tirás un dado. ¿Qué probabilidad hay de sacar un número par?" }),
  () => ({ dice: 2, coins: 0, f: (o) => o[0] === o[1], en: "You roll two dice. What is the chance both show the same number?", es: "Tirás dos dados. ¿Qué probabilidad hay de que salga el mismo número en los dos?" }),
  (r) => { const s = r.int(3, 11); return { dice: 2, coins: 0, f: (o) => o[0] + o[1] === s, en: `You roll two dice. What is the chance the total is ${s}?`, es: `Tirás dos dados. ¿Qué probabilidad hay de que sumen ${s}?` }; },
  (r) => { const s = r.int(8, 11); return { dice: 2, coins: 0, f: (o) => o[0] + o[1] >= s, en: `You roll two dice. What is the chance the total is ${s} or more?`, es: `Tirás dos dados. ¿Qué probabilidad hay de que sumen ${s} o más?` }; },
  () => ({ dice: 0, coins: 2, f: (o) => o[0] + o[1] >= 1, en: "You flip two coins. What is the chance of at least one heads?", es: "Tirás dos monedas. ¿Qué probabilidad hay de que salga al menos una cara?" }),
  (r) => { const k = r.int(1, 2); return { dice: 0, coins: 3, f: (o) => o[0] + o[1] + o[2] === k, en: `You flip three coins. What is the chance of exactly ${k} heads?`, es: `Tirás tres monedas. ¿Qué probabilidad hay de que salgan exactamente ${k} ${k === 1 ? "cara" : "caras"}?` }; },
  () => ({ dice: 2, coins: 0, f: (o) => o[0] === 6 || o[1] === 6, en: "You roll two dice. What is the chance of at least one six?", es: "Tirás dos dados. ¿Qué probabilidad hay de sacar al menos un seis?" }),
  () => ({ dice: 2, coins: 0, f: (o) => (o[0] * o[1]) % 2 === 0, en: "You roll two dice and multiply them. What is the chance the result is even?", es: "Tirás dos dados y multiplicás los números. ¿Qué probabilidad hay de que el resultado sea par?" }),
  () => ({ dice: 3, coins: 0, f: (o) => new Set(o).size === 3, en: "You roll three dice. What is the chance all three numbers are different?", es: "Tirás tres dados. ¿Qué probabilidad hay de que salgan tres números distintos?" }),
];
export function reduce(p: number, q: number): string { const g = gcd(p, q); return `${p / g}/${q / g}`; }
defGen({
  id: "dice", sec: "LOG", a: 1.3, k: 4, minMs: 2500, maxMs: 70000,
  make(d, r, ctx) {
    const Q = DICE_Q[d - 1](r);
    const all = outcomes(Q.dice, Q.coins), hit = all.filter(Q.f).length, tot = all.length;
    const ans = reduce(hit, tot);
    const val = (s: string) => { const [p, q] = s.split("/").map(Number); return p / q; };
    const pool = [reduce(hit + 1, tot), reduce(Math.max(1, hit - 1), tot), reduce(1, Q.dice ? 6 : 2), reduce(hit, tot * 2), `1/${tot}`, reduce(Math.min(tot - 1, hit * 2), tot), reduce(tot - hit, tot), "1/3", "1/4", "2/3"];
    const wrong: string[] = [];
    for (const w of pool) if (Math.abs(val(w) - val(ans)) > 1e-9 && !wrong.some((x) => Math.abs(val(x) - val(w)) < 1e-9) && val(w) > 0 && val(w) < 1 && wrong.length < 3) wrong.push(w);
    const { options, ansIdx } = withAnswer(r, ans, wrong);
    return mkItem(this, d, { display: { text: Q[ctx.lang], options }, key: { t: "idx", v: ansIdx }, meta: { d, hit, tot } });
  },
});

/* ---------------- sudoku: one cell of a 4x4 (or 6x6) grid (N options) ---------------- */
export function solveCount(g: number[][], N: number, bh: number, bw: number, limit = 2): number {
  for (let i = 0; i < N * N; i++) {
    const r0 = Math.floor(i / N), c0 = i % N;
    if (g[r0][c0]) continue;
    let count = 0;
    for (let v = 1; v <= N; v++) {
      let ok = true;
      for (let k = 0; k < N && ok; k++) if (g[r0][k] === v || g[k][c0] === v) ok = false;
      const br = r0 - r0 % bh, bc = c0 - c0 % bw;
      for (let a = 0; a < bh && ok; a++) for (let b = 0; b < bw && ok; b++) if (g[br + a][bc + b] === v) ok = false;
      if (!ok) continue;
      g[r0][c0] = v;
      count += solveCount(g, N, bh, bw, limit - count);
      g[r0][c0] = 0;
      if (count >= limit) return count;
    }
    return count;
  }
  return 1;
}
defGen({
  id: "sudoku", sec: "LOG", a: 1.3, k: 4, minMs: 2500, maxMs: 90000,
  make(d, r) {
    const N = d >= 8 ? 6 : 4, bh = 2, bw = N / 2;
    const givens = [12, 11, 10, 9, 8, 7, 6, 22, 19, 16][d - 1];
    const digits = r.shuffle(Array.from({ length: N }, (_, i) => i + 1));
    const bands = r.shuffle(Array.from({ length: N / bh }, (_, i) => i)), stacks = r.shuffle(Array.from({ length: N / bw }, (_, i) => i));
    const rows = bands.flatMap((b) => r.shuffle(Array.from({ length: bh }, (_, i) => b * bh + i)));
    const cols = stacks.flatMap((s) => r.shuffle(Array.from({ length: bw }, (_, i) => s * bw + i)));
    const sol = rows.map((rr) => cols.map((cc) => digits[(rr * bw + Math.floor(rr / bh) + cc) % N]));
    const g = sol.map((row) => row.slice());
    let left = N * N;
    for (const i of r.shuffle(Array.from({ length: N * N }, (_, i) => i))) {
      if (left <= givens) break;
      const a = Math.floor(i / N), b = i % N, keep = g[a][b];
      g[a][b] = 0;
      if (solveCount(g.map((x) => x.slice()), N, bh, bw) !== 1) g[a][b] = keep; else left--;
    }
    const blanks = [];
    for (let a = 0; a < N; a++) for (let b = 0; b < N; b++) if (!g[a][b]) blanks.push([a, b]);
    const [tr, tc] = r.pick(blanks);
    return mkItem(this, d, { k: N, display: { grid: g, n: N, bh, bw, target: [tr, tc] }, key: { t: "idx", v: sol[tr][tc] - 1 }, meta: { sol } });
  },
});
