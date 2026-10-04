extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "barrel_climb"
const TITLE := "Barrel Climb"
const GOAL := "Climb all six girders and reach the voodoo doll at the top, dodging the barrels the Bone King throws at you."
const HOW := [
	"Hold ◀ ▶ to run. Stand at a ladder and hold ▲ to climb up or ▼ to climb down.",
	"Tap ⤒ to jump. Jumping over a barrel scores 100.",
	"Barrels roll down each girder, drop off its open end onto the one below, and sometimes come down a ladder. One touch costs a life — you have 3.",
	"Grab the 🔨 hammer to smash barrels for 300 each for a few seconds. With the hammer you can't climb or jump.",
	"The BONUS counts down while you climb. Reaching the top adds what's left to your score; if it reaches 0 you lose a life.",
	"Each level the barrels get faster, come more often and take the ladders more. Easy, Normal and Hard set how fast it starts.",
	"⏸ pauses; Resume on the Home screen keeps your score, level and lives and restarts the level from the bottom.",
]
const TIPS := [
	"Wait under a ladder for a gap, then climb — a barrel can't hit you once you're above its girder.",
	"Barrels on a ladder come straight down: never wait at the foot of one that's in use.",
	"Jump early rather than late: you clear a barrel on the way up, not on the way down.",
]
const STATS := ["Best score", "Highest level", "Levels cleared", "Barrels jumped", "Barrels smashed", "Games played"]
