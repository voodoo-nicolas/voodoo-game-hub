-- One player's Intrapersonal (SELF) tests: what was scored and what the stored answers are.
-- Run in the Supabase SQL editor (Claude has no production access). Put the nick below.
-- 1) their SELF section_scores rows (theta, se, n, auc = confidence vs correctness, bias)
-- 2) per SELF session: answers by question type and difficulty, how many were right, and how
--    many carry a key that no longer counts (topview needs rev 3, natclass d>=7 / natodd d>=8 need rev 2)
with p as (select id from profiles where nick = 'PUT_NICK_HERE')
select s.started_at::date as day, s.id, ss.theta, ss.se, ss.n, ss.auc, ss.bias, ss.flagged
from sessions s join p on p.id = s.user_id
left join section_scores ss on ss.session_id = s.id and ss.sec = 'SELF'
where s.mode = 'iq' and s.scope = 'SELF' order by s.started_at desc limit 10;

with p as (select id from profiles where nick = 'PUT_NICK_HERE')
select s.started_at::date as day, left(s.id::text, 8) as session, r.gid, r.d,
       count(*) as answers, sum(r.u)::int as right_, round(avg(r.conf)::numeric, 2) as avg_conf,
       count(*) filter (where
         (r.gid = 'topview' and coalesce((r.answer_key->'key'->>'rev')::int, 1) < 3)
         or (r.gid = 'natclass' and r.d >= 7 and coalesce((r.answer_key->'key'->>'rev')::int, 1) < 2)
         or (r.gid = 'natodd' and r.d >= 8 and coalesce((r.answer_key->'key'->>'rev')::int, 1) < 2)
       ) as dropped
from responses r join sessions s on s.id = r.session_id join p on p.id = s.user_id
where s.mode = 'iq' and s.scope = 'SELF' and r.answered_at is not null
group by 1, 2, 3, 4 order by 1 desc, 2, 3, 4;
