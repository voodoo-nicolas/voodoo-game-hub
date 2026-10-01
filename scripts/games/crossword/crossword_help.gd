extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "crossword"
const TITLE := "Crossword"
const GOAL := "Fill in every word in the grid using the clues."
const HOW := [
	"Tap a square to choose a word. The clue for it appears above the keyboard.",
	"Tap the same square again to switch between the Across and Down word.",
	"Type letters with the keyboard — the cursor moves to the next square by itself.",
	"◀ Prev and Next ▶ jump between clues.",
	"Check shows any wrong letters. Reveal letter fills in the current square if you're stuck.",
]
const TIPS := [
	"Fill in the words you're sure of first — every letter helps the words that cross it.",
	"Short words are often the easiest way in.",
	"Every puzzle is new, built fresh from a big list of clues.",
]
const STATS := ["Puzzles solved"]
