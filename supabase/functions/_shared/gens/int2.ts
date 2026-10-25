// INTERPERSONAL, second set (2026-10-25; NOT in the prototype). Served only to clients that
// send gv >= 9 (engine.ts secGens), which also draw the new hairstyles 3..11 (`newId`).
// Faces: flash (blink and you miss it), smile (real or polite?), gaze (what does she want?),
// intensity (how angry?), facemem (have we met?), eyes (read the eyes).
// Stories: tom (where will she look?, generated and simulated); feel, change, sarcasm, fauxpas,
// help (hand-written banks, gens/int2_data.ts). Body: posture (a drawn figure).
// Face params are the prototype's action units (gens/int.ts); gaze adds gx / gy (pupils).
import { type Ctx, defGen, type GenDef, type Lang, mkItem, say } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { EMO, EMO_KEYS } from "./data.ts";
import { emoCue, emoName, emoOptions } from "./int.ts";
import { tierOf } from "./lin2.ts";
import { CHANGE, FAUXPAS, FEEL, HELP, SARCASM, TOM_TXT } from "./int2_data.ts";

/** Hairstyles 3..11 (client voodoo_iq_art.gd NEW_HAIR; the Face Lab's bun is left out). */
export const NEW_STYLES = 9;
export const BALD_STYLE = 10;
export type FaceId = { skin: number; hair: number; style: number; w: number; sp: number };
export const newId = (r: Rng): FaceId => ({ skin: r.int(0, 5), hair: r.int(0, 4), style: 3 + r.int(0, NEW_STYLES - 1), w: r.int(-1, 1), sp: r.int(-1, 1) });
const ID_KEYS = ["skin", "hair", "style", "w", "sp"] as const;
export const idDiff = (a: FaceId, b: FaceId) => ID_KEYS.filter((k) => a[k] !== b[k]).length;

const AU = ["bi", "bo", "bl", "ul", "lt", "cr", "lc", "ls", "mo", "nw", "ur", "lp"];
const EMO_: Record<string, Record<string, number>> = EMO;
/** Action units of `base` scaled by k, plus a little noise (0 = exact). */
export function auParams(base: Record<string, number>, k: number, r: Rng, noise = 0.04) {
  const p: Record<string, number> = {};
  for (const key of AU) p[key] = (base[key] || 0) * k + (noise ? r.gauss() * noise : 0);
  return p;
}
const idx = (v: number) => ({ t: "idx" as const, v });
const capW = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function pickFrom<T>(g: GenDef, bank: { en: T[][]; es: T[][] }, d: number, r: Rng, ctx: Ctx): T {
  const t = tierOf(d), list = bank[ctx.lang][t];
  const fresh = list.map((_, i) => i).filter((i) => !ctx.used.has(`${g.id}${t}:${i}`));
  const i = r.pick(fresh.length ? fresh : list.map((_, i) => i));
  ctx.used.add(`${g.id}${t}:${i}`);
  return list[i];
}

/* ---------------- flash: an expression shows for flashMs, then the face goes neutral ----------------
   d 1 = 400 ms at full strength ... d 10 = 40 ms at 60%; from d 5 the options are the look-alikes. */
const FLASH_MS = [400, 320, 250, 200, 160, 120, 90, 70, 55, 40];
defGen({
  id: "flash", sec: "INT", a: 1.3, k: 4, minMs: 300, maxMs: 30000,
  make(d, r, ctx) {
    const emo = r.pick(EMO_KEYS);
    const k = [1, 1, .95, .9, .85, .8, .75, .7, .65, .6][d - 1];
    const options = emoOptions(emo, d, r);
    return mkItem(this, d, {
      deferTimer: true,
      display: { face: newId(r), params: auParams(EMO_[emo], k, r), flashMs: FLASH_MS[d - 1], options },
      key: idx(options.indexOf(emo)), meta: { emo },
      why: say(ctx.lang, `For ${FLASH_MS[d - 1]} ms the face showed ${emoName(emo, "en")}: ${emoCue(emo, "en")}.`, `Durante ${FLASH_MS[d - 1]} ms la cara mostró ${emoName(emo, "es")}: ${emoCue(emo, "es")}.`),
    });
  },
});

