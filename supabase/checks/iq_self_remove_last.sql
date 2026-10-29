-- Take ONE player's most recent Intrapersonal (SELF) test out of the standings.
-- Run in the Supabase SQL editor (Claude has no production access). Replace PUT_NICK_HERE.
-- It only deletes that test's section_scores row (what the leaderboards read). The session and
-- its answers stay, so nothing else is lost. iq_rescore.ts only updates rows that exist, so it
-- will not bring the row back. Keep the row that step 2 prints: it is the only copy of its numbers.

-- 1) Their SELF tests, newest first by START TIME (check this is the one you mean)
with p as (select id from profiles where nick = 'PUT_NICK_HERE')
select s.started_at, left(s.id::text, 8) as session, s.status, s.ranked, ss.theta, ss.se, ss.n, ss.auc, ss.bias
from sessions s join p on p.id = s.user_id
left join section_scores ss on ss.session_id = s.id and ss.sec = 'SELF'
where s.mode = 'iq' and s.scope = 'SELF'
order by s.started_at desc limit 6;

-- 2) Remove the newest one's SELF row (prints the deleted row: save it)
with p as (select id from profiles where nick = 'PUT_NICK_HERE'),
last as (
  select s.id from sessions s join p on p.id = s.user_id
  where s.mode = 'iq' and s.scope = 'SELF' order by s.started_at desc limit 1
)
delete from section_scores
where sec = 'SELF' and session_id in (select id from last)
returning *;
