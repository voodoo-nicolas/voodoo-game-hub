extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "mini_golf"
const TITLE := "Mini Golf"
const GOAL := "Sink the ball in every hole in as few strokes as you can."
const HOW := [
	"Touch anywhere on the green and pull back, like a slingshot: the dotted line shows where the ball will go and the bar how hard. Let go to putt. Pull back to where you started to cancel.",
	"Each hole has a par: the number of strokes a good round takes. Under par is a birdie (1 under), an eagle (2 under) or better.",
	"Bumpers bounce the ball away hard. Windmill blades and sliding gates knock it around — time your putt.",
	"Sand slows the ball right down. Slopes (the moving arrows) push it. Water sends it back to where you putted from, with a stroke added.",
	"A ball going too fast skips over the cup. After 8 strokes the ball is picked up.",
	"Pick a course on the Home screen: Front 9, Back 9 or all 18 holes. With 2-4 players, each plays the hole in turn on the same phone; lowest total wins.",
	"📋 shows the scorecard. ⏸ pauses; Resume on the Home screen carries on the round where the ball lies.",
]
const TIPS := [
	"Gentle wins: a ball that just reaches the cup drops in; one that races past may lip out.",
	"Use the walls — banking off a wall is often the only way round a corner.",
	"Watch a windmill go round once before you putt through it.",
]
const STATS := ["Best round (Front 9)", "Best round (Back 9)", "Best round (18 holes)", "Best vs par", "Holes in one", "Birdies or better", "Rounds played", "Multiplayer rounds"]
