// LOGICAL-MATHEMATICAL: series, matrix, digits, arith. Ported 1:1 from the prototype.
// deno-lint-ignore-file no-explicit-any
import { defGen, mkItem } from "./registry.ts";
import { MX_N } from "./data.ts";

/* Number series (typed answer, no guessing) */
defGen({
  id: "series", sec: "LOG", a: 1.6, k: 0, minMs: 2000, maxMs: 60000,
  make(d, r) {
    const L = 7;
    let seq: number[];
    switch (d) {
      case 1: { const s = r.int(1, 20), k = r.int(2, 5); seq = Array.from({ length: L }, (_, i) => s + i * k); break; }
      case 2: { const k = r.int(3, 9); if (r.chance(.5)) { const s = r.int(60, 99); seq = Array.from({ length: L }, (_, i) => s - i * k); } else { const s = r.int(1, 30); seq = Array.from({ length: L }, (_, i) => s + i * k); } break; }
      case 3: { const m = r.pick([2, 3]); const s = r.int(1, m === 2 ? 5 : 2); seq = Array.from({ length: L }, (_, i) => s * m ** i); break; }
      case 4: { const s = r.int(1, 15), d0 = r.int(1, 4), dd = r.int(1, 3); seq = [s]; let df = d0; for (let i = 1; i < L; i++) { seq.push(seq[i - 1] + df); df += dd; } break; }
      case 5: { const a = r.int(2, 6), m = r.pick([2, 3]); let x = r.int(1, 5); seq = [x]; for (let i = 1; i < L; i++) { x = i % 2 ? x + a : x * m; seq.push(x); } break; }
      case 6: { const s1 = r.int(1, 15), k1 = r.int(2, 6), s2 = r.int(40, 70), k2 = r.int(2, 5); seq = []; for (let i = 0; i < L + 1; i++) seq.push(i % 2 ? s2 - ((i - 1) / 2) * k2 : s1 + (i / 2) * k1); break; }
      case 7: { const pw = r.pick([2, 2, 3]), off = r.int(-4, 5), st = r.int(1, 3); seq = Array.from({ length: L }, (_, i) => (st + i) ** pw + off); break; }
      case 8: { const a = r.int(1, 5), b = r.int(2, 7); seq = [a, b]; for (let i = 2; i < L; i++) seq.push(seq[i - 1] + seq[i - 2]); break; }
      case 9: { const s = r.int(1, 10), d0 = r.int(1, 3), m = r.pick([2, 3]); seq = [s]; let df = d0; for (let i = 1; i < L; i++) { seq.push(seq[i - 1] + df); df *= m; } break; }
      default: { const s1 = r.int(1, 3), s2 = r.int(45, 75), k = r.int(3, 7); seq = []; for (let i = 0; i < L + 1; i++) seq.push(i % 2 ? s2 - ((i - 1) / 2) * k : s1 * 2 ** (i / 2)); }
    }
    const ans = seq.pop()!;
    return mkItem(this, d, { display: { seq }, key: { t: "num", v: ans } });
  },
});

/* Matrix reasoning (Raven-style, 8 options, balanced distractors: every attribute value
   appears in exactly half the options, so "pick the most common features" can't work) */
export interface MxCell { shape: number; count: number; fill: number; size: number }
defGen({
  id: "matrix", sec: "LOG", a: 1.5, k: 8, minMs: 3000, maxMs: 90000,
  make(d, r) {
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
    });
  },
});

/* Digit span (forward / backward) — working memory */
defGen({
  id: "digits", sec: "LOG", a: 1.4, k: 0, minMs: 0, maxMs: 30000,
  make(d, r) {
    const spec = [[4, 0], [5, 0], [6, 0], [4, 1], [7, 0], [5, 1], [8, 0], [6, 1], [7, 1], [8, 1]][d - 1];
    const [len, back] = spec;
    const ds: number[] = [];
    while (ds.length < len) { const x = r.int(0, 9); if (x !== ds[ds.length - 1]) ds.push(x); }
    const target = (back ? ds.slice().reverse() : ds).join("");
    return mkItem(this, d, { deferTimer: true, display: { digits: ds, back: !!back }, key: { t: "str", v: target } });
  },
});

/* Quick arithmetic (Blitz: ASVAB numerical-operations style) */
defGen({
  id: "arith", sec: "LOG", a: 1.2, k: 0, minMs: 300, maxMs: 15000, w: 1,
  make(d, r) {
    const op = r.pick(["+", "−", "×", "÷"]);
    let a: number, b: number, ans: number;
    if (op === "+") { a = r.int(1, 20 + d * 3); b = r.int(1, 20 + d * 3); ans = a + b; }
    else if (op === "−") { a = r.int(5, 30 + d * 3); b = r.int(1, a); ans = a - b; }
    else if (op === "×") { a = r.int(2, 9 + Math.floor(d / 3)); b = r.int(2, 9 + Math.floor(d / 3)); ans = a * b; }
    else { b = r.int(2, 9); ans = r.int(1, 10 + d); a = b * ans; }
    return mkItem(this, d, { display: { a, op, b }, key: { t: "num", v: ans } });
  },
});
