// SPATIAL, second set (2026-10-25; NOT in the prototype): paperfold, cubenet, gears,
// mirror, countshapes, cubecount, direction, pieces. Served only to clients that send
// gv >= 2 (engine.ts secGens).
import { defGen, type Lang, mkItem, say } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { chiralPoly, pKey, pMir, pNorm, type Poly, pRotN } from "./spa.ts";

const keyOf = (cells: number[][]) => cells.map((c) => c.join(",")).sort().join(";");
/** The client's symbols (items.gd _sym_pts) by id, for `why`. */
/** Spanish article for symbol s (the star and the cross are feminine). */
const FEM6 = [false, false, false, true, false, true];
const SYM6: Record<Lang, string[]> = {
  en: ["triangle", "circle", "square", "star", "diamond", "cross"],
  es: ["triángulo", "círculo", "cuadrado", "estrella", "rombo", "cruz"],
};

/* ---------------- paperfold: fold, punch, unfold (4 options) ----------------
   A G x G sheet (cells [row, col]). Folds halve the current region:
   L = left half over onto the right, R = right over left, T = top down, B = bottom up,
   D = the lower-left triangle over onto the upper-right (only as the first fold). */
export type Fold = "L" | "R" | "T" | "B" | "D";
export type Region = [number, number, number, number]; // r0, r1, c0, c1 (inclusive)
export function foldStep(reg: Region, f: Fold): { reg: Region; refl: (p: number[]) => number[] } {
  const [r0, r1, c0, c1] = reg;
  if (f === "D") return { reg, refl: ([r, c]) => [c, r] };
  if (f === "L" || f === "R") {
    const mid = (c0 + c1 + 1) / 2;
    return { reg: f === "L" ? [r0, r1, mid, c1] : [r0, r1, c0, mid - 1], refl: ([r, c]) => [r, 2 * mid - 1 - c] };
  }
  const mid = (r0 + r1 + 1) / 2;
  return { reg: f === "T" ? [mid, r1, c0, c1] : [r0, mid - 1, c0, c1], refl: ([r, c]) => [2 * mid - 1 - r, c] };
}
function unfold(G: number, folds: Fold[], holes: number[][], skip = -1, swap = -1): number[][] {
  const steps: ((p: number[]) => number[])[] = [];
  let reg: Region = [0, G - 1, 0, G - 1];
  folds.forEach((f, i) => {
    const sw: Fold = i === swap ? ({ L: "T", R: "B", T: "L", B: "R", D: "D" } as Record<Fold, Fold>)[f] : f;
    steps.push(foldStep(reg, sw).refl);
    reg = foldStep(reg, f).reg;
  });
  let H = holes.map((h) => h.slice());
  for (let i = folds.length - 1; i >= 0; i--) {
    if (i === skip) continue;
    const more = H.map(steps[i]);
    for (const m of more) if (!H.some((h) => h[0] === m[0] && h[1] === m[1])) H.push(m);
  }
  return H.filter(([r, c]) => r >= 0 && c >= 0 && r < G && c < G).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
}
const FOLD_PLAN: [string[], number][] = [ // per d: fold kinds (V = L|R, H = T|B, D) and holes
  [["V"], 1], [["H"], 1], [["V"], 2], [["V", "H"], 1], [["H", "V"], 1],
  [["V", "H"], 2], [["V", "V"], 1], [["H", "V"], 2], [["D"], 2], [["V", "H", "V"], 1],
];
defGen({
  id: "paperfold", sec: "SPA", a: 1.4, k: 4, minMs: 2500, maxMs: 80000,
  make(d, r, ctx) {
    const G = 4;
    const [plan, nh] = FOLD_PLAN[d - 1];
    for (let tries = 0; tries < 200; tries++) {
      const folds = plan.map((p) => (p === "V" ? r.pick(["L", "R"]) : p === "H" ? r.pick(["T", "B"]) : "D") as Fold);
      let reg: Region = [0, G - 1, 0, G - 1];
      for (const f of folds) reg = foldStep(reg, f).reg;
      const cells: number[][] = [];
      for (let a = reg[0]; a <= reg[1]; a++) for (let b = reg[2]; b <= reg[3]; b++) if (folds[0] !== "D" || b > a) cells.push([a, b]);
      if (cells.length < nh) continue;
      const holes = r.shuffle(cells).slice(0, nh);
      const ans = unfold(G, folds, holes);
      const cands: number[][][] = [];
      folds.forEach((_, i) => cands.push(unfold(G, folds, holes, i)));
      folds.forEach((_, i) => cands.push(unfold(G, folds, holes, -1, i)));
      cands.push(ans.map(([a, b]) => [a, G - 1 - b]), ans.map(([a, b]) => [G - 1 - a, b]), ans.map(([a, b]) => [b, a]), holes);
      const seen = new Set([keyOf(ans)]);
      const wrong: number[][][] = [];
      for (const c of cands) { const k = keyOf(c); if (!seen.has(k) && wrong.length < 3) { seen.add(k); wrong.push(c); } }
      if (wrong.length < 3) continue;
      const opts = r.shuffle([ans, ...wrong]);
      const ansIdx = opts.indexOf(ans);
      const nf = folds.length;
      const why = say(ctx.lang, `Unfold it in your head, last fold first. Each fold you open copies every hole to its mirror place across that fold line. ${nh === 1 ? "One hole" : `${nh} holes`} through ${2 ** nf} layers of paper make ${ans.length} holes, in the places shown.`,
        `Desdoblalo mentalmente, empezando por el último doblez. Cada doblez que abrís copia cada agujero a su lugar en espejo del otro lado de la línea del doblez. ${nh === 1 ? "Un agujero" : `${nh} agujeros`} a través de ${2 ** nf} capas de papel dan ${ans.length} agujeros, en los lugares que se ven.`);
      return mkItem(this, d, { display: { g: G, folds, holes, options: opts }, key: { t: "idx", v: ansIdx }, why });
    }
    return null;
  },
});

