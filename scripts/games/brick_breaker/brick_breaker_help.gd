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
	"⏸ pauses the game. A round can't be saved for later: leaving it ends it.",
]
const TIPS := [
	"Break through one side and get the ball above the wall — it will clear bricks from behind.",
	"Bricks are worth more points on higher levels.",
	"Keep the paddle under the ball rather than chasing it at the last moment.",
]
const STATS := ["Best score", "Highest level", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🧱", "title": "Wall Cracker", "key": "Best score", "at": 300},
	{"id": "goal2", "icon": "💥", "title": "Demolisher", "key": "Best score", "at": 1000},
	{"id": "goal3", "icon": "🏚️", "title": "Wrecking Ball", "key": "Best score", "at": 3000},
]
