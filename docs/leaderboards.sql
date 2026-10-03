-- Leaderboards for Voodoo Game Hub (app v0.22+).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Safe to run again: everything is "if not exists" / "or replace".
--
-- One row per player per game: their best score. Everyone (even signed-out
-- players) can READ the board; a signed-in player can only write THEIR OWN
-- row, and the trigger keeps the higher of the old and new score, so a
-- worse game never lowers it.

create table if not exists public.scores (
  user_id      uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  game         text        not null check (char_length(game) between 1 and 40),
  score        integer     not null check (score >= 0),
  display_name text        not null default 'Player' check (char_length(display_name) between 1 and 40),
  updated_at   timestamptz not null default now(),
  primary key (user_id, game)
);

create index if not exists scores_game_score_idx on public.scores (game, score desc);

alter table public.scores enable row level security;

drop policy if exists "Anyone can read the leaderboards" on public.scores;
create policy "Anyone can read the leaderboards"
  on public.scores for select
  using (true);

drop policy if exists "Players add their own score" on public.scores;
create policy "Players add their own score"
  on public.scores for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Players update their own score" on public.scores;
create policy "Players update their own score"
  on public.scores for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.scores_keep_best()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.score <= old.score then
    -- not a new best: keep the old score and when it was set (ties on the
    -- board go to whoever got there first)
    new.score := old.score;
    new.updated_at := old.updated_at;
  else
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists scores_keep_best on public.scores;
create trigger scores_keep_best
  before update on public.scores
  for each row execute function public.scores_keep_best();
