extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "star_runner"
const TITLE := "Star Runner"
const GOAL := "Fly as far as you can through the stages and score as much as you can on the way."
const HOW := [
	"Drag anywhere on the screen to steer the ship (arrow keys on a PC). It flies forward and fires on its own, straight ahead at the green sight.",
	"Fighters come in squadrons and shoot back: 100 each. Aces chase you and take 4 hits: 250. Rocks take 3 hits: 60.",
	"Glowing towers can't be shot: fly through the gap or over them. Green rings give 50 points and 15 shield.",
	"Getting hit drains your shield. When it's empty you lose a ship — you have 3.",
	"💣 Bomb clears everything ahead and wounds the boss. You get 3, and one more after every stage (up to 5).",
	"After about 50 seconds the stage's boss arrives. Shoot its core until its armour bar is gone to clear the stage: a big bonus, more for shield left.",
	"Each stage is faster and busier: a neon planet, a rock belt, deep space, then round again.",
	"⏸ pauses; Resume on the Home screen keeps your score, ships and bombs and restarts that stage.",
]
const TIPS := [
	"Keep moving: shots are aimed where you are, not where you'll be.",
	"Fly through rings when your shield is low — they're the only way to heal it.",
	"Save a bomb for the boss's fan of fire.",
]
const STATS := ["Best score", "Highest stage", "Enemies shot down", "Bosses beaten", "Rings flown through", "Bombs used", "Games played"]
