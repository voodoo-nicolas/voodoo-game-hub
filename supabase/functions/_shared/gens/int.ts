// INTERPERSONAL: procedurally drawn facial expressions (face, faceodd, facequick). Ported 1:1 from the prototype.
// display.params are the action-unit values the client's face drawing uses; `face` is the identity
// (skin 0..5, hair 0..4, style 0..2, w -1..1, sp -1..1). Options are emotion keys; the client
// shows them as emo_<key> text.
import { defGen, type Lang, mkItem, say } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { EMO, EMO_CONFUSE, EMO_KEYS } from "./data.ts";

const EMO_: Record<string, Record<string, number>> = EMO;
const CONFUSE_: Record<string, string[]> = EMO_CONFUSE;

/** Each expression's name and the cues the face drawing uses for it (data.ts EMO), for `why`. */
export const EMO_WHY: Record<string, { en: [string, string]; es: [string, string] }> = {
  happy: { en: ["happiness", "raised cheeks and lip corners pulled up"], es: ["alegría", "mejillas levantadas y comisuras hacia arriba"] },
  sad: { en: ["sadness", "the inner ends of the brows raised and lip corners pulled down"], es: ["tristeza", "las puntas internas de las cejas levantadas y las comisuras hacia abajo"] },
  angry: { en: ["anger", "brows lowered and pulled together, tight lids and pressed lips"], es: ["enojo", "cejas bajas y juntas, párpados tensos y labios apretados"] },
  fear: { en: ["fear", "brows raised and pulled together, upper lids wide open and lips stretched sideways"], es: ["miedo", "cejas levantadas y juntas, párpados superiores muy abiertos y labios estirados hacia los costados"] },
  surprise: { en: ["surprise", "brows raised high, eyes wide open and the jaw dropped"], es: ["sorpresa", "cejas muy levantadas, ojos muy abiertos y la mandíbula caída"] },
  disgust: { en: ["disgust", "a wrinkled nose and a raised upper lip"], es: ["asco", "la nariz arrugada y el labio superior levantado"] },
};
export const emoName = (e: string, lang: Lang) => EMO_WHY[e]?.[lang]?.[0] ?? e;
export const emoCue = (e: string, lang: Lang) => EMO_WHY[e]?.[lang]?.[1] ?? "";
function faceWhy(emo: string, eyesOnly: boolean, lang: Lang) {
  return say(lang, `The face shows ${emoName(emo, "en")}: ${emoCue(emo, "en")}.${eyesOnly ? " With only the eyes, read the brows and lids." : ""}`,
    `La cara muestra ${emoName(emo, "es")}: ${emoCue(emo, "es")}.${eyesOnly ? " Con solo los ojos, mirá las cejas y los párpados." : ""}`);
}

function faceParams(emo: string, k: number, r: Rng) {
  const p: Record<string, number> = {};
  for (const key of ["bi", "bo", "bl", "ul", "lt", "cr", "lc", "ls", "mo", "nw", "ur", "lp"]) p[key] = (EMO_[emo][key] || 0) * k + r.gauss() * 0.04;
  return p;
}
const randId = (r: Rng) => ({ skin: r.int(0, 5), hair: r.int(0, 4), style: r.int(0, 2), w: r.int(-1, 1), sp: r.int(-1, 1) });
/** Eyes-only crop (face d 8+): the nose and mouth are cut off, so disgust (nose wrinkle, raised lip) looks like a
 *  milder anger and surprise like fear: each pair is never offered together (2026-10-27, players' audit). */
const EYES_TWIN: Record<string, string> = { angry: "disgust", disgust: "angry", fear: "surprise", surprise: "fear" };
export function emoOptionsEyes(ans: string, r: Rng) {
  const twin = EYES_TWIN[ans];
  const pool = [...CONFUSE_[ans], ...r.shuffle(EMO_KEYS.filter((e) => e !== ans && !CONFUSE_[ans].includes(e)))].filter((e) => e !== twin);
  return r.shuffle([ans, ...pool.slice(0, 3)]);
}
export function emoOptions(ans: string, d: number, r: Rng) {
  const dist = d >= 5 ? CONFUSE_[ans].slice() : r.shuffle(EMO_KEYS.filter((e) => e !== ans)).slice(0, 3);
  return r.shuffle([ans, ...dist.slice(0, 3)]);
}
defGen({
  id: "face", sec: "INT", a: 1.3, k: 4, minMs: 700, maxMs: 30000,
  make(d, r, ctx) {
    const eyesOnly = d >= 8;
    const k = eyesOnly ? [0.85, 0.7, 0.55][d - 8] : [1, .85, .72, .62, .53, .45, .38][d - 1];
    const emo = r.pick(EMO_KEYS);
    const p = faceParams(emo, k, r);
    const id = randId(r);
    const opts = eyesOnly ? emoOptionsEyes(emo, r) : emoOptions(emo, d, r);
    const ansIdx = opts.indexOf(emo);
    return mkItem(this, d, { display: { params: p, face: id, eyesOnly, options: opts }, key: { t: "idx", v: ansIdx }, meta: { emo }, why: faceWhy(emo, eyesOnly, ctx.lang) });
  },
});
defGen({
  id: "faceodd", sec: "INT", a: 1.3, k: 4, minMs: 900, maxMs: 35000,
  make(d, r, ctx) {
    const emo = r.pick(EMO_KEYS);
    const other = d >= 5 ? r.pick(CONFUSE_[emo]) : r.pick(EMO_KEYS.filter((e) => e !== emo));
    const kb = [1, .9, .8, .7, .62, .55, .5, .45, .4, .36][d - 1];
    const pos = r.int(0, 3);
    const faces = [0, 1, 2, 3].map((i) => ({ params: faceParams(i === pos ? other : emo, kb * (0.85 + r.n() * 0.3), r), face: randId(r) }));
    const why = say(ctx.lang, `Three faces show ${emoName(emo, "en")}. Face ${pos + 1} shows ${emoName(other, "en")}: ${emoCue(other, "en")}.`, `Tres caras muestran ${emoName(emo, "es")}. La cara ${pos + 1} muestra ${emoName(other, "es")}: ${emoCue(other, "es")}.`);
    return mkItem(this, d, { display: { faces }, key: { t: "idx", v: pos }, meta: { emo, other }, why });
  },
});
defGen({
  id: "facequick", sec: "INT", a: 1.1, k: 4, minMs: 400, maxMs: 15000, w: 1.5,
  make(d, r, ctx) {
    const emo = r.pick(EMO_KEYS);
    const p = faceParams(emo, 0.95, r);
    const id = randId(r);
    const opts = r.shuffle([emo, ...r.shuffle(EMO_KEYS.filter((e) => e !== emo)).slice(0, 3)]);
    const ansIdx = opts.indexOf(emo);
    return mkItem(this, d, { display: { params: p, face: id, eyesOnly: false, options: opts }, key: { t: "idx", v: ansIdx }, meta: { emo }, why: faceWhy(emo, false, ctx.lang) });
  },
});
