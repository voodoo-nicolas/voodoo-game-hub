-- Color Sort's leaderboard changed from "Puzzles solved" to "Total stars" (2026-10-16).
-- Old rows hold puzzle counts, which would sit above star totals for good (the scores
-- table only ever keeps the higher number). Run once in the Supabase SQL editor,
-- when the new Color Sort pack goes live. Claude cannot (and did not) run this.
delete from public.scores where game = 'color_sort';
-- The campaign position ('color_sort_level') needs nothing: it is a plain scores row.