/* ---------------- smile: which smile is real? (a real one also raises the cheeks) ----------------
   Both mouths are the same; the real smile adds cheek raise (cr) and lid tightening (lt), which
   narrow the eyes and crease under them. Harder: less cheek raise, two different people (d 4+),
   and a slight cheek lift on the polite one (d 8+). The gap in cr never drops below 0.3. */
export const SMILE = (d: number) => {
  const t = (d - 1) / 9;
  return { realCr: .9 - .45 * t, realLt: .35 - .15 * t, fakeCr: d >= 8 ? .15 : 0 };
};
defGen({
  id: "smile", sec: "INT", a: 1.2, k: 2, minMs: 600, maxMs: 30000,
  make(d, r, ctx) {
    const s = SMILE(d), mouth = { lc: 1, mo: .35 };
    const a = newId(r);
    let b = a;
    if (d >= 4) do b = newId(r); while (idDiff(a, b) < 2);
    const real = auParams({ ...mouth, cr: s.realCr, lt: s.realLt }, 1, r, .02);
    const fake = auParams({ ...mouth, cr: s.fakeCr }, 1, r, .02);
    real.cr = s.realCr; // no noise on the cue itself, so the gap stays >= 0.3
    fake.cr = s.fakeCr;
    const pos = r.int(0, 1);
    const faces = pos === 0 ? [{ face: a, params: real }, { face: b, params: fake }] : [{ face: a, params: fake }, { face: b, params: real }];
    const why = say(ctx.lang, `In a real smile the cheeks lift and the eyes narrow, with creases under them. Face ${pos + 1} does that; the other smile only moves the mouth.`, `En una sonrisa real las mejillas suben y los ojos se achican, con arruguitas debajo. La cara ${pos + 1} hace eso; la otra sonrisa solo mueve la boca.`);
    return mkItem(this, d, { display: { faces }, key: idx(pos), why });
  },
});

/* ---------------- gaze: she looks at the thing she wants ----------------
   n objects evenly round the face (4 on the diagonals, 6, or 8); the pupils point at one.
   Harder: more objects, smaller eye movement. gx / gy = pupil direction (screen: y down). */
export const GAZE_OBJ = ["ball", "book", "hat", "cup", "key", "apple", "star", "flower", "clock", "shoe"];
const GAZE_ES: Record<string, string> = { ball: "la pelota", book: "el libro", hat: "el sombrero", cup: "la taza", key: "la llave", apple: "la manzana", star: "la estrella", flower: "la flor", clock: "el reloj", shoe: "el zapato" };
export const gazeAngles = (n: number) => Array.from({ length: n }, (_, i) => (n === 4 ? 45 : 0) + i * 360 / n);
defGen({
  id: "gaze", sec: "INT", a: 1.1, k: 0, minMs: 500, maxMs: 30000,
  make(d, r, ctx) {
    const n = d <= 3 ? 4 : d <= 7 ? 6 : 8;
    const mag = d <= 6 ? 1 : d <= 8 ? .8 : .65;
    const angles = gazeAngles(n), target = r.int(0, n - 1);
    const objects = r.shuffle(GAZE_OBJ).slice(0, n);
    const a = angles[target] * Math.PI / 180;
    const params = { ...auParams({}, 1, r, .03), gx: Math.cos(a) * mag, gy: Math.sin(a) * mag };
    const why = say(ctx.lang, `Follow the pupils: both eyes point toward the ${objects[target]}. People look at what they want.`, `Seguí las pupilas: los dos ojos apuntan hacia ${GAZE_ES[objects[target]]}. Uno mira lo que quiere.`);
    return mkItem(this, d, { k: n, display: { face: newId(r), params, angles, objects }, key: idx(target), meta: { target }, why });
  },
});

/* ---------------- intensity: put the faces in order, least to most ----------------
   3 / 4 / 5 faces of one emotion, strengths `gap` apart (0.3 at d 1 down to 0.12), no noise.
   Same person up to d 6, then different people. Answer = face indexes, weakest first ("2,0,1"). */
