// Test engine: which item comes next, and how a session is scored.
// Ported 1:1 from the prototype's Runner (pickSection / makeItem / submit / blitzResult)
// and scoreIQ. The prototype keeps one RNG per session in memory; here its int32 state
// is saved between Edge Function calls (sessions.state.rng), so the sequence of
// RNG draws — and therefore every item — is exactly the prototype's.

import { auc2, clamp, composite, dOf, eap, GATE, lz, sum } from "./irt.ts";
import { Rng } from "./rng.ts";
import { checkAnswer, type Ctx, GENS, type Item, type Lang } from "./gens/index.ts";

export const SECS = ["LOG", "SPA", "LIN", "MUS", "NAT", "KIN", "INT", "SELF", "EXI"];
export const CORE = ["LOG", "SPA", "LIN"];
export const SEC_GENS: Record<string, [string, number][]> = {
  LOG: [["matrix", .45], ["series", .35], ["digits", .2]],
  SPA: [["topview", .4], ["rotation", .35], ["corsi", .25]],
  LIN: [["analogy", .34], ["oddword", .36], ["anagram", .3]],
  MUS: [["pitch", .35], ["melody", .4], ["chord", .25]],
  NAT: [["natclass", .55], ["natodd", .45]],
  KIN: [["tap", .5], ["timing", .5]],
  INT: [["face", .6], ["faceodd", .4]],
  EXI: [["syll", .65], ["fallacy", .35]],
};
/** Generator version (`gv`): the game sends the highest it can draw with session-start;
 *  packs from before 2026-10-25 send none (0) and get exactly the prototype's lists.
 *  v1 adds the second LOG set (gens/log2.ts), v2 the second SPA set (gens/spa2.ts),
 *  v3 the second LIN set (gens/lin2.ts), v4 the second MUS set (gens/mus2.ts),
 *  v5 the second NAT set (gens/nat2.ts), v6 the second KIN set (gens/kin2.ts),
 *  v7 the second EXI set (gens/exi2.ts), v8 the Self test's wider pool + "Will you remember?"
 *  (selfGens, gens/self2.ts).
 *  Within a section the prototype's
 *  generators keep half the weight and the added ones share the other half. */
export const GV = 8;
const SEC_GENS_ADDED: Record<string, [number, string[]][]> = {
  LOG: [[1, ["symsum", "scales", "ordering", "letters", "funcmachine", "operators", "fraccmp", "wordprob", "dice", "sudoku"]]],
  SPA: [[2, ["paperfold", "cubenet", "gears", "mirror", "countshapes", "cubecount", "direction", "pieces"]]],
  LIN: [[3, ["remote", "synonym", "cloze", "unscramble", "proverb", "inference"]]],
  MUS: [[4, ["rhythm", "transpose", "beat", "contour", "cadence", "consonance"]]],
  NAT: [[5, ["inherit", "foodweb", "idkey", "camo", "spotdiff"]]],
  KIN: [[6, ["gonogo", "pursuit", "trace", "tapbeat", "dragfit"]]],
  EXI: [[7, ["wason", "necsuf", "assume", "contradict", "crt"]]],
};
export function secGens(sec: string, gv = 0): [string, number][] {
  const base = SEC_GENS[sec];
  const added = (SEC_GENS_ADDED[sec] || []).filter(([v]) => v <= gv).flatMap(([, ids]) => ids);
  if (!added.length) return base;
  return [...base.map(([id, w]): [string, number] => [id, w / 2]), ...added.map((id): [string, number] => [id, 0.5 / added.length])];
}
export const SELF_POOL = ["matrix", "rotation", "topview", "natodd", "face", "syll"];
/** gv 8: the Self test also draws from the added LOG / SPA / LIN / NAT / EXI types (not the
 *  musical ones: sound; not the body trials: speed, not knowledge). The prototype's six keep
 *  half the weight. Every 7th item from the 4th on is a "Will you remember?" trial instead. */
