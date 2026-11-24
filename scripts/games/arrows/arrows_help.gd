extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## TITLE is the working title (name check pending, see the game's notes); the id "arrows" never changes.

const ID := "arrows"
const TITLE := "Arrows"
const GOAL := "Clear the board: tap the arrows one by one so each slides out without hitting another."
const HOW := [
	"Tap an arrow. It slides forward the way its head points, and its body follows.",
	"If nothing is between its head and the edge, it leaves the board. If another arrow is in the way, it bumps back, turns red and you lose a heart.",
	"You have 3 hearts per board. Lose all 3 and you can use a ❤ help or try the board again.",
	"Pinch with two fingers to zoom in on big boards, and drag with one finger to look around. ⤢ Fit shows the whole board again.",
	"💡 Hint makes one arrow that can leave right now blink.",
	"Classic: levels that grow bigger and more tangled, in all kinds of pictures. Stars = hearts left. Daily: one picture a day, the same for everyone. Zen: endless random boards.",
]
const TIPS := [
	"Follow the line in front of an arrow's head all the way to the edge before you tap.",
	"Arrows on the outside pointing outward are usually free.",
	"When you're stuck, look for the arrow that blocks the most others and free it first.",
]
const STATS := ["Puzzles solved", "Perfect boards", "Daily streak"]

const ACHIEVEMENTS := [
	{"id": "solved5", "icon": "➡️", "title": "Way Out", "desc": "Clear 5 boards", "key": "Puzzles solved", "at": 5},
	{"id": "solved50", "icon": "🏹", "title": "Arrow Master", "desc": "Clear 50 boards", "key": "Puzzles solved", "at": 50},
	{"id": "perfect10", "icon": "🎯", "title": "Never Bumped", "desc": "Clear 10 boards without losing a heart", "key": "Perfect boards", "at": 10},
	{"id": "pack1", "icon": "⭐", "title": "Full Pack", "desc": "Earn all 90 stars in the first 30 Classic levels", "key": "Classic stars", "at": 90},
	{"id": "big100", "icon": "🧶", "title": "Big Knot", "desc": "Clear a board with 100 arrows or more", "key": "Most arrows cleared", "at": 100},
	{"id": "daily7", "icon": "📅", "title": "Arrow a Day", "desc": "Clear the Daily 7 days in a row", "key": "Daily streak", "at": 7},
]

## Learning hook (STANDARDS §15): the order you clear arrows in is a dependency order.
const FACTS := [
	"Clearing the arrows is a topological sort: each arrow must leave after every arrow in its way, the same idea computers use to order tasks that depend on each other.",
	"If two arrows block each other, neither can ever leave. Every board here is built so that never happens.",
]
