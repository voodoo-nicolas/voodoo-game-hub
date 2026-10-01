extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "box_pusher"
const TITLE := "Box Pusher"
const GOAL := "Push every box onto a goal square."
const HOW := [
	"Swipe on the board (or use the arrow buttons) to walk one square at a time.",
	"Walk into a box to push it. You can only push one box at a time, and you can never pull.",
	"The level is done when every box sits on a goal.",
	"Stuck? ↶ Undo takes back a step, and Restart resets the level. Finished levels unlock the next one.",
]
const TIPS := [
	"A box pushed into a corner can never come out again — unless the corner is a goal.",
	"A box against a wall can only slide along that wall. Make sure there's a goal along it.",
	"Before each push, check that you'll still be able to get behind the box for the next one.",
]
const STATS := ["Levels solved", "Highest level unlocked"]
