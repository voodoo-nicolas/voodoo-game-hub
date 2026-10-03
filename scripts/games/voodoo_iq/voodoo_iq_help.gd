extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describe what this game's code actually does; then run `hub.py i18n`.

const ID := "voodoo_iq"
const TITLE := "Voodoo IQ"
const GOAL := "Measure nine kinds of smart with an adaptive test, and climb the boards once there is enough evidence."
const HOW := [
	"Tap a region of the brain (or a numbered chip) to pick a section, or keep All sections for a mixed test.",
	"∞ (the default time) has no clock and no per-question limit: keep answering as long as you like and tap Finish. Every answer counts, so long runs reach the boards faster. If you close the app instead, the test is scored the next time you play.",
	"IQ Test: questions adapt to you. Get them right and they get harder; the score comes from how hard the questions you handled were, not from percent correct.",
	"Blitz: quick questions against the clock. Harder types earn more points, wrong multiple-choice answers lose a fraction, Skip costs 2 seconds.",
	"Each new kind of question starts with untimed instructions; the clock is paused while you read.",
	"Ranked counts for the leaderboards: your last 3 ranked tests in each section are combined, and a quit test still counts. Practice is never saved.",
	"🏆 Leaderboards: the Voodoo IQ board, the 9-Mind board, one board per section and the Blitz bests, filtered by age, country and language. Nothing is capped or hidden: everyone is ranked by their real estimate, and ✓ marks scores with enough evidence behind them.",
	"Leaving the app during a question counts that question as wrong. A test can't be paused or resumed later.",
	"Ranked play needs an account, a player profile and age 16+.",
]
const TIPS := [
	"Missing about half is normal: the test keeps raising the difficulty until you do.",
	"Instant answers are scored wrong, so take the time to actually solve each one.",
	"Use headphones for the musical questions.",
]
const STATS := ["Tests taken", "Blitz runs", "Best Blitz points"]
