extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "geometry_wars"
const TITLE := "Geometry Wars"
const GOAL := "Survive the swarm of neon shapes and score as many points as you can."
const HOW := [
	"Hold the phone sideways. The left stick moves your ship and the right stick aims and fires.",
	"Shot enemies drop green crystals. Fly over one to raise your score multiplier by 1 — they fade after 3 seconds.",
	"Every kill scores its points times your multiplier.",
	"💣 Bomb wipes out every enemy on screen. You start with 3 and earn another every 2,500 points.",
	"Touching an enemy costs one of your three lives, clears the screen and resets the multiplier.",
	"New enemies join the longer you survive: green weavers dodge your shots, purple pinwheels split in three, yellow darts charge, red hexagons take three hits.",
]
const TIPS := [
	"Keep moving in wide circles — standing still gets you surrounded.",
	"Crystals drift toward you when you're close; sweep through them after a fight.",
	"Save a bomb for when you're cornered.",
]
const STATS := ["Best score", "Longest time survived", "Games played"]
