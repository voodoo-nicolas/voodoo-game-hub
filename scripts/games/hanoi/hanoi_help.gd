extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "hanoi"
const TITLE := "Tower of Hanoi"
const GOAL := "Move the whole tower of discs to the right-hand peg."
const HOW := [
	"Tap a peg to lift its top disc, then tap another peg to put it down.",
	"Only one disc moves at a time, and a bigger disc can never sit on a smaller one.",
	"Use − and + to change the number of discs. The best possible number of moves is shown.",
	"⏸ pauses and keeps the tower; Resume on the Home screen picks it up.",
]
const TIPS := [
	"The smallest disc moves every other turn, always around the pegs in the same direction.",
	"On the turns in between, make the only legal move that doesn't touch the smallest disc.",
	"With an odd number of discs, move the smallest one to the right-hand peg first; with an even number, to the middle one.",
	"Think big: to move a tower of 5, first move the top 4 out of the way.",
]
const STATS := ["Puzzles solved", "Perfect solves", "Most discs solved"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"The fewest moves for n discs is 2ⁿ − 1: 7 moves for 3 discs, 1,023 for 10.",
	"With 64 discs, at one move per second, the puzzle would take over 500 billion years.",
]
