// profile-save: create or update the caller's Voodoo IQ player profile.
// Not in spec §5's list, but clients have no write access to `profiles` (§4), and
// sessions need a profile, so this is the one write path for it.
//
// POST { nick: 2..18 chars, birth_year, country?: "AR" (ISO 3166-1 alpha-2), province?, lang?: "en"|"es" }
// -> { profile }
// Only the age band is kept (the birth year isn't stored); under 16 = minor
// (practice only). Province is kept for Argentina only, as in the prototype.

import { type Call, HttpError, must } from "../_shared/http.ts";
import { ageBand } from "../_shared/standings.ts";

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const nick = String(body.nick ?? "").trim();
  if (nick.length < 2 || nick.length > 18) throw new HttpError(400, "bad_nick");
  const year = new Date().getUTCFullYear();
  const by = Number(body.birth_year);
  if (!Number.isInteger(by) || by < year - 110 || by > year) throw new HttpError(400, "bad_birth_year");
  const band = ageBand(by);
  const country = typeof body.country === "string" && /^[A-Z]{2}$/.test(body.country) ? body.country : "XX";
  const province = country === "AR" && typeof body.province === "string" ? body.province.trim().slice(0, 40) || null : null;
  const lang = body.lang === "en" ? "en" : "es";
  const profile = must(await db.from("profiles").upsert({ id: uid, nick, age_band: band, minor: !band, country, province, lang }).select().single());
  return { profile };
}
