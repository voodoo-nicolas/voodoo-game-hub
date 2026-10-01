extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "g2048"
const TITLE := "2048"
const GOAL := "Slide the tiles and merge matching numbers until you make a 2048 tile."
const HOW := [
	"Swipe up, down, left or right (or use the arrow keys). Every tile slides as far as it can.",
	"Two tiles with the same number that bump into each other merge into one: 2+2 makes 4, 4+4 makes 8, and so on.",
	"Each merge adds the new tile's number to your score.",
	"A new 2 or 4 appears after every move.",
	"The game ends when the board is full and nothing can merge. Reach 2048 and you can keep going for a bigger score.",
]
const TIPS := [
	"Pick a corner and keep your biggest tile in it.",
	"Mostly use just two or three directions, so the big tile never gets pushed out of its corner.",
	"Keep the row along your corner full, so it can't shift out of place.",
	"Build a chain of shrinking numbers leading away from the corner, so merges cascade into it.",
]
const STATS := ["Best score", "Best tile", "Games played"]
