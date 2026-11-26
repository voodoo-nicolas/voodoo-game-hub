-- Chess Daily games (turn-based, several at once) for Viral Gaming Hub. Chess pack Phase B (2026-11-25).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Safe to run again: everything is "if not exists" / "or replace".
--
-- Clients never touch the table directly (RLS on, no policies): every read and
-- write goes through the chess_daily_* functions, which run as the table owner
-- and only act for auth.uid(). Only friends can challenge each other.
--
-- Move legality is checked by both phones, not here (the server has no chess
-- rules): the server checks whose turn it is, that the move number matches
-- (no double or out-of-date moves) and the deadlines.
--
--   chess_daily_challenge(other, days)  -> game id | -1 not friends | -2 too many games
--   chess_daily_respond(game, accept)   -> 'ok' | 'no'
--   chess_daily_list()                  -> my games: invites, going, and finished in the last 7 days
--   chess_daily_move(game, ply, uci, san, result, reason) -> 'ok' | 'stale' | 'not_your_turn' | 'over' | 'no'
--   chess_daily_resign(game)            -> 'ok' | 'no'
--   chess_daily_draw(game, action)      -> action 'offer' | 'accept' | 'decline'; 'ok' | 'no'
--   chess_daily_claim(game)             -> 'ok' (opponent's deadline passed: I win) | 'no'
--
-- Account deletion: delete-account removes every game where the player is
-- white or black (USER_ROWS); rows also cascade from auth.users.

create table if not exists public.chess_daily (
  id          bigint      generated always as identity primary key,
  white       uuid        not null references auth.users (id) on delete cascade,
  black       uuid        not null references auth.users (id) on delete cascade,
  created_by  uuid        not null references auth.users (id) on delete cascade,
  status      text        not null default 'invited' check (status in ('invited', 'active', 'over', 'declined')),
  days        int         not null default 3 check (days between 1 and 14),
  moves       text        not null default '' check (char_length(moves) <= 6000),   -- UCI, space-separated
  sans        text        not null default '' check (char_length(sans) <= 6000),    -- notation, space-separated
  ply         int         not null default 0 check (ply between 0 and 1200),
  deadline    timestamptz,
  result      text        not null default '*' check (result in ('*', '1-0', '0-1', '1/2-1/2')),
  reason      text        not null default '' check (char_length(reason) <= 40),
  draw_offer  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (white <> black)
);
create index if not exists chess_daily_white_idx on public.chess_daily (white, status);
create index if not exists chess_daily_black_idx on public.chess_daily (black, status);

alter table public.chess_daily enable row level security;
revoke all on public.chess_daily from anon, authenticated;

create or replace function public.chess_daily_challenge(p_other uuid, p_days int default 3)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  n int;
  new_id bigint;
begin
  if me is null or p_other is null or p_other = me then
    return -1;
  end if;
  if not exists (select 1 from friendships
                 where accepted and ((requester = me and target = p_other) or (requester = p_other and target = me))) then
    return -1;
  end if;
  select count(*) into n from chess_daily
  where status in ('invited', 'active') and (white = me or black = me);
  if n >= 10 then
    return -2;
  end if;
  -- Colours by coin toss.
  if random() < 0.5 then
    insert into chess_daily (white, black, created_by, days) values (me, p_other, me, greatest(1, least(14, coalesce(p_days, 3))))
    returning id into new_id;
  else
    insert into chess_daily (white, black, created_by, days) values (p_other, me, me, greatest(1, least(14, coalesce(p_days, 3))))
    returning id into new_id;
  end if;
  return new_id;
end;
$$;

create or replace function public.chess_daily_respond(p_game bigint, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  g chess_daily;
begin
  select * into g from chess_daily where id = p_game for update;
  if not found or g.status <> 'invited' or g.created_by = me or (g.white <> me and g.black <> me) then
    return 'no';
  end if;
  if p_accept then
    update chess_daily set status = 'active', deadline = now() + make_interval(days => g.days), updated_at = now()
    where id = p_game;
  else
    update chess_daily set status = 'declined', updated_at = now() where id = p_game;
  end if;
  return 'ok';
end;
$$;

create or replace function public.chess_daily_list()
returns table (id bigint, white uuid, black uuid, white_name text, black_name text, created_by uuid,
               status text, days int, moves text, sans text, ply int, deadline timestamptz,
               result text, reason text, draw_offer uuid, updated_at timestamptz, now_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select d.id, d.white, d.black, coalesce(cw.display_name, 'Player'), coalesce(cb.display_name, 'Player'), d.created_by,
         d.status, d.days, d.moves, d.sans, d.ply, d.deadline, d.result, d.reason, d.draw_offer, d.updated_at, now()
  from chess_daily d
  left join player_cards cw on cw.user_id = d.white
  left join player_cards cb on cb.user_id = d.black
  where (d.white = auth.uid() or d.black = auth.uid())
    and (d.status in ('invited', 'active') or (d.status = 'over' and d.updated_at > now() - interval '7 days'))
  order by d.updated_at desc
  limit 40;
$$;

-- p_ply = the number of moves already played as this phone saw them; the move
-- is refused as 'stale' if the game has moved on (double tap, two phones).
create or replace function public.chess_daily_move(p_game bigint, p_ply int, p_uci text, p_san text,
                                                   p_result text default '*', p_reason text default '')
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  g chess_daily;
  to_move uuid;
begin
  select * into g from chess_daily where id = p_game for update;
  if not found or (g.white <> me and g.black <> me) then
    return 'no';
  end if;
  if g.status <> 'active' then
    return 'over';
  end if;
  if g.ply <> p_ply then
    return 'stale';
  end if;
  -- An odd ply count means Black is to move (games always start from the usual position).
  to_move := case when g.ply % 2 = 0 then g.white else g.black end;
  if to_move <> me then
    return 'not_your_turn';
  end if;
  if p_uci !~ '^[a-h][1-8][a-h][1-8][nbrq]?$' or char_length(coalesce(p_san, '')) not between 1 and 10 then
    return 'no';
  end if;
  update chess_daily set
    moves = trim(both ' ' from moves || ' ' || p_uci),
    sans = trim(both ' ' from sans || ' ' || p_san),
    ply = g.ply + 1,
    deadline = now() + make_interval(days => g.days),
    draw_offer = null,
    status = case when coalesce(p_result, '*') in ('1-0', '0-1', '1/2-1/2') then 'over' else 'active' end,
    result = case when coalesce(p_result, '*') in ('1-0', '0-1', '1/2-1/2') then p_result else '*' end,
    reason = left(coalesce(p_reason, ''), 40),
    updated_at = now()
  where id = p_game;
  return 'ok';
end;
$$;

create or replace function public.chess_daily_resign(p_game bigint)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  g chess_daily;
begin
  select * into g from chess_daily where id = p_game for update;
  if not found or (g.white <> me and g.black <> me) or g.status not in ('invited', 'active') then
    return 'no';
  end if;
  if g.status = 'invited' then   -- withdrawing a challenge nobody answered
    update chess_daily set status = 'declined', updated_at = now() where id = p_game;
    return 'ok';
  end if;
  update chess_daily set status = 'over', result = case when me = g.white then '0-1' else '1-0' end,
    reason = 'resign', draw_offer = null, updated_at = now()
  where id = p_game;
  return 'ok';
end;
$$;

create or replace function public.chess_daily_draw(p_game bigint, p_action text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  g chess_daily;
begin
  select * into g from chess_daily where id = p_game for update;
  if not found or (g.white <> me and g.black <> me) or g.status <> 'active' then
    return 'no';
  end if;
  if p_action = 'offer' and g.draw_offer is null then
    update chess_daily set draw_offer = me, updated_at = now() where id = p_game;
  elsif p_action = 'accept' and g.draw_offer is not null and g.draw_offer <> me then
    update chess_daily set status = 'over', result = '1/2-1/2', reason = 'draw_agreed', draw_offer = null, updated_at = now()
    where id = p_game;
  elsif p_action = 'decline' and g.draw_offer is not null and g.draw_offer <> me then
    update chess_daily set draw_offer = null, updated_at = now() where id = p_game;
  else
    return 'no';
  end if;
  return 'ok';
end;
$$;

-- The player whose turn it is let the deadline pass: the other one wins.
-- (No check for mating material: a player out of time loses here.)
create or replace function public.chess_daily_claim(p_game bigint)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  g chess_daily;
  to_move uuid;
begin
  select * into g from chess_daily where id = p_game for update;
  if not found or (g.white <> me and g.black <> me) or g.status <> 'active' or g.deadline is null or g.deadline > now() then
    return 'no';
  end if;
  to_move := case when g.ply % 2 = 0 then g.white else g.black end;
  if to_move = me then
    return 'no';
  end if;
  update chess_daily set status = 'over', result = case when me = g.white then '1-0' else '0-1' end,
    reason = 'timeout', draw_offer = null, updated_at = now()
  where id = p_game;
  return 'ok';
end;
$$;

revoke execute on function public.chess_daily_challenge(uuid, int), public.chess_daily_respond(bigint, boolean),
  public.chess_daily_list(), public.chess_daily_move(bigint, int, text, text, text, text),
  public.chess_daily_resign(bigint), public.chess_daily_draw(bigint, text), public.chess_daily_claim(bigint)
  from public, anon;
grant execute on function public.chess_daily_challenge(uuid, int), public.chess_daily_respond(bigint, boolean),
  public.chess_daily_list(), public.chess_daily_move(bigint, int, text, text, text, text),
  public.chess_daily_resign(bigint), public.chess_daily_draw(bigint, text), public.chess_daily_claim(bigint)
  to authenticated;