/* ---------------- cubenet: fold a net (4 options) ----------------
   Nets as cell lists; a face's opposite is found by rolling a die over the net. */
const NET_ROWS: string[][] = [
  ["X...", "XXXX", "X..."], ["X...", "XXXX", ".X.."], ["X...", "XXXX", "..X."], ["X...", "XXXX", "...X"],
  [".X..", "XXXX", ".X.."], [".X..", "XXXX", "..X."], // the six 1-4-1 nets
  ["XX..", ".XXX", ".X.."], ["XX..", ".XXX", "..X."], ["XX..", ".XXX", "...X"], // 2-3-1
  ["XX..", ".XX.", "..XX"], // 2-2-2
  ["XXX..", "..XXX"], // 3-3
];
export function netCells(i: number): number[][] {
  const out: number[][] = [];
  NET_ROWS[i].forEach((row, r) => [...row].forEach((ch, c) => { if (ch === "X") out.push([r, c]); }));
  return out;
}
/** For each cell (by index), the die face touching it and the face opposite (on top). */
export function foldNet(cells: number[][]): { face: number[]; up: number[] } | null {
  const face: number[] = Array(cells.length).fill(-1), up: number[] = Array(cells.length).fill(-1);
  const idx = (r: number, c: number) => cells.findIndex((x) => x[0] === r && x[1] === c);
  const visit = (i: number, s: Record<string, number>) => {
    face[i] = s.D; up[i] = s.U;
    const [r, c] = cells[i];
    const moves: [number, number, (s: Record<string, number>) => Record<string, number>][] = [
      [0, 1, (s) => ({ ...s, D: s.E, E: s.U, U: s.W, W: s.D })],
      [0, -1, (s) => ({ ...s, D: s.W, W: s.U, U: s.E, E: s.D })],
      [1, 0, (s) => ({ ...s, D: s.S, S: s.U, U: s.N, N: s.D })],
      [-1, 0, (s) => ({ ...s, D: s.N, N: s.U, U: s.S, S: s.D })],
    ];
    for (const [dr, dc, roll] of moves) { const j = idx(r + dr, c + dc); if (j >= 0 && face[j] < 0) visit(j, roll(s)); }
  };
  visit(0, { D: 0, U: 1, N: 2, S: 3, E: 4, W: 5 });
  return new Set(face).size === 6 && !face.includes(-1) ? { face, up } : null;
}
defGen({
  id: "cubenet", sec: "SPA", a: 1.4, k: 4, minMs: 2500, maxMs: 80000,
  make(d, r, ctx) {
    let cells = netCells(d <= 3 ? r.int(0, 5) : r.int(0, NET_ROWS.length - 1));
    const rot = r.int(0, 3), mir = r.chance(.5);
    for (let k = 0; k < rot; k++) cells = cells.map(([a, b]) => [b, -a]);
    if (mir) cells = cells.map(([a, b]) => [a, -b]);
    const mr = Math.min(...cells.map((x) => x[0])), mc = Math.min(...cells.map((x) => x[1]));
    cells = cells.map(([a, b]) => [a - mr, b - mc]);
    const f = foldNet(cells)!;
    const sym = r.shuffle([0, 1, 2, 3, 4, 5]); // symbol on each cell
    const opp = (i: number) => f.face.indexOf(f.up[i]); // cell index opposite cell i
    const net = cells.map(([a, b], i) => [a, b, sym[i]]);
    if (d <= 6) {
      const mark = r.int(0, 5), o = opp(mark);
      const adj = r.shuffle([0, 1, 2, 3, 4, 5].filter((i) => i !== mark && i !== o)).slice(0, 3);
      const opts = r.shuffle([o, ...adj]);
      const nm = (i: number) => SYM6[ctx.lang][sym[i]];
      const why = say(ctx.lang, `Folded up, the ${nm(o)} ends up opposite the ${nm(mark)}. A tip: in a straight line of three faces on the net, the two ends are opposite. The other options all share an edge with the ${nm(mark)}.`,
        `Al armar el cubo, ${FEM6[sym[o]] ? "la" : "el"} ${nm(o)} queda ${FEM6[sym[o]] ? "opuesta" : "opuesto"} ${FEM6[sym[mark]] ? "a la" : "al"} ${nm(mark)}. Un truco: en una fila recta de tres caras de la red, las dos de las puntas son opuestas. Las otras opciones comparten un borde con ${FEM6[sym[mark]] ? "la" : "el"} ${nm(mark)}.`);
      return mkItem(this, d, { display: { net, ask: "opp", mark: sym[mark], options: opts.map((i) => sym[i]) }, key: { t: "idx", v: opts.indexOf(o) }, why });
    }
    // three faces that meet at a corner: no two of them opposite
    const all: number[][] = [];
    for (let a = 0; a < 6; a++) for (let b = a + 1; b < 6; b++) for (let c = b + 1; c < 6; c++) all.push([a, b, c]);
    const ok = (t: number[]) => !t.some((x) => t.includes(opp(x)));
    const good = r.pick(all.filter(ok)), bad = r.shuffle(all.filter((t) => !ok(t))).slice(0, 3);
    const opts = r.shuffle([good, ...bad]);
    const pairs: string[] = [];
    for (let i = 0; i < 6; i++) if (i < opp(i)) pairs.push(`${SYM6[ctx.lang][sym[i]]} – ${SYM6[ctx.lang][sym[opp(i)]]}`);
    const why = say(ctx.lang, `Three faces can meet at a corner only if no two of them are opposite each other. The opposite pairs are ${pairs.join(", ")}. Every wrong option has one of those pairs in it.`,
      `Tres caras pueden juntarse en una esquina solo si ninguna es opuesta a otra. Los pares opuestos son ${pairs.join(", ")}. Cada opción incorrecta tiene uno de esos pares.`);
    return mkItem(this, d, { display: { net, ask: "corner", options: opts.map((t) => t.map((i) => sym[i])) }, key: { t: "idx", v: opts.indexOf(good) }, why });
  },
});

