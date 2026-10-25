// LOGICAL-MATHEMATICAL: series, matrix, digits, arith. Ported 1:1 from the prototype.
// deno-lint-ignore-file no-explicit-any
import { defGen, type Lang, mkItem, say } from "./registry.ts";
import { MX_N } from "./data.ts";

/* Number series (typed answer, no guessing) */
defGen({
  id: "series", sec: "LOG", a: 1.6, k: 0, minMs: 2000, maxMs: 60000,
  make(d, r, ctx) {
    const L = 7;
    let seq: number[];
    // why: built from the same values, after the sequence (no RNG draws)
    let why: (s: number[], ans: number, lang: Lang) => string;
    switch (d) {
      case 1: { const s = r.int(1, 20), k = r.int(2, 5); seq = Array.from({ length: L }, (_, i) => s + i * k);
        why = (q, a, l) => say(l, `Each number adds ${k}: ${q[5]} + ${k} = ${a}.`, `Cada número suma ${k}: ${q[5]} + ${k} = ${a}.`); break; }
      case 2: { const k = r.int(3, 9); const down = r.chance(.5); if (down) { const s = r.int(60, 99); seq = Array.from({ length: L }, (_, i) => s - i * k); } else { const s = r.int(1, 30); seq = Array.from({ length: L }, (_, i) => s + i * k); }
        why = (q, a, l) => down ? say(l, `Each number takes away ${k}: ${q[5]} − ${k} = ${a}.`, `Cada número resta ${k}: ${q[5]} − ${k} = ${a}.`) : say(l, `Each number adds ${k}: ${q[5]} + ${k} = ${a}.`, `Cada número suma ${k}: ${q[5]} + ${k} = ${a}.`); break; }
      case 3: { const m = r.pick([2, 3]); const s = r.int(1, m === 2 ? 5 : 2); seq = Array.from({ length: L }, (_, i) => s * m ** i);
        why = (q, a, l) => say(l, `Each number is the one before times ${m}: ${q[5]} × ${m} = ${a}.`, `Cada número es el anterior por ${m}: ${q[5]} × ${m} = ${a}.`); break; }
      case 4: { const s = r.int(1, 15), d0 = r.int(1, 4), dd = r.int(1, 3); seq = [s]; let df = d0; for (let i = 1; i < L; i++) { seq.push(seq[i - 1] + df); df += dd; }
        const g = d0 + 5 * dd;
        why = (q, a, l) => say(l, `The jumps grow by ${dd} each time (+${d0}, +${d0 + dd}, +${d0 + 2 * dd}…), so the next jump is +${g}: ${q[5]} + ${g} = ${a}.`, `Los saltos crecen ${dd} cada vez (+${d0}, +${d0 + dd}, +${d0 + 2 * dd}…), así que el próximo es +${g}: ${q[5]} + ${g} = ${a}.`); break; }
      case 5: { const a = r.int(2, 6), m = r.pick([2, 3]); let x = r.int(1, 5); seq = [x]; for (let i = 1; i < L; i++) { x = i % 2 ? x + a : x * m; seq.push(x); }
        why = (q, an, l) => say(l, `The steps take turns: +${a}, then ×${m}. The next step is ×${m}: ${q[5]} × ${m} = ${an}.`, `Los pasos se turnan: +${a} y después ×${m}. El próximo es ×${m}: ${q[5]} × ${m} = ${an}.`); break; }
      case 6: { const s1 = r.int(1, 15), k1 = r.int(2, 6), s2 = r.int(40, 70), k2 = r.int(2, 5); seq = []; for (let i = 0; i < L + 1; i++) seq.push(i % 2 ? s2 - ((i - 1) / 2) * k2 : s1 + (i / 2) * k1);
        why = (q, a, l) => say(l, `Two series take turns: ${s1}, ${s1 + k1}, ${s1 + 2 * k1}… adds ${k1}, and ${s2}, ${s2 - k2}, ${s2 - 2 * k2}… takes away ${k2}. The missing number is in the second one: ${q[5]} − ${k2} = ${a}.`, `Dos series se turnan: ${s1}, ${s1 + k1}, ${s1 + 2 * k1}… suma ${k1}, y ${s2}, ${s2 - k2}, ${s2 - 2 * k2}… resta ${k2}. El que falta es de la segunda: ${q[5]} − ${k2} = ${a}.`); break; }
      case 7: { const pw = r.pick([2, 2, 3]), off = r.int(-4, 5), st = r.int(1, 3); seq = Array.from({ length: L }, (_, i) => (st + i) ** pw + off);
        const sq = pw === 2 ? "²" : "³", n = st + 6, tail = off ? ` ${off > 0 ? "+" : "−"} ${Math.abs(off)}` : "";
        why = (_q, a, l) => say(l, `They are ${pw === 2 ? "squares" : "cubes"}${off ? (off > 0 ? ` plus ${off}` : ` minus ${-off}`) : ""}: ${st}${sq}${tail}, ${st + 1}${sq}${tail}, … so the next is ${n}${sq}${tail} = ${a}.`, `Son ${pw === 2 ? "cuadrados" : "cubos"}${off ? (off > 0 ? ` más ${off}` : ` menos ${-off}`) : ""}: ${st}${sq}${tail}, ${st + 1}${sq}${tail}, … así que sigue ${n}${sq}${tail} = ${a}.`); break; }
      case 8: { const a = r.int(1, 5), b = r.int(2, 7); seq = [a, b]; for (let i = 2; i < L; i++) seq.push(seq[i - 1] + seq[i - 2]);
        why = (q, an, l) => say(l, `Each number is the sum of the two before it: ${q[4]} + ${q[5]} = ${an}.`, `Cada número es la suma de los dos anteriores: ${q[4]} + ${q[5]} = ${an}.`); break; }
      case 9: { const s = r.int(1, 10), d0 = r.int(1, 3), m = r.pick([2, 3]); seq = [s]; let df = d0; for (let i = 1; i < L; i++) { seq.push(seq[i - 1] + df); df *= m; }
        const g = d0 * m ** 5;
        why = (q, a, l) => say(l, `The jumps are multiplied by ${m} each time (+${d0}, +${d0 * m}, +${d0 * m * m}…), so the next jump is +${g}: ${q[5]} + ${g} = ${a}.`, `Los saltos se multiplican por ${m} cada vez (+${d0}, +${d0 * m}, +${d0 * m * m}…), así que el próximo es +${g}: ${q[5]} + ${g} = ${a}.`); break; }
      default: { const s1 = r.int(1, 3), s2 = r.int(45, 75), k = r.int(3, 7); seq = []; for (let i = 0; i < L + 1; i++) seq.push(i % 2 ? s2 - ((i - 1) / 2) * k : s1 * 2 ** (i / 2));
        why = (q, a, l) => say(l, `Two series take turns: ${s1}, ${s1 * 2}, ${s1 * 4}… doubles, and ${s2}, ${s2 - k}, ${s2 - 2 * k}… takes away ${k}. The missing number is in the second one: ${q[5]} − ${k} = ${a}.`, `Dos series se turnan: ${s1}, ${s1 * 2}, ${s1 * 4}… se duplica, y ${s2}, ${s2 - k}, ${s2 - 2 * k}… resta ${k}. El que falta es de la segunda: ${q[5]} − ${k} = ${a}.`); }
    }
    const ans = seq.pop()!;
    return mkItem(this, d, { display: { seq }, key: { t: "num", v: ans }, why: why(seq, ans, ctx.lang) });
  },
});

