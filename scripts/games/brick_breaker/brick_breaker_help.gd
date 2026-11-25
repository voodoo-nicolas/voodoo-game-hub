extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "brick_breaker"
const TITLE := "Brick Breaker"
const GOAL := "Smash every brick on the wall without letting the ball fall."
const HOW := [
	"Slide your finger to move the paddle, and tap to launch the ball.",
	"Where the ball hits the paddle sets its angle: the edges send it off sideways.",
	"The number on a brick is how many more hits it needs.",
	"Grey steel bricks never break: they guard the others, so find the gap and get behind them.",
	"Bricks cut on a slant send the ball off at an angle.",
	"Miss the ball and you lose one of your three lives.",
	"Clear the wall to move on to a new, tougher one. The ball speeds up as you go.",
	"Reloaded mode: broken bricks drop power-ups. Catch them with the paddle.",
	"↔ wide paddle · ✱ multi-ball · 🔥 fireball smashes through bricks · 💥 explosive ball · ⚡ lasers · ◷ slow-mo · ▬ shield saves one ball · ♥ extra life.",
	"Green ▲ capsules help you. Red ▼ capsules with stripes hurt: dodge the →← (tiny paddle) and » (speed up).",
	"TNT bricks blow up everything around them. Break bricks in a row without touching the paddle for a combo: each one is worth more.",
	"⏸ pauses the game. A round can't be saved for later: leaving it ends it.",
]
const TIPS := [
	"Break through one side and get the ball above the wall — it will clear bricks from behind.",
	"Bricks are worth more points on higher levels.",
	"Keep the paddle under the ball rather than chasing it at the last moment.",
	"In Reloaded, aim for TNT bricks: one hit can clear a whole corner.",
	"On a wide screen the wall is wider too.",
]
const STATS := ["Best score", "Reloaded best", "Highest level", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🧱", "title": "Wall Cracker", "key": "Best score", "at": 300},
	{"id": "goal2", "icon": "💥", "title": "Demolisher", "key": "Best score", "at": 1000},
	{"id": "goal3", "icon": "🏚️", "title": "Wrecking Ball", "key": "Best score", "at": 3000},
	{"id": "goal4", "icon": "⚡", "title": "Reloaded", "key": "Reloaded best", "at": 1500},
	{"id": "goal5", "icon": "💥", "title": "Total Mayhem", "key": "Reloaded best", "at": 6000},
]