const GAP = [.3, .28, .26, .22, .2, .18, .16, .14, .13, .12];
defGen({
  id: "intensity", sec: "INT", a: 1.2, k: 0, minMs: 1500, maxMs: 45000,
  make(d, r, ctx) {
    const n = d <= 3 ? 3 : d <= 7 ? 4 : 5, gap = GAP[d - 1];
    const emo = r.pick(EMO_KEYS);
    const base = .2 + r.n() * (1.05 - .2 - gap * (n - 1));
    const ks = r.shuffle(Array.from({ length: n }, (_, i) => base + i * gap));
    const one = newId(r);
    const faces = ks.map((k) => ({ face: d <= 6 ? one : newId(r), params: auParams(EMO_[emo], k, r, 0) }));
    const order = ks.map((k, i) => [k, i]).sort((x, y) => x[0] - y[0]).map((x) => x[1]).join(",");
    const why = say(ctx.lang, `Every face shows ${emoName(emo, "en")}. Look at how strong the cues are (${emoCue(emo, "en")}): the green numbers go from the weakest to the strongest.`, `Todas las caras muestran ${emoName(emo, "es")}. Mirá qué tan marcadas están las señales (${emoCue(emo, "es")}): los números verdes van de la más leve a la más fuerte.`);
    return mkItem(this, d, { display: { emo, faces }, key: { t: "str", v: order }, meta: { ks }, why });
  },
});

/* ---------------- facemem: study faces, then find one of them in a line-up ----------------
   Study 2 / 3 / 4 neutral faces (2 s each), then 4 (d 1-4) or 6 faces. Exactly one line-up face
   is a person studied; every other differs from every studied person. From d 3 the line-up
   faces wear expressions (so the expression is no clue); from d 4 one (d 8+: two) look-alike
   differs from a studied person in one feature only (skin, hair colour, hairstyle; d 8+ also
   face width or eye spacing). Studied people differ from each other in 2+ features. */
const LOOK_FEATS = ["skin", "hair", "style"] as const, LOOK_FEATS_HARD = ["skin", "hair", "style", "w", "sp"] as const;
const FEAT_RANGE: Record<string, [number, number]> = { skin: [0, 5], hair: [0, 4], style: [3, 11], w: [-1, 1], sp: [-1, 1] };
defGen({
  id: "facemem", sec: "INT", a: 1.2, k: 0, minMs: 600, maxMs: 40000,
  make(d, r, ctx) {
    const m = d <= 3 ? 2 : d <= 6 ? 3 : 4, L = d <= 4 ? 4 : 6;
    const study: FaceId[] = [];
    while (study.length < m) { const c = newId(r); if (study.every((s) => idDiff(s, c) >= 2)) study.push(c); }
    const target = r.pick(study);
    const others: FaceId[] = [];
    const nLook = d < 4 ? 0 : d >= 8 ? 2 : 1;
    const lookF: string[] = [];
    while (others.length < nLook) {
      const src = r.pick(study), feats = d >= 8 ? LOOK_FEATS_HARD : LOOK_FEATS;
      const f = r.pick(feats.filter((x) => !(x === "hair" && src.style === BALD_STYLE)));
      const [lo, hi] = FEAT_RANGE[f];
      let v = src[f];
      while (v === src[f]) v = r.int(lo, hi);
      const c = { ...src, [f]: v };
      if (study.every((s) => idDiff(s, c) >= 1) && others.every((o) => idDiff(o, c) >= 1)) { others.push(c); lookF.push(f); }
    }
    while (others.length < L - 1) { const c = newId(r); if (study.every((s) => idDiff(s, c) >= 2) && others.every((o) => idDiff(o, c) >= 1)) others.push(c); }
    const lineup = r.shuffle([target, ...others]);
    const expr = (): Record<string, number> => (d >= 3 && r.chance(.75) ? auParams(EMO_[r.pick(EMO_KEYS)], .7, r) : auParams({}, 1, r, .02));
    return mkItem(this, d, {
      k: L, deferTimer: true,
      display: { study: study.map((face) => ({ face })), lineup: lineup.map((face) => ({ face, params: expr() })), studyMs: 2000 * m },
      key: idx(lineup.indexOf(target)), meta: { study, lineup },
      why: (() => {
        const F: Record<string, [string, string]> = { skin: ["skin colour", "color de piel"], hair: ["hair colour", "color de pelo"], style: ["hairstyle", "peinado"], w: ["face width", "ancho de la cara"], sp: ["eye spacing", "distancia entre los ojos"] };
        const looks = [...new Set(lookF)].map((f) => F[f][ctx.lang === "es" ? 1 : 0]).join(say(ctx.lang, " or ", " o "));
        return say(ctx.lang, `Face ${lineup.indexOf(target) + 1} in the line-up is one of the people you studied.${lookF.length ? ` The look-alike${lookF.length > 1 ? "s differ" : " differs"} from someone you studied in just one thing: ${looks}.` : ""}${d >= 3 ? " Expressions don't matter: the same person can look happy or sad." : ""}`,
          `La cara ${lineup.indexOf(target) + 1} de la fila es una de las personas que estudiaste.${lookF.length ? ` ${lookF.length > 1 ? "Las parecidas cambian" : "La parecida cambia"} en una sola cosa respecto de alguien que estudiaste: ${looks}.` : ""}${d >= 3 ? " Las expresiones no importan: la misma persona puede verse alegre o triste." : ""}`);
      })(),
    });
  },
});