const SELF_GV = 8;
const SELF_ADDED_SECS = ["LOG", "SPA", "LIN", "NAT", "EXI"];
export const RECALL = "recall";
export function selfGens(gv = 0): [string, number][] {
  const base = SELF_POOL.map((id): [string, number] => [id, 1 / SELF_POOL.length]);
  if (gv < SELF_GV) return base;
  const added = SELF_ADDED_SECS.flatMap((s) => SEC_GENS_ADDED[s].flatMap(([, ids]) => ids));
  return [...base.map(([id, w]): [string, number] => [id, w / 2]), ...added.map((id): [string, number] => [id, 0.5 / added.length])];
}
/** `n` = items answered so far: the next one is a recall trial (4th, 11th, 18th...). */
export const recallSlot = (gv: number, n: number) => gv >= SELF_GV && n % 7 === 3;
export const BLITZ_GEN: Record<string, string> = { LOG: "arith", SPA: "rotquick", LIN: "oddquick", MUS: "pitchhl", NAT: "natquick", KIN: "tap", INT: "facequick", EXI: "syllquick" };
export const IQ_DURS = [5, 15, 30, 60]; // minutes
export const BLITZ_DURS = [60, 120, 180, 300]; // seconds
export const CONF_LEVELS = [0.25, 0.5, 0.75, 1];
export const MIXED_POOL = SECS.filter((s) => s !== "SELF");
export const SKIP_PENALTY_MS = 2000;

export function wpick(r: Rng, list: [string, number][]): string {
  const tot = sum(list.map((x) => x[1]));
  let u = r.n() * tot;
  for (const [k, w] of list) if ((u -= w) <= 0) return k;
  return list[list.length - 1][0];
}

/** One answered item, as stored in `responses`. */
export interface Resp { sec: string; gid: string; d: number; a: number; b: number; c: number; u: number; ms: number; conf?: number | null }

/** What the server keeps between calls for an adaptive session (sessions.state). */
export interface IqState {
  rng: number;
  used: string[];
  lastSec: string | null;
  /** generator version the client can draw (absent = 0, the prototype's generators) */
  gv?: number;
  /** SELF only: starting theta (mean of the player's LOG / SPA standings) and their % prediction */
  selfStart?: number;
  pred?: number | null;
  /** SELF only: each "Will you remember?" trial (guess, got, pairs), added by item-answer */
  recall?: { g: number; s: number; n: number }[];
}

export function newIqState(seed: number, extra: Partial<IqState> = {}): IqState {
  return { rng: new Rng(seed).state, used: [], lastSec: null, ...extra };
}

/** Runner.pickSection for an IQ test (mixed: the section with the highest SE, never twice in a row). */
function pickIqSection(r: Rng, scope: string, resp: Resp[], lastSec: string | null): string {
  if (scope !== "ALL") return scope;
  let best = "", bse = -1;
  for (const s of r.shuffle(MIXED_POOL)) {
    if (s === lastSec) continue;
    const rs = resp.filter((x) => x.sec === s);
    const se = rs.length ? eap(rs).se : 1.5;
    if (se > bse) { bse = se; best = s; }
  }
  return best;
}

/** Runner.next() + makeItem() for an IQ session. `resp` = every answered item so far, in order.
 *  Mutates `state` (rng, used, lastSec); persist it afterwards. */
export function nextIqItem(scope: string, lang: Lang, resp: Resp[], state: IqState): Item {
  const r = new Rng(0, state.rng);
  const used = new Set(state.used);
  const self = scope === "SELF";
  const sec = self ? "SELF" : pickIqSection(r, scope, resp, state.lastSec);
  state.lastSec = sec;
  const ir = r.fork();
  const ctx: Ctx = { lang, used, blitz: false };
  let item: Item | null;
  if (self) {
    const gv = state.gv ?? 0;
    const rs = resp.filter((x) => x.gid !== RECALL); // recall trials aren't ability items
    const th = rs.length ? eap(rs).theta : (state.selfStart || 0);
    const gid = recallSlot(gv, resp.length) ? RECALL : gv >= SELF_GV ? wpick(r, selfGens(gv)) : r.pick(SELF_POOL);
    item = GENS[gid].make(dOf(th - 0.6 + r.gauss() * 0.25), ir, ctx);
  } else {
    const rs = resp.filter((x) => x.sec === sec);
    const recent = rs.slice(-2).map((x) => x.gid);
    let list = secGens(sec, state.gv ?? 0);
    if (recent.length === 2 && recent[0] === recent[1]) list = list.filter((x) => x[0] !== recent[0]);
    const gid = wpick(r, list);
    const d = rs.length ? dOf(eap(rs).theta + r.gauss() * 0.3) : 4;
    item = GENS[gid].make(d, ir, ctx);
  }
  if (!item) throw new Error("generator returned no item");
  state.rng = r.state;
  state.used = [...used];
  return item;
}

