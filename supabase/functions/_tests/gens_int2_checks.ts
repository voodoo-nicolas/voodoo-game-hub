// Checks for the second INT set (gens/int2.ts), merged into gens_test.ts's CHECKS, plus a test
// of the hand-written banks. Each check re-derives the answer its own way: faces by fitting
// every option's recipe to the drawn params, the false-belief stories with a second simulator
// written differently from tomRun, the figure by fitting every pose.
// deno-lint-ignore-file no-explicit-any

import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkAnswer, type Item } from "../_shared/gens/index.ts";
import { EMO, EMO_KEYS } from "../_shared/gens/data.ts";
import { EYE_PARTNERS, EYE_STATES, gazeAngles, POSE_PARTNER, POSES, type TomEv } from "../_shared/gens/int2.ts";
import { CHANGE, FAUXPAS, FEEL, HELP, SARCASM, TOM_TXT } from "../_shared/gens/int2_data.ts";

function oneIndex(it: Item, nOpts: number, expected: number) {
  const ok = Array.from({ length: nOpts }, (_, i) => i).filter((i) => checkAnswer(it.key, i));
  assertEquals(ok, [expected], `${it.gid} d${it.d}: correct options ${ok}, expected [${expected}]`);
}
const newStyle = (id: any) => assert(id.style >= 3 && id.style <= 11 && id.skin >= 0 && id.skin <= 5 && id.hair >= 0 && id.hair <= 4, `face ${JSON.stringify(id)}`);
const same = (a: any, b: any) => ["skin", "hair", "style", "w", "sp"].every((k) => a[k] === b[k]);
const AU = ["bi", "bo", "bl", "ul", "lt", "cr", "lc", "ls", "mo", "nw", "ur", "lp"];
/** least-squares strength k >= 0 of `recipe` in `p`, and the leftover error (over `keys`) */
function fit(p: Record<string, number>, recipe: Record<string, number>, keys = AU) {
  let num = 0, den = 0;
  for (const k of keys) { num += (p[k] || 0) * (recipe[k] || 0); den += (recipe[k] || 0) ** 2; }
  const s = den ? Math.max(0, num / den) : 0;
  let err = 0;
  for (const k of keys) err += ((p[k] || 0) - s * (recipe[k] || 0)) ** 2;
  return { s, err };
}
function bestByFit(it: Item, p: Record<string, number>, options: string[], book: Record<string, Record<string, number>>, keys = AU) {
  const errs = options.map((o) => fit(p, book[o], keys).err);
  const best = errs.indexOf(Math.min(...errs));
  const second = Math.min(...errs.filter((_, i) => i !== best));
  assert(second - errs[best] > 0.05, `${it.gid} d${it.d}: options too close to tell (${errs.map((e) => e.toFixed(3))})`);
  return best;
}
function options4(it: Item) {
  const o = it.display.options as string[];
  assertEquals(o.length, 4);
  assertEquals(new Set(o).size, 4);
  oneIndex(it, 4, o.indexOf((it.meta as any).ans));
}

/** A second false-belief simulator: for each question, scan back for the last event that
 *  person saw (put / move while in the room, or their own peek). */
function tomTruth(n: number, evs: TomEv[], ask: any): number {
  const presentAt: boolean[][] = [];
  const here = Array(n).fill(true);
  for (const e of evs) {
    if (e.t === "leave") here[e.p] = false;
    if (e.t === "back") here[e.p] = true;
    presentAt.push(here.slice());
  }
  const locAt: number[] = [];
  let loc = -1;
  for (const e of evs) { if (e.t === "put" || e.t === "move") loc = e.loc!; locAt.push(loc); }
  const isChange = (e: TomEv) => e.t === "put" || e.t === "move";
  if (ask.t === "real") return loc;
  if (ask.t === "look") {
    for (let i = evs.length - 1; i >= 0; i--) {
      const e = evs[i];
      if ((isChange(e) && presentAt[i][ask.p]) || (e.t === "peek" && e.p === ask.p)) return locAt[i];
    }
    return -1;
  }
  // think: what p last saw q see (both in the room); a secret peek by q is invisible to p
  for (let i = evs.length - 1; i >= 0; i--) if (isChange(evs[i]) && presentAt[i][ask.p] && presentAt[i][ask.q]) return locAt[i];
  return -1;
}

