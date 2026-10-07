extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sky_raider"
const TITLE := "Sky Strike"
const GOAL := "Fight your way through as many stages as you can and sink each stage's battleship."
const HOW := [
	"Slide a finger anywhere on the screen to move your fighter — it follows your finger's movement, so your finger never hides it (arrow keys on a PC). The guns fire on their own.",
	"Only the white dot in the middle of your fighter can be hit. A bullet there, or crashing into a plane or an island, costs a life — you have 3 — and all your gun power: you're back to one level.",
	"The blue islands are solid ground: steer around them. One you crash into goes dark and can't hurt you again.",
	"Darts swoop down in lines (100). Gunships stop and fire spreads (300). Turrets on the islands aim at you (250). Big bombers fire rings of bullets (900).",
	"Shot-down planes drop power-ups: P makes your guns wider (up to 4 levels), B gives a bomb, 1UP an extra life.",
	"💣 Bomb wipes every bullet off the screen and blasts every plane. You start with 2 (1 on Hard).",
	"After about a minute the battleship arrives. Each one is tougher than the last: more armour, faster guns, and new attacks each time its armour passes a mark on its bar — streams, spirals, walls of bullets with one gap, escorts. When a red line blinks, get off it: the battleship slides over and fires a laser down it. Sink it to clear the stage.",
	"Hard: faster and thicker fire, more islands and turrets, fewer drops, one bomb, and tougher battleships.",
	"⏸ pauses; Resume on the Home screen keeps your score, lives, bombs and guns and restarts that stage. 🎵 Music: ⚙ Options → Sound.",
]
const TIPS := [
	"Small moves dodge best: bullets are aimed where you are now.",
	"Stay low on the screen — you have more time to see bullets coming.",
	"Use a bomb before you get hit, not after: losing a life costs all your gun power.",
	"Look for the gap in a wall of bullets as soon as it appears.",
]
const STATS := ["Best score", "Highest stage", "Planes shot down", "Battleships sunk", "Bombs used", "Games played"]
const ACHIEVEMENTS := [
	{"id": "stage3", "icon": "🛩", "title": "Wingman", "key": "Highest stage", "at": 3},
	{"id": "stage5", "icon": "✈️", "title": "Ace Pilot", "key": "Highest stage", "at": 5},
	{"id": "stage8", "icon": "🚀", "title": "Sky Legend", "key": "Highest stage", "at": 8},
]
