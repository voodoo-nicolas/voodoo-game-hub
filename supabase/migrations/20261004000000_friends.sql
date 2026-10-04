-- Friends + game invites for Voodoo Game Hub (app v0.25+).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Safe to run again: everything is "if not exists" / "or replace".
--
-- Clients never touch these tables directly (RLS on, no policies): every
-- read and write goes through the social_* functions below, which run as
-- the table owner and only ever act for auth.uid(). That keeps friend codes
-- from being listed and lets a request be answered only by its target.
--
--   social_me(name)               -> my friend code (made on first call); also "I'm online"
--   social_add(code)              -> 'sent' | 'accepted' | 'already' | 'self' | 'not_found'
--   social_respond(other, accept) -> accept or decline a request sent to me
--   social_remove(other)          -> unfriend / cancel my request
--   social_list()                 -> my friends and requests, with online status
--   social_invite(other, game, code, title) -> invite a friend into an online room
--   social_inbox()                -> invites sent to me in the last 10 minutes (then cleared)

create table if not exists public.player_cards (
  user_id      uuid        primary key references auth.users (id) on delete cascade,
  friend_code  text        not null unique,
  display_name text        not null default 'Player' check (char_length(display_name) between 1 and 40),
  last_seen    timestamptz not null default now()
);

-- One row per pair, written by whoever asked first.
create table if not exists public.friendships (
  requester  uuid        not null references auth.users (id) on delete cascade,
  target     uuid        not null references auth.users (id) on delete cascade,
  accepted   boolean     not null default false,
  created_at timestamptz not null default now(),
  primary key (requester, target),
  check (requester <> target)
);
create index if not exists friendships_target_idx on public.friendships (target);

create table if not exists public.game_invites (
  id         bigint      generated always as identity primary key,
  sender     uuid        not null references auth.users (id) on delete cascade,
  recipient  uuid        not null references auth.users (id) on delete cascade,
  game       text        not null check (char_length(game) between 1 and 40),
  title      text        not null default '' check (char_length(title) <= 60),
  room_code  text        not null check (char_length(room_code) between 1 and 12),
  created_at timestamptz not null default now()
);
create index if not exists game_invites_recipient_idx on public.game_invites (recipient, created_at);

alter table public.player_cards enable row level security;
alter table public.friendships  enable row level security;
alter table public.game_invites enable row level security;
revoke all on public.player_cards, public.friendships, public.game_invites from anon, authenticated;

-- No 0/O/1/I/L, like the online room codes: friend codes get read aloud.
create or replace function public.social_new_code()
returns text
language plpgsql
as $$
declare
  chars constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  c text;
begin
  loop
    c := '';
    for i in 1..6 loop
      c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.player_cards where friend_code = c);
  end loop;
  return c;
end;
$$;

create or replace function public.social_me(p_name text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  n text := left(coalesce(nullif(trim(p_name), ''), 'Player'), 40);
  c text;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  insert into player_cards (user_id, friend_code, display_name)
  values (me, social_new_code(), n)
  on conflict (user_id) do update
    set last_seen = now(),
        display_name = case when p_name is null then player_cards.display_name else excluded.display_name end
  returning friend_code into c;
  return c;
end;
$$;

create or replace function public.social_add(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  other uuid;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  select user_id into other from player_cards where friend_code = upper(trim(p_code));
  if other is null then
    return 'not_found';
  end if;
  if other = me then
    return 'self';
  end if;
  -- They already asked me: adding them back accepts.
  update friendships set accepted = true where requester = other and target = me and not accepted;
  if found then
    return 'accepted';
  end if;
  if exists (select 1 from friendships where (requester = me and target = other) or (requester = other and target = me)) then
    return 'already';
  end if;
  insert into friendships (requester, target) values (me, other);
  return 'sent';
end;
$$;

create or replace function public.social_respond(p_other uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_accept then
    update friendships set accepted = true where requester = p_other and target = auth.uid();
  else
    delete from friendships where requester = p_other and target = auth.uid() and not accepted;
  end if;
end;
$$;

create or replace function public.social_remove(p_other uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from friendships
  where (requester = auth.uid() and target = p_other) or (requester = p_other and target = auth.uid());
$$;

-- status: 'friend', 'incoming' (they asked me), 'outgoing' (I asked them).
-- online: seen in the app during the last 3 minutes (the app calls
-- social_me every minute while it's open).
create or replace function public.social_list()
returns table (user_id uuid, display_name text, status text, online boolean, last_seen timestamptz)
language sql
security definer
set search_path = public
as $$
  select c.user_id, c.display_name,
         case when f.accepted then 'friend' when f.target = auth.uid() then 'incoming' else 'outgoing' end,
         c.last_seen > now() - interval '3 minutes',
         c.last_seen
  from friendships f
  join player_cards c on c.user_id = case when f.requester = auth.uid() then f.target else f.requester end
  where f.requester = auth.uid() or f.target = auth.uid()
  order by f.accepted desc, c.last_seen desc;
$$;

create or replace function public.social_invite(p_other uuid, p_game text, p_code text, p_title text default '')
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from friendships
                 where accepted and ((requester = auth.uid() and target = p_other) or (requester = p_other and target = auth.uid()))) then
    return false;
  end if;
  delete from game_invites where created_at < now() - interval '1 day';
  insert into game_invites (sender, recipient, game, title, room_code)
  values (auth.uid(), p_other, p_game, left(coalesce(p_title, ''), 60), p_code);
  return true;
end;
$$;

create or replace function public.social_inbox()
returns table (sender uuid, sender_name text, game text, title text, room_code text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
    with taken as (
      delete from game_invites i where i.recipient = auth.uid() returning i.*
    )
    select t.sender, coalesce(c.display_name, 'Player'), t.game, t.title, t.room_code, t.created_at
    from taken t left join player_cards c on c.user_id = t.sender
    where t.created_at > now() - interval '10 minutes'
    order by t.created_at desc;
end;
$$;

revoke execute on function public.social_new_code() from public, anon, authenticated;
revoke execute on function public.social_me(text), public.social_add(text), public.social_respond(uuid, boolean),
  public.social_remove(uuid), public.social_list(), public.social_invite(uuid, text, text, text), public.social_inbox()
  from public, anon;
grant execute on function public.social_me(text), public.social_add(text), public.social_respond(uuid, boolean),
  public.social_remove(uuid), public.social_list(), public.social_invite(uuid, text, text, text), public.social_inbox()
  to authenticated;
