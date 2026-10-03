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
