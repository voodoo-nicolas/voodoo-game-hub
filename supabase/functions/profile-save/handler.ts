// profile-save: create or update the caller's Voodoo IQ player profile.
// Not in spec §5's list, but clients have no write access to `profiles` (§4), and
// sessions need a profile, so this is the one write path for it.
//
// POST { nick: 2..18 chars, birth_year, birth_month?: 1..12, country?: "AR" (ISO 3166-1 alpha-2), province?, lang?: "en"|"es" }
// -> { profile }
// Only the age band is kept (the birth date isn't stored); under 16 = minor. 13-15 = band
// "13-15" (Junior board, owner 2026-11-02) + adult_on, the day they count as 16; under 13 =
// no band (practice only). Province is kept for Argentina only, as in the prototype.

import { type Call, HttpError, must } from "../_shared/http.ts";
import { adultOn, ageBand, JUNIOR_BAND } from "../_shared/standings.ts";

export default async function handler({ body, uid, db }: Call): Promise<unknown> {
  const nick = String(body.nick ?? "").trim();
  if (nick.length < 2 || nick.length > 18) throw new HttpError(400, "bad_nick");
  const year = new Date().getUTCFullYear();
  const by = Number(body.birth_year);
  if (!Number.isInteger(by) || by < year - 110 || by > year) throw new HttpError(400, "bad_birth_year");
  const bm = Number(body.birth_month ?? 0);
  const month = Number.isInteger(bm) && bm >= 1 && bm <= 12 ? bm : 0;
  const band = ageBand(by, new Date(), month);
  const junior = band === JUNIOR_BAND;
  const country = typeof body.country === "string" && /^[A-Z]{2}$/.test(body.country) ? body.country : "XX";
  const province = country === "AR" && typeof body.province === "string" ? body.province.trim().slice(0, 40) || null : null;
  const lang = body.lang === "en" ? "en" : "es";
  const profile = must(await db.from("profiles").upsert({
    id: uid, nick, age_band: band, minor: !band || junior, adult_on: junior ? adultOn(by, month) : null, country, province, lang,
  }).select().single());
  return { profile };
}
