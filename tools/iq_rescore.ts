// IQ Test: rescore finished tests that hold answers to wrongly keyed questions (KEY_REV in
// supabase/functions/_shared/session.ts; uses: topview, 2026-10-25, where the "right"
// top view was the mirror image; natclass d 7+ / natodd d 8+, 2026-10-26, mod-3 pair rules). Those answers are left out and each test is scored again
// with the same code as session-finish: section_scores rows updated in place (a section left
// with no answers loses its row), the stored result replaced. Leaderboards read
// section_scores, so they follow at once. Tests still open are scored right when they finish.
//
// Run by the owner (Claude has no production access). Dry run by default: prints what would
// change and writes nothing. --apply writes. Safe to run again (same answers, same scores).
//   $env:SUPABASE_URL = "https://swyzfsyvmqxabhvvhhtn.supabase.co"
//   $env:SUPABASE_SERVICE_ROLE_KEY = "<service_role key: Dashboard > Project Settings > API>"
//   deno run --allow-net --allow-env --allow-read tools/iq_rescore.ts            (dry run)
//   deno run --allow-net --allow-env --allow-read tools/iq_rescore.ts --apply
// deno-lint-ignore-file no-explicit-any

import { createClient } from "npm:@supabase/supabase-js@2";
import { type Db, must } from "../supabase/functions/_shared/http.ts";
import { KEY_REV, rescoreIq, scorable, type SessionRow } from "../supabase/functions/_shared/session.ts";
import { IQ } from "../supabase/functions/_shared/irt.ts";

const PAGE = 1000;

/** Finished IQ sessions with at least one answer that no longer counts, oldest first. */
export async function sessionsToRescore(db: Db): Promise<SessionRow[]> {
  const ids = new Set<string>();
  for (const gid of Object.keys(KEY_REV)) {
    for (let from = 0; ; from += PAGE) {
      const rows = must(await db.from("responses").select("session_id, gid, d, answer_key").eq("gid", gid)
        .not("answered_at", "is", null).order("session_id").range(from, from + PAGE - 1)) as any[];
      for (const r of rows) if (!scorable(r.gid, r.answer_key, r.d)) ids.add(r.session_id);
      if (rows.length < PAGE) break;
    }
  }
  const out: SessionRow[] = [];
  const list = [...ids];
  for (let i = 0; i < list.length; i += 100) {
    const rows = must(await db.from("sessions").select("*").in("id", list.slice(i, i + 100)).eq("mode", "iq")
      .in("status", ["done", "abandoned"])) as any[];
    for (const s of rows) {
      s.seed = Number(s.seed);
      s.flags = { ...(s.flags || {}), hidden: s.flags?.hidden ?? 0, rapid: s.flags?.rapid ?? 0 };
      s.state = s.state || {};
      out.push(s);
    }
  }
  return out.sort((a, b) => String(a.started_at).localeCompare(String(b.started_at)));
}

const fmt = (r: any) => r?.n ? `${Math.round(IQ(r.theta))} (n ${r.n})` : "-";

/** Rescore every affected session; returns one printable line per changed section. */
export async function rescoreAll(db: Db, apply: boolean, log = console.log) {
  const list = await sessionsToRescore(db);
  const users = new Set<string>();
  let ranked = 0;
  for (const s of list) {
    const { before, after } = await rescoreIq(db, s, apply);
    users.add(s.user_id);
    if (s.ranked) ranked++;
    for (const sec of new Set([...Object.keys(before), ...Object.keys(after)])) {
      const b = before[sec], a = after[sec];
      if (b?.n === a?.n && b?.theta === a?.theta) continue;
      log(`${String(s.started_at).slice(0, 10)}  ${s.id.slice(0, 8)}  user ${s.user_id.slice(0, 8)}  ${s.ranked ? "ranked" : "practice"}  ${s.scope.padEnd(4)}  ${sec.padEnd(4)}  ${fmt(b)} -> ${fmt(a)}`);
    }
  }
  log(`${list.length} tests (${ranked} ranked), ${users.size} players ${apply ? "rescored" : "would be rescored (dry run: nothing written; add --apply)"}`);
  return { sessions: list.length, ranked, users: users.size };
}

if (import.meta.main) {
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY first (see the header of this file).");
    Deno.exit(1);
  }
  const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  await rescoreAll(db, Deno.args.includes("--apply"));
}
