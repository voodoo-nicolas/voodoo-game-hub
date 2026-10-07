extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "rummy"
const TITLE := "Rummy"
const GOAL := "Get rid of all your cards by making melds and discarding. First to 100 points wins the match."
const HOW := [
	"You and the computer get 10 cards each. On your turn, first draw: tap the stock pile (face down) or the discard pile (the top card face up).",
	"Then you may put down melds. A set is 3 or 4 cards of the same rank in different suits. A run is 3 or more cards in a row of the same suit (the Ace can be low, A-2-3, or high, Q-K-A, but a run can't wrap round).",
	"Tap your cards to select them, then tap 🃏 Meld. To add a card to a meld already on the table, yours or the computer's, select it and tap that meld: melds that accept your selection glow.",
	"Finish your turn by selecting one card and tapping 🗑 Discard. You can't discard the card you just took from the discard pile.",
	"Go out by playing your last card (by melding, laying off or discarding it). You score the points left in the computer's hand: Ace 1, 2 to 10 face value, J Q K 10 each. If the stock runs out, nobody scores.",
	"A match is played to 100 points. A match in progress is kept; Resume on the Landing carries on.",
]
const TIPS := [
	"Keep cards that are close together (a 6 and an 8 of the same suit, or two of a kind): they are a draw away from a meld.",
	"Watch what the computer takes from the discard pile: it tells you which cards it is collecting.",
	"Lay off cards on melds as soon as you can: it empties your hand and cuts what you'd lose if the computer goes out.",
]
const STATS := ["Wins", "Losses", "Best streak", "Hands won"]

const ACHIEVEMENTS := [
	{"id": "hands1", "icon": "🃏", "title": "Going Out", "desc": "Win 10 hands", "key": "Hands won", "at": 10},
	{"id": "hands2", "icon": "🏆", "title": "Rummy Regular", "desc": "Win 50 hands", "key": "Hands won", "at": 50},
]

## Learning hook (STANDARDS §15). Checked facts only.
const FACTS := [
	"The game that became Gin Rummy was invented around 1909 by Elwood T. Baker in New York.",
]
