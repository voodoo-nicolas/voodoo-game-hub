-- Crash / stall reports from the games (read-only). Run in the Supabase SQL editor.
-- Newest first. For the IQ Test, detail has: fn (which request), waited_ms, attempt, scope, gid, seq,
-- screen, lang, web (true on the browser build), os, and for "stall_end" how long the late reply took.

select r.created_at, p.nick, r.game, r.kind, r.build, r.platform, r.detail
from client_reports r left join profiles p on p.id = r.user_id
order by r.created_at desc limit 50;

-- how often, per kind and platform, in the last 7 days
select game, kind, platform, count(*) as n, count(distinct user_id) as players
from client_reports where created_at > now() - interval '7 days'
group by 1, 2, 3 order by n desc;