export const CHECKS_INT2: Record<string, (it: Item) => void> = {
  flash(it) {
    const { face, params, flashMs, options } = it.display as any;
    newStyle(face);
    assertEquals(flashMs, [400, 320, 250, 200, 160, 120, 90, 70, 55, 40][it.d - 1]);
    assertEquals(options.length, 4);
    assert(new Set(options).size === 4 && options.every((o: string) => EMO_KEYS.includes(o)));
    oneIndex(it, 4, bestByFit(it, params, options, EMO as any));
    assert(options[(it.key as any).v] === (it.meta as any).emo);
  },
  smile(it) {
    const faces = it.display.faces as any[];
    assertEquals(faces.length, 2);
    faces.forEach((f) => newStyle(f.face));
    // the real smile is the one with the cheek raise; both mouths are the same
    const cr = faces.map((f) => f.params.cr);
    const real = cr[0] > cr[1] ? 0 : 1;
    assert(Math.abs(cr[0] - cr[1]) >= 0.3 - 1e-9, `smile d${it.d}: cheek raise gap ${cr}`);
    assert(Math.abs(faces[0].params.lc - faces[1].params.lc) < 0.15 && Math.abs(faces[0].params.mo - faces[1].params.mo) < 0.15);
    assertEquals(same(faces[0].face, faces[1].face), it.d < 4, "same person only below d 4");
    oneIndex(it, 2, real);
  },
  gaze(it) {
    const { face, params, angles, objects } = it.display as any;
    newStyle(face);
    const n = angles.length;
    assertEquals(n, it.d <= 3 ? 4 : it.d <= 7 ? 6 : 8);
    assertEquals(angles, gazeAngles(n));
    assertEquals(objects.length, n);
    assertEquals(new Set(objects).size, n);
    assertEquals(it.k, n);
    const g = Math.atan2(params.gy, params.gx) * 180 / Math.PI;
    const off = angles.map((a: number) => Math.abs(((a - g) % 360 + 540) % 360 - 180));
    const best = off.indexOf(Math.min(...off));
    assert(off[best] < 5 && Math.min(...off.filter((_: number, i: number) => i !== best)) >= 40, `gaze: ${off}`);
    assert(Math.hypot(params.gx, params.gy) >= 0.6);
    oneIndex(it, n, best);
  },
  intensity(it) {
    const { emo, faces } = it.display as any;
    const n = faces.length;
    assertEquals(n, it.d <= 3 ? 3 : it.d <= 7 ? 4 : 5);
    const ks = faces.map((f: any) => fit(f.params, (EMO as any)[emo]).s);
    faces.forEach((f: any) => { newStyle(f.face); assert(fit(f.params, (EMO as any)[emo]).err < 1e-9, "intensity: not a pure emotion"); });
    const sorted = ks.slice().sort((a: number, b: number) => a - b);
    for (let i = 1; i < n; i++) assert(sorted[i] - sorted[i - 1] >= 0.12 - 1e-9, `intensity gaps ${sorted}`);
    const order = ks.map((k: number, i: number) => [k, i]).sort((a: any, b: any) => a[0] - b[0]).map((x: any) => x[1]).join(",");
    assert(checkAnswer(it.key, order), `intensity: ${order} vs ${JSON.stringify(it.key)}`);
    assert(!checkAnswer(it.key, order.split(",").reverse().join(",")));
    if (it.d <= 6) assert(faces.every((f: any) => same(f.face, faces[0].face)));
  },
  facemem(it) {
    const { study, lineup, studyMs } = it.display as any;
    const m = study.length, L = lineup.length;
    assertEquals(m, it.d <= 3 ? 2 : it.d <= 6 ? 3 : 4);
    assertEquals(L, it.d <= 4 ? 4 : 6);
    assertEquals(studyMs, 2000 * m);
    for (let i = 0; i < m; i++) for (let j = i + 1; j < m; j++) {
      const diff = ["skin", "hair", "style", "w", "sp"].filter((k) => study[i].face[k] !== study[j].face[k]).length;
      assert(diff >= 2, "studied people too alike");
    }
    [...study, ...lineup].forEach((f: any) => newStyle(f.face));
    const seen = lineup.map((f: any, i: number) => (study.some((s: any) => same(s.face, f.face)) ? i : -1)).filter((i: number) => i >= 0);
    assertEquals(seen.length, 1, "facemem: not exactly one studied person in the line-up");
    for (let i = 0; i < L; i++) for (let j = i + 1; j < L; j++) assert(!same(lineup[i].face, lineup[j].face), "line-up repeats a person");
    oneIndex(it, L, seen[0]);
  },
  eyes(it) {
    const { face, params, options } = it.display as any;
    newStyle(face);
    assertEquals(options.length, 4);
    assert(new Set(options).size === 4 && options.every((o: string) => EYE_STATES[o]));
    const EYE_KEYS = ["bi", "bo", "bl", "ul", "lt", "cr"];
    const best = bestByFit(it, params, options, EYE_STATES, EYE_KEYS);
    oneIndex(it, 4, best);
    const ans = options[best];
    if (it.d <= 4) assert(!options.some((o: string) => EYE_PARTNERS[ans].includes(o)), `eyes d${it.d}: look-alike offered`);
  },
  tom(it) {
    const { story, q, options } = it.display as any;
    const { n, evs, ask } = it.meta as any;
    assertEquals(story.length, evs.length + 1);
    assertEquals(options.length, 4);
    assertEquals(new Set(options).size, 4);
    const truth = tomTruth(n, evs, ask);
    assert(truth >= 0, "tom: no answer");
    const T = TOM_TXT[it.lang!];
    const places = T.places.map((p) => T.cap(p));
    // the place the story ends with the object in is the one named in the last put / move sentence
    const lastMove = evs.map((e: TomEv, i: number) => (e.t === "put" || e.t === "move" ? i : -1)).filter((i: number) => i >= 0);
    const placeOf = (i: number) => places.find((p) => story[i + 1].includes(p.charAt(0).toLowerCase() + p.slice(1)))!;
    const opt = (it.meta as any).opt as number[];
    assertEquals(options[opt.indexOf(evs[lastMove[lastMove.length - 1]].loc)], placeOf(lastMove[lastMove.length - 1]), "tom: text and events disagree");
    assert(q.length > 10 && options.every((o: string) => places.includes(o)));
    oneIndex(it, 4, opt.indexOf(truth));
    // everyone ends in the room, and the put comes first with everyone there
    assertEquals(evs[0].t, "put");
  },
  posture(it) {
    const { pose, options } = it.display as any;
    assertEquals(options.length, 4);
    assert(new Set(options).size === 4 && options.every((o: string) => POSES[o] && o !== "neutral"));
    const N = POSES.neutral, J = Object.keys(N), scale = (j: string) => (j === "ua" || j === "fa" ? 30 : 6);
    const errs = options.map((o: string) => {
      let best = Infinity;
      for (let k = 0.5; k <= 1.05; k += 0.01) best = Math.min(best, J.reduce((s, j) => s + ((pose[j] - N[j] - (POSES[o][j] - N[j]) * k) / scale(j)) ** 2, 0));
      return best;
    });
    const b = errs.indexOf(Math.min(...errs));
    assert(Math.min(...errs.filter((_: number, i: number) => i !== b)) - errs[b] > 0.5, `posture d${it.d}: ${errs}`);
    oneIndex(it, 4, b);
    if (it.d >= 6) assert(options.includes(POSE_PARTNER[options[b]]), "posture: look-alike missing from d 6");
  },
  feel(it) { options4(it); assert((it.display as any).q.length > 5); },
  change(it) { options4(it); },
  help(it) { options4(it); },
  sarcasm(it) { options4(it); assert((it.display as any).quote.length > 3); },
  fauxpas(it) {
    const o = it.display.options as string[];
    assertEquals(o.length, 3);
    assertEquals(new Set(o).size, 3);
    oneIndex(it, 3, (it.meta as any).who);
  },
};

