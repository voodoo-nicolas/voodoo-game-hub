extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "snake"
const TITLE := "Snake"
const GOAL := "Eat as much food as you can without crashing."
const HOW := [
	"Swipe anywhere on the screen to steer (arrow keys work too). The snake keeps moving on its own.",
	"Each piece of food makes you longer and scores a point.",
	"Running into a wall or your own body ends the game.",
	"Versus (2 players, the computer or online): run into the other snake's body and you're out — so trap them against your side! Two heads meeting is a draw.",
	"2 players on one phone: green swipes on the bottom half, blue on the top half.",
	"Fill the entire board and you win!",
	"⏸ pauses the game (not online). A round you leave is kept: Resume on the Snake screen picks it up, and the snake waits for your first swipe.",
]
const TIPS := [
	"Go around the edges in wide loops rather than zig-zagging through the middle.",
	"One long drag can make several turns — keep your finger down.",
	"In versus, cut across in front of your opponent so they have nowhere to go.",
]
const STATS := ["Best score", "Games played", "Wins", "Losses", "Online wins", "Online losses"]
