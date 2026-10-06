extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "sky_raider"
const TITLE := "Sky Strike"
const GOAL := "Fight your way through as many stages as you can and sink each stage's battleship."
const HOW := [
	"Slide a finger anywhere on the screen to move your fighter — it follows your finger's movement, so your finger never hides it (arrow keys on a PC). The guns fire on their own.",
	"Only the white dot in the middle of your fighter can be hit. A bullet there, or crashing into a plane, costs a life — you have 3 — and one level of guns.",
	"Darts swoop down in lines (100). Gunships stop and fire spreads (300). Turrets on the islands aim at you (250). Big bombers fire rings of bullets (900).",
	"Shot-down planes drop power-ups: P makes your guns wider (up to 4 levels), B gives a bomb, 1UP an extra life.",
	"💣 Bomb wipes every bullet off the screen and blasts every plane. You start with 2.",
	"After about a minute the battleship arrives. Below half its armour it fires rings of bullets. Sink it to clear the stage.",
	"⏸ pauses; Resume on the Home screen keeps your score, lives, bombs and guns and restarts that stage.",
]
const TIPS := [
	"Small moves dodge best: bullets are aimed where you are now.",
	"Stay low on the screen — you have more time to see bullets coming.",
	"Use a bomb before you get hit, not after: losing a life also costs a level of guns.",
]
const STATS := ["Best score", "Highest stage", "Planes shot down", "Battleships sunk", "Bombs used", "Games played"]
