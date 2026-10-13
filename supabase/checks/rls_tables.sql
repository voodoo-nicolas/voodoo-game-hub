-- Run this ONE statement alone (the SQL Editor only shows the last result).
-- Read-only. Shows, per table in the public schema: RLS on? direct grants to the app roles? policies?
select c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       coalesce((select string_agg(distinct g.grantee || ':' || g.privilege_type, ', ')
                 from information_schema.role_table_grants g
                 where g.table_schema = 'public' and g.table_name = c.relname
                   and g.grantee in ('anon', 'authenticated')), '') as client_grants,
       (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as policies
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relrowsecurity, c.relname;
