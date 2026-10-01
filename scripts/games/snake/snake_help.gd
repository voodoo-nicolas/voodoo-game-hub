extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "snake"
const TITLE := "Snake"
const GOAL := "Eat as much food as you can without crashing."
const HOW := [
	"Use the arrow pad to steer (arrow keys work too). The snake keeps moving on its own.",
	"Each piece of food makes you longer and scores a point.",
	"Running into a wall or your own body ends the game.",
	"Fill the entire board and you win!",
]
const TIPS := [
	"Go around the edges in wide loops rather than zig-zagging through the middle.",
	"Plan an escape route before you grab food in a tight spot.",
	"As you get longer, follow your own tail — it always moves out of the way.",
]
const STATS := ["Best score", "Games played"]
