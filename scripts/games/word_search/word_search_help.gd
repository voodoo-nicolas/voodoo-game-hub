extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "word_search"
const TITLE := "Word Search"
const GOAL := "Find every hidden word in the grid."
const HOW := [
	"The words are listed below the grid, all on one theme.",
	"Easy is an 8 × 8 grid with 6 words, and they only read forwards: across, down or diagonally.",
	"Medium (10 × 10, 8 words) and Hard (14 × 14, 12 words) also hide words backwards.",
	"Drag from the first letter to the last letter of a word to mark it.",
	"Find all the words to finish the puzzle.",
	"⏸ pauses and keeps the puzzle; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Look for rare letters like Q, X, Z or J — they stand out.",
	"Scan one row at a time for the first letter of a word, then check the letters around it.",
	"Don't forget the backwards and diagonal words!",
]
const STATS := ["Puzzles solved", "Best time (%s)" % "Easy", "Best time (%s)" % "Medium", "Best time (%s)" % "Hard"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"When you scan for words your eyes don't glide: they jump several times a second, in movements called saccades.",
]
