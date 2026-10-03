extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "memory_grid"
const TITLE := "Memory Grid"
const GOAL := "Remember which tiles lit up, and clear as many levels as you can."
const HOW := [
	"Watch the grid: some tiles light up in gold for a moment.",
	"When they go dark, tap every tile that was lit.",
	"Find them all to clear the level. Each level has more tiles and a bigger grid.",
	"Tapping a tile that wasn't lit costs one of your 3 lives, and you try a new pattern of the same level. Lose all 3 and the game ends.",
	"Your score is the number of levels cleared.",
	"⏸ pauses. A game is quick, so it isn't saved for later.",
]
const TIPS := [
	"Look for shapes (a line, an L, a corner) instead of memorizing single tiles.",
	"Don't touch the screen while the tiles are lit; take it all in first.",
]
const STATS := ["Best score", "Games played"]
