-- Viral Gaming Hub: "a player reached 80 % of a game" alerts for the owner, so more
-- levels get added before players run out (owner 2026-11-24; adventure/story games
-- never report). Sent by scripts/common/cloud_save.gd `report_completion`.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
--
-- Owner reads it with:
--   select game, count(*) players, max(reached_at) latest
--   from public.completion_alerts group by game order by latest desc;
-- Rows go when the account is deleted (docs/ACCOUNT_DELETION.md lists the table).

create table if not exists public.completion_alerts (
  user_id     uuid        not null references auth.users (id) on delete cascade,
  game        text        not null check (char_length(game) between 1 and 40),
  done        int         not null check (done >= 0),
  total       int         not null check (total > 0),
  reached_at  timestamptz not null default now(),
  primary key (user_id, game)
);

alter table public.completion_alerts enable row level security;
revoke all on public.completion_alerts from anon, authenticated;

create or replace function public.report_completion(p_game text, p_done int, p_total int)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if p_total <= 0 or p_done * 10 < p_total * 8 then
    return;   -- under 80 %: nothing to record
  end if;
  insert into public.completion_alerts (user_id, game, done, total)
  values (auth.uid(), p_game, least(p_done, p_total), p_total)
  on conflict (user_id, game) do nothing;
end;
$$;

revoke all on function public.report_completion(text, int, int) from public, anon;
grant execute on function public.report_completion(text, int, int) to authenticated;
