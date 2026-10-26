// leaderboard: the Voodoo IQ boards (spec §3-4), computed like the prototype's boardRows.
//
// POST { board: "viq" | "nine" | "sec" | "blitz",
//        sec?: <section>                                                   (board "sec")
//        scope?: "ALL"|<section>, dur_s?: 60|120|180|300, season?: "month"|"all"  (board "blitz")
//        age?: "16-24"..., country?: "AR", province?, lang?: "en"|"es" (verbal language: viq / LIN) }
// board "player" { nick } -> one player's detail card (tap a name on a board):
//    { nick, country, province, age_band, tests, answered, correct, pct, per_min, avg_s, iq, se,
//      sections: [{ sec, iq, se, n }] } over their ranked IQ tests; 404 for unknown nicks and minors.
// -> { rows: [...], provisional: [...] }, each row:
//    { nick, country, province, age_band, score, theta, se, genius, need_items, sections, correct, me }
//
// Nothing is hidden or capped (the user's decision 2026-10-03, replacing spec §3's
// cautious rank score and 129 cap): every player with a standing is ranked by their
// estimate, score = IQ(theta). `verified` marks the ones that pass the gates (Voodoo IQ
// verification / a section's board: 15+ items, SE <= 0.45); `genius` = 130+ proven.
// Only 9-Mind needs all nine sections to compute, so it still lists the rest as
// `provisional` (k/9). Blitz: best points, then correct answers.
// Reads with the service role; no user ids leave the server (`me` marks the caller).
// deno-lint-ignore-file no-explicit-any

import { type Call, HttpError, must } from "../_shared/http.ts";
import { IQ } from "../_shared/irt.ts";
import { BLITZ_DURS, MIXED_POOL, SECS } from "../_shared/engine.ts";
import { nineStanding, type ScoreRow, secStanding, viqStanding } from "../_shared/standings.ts";
import { monthKey } from "../_shared/rng.ts";
import { closeStaleSessions, scorable } from "../_shared/session.ts";

const DAY = 864e5;
const MAX_ROWS = 100;

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const board = String(body.board ?? "");
  if (!["viq", "nine", "sec", "blitz", "player"].includes(board)) throw new HttpError(400, "bad_board");
  if (board === "player") return await playerCard(db, String(body.nick ?? ""));
  const lang = body.lang === "en" || body.lang === "es" ? body.lang : null;
  // an endless test the player walked away from (idle 30 min) shows up on the boards
  await closeStaleSessions(db, uid, 30 * 60_000);

  // players, filtered by age band / country / province
  let pq = db.from("profiles").select("id, nick, age_band, country, province, minor");
  if (body.age) pq = pq.eq("age_band", String(body.age));
  if (body.country) pq = pq.eq("country", String(body.country));
  if (body.province) pq = pq.eq("province", String(body.province));
  const players = new Map<string, any>();
  for (const p of must(await pq) as any[]) if (!p.minor) players.set(p.id, p);

  const base = (id: string) => {
    const p = players.get(id);
    return { nick: p.nick, country: p.country, province: p.province, age_band: p.age_band, me: id === uid };
  };
  const rows: any[] = [];
  const provisional: any[] = [];

  if (board === "blitz") {
    const scope = String(body.scope ?? "ALL");
    const dur = Number(body.dur_s ?? 120);
    if (scope !== "ALL" && !MIXED_POOL.includes(scope)) throw new HttpError(400, "bad_scope");
    if (!BLITZ_DURS.includes(dur)) throw new HttpError(400, "bad_dur");
    const season = body.season === "all" ? "all" : monthKey();
    const best = must(await db.from("blitz_best").select("user_id, pts, correct").eq("scope", scope).eq("dur_s", dur).eq("season", season)) as any[];
    for (const b of best) if (players.has(b.user_id)) rows.push({ ...base(b.user_id), score: b.pts, correct: b.correct });
  } else {
    const sec = String(body.sec ?? "LOG");
    if (board === "sec" && !SECS.includes(sec)) throw new HttpError(400, "bad_sec");
    let q = db.from("section_scores").select("user_id, sec, day, theta, se, n, hard, lang, flagged, created_at")
      .gte("created_at", new Date(Date.now() - 90 * DAY).toISOString());
    if (board === "sec") q = q.eq("sec", sec);
    const byUser = new Map<string, ScoreRow[]>();
    for (const r of must(await q) as any[]) {
      if (!players.has(r.user_id)) continue;
      if (!byUser.has(r.user_id)) byUser.set(r.user_id, []);
      byUser.get(r.user_id)!.push(r);
    }
    for (const [id, list] of byUser) {
      if (board === "viq") {
        const v: any = viqStanding(list, lang);
        if (v.theta == null) continue;
        rows.push({ ...base(id), score: IQ(v.theta), theta: v.theta, se: v.se, verified: v.verified, genius: v.genius && v.verified });
      } else if (board === "nine") {
        const v: any = nineStanding(list);
        if (!v.ok) {
          if (v.ranked) provisional.push({ ...base(id), score: -1, sections: v.ranked });
          continue;
        }
        rows.push({ ...base(id), score: IQ(v.theta), theta: v.theta, se: v.se, verified: true, genius: v.genius });
      } else {
        const v = secStanding(list, sec, sec === "LIN" ? lang : null);
        if (!v) continue;
        rows.push({ ...base(id), score: IQ(v.theta), theta: v.theta, se: v.se, verified: v.ranked, genius: v.genius && v.ranked && IQ(v.theta) >= 130, need_items: v.needItems });
      }
    }
  }
  const order = (a: any, b: any) => b.score - a.score || (b.correct ?? 0) - (a.correct ?? 0);
  rows.sort(order);
  provisional.sort(order);
  // the top 100, plus the caller if they're further down
  const keep = (list: any[]) => list.slice(0, MAX_ROWS).concat(list.slice(MAX_ROWS).filter((r) => r.me));
  return { rows: keep(rows), provisional: keep(provisional) };
}