/* ---------------- eyes: read the eyes (eyes-only crop, a word for the state) ----------------
   Eight states drawn with eye-region action units only. Each has look-alikes (PARTNERS) that
   are left out of the options up to d 4 and put in from d 5. Strength 1 down to 0.55. */
export const EYE_STATES: Record<string, Record<string, number>> = {
  suspicious: { lt: .9, bl: .45, ul: -.3 },
  furious: { bl: 1, lt: .5, ul: .5 },
  worried: { bi: .9, bl: .45, ul: .15 },
  downcast: { bi: 1, bl: .3, ul: -.45 },
  amazed: { bi: 1, bo: 1, ul: 1 },
  terrified: { bi: 1, bo: .6, bl: .6, ul: 1 },
  cheerful: { cr: .9, lt: .35 },
  sleepy: { ul: -.75 },
};
export const EYE_PARTNERS: Record<string, string[]> = {
  suspicious: ["furious", "sleepy"], furious: ["suspicious"], worried: ["downcast", "terrified"], downcast: ["worried", "sleepy"],
  amazed: ["terrified"], terrified: ["amazed", "worried"], cheerful: ["sleepy"], sleepy: ["downcast", "suspicious"],
};
const EYE_KEYS = Object.keys(EYE_STATES);
const EYE_WHY: Record<string, { en: [string, string]; es: [string, string] }> = {
  suspicious: { en: ["suspicious", "narrowed eyes under slightly lowered brows"], es: ["desconfiado", "ojos entrecerrados bajo las cejas un poco bajas"] },
  furious: { en: ["furious", "brows pulled down hard over wide, staring eyes"], es: ["furioso", "cejas muy bajas sobre ojos muy abiertos y fijos"] },
  worried: { en: ["worried", "the inner ends of the brows raised and pulled together"], es: ["preocupado", "las puntas internas de las cejas levantadas y juntas"] },
  downcast: { en: ["downcast", "inner brows raised over heavy, drooping lids"], es: ["abatido", "puntas internas de las cejas arriba y párpados pesados, caídos"] },
  amazed: { en: ["amazed", "brows high and eyes wide open"], es: ["asombrado", "cejas altas y ojos muy abiertos"] },
  terrified: { en: ["terrified", "eyes wide open with the brows raised and pulled together"], es: ["aterrado", "ojos muy abiertos con las cejas levantadas y juntas"] },
  cheerful: { en: ["cheerful", "raised cheeks narrowing the eyes from below, as in a smile"], es: ["alegre", "mejillas levantadas que achican los ojos desde abajo, como en una sonrisa"] },
  sleepy: { en: ["sleepy", "drooping upper lids and relaxed brows"], es: ["somnoliento", "párpados superiores caídos y cejas relajadas"] },
};
defGen({
  id: "eyes", sec: "INT", a: 1.3, k: 4, minMs: 700, maxMs: 30000,
  make(d, r, ctx) {
    const st = r.pick(EYE_KEYS), k = 1 - .05 * (d - 1);
    const partners = EYE_PARTNERS[st];
    const pool = EYE_KEYS.filter((x) => x !== st && (d >= 5 || !partners.includes(x)));
    const wrong = d >= 5 ? [...partners.slice(0, 2), ...r.shuffle(pool.filter((x) => !partners.includes(x)))].slice(0, 3) : r.shuffle(pool).slice(0, 3);
    const options = r.shuffle([st, ...wrong]);
    const w = EYE_WHY[st][ctx.lang === "es" ? "es" : "en"];
    const why = say(ctx.lang, `These eyes look ${w[0]}: ${w[1]}.`, `Es la mirada de alguien ${w[0]}: ${w[1]}.`);
    return mkItem(this, d, { display: { face: newId(r), params: auParams(EYE_STATES[st], k, r, .02), options }, key: idx(options.indexOf(st)), meta: { st }, why });
  },
});

