extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "crypt_crawler"
const TITLE := "Crypt Crawler"
const GOAL := "Go down as many floors of the crypt as you can: find each floor's glowing green exit before the dead get you."
const HOW := [
	"▲ ▼ walk forward and back, ◀ ▶ step sideways, ⟲ ⟳ turn. You can also drag sideways on the view to turn.",
	"Hold ✴ Fire to blast your wand at whatever is under the crosshair. Walls block the shot.",
	"Skulls fly at you and bite. Wraiths (from floor 2) keep their distance and throw fireballs — dodge them sideways. Horned brutes (from floor 3) take six hits.",
	"Green crosses heal 30 health; gold soul gems are worth 50 points. Each monster destroyed scores 100 to 400.",
	"The map in the corner fills in as you explore; the exit shows green on it once you've seen it. Walk into the green rings to finish the floor (+500 and a little health back).",
	"Every floor is bigger, with more monsters. You have one life: at 0 health the run ends.",
	"⏸ pauses; Resume on the Home screen keeps your score and health and starts that floor afresh.",
]
const TIPS := [
	"Back away while you fire: skulls have to fly straight into your wand.",
	"Fight at corners — peek, shoot, step back out of a wraith's line of fire.",
	"You don't have to clear a floor. When health is low, run for the exit.",
]
const STATS := ["Best score", "Deepest floor", "Floors cleared", "Monsters destroyed", "Soul gems", "Games played"]
