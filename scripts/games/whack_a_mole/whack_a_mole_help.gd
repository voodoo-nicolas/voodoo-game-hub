extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "whack_a_mole"
const TITLE := "Bop the Mole"
const GOAL := "Whack as many moles as you can in 30 seconds."
const HOW := [
	"Tap Start Round, then tap each mole as it pops up out of a hole.",
	"Every hit scores a point. Moles duck back down if you're too slow.",
	"The round ends when the timer runs out.",
	"⏸ pauses the clock. A round is only 30 seconds, so it isn't saved for later.",
]
const TIPS := [
	"Keep your finger near the middle of the board: every hole is close by.",
	"Don't tap empty holes — watch for the mole, then strike.",
]
const STATS := ["Best score", "Rounds played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🔨", "title": "Mole Bopper", "key": "Best score", "at": 20},
	{"id": "goal2", "icon": "🐹", "title": "Whack Pro", "key": "Best score", "at": 40},
	{"id": "goal3", "icon": "⚡", "title": "Lightning Hands", "key": "Best score", "at": 60},
]