/* ---------------- tom: where will she look? (false belief) ----------------
   A story of events is generated and simulated; the question asks where the object really is,
   where someone will look first (what they last saw), or (d 8+) where one person thinks
   another will look. Events: put / move (seen by everyone in the room), leave, back, peek
   (someone outside looks in; nobody knows). d 1-3: 2 people, 2 places, one move; d 4-7:
   up to 3 people and places, 2 moves, people come and go; d 8-10: peeks and second-order
   questions. At the end everyone is back in the room. */
export type TomEv = { t: "put" | "move" | "leave" | "back" | "peek"; p: number; loc?: number };
export type TomAsk = { t: "look" | "real" | "think"; p: number; q?: number };
/** Run the story: where the object is, where each person thinks it is, and where each person
 *  thinks each other person thinks it is. */
export function tomRun(n: number, evs: TomEv[]) {
  let real = -1;
  const here = Array(n).fill(true);
  const b = Array(n).fill(-1);
  const b2 = Array.from({ length: n }, () => Array(n).fill(-1));
  for (const e of evs) {
    if (e.t === "leave") here[e.p] = false;
    else if (e.t === "back") here[e.p] = true;
    else if (e.t === "peek") b[e.p] = real;
    else {
      real = e.loc!;
      for (let x = 0; x < n; x++) {
        if (!here[x]) continue;
        b[x] = real;
        for (let y = 0; y < n; y++) if (here[y]) b2[x][y] = real;
      }
    }
  }
  return { real, b, b2 };
}
export const tomAnswer = (n: number, evs: TomEv[], ask: TomAsk) => {
  const s = tomRun(n, evs);
  return ask.t === "real" ? s.real : ask.t === "look" ? s.b[ask.p] : s.b2[ask.p][ask.q!];
};
function tomStory(d: number, r: Rng): { n: number; nl: number; evs: TomEv[]; ask: TomAsk } {
  const tier = tierOf(d);
  const n = tier === 0 ? 2 : r.int(2, 3), nl = tier === 0 ? 2 : 3;
  const evs: TomEv[] = [{ t: "put", p: 0, loc: 0 }];
  const here = Array(n).fill(true);
  let at = 0, moves = 0;
  const steps = tier === 0 ? 2 : tier === 1 ? r.int(3, 4) : r.int(4, 5);
  const needMoves = tier === 0 ? 1 : 2;
  for (let i = 0; i < steps || moves < needMoves; i++) {
    const inRoom = here.map((h, x) => (h ? x : -1)).filter((x) => x >= 0);
    const out = here.map((h, x) => (h ? -1 : x)).filter((x) => x >= 0);
    const kinds: TomEv["t"][] = [];
    if (inRoom.length > 1) kinds.push("leave");
    if (out.length && (tier > 0 || moves)) kinds.push("back");
    if (inRoom.length) kinds.push("move", "move");
    if (tier === 2 && out.length && moves) kinds.push("peek");
    // the very first step: someone leaves, so a belief can go stale
    const t = i === 0 && inRoom.length > 1 ? "leave" : r.pick(kinds);
    if (t === "leave") { const p = r.pick(inRoom); here[p] = false; evs.push({ t, p }); }
    else if (t === "back") { const p = r.pick(out); here[p] = true; evs.push({ t, p }); }
    else if (t === "peek") evs.push({ t, p: r.pick(out) });
    else { const p = r.pick(inRoom); let loc = at; while (loc === at) loc = r.int(0, nl - 1); at = loc; moves++; evs.push({ t, p, loc }); }
  }
  for (let x = 0; x < n; x++) if (!here[x]) evs.push({ t: "back", p: x });
  const s = tomRun(n, evs);
  // ask about a stale belief most of the time; reality and true beliefs keep "always the old place" from working
  const stale = Array.from({ length: n }, (_, x) => x).filter((x) => s.b[x] !== s.real);
  let ask: TomAsk;
  const u = r.n();
  if (tier === 2 && u < .5) {
    const pairs: [number, number][] = [];
    for (let x = 0; x < n; x++) for (let y = 0; y < n; y++) if (x !== y && s.b2[x][y] !== s.b[y]) pairs.push([x, y]);
    const [p, q] = pairs.length ? r.pick(pairs) : [1, 0];
    ask = { t: "think", p, q };
  } else if (u < .12 || (!stale.length && u < .3)) ask = { t: "real", p: 0 };
  else ask = { t: "look", p: stale.length && r.chance(.8) ? r.pick(stale) : r.int(0, n - 1) };
  return { n, nl, evs, ask };
}
defGen({
  id: "tom", sec: "INT", a: 1.3, k: 4, minMs: 2500, maxMs: 90000,
  make(d, r, ctx) {
    const { n, nl, evs, ask } = tomStory(d, r);
    const T = TOM_TXT[ctx.lang];
    const names = r.shuffle(T.names).slice(0, n);
    const [thing, pron, be] = r.pick(T.things);
    const locs = r.shuffle(T.places).slice(0, 4); // nl used in the story, the rest only as options
    const fill = (s: string, e: Partial<TomEv> & { q?: number }) =>
      s.replace("{p}", names[e.p ?? 0]).replace("{q}", names[e.q ?? 0]).replace("{o}", thing).replace("{pr}", pron).replace("{be}", be).replace("{l}", locs[e.loc ?? 0]);
    const story = [T.intro.replace("{all}", T.and(names)), ...evs.map((e) => fill(T[e.t], e))];
    const q = fill(T.ask[ask.t], { p: ask.p, q: ask.q });
    const ans = tomAnswer(n, evs, ask);
    const options = r.shuffle([0, 1, 2, 3]);
    const run = tomRun(n, evs), P = names[ask.p], Q = names[ask.q ?? 0], es = ctx.lang === "es";
    let why: string;
    if (ask.t === "real") why = say(ctx.lang, `Follow the story: ${thing} ended up ${locs[run.real]}. What people think doesn't change where it really is.`, `Seguí la historia: ${thing} ${be === "están" ? "terminaron" : "terminó"} ${locs[run.real]}. Lo que crea la gente no cambia dónde está de verdad.`);
    else if (ask.t === "look") why = run.b[ask.p] === run.real
      ? say(ctx.lang, `${P} saw where ${thing} ended up: ${locs[ans]}. So ${P} will look there.`, `${P} vio dónde ${be === "están" ? "terminaron" : "terminó"} ${thing}: ${locs[ans]}. Así que ${P} va a buscar ahí.`)
      : say(ctx.lang, `${P} last saw ${thing} ${locs[ans]}, and wasn't there when it was moved ${locs[run.real]}. People look where they last saw something, so ${P} will look ${locs[ans]} first.`, `${P} vio ${thing} por última vez ${locs[ans]}, y no estaba cuando ${es && be === "están" ? "las movieron" : "lo movieron"} ${locs[run.real]}. Uno busca donde vio algo por última vez, así que ${P} va a buscar primero ${locs[ans]}.`);
    else why = say(ctx.lang, `Think like ${P}: from what ${P} saw, ${Q} last saw ${thing} ${locs[ans]}. ${P} doesn't know what ${Q} saw while ${P} wasn't looking, so ${P} thinks ${Q} will look ${locs[ans]} first.`, `Pensá como ${P}: por lo que ${P} vio, ${Q} vio ${thing} por última vez ${locs[ans]}. ${P} no sabe qué vio ${Q} mientras ${P} no miraba, así que cree que ${Q} va a buscar primero ${locs[ans]}.`);
    return mkItem(this, d, {
      lang: ctx.lang,
      display: { story, q, options: options.map((i) => T.cap(locs[i])) },
      key: idx(options.indexOf(ans)), meta: { n, nl, evs, ask, ans, opt: options },
      why,
    });
  },
});