/* Matrix reasoning (Raven-style, 8 options, balanced distractors: every attribute value
   appears in exactly half the options, so "pick the most common features" can't work) */
export interface MxCell { shape: number; count: number; fill: number; size: number }
const MX_WORD: Record<string, [string, string, string, string]> = { // en, es, en "all three", es "las tres"
  shape: ["the shape", "la forma", "all three shapes", "las tres formas"], count: ["the number of shapes", "la cantidad de figuras", "one, two and three shapes", "una, dos y tres figuras"],
  fill: ["the fill", "el relleno", "all three fills", "los tres rellenos"], size: ["the size", "el tamaño", "all three sizes", "los tres tamaños"],
};
/** One sentence per attribute rule, then why only one option fits. */
export function matrixWhy(rule: Record<string, any>, lang: Lang): string {
  const parts = ["shape", "count", "fill", "size"].map((k) => {
    const u = rule[k], [en, es, enP, esP] = MX_WORD[k];
    if (u.t === "const") return say(lang, `${cap(en)} is the same in every cell.`, `${cap(es)} es igual en todas las celdas.`);
    if (u.t === "prog") return u.dir > 0 ? say(lang, `${cap(en)} grows from left to right in every row.`, `${cap(es)} crece de izquierda a derecha en cada fila.`) : say(lang, `${cap(en)} shrinks from left to right in every row.`, `${cap(es)} disminuye de izquierda a derecha en cada fila.`);
    if (u.t === "add") return say(lang, "In every row, the third cell has as many shapes as the first two together.", "En cada fila, la tercera celda tiene tantas figuras como las dos primeras juntas.");
    return say(lang, `Every row has ${enP}, none repeated.`, `En cada fila aparecen ${esP}, sin repetir.`);
  });
  return parts.join(" ") + " " + say(lang, "Only one option follows every rule at once.", "Solo una opción cumple todas las reglas a la vez.");
}
const cap = (s: string) => s[0].toUpperCase() + s.slice(1);
defGen({
  id: "matrix", sec: "LOG", a: 1.5, k: 8, minMs: 3000, maxMs: 90000,
  make(d, r, ctx) {
    const nVar = d <= 2 ? 1 : d <= 4 ? 2 : d <= 7 ? 3 : 4;
    const keys = r.shuffle(["shape", "count", "fill", "size"] as const);
    const varKeys = keys.slice(0, nVar), constKeys = keys.slice(nVar);
    const rule: Record<string, any> = {};
    const addRows = r.shuffle([[0, 0, 1], [0, 1, 2], [1, 0, 2]]);
    for (const k of varKeys) {
      if (k === "count" && d >= 9 && r.chance(.6)) rule[k] = { t: "add" };
      else if ((k === "count" || k === "size") && r.chance(d <= 4 ? .6 : .3)) rule[k] = { t: "prog", dir: r.chance(.5) ? 1 : -1 };
      else rule[k] = { t: "dist", vals: k === "shape" ? r.shuffle([0, 1, 2, 3, 4]).slice(0, 3) : r.shuffle([0, 1, 2]), sh: d >= 6 && r.chance(.5) ? 2 : 1 };
    }
    for (const k of constKeys) rule[k] = { t: "const", v: r.int(0, MX_N[k] - 1) };
    const val = (k: string, row: number, col: number): number => {
      const u = rule[k];
      if (u.t === "const") return u.v;
      if (u.t === "prog") return u.dir > 0 ? col : 2 - col;
      if (u.t === "add") return addRows[row][col];
      return u.vals[(col + row * u.sh) % 3];
    };
    const cells: MxCell[] = [];
    for (let row = 0; row < 3; row++) for (let col = 0; col < 3; col++) cells.push({ shape: val("shape", row, col), count: val("count", row, col), fill: val("fill", row, col), size: val("size", row, col) });
    const answer = cells[8];
    // three perturbed attributes, alternatives that are plausible at higher difficulty
    const pert = (varKeys as string[]).concat(r.shuffle(constKeys)).slice(0, 3) as (keyof MxCell)[];
    const alt: Record<string, number> = {};
    for (const k of pert) {
      const seen = [...new Set(cells.slice(0, 8).map((c) => c[k]))].filter((v) => v !== answer[k]);
      const all = Array.from({ length: MX_N[k] }, (_, i) => i).filter((v) => v !== answer[k]);
      alt[k] = (d >= 5 && seen.length) ? r.pick(seen) : r.pick(all);
    }
    const opts: MxCell[] = [];
    for (let m = 0; m < 8; m++) { const o = Object.assign({}, answer); pert.forEach((k, i) => { if (m >> i & 1) o[k] = alt[k]; }); opts.push(o); }
    const order = r.shuffle([0, 1, 2, 3, 4, 5, 6, 7]);
    const ansIdx = order.indexOf(0);
    return mkItem(this, d, {
      display: { cells: cells.slice(0, 8), options: order.map((i) => opts[i]) },
      key: { t: "idx", v: ansIdx },
      meta: { answer },
      why: matrixWhy(rule, ctx.lang),
    });
  },
});

