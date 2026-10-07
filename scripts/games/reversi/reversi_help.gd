extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "reversi"
const TITLE := "Reversi"
const GOAL := "Have more discs of your colour on the board when it's full."
const HOW := [
	"Play the computer (Easy, Medium or Hard) or a friend on one phone. Black moves first; against the computer you are Black.",
	"Place a disc so that one or more of your opponent's discs are trapped in a straight line between it and another of yours. Every trapped disc flips to your colour.",
	"Lines can go across, down or diagonally, and one move can flip lines in several directions.",
	"If you can't make a legal move, your turn passes. The game ends when neither player can move.",
	"Tap 🌐 Online on the Home screen to play a friend on another phone with a room code.",
]
const TIPS := [
	"Corners can never be flipped back — they're the best squares on the board.",
	"Avoid the squares right next to an empty corner: they hand the corner to your opponent.",
	"Having lots of discs early doesn't matter much. Keep your options open instead.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "Biggest win (discs)", "Black wins", "White wins"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"A corner disc can never be flipped back — that's why corners are so valuable.",
	"A 2023 computer study found that perfect play on the 8 × 8 board ends in a draw.",
]