/* ---------------- posture: what is this person feeling? (no face, no voice) ----------------
   A front-view figure posed by joint values, blended from neutral by strength k (1 down to
   0.68). sh shoulder drop (+ = slumped), nk neck (+ = head up, - = head sinks), ua upper arm
   and fa forearm angles from straight down (+ = outward, 180 = up), kn knee bend, st stance
   half-width, fist. From d 6 the look-alike (proud / joyful, afraid / sad, angry / proud) is
   in the options. */
export const POSES: Record<string, Record<string, number>> = {
  neutral: { sh: 0, nk: 0, ua: 10, fa: 10, kn: 0, st: 14 },
  sad: { sh: 12, nk: -16, ua: 3, fa: 1, kn: 8, st: 10 },
  angry: { sh: -6, nk: -4, ua: 38, fa: -25, kn: 6, st: 28 },
  proud: { sh: -5, nk: 10, ua: 50, fa: -70, kn: 0, st: 22 },
  afraid: { sh: -10, nk: -10, ua: 22, fa: 195, kn: 22, st: 8 },
  joyful: { sh: -5, nk: 8, ua: 150, fa: 155, kn: 0, st: 30 },
};
export const POSE_PARTNER: Record<string, string> = { proud: "joyful", joyful: "proud", afraid: "sad", sad: "afraid", angry: "proud" };
const POSE_KEYS = ["sad", "angry", "proud", "afraid", "joyful"];
const POSE_WHY: Record<string, { en: [string, string]; es: [string, string] }> = {
  sad: { en: ["sad", "slumped shoulders, the head sinking and arms hanging loose"], es: ["triste", "hombros caídos, la cabeza hundida y los brazos colgando"] },
  angry: { en: ["angry", "a wide stance, arms held out from the body and clenched fists"], es: ["enojado", "piernas abiertas, brazos separados del cuerpo y puños cerrados"] },
  proud: { en: ["proud", "the head up, chest out and hands on the hips"], es: ["orgulloso", "la cabeza en alto, el pecho afuera y las manos en la cintura"] },
  afraid: { en: ["afraid", "shoulders hunched, knees bent and hands up in front for protection"], es: ["asustado", "hombros encogidos, rodillas flexionadas y las manos adelante para protegerse"] },
  joyful: { en: ["joyful", "both arms thrown up high and the head up"], es: ["eufórico", "los dos brazos bien arriba y la cabeza en alto"] },
};
defGen({
  id: "posture", sec: "INT", a: 1.1, k: 4, minMs: 600, maxMs: 30000,
  make(d, r, ctx) {
    const emo = r.pick(POSE_KEYS), k = [1, 1, .95, .9, .85, .8, .76, .72, .7, .68][d - 1];
    const N = POSES.neutral, E = POSES[emo];
    const pose: Record<string, number> = {};
    for (const j of Object.keys(N)) pose[j] = N[j] + (E[j] - N[j]) * k + r.gauss() * (j === "ua" || j === "fa" ? 3 : 1);
    pose.fist = emo === "angry" ? 1 : 0;
    const partner = POSE_PARTNER[emo];
    const rest = r.shuffle(POSE_KEYS.filter((x) => x !== emo && x !== partner));
    const wrong = d >= 6 ? [partner, ...rest.slice(0, 2)] : rest.slice(0, 3);
    const options = r.shuffle([emo, ...wrong]);
    const pw = POSE_WHY[emo][ctx.lang === "es" ? "es" : "en"];
    const why = say(ctx.lang, `The body looks ${pw[0]}: ${pw[1]}.`, `Es la postura de alguien ${pw[0]}: ${pw[1]}.`);
    return mkItem(this, d, { display: { pose, options }, key: idx(options.indexOf(emo)), meta: { emo }, why });
  },
});

