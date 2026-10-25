// Uniqueness checks for the generators added after the prototype (gens/log2.ts ...),
// merged into gens_test.ts's CHECKS. Same rule: re-derive "correct" independently
// (brute force / parse the shown text where possible), then the key must accept it
// and reject every other option.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";
import { DICE_Q, evalOps, reduce, solveCount, termValue } from "../_shared/gens/log2.ts";
import { Rng } from "../_shared/rng.ts";

function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
const distinct = (xs: unknown[]) => new Set(xs.map((x) => JSON.stringify(x))).size === xs.length;
function typedOk(it: Item, v: number) {
  assert(Number.isInteger(v) && v > 0, `${it.gid}: answer ${v}`);
  assert(checkAnswer(it.key, String(v)) && !checkAnswer(it.key, String(v + 1)) && !checkAnswer(it.key, String(v - 1)));
}
function perms<T>(xs: T[]): T[][] {
  if (xs.length <= 1) return [xs];
  return xs.flatMap((x, i) => perms([...xs.slice(0, i), ...xs.slice(i + 1)]).map((p) => [x, ...p]));
}
const numOf = (s: string) => s.endsWith("%") ? Number(s.slice(0, -1)) / 100
  : s.includes("/") ? Number(s.split("/")[0]) / Number(s.split("/")[1]) : Number(s.replace(",", "."));

