// Seeded RNG, ported 1:1 from the prototype's mulberry32 / RNG (docs/voodoo-iq-prototype.html).
// Same seed => same sequence as the prototype, so items match it exactly.
// mulberry32's whole state is one int32 (`state`), which is what lets the server
// save an adaptive session's RNG between Edge Function calls and resume it.

export function hashStr(str: string): number {
  let x = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    x ^= str.charCodeAt(i);
    x = Math.imul(x, 16777619);
  }
  return x >>> 0;
}

export class Rng {
  /** int32 mulberry32 state; persist this to resume the sequence. */
  state: number;

  constructor(seed: number, state?: number) {
    this.state = state ?? ((seed >>> 0) | 0);
  }

  /** uniform [0, 1) */
  n(): number {
    let a = this.state | 0;
    a = (a + 0x6D2B79F5) | 0;
    this.state = a;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  int(a: number, b: number): number {
    return a + Math.floor(this.n() * (b - a + 1));
  }

  pick<T>(arr: readonly T[]): T {
    return arr[Math.floor(this.n() * arr.length)];
  }

  shuffle<T>(arr: readonly T[]): T[] {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(this.n() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  chance(p: number): boolean {
    return this.n() < p;
  }

  gauss(): number {
    let u = 0, v = 0;
    while (!u) u = this.n();
    while (!v) v = this.n();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  }

  fork(): Rng {
    return new Rng(Math.floor(this.n() * 4294967296));
  }
}

export function randomSeed(): number {
  return crypto.getRandomValues(new Uint32Array(1))[0];
}

export const utcDay = (t = Date.now()) => new Date(t).toISOString().slice(0, 10);
export const monthKey = (t = Date.now()) => new Date(t).toISOString().slice(0, 7);
export const dailySeed = (day = utcDay()) => hashStr("voodoo-daily-" + day);
