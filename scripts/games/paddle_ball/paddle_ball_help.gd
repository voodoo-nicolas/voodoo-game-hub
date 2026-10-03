extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "paddle_ball"
const TITLE := "Paddle Ball"
const GOAL := "Get the ball past the computer's paddle. First to 7 points wins."
const HOW := [
	"Slide your finger to move your paddle at the bottom.",
	"Where the ball hits your paddle sets its angle: near the edge sends it off at a sharp angle.",
	"Every hit makes the ball a little faster.",
	"Choose Easy, Medium or Hard for the computer.",
	"⏸ pauses the game. A round can't be saved for later: leaving it ends it.",
]
const TIPS := [
	"Hit the ball with the edge of your paddle to send it at an angle the computer can't reach.",
	"Get back to the middle after each hit.",
	"Watch where the ball will bounce off the walls, not where it is now.",
]
const STATS := ["Wins", "Losses", "Best streak"]
