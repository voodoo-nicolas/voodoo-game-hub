extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).

const ID := "geometry_wars"
const TITLE := "Geometry Wars"
const GOAL := "Survive the swarm of neon shapes and score as many points as you can -- or clear the Adventure's 40 levels and beat its bosses."
const HOW := [
	"Hold the phone sideways. The left stick flies the ship, and it points the way you steer. The right stick aims and fires without turning the ship.",
	"You fire bursts of three shots, ten bursts a second. The middle shot is faster and flies farther.",
	"The maps are bigger than the screen: the view follows your ship, and the minimap at the bottom shows the whole arena.",
	"After you appear, a glowing halo keeps you safe for 5 seconds. Six quick beeps warn that it is about to fade.",
	"Kills drop tiny yellow crystals called geoms. Fly over one to raise your score multiplier by 1 — they vanish after 3 seconds. Huge orange geoms are worth 10.",
	"Every kill scores its points times your multiplier. Dying clears the screen and resets the multiplier.",
	"💣 Bomb wipes out every enemy on screen and dents a boss. You earn more with points in some modes.",
	"Wanderers and neutrons drift and bounce. Blue grunts chase you and get faster the longer they live. Green weavers dodge your shots. Pink spinners split in three. Tiny mayflies swarm in hordes, and one shot pierces many.",
	"Snakes can only be killed by hitting the head. Rockets charge in straight lines. Repulsors aim, then charge: their orange front shrugs off shots, so hit them from behind.",
	"Gravity wells are black holes: even asleep they pull gently. Shoot one to wake it — it sucks in enemies, shots and you, and grows with everything it eats. Kill it to blow up everything around it, or let it eat too much and it pops into a swarm of protons that chase you.",
	"Gates are bars with deadly orange ends. Fly through the middle to blow them up with everything nearby; several in a row make a combo. Shots bounce off them as gold shots worth 4x. Golden gates are worth far more but vanish after 7 seconds.",
	"Mine layers hop about dropping mines. Touch or shoot a mine and it blows up the enemies around it.",
	"Modes: Evolved (3 lives, bombs, extra lives), Deadline (3 minutes, endless lives), Pacifism (no gun, only gates), King (you can only shoot inside a zone, and enemies can't enter one), Waves (walls of rockets), Claustrophobia (a tiny arena) and Boss Rush.",
	"Adventure: 40 levels in 6 worlds, each with a goal. Finishing earns a star, beating the score targets two more. Every sixth level is a boss.",
	"Stars unlock drones that fly with you: Attack, Collect, Ram, Snipe, Defend and Sweep. Pick one on the level map. Hardcore plays the same levels with no drone.",
	"The pause button keeps the game; Resume on the Home screen picks it up.",
]
const TIPS := [
	"Keep moving in wide circles — standing still gets you surrounded.",
	"Kill grunts early: the older they get, the faster they chase.",
	"Fire at a weaver's wall side to pin it, or get close and shoot a quick burst it can't dodge.",
	"Sweep through geoms after a fight, before they vanish.",
	"Let a gravity well swallow a crowd, then kill it for a huge blast — but don't let it pop.",
	"Lead the swarm past a gate before you fly through it.",
	"Bosses have a weak spot: the Hive Queen's core behind her plates, the Serpent King's glowing tail, the Titan's guns first.",
	"Save a bomb for when you're cornered.",
]
const STATS := ["Best score", "Highest multiplier", "Longest time survived", "Games played", "Campaign stars", "Hardcore stars",
	"Levels cleared", "Bosses defeated", "Gates exploded", "Drones unlocked",
	"Best score (Deadline)", "Best score (Pacifism)", "Best score (King)", "Best score (Waves)",
	"Best score (Claustrophobia)", "Best score (Boss Rush)"]

## Goals worth bragging about (app v0.25+ shows them as achievements; see achievements.gd).
const ACHIEVEMENTS := [
	{"id": "goal1", "icon": "🔺", "title": "Survivor", "key": "Best score", "at": 10000},
	{"id": "goal2", "icon": "✴️", "title": "Grid Warrior", "key": "Best score", "at": 50000},
	{"id": "goal3", "icon": "🌟", "title": "Geometry God", "key": "Best score", "at": 200000},
	{"id": "mult100", "icon": "✖️", "title": "Multiplier Maniac", "key": "Highest multiplier", "at": 100},
	{"id": "mult500", "icon": "💥", "title": "Geom Hoarder", "key": "Highest multiplier", "at": 500},
	{"id": "boss1", "icon": "🐉", "title": "Giant Slayer", "desc": "Defeat a boss", "key": "Bosses defeated", "at": 1},
	{"id": "boss10", "icon": "⚔️", "title": "Boss Hunter", "desc": "Defeat 10 bosses", "key": "Bosses defeated", "at": 10},
	{"id": "rush", "icon": "☠️", "title": "Rush Survivor", "desc": "Clear Boss Rush", "key": "Boss Rush clears", "at": 1},
	{"id": "stars15", "icon": "⭐", "title": "Star Pilot", "key": "Campaign stars", "at": 15},
	{"id": "stars60", "icon": "🌠", "title": "Constellation", "key": "Campaign stars", "at": 60},
	{"id": "stars120", "icon": "🌌", "title": "Ultimate Ace", "desc": "Every star in the Adventure", "key": "Campaign stars", "at": 120},
	{"id": "hard30", "icon": "💀", "title": "Hardcore Hero", "key": "Hardcore stars", "at": 30},
	{"id": "drones", "icon": "🛸", "title": "Drone Fleet", "desc": "Unlock all 6 drones", "key": "Drones unlocked", "at": 6},
	{"id": "gates100", "icon": "🚪", "title": "Gatecrasher", "key": "Gates exploded", "at": 100},
	{"id": "deadline", "icon": "⏱️", "title": "Beat the Clock", "key": "Best score (Deadline)", "at": 100000},
	{"id": "pacifism", "icon": "🕊️", "title": "Pacifist", "key": "Best score (Pacifism)", "at": 20000},
	{"id": "king", "icon": "👑", "title": "King of the Grid", "key": "Best score (King)", "at": 50000},
	{"id": "waves", "icon": "🌊", "title": "Wave Rider", "key": "Best score (Waves)", "at": 50000},
	{"id": "claustro", "icon": "📦", "title": "No Room to Breathe", "key": "Best score (Claustrophobia)", "at": 50000},
]
