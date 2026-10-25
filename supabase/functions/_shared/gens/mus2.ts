// MUSICAL, second set (2026-10-25; NOT in the prototype): rhythm, transpose, beat,
// contour, cadence, consonance. All synthesized tones (no recordings). The client
// renders the clip from `display`, so (as with the prototype's audio items) the display
// encodes the answer. Served only to clients that send gv >= 4 (engine.ts secGens).
import { defGen, mkItem, say } from "./registry.ts";

export const MAJOR = [0, 2, 4, 5, 7, 9, 11, 12];

/* Same rhythm? Onsets on a grid of `unit` seconds; "different" moves one onset. */
defGen({
  id: "rhythm", sec: "MUS", a: 1.2, k: 2, minMs: 300, maxMs: 30000,
  make(d, r, ctx) {
    const n = [4, 5, 5, 6, 6, 7, 7, 8, 8, 9][d - 1];
    const unit = [0.19, 0.18, 0.17, 0.16, 0.15, 0.14, 0.13, 0.125, 0.12, 0.115][d - 1];
    const slots = d >= 6 ? 24 : 16;
    for (let tries = 0; tries < 200; tries++) {
      const a = [0, ...r.shuffle(Array.from({ length: slots - 1 }, (_, i) => i + 1)).slice(0, n - 1)].sort((x, y) => x - y);
      const same = r.chance(.5);
      let b = a.slice();
      let why = say(ctx.lang, "Both plays had exactly the same rhythm.", "Las dos veces el ritmo fue exactamente el mismo.");
      if (!same) {
        const i = r.int(1, n - 1), step = (d <= 3 ? 2 : d <= 7 ? r.pick([1, 2]) : 1) * (r.chance(.5) ? 1 : -1);
        const x = a[i] + step;
        if (x <= 0 || x >= slots || a.includes(x)) continue;
        b[i] = x;
        b = b.sort((p, q) => p - q);
        const ms = Math.round(Math.abs(step) * unit * 1000);
        why = say(ctx.lang, `In the second play, beat ${i + 1} of ${n} came ${ms} ms ${step > 0 ? "later" : "earlier"}. Everything else was the same.`, `En la segunda vez, el golpe ${i + 1} de ${n} llegó ${ms} ms ${step > 0 ? "más tarde" : "antes"}. Todo lo demás fue igual.`);
      }
      return mkItem(this, d, { deferTimer: true, display: { a, b, unit, slots }, key: { t: "idx", v: same ? 0 : 1 }, why });
    }
    return null;
  },
});

/* Same tune in a new key? The second play is moved up; "different" also changes one note. */
defGen({
  id: "transpose", sec: "MUS", a: 1.3, k: 2, minMs: 300, maxMs: 30000,
  make(d, r, ctx) {
    const n = [4, 4, 5, 5, 6, 6, 7, 7, 8, 8][d - 1];
    for (let tries = 0; tries < 200; tries++) {
      const base = r.int(55, 64);
      const deg = [r.int(0, 4)];
      while (deg.length < n) { const x = deg[deg.length - 1] + r.pick([-2, -1, 1, 2]); if (x >= 0 && x <= 7 && x !== deg[deg.length - 1]) deg.push(x); }
      const a = deg.map((x) => base + MAJOR[x]);
      const k = r.pick([3, 4, 5, 7]);
      const b = a.map((x) => x + k);
      const same = r.chance(.5);
      let why = say(ctx.lang, `The second play was the same tune moved up ${k} semitones: every note moved by the same amount, so it is the same tune.`, `La segunda vez fue la misma melodía subida ${k} semitonos: todas las notas se movieron lo mismo, así que es la misma melodía.`);
      if (!same) {
        const i = r.int(1, n - 1), step = (d <= 4 ? 2 : 1) * (r.chance(.5) ? 1 : -1);
        const y = b[i] + step;
        // at the top levels the change keeps the tune's up / down shape
        if (d >= 8 && (Math.sign(y - b[i - 1]) !== Math.sign(b[i] - b[i - 1]) || (i < n - 1 && Math.sign(b[i + 1] - y) !== Math.sign(b[i + 1] - b[i])))) continue;
        if (y === b[i - 1] || (i < n - 1 && y === b[i + 1])) continue;
        b[i] = y;
        why = say(ctx.lang, `The second play was moved up ${k} semitones, but note ${i + 1} moved ${Math.abs(step)} more semitone${Math.abs(step) === 1 ? "" : "s"} ${step > 0 ? "up" : "down"}, so the tune changed.`, `La segunda vez estaba subida ${k} semitonos, pero la nota ${i + 1} se movió ${Math.abs(step)} semitono${Math.abs(step) === 1 ? "" : "s"} más ${step > 0 ? "arriba" : "abajo"}, así que la melodía cambió.`);
      }
      return mkItem(this, d, { deferTimer: true, display: { notes1: a, notes2: b }, key: { t: "idx", v: same ? 0 : 1 }, why });
    }
    return null;
  },
});

