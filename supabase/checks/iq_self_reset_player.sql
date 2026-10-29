-- Reset ONE player's Intrapersonal (SELF) standing so they start over as if it were their first time.
-- Run in the Supabase SQL editor (Claude has no production access). Replace PUT_NICK_HERE in both steps.
-- It deletes only their SELF rows in section_scores (what the leaderboards and the player card's
-- section standing read). Their sessions and answers stay (audit, answer review, 🚩 reports), so
-- the player card's overall % correct still counts them. Other sections are not touched.
-- iq_rescore.ts only updates rows that exist, so it will not bring them back.
-- Step 2 prints every deleted row: save that output, it is the only copy of those numbers.

-- 1) What will be removed
with p as (select id from profiles where nick = 'PUT_NICK_HERE')
select ss.created_at, left(ss.session_id::text, 8) as session, ss.theta, ss.se, ss.n, ss.auc, ss.bias, ss.flagged
from section_scores ss join p on p.id = ss.user_id
where ss.sec = 'SELF' order by ss.created_at;

-- 2) Remove them (run only after checking step 1 is the right player)
with p as (select id from profiles where nick = 'PUT_NICK_HERE')
delete from section_scores
where sec = 'SELF' and user_id in (select id from p)
returning *;

-- 3) Check: nothing left for them in SELF
with p as (select id from profiles where nick = 'PUT_NICK_HERE')
select count(*) as self_rows_left from section_scores ss join p on p.id = ss.user_id where ss.sec = 'SELF';
