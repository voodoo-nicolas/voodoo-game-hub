extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "same_game"
const TITLE := "Block Collapse"
const GOAL := "Clear as many blocks as you can, in big groups, for the highest score."
const HOW := [
	"Tap a block to light up its group: every block of the same colour joined to it side by side. The line above the board shows what it's worth.",
	"Tap the group again to clear it. Single blocks can't be cleared.",
	"Blocks above fall down into the gaps, and empty columns slide together to the left.",
	"A group of n blocks scores (n − 2)²: 3 blocks = 1, 5 = 9, 10 = 64. Clearing the whole board earns 1000 more.",
	"The game ends when no group of two is left. ↶ Undo takes back a move.",
	"Easy has 3 colours, Normal 4, Hard 5.",
	"⏸ pauses and keeps the board; Resume on the Home screen carries on.",
]
const TIPS := [
	"Don't clear small groups just because you can: let them join up into a big one first.",
	"Pick one colour to save for a giant group at the end, and clear the others out of its way.",
	"Clearing from the bottom moves more blocks than clearing from the top.",
]
const STATS := ["Best score", "Boards cleared", "Fewest blocks left", "Games played"]
