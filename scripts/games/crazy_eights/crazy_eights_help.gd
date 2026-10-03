extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "crazy_eights"
const TITLE := "Crazy Eights"
const GOAL := "Be the first to get rid of all your cards. You play against two computers."
const HOW := [
	"On your turn, play a card that matches the top card's suit or rank.",
	"8s are wild: play one on anything and choose the next suit.",
	"Can't play? Tap the deck to draw until you can. If the deck is empty too, you pass.",
	"The first player with no cards left wins.",
	"⏸ pauses; the game is kept on your turn, and Resume on the Home screen carries on.",
]
const TIPS := [
	"Keep your 8s for when you're stuck.",
	"When you play an 8, pick the suit you hold the most of.",
	"Watch how many cards the computers have left, and change the suit when one is about to go out.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak"]
