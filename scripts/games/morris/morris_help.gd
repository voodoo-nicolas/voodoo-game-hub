extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "morris"
const TITLE := "Nine Men's Morris"
const GOAL := "Take your opponent down to two pieces, or leave them with no move. Play the computer or a friend."
const HOW := [
	"First, take turns placing your 9 pieces on empty points.",
	"Then take turns moving a piece along a line to a neighbouring empty point.",
	"Three of your pieces in a row along a line is a mill: remove one of the computer's pieces. Pieces in a mill are safe unless there's nothing else to take.",
	"Once you're down to three pieces you can fly — move to any empty point.",
	"Choose Normal or Hard for the computer.",
	"Two players share the phone: White moves first, then Black.",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"Aim for two mills that share a point: you can open and close one every turn.",
	"Don't place all your pieces on the outside — middle points connect to more lines.",
	"Block the computer whenever it has two in a row with the third point empty.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "White wins", "Black wins"]
