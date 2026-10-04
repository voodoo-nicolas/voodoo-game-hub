extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "memory"
const TITLE := "Memory"
const GOAL := "Find all the matching pairs of cards in as few moves as you can."
const HOW := [
	"All cards start face down. Tap two cards to turn them over.",
	"If they match, they stay face up. If not, they turn back over.",
	"Every pair of cards you turn over counts as one move.",
	"Two players: take turns flipping; find a pair and you go again. Most pairs wins.",
	"Tap 🌐 Online on the Home screen to play a friend on another phone with a room code.",
	"⏸ pauses and keeps the board; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Always turn over a card you haven't seen yet first — then you might already know where its partner is.",
	"Remember cards by their position: say them to yourself, like \"star, top left\".",
	"Work through the board in order, row by row.",
]
const STATS := ["Games solved", "Fewest moves", "2-player games", "Online wins"]