/* ---------------- gears: which way does it turn? (2 or 3 options) ----------------
   Gears {x, y, r}; links mesh (touching: opposite way), belt (same way), cross (crossed
   belt: opposite way). Gear 0 turns clockwise. A ring of an odd number of meshing gears jams. */
export interface Gear { x: number; y: number; r: number }
export interface Link { a: number; b: number; t: "mesh" | "belt" | "cross" }
export function spin(n: number, links: Link[]): number[] | null { // +1 cw, -1 ccw, null = jams
  const dir = Array(n).fill(0);
  dir[0] = 1;
  const q = [0];
  while (q.length) {
    const i = q.shift()!;
    for (const l of links) {
      if (l.a !== i && l.b !== i) continue;
      const j = l.a === i ? l.b : l.a, want = l.t === "belt" ? dir[i] : -dir[i];
      if (!dir[j]) { dir[j] = want; q.push(j); } else if (dir[j] !== want) return null;
    }
  }
  return dir;
}
defGen({
  id: "gears", sec: "SPA", a: 1.3, k: 2, minMs: 1500, maxMs: 50000,
  make(d, r, ctx) {
    const gears: Gear[] = [], links: Link[] = [];
    const row = (n: number, radii: () => number, x0 = 0) => {
      let x = x0;
      for (let i = 0; i < n; i++) {
        const rr = radii();
        if (i) { x += gears[gears.length - 1].r + rr; links.push({ a: gears.length - 1, b: gears.length, t: "mesh" }); }
        gears.push({ x, y: 0, r: rr });
      }
    };
    if (d <= 3) row([3, 4, 5][d - 1], () => (d === 3 ? r.pick([0.8, 1, 1.3]) : 1));
    else if (d <= 6) {
      row(r.int(2, 3), () => 1);
      const kinds: Link["t"][] = d === 4 ? ["belt"] : d === 5 ? ["cross"] : r.shuffle(["belt", "cross"] as Link["t"][]);
      for (const t of kinds) {
        const last = gears.length - 1, x0 = gears[last].x + 4;
        const start = gears.length;
        row(r.int(1, 2), () => 1, x0);
        links.push({ a: last, b: start, t });
      }
    } else if (d <= 8) {
      const n = d === 7 ? 5 : 7, cells: number[][] = [[0, 0]];
      for (let tries = 0; cells.length < n && tries < 500; tries++) {
        const [a, b] = cells[cells.length - 1], [da, db] = r.pick([[0, 1], [1, 0], [0, -1], [-1, 0]]);
        const nx = [a + da, b + db];
        // a path whose cells touch only their neighbours in the path
        if (cells.some((c) => Math.abs(c[0] - nx[0]) + Math.abs(c[1] - nx[1]) <= 1 && c !== cells[cells.length - 1])) continue;
        cells.push(nx);
      }
      if (cells.length < n) return null;
      cells.forEach(([a, b], i) => { gears.push({ x: b * 2, y: a * 2, r: 1 }); if (i) links.push({ a: i - 1, b: i, t: "mesh" }); });
    } else {
      const chain = d === 9 ? 2 : 3;
      for (let i = chain; i >= 1; i--) gears.push({ x: -2 * i, y: 0, r: 1 });
      const base = gears.length;
      gears.push({ x: 0, y: 0, r: 1 }, { x: 2, y: 0, r: 1 });
      const jam = r.chance(.5);
      gears.push(jam ? { x: 1, y: -Math.sqrt(3), r: 1 } : { x: 3, y: -Math.sqrt(3), r: 1 });
      for (let i = 0; i < base; i++) links.push({ a: i, b: i + 1, t: "mesh" });
      links.push({ a: base, b: base + 1, t: "mesh" }, { a: base + 1, b: base + 2, t: "mesh" });
      if (jam) links.push({ a: base, b: base + 2, t: "mesh" });
    }
    const target = gears.length - 1;
    const dir = spin(gears.length, links);
    const options = d >= 9 ? ["cw", "ccw", "jam"] : ["cw", "ccw"];
    const ans = dir ? (dir[target] > 0 ? "cw" : "ccw") : "jam";
    const way = (a: string) => say(ctx.lang, a === "cw" ? "clockwise" : "counterclockwise", a === "cw" ? "en sentido horario" : "en sentido antihorario");
    const rules = say(ctx.lang, "Gears that touch turn opposite ways.", "Los engranajes que se tocan giran en sentidos opuestos.")
      + (links.some((l) => l.t !== "mesh") ? say(ctx.lang, " A straight belt keeps the same way; a crossed belt reverses it.", " Una correa recta mantiene el sentido; una correa cruzada lo invierte.") : "");
    const why = ans === "jam"
      ? say(ctx.lang, `${rules} Here three gears all touch each other: if one turns clockwise, the next must turn counterclockwise, and the third would have to turn both ways at once. So it jams.`, `${rules} Acá hay tres engranajes que se tocan entre sí: si uno gira en sentido horario, el siguiente gira al revés, y el tercero tendría que girar para los dos lados a la vez. Por eso se traba.`)
      : say(ctx.lang, `${rules} The first gear turns clockwise; follow the chain one gear at a time and the marked gear turns ${way(ans)}.`, `${rules} El primer engranaje gira en sentido horario; seguí la cadena de a un engranaje y el marcado gira ${way(ans)}.`);
    return mkItem(this, d, { k: options.length, display: { gears, links, target, options }, key: { t: "idx", v: options.indexOf(ans) }, why });
  },
});

