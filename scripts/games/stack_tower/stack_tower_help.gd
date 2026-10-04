extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "stack_tower"
const TITLE := "Stack Tower"
const GOAL := "Build the tallest tower you can."
const HOW := [
	"A slab slides back and forth above the tower. Tap anywhere to drop it.",
	"Any part that hangs over the slab below is sliced off and falls — so the next slab is narrower.",
	"Line it up almost exactly for a Perfect drop: nothing is sliced. Three perfect drops in a row win back a little width.",
	"Miss the tower completely and the game is over. The slabs slide faster as the tower grows.",
	"⏸ pauses and keeps the tower; Resume on the Home screen carries on.",
]
const TIPS := [
	"Watch the edge of the slab, not its middle: drop when its edge meets the edge below.",
	"Find a rhythm — the slab takes the same time to cross each way.",
	"A narrow tower is fast to miss: chase perfect drops to earn width back.",
]
const STATS := ["Best score", "Most perfect drops in a row", "Games played"]
