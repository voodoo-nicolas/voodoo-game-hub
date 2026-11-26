extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "chess"
const TITLE := "Chess"
const GOAL := "Checkmate your opponent's king: attack it so it has no way to escape."
const HOW := [
	"Play the computer (Easy, Medium or Hard) or a friend on one phone. White moves first; against the computer you are White.",
	"Tap a piece to see where it can go, then tap a highlighted square. Or drag the piece there.",
	"King: one square any way. Queen: any distance in any direction. Rook: straight lines. Bishop: diagonals. Knight: an L-shape, jumping over pieces. Pawn: one square forward (two on its first move), capturing diagonally.",
	"Castling, en passant and pawn promotion are all allowed.",
	"You can never leave your own king in check. No legal move while not in check is stalemate — a draw. So are repeating a position 3 times, 50 moves without a capture or pawn move, and too few pieces to checkmate.",
	"Clock: pick one on the setup screen. 3+2 means 3 minutes each, and 2 seconds are added after each of your moves. Run out of time and you lose, unless your opponent has nothing left that could checkmate: then it's a draw.",
	"Under the board: ⟲ Undo takes back a move (against the computer: your move and its answer; turn it off in ⚙ Options), ½ Draw offers a draw, 🏳 Resign gives up, ⇅ Flip turns the board round, 📋 Copy copies the game (PGN) or the position (FEN).",
	"A game with a takeback doesn't change your rating or earn points. The computer accepts a draw only when it stands worse, or late in an even game.",
	"♟ Ongoing Games keeps up to 6 games against the computer or on one phone. Starting a new game keeps the others; ▶ Resume opens the last one you played. When all 6 are in use, a new game asks which one to replace.",
	"📮 Daily Games: challenge a friend to a game played one move at a time, whenever you like (1, 3 or 7 days a move). Up to 10 at once. Miss your deadline and your friend can claim the win. Needs an account and friends.",
	"📜 My Games keeps your last 50 finished games: replay them move by move. Paste a PGN to replay a game from another app, or a FEN to play from that position.",
	"📚 Lessons teach each piece, the rules and checkmate on short boards. 📅 Daily Lesson gives three new boards every day. Lessons aren't saved halfway: a board starts again.",
	"Solving lesson boards (the first time), the daily lesson and beating the computer earn ⭐ points. Spend them in the 🛒 Shop on new boards and piece sets.",
	"Around the board: names and ratings, captured pieces with the material lead (+3 = three pawns' worth ahead), clocks, the move list in chess notation, and the evaluation bar. Turn each on or off in ⚙ Options.",
	"Your rating starts at 1200 and moves after every game against the computer.",
	"Tap 🌐 Online on the Home screen to play a friend on another phone with a room code.",
]
const TIPS := [
	"Control the centre with your pawns and pieces early on.",
	"Develop your knights and bishops before moving the queen out.",
	"Castle early to keep your king safe.",
	"Before every move, check what your opponent's last move threatens.",
	"Count the material: a queen is worth 9 pawns, a rook 5, a bishop or knight 3.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "White wins", "Black wins",
	"Lessons solved", "Daily lessons", "Points earned"]
## Owner 2026-11-08 (STANDARDS §3b, 1000 points per game): these counters get no tier
## badges (app v0.40+; badges already earned keep their XP).
const NO_TIER_BADGES := ["Points earned"]

const ACHIEVEMENTS := [
	{"id": "lessons10", "icon": "🎓", "title": "Good Student", "key": "Lessons solved", "at": 10},
	{"id": "lessons43", "icon": "📜", "title": "Rule Master", "key": "Lessons solved", "at": 43},
	{"id": "daily7", "icon": "📅", "title": "Daily Habit", "key": "Daily lessons", "at": 7},
	{"id": "points500", "icon": "⭐", "title": "Collector", "key": "Points earned", "at": 500},
]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"After each player has made just one move, there are already 400 possible positions.",
	"Castling is the only move in which two of your pieces move at once.",
	"A pawn that reaches the far side can become any piece except a king — almost always a queen.",
	"The 50-move rule: after 50 moves each with no capture and no pawn move, a player can claim a draw.",
	"\"En passant\" is French for \"in passing\": the pawn is captured as it passes by.",
	"Chess notation names each square by its file (a–h) and rank (1–8): e4 is the e-file, fourth rank.",
]
