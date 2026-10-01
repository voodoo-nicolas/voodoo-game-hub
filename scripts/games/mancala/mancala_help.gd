extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "mancala"
const TITLE := "Mancala"
const GOAL := "Collect more seeds in your store than your opponent."
const HOW := [
	"Two players share the phone. Player 1 owns the bottom row of pits and the store on the right; Player 2 the top row and the store on the left.",
	"On your turn, tap one of your pits. Its seeds are sown one at a time into the following pits, counter-clockwise, including your own store but never your opponent's.",
	"If your last seed lands in your store, you get another turn.",
	"If your last seed lands in an empty pit on your side, you capture it and every seed in the pit directly opposite.",
	"The game ends when one side is empty; the other player collects their remaining seeds.",
	"Tap 🌐 Play Online to play a friend on another phone with a room code.",
]
const TIPS := [
	"Look for a pit whose seed count reaches your store exactly — a free extra turn.",
	"Pits close to your store are best for extra turns; use them first.",
	"Watch for captures — yours and your opponent's. Keep an eye on your empty pits.",
]
const STATS := ["Player 1 wins", "Player 2 wins", "Draws"]
