extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "quick_math"
const TITLE := "Quick Math"
const GOAL := "Answer as many sums as you can in 60 seconds."
const HOW := [
	"A sum appears. Tap the right answer from the four choices.",
	"Every right answer scores a point. Every 5 points the questions get harder: bigger numbers, times tables, division and brackets.",
	"A wrong answer breaks your streak and costs you 3 seconds.",
	"⏸ pauses the clock. A round is only a minute, so it isn't saved for later.",
]
const TIPS := [
	"Don't chase exact digits: check the last digit first, it often rules out two choices.",
	"A wrong answer costs 3 seconds, about the time of a fast right one, so guessing blindly rarely pays.",
]
const STATS := ["Best score", "Best streak", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "➕", "title": "Quick Thinker", "key": "Best score", "at": 15},
	{"id": "goal2", "icon": "✖️", "title": "Mental Math", "key": "Best score", "at": 30},
	{"id": "goal3", "icon": "🧮", "title": "Human Calculator", "key": "Best score", "at": 50},
]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"To multiply by 5, multiply by 10 and halve: 5 × 18 = 180 ÷ 2 = 90.",
	"Adding 9 is the same as adding 10 and taking away 1.",
	"A number can be divided by 9 exactly when its digits add up to a multiple of 9: 576 → 5 + 7 + 6 = 18.",
]
