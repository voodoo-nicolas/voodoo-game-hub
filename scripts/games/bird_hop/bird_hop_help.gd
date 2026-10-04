extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "bird_hop"
const TITLE := "Bird Hop"
const GOAL := "Fly through as many gaps between the pillars as you can."
const HOW := [
	"Tap anywhere (or press Space) to flap. Gravity pulls you down between taps.",
	"Every pillar you pass is one point.",
	"Touching a pillar or the ground ends the run.",
	"⏸ pauses the game. A round can't be saved for later: leaving it ends it.",
]
const TIPS := [
	"Short, gentle taps work better than frantic ones.",
	"Aim for the middle of each gap, and get lined up early for the next one.",
	"Look at the next gap, not at the bird.",
]
const STATS := ["Best score", "Games played"]

## Score goals (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🐣", "title": "Fledgling", "key": "Best score", "at": 10},
	{"id": "goal2", "icon": "🐦", "title": "High Flyer", "key": "Best score", "at": 25},
	{"id": "goal3", "icon": "🦅", "title": "Sky King", "key": "Best score", "at": 50},
]
