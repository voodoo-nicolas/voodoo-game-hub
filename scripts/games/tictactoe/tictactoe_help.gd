extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "tictactoe"
const TITLE := "Tic-Tac-Toe"
const GOAL := "Get three of your marks in a row — across, down or diagonally."
const HOW := [
	"Play the computer (Easy, Medium or Hard) or a friend: on one phone you take turns, X always goes first.",
	"Against the computer you are X and move first.",
	"Tap an empty square to place your mark.",
	"The first to line up three wins. If all nine squares fill up with no line, it's a draw.",
	"Tap 🌐 Online on the Home screen to play a friend on another phone with a room code.",
]
const TIPS := [
	"The centre square is part of four lines — take it if you can.",
	"Corners are the next best: each one is part of three lines.",
	"Always block when your opponent has two in a row.",
	"Win by making two threats at once — they can only block one.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "X wins", "O wins"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"With perfect play from both sides, Tic-Tac-Toe always ends in a draw.",
	"There are 255,168 different possible games of Tic-Tac-Toe.",
]
