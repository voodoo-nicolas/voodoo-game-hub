extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "nonogram"
const TITLE := "Nonogram"
const GOAL := "Fill in the right squares to reveal the hidden picture."
const HOW := [
	"The numbers beside each row and above each column are the lengths of its runs of filled squares, in order.",
	"Runs are separated by at least one empty square. \"3 1\" means three filled, a gap, then one filled.",
	"Tap or drag to fill squares. Switch to ✕ mode to mark squares you know are empty.",
	"The puzzle is solved when every row and column matches its numbers.",
	"Every puzzle can be solved by logic alone — no guessing needed.",
	"⏸ pauses and keeps the puzzle; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Start with big numbers: a 7 in a 10-square row must cover its middle four squares.",
	"A row or column with a 0 is completely empty — mark it all off.",
	"Mark the squares you've ruled out. Every ✕ narrows down the lines that cross it.",
	"Go back and forth between rows and columns.",
]
const STATS := ["Puzzles solved"]
