// delete-account: a signed-in player deletes their own account (Profile ->
// "Delete account"; Google Play requires in-app account deletion). Replaces the
// old delete_my_account() RPC (docs/delete_my_account.sql), which only removed
// the auth user and relied on cascades.
//
// POST {} with the player's access token -> { ok: true }
// Deletes EVERY row we hold for the caller -- nothing is kept, not even store
// rows (owner 2026-11-19: no purchases exist yet, keep nothing) -- then the
// auth user itself with the service role (env SUPABASE_SERVICE_ROLE_KEY, set by
// Supabase; never in the APK). docs/ACCOUNT_DELETION.md lists every table.
//
// Idempotent: a second call (retry after a dropped connection, the account is
// already gone) still answers { ok: true }.
// deno-lint-ignore-file no-explicit-any

import type { Db } from "../_shared/http.ts";

/** [table, column holding the user id]. Children before parents (FKs). */
export const USER_ROWS: [string, string][] = [
  // Voodoo IQ: answers hang off sessions; section_scores also carry user_id.
  ["section_scores", "user_id"],
  ["blitz_best", "user_id"],
  ["daily", "user_id"],
  ["duel_results", "user_id"],
  ["duels", "created_by"],
  ["certificates", "user_id"],
  // Leaderboards, awards, cloud progress.
  ["scores", "user_id"],
  ["player_awards", "user_id"],
  ["game_progress", "user_id"],
  // Friends and invites, both directions.
  ["friendships", "requester"],
  ["friendships", "target"],
  ["game_invites", "sender"],
  ["game_invites", "recipient"],
  // Store: trials, entitlements (incl. grants), legacy purchase tables. Nothing kept.
  ["store_trials", "user_id"],
  ["store_entitlements", "user_id"],
  ["user_purchases", "user_id"],
  ["purchase_history", "user_id"],
  // Founders list is by email, handled in deleteAccount().
  // Consents, bug reports, public player card.
  ["user_consents", "user_id"],
  ["client_reports", "user_id"],
  ["player_cards", "user_id"],
];

/** Tables that are missing on a project (SQL never run) are skipped, not errors. */
function missingTable(err: any): boolean {
  const code = String(err?.code ?? "");
  return code === "42P01" || code === "PGRST205" || code === "42703" || code === "PGRST204";
}

async function del(db: Db, table: string, col: string, value: string): Promise<void> {
  const { error } = await db.from(table).delete().eq(col, value);
  if (error && !missingTable(error)) throw error;
}

export async function deleteAccount(db: Db, uid: string, email: string | null): Promise<{ ok: true }> {
  // IQ sessions: their responses first, then the sessions, then the profile.
  const { data: sessions, error } = await db.from("sessions").select("id").eq("user_id", uid);
  if (error && !missingTable(error)) throw error;
  const ids = (sessions ?? []).map((s: any) => s.id);
  if (ids.length) {
    const r = await db.from("responses").delete().in("session_id", ids);
    if (r.error && !missingTable(r.error)) throw r.error;
    const s = await db.from("section_scores").delete().in("session_id", ids);
    if (s.error && !missingTable(s.error)) throw s.error;
  }
  for (const [table, col] of USER_ROWS) await del(db, table, col, uid);
  await del(db, "sessions", "user_id", uid);
  await del(db, "profiles", "id", uid);
  if (email) await del(db, "founders", "email", email.toLowerCase());
  // Last: the sign-in itself. "User not found" = already deleted (idempotent).
  const res = await db.auth.admin.deleteUser(uid);
  if (res.error && (res.error as any).status !== 404 && !/not.?found/i.test(res.error.message)) throw res.error;
  return { ok: true };
}
