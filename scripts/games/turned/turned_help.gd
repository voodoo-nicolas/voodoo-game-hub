extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Written from the game's code (turned_world.gd, turned_hud.gd, turned_engine.gd): the first
## slice, Prologue and Day 1. No learning hook: a gothic story has no natural one (STANDARDS §15).

const ID := "turned"
const TITLE := "Turned"
const GOAL := "1900. You wake up thirsty, with two marks on your neck. Find out what happened, and stay out of the sun."
const HOW := [
	"Hold the phone sideways. The stick (lower left) walks: push it any way you like. A (lower right) says what it does: Examine, Read, Take, Talk, Go in.",
	"At first only A works. Follow what it says; the stick comes when you are ready to walk.",
	"Search the bedroom for clues. Each one goes in the Journal (the Menu button, bottom middle). Look at yourself in the bathroom mirror.",
	"Outside, the sun burns you: your Health (red bar) drops. Stand in shade (awnings, trees, the alley, any building) and it slowly comes back.",
	"If Health runs out you wake in the nearest shade with half your Health back and a quarter of your Blood gone.",
	"Villagers talk when you press A near them. Some know more than they say.",
	"In the alley something new wakes up: B toggles Sneak. You walk slower and quieter, and the rings around you show how far you can be noticed.",
	"The game saves when you leave the house, in the alley, and every time you pause. ▶ Resume starts from there.",
	"Keyboard: arrows or WASD walk, E is A, Shift is B, Esc pauses, Tab opens the Menu.",
]
const TIPS := [
	"Plan your route from shade to shade. The porch, the awnings and the trees are all on the way.",
	"Inside a house the sun cannot reach you. Your own front door is always open.",
	"A scarf by the front door hides the marks from people who do not already know.",
	"Everyone in the street has something to say. Press A near them.",
]
const STATS := ["Times died", "Clues found"]
