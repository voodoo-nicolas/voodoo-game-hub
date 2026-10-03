// Psychometrics: 3PL IRT, EAP, person-fit, session combining, composites, type-2 AUC.
// Ported 1:1 from the prototype's `IRT` object (docs/voodoo-iq-prototype.html, spec §3).

export const clamp = (x: number, a: number, b: number) => Math.max(a, Math.min(b, x));
export const sum = (a: number[]) => a.reduce((x, y) => x + y, 0);

export interface IrtResp { a: number; b: number; c: number; u: number }
export interface Estimate { theta: number; se: number; n: number }

/** EAP grid -4..4 step 0.05 with a N(0,1) log-prior. */
export const GRID: number[] = [];
export const LPRIOR: number[] = [];
for (let i = 0; i <= 160; i++) {
  const x = -4 + i * 0.05;
  GRID.push(x);
  LPRIOR.push(-x * x / 2);
}

export const p3 = (th: number, a: number, b: number, c: number) => c + (1 - c) / (1 + Math.exp(-a * (th - b)));

/** difficulty level 1..10 -> b on the theta scale (-2.5 .. +3.0) */
export const bOf = (d: number) => -2.5 + (d - 1) * (5.5 / 9);
export const dOf = (th: number) => clamp(Math.round((th + 2.5) / (5.5 / 9) + 1), 1, 10);

/** EAP with N(0,1) prior. */
export function eap(resp: IrtResp[]): Estimate {
  const G = GRID, L = LPRIOR.slice();
  for (const r of resp) {
    for (let i = 0; i < G.length; i++) {
      const p = clamp(p3(G[i], r.a, r.b, r.c), 1e-6, 1 - 1e-6);
      L[i] += r.u ? Math.log(p) : Math.log(1 - p);
    }
  }
  let m = -Infinity;
  for (const l of L) if (l > m) m = l;
  let sw = 0, mean = 0;
  const w = L.map((l) => Math.exp(l - m));
  for (let i = 0; i < G.length; i++) { sw += w[i]; mean += G[i] * w[i]; }
  mean /= sw;
  let v = 0;
  for (let i = 0; i < G.length; i++) v += (G[i] - mean) ** 2 * w[i];
  return { theta: mean, se: Math.sqrt(v / sw), n: resp.length };
}

/** Standardized log-likelihood person-fit (lz). Very negative = aberrant pattern. */
export function lz(resp: IrtResp[], th: number): number {
  let l = 0, E = 0, V = 0;
  for (const r of resp) {
    const p = clamp(p3(th, r.a, r.b, r.c), 1e-6, 1 - 1e-6);
    l += r.u ? Math.log(p) : Math.log(1 - p);
    E += p * Math.log(p) + (1 - p) * Math.log(1 - p);
    V += p * (1 - p) * Math.log(p / (1 - p)) ** 2;
  }
  return V > 0 ? (l - E) / Math.sqrt(V) : 0;
}

export interface Combinable { theta: number; se: number; n?: number; hard?: number }

/** Combine several sessions' posteriors without counting the N(0,1) prior twice.
 *  Each posterior ~ N(theta, se^2) = prior x likelihood; likelihood precision = 1/se^2 - 1. */
export function combine(list: Combinable[]) {
  let lam = 0, S = 0, n = 0, hard = 0;
  for (const x of list) {
    const P = 1 / (x.se * x.se);
    lam += Math.max(0, P - 1);
    S += x.theta * P;
    n += x.n || 0;
    hard += x.hard || 0;
  }
  const Pt = 1 + lam;
  return { theta: S / Pt, se: 1 / Math.sqrt(Pt), n, hard };
}

/** Composite of correlated section z-scores (WAIS-style): sum, then re-standardize.
 *  r = assumed mean intercorrelation. */
export function composite(list: { theta: number; se: number }[], r = 0.5) {
  const k = list.length;
  if (!k) return null;
  const den = Math.sqrt(k + k * (k - 1) * r);
  return { theta: sum(list.map((x) => x.theta)) / den, se: Math.sqrt(sum(list.map((x) => x.se * x.se))) / den };
}

/** Type-2 ROC area (metacognitive resolution) with Hanley-McNeil SE. */
export function auc2(rows: { u: number; conf: number }[]) {
  const C = rows.filter((r) => r.u).map((r) => r.conf), W = rows.filter((r) => !r.u).map((r) => r.conf);
  if (!C.length || !W.length) return null;
  let s = 0;
  for (const a of C) for (const b of W) s += a > b ? 1 : a === b ? 0.5 : 0;
  const A = s / (C.length * W.length), n1 = C.length, n2 = W.length;
  const Q1 = A / (2 - A), Q2 = 2 * A * A / (1 + A);
  const se = Math.sqrt(Math.max(1e-6, (A * (1 - A) + (n1 - 1) * (Q1 - A * A) + (n2 - 1) * (Q2 - A * A)) / (n1 * n2)));
  return { A, se };
}

export const IQ = (th: number) => 100 + 15 * th;

export function normCdf(z: number): number {
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989423 * Math.exp(-z * z / 2);
  const p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
  return z > 0 ? 1 - p : p;
}

/** Ranking gates (spec §3). */
export const GATE = { minItems: 15, seBoard: 0.45, seCore: 0.40, seGenius: 0.30, hardGenius: 3, lzFlag: -2.5 };