export const CHECKS2: Record<string, (it: Item) => void> = {
  symsum(it) {
    const eqs = it.display.eqs as { t: any[]; r: number }[], ask = it.display.ask as number;
    const used = [...new Set(eqs.flatMap((e) => e.t.filter((_, i) => i % 2 === 0) as number[]))];
    assert(used.includes(ask));
    const found = new Set<number>(), v = [0, 0, 0, 0];
    const rec = (i: number) => {
      if (i === used.length) { if (eqs.every((e) => Math.abs(termValue(e.t, v) - e.r) < 1e-9)) found.add(v[ask]); return; }
      for (let x = 1; x <= 15; x++) { v[used[i]] = x; rec(i + 1); }
    };
    rec(0);
    assertEquals([...found], [(it.key as any).v], "symsum: asked value not unique");
    typedOk(it, (it.key as any).v);
  },
  scales(it) {
    const { scales, n, sym, unit, options } = it.display as any;
    const w: Record<number, number> = { [unit]: 1 };
    for (let pass = 0; pass < 6; pass++) for (const s of scales) {
      const unknown = [...new Set<number>([...s.l, ...s.r].filter((x: number) => w[x] === undefined))];
      if (unknown.length !== 1) continue;
      const u = unknown[0];
      const cnt = (a: number[]) => a.filter((x) => x === u).length, known = (a: number[]) => a.filter((x) => x !== u).reduce((t, x) => t + w[x], 0);
      w[u] = (known(s.r) - known(s.l)) / (cnt(s.l) - cnt(s.r));
    }
    assert(w[sym] !== undefined, "scales: not solvable step by step");
    for (const s of scales) assert(Math.abs(s.l.reduce((t: number, x: number) => t + w[x], 0) - s.r.reduce((t: number, x: number) => t + w[x], 0)) < 1e-9, "scales: unbalanced");
    for (const s of scales) assert(s.l.length <= 4 && s.r.length <= 5, "scales: too many on a pan");
    assert(distinct(options) && options.every((o: number) => Number.isInteger(o) && o > 0));
    oneIndex(it, 4, options.indexOf(n * w[sym]));
  },
  ordering(it) {
    const { facts, q, options } = it.display as any;
    const pairs: [string, string][] = facts.map((s: string) => { // [older, younger] read from the text
      let m = s.match(/^(\S+) (?:is older than|es mayor que) (\S+)\.$/);
      if (m) return [m[1], m[2]];
      m = s.match(/^(\S+) (?:is younger than|es menor que|is not older than|no es mayor que) (\S+)\.$/);
      assert(m, `ordering: can't read "${s}"`);
      return [m![2], m![1]];
    });
    const young = /youngest|más joven/.test(q);
    const pos = /second|segunda/.test(q) ? 2 : /third|tercera/.test(q) ? 3 : 1;
    const fits = perms(options as string[]).filter((p) => pairs.every(([o, y]) => p.indexOf(o) < p.indexOf(y)));
    const who = new Set(fits.map((p) => (young ? p[p.length - pos] : p[pos - 1])));
    assertEquals(who.size, 1, "ordering: answer not determined");
    oneIndex(it, options.length, options.indexOf([...who][0]));
  },
  letters(it) {
    const { seq, options } = it.display as any;
    assertEquals(options.length, 4);
    assert(distinct(options), "letters: options not distinct");
    for (const s of [...seq, ...options]) assert(/^[A-Z]\d*$/.test(s), `letters: bad "${s}"`);
    oneIndex(it, 4, options.indexOf((it.meta as any).ans));
  },
  funcmachine(it) {
    const ex = it.display.ex as number[][], x = it.display.x as number;
    const P = (t: number) => { let s = 0; for (let i = 0; i < 3; i++) { let p = ex[i][1]; for (let j = 0; j < 3; j++) if (j !== i) p *= (t - ex[j][0]) / (ex[i][0] - ex[j][0]); s += p; } return s; };
    for (const [a, b] of ex) assert(Math.abs(P(a) - b) < 1e-6, "funcmachine: examples are not one rule of degree <= 2");
    assert(!ex.some((e) => e[0] === x));
    const v = Math.round(P(x));
    assert(Math.abs(P(x) - v) < 1e-6);
    typedOk(it, v);
  },
  operators(it) {
    const { nums, r, options } = it.display as any;
    assert(distinct(options));
    const right = options.map((o: any, i: number) => (Math.abs(evalOps(nums, o) - r) < 1e-9 ? i : -1)).filter((i: number) => i >= 0);
    assertEquals(right.length, 1, "operators: not exactly one option gives the result");
    oneIndex(it, 4, right[0]);
  },
  fraccmp(it) {
    const o = it.display.options as string[];
    assertEquals(o.length, 2);
    const [a, b] = o.map(numOf);
    assert(Number.isFinite(a) && Number.isFinite(b), `fraccmp: can't read ${o}`);
    assert(Math.abs(a - b) > 1e-9, `fraccmp: equal ${o}`);
    oneIndex(it, 2, a > b ? 0 : 1);
  },
  wordprob(it) {
    assert(String(it.display.text).includes("?"));
    typedOk(it, (it.key as any).v);
  },
  dice(it) {
    const { options } = it.display as any;
    const { d, hit, tot } = it.meta as any;
    // count again with plain loops (not the generator's outcome list); questions with a
    // random number in them (d 1, 4, 5, 7) can't be rebuilt from here
    const Q = DICE_Q[d - 1](new Rng(1));
    if (![1, 4, 5, 7].includes(d)) {
      let h = 0, t = 0;
      const dieN = Q.dice, coinN = Q.coins;
      const rec = (o: number[]) => {
        if (o.length === dieN + coinN) { t++; if (Q.f(o)) h++; return; }
        const vals = o.length < dieN ? [1, 2, 3, 4, 5, 6] : [0, 1];
        for (const v of vals) rec([...o, v]);
      };
      rec([]);
      assertEquals([h, t], [hit, tot]);
    }
    assert(distinct(options.map(numOf)), "dice: options with the same value");
    assert(options.every((s: string) => numOf(s) > 0 && numOf(s) < 1));
    oneIndex(it, 4, options.indexOf(reduce(hit, tot)));
  },
  sudoku(it) {
    const { grid, n, bh, bw, target } = it.display as any;
    const sol = (it.meta as any).sol as number[][];
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) {
      if (grid[r][c]) assertEquals(grid[r][c], sol[r][c]);
      assert(new Set(sol[r]).size === n && new Set(sol.map((row) => row[c])).size === n);
    }
    for (let br = 0; br < n; br += bh) for (let bc = 0; bc < n; bc += bw) {
      const box: number[] = [];
      for (let a = 0; a < bh; a++) for (let b = 0; b < bw; b++) box.push(sol[br + a][bc + b]);
      assertEquals(new Set(box).size, n);
    }
    assertEquals(grid[target[0]][target[1]], 0);
    assertEquals(solveCount(grid.map((r: number[]) => r.slice()), n, bh, bw), 1, "sudoku: not exactly one solution");
    oneIndex(it, n, sol[target[0]][target[1]] - 1);
  },
};
