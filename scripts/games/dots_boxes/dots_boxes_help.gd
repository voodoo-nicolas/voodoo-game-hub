extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "dots_boxes"
const TITLE := "Dots and Boxes"
const GOAL := "Close more boxes than your opponent."
const HOW := [
	"Pick vs Computer or 2 Players and a board size. You can also play a friend online.",
	"Take turns drawing one line between two neighbouring dots.",
	"Draw the fourth side of a box and it's yours — and you must draw another line.",
	"When every line is drawn, the player with the most boxes wins.",
	"On a touch screen, tap a line and then Confirm Line, so a slip of the finger doesn't cost you.",
]
const TIPS := [
	"Never draw the third side of a box — your opponent will take it.",
	"Early on, draw lines that don't give anything away. The player forced to open a chain of boxes first usually loses.",
	"When you take a long chain, consider leaving the last two boxes for your opponent: then they have to open the next chain for you.",
]
const STATS := ["Wins", "Losses", "Draws"]
