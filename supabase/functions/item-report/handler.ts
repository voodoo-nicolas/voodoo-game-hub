// item-report: the player flags a practice question as looking wrong (🚩, owner 2026-10-25).
//
// POST { session_id, seq, why, value?, display? }
//   why:     "none" (no right answer) | "two" (more than one right answer) | "picture" (the
//            drawing or sound is wrong) | "other"
//   value:   what the player answered (as sent to item-answer / blitz-submit)
//   display: the item's render params as the client drew them, so the question can be
//            drawn again exactly (dropped when over 100 KB)
// -> { ok: true }
//
// Practice sessions only (ranked tests show no answers, so nothing to report there). The
// report goes into that item's own responses.answer_key (`report`), next to the key, so no
// schema change is needed and nothing else writes that column after the item is served.
// Find them with supabase/checks/iq_reports.sql. Reporting again replaces the report.
// deno-lint-ignore-file no-explicit-any

import { type Call, HttpError, must } from "../_shared/http.ts";
import { loadSession } from "../_shared/session.ts";

const WHY = ["none", "two", "picture", "other"];
const MAX_DISPLAY = 100_000;

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const s = await loadSession(db, body.session_id, uid);
  if (s.ranked || s.kind !== "normal") throw new HttpError(403, "not_practice");
  const seq = Number(body.seq);
  if (!Number.isInteger(seq) || seq < 0) throw new HttpError(400, "bad_seq");
  const why = String(body.why ?? "");
  if (!WHY.includes(why)) throw new HttpError(400, "bad_why");

  const rows = must(await db.from("responses").select("seq, answer_key, answered_at")
    .eq("session_id", s.id).eq("seq", seq).limit(1)) as any[];
  if (!rows.length || !rows[0].answered_at) throw new HttpError(404, "no_answered_item");

  const report: Record<string, unknown> = { why, at: new Date().toISOString(), value: body.value ?? null };
  if (body.display && typeof body.display === "object" && JSON.stringify(body.display).length <= MAX_DISPLAY) report.display = body.display;
  must(await db.from("responses").update({ answer_key: { ...rows[0].answer_key, report } })
    .eq("session_id", s.id).eq("seq", seq));
  return { ok: true };
}
