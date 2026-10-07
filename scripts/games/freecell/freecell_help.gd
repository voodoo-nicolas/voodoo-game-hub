extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "freecell"
const TITLE := "FreeCell"
const GOAL := "Move all 52 cards onto the foundations, each suit from Ace up to King."
const HOW := [
	"All cards are dealt face up in eight columns. Build down in alternating colours.",
	"The four free cells (top left) each hold one card for a while.",
	"Tap a card to send it to the best spot: a foundation, another column, or a free cell. Cards below it move along if there's room.",
	"The more free cells and empty columns you have, the longer the runs you can move at once.",
	"Cards that aren't needed any more go up to the foundations by themselves.",
	"⏸ pauses and keeps the deal; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Free cells are precious — try to keep at least one empty.",
	"An empty column is worth even more than a free cell.",
	"Before you start, look for the Aces and twos buried deepest, and plan how to dig them out.",
	"Almost every deal can be won, so if you get stuck, Undo and try another way.",
]
const STATS := ["Games won", "Best time", "Fewest moves"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Almost every FreeCell deal can be won: of the 32,000 classic numbered deals, only one (#11982) can't.",
]
