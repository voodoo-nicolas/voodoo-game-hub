// Session storage shared by the Edge Functions: loading a session, its answered items,
// and finishing it (score, then write section_scores / blitz_best / daily / duel_results).
// deno-lint-ignore-file no-explicit-any

import { type Db, HttpError, must } from "./http.ts";
import { type BlitzResult, type BlitzScored, type Flags, type IqState, type Resp, scoreIQ, storedKey } from "./engine.ts";
import { monthKey, utcDay } from "./rng.ts";
import { GENS, type Lang } from "./gens/index.ts";
import { bOf } from "./irt.ts";

export interface SessionRow {
  id: string; user_id: string; mode: "iq" | "blitz"; kind: "normal" | "daily" | "duel";
  scope: string; dur_s: number; ranked: boolean; seed: number; lang: Lang;
  started_at: string; deadline: string; status: "live" | "done" | "abandoned";
  flags: Flags; result: any; state: IqState & { duel?: string };
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The caller's own session, or 404. */
export async function loadSession(db: Db, id: unknown, uid: string): Promise<SessionRow> {
  if (typeof id !== "string" || !UUID.test(id)) throw new HttpError(400, "bad_session_id");
  const rows = must(await db.from("sessions").select("*").eq("id", id).limit(1)) as SessionRow[];
  if (!rows.length || rows[0].user_id !== uid) throw new HttpError(404, "session_not_found");
  const s = rows[0];
  s.seed = Number(s.seed);
  const f = (s.flags || {}) as Partial<Flags>;
  s.flags = { ...f, hidden: f.hidden ?? 0, rapid: f.rapid ?? 0 };
  s.state = (s.state || {}) as SessionRow["state"];
  return s;
}

/** Every answered item, in order (the unanswered pending one is left out).
 *  a / b / c are rebuilt from the generator and the stored key rather than read from the
 *  `real` (float4) columns, so estimates and item choice use the prototype's exact doubles. */
export async function answeredResponses(db: Db, sessionId: string): Promise<Resp[]> {
  const rows = must(await db.from("responses").select("seq, sec, gid, d, u, ms, conf, answer_key")
    .eq("session_id", sessionId).not("answered_at", "is", null).order("seq")) as any[];
  return rows.map((r) => {
    const k = r.answer_key?.k ?? 0;
    return { sec: r.sec, gid: r.gid, d: r.d, a: GENS[r.gid].a, b: bOf(r.d), c: k ? 1 / k : 0, u: r.u, ms: r.ms, conf: r.conf };
  });
}

/** Mark the session over. Only the caller that flips it from 'live' gets true, so
 *  results are written once even if two finishes race. */
async function claim(db: Db, s: SessionRow, status: "done" | "abandoned", result: unknown, flags: Flags): Promise<boolean> {
  const rows = must(await db.from("sessions").update({ status, result, flags }).eq("id", s.id).eq("status", "live").select("id"));
  return (rows as unknown[]).length > 0;
}

async function storedResult(db: Db, s: SessionRow) {
  const rows = must(await db.from("sessions").select("result").eq("id", s.id).limit(1)) as any[];
  return rows[0]?.result ?? null;
}

/** Score an IQ session from its stored answers (spec §3) and, if ranked, write one
 *  section_scores row per section played. */
export async function finishIq(db: Db, s: SessionRow, reason: string) {
  const resp = await answeredResponses(db, s.id);
  const self = s.scope === "SELF";
  const res = scoreIQ(resp, s.flags, self ? { rows: resp.map((r) => ({ u: r.u, conf: r.conf ?? 0 })), pred: s.state.pred ?? null } : null);
  const result = { ...res, reason, lang: s.lang, ranked: s.ranked, mode: s.mode, scope: s.scope };
  if (!await claim(db, s, reason === "abandoned" ? "abandoned" : "done", result, s.flags)) return await storedResult(db, s);
  if (s.ranked) {
    const day = utcDay();
    const rows = Object.entries(res.secs).filter(([, r]) => r.n).map(([sec, r]) => ({
      session_id: s.id, user_id: s.user_id, sec, day, theta: r.theta, se: r.se, n: r.n, hard: r.hard || 0,
      lang: s.lang, flagged: r.misfit || res.flagged, auc: r.auc ?? null, bias: r.bias ?? null,
    }));
    if (rows.length) must(await db.from("section_scores").insert(rows));
  }
  return result;
}

const better = (a: { pts: number; correct: number }, b?: { pts: number; correct: number } | null) =>
  !b || a.pts > b.pts || (a.pts === b.pts && a.correct > b.correct);

/** Finish a Blitz session. `scored` is null when the player left without submitting
 *  (the session is abandoned with no points; a ranked Daily attempt is still used). */
export async function finishBlitz(db: Db, s: SessionRow, scored: BlitzScored | null, reason: string) {
  const empty: BlitzResult = { blitz: true, pts: 0, correct: 0, wrong: 0, skipped: 0, n: 0, acc: 0, flags: s.flags, flagged: false };
  const res = scored ? scored.result : empty;
  const result: Record<string, unknown> = { ...res, reason, lang: s.lang, ranked: s.ranked, mode: s.mode, kind: s.kind, scope: s.scope, dur_s: s.dur_s };
  if (!await claim(db, s, scored ? "done" : "abandoned", result, res.flags)) return await storedResult(db, s);

  if (scored && scored.rows.length) {
    const at = new Date().toISOString();
    must(await db.from("responses").insert(scored.rows.map((r) => ({
      session_id: s.id, seq: r.seq, sec: r.sec, gid: r.gid, d: r.d, a: r.a, b: r.b, c: r.c, u: r.u, ms: r.ms,
      served_at: s.started_at, answered_at: at, answer_key: storedKey(r.item),
    }))));
  }
  if (!scored) return result;

  const cur = { pts: res.pts, correct: res.correct };
  if (s.kind === "duel" && s.state.duel) {
    must(await db.from("duel_results").upsert({ code: s.state.duel, user_id: s.user_id, ...cur }, { onConflict: "code,user_id", ignoreDuplicates: true }));
  }
  if (!s.ranked || res.flagged) return result;

  if (s.kind === "daily") {
    must(await db.from("daily").upsert({ user_id: s.user_id, day: utcDay(Date.parse(s.started_at)), ...cur }, { onConflict: "user_id,day", ignoreDuplicates: true }));
  } else if (s.kind === "normal") {
    const seasons = ["all", monthKey()];
    const have = must(await db.from("blitz_best").select("season, pts, correct")
      .eq("user_id", s.user_id).eq("scope", s.scope).eq("dur_s", s.dur_s).in("season", seasons)) as any[];
    const at = new Date().toISOString();
    for (const season of seasons) {
      if (!better(cur, have.find((h) => h.season === season))) continue;
      must(await db.from("blitz_best").upsert({ user_id: s.user_id, scope: s.scope, dur_s: s.dur_s, season, ...cur, at }));
      result[season === "all" ? "best" : "monthBest"] = true;
    }
    if (result.best || result.monthBest) must(await db.from("sessions").update({ result }).eq("id", s.id));
  }
  return result;
}
