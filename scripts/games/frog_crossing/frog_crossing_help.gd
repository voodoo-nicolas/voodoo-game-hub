extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "frog_crossing"
const TITLE := "Frog Crossing"
const GOAL := "Get your frog across the road and the river into all five homes at the top."
const HOW := [
	"Swipe (or use the arrow keys) to hop one square up, down, left or right.",
	"On the road, dodge the cars. On the river, ride the logs — the water is deadly.",
	"Each life has 30 seconds. Getting hit, falling in or running out of time costs a life.",
	"Fill all five homes to reach the next, faster level. You have three lives.",
]
const TIPS := [
	"Every new row you reach is 10 points; a home is worth 50 plus a bonus for the time left.",
	"Wait on the grass strip in the middle to time the river.",
	"Logs carry you sideways — don't ride one off the edge of the screen.",
]
const STATS := ["Best score", "Highest level", "Games played"]
