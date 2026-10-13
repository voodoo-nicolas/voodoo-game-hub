-- Viral Game Hub: close the holes found in the RLS policy review (2026-10-13).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Not run by Claude (no production DB access). Safe to run again.
--
-- What was wrong (from supabase/checks/rls_policies.sql):
--   user_purchases:   policy "Service role can insert purchases" lets {public} (anyone,
--                     signed in or not) INSERT with check (true) -> a player could
--                     write themselves a purchase / entitlement. "Users can update own
--                     purchases" let them edit their own row (no check).
--   purchase_history: policy "Service role can insert history" -> anyone could insert rows.
--   The service role bypasses RLS anyway, so those policies were never needed.
-- After this, only the service role (edge functions / the store's server code) and
-- SECURITY DEFINER functions can write these two tables; players can still read their own.
--
-- This is the minimum. The planned clean-up (docs/monetization/cleanup_chat_sql.sql on
-- branch `store`) drops both tables with the old chat-drafted store SQL; if you run that,
-- this file is not needed for them (the grants part below still is).

drop policy if exists "Service role can insert purchases"   on public.user_purchases;
drop policy if exists "Users can update own purchases"      on public.user_purchases;
drop policy if exists "Service role can insert history"     on public.purchase_history;

revoke insert, update, delete, truncate on public.user_purchases   from anon, authenticated;
revoke insert, update, delete, truncate on public.purchase_history from anon, authenticated;

-- Default Supabase grants hand every table's TRUNCATE / TRIGGER / REFERENCES to the app
-- roles. The API never uses them (RLS doesn't cover TRUNCATE), so take them away everywhere.
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('revoke truncate, trigger, references on public.%I from anon, authenticated', t.tablename);
  end loop;
end $$;

-- scores / player_stats: only signed-in players write their own rows (policies already say so);
-- anonymous visitors never write, and nobody deletes through the API.
revoke insert, update, delete on public.scores       from anon;
revoke insert, update, delete on public.player_stats from anon;
revoke delete on public.scores, public.player_stats from authenticated;
