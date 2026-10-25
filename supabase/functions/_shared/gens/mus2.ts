// MUSICAL, second set (2026-10-25; NOT in the prototype): rhythm, transpose, beat,
// contour, cadence, consonance. All synthesized tones (no recordings). The client
// renders the clip from `display`, so (as with the prototype's audio items) the display
// encodes the answer. Served only to clients that send gv >= 4 (engine.ts secGens).
import { defGen, mkItem } from "./registry.ts";

export const MAJOR = [0, 2, 4, 5, 7, 9, 11, 12];

/* Same rhythm? Onsets on a grid of `unit` seconds; "different" moves one onset. */
defGen({
  id: "rhythm", sec: "MUS", a: 1.2, k: 2, minMs: 300, maxMs: 30000,
  make(d, r) {
    const n = [4, 5, 5, 6, 6, 7, 7, 8, 8, 9][d - 1];
    const unit = [0.19, 0.18, 0.17, 0.16, 0.15, 0.14, 0.13, 0.125, 0.12, 0.115][d - 1];
    const slots = d >= 6 ? 24 : 16;
    for (let tries = 0; tries < 200; tries++) {
      const a = [0, ...r.shuffle(Array.from({ length: slots - 1 }, (_, i) => i + 1)).slice(0, n - 1)].sort((x, y) => x - y);
      const same = r.chance(.5);
      let b = a.slice();
      if (!same) {
        const i = r.int(1, n - 1), step = (d <= 3 ? 2 : d <= 7 ? r.pick([1, 2]) : 1) * (r.chance(.5) ? 1 : -1);
        const x = a[i] + step;
        if (x <= 0 || x >= slots || a.includes(x)) continue;
        b[i] = x;
        b = b.sort((p, q) => p - q);
      }
      return mkItem(this, d, { deferTimer: true, display: { a, b, unit, slots }, key: { t: "idx", v: same ? 0 : 1 } });
    }
    return null;
  },
});

/* Same tune in a new key? The second play is moved up; "different" also changes one note. */
defGen({
  id: "transpose", sec: "MUS", a: 1.3, k: 2, minMs: 300, maxMs: 30000,
  make(d, r) {
    const n = [4, 4, 5, 5, 6, 6, 7, 7, 8, 8][d - 1];
    for (let tries = 0; tries < 200; tries++) {
      const base = r.int(55, 64);
      const deg = [r.int(0, 4)];
      while (deg.length < n) { const x = deg[deg.length - 1] + r.pick([-2, -1, 1, 2]); if (x >= 0 && x <= 7 && x !== deg[deg.length - 1]) deg.push(x); }
      const a = deg.map((x) => base + MAJOR[x]);
      const k = r.pick([3, 4, 5, 7]);
      const b = a.map((x) => x + k);
      const same = r.chance(.5);
      if (!same) {
        const i = r.int(1, n - 1), step = (d <= 4 ? 2 : 1) * (r.chance(.5) ? 1 : -1);
        const y = b[i] + step;
        // at the top levels the change keeps the tune's up / down shape
        if (d >= 8 && (Math.sign(y - b[i - 1]) !== Math.sign(b[i] - b[i - 1]) || (i < n - 1 && Math.sign(b[i + 1] - y) !== Math.sign(b[i + 1] - b[i])))) continue;
        if (y === b[i - 1] || (i < n - 1 && y === b[i + 1])) continue;
        b[i] = y;
      }
      return mkItem(this, d, { deferTimer: true, display: { notes1: a, notes2: b }, key: { t: "idx", v: same ? 0 : 1 } });
    }
    return null;
  },
});

/* On the beat? A drum keeps time; a click plays with it, or a little late / early. */
defGen({
  id: "beat", sec: "MUS", a: 1.2, k: 2, minMs: 300, maxMs: 30000,
  make(d, r) {
    const off = [0.15, 0.12, 0.1, 0.08, 0.065, 0.055, 0.045, 0.038, 0.032, 0.028][d - 1];
    const on = r.chance(.5);
    const interval = r.pick([0.5, 0.55, 0.6]);
    return mkItem(this, d, { deferTimer: true, display: { interval, beats: 8, offset: on ? 0 : off * (r.chance(.6) ? 1 : -1) }, key: { t: "idx", v: on ? 0 : 1 } });
  },
});

