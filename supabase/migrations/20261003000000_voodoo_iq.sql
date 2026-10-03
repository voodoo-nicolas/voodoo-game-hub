-- Voodoo IQ, Phase 1: tables + Row Level Security (docs/voodoo-iq-spec.md §4).
--
-- Clients (anon / authenticated) can READ the leaderboard tables and nothing else.
-- They can never write: every insert/update comes from the Edge Functions in
-- supabase/functions/, which use the service_role key (it bypasses RLS).
--
-- Differences from the spec's SQL (additions only; every spec column is unchanged):
--   * sessions.state    server-only engine state between calls: the RNG state of the
--                       adaptive test (so items stay exactly the prototype's), the used
--                       analogy/fallacy ids, the SELF start point / prediction, a duel code.
--   * profiles_public   the view the spec asks for (nick / age band / country only).
--                       Profiles themselves are written by the `profile-save` function.
--   * indexes for the per-user / per-day lookups the functions do.
--
-- Run once: Supabase dashboard -> SQL editor (or `supabase db push`). Plain `create
-- table` on purpose: if a table with one of these names already exists, this fails
-- loudly instead of silently reusing it.

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  nick text not null check (char_length(nick) between 2 and 18),
  age_band text, minor boolean default false,
  country text, province text, lang text default 'es',
  created_at timestamptz default now()
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  mode text not null check (mode in ('iq','blitz')),
  kind text not null default 'normal' check (kind in ('normal','daily','duel')),
  scope text not null, dur_s int not null, ranked boolean not null,
  seed bigint not null, lang text not null,
  started_at timestamptz not null default now(),
  deadline timestamptz not null,
  status text not null default 'live' check (status in ('live','done','abandoned')),
  flags jsonb default '{}'::jsonb, result jsonb,
  state jsonb not null default '{}'::jsonb      -- server-only engine state (see header)
);
create index sessions_user_started on public.sessions (user_id, started_at desc);
create index sessions_live_deadline on public.sessions (deadline) where status = 'live';

create table public.responses (
  session_id uuid references public.sessions(id) on delete cascade,
  seq int, sec text, gid text, d int, a real, b real, c real,
  u smallint, ms int, conf real,
  served_at timestamptz, answered_at timestamptz,
  answer_key jsonb,        -- server only, never exposed
  primary key (session_id, seq)
);

create table public.section_scores (     -- one row per ranked session per section
  session_id uuid references public.sessions(id), user_id uuid references public.profiles(id),
  sec text, day date, theta real, se real, n int, hard int, lang text, flagged boolean,
  auc real, bias real, created_at timestamptz default now(),
  primary key (session_id, sec)
);
create index section_scores_user_sec on public.section_scores (user_id, sec, created_at desc);

create table public.blitz_best (user_id uuid, scope text, dur_s int, season text, pts real, correct int, at timestamptz,
  primary key (user_id, scope, dur_s, season));      -- season = 'all' or 'YYYY-MM'
create table public.daily (user_id uuid, day date, pts real, correct int, primary key (user_id, day));
create table public.duels (code text primary key, seed bigint, scope text, dur_s int, created_by uuid, created_at timestamptz default now());
create table public.duel_results (code text references public.duels, user_id uuid, pts real, correct int, primary key (code, user_id));
create table public.certificates (token text primary key, user_id uuid, score int, theta real, se real, issued_at timestamptz default now());

-- ---------------------------------------------------------------- RLS
alter table public.profiles       enable row level security;
alter table public.sessions       enable row level security;
alter table public.responses      enable row level security;
alter table public.section_scores enable row level security;
alter table public.blitz_best     enable row level security;
alter table public.daily          enable row level security;
alter table public.duels          enable row level security;
alter table public.duel_results   enable row level security;
alter table public.certificates   enable row level security;

-- No client writes anywhere. RLS with no insert/update/delete policy already denies
-- them; revoking the privileges as well means a policy added by mistake later still
-- can't open a write path.
revoke insert, update, delete, truncate on
  public.profiles, public.sessions, public.responses, public.section_scores, public.blitz_best,
  public.daily, public.duels, public.duel_results, public.certificates
  from anon, authenticated;

-- Never readable by clients: sessions (seed, engine state), responses (answer keys),
-- duels (seed). The client gets what it needs through the Edge Functions.
revoke select on public.sessions, public.responses, public.duels from anon, authenticated;

-- profiles: a player reads their own full row; everyone else goes through profiles_public.
create policy "own profile" on public.profiles for select to authenticated using (id = auth.uid());

-- Public player view (spec: nick / age / country only). A plain view runs with its
-- owner's rights, so it reads every row although profiles' own policy shows one.
-- That also makes it an auto-updatable view writing as its owner, past RLS, so every
-- privilege but select is revoked (Supabase's default privileges grant them all).
create view public.profiles_public as
  select id, nick, age_band, country, province from public.profiles;
revoke all on public.profiles_public from anon, authenticated;
grant select on public.profiles_public to authenticated;

-- Leaderboard tables: readable by any signed-in player.
create policy "read" on public.section_scores for select to authenticated using (true);
create policy "read" on public.blitz_best     for select to authenticated using (true);
create policy "read" on public.daily          for select to authenticated using (true);
create policy "read" on public.duel_results   for select to authenticated using (true);
create policy "read" on public.certificates   for select to authenticated using (true);
