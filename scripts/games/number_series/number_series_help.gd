extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "number_series"
const TITLE := "Number Series"
const GOAL := "Spot the pattern and pick the number that comes next."
const HOW := [
	"A row of numbers follows a hidden rule. Tap the number that should come next.",
	"There are 12 questions, and they get harder: simple steps first, then squares, growing gaps and number sequences woven together.",
	"Each right answer scores 10 points, plus up to 5 bonus points for answering quickly. You have 25 seconds per question.",
	"After a miss you see the rule, so you can learn it for next time.",
]
const TIPS := [
	"Check the gaps between neighbors first: are they equal, growing, or alternating?",
	"If the numbers grow fast, try multiplying. If they seem to zigzag, look at every second number.",
]
const STATS := ["Best score", "Best streak", "Games played"]
