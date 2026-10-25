// Uniqueness checks for the second SPA set (gens/spa2.ts), merged into gens_test.ts's
// CHECKS. Each re-derives the answer its own way (fold forward instead of unfolding,
// 3D normals instead of die rolling, geometry instead of the link list, parsing the text).
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";

function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
const keyCells = (cells: number[][]) => cells.map((c) => c.join(",")).sort().join(";");
const norm = (cells: number[][]) => { const mx = Math.min(...cells.map((c) => c[0])), my = Math.min(...cells.map((c) => c[1])); return keyCells(cells.map(([x, y]) => [x - mx, y - my])); };
const rot = (cells: number[][]) => cells.map(([x, y]) => [-y, x]);
function typedOk(it: Item, v: number) {
  assert(Number.isInteger(v) && v >= 0, `${it.gid}: answer ${v}`);
  assert(checkAnswer(it.key, String(v)) && !checkAnswer(it.key, String(v + 1)));
}

export const CHECKS_SPA2: Record<string, (it: Item) => void> = {
  paperfold(it) {
    const { g, folds, holes, options } = it.display as any;
    // fold every cell of the sheet forward; a cell has a hole if it lands on a punched cell
    const land = (cell: number[]) => {
      let [r, c] = cell, r0 = 0, r1 = g - 1, c0 = 0, c1 = g - 1;
      for (const f of folds) {
        if (f === "D") { if (c < r) [r, c] = [c, r]; continue; }
        if (f === "L" || f === "R") {
          const mid = (c0 + c1 + 1) / 2;
          if (f === "L" && c < mid) c = 2 * mid - 1 - c;
          if (f === "R" && c >= mid) c = 2 * mid - 1 - c;
          if (f === "L") c0 = mid; else c1 = mid - 1;
        } else {
          const mid = (r0 + r1 + 1) / 2;
          if (f === "T" && r < mid) r = 2 * mid - 1 - r;
          if (f === "B" && r >= mid) r = 2 * mid - 1 - r;
          if (f === "T") r0 = mid; else r1 = mid - 1;
        }
      }
      return [r, c];
    };
    const punched = new Set(holes.map((h: number[]) => h.join(",")));
    const truth: number[][] = [];
    for (let r = 0; r < g; r++) for (let c = 0; c < g; c++) if (punched.has(land([r, c]).join(","))) truth.push([r, c]);
    assert(truth.length >= holes.length);
    const keys = options.map(keyCells);
    assertEquals(new Set(keys).size, 4, "paperfold: options not distinct");
    oneIndex(it, 4, keys.indexOf(keyCells(truth)));
  },
  cubenet(it) {
    const { net, ask, mark, options } = it.display as any;
    // fold with 3D vectors: each face has a normal and east / south directions in space
    const add = (a: number[], s = 1) => a.map((x) => x * s);
    const at = new Map<string, number>();
    net.forEach(([r, c]: number[], i: number) => at.set(r + "," + c, i));
    const normal: number[][] = Array(6);
    const go = (i: number, n: number[], E: number[], S: number[]) => {
      normal[i] = n;
      const [r, c] = net[i];
      const nb: [number, number, number[], number[], number[]][] = [
        [0, 1, E, add(n, -1), S], [0, -1, add(E, -1), n, S], [1, 0, S, E, add(n, -1)], [-1, 0, add(S, -1), E, n],
      ];
      for (const [dr, dc, n2, E2, S2] of nb) { const j = at.get((r + dr) + "," + (c + dc)); if (j !== undefined && !normal[j]) go(j, n2, E2, S2); }
    };
    go(0, [0, 0, -1], [1, 0, 0], [0, 1, 0]);
    assertEquals(new Set(normal.map((v) => v.join(","))).size, 6, "cubenet: net doesn't fold into a cube");
    const symAt = (i: number) => net[i][2];
    const oppOf = (s: number) => { const i = net.findIndex((x: number[]) => x[2] === s); return symAt(normal.findIndex((v) => v.every((x, k) => x === -normal[i][k]))); };
    if (ask === "opp") {
      assertEquals(new Set(options).size, 4);
      assert(!options.includes(mark));
      oneIndex(it, 4, options.indexOf(oppOf(mark)));
    } else {
      const ok = options.map((t: number[]) => !t.some((s) => t.includes(oppOf(s))));
      assertEquals(ok.filter(Boolean).length, 1, "cubenet: not exactly one corner triple");
      oneIndex(it, 4, ok.indexOf(true));
    }
  },
  gears(it) {
    const { gears, links, target, options } = it.display as any;
    const dist = (a: any, b: any) => Math.hypot(a.x - b.x, a.y - b.y);
    // the picture must match the links: meshing gears touch, nothing else touches or overlaps
    for (let i = 0; i < gears.length; i++) for (let j = i + 1; j < gears.length; j++) {
      const l = links.find((l: any) => (l.a === i && l.b === j) || (l.a === j && l.b === i));
      const gap = dist(gears[i], gears[j]) - gears[i].r - gears[j].r;
      if (l && l.t === "mesh") assert(Math.abs(gap) < 1e-6, `gears: ${i}-${j} mesh but gap ${gap}`);
      else assert(gap > 0.3, `gears: ${i}-${j} touch without a mesh link`);
    }
    const dir: number[] = Array(gears.length).fill(0);
    dir[0] = 1;
    let jam = false;
    for (let pass = 0; pass < gears.length + 2; pass++) for (const l of links) {
      for (const [a, b] of [[l.a, l.b], [l.b, l.a]]) {
        if (!dir[a]) continue;
        const want = l.t === "belt" ? dir[a] : -dir[a];
        if (!dir[b]) dir[b] = want; else if (dir[b] !== want) jam = true;
      }
    }
    assert(jam || dir[target] !== 0, "gears: target not connected");
    const ans = jam ? "jam" : dir[target] > 0 ? "cw" : "ccw";
    oneIndex(it, options.length, options.indexOf(ans));
  },
  mirror(it) {
    const { shape, axis, options } = it.display as any;
    const refl = shape.map(([x, y]: number[]) => (axis === "v" ? [-x, y] : axis === "h" ? [x, -y] : [y, x]));
    const keys = options.map(norm);
    assertEquals(new Set(keys).size, 4, "mirror: options not distinct");
    // the shape is chiral: no turn of it is its mirror image
    let p = shape;
    for (let k = 0; k < 4; k++) { assert(norm(p) !== norm(refl), "mirror: shape not chiral"); p = rot(p); }
    oneIndex(it, 4, keys.indexOf(norm(refl)));
  },
  countshapes(it) {
    const D = it.display as any;
    let n = 0;
    if (D.kind === "fan") {
      const apex = D.base.length + 2, levels = D.levels.length + 1;
      for (let a = 0; a < apex; a++) for (let b = a + 1; b < apex; b++) for (let l = 0; l < levels; l++) n++;
      assert(D.base.every((x: number, i: number) => x > 0 && x < 1 && (!i || x > D.base[i - 1])));
    } else {
      const v = D.cols.length + 2, hz = D.rows.length + 2;
      for (let a = 0; a < v; a++) for (let b = a + 1; b < v; b++) for (let c = 0; c < hz; c++) for (let d = c + 1; d < hz; d++) n++;
    }
    typedOk(it, n);
  },
  cubecount(it) {
    const { heights: h, ask } = it.display as any;
    const n = h.length;
    let sum = 0, max = 0;
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
      if (i) assert(h[i][j] <= h[i - 1][j], "cubecount: a nearer column is taller (could hide cubes)");
      if (j) assert(h[i][j] <= h[i][j - 1], "cubecount: a nearer column is taller (could hide cubes)");
      sum += h[i][j]; max = Math.max(max, h[i][j]);
    }
    typedOk(it, ask === "fill" ? n * n * max - sum : sum);
  },
  direction(it) {
    const { text, options } = it.display as any;
    const names = /^Est/.test(text)
      ? ["norte", "noreste", "este", "sureste", "sur", "suroeste", "oeste", "noroeste"]
      : ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"];
    const start = names.indexOf(text.match(/(?:facing|mirando al) (\w+)\./)[1]);
    assert(start >= 0, `direction: can't read the start in "${text}"`);
    const steps: Record<string, number> = { "turn right": 2, "turn left": -2, "turn around": 4, "turn 45° right": 1, "turn 45° left": -1,
      "girás a la derecha": 2, "girás a la izquierda": -2, "te das vuelta": 4, "girás 45° a la derecha": 1, "girás 45° a la izquierda": -1 };
    const body = text.replace(/^[^.]*\.\s*(You )?/, "").replace(/\.\s*[^.]*\?$/, "").toLowerCase();
    const parts = body.split(/, then |, después /);
    let at = start;
    for (const p of parts) { assert(p in steps, `direction: unknown move "${p}"`); at += steps[p]; }
    const end = ((at % 8) + 8) % 8;
    assertEquals(new Set(options).size, 4);
    oneIndex(it, 4, options.map((o: string) => o.toLowerCase()).indexOf(names[end]));
  },
  pieces(it) {
    const { n, piece, turn, options } = it.display as any;
    const gap: number[][] = [];
    for (let x = 0; x < n; x++) for (let y = 0; y < n; y++) if (!piece.some((p: number[]) => p[0] === x && p[1] === y)) gap.push([x, y]);
    const fits = (o: number[][]) => { let q = o; for (let k = 0; k < (turn ? 4 : 1); k++) { if (norm(q) === norm(gap)) return true; q = rot(q); } return false; };
    const ok = options.map(fits);
    assertEquals(ok.filter(Boolean).length, 1, "pieces: not exactly one piece fits");
    oneIndex(it, 4, ok.indexOf(true));
  },
};
