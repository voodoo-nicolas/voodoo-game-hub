-- Viral Game Hub: crash / stall reports sent by the games (the IQ Test's "Loading" watchdog first).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
--
-- One row per report. Only the client-report Edge Function writes it (service role); players
-- can neither read nor write it through the API. Read with supabase/checks/client_reports.sql.
-- Rows go when the account is deleted.

create table if not exists public.client_reports (
  id          bigint      generated always as identity primary key,
  created_at  timestamptz not null default now(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  game        text        not null check (char_length(game) between 1 and 40),
  kind        text        not null check (char_length(kind) between 1 and 40),
  build       integer,
  platform    text        not null default '',
  detail      jsonb       not null default '{}'::jsonb
);
create index if not exists client_reports_user_idx on public.client_reports (user_id, created_at desc);
create index if not exists client_reports_game_idx on public.client_reports (game, created_at desc);

alter table public.client_reports enable row level security;
revoke all on public.client_reports from anon, authenticated;
