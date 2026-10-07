extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "dots_boxes"
const TITLE := "Dots and Boxes"
const GOAL := "Close more boxes than your opponent."
const HOW := [
	"On the Home screen, pick a board size under vs Computer or 2 Players (one phone), or 🌐 Online to play a friend on another phone.",
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
const STATS := ["Wins", "Losses", "Draws", "Best streak", "Blue wins", "Red wins", "2-player ties"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Mathematician Elwyn Berlekamp wrote a whole book about this game; strong players win by counting long chains.",
]
