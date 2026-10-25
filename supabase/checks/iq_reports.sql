-- IQ Test: questions players flagged with 🚩 in a practice test (item-report Edge Function).
-- Not run by Claude (no production DB access).
-- Read-only. Run in the Supabase SQL editor; newest first. Each row has everything needed to
-- rebuild and check the question: the generator (gid), level (d), the key, what the player
-- answered and the display the app drew (answer_key.report.display).
select
  r.answer_key -> 'report' ->> 'at'  as reported_at,
  r.answer_key -> 'report' ->> 'why' as why,
  r.gid, r.sec, r.d, r.u,
  r.answer_key -> 'key'               as answer_key,
  r.answer_key -> 'report' -> 'value' as player_answer,
  s.lang, s.mode, s.id as session_id, r.seq,
  r.answer_key -> 'report' -> 'display' as display
from public.responses r
join public.sessions s on s.id = r.session_id
where r.answer_key ? 'report'
order by r.answer_key -> 'report' ->> 'at' desc
limit 200;