/* ---------------- mirror: reflect a shape (4 options) ---------------- */
const REFL: Record<string, (p: Poly) => Poly> = {
  v: (p) => pMir(p),
  h: (p) => p.map(([x, y]) => [x, -y]),
  d: (p) => p.map(([x, y]) => [y, x]),
};
defGen({
  id: "mirror", sec: "SPA", a: 1.3, k: 4, minMs: 1500, maxMs: 50000,
  make(d, r, ctx) {
    const m = [4, 5, 5, 5, 6, 6, 7, 6, 7, 8][d - 1];
    const axis = d <= 4 ? "v" : d <= 7 ? "h" : "d";
    const p = chiralPoly(m, r);
    const ans = pNorm(REFL[axis](p));
    const cands = [p, pRotN(p, 1), pRotN(p, 2), pRotN(p, 3), ...Object.keys(REFL).filter((a) => a !== axis).map((a) => REFL[a](p)), pRotN(ans, 1)];
    const seen = new Set([pKey(ans)]);
    const wrong: Poly[] = [];
    for (const c of d >= 5 ? r.shuffle(cands) : cands.slice(0, 4).concat(r.shuffle(cands.slice(4)))) {
      const k = pKey(c);
      if (!seen.has(k) && wrong.length < 3) { seen.add(k); wrong.push(pNorm(c)); }
    }
    const opts = r.shuffle([ans, ...wrong]);
    const line = say(ctx.lang, { v: "upright", h: "flat", d: "slanted" }[axis]!, { v: "vertical", h: "horizontal", d: "diagonal" }[axis]!);
    const why = say(ctx.lang, `Flip the shape across the ${line} mirror line: every square moves to the other side, the same distance from the line. The other options are the shape turned, or flipped across a different line.`,
      `Reflejá la figura sobre la línea ${line}: cada cuadradito pasa al otro lado, a la misma distancia de la línea. Las otras opciones son la figura girada o reflejada sobre otra línea.`);
    return mkItem(this, d, { display: { shape: pNorm(p), axis, options: opts }, key: { t: "idx", v: opts.indexOf(ans) }, why });
  },
});

