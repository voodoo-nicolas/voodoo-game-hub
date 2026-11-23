extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "el_9"
const TITLE := "El 9"
const GOAL := "Be the first to get rid of all your cards by building ladders on the table, against two computers."
const HOW := [
	"The whole Spanish deck (48 cards, 1 to 12 in oros, copas, espadas and bastos) is dealt out. Whoever holds the 9 of oros opens the table with it.",
	"On your turn, play a glowing card: a 9 starts a new ladder for its suit, any other card must be the next number down or up from the ladder of its suit (an 8 or a 10 next to the 9, and so on).",
	"Nothing you can play? Tap Pass.",
	"The first player with no cards left wins. If nobody can move, the one with the fewest cards wins.",
	"With two seats, 12 cards each are dealt and the rest stay out of the game.",
]
const TIPS := [
	"Keep a 9 back when you can: starting a suit lets everybody play in it.",
	"Play the cards that unlock your own neighbours first, and hold on to the 1s and 12s: they close a ladder and block nobody.",
	"Count how many cards the computers have left.",
]
const STATS := ["Wins", "Losses", "Best streak"]
