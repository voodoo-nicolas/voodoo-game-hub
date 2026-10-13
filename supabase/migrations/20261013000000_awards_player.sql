-- Viral Game Hub: the award log (Viral XP), the Player page and its privacy
-- setting (app v0.35+).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
-- Needs 20261004000000_friends.sql and 20261012000000_presence_avatar.sql first.
--
-- Viral XP = points for completing challenges (achievements). Permanent: rows
-- are only ever added, never changed or deleted (except when the account is
-- deleted: ON DELETE CASCADE). It is not spendable. Viral Power = the sum of a
-- player's XP across all games = player_cards.viral_power, recomputed from the
-- log on every report, so the log is the source of truth.
--
-- The app reports earned challenges (client-side, so SPOOFABLE: a modified app
-- can claim any award). Limits: xp per challenge <= 200, xp per game <= 1500
-- (XP_GAME_CAP), 100 awards per call. Competitive rankings that matter should
-- be validated server-side per game before relying on them.
--
--   xp_report(awards jsonb)            -> my new Viral Power (idempotent)
--   player_overview(other uuid)        -> a friend's games + XP (or {"private": true})
--   player_compare(other uuid, game)   -> both players' awards in one game
--   social_set_visibility(vis)         -> 'friends' (default) | 'private'

create table if not exists public.player_awards (
  user_id      uuid        not null references auth.users (id) on delete cascade,
  game_id      text        not null check (char_length(game_id) between 1 and 40),
  challenge_id text        not null check (char_length(challenge_id) between 1 and 80),
  title        text        not null default '' check (char_length(title) <= 80),
  icon         text        not null default '' check (char_length(icon) <= 16),
  xp           integer     not null check (xp between 0 and 200),
  earned_at    timestamptz not null default now(),
  primary key (user_id, game_id, challenge_id)
);
create index if not exists player_awards_user_idx on public.player_awards (user_id, game_id);

alter table public.player_awards enable row level security;
revoke all on public.player_awards from anon, authenticated;

alter table public.player_cards add column if not exists visibility text not null default 'friends'
  check (visibility in ('friends', 'private'));

create or replace function public.social_set_visibility(p_vis text default 'friends')
returns void
language sql
security definer
set search_path = public
as $$
  update player_cards
     set visibility = case when p_vis = 'private' then 'private' else 'friends' end
   where user_id = auth.uid();
$$;

-- Adds new awards (existing ones are left alone), within the per-game cap, and
-- returns my total Viral Power. Each item: {"game", "id", "title", "icon", "xp", "at" (unix seconds)}.
create or replace function public.xp_report(p_awards jsonb)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  item jsonb;
  g text;
  x integer;
  game_total integer;
  n integer := 0;
  total bigint;
  game_cap constant integer := 1500;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  if jsonb_typeof(p_awards) <> 'array' then
    raise exception 'awards must be an array';
  end if;
  for item in select * from jsonb_array_elements(p_awards) loop
    n := n + 1;
    exit when n > 100;
    g := left(coalesce(item->>'game', ''), 40);
    x := least(greatest(coalesce((item->>'xp')::integer, 0), 0), 200);
    continue when g = '' or coalesce(item->>'id', '') = '';
    select coalesce(sum(xp), 0) into game_total from player_awards where user_id = me and game_id = g;
    continue when game_total + x > game_cap;
    insert into player_awards (user_id, game_id, challenge_id, title, icon, xp, earned_at)
    values (me, g, left(item->>'id', 80), left(coalesce(item->>'title', ''), 80), left(coalesce(item->>'icon', ''), 16), x,
            least(coalesce(to_timestamp((item->>'at')::double precision), now()), now()))
    on conflict (user_id, game_id, challenge_id) do nothing;
  end loop;
  select coalesce(sum(xp), 0) into total from player_awards where user_id = me;
  update player_cards set viral_power = total where user_id = me;
  return total;
end;
$$;

create or replace function public.social_can_see(p_other uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select p_other = auth.uid()
      or (exists (select 1 from friendships
                  where accepted and ((requester = auth.uid() and target = p_other)
                                   or (requester = p_other and target = auth.uid())))
          and exists (select 1 from player_cards where user_id = p_other and visibility = 'friends'));
$$;

create or replace function public.player_overview(p_other uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c player_cards;
begin
  if not exists (select 1 from friendships
                 where accepted and ((requester = auth.uid() and target = p_other)
                                  or (requester = p_other and target = auth.uid())))
     and p_other <> auth.uid() then
    return null;
  end if;
  select * into c from player_cards where user_id = p_other;
  if c.user_id is null then
    return null;
  end if;
  if not social_can_see(p_other) then
    return jsonb_build_object('name', c.display_name, 'avatar', c.avatar, 'private', true);
  end if;
  return jsonb_build_object(
    'name', c.display_name, 'avatar', c.avatar, 'private', false, 'power', c.viral_power,
    'games', coalesce((select jsonb_agg(jsonb_build_object('game', game_id, 'xp', xp, 'count', n) order by xp desc)
                       from (select game_id, sum(xp)::int as xp, count(*)::int as n
                             from player_awards where user_id = p_other group by game_id) t), '[]'::jsonb));
end;
$$;

-- Every challenge either of us has earned in one game: mine / theirs are the
-- unix time earned, or null when not earned.
create or replace function public.player_compare(p_other uuid, p_game text)
returns table (challenge_id text, title text, icon text, xp integer, mine bigint, theirs bigint)
language sql
security definer
set search_path = public
as $$
  select coalesce(a.challenge_id, b.challenge_id),
         coalesce(a.title, b.title), coalesce(a.icon, b.icon), coalesce(a.xp, b.xp),
         extract(epoch from a.earned_at)::bigint, extract(epoch from b.earned_at)::bigint
  from (select * from player_awards where user_id = auth.uid() and game_id = p_game) a
  full join (select * from player_awards where user_id = p_other and game_id = p_game and social_can_see(p_other)) b
    on a.challenge_id = b.challenge_id
  order by coalesce(a.xp, b.xp) desc, 1;
$$;

-- Friends list: hide Viral Power of players who chose 'private'. Same columns as
-- before, so this replaces the previous definition in place.
create or replace function public.social_list()
returns table (user_id uuid, display_name text, status text, online boolean, last_seen timestamptz,
               avatar text, current_game text, viral_power bigint)
language sql
security definer
set search_path = public
as $$
  select c.user_id, c.display_name,
         case when f.accepted then 'friend' when f.target = auth.uid() then 'incoming' else 'outgoing' end,
         c.last_seen > now() - interval '3 minutes',
         c.last_seen,
         case when f.accepted then c.avatar else '' end,
         case when f.accepted and c.last_seen > now() - interval '3 minutes' then c.current_game else '' end,
         case when f.accepted and c.visibility = 'friends' then c.viral_power else 0 end
  from friendships f
  join player_cards c on c.user_id = case when f.requester = auth.uid() then f.target else f.requester end
  where f.requester = auth.uid() or f.target = auth.uid()
  order by f.accepted desc, c.last_seen desc;
$$;

revoke execute on function public.social_set_visibility(text), public.xp_report(jsonb), public.social_can_see(uuid),
  public.player_overview(uuid), public.player_compare(uuid, text), public.social_list() from public, anon;
grant execute on function public.social_set_visibility(text), public.xp_report(jsonb),
  public.player_overview(uuid), public.player_compare(uuid, text), public.social_list() to authenticated;
revoke execute on function public.social_can_see(uuid) from authenticated;
