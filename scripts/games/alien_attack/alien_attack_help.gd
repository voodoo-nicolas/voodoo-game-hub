extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "alien_attack"
const TITLE := "Alien Attack"
const GOAL := "Shoot down the marching aliens before they reach the bottom."
const HOW := [
	"Slide your finger left and right to move the cannon. It fires by itself.",
	"The aliens march side to side and step down each time they reach an edge.",
	"Dodge their falling bombs — a hit costs one of your three lives.",
	"Clear the whole wave and a faster one arrives.",
	"Game over when you run out of lives or the aliens reach the bottom.",
	"⏸ pauses the game. A round can't be saved for later: leaving it ends it.",
]
const TIPS := [
	"Aliens in the top rows are worth more points.",
	"Clear out a whole column at the edge: the wave takes longer to reach the side and step down.",
	"Keep moving — standing still under the wave is how bombs find you.",
]
const STATS := ["Best score", "Highest wave", "Games played"]
