extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "chinchon"
const TITLE := "Chinchón"
const GOAL := "Make groups of cards, close the hand with almost nothing left over, and stay under 100 points, against the computer."
const HOW := [
	"Spanish 40-card deck, 7 cards each. On your turn draw the top card of the deck or the top discard, then discard one card.",
	"Groups: 3 or 4 cards of the same number, or 3 or more cards of one suit in a row (1 to 7, then 10, 11, 12: the 7 is followed by the 10). The picture cards 10, 11 and 12 are worth 10 points, the others are worth their number.",
	"You cannot throw back the discard you just took.",
	"Close the hand by discarding when the 7 cards you keep have at most 5 points outside groups. Both players add the points of their ungrouped cards; closing with every card in a group takes 10 off.",
	"Seven cards of one suit in a row is a Chinchón: you win the whole match at once.",
	"The match ends when someone reaches 100 points: the lower score wins.",
]
const TIPS := [
	"Take the discard only when it completes a group or comes close to one.",
	"Throw away the dear cards (10, 11, 12) first when they are not in a group.",
	"Close early: 5 points left over is enough.",
]
const STATS := ["Wins", "Losses", "Best streak", "Hands closed", "Chinchones"]
