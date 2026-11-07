extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describes what tilt_maze_game.gd / tilt_maze_engine.gd actually do.

const ID := "tilt_maze"
const TITLE := "Tilt Maze"
const GOAL := "Tilt the phone to roll the marble through the maze into the green goal hole."
const HOW := [
	"Hold the phone the way you like when a maze starts: that is level. Tilt it to roll the marble.",
	"◎ recentres the tilt whenever you change how you hold the phone.",
	"A dark hole swallows the marble and sends it back to the start. The clock keeps running.",
	"Some holes fill dead ends, some sit in the outer corner of a bend (take it on the inside), some on one side of a straight (keep to the other side).",
	"Campaign: 195 mazes in six tiers: Very Easy, Easy, Medium, Hard, Very Hard and Insane, 30 each.",
	"After every 10 mazes comes a ⚡ challenge maze from the next tier, a taste of what is coming.",
	"Stars: 3 for no falls within the par time, 2 for at most one fall within 1.6 times par, 1 for getting there.",
	"No motion sensor? Choose the touch joystick in ⚙ Options: drag anywhere on the maze. Arrow keys work on a keyboard.",
	"💡 draws the safe way to the goal for a few seconds. You hold up to 3 hints; one comes back every 24 hours.",
	"📅 Daily Maze: one maze a day, the same for everyone; easier early in the week, Insane on Saturday.",
	"🛒 Marble Shop: clearing a maze earns coins (more for stars and for no falls; the Daily Maze pays once a day). Spend them on new marbles and effects. Coins are earned only, never sold.",
]
const TIPS := [
	"Small tilts. The marble keeps rolling, so tilt back a little before a bend.",
	"Insane mazes are slippery: the marble slows down much less.",
	"Hitting a wall on purpose is a good way to stop next to a hole.",
	"If the marble rolls the wrong way, flip left-right or up-down in ⚙ Options.",
]
## Counting stats earn generic badges; keep them few (1000-point cap, STANDARDS §3b).
const STATS := ["Mazes cleared", "Campaign stars", "Clean runs", "Highest maze cleared", "Highest tier reached", "Longest daily streak"]

## Goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "tier_easy", "icon": "🟢", "title": "Steady Hands", "key": "Highest tier reached", "at": 2},
	{"id": "tier_medium", "icon": "🔵", "title": "Rolling Along", "key": "Highest tier reached", "at": 3},
	{"id": "tier_hard", "icon": "🟠", "title": "Hole Dodger", "key": "Highest tier reached", "at": 4},
	{"id": "tier_vhard", "icon": "🔴", "title": "Tightrope", "key": "Highest tier reached", "at": 5},
	{"id": "tier_insane", "icon": "🟣", "title": "Marble Wizard", "key": "Highest tier reached", "at": 6},
	{"id": "all195", "icon": "🏆", "title": "Tilt Master", "key": "Highest maze cleared", "at": 195},
	{"id": "clean50", "icon": "🎯", "title": "Never Dropped", "key": "Clean runs", "at": 50},
	{"id": "daily7", "icon": "📅", "title": "Week of Marbles", "key": "Longest daily streak", "at": 7},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"Your phone tells which way is down with its accelerometer: held still, it measures gravity along three axes.",
	"A rolling marble keeps going until friction or a wall stops it: Newton's first law of motion.",
	"On a gentle slope, a ball speeds up at a rate proportional to the sine of the slope's angle.",
]
