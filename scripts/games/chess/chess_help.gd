extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "chess"
const TITLE := "Chess"
const GOAL := "Checkmate your opponent's king: attack it so it has no way to escape."
const HOW := [
	"Play the computer (Easy, Medium or Hard) or a friend on one phone. White moves first; against the computer you are White.",
	"Tap a piece to see where it can go, then tap a highlighted square.",
	"King: one square any way. Queen: any distance in any direction. Rook: straight lines. Bishop: diagonals. Knight: an L-shape, jumping over pieces. Pawn: one square forward (two on its first move), capturing diagonally.",
	"Castling, en passant and pawn promotion are all allowed.",
	"You can never leave your own king in check. No legal move while not in check is stalemate — a draw. So are repeating a position 3 times, 50 moves without a capture or pawn move, and too few pieces to checkmate.",
	"Tap 🌐 Online on the Home screen to play a friend on another phone with a room code.",
]
const TIPS := [
	"Control the centre with your pawns and pieces early on.",
	"Develop your knights and bishops before moving the queen out.",
	"Castle early to keep your king safe.",
	"Before every move, check what your opponent's last move threatens.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "White wins", "Black wins"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"After each player has made just one move, there are already 400 possible positions.",
	"Castling is the only move in which two of your pieces move at once.",
	"A pawn that reaches the far side can become any piece except a king — almost always a queen.",
	"The 50-move rule: after 50 moves each with no capture and no pawn move, a player can claim a draw.",
]