/* ---------------- countshapes: count triangles / rectangles (typed) ----------------
   fan: n lines from the top corner (sides included) crossed by m level lines (base
   included): every triangle is 2 of the n lines + 1 of the m, so C(n,2) * m.
   grid: a x b cells: C(a+1,2) * C(b+1,2) rectangles. Line positions vary. */
const C2 = (n: number) => n * (n - 1) / 2;
defGen({
  id: "countshapes", sec: "SPA", a: 1.3, k: 0, minMs: 2500, maxMs: 80000,
  make(d, r, ctx) {
    const pos = (k: number) => { const xs = Array.from({ length: k }, (_, i) => (i + 1) / (k + 1) + (r.n() - .5) * .3 / (k + 1)); return xs.map((x) => Math.round(x * 1000) / 1000); };
    if (d <= 7) {
      const n = [3, 4, 5, r.int(3, 4), 4, 4, 5][d - 1], m = [1, 1, 1, 2, 2, 3, 3][d - 1];
      // inner apex lines meet the base at `base`; inner level lines at heights `levels` (0 top .. 1 base)
      const why = say(ctx.lang, `Every triangle uses 2 of the ${n} lines from the top corner and 1 of the ${m} line${m === 1 ? "" : "s"} across (the base counts). There are ${C2(n)} pairs of corner lines, so ${C2(n)} × ${m} = ${C2(n) * m}.`,
        `Cada triángulo usa 2 de las ${n} líneas que salen de la punta y 1 de las ${m} línea${m === 1 ? "" : "s"} que cruzan (la base cuenta). Hay ${C2(n)} pares de líneas de la punta, así que ${C2(n)} × ${m} = ${C2(n) * m}.`);
      return mkItem(this, d, { display: { kind: "fan", base: pos(n - 2), levels: pos(m - 1) }, key: { t: "num", v: C2(n) * m }, why });
    }
    const [a, b] = [[2, 2], [2, 3], [3, 3]][d - 8];
    const why = say(ctx.lang, `A rectangle is made by choosing 2 of the ${a + 1} lines across and 2 of the ${b + 1} lines up and down. That is ${C2(a + 1)} × ${C2(b + 1)} = ${C2(a + 1) * C2(b + 1)} (the small squares count too).`,
      `Un rectángulo se arma eligiendo 2 de las ${a + 1} líneas horizontales y 2 de las ${b + 1} verticales. Eso da ${C2(a + 1)} × ${C2(b + 1)} = ${C2(a + 1) * C2(b + 1)} (los cuadraditos también cuentan).`);
    return mkItem(this, d, { display: { kind: "grid", cols: pos(b - 1), rows: pos(a - 1) }, key: { t: "num", v: C2(a + 1) * C2(b + 1) }, why });
  },
});

