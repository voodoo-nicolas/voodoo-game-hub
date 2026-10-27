// item-answer: score one IQ-test answer and serve the next item (spec §5).
//
// POST { session_id, seq, value, client_ms, conf? }
//   value:     option index | typed text | tap outcome ('hit' ...) | timing offset (ms)
//              | null (item timer ran out) | "__hidden" (app left during the item)
//   client_ms: answer time measured by the client (from when the item was ready)
//   conf:      SELF only: 0.25 | 0.5 | 0.75 | 1 (not for a "Will you remember?" trial, whose
//              value is { g: guess, picks: [...] }; its guess and score go to sessions.state.recall)
// -> { next_item, fb? }   or   { done: true, result } once past the server deadline.
//   A resend of the answer just given (the client's "Loading" watchdog sends one when a reply
//   takes over 3 s, and a lost reply is retried the same way) is not an error: it returns the
//   same next_item, without fb, and judges nothing twice. The pending item's render params are
//   kept in its answer_key.pub until it is answered (then dropped), so it can be served again.
//   fb:        practice tests only: { seq, u, key, minMs, rapid, timeout, hidden, why? } (engine.ts
//              practiceFeedback), so the player sees right / wrong and the right answer
//
// The answer must be for the item currently pending (409 out_of_order otherwise). In a
// ranked test the player isn't told whether they were right (as in the prototype); a
// practice test tells them after each answer (owner, 2026-10-25). Rapid correct answers
// (faster than the generator's minMs by the client's clock or the server's) score wrong.
// deno-lint-ignore-file no-explicit-any

import { type Call, HttpError, must } from "../_shared/http.ts";
import { CONF_LEVELS, judge, nextIqItem, practiceFeedback, publicItem, RECALL, storedKey } from "../_shared/engine.ts";
import { recallScore } from "../_shared/gens/index.ts";
import { clamp } from "../_shared/irt.ts";
import { answeredResponses, finishIq, loadSession } from "../_shared/session.ts";

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const s = await loadSession(db, body.session_id, uid);
  if (s.mode !== "iq") throw new HttpError(400, "not_an_iq_session", "Blitz answers go to blitz-submit.");
  if (s.status !== "live") throw new HttpError(409, "session_over", undefined, { result: s.result });
  const now = Date.now();
  if (now > Date.parse(s.deadline)) return { done: true, result: await finishIq(db, s, "time") };

  const pending = must(await db.from("responses").select("seq, gid, served_at, answer_key")
    .eq("session_id", s.id).is("answered_at", null).order("seq", { ascending: false }).limit(1)) as any[];
  if (!pending.length) throw new HttpError(409, "no_pending_item");
  const p = pending[0];
  const seq = Number(body.seq);
  if (seq !== p.seq) {
    if (seq === p.seq - 1 && p.answer_key.pub) return { next_item: p.answer_key.pub };
    throw new HttpError(409, "out_of_order", undefined, { expected: p.seq });
  }

  let conf: number | null = null;
  if (s.scope === "SELF" && p.gid !== RECALL) {
    conf = Number(body.conf);
    if (!CONF_LEVELS.includes(conf)) throw new HttpError(400, "bad_conf");
  }

  const clientMs = clamp(Math.round(Number(body.client_ms) || 0), 0, 3_600_000);
  const serverMs = now - Date.parse(p.served_at);
  // endless tests (dur 0) have no per-question time limit
  const j = judge(p.answer_key, body.value ?? null, clientMs, serverMs, s.dur_s === 0);
  if (j.hidden) s.flags.hidden++;
  if (j.rapid) s.flags.rapid++;
  if (p.gid === RECALL && !j.hidden) {
    const rc = recallScore(p.answer_key.key, body.value);
    if (rc) (s.state.recall ||= []).push(rc);
  }

  const { pub: _pub, ...keptKey } = p.answer_key;
  const done = must(await db.from("responses").update({ u: j.u, ms: clientMs, conf, answered_at: new Date(now).toISOString(), answer_key: keptKey })
    .eq("session_id", s.id).eq("seq", seq).is("answered_at", null).select("seq")) as any[];
  if (!done.length) {
    // a duplicate that lost the race to the same answer: serve what the winner stored, if it already has
    const again = must(await db.from("responses").select("seq, answer_key").eq("session_id", s.id).eq("seq", seq + 1).limit(1)) as any[];
    if (again.length && again[0].answer_key?.pub) return { next_item: again[0].answer_key.pub };
    throw new HttpError(409, "already_answered");
  }

  const resp = await answeredResponses(db, s.id);
  const item = nextIqItem(s.scope, s.lang, resp, s.state);
  const next_item = publicItem(item, seq + 1);
  must(await db.from("responses").insert({
    session_id: s.id, seq: seq + 1, sec: item.sec, gid: item.gid, d: item.d, a: item.a, b: item.b, c: item.c,
    served_at: new Date().toISOString(), answer_key: { ...storedKey(item), pub: next_item },
  }));
  must(await db.from("sessions").update({ state: s.state, flags: s.flags }).eq("id", s.id));
  if (s.ranked || s.kind !== "normal") return { next_item };
  return { next_item, fb: practiceFeedback(seq, p.answer_key.key, p.answer_key.minMs, j, p.answer_key.why) };
}
