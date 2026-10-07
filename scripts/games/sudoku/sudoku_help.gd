extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sudoku"
const TITLE := "Sudoku"
const GOAL := "Fill the grid so every row, column and 3×3 box has the numbers 1 to 9 exactly once."
const HOW := [
	"Tap an empty square, then tap a number to place it.",
	"A wrong number turns red and counts as a mistake.",
	"Notes mode lets you pencil in small candidate numbers. Placing a correct number clears it from the notes in its row, column and box. Erase clears a square and Undo takes back your last move.",
	"💡 Hint never fills in a square: it shows you where to look and which rule to use. Tap it again to see why. You get 3 per puzzle, and a square it reveals earns no points.",
	"Each correct square scores points, mistakes cost points, and fast solves earn a time bonus. Harder levels multiply your score.",
	"📊 Statistics on the Sudoku menu shows your games, solves, best and average times and best scores for each difficulty.",
]
const TIPS := [
	"Look for a number that can only go in one place in a row, column or box.",
	"Look for a square where only one number fits, because the other eight are already in its row, column or box.",
	"Use notes on harder puzzles: when two squares in a box can only be the same two numbers, those numbers can't go anywhere else in that box.",
	"Scan each number from 1 to 9 across the whole grid before you start guessing.",
]
const STATS := ["Puzzles solved", "Perfect games", "Best score"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"A proper Sudoku has exactly one solution, and it needs at least 17 given numbers to have only one (proven in 2012).",
	"There are about 6.67 × 10²¹ different completed Sudoku grids.",
	"The numbers are only symbols: Sudoku works exactly the same with nine letters or nine colours.",
	"The hints name real techniques — hidden single, naked single, pointing, naked pair — the same ones experts use.",
]
