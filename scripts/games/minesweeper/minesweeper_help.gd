extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "minesweeper"
const TITLE := "Minesweeper"
const GOAL := "Uncover every square that doesn't hide a mine."
const HOW := [
	"Tap a square to dig it. Your first tap is always safe and opens up an area.",
	"A number tells you how many mines touch that square, diagonals included.",
	"Switch to 🚩 mode to flag squares you think hide mines.",
	"Tap a number that already has all its flags around it to dig every other square next to it.",
	"Dig up a mine and you lose. Pick Easy, Medium or Hard for bigger boards with more mines.",
]
const TIPS := [
	"A 1 with only one hidden square next to it: that square is a mine.",
	"If a number already has all its mines flagged, every other square around it is safe.",
	"Look for the 1-2-1 pattern along a wall: the mines are under the two 1s.",
	"Guess only when nothing else is left, and prefer squares far from the numbers.",
]
const STATS := ["Wins", "Losses", "Best streak"]
