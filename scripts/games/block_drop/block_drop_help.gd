extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "block_drop"
const TITLE := "Block Drop"
const GOAL := "Fit the falling pieces together to fill complete rows. Keep going as long as you can!"
const HOW := [
	"Drag sideways to move the piece, tap to rotate it, and flick down to drop it.",
	"The ↺ and ↻ buttons turn the piece left or right.",
	"Before starting, pick a Difficulty (Easy is slower, Hard starts at level 5) and a Board: Big and Huge wells make the pieces smaller, with more room to fit them.",
	"A complete row disappears and everything above it falls down.",
	"Clearing 1, 2, 3 or 4 rows at once scores 100, 300, 500 or 800 points, times the level.",
	"Every 10 rows the level goes up and pieces fall faster.",
	"The game ends when the pieces stack up to the top.",
]
const TIPS := [
	"Keep the surface flat and leave one column open at the side for the long piece — four rows at once scores the most.",
	"Check the Next box to plan where the following piece will go.",
	"Avoid covering up holes: a gap under a block is hard to fill later.",
	"Dropping fast earns a few bonus points.",
]
const STATS := ["Best score", "Most lines", "Games played"]
