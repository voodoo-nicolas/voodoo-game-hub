// SPATIAL: topview, rotation, rotquick, corsi. Ported 1:1 from the prototype, except
// topview's right answer (tvView, 2026-10-25: the prototype's was the mirror image).
import { defGen, GENS, mkItem, say } from "./registry.ts";

/* --- Top view of a cube stack (isometric) --- */
export type Stack = number[][][]; // [row][col] -> colors bottom..top
export type TopGrid = number[][]; // [row][col] -> top color, -1 = empty

export function tvTop(stack: Stack): TopGrid { return stack.map((row) => row.map((c) => c.length ? c[c.length - 1] : -1)); }
export const tvKey = (T: TopGrid) => T.map((r) => r.join(",")).join("|");
export const tvRot = (T: TopGrid) => { const n = T.length; return T.map((row, i) => row.map((_, j) => T[n - 1 - j][i])); };
export const tvMir = (T: TopGrid) => T.map((row) => row.slice().reverse());
/** The stack seen from directly above, as an answer grid draws it (front edge x = n at the
 *  bottom, column j = T[i][j] at x = j). In the isometric drawing, column index j runs
 *  right to left along the front edge, so the true view is the mirror of tvTop.
 *  (2026-10-25 fix: the prototype keyed tvTop itself, i.e. the mirror image, as right.) */
export const tvView = (stack: Stack): TopGrid => tvMir(tvTop(stack));

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
/* fraction of one column's top face that is visible to the viewer (cubes: every cube of the stack) */
function tvCellVisible(P: ReturnType<typeof tvProj>, cubes: [number, number, number][], i: number, j: number, z: number): number {
  const hexOf = ([a, b, c]: [number, number, number]) => [P(a, b, c + 1), P(a + 1, b, c + 1), P(a + 1, b, c), P(a + 1, b + 1, c), P(a, b + 1, c), P(a, b + 1, c + 1)];
  const front = cubes.filter((q) => q[0] + q[1] > i + j).map(hexOf);
  let ok = 0, tot = 0;
  for (let u = 1; u <= 4; u++) for (let w = 1; w <= 4; w++) {
    const [px, py] = P(i + u / 5, j + w / 5, z);
    tot++;
    if (!front.some((h) => pointInPoly(px, py, h))) ok++;
  }
  return ok / tot;
}
const tvCubes = (stack: Stack) => {
  const cubes: [number, number, number][] = [];
  for (let i = 0; i < stack.length; i++) for (let j = 0; j < stack.length; j++) for (let z = 0; z < stack[i][j].length; z++) cubes.push([i, j, z]);
  return cubes;
};
export function tvVisibility(stack: Stack): number[][] {
  const n = stack.length, P = tvProj(n, 10), cubes = tvCubes(stack);
  return stack.map((row, i) => row.map((c, j) => tvCellVisible(P, cubes, i, j, c.length)));
}

