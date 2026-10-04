extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "air_hockey"
const TITLE := "Air Hockey"
const GOAL := "Score 7 goals before your opponent does."
const HOW := [
	"Drag your mallet anywhere in your half of the table and hit the puck into the other goal.",
	"Against the computer you're at the bottom (cyan). Pick Easy, Normal or Hard.",
	"Two players: hold the phone flat between you. Bottom player is cyan, top player is pink — both can drag at the same time.",
	"Faster swings send the puck faster. It bounces off the side walls.",
	"After a goal, the player who conceded gets the puck.",
	"A match is short, so it isn't saved: ⏸ pauses it, but leaving ends it.",
]
const TIPS := [
	"Bank shots off the side walls get past a defender in the middle.",
	"Stay between the puck and your goal when it's in your half.",
	"Don't chase too far forward — a rebound can fly straight into your goal.",
]
const STATS := ["Wins", "Losses", "Best streak", "Wins (Hard)", "2-player games"]
