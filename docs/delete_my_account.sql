-- Viral Game Hub: let a signed-in player delete their own account (Profile ->
-- "Delete my account", app v0.30+; Google Play requires in-app account
-- deletion for apps with accounts). Run ONCE in the Supabase SQL editor.
-- Not run by Claude (no production DB access) -- the owner runs it.
--
-- Deletes the caller's auth user; rows keyed to it with ON DELETE CASCADE
-- (scores, profiles, friends...) go with it. Check that every table that
-- references auth.users cascades, or add the deletes below before it.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  -- delete from public.scores where user_id = auth.uid();   -- if not cascading
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
