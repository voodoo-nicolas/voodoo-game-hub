// item-answer: score one IQ-test answer and serve the next item (spec §5).
//
// POST { session_id, seq, value, client_ms, conf? }
//   value:     option index | typed text | tap outcome ('hit' ...) | timing offset (ms)
//              | null (item timer ran out) | "__hidden" (app left during the item)
//   client_ms: answer time measured by the client (from when the item was ready)
//   conf:      SELF only: 0.25 | 0.5 | 0.75 | 1
// -> { next_item }   or   { done: true, result } once past the server deadline.
//
// The answer must be for the item currently pending (409 out_of_order otherwise). The
// player isn't told whether they were right (as in the prototype). Rapid correct answers
// (faster than the generator's minMs by the client's clock or the server's) score wrong.
// deno-lint-ignore-file no-explicit-any

import { type Call, HttpError, must } from "../_shared/http.ts";
import { CONF_LEVELS, judge, nextIqItem, publicItem, storedKey } from "../_shared/engine.ts";
import { clamp } from "../_shared/irt.ts";
import { answeredResponses, finishIq, loadSession } from "../_shared/session.ts";

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const s = await loadSession(db, body.session_id, uid);
  if (s.mode !== "iq") throw new HttpError(400, "not_an_iq_session", "Blitz answers go to blitz-submit.");
  if (s.status !== "live") throw new HttpError(409, "session_over", undefined, { result: s.result });
  const now = Date.now();
  if (now > Date.parse(s.deadline)) return { done: true, result: await finishIq(db, s, "time") };

  const pending = must(await db.from("responses").select("seq, served_at, answer_key")
    .eq("session_id", s.id).is("answered_at", null).order("seq", { ascending: false }).limit(1)) as any[];
  if (!pending.length) throw new HttpError(409, "no_pending_item");
  const p = pending[0];
  const seq = Number(body.seq);
  if (seq !== p.seq) throw new HttpError(409, "out_of_order", undefined, { expected: p.seq });

  let conf: number | null = null;
  if (s.scope === "SELF") {
    conf = Number(body.conf);
    if (!CONF_LEVELS.includes(conf)) throw new HttpError(400, "bad_conf");
  }

  const clientMs = clamp(Math.round(Number(body.client_ms) || 0), 0, 3_600_000);
  const serverMs = now - Date.parse(p.served_at);
  // endless tests (dur 0) have no per-question time limit
  const j = judge(p.answer_key, body.value ?? null, clientMs, serverMs, s.dur_s === 0);
  if (j.hidden) s.flags.hidden++;
  if (j.rapid) s.flags.rapid++;

  const done = must(await db.from("responses").update({ u: j.u, ms: clientMs, conf, answered_at: new Date(now).toISOString() })
    .eq("session_id", s.id).eq("seq", seq).is("answered_at", null).select("seq")) as any[];
  if (!done.length) throw new HttpError(409, "already_answered");

  const resp = await answeredResponses(db, s.id);
  const item = nextIqItem(s.scope, s.lang, resp, s.state);
  must(await db.from("responses").insert({
    session_id: s.id, seq: seq + 1, sec: item.sec, gid: item.gid, d: item.d, a: item.a, b: item.b, c: item.c,
    served_at: new Date().toISOString(), answer_key: storedKey(item),
  }));
  must(await db.from("sessions").update({ state: s.state, flags: s.flags }).eq("id", s.id));
  return { next_item: publicItem(item, seq + 1) };
}
