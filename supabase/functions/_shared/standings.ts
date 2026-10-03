// Standings and gates (spec §3), ported 1:1 from the prototype's secStanding /
// viqStanding / nineStanding. Input = a player's section_scores rows.
// Used now for the SELF starting point; Phase 3 leaderboards / certificates reuse it.

import { combine, composite, GATE, IQ } from "./irt.ts";
import { CORE, SECS } from "./engine.ts";

const DAY = 864e5;

export interface ScoreRow {
  sec: string; day: string; theta: number; se: number; n: number; hard: number;
  lang: string | null; flagged: boolean; created_at: string;
}

export const capScore = (v: number, genius: boolean) => (v >= 130 && !genius) ? 129 : v;

/** Last 3 unflagged ranked sessions within 90 days, combined; LIN filtered by language. */
export function secStanding(rows: ScoreRow[], sec: string, lang?: string | null, now = Date.now()) {
  const list = rows
    .filter((x) => x.sec === sec)
    .sort((a, b) => Date.parse(a.created_at) - Date.parse(b.created_at))
    .filter((x) => !x.flagged && now - Date.parse(x.created_at) < 90 * DAY && (sec !== "LIN" || !lang || x.lang === lang))
    .slice(-3);
  if (!list.length) return null;
  const c = combine(list.map((x) => ({ theta: x.theta, se: x.se, n: x.n, hard: x.hard })));
  let consistent = true;
  for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) {
    const z = Math.abs(list[i].theta - list[j].theta) / Math.sqrt(list[i].se ** 2 + list[j].se ** 2);
    if (z > 2.5) consistent = false;
  }
  const cons = c.theta - 2 * c.se;
  const genius = sec === "SELF" ? (c.se <= GATE.seGenius && c.n >= 40) : (c.se <= GATE.seGenius && c.hard >= GATE.hardGenius);
  return {
    ...c,
    days: [...new Set(list.map((x) => x.day))],
    sessions: list.length,
    consistent,
    ranked: c.n >= GATE.minItems && c.se <= GATE.seBoard,
    cons,
    genius,
    score: capScore(IQ(cons), genius),
    needItems: Math.max(0, GATE.minItems - c.n),
  };
}
export type Standing = NonNullable<ReturnType<typeof secStanding>>;

/** Voodoo IQ = composite of LOG, SPA, LIN (r = 0.5) with its verification checks. */
export function viqStanding(rows: ScoreRow[], lang?: string | null, now = Date.now()) {
  const parts = CORE.map((s) => secStanding(rows, s, lang, now));
  const have = parts.filter(Boolean) as Standing[];
  const days = new Set(have.flatMap((x) => x.days));
  const secs = CORE.map((s, i) => ({ sec: s, ok: !!(parts[i] && parts[i]!.n >= GATE.minItems && parts[i]!.se <= GATE.seCore), st: parts[i] }));
  const checks = { secs, days: days.size >= 2, consistent: have.length === 3 && have.every((x) => x.consistent), verified: false };
  checks.verified = checks.secs.every((x) => x.ok) && checks.days && checks.consistent;
  if (have.length < 3) return { checks, verified: false };
  const comp = composite(have)!;
  const genius = comp.se <= GATE.seGenius && have.every((x) => x.hard >= 2);
  return { checks, verified: checks.verified, theta: comp.theta, se: comp.se, cons: comp.theta - 2 * comp.se, score: capScore(IQ(comp.theta - 2 * comp.se), genius), genius };
}

/** 9-Mind = composite of all 9 sections (r = 0.3), every section on its board. */
export function nineStanding(rows: ScoreRow[], now = Date.now()) {
  const parts = SECS.map((s) => secStanding(rows, s, null, now));
  const ranked = parts.filter((x) => x && x.ranked).length;
  if (ranked < 9) return { ranked, ok: false };
  const comp = composite(parts as Standing[], 0.3)!;
  const genius = comp.se <= GATE.seGenius;
  return { ranked, ok: true, theta: comp.theta, se: comp.se, score: capScore(IQ(comp.theta - 2 * comp.se), genius), genius };
}

export const AGE_BANDS = ["16-24", "25-34", "35-44", "45-54", "55+"];
export function ageBand(birthYear: number, now = new Date()) {
  const a = now.getUTCFullYear() - birthYear;
  return a < 16 ? null : a < 25 ? "16-24" : a < 35 ? "25-34" : a < 45 ? "35-44" : a < 55 ? "45-54" : "55+";
}
