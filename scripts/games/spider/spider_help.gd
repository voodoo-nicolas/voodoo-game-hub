extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "spider"
const TITLE := "Spider"
const GOAL := "Build eight complete runs from King down to Ace in the same suit to clear the table."
const HOW := [
	"You can put any card on a card one rank higher, whatever its suit.",
	"Only a run of cards in the same suit can be moved together.",
	"Tap a card to move it (with the cards below it) to the best spot.",
	"A complete King-to-Ace run in one suit is removed from the table.",
	"Tap the stock (top left) to deal one new card onto every column. Every column needs at least one card first.",
	"Choose 1, 2 or 4 suits for a new game — more suits is much harder.",
	"⏸ pauses and keeps the deal; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Build in the same suit whenever you can: mixed runs can't be moved as one.",
	"Empty columns are gold — use them to reorganise runs.",
	"Before dealing, tidy up as much as you can: the new row covers everything.",
	"Start with 1 suit to learn the game.",
]
const STATS := ["Games won"]
