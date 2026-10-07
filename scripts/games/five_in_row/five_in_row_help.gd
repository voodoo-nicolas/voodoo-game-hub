extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "five_in_row"
const TITLE := "Five in a Row"
const GOAL := "Be the first to get five of your stones in an unbroken line — across, down or diagonally."
const HOW := [
	"Black moves first; then the players take turns placing one stone on any empty point of the 15 × 15 grid.",
	"Stones never move and are never taken.",
	"Five or more in a row wins. A gold dot marks the last stone played.",
	"Against the computer you play Black. Pick Easy, Normal or Hard.",
	"Two players can share one phone, or tap 🌐 Online to play a friend on another phone (the host is Black).",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"An open three (three in a row with both ends free) must be blocked at once — or it becomes an unstoppable four.",
	"Build two threats with one stone: your opponent can only block one.",
	"Play near the middle early; stones at the edge have fewer lines through them.",
]
const STATS := ["Wins", "Losses", "Draws", "Best streak", "Wins (Hard)", "Black wins", "White wins", "Online wins"]

## Learning hook (STANDARDS §15): one shows on the Home screen's
## "Did you know?" card. Checked facts only.
const FACTS := [
	"On a 15 × 15 board, computers proved in 1993 that the first player can always win five in a row.",
]
