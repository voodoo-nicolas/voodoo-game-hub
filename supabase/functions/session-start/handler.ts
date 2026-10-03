// session-start: create an IQ test or Blitz session (spec §5).
//
// POST { mode: "iq"|"blitz", kind?: "normal"|"daily"|"duel", scope: "ALL"|<section>,
//        dur: minutes (iq: 5/15/30/60) | seconds (blitz: 60/120/180/300),
//        ranked: bool, duel?: "<6-char code>", lang?: "en"|"es", pred?: 0..1 (SELF only) }
// -> IQ:    { session_id, deadline, ..., first_item }
// -> Blitz: { session_id, deadline, ..., first_item, items }   (whole batch, no keys)
//
// Ranked eligibility (409 { error: "not_eligible", why }): needs a profile with age 16+
// ("age"); IQ: one ranked attempt per scope per UTC day ("used_today"); Daily Brain:
// one ranked attempt per UTC day ("daily_done"). Daily and Duel force their own
// scope / time / seed; duels are never ranked and allow one attempt per player.
// deno-lint-ignore-file no-explicit-any

import { type Call, HttpError, must } from "../_shared/http.ts";
import { blitzBatch, blitzBatchSize, BLITZ_DURS, IQ_DURS, type IqState, MIXED_POOL, newIqState, nextIqItem, publicItem, SECS, storedKey } from "../_shared/engine.ts";
import { dailySeed, randomSeed, utcDay } from "../_shared/rng.ts";
import { type ScoreRow, secStanding } from "../_shared/standings.ts";
import type { Lang } from "../_shared/gens/index.ts";

/** Instructions pause the client's clock, so the server allows 10 extra minutes
 *  (the prototype's own session deadline). */
const DEADLINE_GRACE_MS = 600_000;

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const profile = (must(await db.from("profiles").select("*").eq("id", uid).limit(1)) as any[])[0];
  if (!profile) throw new HttpError(412, "no_profile", "Create a profile first (profile-save).");

  const lang: Lang = body.lang === "en" || body.lang === "es" ? body.lang : profile.lang === "en" ? "en" : "es";
  const kind: "normal" | "daily" | "duel" = body.kind === "daily" || body.kind === "duel" ? body.kind : "normal";
  let mode: "iq" | "blitz" = body.mode === "blitz" ? "blitz" : body.mode === "iq" ? "iq" : (() => { throw new HttpError(400, "bad_mode"); })();
  let scope = String(body.scope ?? "");
  let dur = Number(body.dur);
  let ranked = body.ranked === true;
  let seed = randomSeed();
  const state: Partial<IqState> & { duel?: string } = {};
  const todayStart = utcDay() + "T00:00:00Z";

  if (kind === "daily") {
    mode = "blitz"; scope = "ALL"; dur = 180; seed = dailySeed();
  } else if (kind === "duel") {
    const code = String(body.duel ?? "").toUpperCase();
    if (!/^[A-Z0-9]{6}$/.test(code)) throw new HttpError(400, "bad_duel_code");
    const duel = (must(await db.from("duels").select("*").eq("code", code).limit(1)) as any[])[0];
    if (!duel) throw new HttpError(404, "duel_not_found");
    const played = must(await db.from("sessions").select("id").eq("user_id", uid).eq("kind", "duel").eq("state->>duel", code).limit(1)) as any[];
    if (played.length) throw new HttpError(409, "duel_played");
    mode = "blitz"; scope = duel.scope; dur = duel.dur_s; seed = Number(duel.seed); ranked = false; state.duel = code;
  }

  if (mode === "iq") {
    if (!IQ_DURS.includes(dur)) throw new HttpError(400, "bad_dur");
    if (scope !== "ALL" && !SECS.includes(scope)) throw new HttpError(400, "bad_scope");
  } else {
    if (!BLITZ_DURS.includes(dur)) throw new HttpError(400, "bad_dur");
    if (scope !== "ALL" && !MIXED_POOL.includes(scope)) throw new HttpError(400, "bad_scope"); // no SELF Blitz
  }
  const durS = mode === "iq" ? dur * 60 : dur;

  if (ranked) {
    let why: string | null = null;
    if (profile.minor || !profile.age_band) why = "age";
    else if (kind === "daily") {
      const used = must(await db.from("sessions").select("id").eq("user_id", uid).eq("kind", "daily").eq("ranked", true).gte("started_at", todayStart).limit(1)) as any[];
      if (used.length) why = "daily_done";
    } else if (mode === "iq") {
      const used = must(await db.from("sessions").select("id").eq("user_id", uid).eq("mode", "iq").eq("ranked", true).eq("scope", scope).gte("started_at", todayStart).limit(1)) as any[];
      if (used.length) why = "used_today";
    }
    if (why) throw new HttpError(409, "not_eligible", undefined, { why });
  }

  // SELF starts targeting at the mean of the player's LOG / SPA standings (prototype startRun)
  if (mode === "iq" && scope === "SELF") {
    const rows = must(await db.from("section_scores").select("sec, day, theta, se, n, hard, lang, flagged, created_at").eq("user_id", uid).in("sec", ["LOG", "SPA"])) as ScoreRow[];
    const xs = ["LOG", "SPA"].map((s) => secStanding(rows, s)).filter(Boolean);
    state.selfStart = xs.length ? xs.reduce((a, x) => a + x!.theta, 0) / xs.length : 0;
    const pred = Number(body.pred);
    state.pred = body.pred != null && pred >= 0 && pred <= 1 ? pred : null;
  }

  const now = Date.now();
  const deadline = new Date(now + durS * 1000 + DEADLINE_GRACE_MS).toISOString();
  const base = { user_id: uid, mode, kind, scope, dur_s: durS, ranked, seed, lang, started_at: new Date(now).toISOString(), deadline };
  const meta = { mode, kind, scope, dur_s: durS, ranked, lang };

  if (mode === "blitz") {
    const items = blitzBatch(seed, scope, lang, blitzBatchSize(durS)).map((it, i) => publicItem(it, i));
    const row = must(await db.from("sessions").insert({ ...base, state }).select("id").single()) as any;
    return { session_id: row.id, deadline, ...meta, first_item: items[0], items };
  }

  const iqState = newIqState(seed, state);
  const item = nextIqItem(scope, lang, [], iqState);
  const row = must(await db.from("sessions").insert({ ...base, state: iqState }).select("id").single()) as any;
  must(await db.from("responses").insert({
    session_id: row.id, seq: 0, sec: item.sec, gid: item.gid, d: item.d, a: item.a, b: item.b, c: item.c,
    served_at: new Date().toISOString(), answer_key: storedKey(item),
  }));
  return { session_id: row.id, deadline, ...meta, first_item: publicItem(item, 0) };
}
