-- IQ Test: mark 🚩 reports as "deemed buggy and fixed", which earns the reporter the
-- 🔧 Fixer achievement (owner, 2026-10-28). The game asks the leaderboard function
-- (board "awards") and pays the badge the next time that player opens the IQ Test.
-- Not run by Claude (no production DB access). Run in the Supabase SQL editor AFTER the
-- fix is deployed. Writes only `answer_key.report.fixed` (the day); no schema change.
-- Find the reports first with supabase/checks/iq_reports.sql (it shows session_id + seq).

-- 1) Check what will be marked: edit the list, run this select, then run the update below.
select r.session_id, r.seq, r.gid, r.d,
       r.answer_key -> 'report' ->> 'why'   as why,
       r.answer_key -> 'report' ->> 'at'    as reported_at,
       r.answer_key -> 'report' ->> 'fixed' as already_fixed
from public.responses r
where r.answer_key ? 'report'
  and (r.session_id, r.seq) in (
    ('00000000-0000-0000-0000-000000000000'::uuid, 0)   -- (session_id, seq) of each report
  );

-- 2) Mark them fixed (same list as above).
update public.responses r
set answer_key = jsonb_set(r.answer_key, '{report,fixed}', to_jsonb(current_date::text))
where r.answer_key ? 'report'
  and not (r.answer_key -> 'report') ? 'fixed'
  and (r.session_id, r.seq) in (
    ('00000000-0000-0000-0000-000000000000'::uuid, 0)
  );

-- Or every report of one question type made before the fix, when the whole type was wrong
-- (look at them first: a report can be wrong too). Replace 'topview' and the time.
-- update public.responses r
-- set answer_key = jsonb_set(r.answer_key, '{report,fixed}', to_jsonb(current_date::text))
-- where r.answer_key ? 'report'
--   and not (r.answer_key -> 'report') ? 'fixed'
--   and r.gid = 'topview'
--   and (r.answer_key -> 'report' ->> 'at') < '2026-10-28T12:00:00Z';
