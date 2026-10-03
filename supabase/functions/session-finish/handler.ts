// session-finish: end a session and record its result (spec §5).
//
// POST { session_id, reason: "time" | "quit" }
// -> { result }  (IQ: per-section theta / se / n / hard / misfit, flags, composite;
//                 calling it again returns the stored result)
//
// IQ: scored from the answers given so far (the pending item is dropped); a ranked
// session writes one section_scores row per section. Quitting a ranked test still
// uses the day's attempt. A Blitz session ends through blitz-submit; finishing one
// here means the player left without submitting, so it is abandoned with no points.

import { type Call, HttpError } from "../_shared/http.ts";
import { finishBlitz, finishIq, loadSession } from "../_shared/session.ts";

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const s = await loadSession(db, body.session_id, uid);
  if (s.status !== "live") return { result: s.result };
  const reason = body.reason === "time" ? "time" : body.reason === "quit" ? "quit" : null;
  if (!reason) throw new HttpError(400, "bad_reason");
  if (s.mode === "iq") return { result: await finishIq(db, s, reason) };
  return { result: await finishBlitz(db, s, null, reason) };
}
