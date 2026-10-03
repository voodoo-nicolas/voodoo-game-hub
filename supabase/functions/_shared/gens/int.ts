// INTERPERSONAL: procedurally drawn facial expressions (face, faceodd, facequick). Ported 1:1 from the prototype.
// display.params are the action-unit values the client's face drawing uses; `face` is the identity
// (skin 0..5, hair 0..4, style 0..2, w -1..1, sp -1..1). Options are emotion keys; the client
// shows them as emo_<key> text.
import { defGen, mkItem } from "./registry.ts";
import type { Rng } from "../rng.ts";
import { EMO, EMO_CONFUSE, EMO_KEYS } from "./data.ts";

const EMO_: Record<string, Record<string, number>> = EMO;
const CONFUSE_: Record<string, string[]> = EMO_CONFUSE;

function faceParams(emo: string, k: number, r: Rng) {
  const p: Record<string, number> = {};
  for (const key of ["bi", "bo", "bl", "ul", "lt", "cr", "lc", "ls", "mo", "nw", "ur", "lp"]) p[key] = (EMO_[emo][key] || 0) * k + r.gauss() * 0.04;
  return p;
}
const randId = (r: Rng) => ({ skin: r.int(0, 5), hair: r.int(0, 4), style: r.int(0, 2), w: r.int(-1, 1), sp: r.int(-1, 1) });
function emoOptions(ans: string, d: number, r: Rng) {
  const dist = d >= 5 ? CONFUSE_[ans].slice() : r.shuffle(EMO_KEYS.filter((e) => e !== ans)).slice(0, 3);
  return r.shuffle([ans, ...dist.slice(0, 3)]);
}
defGen({
  id: "face", sec: "INT", a: 1.3, k: 4, minMs: 700, maxMs: 30000,
  make(d, r) {
    const eyesOnly = d >= 8;
    const k = eyesOnly ? [0.85, 0.7, 0.55][d - 8] : [1, .85, .72, .62, .53, .45, .38][d - 1];
    const emo = r.pick(EMO_KEYS);
    const p = faceParams(emo, k, r);
    const id = randId(r);
    const opts = emoOptions(emo, d, r);
    const ansIdx = opts.indexOf(emo);
    return mkItem(this, d, { display: { params: p, face: id, eyesOnly, options: opts }, key: { t: "idx", v: ansIdx }, meta: { emo } });
  },
});
defGen({
  id: "faceodd", sec: "INT", a: 1.3, k: 4, minMs: 900, maxMs: 35000,
  make(d, r) {
    const emo = r.pick(EMO_KEYS);
    const other = d >= 5 ? r.pick(CONFUSE_[emo]) : r.pick(EMO_KEYS.filter((e) => e !== emo));
    const kb = [1, .9, .8, .7, .62, .55, .5, .45, .4, .36][d - 1];
    const pos = r.int(0, 3);
    const faces = [0, 1, 2, 3].map((i) => ({ params: faceParams(i === pos ? other : emo, kb * (0.85 + r.n() * 0.3), r), face: randId(r) }));
    return mkItem(this, d, { display: { faces }, key: { t: "idx", v: pos }, meta: { emo, other } });
  },
});
defGen({
  id: "facequick", sec: "INT", a: 1.1, k: 4, minMs: 400, maxMs: 15000, w: 1.5,
  make(d, r) {
    const emo = r.pick(EMO_KEYS);
    const p = faceParams(emo, 0.95, r);
    const id = randId(r);
    const opts = r.shuffle([emo, ...r.shuffle(EMO_KEYS.filter((e) => e !== emo)).slice(0, 3)]);
    const ansIdx = opts.indexOf(emo);
    return mkItem(this, d, { display: { params: p, face: id, eyesOnly: false, options: opts }, key: { t: "idx", v: ansIdx }, meta: { emo } });
  },
});
