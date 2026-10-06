extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "maze_muncher"
const TITLE := "Maze Muncher"
const GOAL := "Eat every dot in the maze without getting caught by the spirits."
const HOW := [
	"Swipe up, down, left or right anywhere on the screen to steer. A swipe before a corner turns you as soon as the way is open.",
	"Dots are 10 points. The big flashing power dots are 50 — and scare the spirits for a few seconds.",
	"Scared spirits go pale, run away and can be eaten: 200, 400, 800, then 1600 points. Their eyes fly home and they come back.",
	"A spirit that catches you costs a life. You have 3.",
	"The tunnel at the sides takes you across the maze — spirits slow down in it.",
	"Clear all the dots for the next level: the spirits get faster and stay scared for less time.",
	"Each spirit hunts its own way: green chases you, violet cuts you off, blue works with green, bone-white keeps its distance.",
	"⏸ pauses; Resume on the Home screen keeps your score, lives and the dots left.",
]
const TIPS := [
	"Save the power dots until the spirits are close — then eat them all.",
	"Spirits can't turn back on themselves, so a corner is a good place to lose them.",
	"Every now and then the spirits scatter to their corners: use the gap to clear a crowded area.",
]
const STATS := ["Best score", "Highest level", "Games played"]
