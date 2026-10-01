extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "farkle"
const TITLE := "Farkle"
const GOAL := "Be the first to 10,000 points. You play against the computer."
const HOW := [
	"Roll the six dice, then tap the scoring dice you want to set aside. You must keep at least one.",
	"Then roll the rest to add more, or Bank to save your turn's points.",
	"Roll with nothing that scores and it's a Farkle: you lose that turn's points.",
	"Score all six dice (hot dice) and you get to roll all six again.",
	"Scoring: a 1 is 100, a 5 is 50. Three of a kind is the number × 100 (three 1s are 1,000); each extra die of the kind doubles it. 1-2-3-4-5-6 or three pairs is 1,500.",
]
const TIPS := [
	"With only one or two dice left, banking is usually smart — farkling is very likely.",
	"You don't have to keep every scoring die: setting aside just a 1 leaves more dice to roll.",
	"When you're far behind near the end, take bigger risks.",
]
const STATS := ["Wins", "Losses", "Best streak"]
