extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## TITLE is the working title (name check pending); the id "rectangles" never changes.

const ID := "rectangles"
const TITLE := "Gridmaster"
const GOAL := "Split the grid into rectangles: each holds one number, and the number is its size."
const HOW := [
	"Drag from one cell to another to draw a rectangle between them. It fills with colour when it holds exactly one number and has that many cells.",
	"A rectangle that doesn't fit the rule disappears when you let go.",
	"Drawing over coloured rectangles removes them. Tap a coloured rectangle to remove it. ↶ Undo takes back your last change, ⟲ Reset clears the board.",
	"Tap a number that has no rectangle yet to see every shape it can take (6 can be 1 × 6, 2 × 3, 3 × 2 or 6 × 1). This costs nothing.",
	"💡 Hint makes one correct rectangle blink, without placing it. The counter at the top shows rectangles placed out of the total.",
	"You win when every cell is covered. Any split that follows the rules wins, and every puzzle has exactly one.",
	"Classic levels: 3 ★ with no hint and under the par time, 2 ★ with at most one hint, 1 ★ for finishing. Daily: one 7 × 7 board a day, the same for everyone. Weekly: a big 10 × 10 board. Zen: endless random boards.",
]
const TIPS := [
	"Start with the numbers that have only one possible shape: a prime number on a wall, or a big number in a narrow spot.",
	"A cell that only one number can reach belongs to that number.",
	"Small numbers next to each other often fix each other's shapes.",
]
const STATS := ["Puzzles solved", "No-hint solves", "Daily streak"]

const ACHIEVEMENTS := [
	{"id": "solved5", "icon": "🟦", "title": "First Cuts", "desc": "Solve 5 puzzles", "key": "Puzzles solved", "at": 5},
	{"id": "solved50", "icon": "🧱", "title": "Master Tiler", "desc": "Solve 50 puzzles", "key": "Puzzles solved", "at": 50},
	{"id": "clean10", "icon": "🧠", "title": "Pure Logic", "desc": "Solve 10 puzzles without a hint", "key": "No-hint solves", "at": 10},
	{"id": "pack1", "icon": "⭐", "title": "Full Pack", "desc": "Earn all 90 stars in the first 30 Classic levels", "key": "Classic stars", "at": 90},
	{"id": "daily7", "icon": "📅", "title": "Week of Rectangles", "desc": "Solve the Daily 7 days in a row", "key": "Daily streak", "at": 7},
	{"id": "fast7", "icon": "⚡", "title": "Quick Cutter", "desc": "Solve a 7 × 7 board in under 60 seconds", "key": "Fast 7x7 solves", "at": 1},
]

## Learning hook (STANDARDS §15): every clue is an area, so play is factorizing.
const FACTS := [
	"Each number is an area, so finding a shape means finding two numbers that multiply to it: 12 can be 1 × 12, 2 × 6 or 3 × 4, either way round.",
	"A prime number, like 7 or 11, can only make a straight line of cells, because its only factors are 1 and itself.",
	"A square number, like 4 or 9, is the only kind that can make a square.",
]
