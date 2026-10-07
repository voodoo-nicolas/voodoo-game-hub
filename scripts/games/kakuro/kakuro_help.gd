extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "kakuro"
const TITLE := "Kakuro"
const GOAL := "Fill the white squares with 1–9 so each run adds up to its clue."
const HOW := [
	"A clue in the top-right of a dark square is the total for the run of white squares to its right.",
	"A clue in the bottom-left is the total for the run going down below it.",
	"No digit can repeat within a run.",
	"Tap a square, then a digit to fill it (⌫ clears it). Repeated digits are shown in red.",
	"Switch between Small and Large boards with the size button.",
	"⏸ pauses and keeps the puzzle; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Learn the runs with only one answer: 3 in two squares is always 1+2, 4 is 1+3, 16 is 7+9 and 17 is 8+9.",
	"Where an across run and a down run cross, the square must suit both sums.",
	"Big sums in short runs force big digits, small sums force small digits.",
]
const STATS := ["Puzzles solved"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Some sums can be made only one way: 3 in two squares is always 1 + 2, and 45 in nine squares uses every digit.",
]