/* ---------------- cubecount: count the cubes (typed) ----------------
   Heights never grow toward the viewer (higher row / column index is nearer), so every
   column's top shows and no cube can hide; no cube floats. d >= 8 asks how many more
   cubes make a full n x n block as tall as the tallest column. */
defGen({
  id: "cubecount", sec: "SPA", a: 1.3, k: 0, minMs: 2000, maxMs: 70000,
  make(d, r, ctx) {
    const n = d <= 3 ? 2 : d <= 6 ? 3 : 4, maxH = d <= 2 ? 2 : d <= 5 ? 3 : 4;
    const h: number[][] = [];
    for (let i = 0; i < n; i++) {
      h.push([]);
      for (let j = 0; j < n; j++) {
        const cap = Math.min(i ? h[i - 1][j] : maxH, j ? h[i][j - 1] : maxH);
        h[i].push(i + j === 0 ? r.int(Math.max(2, maxH - 1), maxH) : r.int(Math.max(0, cap - 2), cap));
      }
    }
    const sum = h.flat().reduce((a, x) => a + x, 0);
    const fill = d >= 8;
    const cols = h.flat().filter((x) => x > 0).join(" + ");
    const why = fill
      ? say(ctx.lang, `Count each column of cubes: ${cols} = ${sum}. A full ${n} × ${n} block as tall as the tallest column (${h[0][0]}) has ${n * n * h[0][0]} cubes, so ${n * n * h[0][0]} − ${sum} = ${n * n * h[0][0] - sum} more.`,
        `Contá cada columna de cubos: ${cols} = ${sum}. Un bloque lleno de ${n} × ${n} tan alto como la columna más alta (${h[0][0]}) tiene ${n * n * h[0][0]} cubos, así que faltan ${n * n * h[0][0]} − ${sum} = ${n * n * h[0][0] - sum}.`)
      : say(ctx.lang, `Count each column of cubes (every column rests on the floor, none hide): ${cols} = ${sum}.`, `Contá cada columna de cubos (todas apoyan en el piso y ninguna se esconde): ${cols} = ${sum}.`);
    return mkItem(this, d, { display: { heights: h, ask: fill ? "fill" : "count" }, key: { t: "num", v: fill ? n * n * h[0][0] - sum : sum }, why });
  },
});

