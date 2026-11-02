-- IQ Test: the Junior board (owner, 2026-11-02: ranked play for ages 13-15).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
--
-- profiles.adult_on: the first day a 13-15 player counts as 16 (profile-save sets it from the
-- birth month and year; the birth date itself is still not stored). Until then the row keeps
-- age_band '13-15' and minor = true, so they stay off the adult boards and play on the Junior
-- board; from that day the Edge Functions treat them as 16-24, with their scores kept.
-- Null for everyone else.

alter table public.profiles add column if not exists adult_on date;

-- The public view hides a minor's country, province and age band (junior rows show only the
-- nickname). Same columns as before, so it is replaced in place.
create or replace view public.profiles_public as
  select id, nick,
         case when minor then null else age_band end as age_band,
         case when minor then null else country end as country,
         case when minor then null else province end as province
  from public.profiles;
revoke all on public.profiles_public from anon, authenticated;
grant select on public.profiles_public to authenticated;
