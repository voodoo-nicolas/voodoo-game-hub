extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "rock_blaster"
const TITLE := "Rock Blaster"
const GOAL := "Blast the space rocks for points and survive as many waves as you can."
const HOW := [
	"Tap anywhere: your ship turns that way and fires one shot.",
	"Touch and hold: the ship turns towards your finger, flies that way and keeps firing. Let go to drift.",
	"Big rocks split into two medium ones, medium into two small; small ones turn to dust. Big 20, medium 50, small 100 points.",
	"The field wraps around: fly off one edge and you come back on the other — and so do the rocks.",
	"A rock that hits your ship costs a life. You start with 3 and get one more every 10,000 points. A new ship blinks for a moment and can't be hit.",
	"Clear every rock for the next wave: more rocks, a little faster each time.",
	"⏸ pauses and keeps the game; Resume on the Home screen carries on.",
]
const TIPS := [
	"Small rocks are fast and worth the most — finish them before splitting another big one.",
	"Short taps are safer than flying: stay near the middle and let the rocks come to you.",
	"Watch the edges: a rock leaving one side is about to appear on the other.",
]
const STATS := ["Best score", "Highest wave", "Games played"]