/** Blitz items are a pure function of (seed, scope, lang): Runner.next() with the shuffled
 *  section bag, each item made at d = 4 from a fork. Regenerated by blitz-submit to score. */
export function blitzBatch(seed: number, scope: string, lang: Lang, count: number): Item[] {
  const r = new Rng(seed);
  let bag: string[] = [];
  const ctx: Ctx = { lang, used: new Set(), blitz: true };
  const items: Item[] = [];
  for (let i = 0; i < count; i++) {
    let sec: string;
    if (scope !== "ALL") sec = scope;
    else { if (!bag.length) bag = r.shuffle(MIXED_POOL); sec = bag.pop()!; }
    const ir = r.fork();
    const item = GENS[BLITZ_GEN[sec]].make(4, ir, ctx);
    if (!item) throw new Error("generator returned no item");
    items.push(item);
  }
  return items;
}

/** ~200 items per batch (spec §5); long Blitz runs get at least one item per second. */
export const blitzBatchSize = (durS: number) => Math.max(200, durS);

export interface Flags { hidden: number; rapid: number; implausible?: boolean }

export interface Judged { u: number; rapid: boolean; hidden: boolean; timeout: boolean }

/** Runner.submit's verdict for one answer. `value` null = timed out, '__hidden' = app left
 *  during the item. Rapid rule (spec §3): a correct answer faster than gen.minMs is scored
 *  wrong. `serverMs` is the server-measured time since the item was served (always >= the
 *  real answering time), so a client can't dodge the rule by reporting a slow `clientMs`. */
/** `untimed`: endless tests have no per-question limit (only an explicit null times out). */
export function judge(item: Pick<Item, "key" | "minMs" | "maxMs">, value: unknown, clientMs: number, serverMs = Infinity, untimed = false): Judged {
  const hidden = value === "__hidden";
  const timeout = value == null || (!untimed && clientMs > item.maxMs + 1000);
  let u = (!timeout && !hidden && checkAnswer(item.key, value)) ? 1 : 0;
  let rapid = false;
  if (u && item.minMs && (clientMs < item.minMs || serverMs < item.minMs)) { rapid = true; u = 0; }
  return { u, rapid, hidden, timeout };
}

/* ---------------- IQ scoring (prototype scoreIQ) ---------------- */

export interface SecResult {
  theta: number; se: number; n: number; hard: number; maxd: number; acc: number; lz?: number; misfit: boolean;
  auc?: number | null; bias?: number; pred?: number | null; predErr?: number | null; valid?: boolean;
  /** SELF, "Will you remember?": trials, mean |guess - got| / pairs, mean (guess - got) / pairs */
  recallN?: number; recallErr?: number | null; recallBias?: number | null;
}
export interface IqResult {
  blitz: false;
  secs: Record<string, SecResult>;
  n: number;
  flags: Flags;
  flagged: boolean;
  composite?: { theta: number; se: number } | null;
}

/** Score an adaptive session: per-section EAP, person-fit, hard items, flags.
 *  For SELF, `selfData.rows` are the answered items with the confidence the player gave, and
 *  `recall` the "Will you remember?" trials: reported beside the score, not part of it (like `pred`). */
