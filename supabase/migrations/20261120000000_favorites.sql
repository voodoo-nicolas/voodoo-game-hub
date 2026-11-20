-- Viral Gaming Hub: ★ favorites follow the account across devices (owner 2026-11-20:
-- "favorites should be multi-device knowledge").
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
--
-- One row per player: the list of game ids and the device time of the last change.
-- The newest change wins (so removing a favorite on one phone removes it everywhere);
-- the app merges a guest's favorites into the account on first sign-in.
-- Apps from v0.43.0 call these; until this runs they just keep favorites on the device.
-- Rows go when the account is deleted (on delete cascade).

create table if not exists public.user_favorites (
  user_id     uuid        primary key references auth.users (id) on delete cascade,
  ids         jsonb       not null default '[]'::jsonb,
  changed_at  bigint      not null default 0,          -- device unix time of the change
  updated_at  timestamptz not null default now(),
  check (jsonb_typeof(ids) = 'array'),
  check (jsonb_array_length(ids) <= 300),
  check (octet_length(ids::text) <= 16000)
);

alter table public.user_favorites enable row level security;
revoke all on public.user_favorites from anon, authenticated;

-- Save my favorites, unless a newer change is already stored.
create or replace function public.save_favorites(p_ids jsonb, p_changed_at bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if jsonb_typeof(p_ids) <> 'array' then
    raise exception 'ids must be an array';
  end if;
  insert into public.user_favorites (user_id, ids, changed_at, updated_at)
  values (auth.uid(), p_ids, coalesce(p_changed_at, 0), now())
  on conflict (user_id) do update
    set ids = excluded.ids, changed_at = excluded.changed_at, updated_at = now()
    where public.user_favorites.changed_at <= excluded.changed_at;
end;
$$;

-- Load my favorites: {"ids": [...], "at": <device unix time>}, or null when none yet.
create or replace function public.load_favorites()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object('ids', ids, 'at', changed_at)
  from public.user_favorites where user_id = auth.uid();
$$;

revoke all on function public.save_favorites(jsonb, bigint) from public, anon;
revoke all on function public.load_favorites() from public, anon;
grant execute on function public.save_favorites(jsonb, bigint) to authenticated;
grant execute on function public.load_favorites() to authenticated;
