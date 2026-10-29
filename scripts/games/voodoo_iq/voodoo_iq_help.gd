extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describe what this game's code actually does; then run `hub.py i18n`.

const ID := "voodoo_iq"
const TITLE := "IQ Test"
const GOAL := "Measure nine kinds of smart with an adaptive test, and climb the boards once there is enough evidence."
const HOW := [
	"Tap a region of the brain (or a numbered chip) to pick a section, or keep All sections for a mixed test.",
	"∞ (the default time) has no clock and no per-question limit: keep answering as long as you like and tap Finish. Every answer counts, so long runs reach the boards faster. If you close the app instead, the test is scored the next time you play.",
	"IQ Test: questions adapt to you. Get them right and they get harder; the score comes from how hard the questions you handled were, not from percent correct.",
	"Speed Round: quick questions against the clock. Harder types earn more points, wrong multiple-choice answers lose a fraction, Skip costs 2 seconds.",
	"Each new kind of question starts with untimed instructions; the clock is paused while you read.",
	"Ranked counts for the leaderboards: your last 3 ranked tests in each section are combined, and a quit test still counts. Practice is never saved.",
	"Practice shows the answers: after each question you see whether you were right, what the right answer was and 💡 why, and at the end 📝 Review answers lists every question. 🚩 reports a question that looks wrong so we can check it. Ranked tests never show answers.",
	"🏆 Leaderboards: the IQ board, the 9-Mind board, one board per section and the Speed Round bests, filtered by age, country and language. Nothing is capped or hidden: everyone is ranked by their real estimate, and ✓ marks scores with enough evidence behind them.",
	"⏸ pauses a test: the clock stops and the question is hidden, and you can change the text size and sound there.",
	"Can't play sound? The musical questions offer 🔇: skip them for the rest of the test (they count only for the Musical section) or end the test.",
	"Leaving the app during a question counts that question as wrong. A test can't be resumed after you leave it.",
	"Ranked play needs an account, a player profile and age 16+.",
	"🏅 Achievements: besides tests taken and Speed Rounds, earn the ★130+ genius medal in each section, practice for an hour in all, or 🚩 flag a question that turns out to be wrong and gets fixed.",
]
const TIPS := [
	"Missing about half is normal: the test keeps raising the difficulty until you do.",
	"Instant answers are scored wrong, so take the time to actually solve each one.",
	"Use headphones for the musical questions.",
	"Existential questions are pure logic: 💡 Example shows how to read them.",
]
const STATS := ["Tests taken", "Blitz runs", "Best Blitz points"]
## IQ Test's own achievements (owner, 2026-10-28), paid by voodoo_iq_awards.gd. Points: the
## generic badges above pay 480 (tests 220, Speed Rounds 220, records 40) + these 500 = 980,
## under the 1000 a game may offer (STANDARDS §3b).
const CHALLENGES := [
	{"id": "genius_LOG", "icon": "🧮", "title": "Logic Genius", "desc": "Earn the ★130+ genius medal in Logical-Mathematical.", "xp": 40},
	{"id": "genius_SPA", "icon": "🧊", "title": "Spatial Genius", "desc": "Earn the ★130+ genius medal in Spatial.", "xp": 40},
	{"id": "genius_LIN", "icon": "📖", "title": "Linguistic Genius", "desc": "Earn the ★130+ genius medal in Linguistic.", "xp": 40},
	{"id": "genius_MUS", "icon": "🎵", "title": "Musical Genius", "desc": "Earn the ★130+ genius medal in Musical.", "xp": 40},
	{"id": "genius_NAT", "icon": "🌿", "title": "Naturalist Genius", "desc": "Earn the ★130+ genius medal in Naturalist.", "xp": 40},
	{"id": "genius_KIN", "icon": "🤸", "title": "Kinesthetic Genius", "desc": "Earn the ★130+ genius medal in Bodily-Kinesthetic.", "xp": 40},
	{"id": "genius_INT", "icon": "🤝", "title": "Interpersonal Genius", "desc": "Earn the ★130+ genius medal in Interpersonal.", "xp": 40},
	{"id": "genius_SELF", "icon": "🪞", "title": "Intrapersonal Genius", "desc": "Earn the ★130+ genius medal in Intrapersonal.", "xp": 40},
	{"id": "genius_EXI", "icon": "🌌", "title": "Existential Genius", "desc": "Earn the ★130+ genius medal in Existential.", "xp": 40},
	{"id": "prepper", "icon": "📚", "title": "Prepper", "desc": "Practice for 1 hour in all (IQ tests and Speed Rounds).", "xp": 60},
	{"id": "fixer", "icon": "🔧", "title": "Fixer", "desc": "Flag a practice question with 🚩 that turns out to be wrong and gets fixed.", "xp": 80},
]
