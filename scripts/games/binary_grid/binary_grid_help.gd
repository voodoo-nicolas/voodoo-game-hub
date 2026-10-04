extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "binary_grid"
const TITLE := "Binary Grid"
const GOAL := "Fill every cell with cyan or pink so the grid follows both rules."
const HOW := [
	"Rule 1: never three of the same colour next to each other in a row or a column.",
	"Rule 2: every row and every column has as many cyan as pink cells.",
	"Tap an empty cell to make it cyan, again for pink, again to empty it. Cells with a white dot are part of the puzzle and can't change.",
	"A circle breaking a rule glows red. A green dot beside a row or under a column means it's complete and balanced.",
	"Every puzzle has exactly one answer, and you can always reach it by logic — no guessing. 💡 Hint marks a cell you can work out now (or one that's wrong).",
	"Easy is 6 × 6, Medium 8 × 8, Hard 10 × 10.",
	"⏸ pauses the clock and keeps the board; Resume on the Home screen carries on.",
]
const TIPS := [
	"Two of a colour side by side? The cells on both ends must be the other colour.",
	"A gap between two of a colour (cyan, empty, cyan) must be the other colour.",
	"When a row already has half its cells in one colour, the rest are the other colour.",
]
const STATS := ["Puzzles solved", "Best time (Easy)", "Best time (Medium)", "Best time (Hard)"]
