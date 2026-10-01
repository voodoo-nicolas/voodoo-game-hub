extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "bird_hop"
const TITLE := "Bird Hop"
const GOAL := "Fly through as many gaps between the pillars as you can."
const HOW := [
	"Tap anywhere (or press Space) to flap. Gravity pulls you down between taps.",
	"Every pillar you pass is one point.",
	"Touching a pillar or the ground ends the run.",
]
const TIPS := [
	"Short, gentle taps work better than frantic ones.",
	"Aim for the middle of each gap, and get lined up early for the next one.",
	"Look at the next gap, not at the bird.",
]
const STATS := ["Best score", "Games played"]
