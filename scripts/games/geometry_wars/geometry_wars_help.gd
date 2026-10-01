extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "geometry_wars"
const TITLE := "Geometry Wars"
const GOAL := "Survive the swarm of neon shapes and score as many points as you can."
const HOW := [
	"Hold the phone sideways. The left stick moves your ship and the right stick aims and fires.",
	"Every enemy you shoot is worth 10 points, times your combo multiplier.",
	"Kill enemies within 2 seconds of each other to build a combo: every 5 kills in a row raises the multiplier.",
	"Touching an enemy costs one of your three lives and clears the screen.",
	"Enemies arrive faster the longer you survive.",
]
const TIPS := [
	"Keep moving in wide circles — standing still gets you surrounded.",
	"Stay away from the walls, where you can get trapped.",
	"Your combo resets when you get hit, so staying alive is worth more than a risky kill.",
]
const STATS := ["Best score", "Longest time survived", "Games played"]
