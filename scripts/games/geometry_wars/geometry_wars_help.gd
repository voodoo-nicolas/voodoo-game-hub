extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## TITLE is the game's shown name -- a placeholder for now (2026-10-05); change
## it here and in manifest.json ("title" / "title_es"). The id stays.

const ID := "geometry_wars"
const TITLE := "Neon Blast"
const GOAL := "Fly a horned voodoo skull through a swarm of neon spirits: break them with a storm of pins and score as much as you can -- or survive the Campaign's 40 levels and beat its bosses."
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
	"At first you can play Endless (3 lives, bombs, extra lives) and the Campaign. Each Campaign boss you beat opens another mode: Time Attack (3 minutes, endless lives), Unarmed (no pins, only seals), Stampede (walls of darts), Sanctuary (you can only shoot inside a sacred circle, and enemies can't enter one), Coffin (a tiny box) and Boss Rush.",
	"Campaign: 40 levels in 6 worlds. The first two teach flying and bombs; from the third, survive the clock. When it runs out the level is cleared and the swarm keeps coming: carry on, because the stars are points -- the first for surviving, two more at the level's point targets. Tap 🏁 Finish to stop. Every sixth level has a boss: beat it, not just outlast it, to open its prize.",
	"Bosses grow bigger and tougher as you go. The Hive Queen hides behind rings of plates; every part of the Serpent King can be shot; the Bone Scorpion's claws go first, then its stinger -- only while its tail is out after a strike (it stops, rattles and marks the spot in red first: move!) -- then its head. The Watcher's beam and shots stop at tombstones: hide behind one, then shoot its eye while it's open. The Warden's shield stays up until you break the four crystals in the corners of the map.",
	"Familiars are spirit animals that fly with you: Raven, Moth, Bull, Owl, Bat and Wisp. The Raven joins when you beat the first boss; the others come as your Campaign stars add up. Pick one on the level map. A Cursed run plays the same levels with no familiar.",
	"The points scored while a familiar flies with you go to that familiar: spend them on its upgrades -- armor, speed, power and soul pull. They are expensive. Enemies can knock a familiar out for a few seconds.",
	"The pause button keeps the game; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Keep moving in wide circles — standing still gets you surrounded.",
	"Break the eyes early: the older they get, the faster they stalk you.",
	"Pin a mask against a wall, or get close and fire a burst it can't dodge.",
	"Sweep through the souls after a fight, before they fade.",
	"Let a black hole swallow a crowd, then kill it for a huge blast — but don't let it pop.",
	"Lead the swarm past a seal before you break it.",
	"Bosses have a weak spot: the Hive Queen's core behind her plates, the Serpent King's body before its head, the Titan's guns first.",
	"When the Bone Scorpion stops and rattles, a red mark shows where its tail will strike: get out of it, then shoot the stinger while it's stuck there.",
	"The Watcher's sight line follows you slowly: put a tombstone between you before it fires, then shoot its dazed eye.",
	"Save a bomb for when you're cornered.",
]
const STATS := ["Best score", "Highest multiplier", "Longest time survived", "Games played", "Campaign stars", "Cursed stars",
	"Levels cleared", "Bosses defeated", "Seals broken", "Familiars unlocked",
	"Most seals in one run", "Longest seal chain", "Longest overtime", "Biggest chain reaction",
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
	# Special moves (owner, 2026-10-07): what you pull off in one run.
	{"id": "seals10", "icon": "📿", "title": "Seal Runner", "desc": "Fly through 10 seals in one run", "key": "Most seals in one run", "at": 10},
	{"id": "seals25", "icon": "🔱", "title": "Seal Dancer", "desc": "Fly through 25 seals in one run", "key": "Most seals in one run", "at": 25},
	{"id": "seals50", "icon": "🌀", "title": "Seal Storm", "desc": "Fly through 50 seals in one run", "key": "Most seals in one run", "at": 50},
	{"id": "chain3", "icon": "⛓️", "title": "Chain Breaker", "desc": "Break 3 seals in a row, each within 2.5 seconds of the last", "key": "Longest seal chain", "at": 3},
	{"id": "chain6", "icon": "👑", "title": "Combo King", "desc": "Break 6 seals in a row", "key": "Longest seal chain", "at": 6},
	{"id": "graze25", "icon": "😬", "title": "Close Call", "desc": "25 near misses in one run", "key": "Most close calls in one run", "at": 25},
	{"id": "graze100", "icon": "💃", "title": "Bullet Dancer", "desc": "100 near misses in one run", "key": "Most close calls in one run", "at": 100},
	{"id": "blast15", "icon": "💥", "title": "Chain Reaction", "desc": "Destroy 15 enemies with one blast", "key": "Biggest chain reaction", "at": 15},
	{"id": "blast40", "icon": "🎆", "title": "Domino Effect", "desc": "Destroy 40 enemies with one blast", "key": "Biggest chain reaction", "at": 40},
	{"id": "well8", "icon": "🕳️", "title": "Feeding Frenzy", "desc": "Break a black hole that swallowed 8 things", "key": "Biggest black hole broken", "at": 8},
	{"id": "over60", "icon": "⏳", "title": "Overtime", "desc": "Keep going 1 minute past a level's clock", "key": "Longest overtime", "at": 60},
	{"id": "over180", "icon": "🔥", "title": "Iron Will", "desc": "Keep going 3 minutes past a level's clock", "key": "Longest overtime", "at": 180},
	{"id": "hide1", "icon": "👁️", "title": "Hide and Seek", "desc": "Let a tombstone take the Watcher's beam", "key": "Most beams dodged behind cover", "at": 1},
	{"id": "hide5", "icon": "🕶️", "title": "Out of Sight", "desc": "Hide from 5 of the Watcher's beams in one run", "key": "Most beams dodged behind cover", "at": 5},
	{"id": "shield1", "icon": "💎", "title": "Shield Breaker", "desc": "Break all four of the Warden's crystals", "key": "Most shields broken in one run", "at": 1},
	{"id": "shield3", "icon": "🏰", "title": "Siege Master", "desc": "Drop the Warden's shield 3 times in one run", "key": "Most shields broken in one run", "at": 3},
	{"id": "flawboss", "icon": "😇", "title": "Untouchable", "desc": "Beat a boss without losing a life", "key": "Flawless boss kills", "at": 1},
]
