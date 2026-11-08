extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Describes what maze_trail_game.gd / maze_trail_engine.gd actually do.

const ID := "maze_trail"
const TITLE := "Maze Trail"
const GOAL := "Walk from the start to the exit flag in as few steps as you can."
const HOW := [
	"Drag your finger along the paths: you walk to the cell under your finger when it is a few steps away.",
	"Swipe quickly to run: you keep going down the corridor until the next turning, dead end or key.",
	"Campaign: 195 mazes in six tiers: Very Easy, Easy, Medium, Hard, Very Hard and Insane, 30 each.",
	"After every 10 mazes comes a ⚡ challenge maze from the next tier, a taste of what is coming.",
	"From Medium on, some mazes have gates. A gate opens only after you pick up the key of its colour.",
	"Very Hard and Insane mazes may be in fog: you only see what is near you and where you have been.",
	"Stars: 3 if your steps are within 30% of the best route, 2 within about twice it, 1 for any way out.",
	"💡 shows the next stretch of the way. You hold up to 3 hints; one comes back 24 hours after the last one you used.",
	"📅 Daily Maze: one maze a day, the same for everyone; easier early in the week, Insane on Saturday.",
]
const TIPS := [
	"Stuck? Follow one wall with your hand, so to speak: in these mazes it always leads out.",
	"Look ahead from the exit back towards you: dead ends are easier to spot from the far side.",
	"Gates sit on the only way out, so the key is always somewhere you can already reach.",
	"Your trail shows where you have been. Walking back over it shortens it again.",
]
## Counting stats earn generic badges; keep them few (1000-point cap, STANDARDS §3b).
const STATS := ["Mazes solved", "Campaign stars", "Perfect routes", "Highest maze cleared", "Highest tier reached", "Longest daily streak", "Fastest maze (seconds)"]

## Goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "tier_easy", "icon": "🌱", "title": "Out of the Garden", "key": "Highest tier reached", "at": 2},
	{"id": "tier_medium", "icon": "🧭", "title": "Pathfinder", "key": "Highest tier reached", "at": 3},
	{"id": "tier_hard", "icon": "🗝", "title": "Gatekeeper", "key": "Highest tier reached", "at": 4},
	{"id": "tier_vhard", "icon": "🌫", "title": "Into the Fog", "key": "Highest tier reached", "at": 5},
	{"id": "tier_insane", "icon": "🌀", "title": "Insane Walker", "key": "Highest tier reached", "at": 6},
	{"id": "all195", "icon": "🏆", "title": "Maze Master", "key": "Highest maze cleared", "at": 195},
	{"id": "perfect50", "icon": "🎯", "title": "No Wrong Turns", "key": "Perfect routes", "at": 50},
	{"id": "daily7", "icon": "📅", "title": "Week of Mazes", "key": "Longest daily streak", "at": 7},
]

## Learning hook (STANDARDS §15): checked facts only.
const FACTS := [
	"In a maze with no loops and its exit on the outer wall, keeping one hand on the same wall always leads you out.",
	"A maze with exactly one route between any two points is called a perfect maze. Every Maze Trail maze is one.",
	"Hedge mazes became popular in European gardens in the 16th and 17th centuries.",
]
