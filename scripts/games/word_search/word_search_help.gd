extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "word_search"
const TITLE := "Word Search"
const GOAL := "Find every hidden word in the grid."
const HOW := [
	"The words are listed below the grid, all on one theme.",
	"Words can run across, down or diagonally, forwards or backwards.",
	"Drag from the first letter to the last letter of a word to mark it.",
	"Find all the words to finish the puzzle.",
]
const TIPS := [
	"Look for rare letters like Q, X, Z or J — they stand out.",
	"Scan one row at a time for the first letter of a word, then check the letters around it.",
	"Don't forget the backwards and diagonal words!",
]
const STATS := ["Puzzles solved"]
