-- Removes what a claude.ai chat's draft SQL created (2026-10-05): the sign-up
-- trigger on_auth_user_created -> initialize_user_purchases(), which adds a
-- user_purchases row for every new account, the tables user_purchases /
-- purchase_history, and functions like can_access_game, start_game_trial,
-- add_game_purchase, set_hub_subscription.
--
-- Nothing in the app, the packs or the Edge Functions uses any of it: the real
-- store is supabase/migrations/20261005000000_store.sql (store_trials,
-- store_entitlements, store_status, store_start_trial), and no part of this
-- project needs a sign-up trigger (profiles are written by profile-save).
-- The functions take a user id from the caller, so with the public anon key
-- anyone could grant themselves purchases -- another reason to remove them.
--
-- A first version of this file stopped at the trigger on purpose; running it
-- found that the trigger is the draft's own. Run this whole file once in the
-- SQL editor. One transaction: everything happens or nothing does. The
-- trigger function's code is printed (Messages) before it is dropped.

do $$
declare
  f record;
begin
  -- 1. The draft's sign-up trigger, and the function it runs.
  for f in
    select p.oid::regprocedure as fn, p.prosrc as src
      from pg_trigger t join pg_proc p on p.oid = t.tgfoid
     where t.tgname = 'on_auth_user_created' and t.tgrelid = 'auth.users'::regclass
  loop
    raise notice 'trigger on_auth_user_created ran %: %', f.fn, f.src;
  end loop;
  drop trigger if exists on_auth_user_created on auth.users;
  drop function if exists public.initialize_user_purchases();

  -- 2. The draft's other functions: the known names, plus any public function
  --    that reads or writes the draft's tables (never the real store_*).
  for f in
    select p.oid::regprocedure as fn
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and (p.proname in ('can_access_game', 'start_game_trial', 'add_game_purchase',
                          'set_hub_subscription', 'log_purchase')
            or p.prosrc ilike '%user_purchases%' or p.prosrc ilike '%purchase_history%')
       and p.proname not like 'store\_%'
  loop
    raise notice 'dropping function %', f.fn;
    execute format('drop function %s', f.fn);
  end loop;

  -- 3. The draft's tables (their policies and indexes go with them).
  drop table if exists public.purchase_history;
  drop table if exists public.user_purchases;
end $$;
