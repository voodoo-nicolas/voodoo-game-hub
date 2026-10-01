extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "connect4"
const TITLE := "Connect Four"
const GOAL := "Get four of your discs in a row — across, down or diagonally."
const HOW := [
	"Two players share the phone. Red goes first.",
	"Tap a column to drop a disc into it. It falls to the lowest empty spot.",
	"The first to line up four wins. If the board fills up with no line, it's a draw.",
	"Tap 🌐 Play Online to play a friend on another phone with a room code.",
]
const TIPS := [
	"The middle column is part of the most lines — play there early.",
	"Always check whether your opponent can win with their next disc, and block it.",
	"Build threats where your opponent must block — then the disc they drop may give you the spot above.",
	"Don't drop a disc that lets your opponent win in the spot right above it.",
]
const STATS := ["Red wins", "Yellow wins", "Draws"]
