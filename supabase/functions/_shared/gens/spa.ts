// SPATIAL: topview, rotation, rotquick, corsi. Ported 1:1 from the prototype.
import { defGen, GENS, mkItem } from "./registry.ts";

/* --- Top view of a cube stack (isometric) --- */
export type Stack = number[][][]; // [row][col] -> colors bottom..top
export type TopGrid = number[][]; // [row][col] -> top color, -1 = empty

export function tvTop(stack: Stack): TopGrid { return stack.map((row) => row.map((c) => c.length ? c[c.length - 1] : -1)); }
export const tvKey = (T: TopGrid) => T.map((r) => r.join(",")).join("|");
export const tvRot = (T: TopGrid) => { const n = T.length; return T.map((row, i) => row.map((_, j) => T[n - 1 - j][i])); };
export const tvMir = (T: TopGrid) => T.map((row) => row.slice().reverse());

/* iso projection helpers */
function tvProj(n: number, s: number) {
  const cw = s * 0.866, ch = s * 0.5;
  const ox = n * cw + 10;
  const oy = 10 + 4 * s;
  return (x: number, y: number, z: number): [number, number] => [ox + (x - y) * cw, oy + (x + y) * ch - z * s];
}
function pointInPoly(px: number, py: number, poly: [number, number][]) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if (((yi > py) !== (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) inside = !inside;
  }
  return inside;
}
/* fraction of each column's top face that is visible to the viewer */
export function tvVisibility(stack: Stack): number[][] {
  const n = stack.length, P = tvProj(n, 10);
  const cubes: [number, number, number][] = [];
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) for (let z = 0; z < stack[i][j].length; z++) cubes.push([i, j, z]);
  const hexOf = ([a, b, c]: [number, number, number]) => [P(a, b, c + 1), P(a + 1, b, c + 1), P(a + 1, b, c), P(a + 1, b + 1, c), P(a, b + 1, c), P(a, b + 1, c + 1)];
  const vis: number[][] = [];
  for (let i = 0; i < n; i++) {
    vis.push([]);
    for (let j = 0; j < n; j++) {
      const z = stack[i][j].length;
      let ok = 0, tot = 0;
      for (let u = 1; u <= 4; u++) for (let w = 1; w <= 4; w++) {
        const [px, py] = P(i + u / 5, j + w / 5, z);
        tot++;
        let hidden = false;
        for (const q of cubes) { if (q[0] + q[1] <= i + j) continue; if (pointInPoly(px, py, hexOf(q))) { hidden = true; break; } }
        if (!hidden) ok++;
      }
      vis[i].push(ok / tot);
    }
  }
  return vis;
}

defGen({
  id: "topview", sec: "SPA", a: 1.4, k: 5, minMs: 2500, maxMs: 75000,
  make(d, r, ctx) {
    for (let tries = 0; tries < 60; tries++) {
      const n = d <= 2 ? 3 : d <= 6 ? 4 : 5, hmax = d <= 2 ? 2 : d <= 4 ? 3 : 4;
      const stack: Stack = [];
      for (let i = 0; i < n; i++) { stack.push([]); for (let j = 0; j < n; j++) { const hh = r.chance(d <= 3 ? .15 : .08) ? 0 : r.int(1, hmax); stack[i].push(Array.from({ length: hh }, () => r.int(0, 3))); } }
      const T = tvTop(stack), vis = tvVisibility(stack);
      const visCells: [number, number][] = [];
      for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) if (vis[i][j] >= 0.5 && T[i][j] >= 0) visCells.push([i, j]);
      if (visCells.length < 4) continue;
      const recolor = () => { const X = T.map((x) => x.slice()); const [i, j] = r.pick(visCells); X[i][j] = r.pick([0, 1, 2, 3].filter((c) => c !== T[i][j])); return X; };
      const swap = () => { const X = T.map((x) => x.slice()); for (let k = 0; k < 20; k++) { const [a, b] = r.pick(visCells), [c, e] = r.pick(visCells); if (X[a][b] !== X[c][e]) { [X[a][b], X[c][e]] = [X[c][e], X[a][b]]; return X; } } return recolor(); };
      const dist = d <= 4 ? [tvRot(T), tvMir(T), tvRot(tvRot(T)), recolor()] : d <= 7 ? [tvMir(T), tvRot(tvRot(T)), recolor(), swap()] : [swap(), recolor(), swap(), tvMir(tvRot(T))];
      const all = [T, ...dist];
      const keys = new Set(all.map(tvKey));
      if (keys.size !== 5) continue;
      const order = r.shuffle([0, 1, 2, 3, 4]);
      const ansIdx = order.indexOf(0);
      return mkItem(this, d, { display: { stack, options: order.map((i) => all[i]) }, key: { t: "idx", v: ansIdx } });
    }
    return GENS.rotation.make(d, r, ctx);
  },
});

