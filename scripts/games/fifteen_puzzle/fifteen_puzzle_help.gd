extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "fifteen_puzzle"
const TITLE := "15-Puzzle"
const GOAL := "Slide the tiles back into order, 1 to 15, with the gap in the bottom-right corner."
const HOW := [
	"Tap a tile in the same row or column as the gap to slide it (and any tiles between) into the gap.",
	"Tiles turn green when they're in their correct spot.",
	"Shuffle starts a new puzzle. Every shuffle can be solved.",
	"⏸ pauses the clock and keeps the puzzle; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Solve the top row first, then the second row. Never disturb a finished row.",
	"Place the last two tiles of a row together: line them up next to their spots, then rotate them in.",
	"Finish the bottom two rows column by column, from left to right.",
]
const STATS := ["Puzzles solved", "Fewest moves", "Best time"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Exactly half of all mixed-up positions of the 15-puzzle can never be solved.",
	"In 1880 a craze for this sliding puzzle swept the United States and Europe.",
]
