extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "city_defense"
const TITLE := "City Defense"
const GOAL := "Protect your six cities from falling missiles for as many waves as you can."
const HOW := [
	"Tap anywhere in the sky. The nearest base with ammo fires an interceptor that bursts into a fireball where you tapped.",
	"Any missile that touches a fireball is destroyed — and explodes, which can catch more missiles. Each one is 25 points.",
	"Aim ahead of a missile: the fireball needs a moment to reach its full size.",
	"Each base has 10 shots per wave. A missile that lands on a base wipes out its remaining shots for that wave.",
	"From wave 3, some missiles split into two on the way down.",
	"After each wave, every city left and every unused shot earns a bonus. Every 10,000 points rebuilds a ruined city.",
	"The game ends when the last city falls. ⏸ pauses; Resume on the Home screen restarts the wave you were on, with your cities and score.",
]
const TIPS := [
	"One well-placed fireball in the middle of a group beats three rushed shots.",
	"Use the base closest to the missile: its interceptor arrives sooner.",
	"Save a few shots for the end of the wave — that's when the fast ones come.",
]
const STATS := ["Best score", "Highest wave", "Games played"]
