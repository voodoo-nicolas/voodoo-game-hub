-- DRAFT -- not run anywhere. Trials + entitlements for the store (see PLAN.md).
-- When approved this moves to supabase/migrations/<date>_store.sql and the
-- user runs it once in the Supabase SQL editor. Safe to re-run.
--
-- Clients never write these tables (RLS on, read-own policies only):
--   store_status()          -> my trials, my live entitlements, server now()
--   store_start_trial(game) -> started_at (inserts once; can't restart a trial)
-- Entitlements are written only by the purchase-verify / play-rtdn Edge
-- Functions (service role) or by hand for grants.

create table if not exists public.store_trials (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  game       text        not null check (game ~ '^[a-z0-9_]{1,40}$'),
  started_at timestamptz not null default now(),
  primary key (user_id, game)
);

create table if not exists public.store_entitlements (
  id             bigint      generated always as identity primary key,
  user_id        uuid        not null references auth.users (id) on delete cascade,
  product_id     text        not null,                -- 'game_chess' | 'hub_all' | 'grant_all'
  kind           text        not null check (kind in ('game', 'hub')),
  game           text,                                -- set when kind = 'game'
  state          text        not null default 'active'
                 check (state in ('active', 'grace', 'canceled', 'on_hold', 'expired', 'revoked')),
  expires_at     timestamptz,                         -- null = never (one-time purchase, grant)
  source         text        not null check (source in ('play', 'grant')),
  purchase_token text        unique,                  -- Play token; null for grants
  order_id       text,
  updated_at     timestamptz not null default now(),
  check ((kind = 'game') = (game is not null))
);
create index if not exists store_entitlements_user_idx on public.store_entitlements (user_id);

alter table public.store_trials       enable row level security;
alter table public.store_entitlements enable row level security;

drop policy if exists "read own trials" on public.store_trials;
create policy "read own trials" on public.store_trials
  for select using (auth.uid() = user_id);

drop policy if exists "read own entitlements" on public.store_entitlements;
create policy "read own entitlements" on public.store_entitlements
  for select using (auth.uid() = user_id);

-- Access counts while active, in Play's grace period, or canceled but not
-- yet past the paid period.
create or replace function public.store_status()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'now', now(),
    'trials', coalesce((
      select jsonb_object_agg(game, started_at)
      from store_trials where user_id = auth.uid()), '{}'::jsonb),
    'entitlements', coalesce((
      select jsonb_agg(jsonb_build_object(
               'product_id', product_id, 'kind', kind, 'game', game,
               'state', state, 'expires_at', expires_at))
      from store_entitlements
      where user_id = auth.uid()
        and state in ('active', 'grace', 'canceled')
        and (expires_at is null or expires_at > now())), '[]'::jsonb)
  );
$$;

create or replace function public.store_start_trial(p_game text)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  started timestamptz;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into store_trials (user_id, game) values (auth.uid(), p_game)
    on conflict (user_id, game) do nothing;
  select started_at into started from store_trials
    where user_id = auth.uid() and game = p_game;
  return started;
end;
$$;

revoke all on function public.store_status()          from public, anon;
revoke all on function public.store_start_trial(text) from public, anon;
grant execute on function public.store_status()          to authenticated;
grant execute on function public.store_start_trial(text) to authenticated;
-- Trials are for signed-in players only (PLAN.md Decision 4); anon has no access.

-- Example grant (run by hand for a tester):
-- insert into store_entitlements (user_id, product_id, kind, source)
--   values ('<uuid>', 'grant_all', 'hub', 'grant');
