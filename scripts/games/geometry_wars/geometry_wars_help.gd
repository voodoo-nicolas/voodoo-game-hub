extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## TITLE is the game's shown name -- a placeholder for now (2026-10-05); change
## it here and in manifest.json ("title" / "title_es"). The id stays.

const ID := "geometry_wars"
const TITLE := "Neon Blast"
const GOAL := "Fly a horned voodoo skull through a swarm of neon spirits: break them with a storm of pins and score as much as you can -- or clear the Campaign's 40 levels and beat its bosses."
const HOW := [
	"Hold the phone sideways. The left stick flies your skull, and it faces the way you steer. The right stick aims and fires without turning it.",
	"You fire bursts of three pins, ten bursts a second. The middle pin is faster and flies farther.",
	"The maps are bigger than the screen: the view follows you, and the minimap in the corner shows the whole arena.",
	"After you appear, a glowing halo keeps you safe for 5 seconds. Six quick beeps warn that it is about to fade.",
	"Every spirit you break leaves souls: little flames. Fly over one to raise your score multiplier by 1 — they fade after 3 seconds. Small souls are yellow; big green ones are worth 10.",
	"Every kill scores its points times your multiplier. Dying clears the screen and resets the multiplier.",
	"💣 Bomb wipes out every enemy on screen and dents a boss. Some modes give you more as you score.",
	"Drifting crossbones and orbs wander and bounce. Pink eyes stalk you and get faster the longer they live. Masks dodge your pins. Orange splitters break in three. Tiny gnats swarm in hordes, and one pin pierces many.",
	"Bone serpents can only be broken at the skull. Darts charge in straight lines. Chargers aim, then rush you: their golden shell shrugs off pins, so hit them from behind.",
	"Black holes pull, even asleep. Shoot one to wake it — it sucks in enemies, pins and you, and grows with everything it eats. Kill it to blow up everything around it, or let it eat too much and it pops into a swarm of sprites that chase you.",
	"Seals are rune bars with deadly orange ends. Fly through the middle to break them, taking everything nearby with them; several in a row make a combo. Pins bounce off them as golden pins worth 4x. Golden seals are worth far more but fade after 7 seconds.",
	"Spiders hop about laying hex charms. Touch or shoot a charm and it blows up the enemies around it.",
	"Modes: Endless (3 lives, bombs, extra lives), Time Attack (3 minutes, endless lives), Unarmed (no pins, only seals), Sanctuary (you can only shoot inside a sacred circle, and enemies can't enter one), Stampede (walls of darts), Coffin (a tiny box) and Boss Rush.",
	"Campaign: 40 levels in 6 worlds, each with a goal. Finishing earns a star, not losing a life another, beating the score target a third. Every sixth level is a boss.",
	"Familiars are spirit animals that fly with you: Raven, Moth, Bull, Owl, Bat and Wisp. Each comes up for sale as you get through the Campaign; buy it with the points every campaign score adds to your purse. Pick one on the level map. A Cursed run plays the same levels with no familiar.",
	"The points scored while a familiar flies with you go to that familiar: spend them on its upgrades -- armor, speed, power and soul pull. Enemies can knock a familiar out for a few seconds.",
	"The pause button keeps the game; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Keep moving in wide circles — standing still gets you surrounded.",
	"Break the eyes early: the older they get, the faster they stalk you.",
	"Pin a mask against a wall, or get close and fire a burst it can't dodge.",
	"Sweep through the souls after a fight, before they fade.",
	"Let a black hole swallow a crowd, then kill it for a huge blast — but don't let it pop.",
	"Lead the swarm past a seal before you break it.",
	"Bosses have a weak spot: the Hive Queen's core behind her plates, the Serpent King's glowing tail, the Titan's guns first.",
	"Save a bomb for when you're cornered.",
]
const STATS := ["Best score", "Highest multiplier", "Longest time survived", "Games played", "Campaign stars", "Cursed stars",
	"Levels cleared", "Bosses defeated", "Seals broken", "Familiars unlocked",
	"Best score (Time Attack)", "Best score (Unarmed)", "Best score (Sanctuary)", "Best score (Stampede)",
	"Best score (Coffin)", "Best score (Boss Rush)"]

## Stats renamed in the re-theme (2026-10-05): old key -> new key, moved over
## once by the game so nobody loses a record.
const RENAMED_STATS := {
	"Best score (Deadline)": "Best score (Time Attack)", "Best score (Pacifism)": "Best score (Unarmed)",
	"Best score (King)": "Best score (Sanctuary)", "Best score (Waves)": "Best score (Stampede)",
	"Best score (Claustrophobia)": "Best score (Coffin)", "Hardcore stars": "Cursed stars",
	"Drones unlocked": "Familiars unlocked", "Gates exploded": "Seals broken",
}

## Goals worth bragging about (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🔺", "title": "Survivor", "key": "Best score", "at": 10000},
	{"id": "goal2", "icon": "✴️", "title": "Grid Warrior", "key": "Best score", "at": 50000},
	{"id": "goal3", "icon": "🌟", "title": "Neon Legend", "key": "Best score", "at": 200000},
	{"id": "mult100", "icon": "✖️", "title": "Multiplier Maniac", "key": "Highest multiplier", "at": 100},
	{"id": "mult500", "icon": "🔥", "title": "Soul Hoarder", "key": "Highest multiplier", "at": 500},
	{"id": "boss1", "icon": "🐉", "title": "Giant Slayer", "desc": "Defeat a boss", "key": "Bosses defeated", "at": 1},
	{"id": "boss10", "icon": "⚔️", "title": "Boss Hunter", "desc": "Defeat 10 bosses", "key": "Bosses defeated", "at": 10},
	{"id": "rush", "icon": "☠️", "title": "Rush Survivor", "desc": "Clear Boss Rush", "key": "Boss Rush clears", "at": 1},
	{"id": "stars15", "icon": "⭐", "title": "Star Pilot", "key": "Campaign stars", "at": 15},
	{"id": "stars60", "icon": "🌠", "title": "Constellation", "key": "Campaign stars", "at": 60},
	{"id": "stars120", "icon": "🌌", "title": "Underworld Ace", "desc": "Every star in the Campaign", "key": "Campaign stars", "at": 120},
	{"id": "hard30", "icon": "💀", "title": "Curse Breaker", "key": "Cursed stars", "at": 30},
	{"id": "drones", "icon": "🦉", "title": "Menagerie", "desc": "Unlock all 6 familiars", "key": "Familiars unlocked", "at": 6},
	{"id": "gates100", "icon": "📿", "title": "Seal Breaker", "key": "Seals broken", "at": 100},
	{"id": "deadline", "icon": "⏱️", "title": "Beat the Clock", "key": "Best score (Time Attack)", "at": 100000},
	{"id": "pacifism", "icon": "✋", "title": "Empty Hands", "key": "Best score (Unarmed)", "at": 20000},
	{"id": "king", "icon": "🕯️", "title": "High Priest", "key": "Best score (Sanctuary)", "at": 50000},
	{"id": "waves", "icon": "🐃", "title": "Stampede Survivor", "key": "Best score (Stampede)", "at": 50000},
	{"id": "claustro", "icon": "⚰️", "title": "Buried Alive", "key": "Best score (Coffin)", "at": 50000},
]