defGen({
  id: "topview", sec: "SPA", a: 1.4, k: 5, minMs: 2500, maxMs: 75000,
  make(d, r, ctx) {
    for (let tries = 0; tries < 120; tries++) {
      const n = d <= 2 ? 3 : d <= 6 ? 4 : 5, hmax = d <= 2 ? 2 : d <= 4 ? 3 : 4;
      // Columns are built front to back (the viewer's side first) and each gets a height that
      // leaves its top face in view where one exists: a taller column in front hides what is
      // behind it, and a colour the player can't see can't be checked against the options.
      // (Players, 2026-10-26: "the boxes and colors don't line up" on the big grids: 30-37 % of
      // the columns were hidden.) Hidden ones are rare now and never what tells the options apart.
      const P = tvProj(n, 10);
      const stack: Stack = Array.from({ length: n }, () => Array.from({ length: n }, () => [] as number[]));
      const cells: [number, number][] = [];
      for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) cells.push([i, j]);
      r.shuffle(cells).sort((a, b) => (b[0] + b[1]) - (a[0] + a[1]));
      for (const [i, j] of cells) {
        const hole = r.chance(d <= 3 ? .15 : .08);
        const cap = i + j >= n - 1 ? Math.min(hmax, 2) : hmax; // low in front, tall behind: the stack climbs away from the viewer
        const hs = r.shuffle(Array.from({ length: cap + 1 }, (_, h) => h)).filter((h) => (h === 0) === hole);
        let pick = hs[0];
        const cubes = tvCubes(stack); // only the columns in front count; the ones behind are still empty
        for (const h of hs) if (tvCellVisible(P, cubes, i, j, h) >= .95) { pick = h; break; }
        stack[i][j] = Array.from({ length: pick }, () => r.int(0, 3));
      }
      const T = tvView(stack), vis = tvMir(tvVisibility(stack)); // both indexed as the grid draws them
      const hiddenCells = vis.flat().filter((v) => v < .5).length;
      if (hiddenCells > Math.ceil(n * n * .16)) continue;
      const visCells: [number, number][] = [];
      for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) if (vis[i][j] >= 0.5 && T[i][j] >= 0) visCells.push([i, j]);
      if (visCells.length < 4) continue;
      const recolor = () => { const X = T.map((x) => x.slice()); const [i, j] = r.pick(visCells); X[i][j] = r.pick([0, 1, 2, 3].filter((c) => c !== T[i][j])); return X; };
      const swap = () => { const X = T.map((x) => x.slice()); for (let k = 0; k < 20; k++) { const [a, b] = r.pick(visCells), [c, e] = r.pick(visCells); if (X[a][b] !== X[c][e]) { [X[a][b], X[c][e]] = [X[c][e], X[a][b]]; return X; } } return recolor(); };
      const dist = d <= 4 ? [tvRot(T), tvMir(T), tvRot(tvRot(T)), recolor()] : d <= 7 ? [tvMir(T), tvRot(tvRot(T)), recolor(), swap()] : [swap(), recolor(), swap(), tvMir(tvRot(T))];
      const all = [T, ...dist];
      const keys = new Set(all.map(tvKey));
      if (keys.size !== 5) continue;
      // every wrong picture must differ from the right one in a column the player can see
      const seenDiff = (X: TopGrid) => { let c = 0; for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) if (vis[i][j] >= .5 && X[i][j] !== T[i][j]) c++; return c; };
      if (dist.some((X) => seenDiff(X) < 1)) continue;
      const order = r.shuffle([0, 1, 2, 3, 4]);
      const ansIdx = order.indexOf(0);
      const wrongs = d <= 4 ? ["turned", "mirrored", "turned upside down", "with one colour changed"] : d <= 7 ? ["mirrored", "turned upside down", "with one colour changed", "with two colours swapped"] : ["with two colours swapped", "with one colour changed", "with two other colours swapped", "turned and mirrored"];
      const wrongsEs = d <= 4 ? ["girada", "espejada", "dada vuelta", "con un color cambiado"] : d <= 7 ? ["espejada", "dada vuelta", "con un color cambiado", "con dos colores intercambiados"] : ["con dos colores intercambiados", "con un color cambiado", "con otros dos colores intercambiados", "girada y espejada"];
      const why = say(ctx.lang, `From straight above you see only the top cube of each column, in the same place as on the floor grid (the front edge at the bottom). The right picture matches every column you can see (ignore one hidden behind a taller column). The others are the view ${wrongs.join(", ")}.`,
        `Desde arriba se ve solo el cubo de más arriba de cada columna, en el mismo lugar que en la cuadrícula del piso (el borde de adelante abajo). La imagen correcta coincide en todas las columnas que se ven (ignorá las que quedan tapadas por una más alta). Las otras son la vista ${wrongsEs.join(", ")}.`);
      return mkItem(this, d, { display: { stack, options: order.map((i) => all[i]) }, key: { t: "idx", v: ansIdx, rev: 3 }, why });
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
export function chiralPoly(m: number, r: import("../rng.ts").Rng): Poly {
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
  make(d, r, ctx) {
    const m = [4, 5, 5, 6, 6, 7, 8, 9, 10, 11][d - 1];
    const p = chiralPoly(m, r);
    const turns = r.int(1, 3);
    const correct = pRotN(p, turns);
    const ks = r.shuffle([0, 1, 2, 3]).slice(0, 3);
    const dist = ks.map((k) => pRotN(pMir(p), k));
    const all = [correct, ...dist];
    const order = r.shuffle([0, 1, 2, 3]);
    const ansIdx = order.indexOf(0);
    const why = say(ctx.lang, `The right one is the same shape turned ${turns * 90}°. The other three are mirror images: they would have to be flipped over, not just turned, to match.`,
      `La correcta es la misma figura girada ${turns * 90}°. Las otras tres son su imagen en el espejo: habría que darlas vuelta, no solo girarlas, para que coincidan.`);
    return mkItem(this, d, { display: { target: pNorm(p), options: order.map((i) => pNorm(all[i])) }, key: { t: "idx", v: ansIdx }, why });
  },
});
/* Blitz quick version: same or mirror? */
defGen({
  id: "rotquick", sec: "SPA", a: 1.2, k: 2, minMs: 400, maxMs: 15000, w: 2,
  make(d, r, ctx) {
    const p = chiralPoly(r.int(5, 6), r);
    const same = r.chance(.5);
    const turns = r.int(1, 3);
    const q = pRotN(same ? p : pMir(p), turns);
    const ans = same ? 0 : 1;
    const why = same
      ? say(ctx.lang, `The right shape is the left one turned ${turns * 90}°: the same shape.`, `La figura de la derecha es la de la izquierda girada ${turns * 90}°: la misma figura.`)
      : say(ctx.lang, `The right shape is the left one flipped over (a mirror image), then turned ${turns * 90}°. Turning alone can't make them match.`, `La figura de la derecha es la de la izquierda dada vuelta (en espejo) y girada ${turns * 90}°. Solo girándola no coinciden.`);
    return mkItem(this, d, { display: { left: pNorm(p), right: pNorm(q) }, key: { t: "idx", v: ans }, why });
  },
});

/* --- Corsi block tapping (visuospatial memory); block positions are fixed client-side (CORSI_POS) --- */
defGen({
  id: "corsi", sec: "SPA", a: 1.3, k: 0, minMs: 0, maxMs: 25000,
  make(d, r, ctx) {
    const len = [3, 3, 4, 4, 5, 5, 6, 7, 8, 9][d - 1];
    const seq: number[] = [];
    while (seq.length < len) { const x = r.int(0, 8); if (x !== seq[seq.length - 1]) seq.push(x); }
    const why = say(ctx.lang, `${len} blocks lit up, one after another. The numbers on the blocks show the order they lit up in, which is the order to tap them.`, `Se iluminaron ${len} bloques, uno tras otro. Los números en los bloques muestran el orden en que se iluminaron, que es el orden para tocarlos.`);
    return mkItem(this, d, { deferTimer: true, display: { seq }, key: { t: "str", v: seq.join(""), strict: true }, why });
  },
});
