-- Viral Game Hub: per-player game progress in the cloud (Creation first), so a player
-- can switch between PC and phone, log out and back in, or sign in as someone else.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
--
-- One row per (player, game). The game writes its whole save as JSON and merges
-- (set union of discoveries) on the device; the server only stores and returns it.
-- Players reach the table only through the two functions below, as themselves.
-- Rows go when the account is deleted.

create table if not exists public.game_progress (
  user_id     uuid        not null references auth.users (id) on delete cascade,
  game        text        not null check (char_length(game) between 1 and 40),
  data        jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  primary key (user_id, game),
  check (octet_length(data::text) <= 1000000)
);

alter table public.game_progress enable row level security;
revoke all on public.game_progress from anon, authenticated;

-- Save (replace) my progress for one game.
create or replace function public.save_game_progress(p_game text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into public.game_progress (user_id, game, data, updated_at)
  values (auth.uid(), p_game, coalesce(p_data, '{}'::jsonb), now())
  on conflict (user_id, game)
  do update set data = excluded.data, updated_at = now();
end;
$$;

-- Load my progress for one game (null when there is none yet).
create or replace function public.load_game_progress(p_game text)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select data from public.game_progress
  where user_id = auth.uid() and game = p_game;
$$;

revoke all on function public.save_game_progress(text, jsonb) from public, anon;
revoke all on function public.load_game_progress(text) from public, anon;
grant execute on function public.save_game_progress(text, jsonb) to authenticated;
grant execute on function public.load_game_progress(text) to authenticated;