/* ---------------- the hand-written banks (int2_data.ts) ---------------- */
/** feel / change / help: [story, question, right, wrong x3] */
function bankItem(g: GenDef, bank: any, d: number, r: Rng, ctx: Ctx) {
  const [story, q, ans, wrong] = pickFrom(g, bank, d, r, ctx) as [string, string, string, string[]];
  const options = r.shuffle([ans, ...wrong]);
  const why = g.id === "feel"
    ? say(ctx.lang, `Put yourself in their place: after what happened, “${ans}” is the most natural feeling. The other feelings would need a different story.`, `Ponete en su lugar: después de lo que pasó, “${ans}” es lo que más naturalmente se siente. Los otros sentimientos necesitarían otra historia.`)
    : g.id === "help"
      ? say(ctx.lang, `“${ans}” deals with what the person actually needs right now. The other options ignore the feeling, brush it off or make it worse.`, `“${ans}” atiende lo que la persona necesita en este momento. Las otras opciones ignoran lo que siente, le restan importancia o lo empeoran.`)
      : say(ctx.lang, `“${ans}” is where that feeling most often leads. The others are feelings that usually come from somewhere else.`, `“${ans}” es adonde más a menudo lleva ese sentimiento. Los otros suelen venir de otro lado.`);
  return mkItem(g, d, { display: { story, q, options }, key: idx(options.indexOf(ans)), meta: { ans }, why });
}
defGen({ id: "feel", sec: "INT", a: 1.2, k: 4, minMs: 2000, maxMs: 60000, make(d, r, ctx) { return bankItem(this, FEEL, d, r, ctx); } });
defGen({ id: "change", sec: "INT", a: 1.1, k: 4, minMs: 1500, maxMs: 60000, make(d, r, ctx) { return bankItem(this, CHANGE, d, r, ctx); } });
defGen({ id: "help", sec: "INT", a: 1.1, k: 4, minMs: 2000, maxMs: 60000, make(d, r, ctx) { return bankItem(this, HELP, d, r, ctx); } });
/** sarcasm: [situation, what is said, what they mean, wrong x3] */
defGen({
  id: "sarcasm", sec: "INT", a: 1.2, k: 4, minMs: 2000, maxMs: 60000,
  make(d, r, ctx) {
    const [story, quote, ans, wrong] = pickFrom(this, SARCASM, d, r, ctx);
    const options = r.shuffle([ans, ...wrong]);
    const why = say(ctx.lang, `“${quote}” can't be meant literally in that situation: it's sarcasm, where what is said isn't what is meant. ${capW(ans)}.`, `“${quote}” no puede decirse en serio en esa situación: es sarcasmo, lo que se dice no es lo que se quiere decir. ${capW(ans)}.`);
    return mkItem(this, d, { display: { story, quote, options }, key: idx(options.indexOf(ans)), meta: { ans }, why });
  },
});
/** fauxpas: [story, what is said, speaker, the other person, who slipped: 0 speaker / 1 other / 2 nobody].
 *  Options: "Yes, <speaker>", "Yes, <other>", "No, nobody did" (fixed order). */
