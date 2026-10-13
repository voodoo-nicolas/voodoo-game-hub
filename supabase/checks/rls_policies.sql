-- Run this ONE statement alone. Read-only. Lists every Row Level Security policy
-- (who it applies to and what rows it lets them touch). Needed to review the
-- tables where anon / signed-in users have direct INSERT / UPDATE / DELETE.
select tablename, policyname, cmd, roles, qual as using_expr, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
