-- Why did ONE player's IQ test stick on "Loading"? Read-only. Run in the Supabase SQL editor
-- (Claude has no production access). Replace PUT_NICK_HERE in both queries.
--
-- Query 1: their newest sessions, and the last items of the newest one.
-- What to look for in query 2 (the newest session's last 6 rows, newest first):
--   * top row answered_at is NULL  -> the server made the next item and saved it, so the app
--     never drew it (client / network). Note its gid and d.
--   * top row answered_at is set and the session is still 'live' -> the answer was saved but
--     the server failed before it stored the next item (a server error while building it).
--     The Edge Function log (Dashboard -> Edge Functions -> item-answer -> Logs) has the error
--     at the same time as that row's answered_at.
--   * served_at of the top row vs answered_at of the one under it: a gap of more than ~25 s
--     means the answer request itself was slow.

with p as (select id from profiles where nick = 'PUT_NICK_HERE')
select left(s.id::text, 8) as session, s.started_at, s.mode, s.scope, s.lang, s.ranked, s.kind, s.status,
       (s.state->>'gv') as gv, s.dur_s,
       (select count(*) from responses r where r.session_id = s.id and r.answered_at is not null) as answered,
       (select count(*) from responses r where r.session_id = s.id and r.answered_at is null) as pending
from sessions s join p on p.id = s.user_id
order by s.started_at desc limit 8;

with p as (select id from profiles where nick = 'PUT_NICK_HERE'),
last as (select s.id from sessions s join p on p.id = s.user_id order by s.started_at desc limit 1)
select r.seq, r.sec, r.gid, r.d, r.served_at, r.answered_at, r.u, r.ms, r.conf
from responses r join last on last.id = r.session_id
order by r.seq desc limit 6;