/* ---------------- direction: which way are you facing? (4 options) ---------------- */
export const DIRS: Record<Lang, string[]> = {
  en: ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"],
  es: ["norte", "noreste", "este", "sureste", "sur", "suroeste", "oeste", "noroeste"],
};
export const MOVE_TXT: Record<Lang, Record<string, string>> = {
  en: { R: "turn right", L: "turn left", U: "turn around", HR: "turn 45° right", HL: "turn 45° left" },
  es: { R: "girás a la derecha", L: "girás a la izquierda", U: "te das vuelta", HR: "girás 45° a la derecha", HL: "girás 45° a la izquierda" },
};
export const MOVE_STEP: Record<string, number> = { R: 2, L: -2, U: 4, HR: 1, HL: -1 };
defGen({
  id: "direction", sec: "SPA", a: 1.2, k: 4, minMs: 1500, maxMs: 50000,
  make(d, r, ctx) {
    const n = [2, 3, 3, 4, 5, 5, 6, 4, 5, 7][d - 1];
    const kinds = d <= 2 ? ["R", "L"] : d <= 7 ? ["R", "L", "U"] : ["R", "L", "U", "HR", "HL"];
    const moves = Array.from({ length: n }, () => r.pick(kinds));
    if (d >= 8 && !moves.some((m) => m.startsWith("H"))) moves[r.int(0, n - 1)] = r.pick(["HR", "HL"]);
    const start = r.int(0, 3) * 2;
    const end = ((start + moves.reduce((s, m) => s + MOVE_STEP[m], 0)) % 8 + 8) % 8;
    const D = DIRS[ctx.lang], M = MOVE_TXT[ctx.lang];
    const cap = (s: string) => s[0].toUpperCase() + s.slice(1);
    const list = moves.map((m) => M[m]).join(ctx.lang === "es" ? ", después " : ", then ");
    const text = ctx.lang === "es" ? `Estás mirando al ${D[start]}. ${cap(list)}. ¿Hacia dónde mirás ahora?` : `You are facing ${D[start]}. You ${list}. Which way are you facing now?`;
    const optIdx = end % 2 === 0 && d < 8 ? [0, 2, 4, 6] : [end, (end + 1) % 8, (end + 7) % 8, (end + 4) % 8].sort((a, b) => a - b);
    const path: string[] = [D[start]];
    moves.reduce((at, m) => { const nx = ((at + MOVE_STEP[m]) % 8 + 8) % 8; path.push(D[nx]); return nx; }, start);
    const why = say(ctx.lang, `Follow one turn at a time: ${path.join(" → ")}.`, `Seguí un giro por vez: ${path.join(" → ")}.`);
    return mkItem(this, d, { display: { text, options: optIdx.map((i) => cap(D[i])) }, key: { t: "idx", v: optIdx.indexOf(end) }, meta: { start, moves, end }, why });
  },
});