/** The detail card for one player: answers, % correct and pace from their ranked IQ tests,
 *  plus their standing per section. Minors never get a card (they aren't on the boards). */
async function playerCard(db: Call["db"], nick: string) {
  const found = must(await db.from("profiles").select("id, nick, age_band, country, province, minor").eq("nick", nick).limit(1)) as any[];
  const p = found[0];
  if (!p || p.minor) throw new HttpError(404, "no_player");
  const sess = must(await db.from("sessions").select("id").eq("user_id", p.id).eq("mode", "iq").eq("ranked", true)
    .in("status", ["done", "abandoned"]).order("started_at", { ascending: false }).limit(200)) as any[];
  let answered = 0, correct = 0, ms = 0;
  const ids = sess.map((r) => r.id);
  for (let i = 0; i < ids.length; i += 50) {
    const rs = must(await db.from("responses").select("u, ms, gid, d, answer_key").in("session_id", ids.slice(i, i + 50)).not("answered_at", "is", null)) as any[];
    for (const r of rs) {
      if (!scorable(r.gid, r.answer_key, r.d)) continue;
      answered++;
      if (Number(r.u) >= 1) correct++;
      ms += Number(r.ms) || 0;
    }
  }
  const scores = must(await db.from("section_scores").select("user_id, sec, day, theta, se, n, hard, lang, flagged, created_at")
    .eq("user_id", p.id).gte("created_at", new Date(Date.now() - 90 * DAY).toISOString())) as any[];
  const sections: any[] = [];
  for (const sec of SECS) {
    const v: any = secStanding(scores.filter((r) => r.sec === sec), sec, null);
    if (v) sections.push({ sec, iq: Math.round(IQ(v.theta)), se: v.se, n: v.n ?? null });
  }
  const v: any = viqStanding(scores, null);
  return {
    nick: p.nick, country: p.country, province: p.province, age_band: p.age_band,
    tests: sess.length, answered, correct,
    pct: answered ? correct / answered : 0,
    per_min: ms > 0 ? correct / (ms / 60000) : 0,
    avg_s: answered ? ms / answered / 1000 : 0,
    iq: v.theta == null ? null : Math.round(IQ(v.theta)), se: v.theta == null ? null : v.se,
    sections,
  };
}
