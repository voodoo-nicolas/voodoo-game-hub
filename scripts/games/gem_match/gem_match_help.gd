extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "gem_match"
const TITLE := "Gem Match"
const GOAL := "Score as many points as you can in 30 moves."
const HOW := [
	"Swap two neighbouring gems to line up three or more of the same kind.",
	"Matched gems clear, the gems above fall down and new ones drop in from the top.",
	"Only swaps that make a match are allowed, and each one uses a move.",
	"Falling gems that make new matches are a chain, and chains score extra.",
	"💡 Hint shows you a swap that works.",
]
const TIPS := [
	"Lines of 4 or 5 score a big bonus.",
	"Make matches near the bottom: more gems fall, so more chains happen.",
	"Look over the whole board before each move — you only have 30.",
]
const STATS := ["Best score", "Games played"]
