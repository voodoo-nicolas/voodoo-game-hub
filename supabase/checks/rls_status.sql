-- Viral Game Hub: is Row Level Security on for every table with personal data?
-- Read-only: only SELECTs. Paste into Supabase dashboard -> SQL Editor -> Run.
-- Not run by Claude (no production DB access).
--
-- Expected for this app: every table below shows rls_enabled = true, and the
-- "client_grants" column empty (clients never touch the tables directly; all
-- access goes through the social_* / xp_* / player_* functions, which run as
-- the owner). A table with rls_enabled = false, or with grants to
-- anon/authenticated and no policies, is a problem to fix before publishing.

-- 1) Every table in the public schema: RLS on? RLS forced? who has direct grants?
select c.relname                                        as table_name,
       c.relrowsecurity                                 as rls_enabled,
       c.relforcerowsecurity                            as rls_forced,
       coalesce((select string_agg(distinct g.grantee || ':' || g.privilege_type, ', ' order by g.grantee || ':' || g.privilege_type)
                 from information_schema.role_table_grants g
                 where g.table_schema = 'public' and g.table_name = c.relname
                   and g.grantee in ('anon', 'authenticated')), '') as client_grants,
       (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as policies
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relrowsecurity, c.relname;

-- 2) The policies that exist (tables with scores / profiles usually have a few).
select tablename, policyname, cmd, roles, qual as using_expr, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 3) Functions the app can call directly (anon should call none of the social/xp ones).
select p.proname as function_name,
       has_function_privilege('anon', p.oid, 'execute')          as anon_can_run,
       has_function_privilege('authenticated', p.oid, 'execute') as signed_in_can_run
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (p.proname like 'social\_%' or p.proname like 'xp\_%' or p.proname like 'player\_%' or p.proname = 'delete_my_account')
order by p.proname;
