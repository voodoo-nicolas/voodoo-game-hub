extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "calcudoku"
const TITLE := "Calcudoku"
const GOAL := "Fill the grid so every row and column has each number once, and every cage makes its target."
const HOW := [
	"In a 4×4 grid use 1–4, in a 5×5 use 1–5, and so on. No number repeats in any row or column.",
	"Each outlined cage shows a target and an operation (+ − × ÷). Its numbers must combine to make the target.",
	"For − and ÷, start with the bigger number: a \"2÷\" cage could be 4 and 2.",
	"A one-square cage just gives you its number.",
	"Tap a square, then a number to fill it (⌫ clears it). Repeated numbers are shown in red.",
	"⏸ pauses and keeps the puzzle; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Fill the one-square cages first — they're free.",
	"Large × targets have few options: 12× in two squares on a 4×4 can only be 3 and 4.",
	"Once a row has only one number missing, it's whatever is left over.",
	"Use the size button to try a bigger grid.",
]
const STATS := ["Puzzles solved"]