const FP_TXT: Record<Lang, { yes: string; none: string }> = { en: { yes: "Yes, {p}", none: "No, nobody did" }, es: { yes: "Sí, {p}", none: "No, nadie" } };
defGen({
  id: "fauxpas", sec: "INT", a: 1.2, k: 3, minMs: 2500, maxMs: 60000,
  make(d, r, ctx) {
    const [story, quote, a, b, who] = pickFrom(this, FAUXPAS, d, r, ctx);
    const t = FP_TXT[ctx.lang];
    const options = [t.yes.replace("{p}", a), t.yes.replace("{p}", b), t.none];
    const why = who === 0
      ? say(ctx.lang, `${a} said something hurtful to ${b} without meaning to: ${a} didn't know the whole story. That is a faux pas.`, `${a} le dijo a ${b} algo hiriente sin querer: ${a} no sabía toda la historia. Eso es una metida de pata.`)
      : who === 1
        ? say(ctx.lang, `${b} is the one who slipped: what ${b} said before was hurtful without ${b} realising it. ${a}'s answer only shows it.`, `${b} es quien metió la pata: lo que dijo antes era hiriente sin darse cuenta. La respuesta de ${a} solo lo deja ver.`)
        : say(ctx.lang, `Nobody slipped: what ${a} said is kind and fits what ${a} knows.`, `Nadie metió la pata: lo que dijo ${a} es amable y coincide con lo que sabe.`);
    return mkItem(this, d, { display: { story, quote, options }, key: idx(who), meta: { who }, why });
  },
});