/* --- Mental rotation of polyominoes (rotated vs mirrored) --- */
export type Poly = [number, number][];
function polyo(m: number, r: import("../rng.ts").Rng): Poly {
  const cells: Poly = [[0, 0]], set = new Set(["0,0"]);
  while (cells.length < m) {
    const [x, y] = r.pick(cells);
    const [dx, dy] = r.pick([[1, 0], [-1, 0], [0, 1], [0, -1]]);
    const k = (x + dx) + "," + (y + dy);
    if (!set.has(k)) { set.add(k); cells.push([x + dx, y + dy]); }
  }
  return cells;
}
export const pNorm = (c: Poly): Poly => { const mx = Math.min(...c.map((p) => p[0])), my = Math.min(...c.map((p) => p[1])); return c.map(([x, y]) => [x - mx, y - my] as [number, number]).sort((a, b) => a[0] - b[0] || a[1] - b[1]); };
export const pKey = (c: Poly) => pNorm(c).map((p) => p.join(",")).join(";");
export const pRot = (c: Poly): Poly => c.map(([x, y]) => [y, -x]);
export const pMir = (c: Poly): Poly => c.map(([x, y]) => [-x, y]);
export const pRotN = (c: Poly, k: number) => { let o = c; for (let i = 0; i < k; i++) o = pRot(o); return o; };
function chiralPoly(m: number, r: import("../rng.ts").Rng): Poly {
  for (let t2 = 0; t2 < 200; t2++) {
    const p = polyo(m, r);
    const rots = new Set([0, 1, 2, 3].map((k) => pKey(pRotN(p, k))));
    if (rots.size < 4 && m >= 5) continue;
    const mir = pMir(p);
    if ([0, 1, 2, 3].some((k) => rots.has(pKey(pRotN(mir, k))))) continue;
    return p;
  }
  return [[0, 0], [1, 0], [2, 0], [2, 1], [3, 1]];
}
defGen({
  id: "rotation", sec: "SPA", a: 1.4, k: 4, minMs: 1200, maxMs: 40000,
  make(d, r) {
    const m = [4, 5, 5, 6, 6, 7, 8, 9, 10, 11][d - 1];
    const p = chiralPoly(m, r);
    const correct = pRotN(p, r.int(1, 3));
    const ks = r.shuffle([0, 1, 2, 3]).slice(0, 3);
    const dist = ks.map((k) => pRotN(pMir(p), k));
    const all = [correct, ...dist];
    const order = r.shuffle([0, 1, 2, 3]);
    const ansIdx = order.indexOf(0);
    return mkItem(this, d, { display: { target: pNorm(p), options: order.map((i) => pNorm(all[i])) }, key: { t: "idx", v: ansIdx } });
  },
});
/* Blitz quick version: same or mirror? */
defGen({
  id: "rotquick", sec: "SPA", a: 1.2, k: 2, minMs: 400, maxMs: 15000, w: 2,
  make(d, r) {
    const p = chiralPoly(r.int(5, 6), r);
    const same = r.chance(.5);
    const q = pRotN(same ? p : pMir(p), r.int(1, 3));
    const ans = same ? 0 : 1;
    return mkItem(this, d, { display: { left: pNorm(p), right: pNorm(q) }, key: { t: "idx", v: ans } });
  },
});

/* --- Corsi block tapping (visuospatial memory); block positions are fixed client-side (CORSI_POS) --- */
defGen({
  id: "corsi", sec: "SPA", a: 1.3, k: 0, minMs: 0, maxMs: 25000,
  make(d, r) {
    const len = [3, 3, 4, 4, 5, 5, 6, 7, 8, 9][d - 1];
    const seq: number[] = [];
    while (seq.length < len) { const x = r.int(0, 8); if (x !== seq[seq.length - 1]) seq.push(x); }
    return mkItem(this, d, { deferTimer: true, display: { seq }, key: { t: "str", v: seq.join(""), strict: true } });
  },
});
