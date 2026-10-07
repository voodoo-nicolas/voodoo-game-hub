extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "flood_it"
const TITLE := "Color Flood"
const GOAL := "Turn the whole board into one colour before you run out of moves."
const HOW := [
	"The flood starts in the top-left corner: that cell and every cell of the same colour touching it.",
	"Tap a colour button (or any cell of that colour): the whole flood takes that colour and swallows the touching cells that match.",
	"Fill the board within the move limit shown at the top. The limit leaves a little room, but not much.",
	"Easy is 10 × 10 with 5 colours, Normal 14 × 14 with 6, Hard 18 × 18 with 7.",
	"⏸ pauses and keeps the board; Resume on the Home screen carries on.",
]
const TIPS := [
	"Grow towards the middle first: the flood's edge gets longer, and longer edges catch more cells.",
	"Look a move ahead: a colour that swallows little now may open up a big patch next.",
	"Clear away a colour completely when you can — then it never needs another move.",
]
const STATS := ["Puzzles solved", "Wins", "Losses", "Best streak", "Fewest moves (Easy)", "Fewest moves (Normal)", "Fewest moves (Hard)"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Finding the fewest moves to flood a board is NP-hard: no fast method is known for big boards.",
]
