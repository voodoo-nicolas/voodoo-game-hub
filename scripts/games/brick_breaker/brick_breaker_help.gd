extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "brick_breaker"
const TITLE := "Brick Breaker"
const GOAL := "Smash every brick on the wall without letting the ball fall."
const HOW := [
	"Slide your finger to move the paddle, and tap to launch the ball.",
	"Where the ball hits the paddle sets its angle: the edges send it off sideways.",
	"Darker bricks take two hits.",
	"Miss the ball and you lose one of your three lives.",
	"Clear the wall to move on to a new, tougher one. The ball speeds up as you go.",
]
const TIPS := [
	"Break through one side and get the ball above the wall — it will clear bricks from behind.",
	"Bricks are worth more points on higher levels.",
	"Keep the paddle under the ball rather than chasing it at the last moment.",
]
const STATS := ["Best score", "Highest level", "Games played"]
