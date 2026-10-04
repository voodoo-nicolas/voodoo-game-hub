extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sky_hop"
const TITLE := "Sky Hop"
const GOAL := "Hop from platform to platform and climb as high as you can."
const HOW := [
	"The hopper bounces by itself every time it lands on a platform.",
	"Hold the left or right half of the screen to steer. Go off one side and you come back on the other.",
	"Cyan platforms are solid. Purple ones slide back and forth. Pink ones crumble the moment you land on them. Green springs launch you extra high.",
	"The higher you go, the further apart the platforms are. Fall off the bottom of the screen and the game is over.",
	"Your score is the highest point you reached.",
	"⏸ pauses and keeps the climb; Resume on the Home screen carries on.",
]
const TIPS := [
	"Steer while you're still going up — by the time you're falling it can be too late.",
	"Use the wrap-around: a platform on the far edge is often closer the other way round.",
	"Never count on a pink platform; there's always a safe one near it.",
]
const STATS := ["Best score", "Games played"]
