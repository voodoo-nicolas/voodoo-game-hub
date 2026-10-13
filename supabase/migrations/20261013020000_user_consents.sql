-- Viral Game Hub: record that a player accepted the Terms/EULA and the Privacy
-- Policy (compliance pack, Task 2; app v0.35+).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
--
-- One row per account, document and version. Only the age BRACKET is stored
-- ('13-15', '16-17', '18+'), never a birth date; under-13 players never reach
-- the server (the app blocks account creation locally).
-- Row Level Security: a player can read their own rows and add their own; nobody
-- edits or deletes them through the API (they go when the account is deleted).
--
--   consent_record(version, locale, bracket) -> records BOTH documents at that version
--   consent_status()                         -> the versions I accepted last (for re-prompting)

create table if not exists public.user_consents (
  id           bigint      generated always as identity primary key,
  user_id      uuid        not null references auth.users (id) on delete cascade,
  doc_type     text        not null check (doc_type in ('terms_eula', 'privacy')),
  doc_version  text        not null check (char_length(doc_version) between 1 and 20),
  locale       text        not null check (locale in ('es', 'en')),
  age_bracket  text        not null default '' check (age_bracket in ('', '13-15', '16-17', '18+')),
  accepted_at  timestamptz not null default now(),
  unique (user_id, doc_type, doc_version)
);
create index if not exists user_consents_user_idx on public.user_consents (user_id, accepted_at desc);

alter table public.user_consents enable row level security;
revoke all on public.user_consents from anon, authenticated;
grant select on public.user_consents to authenticated;

drop policy if exists "Players read their own consents" on public.user_consents;
create policy "Players read their own consents" on public.user_consents
  for select to authenticated using (auth.uid() = user_id);

create or replace function public.consent_record(p_version text, p_locale text, p_bracket text default '')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  loc text := case when p_locale = 'en' then 'en' else 'es' end;
  br text := case when p_bracket in ('13-15', '16-17', '18+') then p_bracket else '' end;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  insert into user_consents (user_id, doc_type, doc_version, locale, age_bracket)
  values (me, 'terms_eula', left(p_version, 20), loc, br),
         (me, 'privacy',    left(p_version, 20), loc, br)
  on conflict (user_id, doc_type, doc_version) do nothing;
end;
$$;

create or replace function public.consent_status()
returns table (doc_type text, doc_version text, accepted_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select distinct on (doc_type) doc_type, doc_version, accepted_at
  from user_consents
  where user_id = auth.uid()
  order by doc_type, accepted_at desc;
$$;

revoke execute on function public.consent_record(text, text, text), public.consent_status() from public, anon;
grant execute on function public.consent_record(text, text, text), public.consent_status() to authenticated;