/* Digit span (forward / backward) — working memory */
defGen({
  id: "digits", sec: "LOG", a: 1.4, k: 0, minMs: 0, maxMs: 30000,
  make(d, r, ctx) {
    const spec = [[4, 0], [5, 0], [6, 0], [4, 1], [7, 0], [5, 1], [8, 0], [6, 1], [7, 1], [8, 1]][d - 1];
    const [len, back] = spec;
    const ds: number[] = [];
    while (ds.length < len) { const x = r.int(0, 9); if (x !== ds[ds.length - 1]) ds.push(x); }
    const target = (back ? ds.slice().reverse() : ds).join("");
    const why = back
      ? say(ctx.lang, `The digits were ${ds.join(" ")}. Backwards, that is ${target.split("").join(" ")}.`, `Los dígitos fueron ${ds.join(" ")}. Al revés: ${target.split("").join(" ")}.`)
      : say(ctx.lang, `The digits were ${ds.join(" ")}, in that order.`, `Los dígitos fueron ${ds.join(" ")}, en ese orden.`);
    return mkItem(this, d, { deferTimer: true, display: { digits: ds, back: !!back }, key: { t: "str", v: target }, why });
  },
});

/* Quick arithmetic (Blitz: ASVAB numerical-operations style) */
defGen({
  id: "arith", sec: "LOG", a: 1.2, k: 0, minMs: 300, maxMs: 15000, w: 1,
  make(d, r, ctx) {
    const op = r.pick(["+", "−", "×", "÷"]);
    let a: number, b: number, ans: number;
    if (op === "+") { a = r.int(1, 20 + d * 3); b = r.int(1, 20 + d * 3); ans = a + b; }
    else if (op === "−") { a = r.int(5, 30 + d * 3); b = r.int(1, a); ans = a - b; }
    else if (op === "×") { a = r.int(2, 9 + Math.floor(d / 3)); b = r.int(2, 9 + Math.floor(d / 3)); ans = a * b; }
    else { b = r.int(2, 9); ans = r.int(1, 10 + d); a = b * ans; }
    return mkItem(this, d, { display: { a, op, b }, key: { t: "num", v: ans }, why: say(ctx.lang, `${a} ${op} ${b} = ${ans}.`, `${a} ${op} ${b} = ${ans}.`) });
  },
});
