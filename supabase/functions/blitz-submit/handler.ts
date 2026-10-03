// blitz-submit: score a whole Blitz run in one call (spec §5).
//
// POST { session_id, reason?: "time" | "quit",
//        answers: [{ seq, value, ms } | { seq, skip: true, ms? }, ...] }   in play order
//   value: option index | typed text | tap outcome; null = the item timed out
//   ms:    time the item was on screen and ready
// -> { result: { pts, correct, wrong, skipped, n, acc, flags, flagged, best?, monthBest? } }
//
// The server regenerates the batch from the session seed (the client never had keys)
// and scores it: Σ weight(correct) − Σ weight/(k−1) for wrong multiple choice, skips
// cost 2 s. Plausibility: a correct answer faster than its generator's minMs scores
// wrong; total answer time (+2 s per skip) must fit in the time limit + 2 s and in the
// real time since the session started. A flagged run is kept but never reaches a board.
// deno-lint-ignore-file no-explicit-any

import { type Call, HttpError } from "../_shared/http.ts";
import { type BlitzAnswer, blitzBatch, blitzBatchSize, type BlitzScored, scoreBlitz } from "../_shared/engine.ts";
import { finishBlitz, loadSession } from "../_shared/session.ts";

const SLACK_MS = 2000;

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const s = await loadSession(db, body.session_id, uid);
  if (s.mode !== "blitz") throw new HttpError(400, "not_a_blitz_session");
  if (s.status !== "live") throw new HttpError(409, "session_over", undefined, { result: s.result });
  const now = Date.now();
  if (now > Date.parse(s.deadline)) {
    await finishBlitz(db, s, null, "late");
    throw new HttpError(409, "too_late");
  }

  const count = blitzBatchSize(s.dur_s);
  const answers = body.answers;
  if (!Array.isArray(answers) || answers.length > count) throw new HttpError(400, "bad_answers");
  const items = blitzBatch(s.seed, s.scope, s.lang, count);
  let scored: BlitzScored;
  try {
    scored = scoreBlitz(items, answers as BlitzAnswer[]);
  } catch (e) {
    throw new HttpError(400, "bad_answers", (e as Error).message);
  }

  const answerMs = (answers as any[]).reduce((t, a) => t + Math.max(0, Math.round(Number(a?.ms) || 0)), 0);
  const implausible = scored.totalMs > s.dur_s * 1000 + SLACK_MS || answerMs > now - Date.parse(s.started_at) + SLACK_MS;
  if (implausible) {
    scored.result.flags.implausible = true;
    scored.result.flagged = true;
  }
  const reason = body.reason === "quit" ? "quit" : "time";
  return { result: await finishBlitz(db, s, scored, reason) };
}
