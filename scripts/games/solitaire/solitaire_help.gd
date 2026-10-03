extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "solitaire"
const TITLE := "Solitaire"
const GOAL := "Move all 52 cards onto the four foundation piles, each suit from Ace up to King."
const HOW := [
	"Build down the seven columns in alternating colours: a red 6 goes on a black 7.",
	"Tap a card to pick it up (with any cards on top of it), then tap where it should go.",
	"Only a King (or a run starting with a King) can go into an empty column.",
	"Tap the stock to turn over a card. When it runs out, tap it again to turn the pile back over.",
	"Undo takes back a move. New Deal starts over.",
	"⏸ pauses the clock and keeps the deal; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Turning over face-down cards in the columns is usually the best move.",
	"Don't rush cards to the foundations — low cards are often still needed to build on.",
	"Only empty a column when you have a King ready to move into it.",
	"Work on the columns with the most face-down cards first.",
]
const STATS := ["Games won", "Best time", "Fewest moves"]
