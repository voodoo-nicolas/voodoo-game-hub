extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "maze_muncher"
const TITLE := "Maze Muncher"
const GOAL := "Eat every dot in the maze without getting caught by the ghosts."
const HOW := [
	"Swipe up, down, left or right anywhere on the screen to steer. A swipe before a corner turns you as soon as the way is open.",
	"Dots are 10 points. The big flashing power dots are 50 — and turn the ghosts blue for a few seconds.",
	"Blue ghosts run away and can be eaten: 200, 400, 800, then 1600 points. Their eyes fly home and they come back.",
	"A ghost that catches you costs a life. You have 3.",
	"The tunnel at the sides takes you across the maze — ghosts slow down in it.",
	"Clear all the dots for the next level: the ghosts get faster and stay blue for less time.",
	"Each ghost hunts its own way: red chases you, pink cuts you off, cyan works with red, orange keeps its distance.",
	"⏸ pauses; Resume on the Home screen keeps your score, lives and the dots left.",
]
const TIPS := [
	"Save the power dots until the ghosts are close — then eat them all.",
	"Ghosts can't turn back on themselves, so a corner is a good place to lose them.",
	"Every now and then the ghosts scatter to their corners: use the gap to clear a crowded area.",
]
const STATS := ["Best score", "Highest level", "Games played"]
