extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "reversi"
const TITLE := "Reversi"
const GOAL := "Have more discs of your colour on the board when it's full."
const HOW := [
	"Two players share the phone. Black moves first.",
	"Place a disc so that one or more of your opponent's discs are trapped in a straight line between it and another of yours. Every trapped disc flips to your colour.",
	"Lines can go across, down or diagonally, and one move can flip lines in several directions.",
	"If you can't make a legal move, your turn passes. The game ends when neither player can move.",
	"Tap 🌐 Play Online to play a friend on another phone with a room code.",
]
const TIPS := [
	"Corners can never be flipped back — they're the best squares on the board.",
	"Avoid the squares right next to an empty corner: they hand the corner to your opponent.",
	"Having lots of discs early doesn't matter much. Keep your options open instead.",
]
const STATS := ["Black wins", "White wins", "Draws"]
