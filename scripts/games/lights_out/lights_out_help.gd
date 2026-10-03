extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "lights_out"
const TITLE := "Lights Out"
const GOAL := "Switch off every light on the board."
const HOW := [
	"Tapping a square toggles it and the squares directly above, below, left and right of it.",
	"Lit squares turn off and dark ones turn on.",
	"Every puzzle can be solved. Leave any time: ⏸ saves the puzzle and Resume on the Home screen picks it up.",
]
const TIPS := [
	"The order of your taps doesn't matter, and tapping a square twice undoes it — so each square only ever needs one tap or none.",
	"Chase the lights down: for each lit square, tap the square just below it, one row at a time. Then look at what's left in the bottom row.",
	"Try to solve it in as few moves as you can.",
]
const STATS := ["Puzzles solved", "Fewest moves"]
