extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "gin_rummy"
const TITLE := "Gin Rummy"
const GOAL := "Form your cards into melds and be the first to 100 points. You play against the computer."
const HOW := [
	"Each turn, draw a card from the stock or take the top discard, then discard one.",
	"Melds are sets (3 or 4 cards of the same rank) or runs (3 or more in a row of one suit). Aces are low.",
	"Cards that aren't in a meld are deadwood. Face cards count 10, Aces 1, others their number.",
	"When your deadwood is 10 or less you can Knock to end the hand. Zero deadwood is Gin, worth a 25-point bonus.",
	"After a knock, the other player can lay off deadwood onto the knocker's melds. If they end up with less or equal deadwood, they undercut and score a 25 bonus instead.",
	"⏸ pauses and keeps the match; Resume on the Home screen carries on.",
]
const TIPS := [
	"Get rid of high cards early — a stray King is 10 points of deadwood.",
	"Watch what the computer picks up from the discard pile, and don't give it cards it needs.",
	"Knock as soon as you can early in the hand; go for Gin when the computer seems slow.",
]
const STATS := ["Wins", "Losses", "Best streak"]