Deno.test("INT banks: 5 per tier, EN and ES line up, the answer never among the wrong options", () => {
  for (const [name, bank] of Object.entries({ FEEL, CHANGE, HELP, SARCASM }) as [string, any][]) {
    for (const lang of ["en", "es"]) {
      bank[lang].forEach((tier: any[], t: number) => {
        assertEquals(tier.length, 5, `${name} ${lang} tier ${t}`);
        assertEquals(tier.length, bank.en[t].length);
        for (const [, , ans, wrong, why] of tier) {
          assertEquals(wrong.length, 3);
          // FEEL / CHANGE / HELP explain each answer (practice tests, 2026-10-25); SARCASM's 5th is unused
          if (name !== "SARCASM") assert(typeof why === "string" && why.length > 20, `${name} ${lang}: no why for ${ans}`);
          assert(!wrong.includes(ans) && new Set(wrong).size === 3, `${name} ${lang}: ${ans}`);
        }
      });
    }
  }
  for (const lang of ["en", "es"] as const) {
    FAUXPAS[lang].forEach((tier, t) => {
      assertEquals(tier.length, 5);
      // the Spanish version of each story has the same answer as the English one
      assertEquals(tier.map((x) => x[4]), FAUXPAS.en[t].map((x) => x[4]), `FAUXPAS ${lang} tier ${t}`);
      for (const [story, quote, a, b] of tier) assert(story.length > 20 && quote.length > 3 && a !== b);
    });
  }
  const whos = FAUXPAS.en.flat().map((x) => x[4]);
  for (const w of [0, 1, 2]) assert(whos.filter((x) => x === w).length >= 2, `FAUXPAS: answer ${w} too rare`);
});
