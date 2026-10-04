extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "moon_lander"
const TITLE := "Moon Lander"
const GOAL := "Land on the green pads, gently and upright, as many times as you can."
const HOW := [
	"Hold ⟲ or ⟳ to tilt the lander. Hold 🔥 to fire the engine: it pushes the way the nose points and burns fuel.",
	"Gravity always pulls you down. Without fuel the engine stops.",
	"To land safely: on a green pad, falling slower than 42, sliding slower than 26 and tilted less than about 12°. The numbers turn green when they're safe.",
	"Narrow pads pay more: ×2, ×3 and ×5. Fuel left over and a soft touchdown add to the score.",
	"Each landing brings new mountains, a little less fuel and a little more gravity. A crash costs one of your 3 landers.",
	"⏸ pauses; Resume on the Home screen keeps your score, level and landers, and starts a fresh descent.",
]
const TIPS := [
	"Use short bursts of the engine — long burns waste fuel and shoot you upwards.",
	"Kill your sideways speed first, high up, then come straight down over the pad.",
	"Straighten up just before touchdown: the tilt counts as much as the speed.",
]
const STATS := ["Best score", "Highest level", "Landings", "Landings on ×5 pads", "Games played"]