/* ---------------- pieces: complete the square (4 options) ----------------
   An n x n square with one piece in it; which option fills the gap? d >= 8: pieces may turn. */
function connected(cells: number[][]): boolean {
  if (!cells.length) return false;
  const k = new Set(cells.map((c) => c.join(","))), seen = new Set([cells[0].join(",")]), q = [cells[0]];
  while (q.length) {
    const [a, b] = q.pop()!;
    for (const [x, y] of [[a + 1, b], [a - 1, b], [a, b + 1], [a, b - 1]]) { const s = x + "," + y; if (k.has(s) && !seen.has(s)) { seen.add(s); q.push([x, y]); } }
  }
  return seen.size === cells.length;
}
export const fitsGap = (gap: Poly, opt: Poly, turn: boolean) => (turn ? [0, 1, 2, 3] : [0]).some((k) => pKey(pRotN(opt, k)) === pKey(gap));
defGen({
  id: "pieces", sec: "SPA", a: 1.3, k: 4, minMs: 2000, maxMs: 70000,
  make(d, r, ctx) {
    const n = d <= 3 ? 3 : 4, turn = d >= 8;
    const size = n === 3 ? r.int(3, 5) : r.int(6, 9);
    const all: Poly = [];
    for (let x = 0; x < n; x++) for (let y = 0; y < n; y++) all.push([x, y]);
    for (let tries = 0; tries < 400; tries++) {
      const piece: Poly = [r.pick(all)];
      while (piece.length < size) {
        const [x, y] = r.pick(piece), [dx, dy] = r.pick([[1, 0], [-1, 0], [0, 1], [0, -1]]);
        const c: [number, number] = [x + dx, y + dy];
        if (c[0] < 0 || c[1] < 0 || c[0] >= n || c[1] >= n || piece.some((p) => p[0] === c[0] && p[1] === c[1])) continue;
        piece.push(c);
      }
      const gap = all.filter(([x, y]) => !piece.some((p) => p[0] === x && p[1] === y)) as Poly;
      if (!connected(gap)) continue;
      const cands: Poly[] = [pMir(gap), pRotN(gap, 1), pRotN(gap, 2), pRotN(pMir(gap), 1)];
      for (let k = 0; k < 6; k++) { // move one cell
        const g2 = gap.slice(), i = r.int(0, g2.length - 1), [x, y] = r.pick(g2), [dx, dy] = r.pick([[1, 0], [-1, 0], [0, 1], [0, -1]]);
        g2.splice(i, 1);
        const c: [number, number] = [x + dx, y + dy];
        if (!g2.some((p) => p[0] === c[0] && p[1] === c[1])) { g2.push(c); if (connected(g2)) cands.push(g2); }
      }
      const seen = new Set<string>(), wrong: Poly[] = [];
      for (const c of r.shuffle(cands)) {
        const k = pKey(c);
        if (seen.has(k) || fitsGap(gap, c, turn) || wrong.length >= 3) continue;
        seen.add(k); wrong.push(pNorm(c));
      }
      if (wrong.length < 3) continue;
      const shown = turn ? pNorm(pRotN(gap, r.int(1, 3))) : pNorm(gap);
      const opts = r.shuffle([shown, ...wrong]);
      const why = say(ctx.lang, `The empty part of the square has exactly the shape of the right piece${turn ? " (shown turned: turn it back to fit)" : ""}. Each other option is mirrored, turned the wrong way or has one square in a different place.`,
        `La parte vacía del cuadrado tiene exactamente la forma de la pieza correcta${turn ? " (se muestra girada: girala para que encaje)" : ""}. Cada una de las otras está espejada, girada al revés o tiene un cuadradito en otro lugar.`);
      return mkItem(this, d, { display: { n, piece: piece.map((p) => [p[0], p[1]]), turn, options: opts }, key: { t: "idx", v: opts.indexOf(shown) }, why });
    }
    return null;
  },
});