/* Draw the tune: which line has the melody's up / down shape? Wrong lines flip one step. */
defGen({
  id: "contour", sec: "MUS", a: 1.2, k: 4, minMs: 300, maxMs: 30000,
  make(d, r) {
    const n = [4, 4, 5, 5, 5, 6, 6, 7, 7, 8][d - 1];
    const [lo, hi] = d <= 3 ? [3, 5] : d <= 7 ? [2, 4] : [1, 2];
    for (let tries = 0; tries < 200; tries++) {
      const steps = Array.from({ length: n - 1 }, () => r.int(lo, hi) * (r.chance(.5) ? 1 : -1));
      const notes = [r.int(60, 67)];
      for (const s of steps) notes.push(notes[notes.length - 1] + s);
      if (Math.max(...notes) - Math.min(...notes) > 16) continue;
      const heights = (st: number[]) => st.reduce((h, s) => (h.push(h[h.length - 1] + s), h), [0]);
      const flips = r.shuffle(steps.map((_, i) => i)).slice(0, 3);
      const wrong = flips.map((i) => heights(steps.map((s, j) => (j === i ? -s : s))));
      const opts = r.shuffle([heights(steps), ...wrong]);
      const ans = opts.findIndex((h) => h.every((x, i) => x === heights(steps)[i]));
      return mkItem(this, d, { deferTimer: true, display: { notes, options: opts }, key: { t: "idx", v: ans } });
    }
    return null;
  },
});

/* Does it end? After the key's chord, two phrases that differ only in their last note;
   one ends on the key note. Harder: the other ends on a note of the key chord. */
defGen({
  id: "cadence", sec: "MUS", a: 1.1, k: 2, minMs: 300, maxMs: 30000,
  make(d, r) {
    const root = r.int(57, 65);
    const len = d <= 3 ? 4 : d <= 7 ? 5 : 6;
    for (let tries = 0; tries < 200; tries++) {
      const deg = [r.int(2, 5)];
      while (deg.length < len) { const x = deg[deg.length - 1] + r.pick([-2, -1, 1, 2]); if (x >= 1 && x <= 6 && x !== deg[deg.length - 1]) deg.push(x); }
      const last = deg[deg.length - 1];
      if (last !== 1 && last !== 6) continue; // lead into the key note: from the 2nd, or the 7th up to the octave
      const home = last === 1 ? 0 : 7;
      const away = (d <= 3 ? [3, 5] : d <= 7 ? [1, 6] : [2, 4]).filter((x) => x !== last);
      const end2 = r.pick(away);
      const pre = deg.map((x) => root + MAJOR[x]);
      const good = [...pre, root + MAJOR[home]], bad = [...pre, root + MAJOR[end2]];
      const first = r.chance(.5);
      return mkItem(this, d, {
        deferTimer: true,
        display: { chord: [root, root + 4, root + 7], a: first ? good : bad, b: first ? bad : good },
        key: { t: "idx", v: first ? 0 : 1 }, meta: { root },
      });
    }
    return null;
  },
});

/* Smooth or clashing? Two chords; exactly one has no rough interval (semitone, whole
   tone, tritone, minor or major 7th, counted within the octave). */
export const ROUGH = new Set([1, 2, 6, 10, 11]);
const CONS: number[][][] = [[[0, 12], [0, 7]], [[0, 3], [0, 4], [0, 5], [0, 8], [0, 9]], [[0, 4, 7], [0, 3, 7], [0, 5, 9], [0, 3, 8]], [[0, 4, 7, 12], [0, 3, 7, 12], [0, 5, 9, 12]]];
const DIS: number[][][] = [[[0, 1], [0, 11]], [[0, 1], [0, 2], [0, 6], [0, 10], [0, 11]], [[0, 1, 5], [0, 6, 10], [0, 2, 3], [0, 6, 11]], [[0, 1, 4, 7], [0, 4, 6, 10], [0, 2, 7, 8]]];
defGen({
  id: "consonance", sec: "MUS", a: 1.1, k: 2, minMs: 300, maxMs: 30000,
  make(d, r) {
    const t = d <= 3 ? 0 : d <= 6 ? 1 : d <= 8 ? 2 : 3;
    const r1 = r.int(52, 62), r2 = r.int(52, 62);
    const smooth = r.pick(CONS[t]).map((x) => x + r1);
    const rough = r.pick(DIS[t]).map((x) => x + r2);
    const first = r.chance(.5);
    return mkItem(this, d, { deferTimer: true, display: { chord1: first ? smooth : rough, chord2: first ? rough : smooth }, key: { t: "idx", v: first ? 0 : 1 } });
  },
});