/* On the beat? A drum keeps time; a click plays with it, or a little late / early. */
defGen({
  id: "beat", sec: "MUS", a: 1.2, k: 2, minMs: 300, maxMs: 30000,
  make(d, r, ctx) {
    const off = [0.15, 0.12, 0.1, 0.08, 0.065, 0.055, 0.045, 0.038, 0.032, 0.028][d - 1];
    const on = r.chance(.5);
    const interval = r.pick([0.5, 0.55, 0.6]);
    const offset = on ? 0 : off * (r.chance(.6) ? 1 : -1), ms = Math.round(Math.abs(offset) * 1000);
    const why = on ? say(ctx.lang, "The click landed exactly on every drum beat.", "El clic cayó justo en cada golpe del tambor.")
      : say(ctx.lang, `The click came ${ms} ms ${offset > 0 ? "after" : "before"} every drum beat.`, `El clic sonó ${ms} ms ${offset > 0 ? "después" : "antes"} de cada golpe del tambor.`);
    return mkItem(this, d, { deferTimer: true, display: { interval, beats: 8, offset }, key: { t: "idx", v: on ? 0 : 1 }, why });
  },
});

/* Draw the tune: which line has the melody's up / down shape? Wrong lines flip one step. */
defGen({
  id: "contour", sec: "MUS", a: 1.2, k: 4, minMs: 300, maxMs: 30000,
  make(d, r, ctx) {
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
      const arrows = steps.map((s) => (s > 0 ? "↑" : "↓")).join(" ");
      const why = say(ctx.lang, `From note to note the tune went ${arrows}. Only the right line has that shape; each wrong line turns one step the other way.`, `De nota a nota la melodía fue ${arrows}. Solo la línea correcta tiene esa forma; cada línea incorrecta da vuelta un paso.`);
      return mkItem(this, d, { deferTimer: true, display: { notes, options: opts }, key: { t: "idx", v: ans }, why });
    }
    return null;
  },
});

/* Does it end? After the key's chord, two phrases that differ only in their last note;
   one ends on the key note. Harder: the other ends on a note of the key chord. */
defGen({
  id: "cadence", sec: "MUS", a: 1.1, k: 2, minMs: 300, maxMs: 30000,
  make(d, r, ctx) {
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
        why: say(ctx.lang, `Phrase ${first ? 1 : 2} ends on the home note of the key (the note the opening chord is built on), so it sounds finished. The other stops on a different note and sounds like it should go on.`,
          `La frase ${first ? 1 : 2} termina en la nota base de la tonalidad (la nota sobre la que se arma el acorde del principio), por eso suena terminada. La otra se detiene en otra nota y suena como si tuviera que seguir.`),
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
  make(d, r, ctx) {
    const t = d <= 3 ? 0 : d <= 6 ? 1 : d <= 8 ? 2 : 3;
    const r1 = r.int(52, 62), r2 = r.int(52, 62);
    const smooth = r.pick(CONS[t]).map((x) => x + r1);
    const rough = r.pick(DIS[t]).map((x) => x + r2);
    const first = r.chance(.5);
    let clash = 0;
    for (const x of rough) for (const y of rough) if (y > x && ROUGH.has((y - x) % 12) && !clash) clash = (y - x) % 12;
    const name = say(ctx.lang, { 1: "a semitone", 2: "a whole tone", 6: "a tritone", 10: "a minor seventh", 11: "a major seventh" }[clash]!, { 1: "un semitono", 2: "un tono", 6: "un tritono", 10: "una séptima menor", 11: "una séptima mayor" }[clash]!);
    const why = say(ctx.lang, `Chord ${first ? 1 : 2} has no clashing notes. The other has two notes ${name} apart, which rubs and sounds rough.`, `El acorde ${first ? 1 : 2} no tiene notas que choquen. El otro tiene dos notas a ${name} de distancia, que roza y suena áspero.`);
    return mkItem(this, d, { deferTimer: true, display: { chord1: first ? smooth : rough, chord2: first ? rough : smooth }, key: { t: "idx", v: first ? 0 : 1 }, why });
  },
});
