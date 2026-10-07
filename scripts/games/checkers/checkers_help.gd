extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "checkers"
const TITLE := "Checkers"
const GOAL := "Capture all of your opponent's pieces, or leave them with no move."
const HOW := [
	"Play the computer (Easy, Medium or Hard) or a friend on one phone. Red (Player 1) starts at the bottom and moves first; against the computer you are Red.",
	"Tap a piece, then the dark square to move to. Pieces move diagonally forward one square.",
	"Jump diagonally over an enemy piece into the empty square behind it to capture it. You can keep jumping in the same turn.",
	"Captures are compulsory: if you can jump, you must.",
	"Reach the far row and your piece is crowned a king, which can move and jump backwards too.",
	"40 moves each with no captures and no ordinary piece moving is a draw.",
	"Tap 🌐 Online on the Home screen to play a friend on another phone with a room code.",
]
const TIPS := [
	"Keep your back row filled for as long as you can — it stops the other side from getting kings.",
	"Pieces on the edges can't be jumped.",
	"Use the compulsory-capture rule to force your opponent into a jump that sets up a double jump for you.",
	"Trade pieces when you're ahead.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "Red wins", "White wins"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"Checkers was solved in 2007: with perfect play from both sides, the game is a draw.",
	"Checkers grew out of alquerque, a much older board game.",
]
