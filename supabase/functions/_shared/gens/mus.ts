// MUSICAL: pitch, pitchhl, melody, chord. Ported 1:1 from the prototype.
// The client synthesizes the tones from these params (prototype: Web Audio, triangle
// waves; chords use sawtooth at volume 0.11). Audio items must reveal their pitches
// to be playable, so their display necessarily encodes the answer.
import { clamp } from "../irt.ts";
import { defGen, mkItem, say } from "./registry.ts";

defGen({
  id: "pitch", sec: "MUS", a: 1.3, k: 3, minMs: 300, maxMs: 20000,
  make(d, r, ctx) {
    const cents = [200, 120, 80, 50, 35, 25, 18, 13, 10, 7][d - 1];
    const f = r.int(300, 650), odd = r.int(0, 2), up = r.chance(.5);
    const fo = f * Math.pow(2, (up ? 1 : -1) * cents / 1200);
    return mkItem(this, d, {
      deferTimer: true,
      // tones at t0 + i*0.75 s, 0.45 s each
      display: { freqs: [0, 1, 2].map((i) => i === odd ? fo : f), autoplay: ctx.blitz, replays: ctx.blitz ? 0 : 1 },
      key: { t: "idx", v: odd },
      why: say(ctx.lang, `Tone ${odd + 1} was a little ${up ? "higher" : "lower"} than the other two: ${cents} cents (100 cents is one piano key).`,
        `El sonido ${odd + 1} era un poco más ${up ? "agudo" : "grave"} que los otros dos: ${cents} cents (100 cents son una tecla del piano).`),
    });
  },
});
defGen({
  id: "pitchhl", sec: "MUS", a: 1.1, k: 2, minMs: 200, maxMs: 12000, w: 2,
  make(d, r, ctx) {
    const cents = r.int(60, 160), f = r.int(300, 650), up = r.chance(.5);
    const f2 = f * Math.pow(2, (up ? 1 : -1) * cents / 1200);
    const ans = up ? 0 : 1;
    // tones at t0 and t0 + 0.6 s, 0.4 s each, autoplay, no replay
    const why = say(ctx.lang, `The second tone was ${up ? "higher" : "lower"} than the first, by ${cents} cents (100 cents is one piano key).`, `El segundo sonido era más ${up ? "agudo" : "grave"} que el primero, por ${cents} cents (100 cents son una tecla del piano).`);
    return mkItem(this, d, { deferTimer: true, display: { f1: f, f2, autoplay: true, replays: 0 }, key: { t: "idx", v: ans }, why });
  },
});
defGen({
  id: "melody", sec: "MUS", a: 1.3, k: 5, minMs: 300, maxMs: 25000,
  make(d, r, ctx) {
    const n = [3, 4, 4, 5, 5, 6, 6, 7, 8, 9][d - 1];
    const scale = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16];
    let base = 0, idx: number[] = [], q = 0, idx2: number[] = [];
    // Deviation from the prototype (its only one): the prototype keeps its 50th failed
    // attempt when no note can change validly (~1 in 100,000 items at d = 8: a melody
    // running straight up to the top of the scale), leaving both plays identical and no
    // correct option. Here the melody is rebuilt instead; every item the prototype makes
    // correctly is unchanged, draw for draw.
    for (let attempt = 0; attempt < 20; attempt++) {
      base = r.int(57, 64);
      idx = [r.int(2, 6)];
      while (idx.length < n) { let x = idx[idx.length - 1] + r.pick([-2, -1, 1, 2, 3, -3]); x = clamp(x, 0, scale.length - 1); if (x !== idx[idx.length - 1]) idx.push(x); }
      let found = false;
      for (let tr = 0; tr < 50; tr++) {
        q = r.int(1, n - 1);
        const step = d <= 4 ? r.pick([2, 3, -2, -3]) : d <= 7 ? r.pick([1, 2, -1, -2]) : r.pick([1, -1]);
        idx2 = idx.slice();
        idx2[q] = clamp(idx[q] + step, 0, scale.length - 1);
        if (idx2[q] === idx[q] || idx2[q] === idx[q - 1] || (q < n - 1 && idx2[q] === idx[q + 1])) continue;
        if (d >= 8) {
          const sg = (a: number, b: number) => Math.sign(b - a);
          const keep = sg(idx[q - 1], idx[q]) === sg(idx2[q - 1], idx2[q]) && (q === n - 1 || sg(idx[q], idx[q + 1]) === sg(idx2[q], idx2[q + 1]));
          if (!keep) continue;
        }
        found = true;
        break;
      }
      if (found) break;
    }
    const nd = 0.34, gap = 0.08;
    return mkItem(this, d, {
      k: n, deferTimer: true,
      // MIDI notes; second play starts 0.9 s after the first ends
      display: { notes1: idx.map((x) => base + scale[x]), notes2: idx2.map((x) => base + scale[x]), noteDur: nd, gap, replays: ctx.blitz ? 0 : 1 },
      key: { t: "idx", v: q },
      why: say(ctx.lang, `Note ${q + 1} of ${n} changed: in the second play it was ${idx2[q] > idx[q] ? "higher" : "lower"}. Every other note stayed the same.`,
        `Cambió la nota ${q + 1} de ${n}: en la segunda vez sonó más ${idx2[q] > idx[q] ? "aguda" : "grave"}. Las demás notas fueron iguales.`),
    });
  },
});
defGen({
  id: "chord", sec: "MUS", a: 1.2, k: 4, minMs: 300, maxMs: 20000,
  make(d, r, ctx) {
    const kmax = d <= 3 ? 3 : 4, kk = r.int(1, kmax);
    const minGap = d <= 3 ? 5 : d <= 7 ? 3 : 3, consonant = d >= 8;
    let notes: number[] = [];
    for (let tr = 0; tr < 100; tr++) {
      const root = r.int(52, 64);
      if (consonant) { const tri = r.pick([[0, 4, 7, 12], [0, 3, 7, 12], [0, 4, 7, 11], [0, 5, 9, 12]]); notes = r.shuffle(tri).slice(0, kk).map((x) => root + x); }
      else { notes = [root]; while (notes.length < kk) notes.push(notes[notes.length - 1] + r.int(minGap, minGap + 5)); }
      break;
    }
    const ans = kk - 1;
    // MIDI notes played together for 1.1 s; options are "1".."4"
    const why = say(ctx.lang, `${kk} different note${kk === 1 ? " was" : "s were"} played at the same time.${consonant ? " Notes that blend well are the hardest to tell apart." : ""}`,
      `Sonaron ${kk} nota${kk === 1 ? "" : "s"} distinta${kk === 1 ? "" : "s"} a la vez.${consonant ? " Las notas que combinan bien son las más difíciles de separar." : ""}`);
    return mkItem(this, d, { deferTimer: true, display: { notes, replays: ctx.blitz ? 0 : 1 }, key: { t: "idx", v: ans }, why });
  },
});
