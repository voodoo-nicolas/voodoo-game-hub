extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "hidato"
const TITLE := "Hidato"
const GOAL := "Fill the grid with every number from 1 to the last, each one touching the next."
const HOW := [
	"Some numbers are already in the grid (shaded). Place all the others so that 1 touches 2, 2 touches 3, and so on up to the last number.",
	"Numbers touch when their cells are next to each other sideways, up and down, or diagonally.",
	"Tap an empty cell, then tap a number in the pad under the board. Only numbers not yet on the board are in the pad. Putting a number somewhere else moves it. ⌫ Clear empties the picked cell.",
	"A faint gold line joins each pair of consecutive numbers that touch, so you can see your path grow.",
	"✔ Check lights up numbers that don't touch their next number. 💡 Hint fills one cell for you. Any complete path that matches the given numbers counts as a solution.",
	"Easy is 4 × 4, Normal 5 × 5, Hard 6 × 6, Expert 7 × 7. A puzzle in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Look at the given numbers that have only one empty cell near them: they often have one possible neighbor.",
	"A cell in a corner touches only three others, so the number there must be next to one of those.",
	"Work from both directions: if 5 and 7 are given and 6 must be next to both, only the cells touching both can hold it.",
]
const STATS := ["Puzzles solved", "Best time (Easy)", "Best time (Normal)", "Best time (Hard)", "Best time (Expert)", "No-hint solves"]

const ACHIEVEMENTS := [
	{"id": "solved1", "icon": "🔢", "title": "Path Finder", "desc": "Solve 5 puzzles", "key": "Puzzles solved", "at": 5},
	{"id": "solved2", "icon": "🧭", "title": "Pathmaster", "desc": "Solve 50 puzzles", "key": "Puzzles solved", "at": 50},
	{"id": "clean1", "icon": "💡", "title": "Pure Logic", "desc": "Solve 10 puzzles without a hint", "key": "No-hint solves", "at": 10},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"Hidato was invented by the Israeli mathematician Gyora Benedek, and its name comes from the Hebrew word for 'riddle'.",
]
