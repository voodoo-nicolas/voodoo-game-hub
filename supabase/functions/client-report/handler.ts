// client-report: a game tells us it got stuck or crashed (owner, 2026-10-27: the IQ test
// froze on "Loading" on the PC and web builds).
//
// POST { game, kind, build?, platform?, detail? }
//   game:     "voodoo_iq" ...  (max 40 chars, letters / digits / _ -)
//   kind:     "stall" (a request had no reply for 3 s) | "stall_end" (it did answer, late) |
//             "error" | "crash"  (max 40 chars)
//   detail:   anything useful, as one JSON object (what was being asked, how long, the
//             error code, the screen state). Never put names, emails or tokens in it.
// -> { ok: true }   (or { ok: true, dropped: true } past the per-player limit)
//
// Stored in client_reports (supabase/migrations/20261027000000_client_reports.sql), one row
// per report; only this function writes it. Read them with supabase/checks/client_reports.sql.
// deno-lint-ignore-file no-explicit-any

import { type Call, HttpError, must } from "../_shared/http.ts";

const MAX_DETAIL = 8_000;
const PER_HOUR = 30;
const TAG = /^[A-Za-z0-9_-]{1,40}$/;

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const game = String(body.game ?? ""), kind = String(body.kind ?? "");
  if (!TAG.test(game) || !TAG.test(kind)) throw new HttpError(400, "bad_report");
  let detail: Record<string, unknown> = {};
  if (body.detail && typeof body.detail === "object" && !Array.isArray(body.detail)) {
    detail = JSON.stringify(body.detail).length <= MAX_DETAIL ? body.detail : { truncated: true };
  }
  const recent = must(await db.from("client_reports").select("id").eq("user_id", uid)
    .gte("created_at", new Date(Date.now() - 3_600_000).toISOString()).limit(PER_HOUR + 1)) as any[];
  if (recent.length >= PER_HOUR) return { ok: true, dropped: true };
  must(await db.from("client_reports").insert({
    user_id: uid, game, kind, detail,
    build: Number.isInteger(body.build) ? body.build : null,
    platform: String(body.platform ?? "").slice(0, 40),
  }));
  return { ok: true };
}