export function scoreIQ(resp: Resp[], flags: Flags, selfData: { rows: { u: number; conf: number }[]; pred?: number | null; recall?: { g: number; s: number; n: number }[] } | null): IqResult {
  const out: IqResult = { blitz: false, secs: {}, n: resp.length, flags: Object.assign({}, flags), flagged: false };
  const secs = [...new Set(resp.map((x) => x.sec))];
  for (const s of secs) {
    const rs = resp.filter((x) => x.sec === s);
    const e = eap(rs);
    const l = rs.length >= GATE.minItems ? lz(rs, e.theta) : 0;
    out.secs[s] = { theta: e.theta, se: e.se, n: rs.length, hard: rs.filter((x) => x.u && x.d >= 8).length, maxd: Math.max(0, ...rs.filter((x) => x.u).map((x) => x.d)), acc: sum(rs.map((x) => x.u)) / rs.length, lz: l, misfit: l < GATE.lzFlag };
  }
  if (selfData) {
    const rows = selfData.rows;
    const a = auc2(rows);
    const acc = rows.length ? sum(rows.map((r) => r.u)) / rows.length : 0;
    const meanConf = rows.length ? sum(rows.map((r) => r.conf)) / rows.length : 0;
    const nC = rows.filter((r) => r.u).length, nW = rows.length - nC;
    const valid = !!a && acc >= 0.35 && nC >= 3 && nW >= 3;
    const theta = a ? clamp((a.A - 0.68) / 0.08, -3, 3) : 0;
    const se = valid ? clamp(a!.se / 0.08, 0.2, 1.5) : 1.5;
    out.secs = { SELF: { theta, se, n: rows.length, hard: 0, maxd: 0, acc, auc: a ? a.A : null, bias: meanConf - acc, pred: selfData.pred, predErr: selfData.pred != null ? selfData.pred - acc : null, misfit: false, valid } };
    const rc = selfData.recall || [];
    if (rc.length) {
      Object.assign(out.secs.SELF, {
        recallN: rc.length,
        recallErr: sum(rc.map((x) => Math.abs(x.g - x.s) / x.n)) / rc.length,
        recallBias: sum(rc.map((x) => (x.g - x.s) / x.n)) / rc.length,
      });
    }
  }
  out.flagged = flags.hidden > 2 || flags.rapid > 3 || !!flags.implausible;
  const core = CORE.filter((s) => out.secs[s]).map((s) => out.secs[s]);
  if (core.length >= 2) out.composite = composite(core);
  return out;
}

/* ---------------- Blitz scoring (prototype submit / skip / blitzResult) ---------------- */

/** One Blitz answer as posted by the client, in the order the items were shown.
 *  skip = the Skip button (costs 2 s, not counted as an answer); value null = timed out. */
export interface BlitzAnswer { seq: number; value?: unknown; ms?: number; skip?: boolean }

export interface BlitzResult {
  blitz: true; pts: number; correct: number; wrong: number; skipped: number; n: number; acc: number;
  flags: Flags; flagged: boolean;
}

export interface BlitzScored { result: BlitzResult; rows: (Resp & { seq: number; item: Item })[]; totalMs: number }

/** Points = Σ weight(correct) − Σ weight/(k−1) for wrong multiple choice (spec §2). */
export function scoreBlitz(items: Item[], answers: BlitzAnswer[]): BlitzScored {
  let pts = 0, correct = 0, wrong = 0, skipped = 0, totalMs = 0;
  const flags: Flags = { hidden: 0, rapid: 0 };
  const rows: BlitzScored["rows"] = [];
  answers.forEach((ans, i) => {
    if (ans.seq !== i) throw new Error(`answers out of order at ${i}`);
    const it = items[i];
    if (!it) throw new Error(`no item ${i}`);
    const ms = Math.max(0, Math.round(Number(ans.ms) || 0));
    totalMs += ms;
    if (ans.skip) { skipped++; totalMs += SKIP_PENALTY_MS; return; }
    const value = ans.value === undefined ? null : ans.value;
    const j = judge(it, value, ms);
    if (j.hidden) flags.hidden++;
    if (j.rapid) flags.rapid++;
    const k = it.c ? Math.round(1 / it.c) : 0;
    const answered = !j.timeout && !j.hidden;
    if (j.u) { correct++; pts += it.w; }
    else if (answered) { wrong++; if (k >= 2) pts -= it.w / (k - 1); }
    else skipped++;
    rows.push({ seq: i, sec: it.sec, gid: it.gid, d: it.d, a: it.a, b: it.b, c: it.c, u: j.u, ms, item: it });
  });
  const n = rows.length;
  const result: BlitzResult = {
    blitz: true, pts: Math.round(pts * 10) / 10, correct, wrong, skipped, n, acc: n ? correct / n : 0,
    flags, flagged: flags.hidden > 2 || flags.rapid > 3,
  };
  return { result, rows, totalMs };
}

/** What the client gets for an item: render params, never the key. */
export function publicItem(item: Item, seq: number) {
  return {
    seq, gid: item.gid, sec: item.sec, d: item.d, k: item.k, maxMs: item.maxMs, lang: item.lang ?? null,
    deferTimer: !!item.deferTimer, noTimerBar: !!item.noTimerBar, display: item.display,
  };
}

/** What responses.answer_key holds: everything needed to judge the answer later. */
export function storedKey(item: Item) {
  return { key: item.key, minMs: item.minMs, maxMs: item.maxMs, w: item.w, k: item.k };
}
