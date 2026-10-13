-- Viral Game Hub: presence (which game a friend is in), avatars and Viral Power
-- on the friends list (app v0.35+).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
-- The app works without it: the new fields just stay empty, and the calls that
-- need it fail quietly.
--
-- Builds on 20261004000000_friends.sql (player_cards, friendships, social_*).
--
--   social_set_presence(game)  -> "I'm in <game>" ('' = in the menus); also "I'm online"
--   social_set_avatar(avatar)  -> 'p<n>' (a preset) or 'img:<base64 jpeg>' (a small photo)
--   social_list()              -> now also avatar, current_game, viral_power
--
-- viral_power stays 0 until the Viral XP system (Phase 6) fills it.

alter table public.player_cards add column if not exists current_game text not null default ''
  check (char_length(current_game) <= 40);
alter table public.player_cards add column if not exists avatar text not null default ''
  check (char_length(avatar) <= 40000);
alter table public.player_cards add column if not exists viral_power bigint not null default 0
  check (viral_power >= 0);

create or replace function public.social_set_presence(p_game text default '')
returns void
language sql
security definer
set search_path = public
as $$
  update player_cards
     set current_game = left(coalesce(p_game, ''), 40), last_seen = now()
   where user_id = auth.uid();
$$;

create or replace function public.social_set_avatar(p_avatar text default '')
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  p_avatar := coalesce(p_avatar, '');
  if p_avatar <> '' and p_avatar !~ '^(p[0-9]{1,2}|img:[A-Za-z0-9+/=]{1,39000})$' then
    raise exception 'bad avatar';
  end if;
  update player_cards set avatar = p_avatar where user_id = auth.uid();
end;
$$;

-- Return type changes, so the old function has to go first.
drop function if exists public.social_list();
create function public.social_list()
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
         case when f.accepted then c.viral_power else 0 end
  from friendships f
  join player_cards c on c.user_id = case when f.requester = auth.uid() then f.target else f.requester end
  where f.requester = auth.uid() or f.target = auth.uid()
  order by f.accepted desc, c.last_seen desc;
$$;

revoke execute on function public.social_set_presence(text), public.social_set_avatar(text), public.social_list()
  from public, anon;
grant execute on function public.social_set_presence(text), public.social_set_avatar(text), public.social_list()
  to authenticated;
