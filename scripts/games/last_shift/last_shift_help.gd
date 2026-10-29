extends RefCounted

## How to Play text and stats for GameInfo (scripts/common/game_info.gd).
## Written from the game's code (last_shift_world.gd, _touch_controls.gd, _engine.gd, v0.5).
## Day 0 rule (docs/story/expansions/day0_intercom_and_silent_ai_rule.md in the claudius repo):
## nothing here explains what is happening in the building.

const ID := "last_shift"
const TITLE := "Last Shift"
const GOAL := "Nash Kovac fixes chillers on the night shift. Tonight something goes wrong in the building: find a way out before dawn."
const HOW := [
	"Hold the phone sideways. The stick on the left walks. A (lower right) says what it does: USE, SEARCH, HIDE, OPEN, READ, TALK, TAKE... B (to its right) attacks with the weapon it shows.",
	"Walk into a door to open it. Locked doors need a key, a keycard or another way round.",
	"Search lockers, desks, cabinets and bodies: it takes 2 seconds, and the noise can draw infected. A searched locker is a place to hide.",
	"Infected that lose sight of you while you hide wander off searching. If one saw you climb in, it drags you out.",
	"Health is out of 100. It ticks back slowly while nobody is chasing you, up to a limit that depends on the difficulty. Tap the health bar to use a first-aid kit (50) or a snack (10) from your bag.",
	"Armor soaks part of each hit: Nash's hi-vis vest, or the riot gear if you find it.",
	"Weapons: fists, a kitchen knife (silent; one stab takes down an infected that hasn't noticed you), a severed arm, a pipe wrench, a pistol with very few bullets (loud), and coolant cans you throw to slow the infected. With two or more, the wheel button picks one.",
	"Security guards and shooters are people: Nash knocks them out, never kills them.",
	"The mission log (top right) lists what to do next; emails and notes start new tasks. The map button (left of pause) shows the building.",
	"There are three ways out. Each escape counts, and they are all achievements.",
	"The game saves at every room you enter and when you pause. ▶ Resume starts that room again. Getting caught sends you back to it.",
	"Keyboard: arrows or WASD walk, Space or E is A, J or K is B, Tab the wheel, I the bag, L the log, M the map, H a quick heal, Q the next weapon, 1-6 a weapon, Esc or P pause.",
]
const TIPS := [
	"Read the gauges and the emails: the numbers for the puzzles are in them.",
	"Gunshots are loud. Save the pistol for what a wrench can't stop.",
	"Sneak up on infected that haven't seen you and use the knife.",
	"Vending machines sell snacks if you have cash.",
	"On Hard, health barely comes back on its own: keep your first-aid kits.",
]
const STATS := ["Escapes", "Fastest escape time", "Most infected in one night", "Infected down", "Most money in one night",
	"Nights started", "Times caught", "Total time played",
	"Infected down: fists", "Infected down: knife", "Infected down: severed arm", "Infected down: pipe wrench",
	"Infected down: pistol"]

## The night's achievements, paid in Viral XP by the hub (docs/ADDING_A_GAME.md §2). Ids, XP and
## order = LsEngine.ACHIEVEMENTS; titles and descriptions = LsText.ACH (same English, so one es.json
## entry each). Reported by last_shift_achievements.gd (report_hub) when the world unlocks one.
const CHALLENGES := [
	{"id": "not_my_shift", "icon": "🏃", "title": "Not My Shift", "desc": "Survive the first attack.", "xp": 25},
	{"id": "coroner", "icon": "🔎", "title": "Coroner's Report", "desc": "Inspect the first body.", "xp": 25},
	{"id": "promotion", "icon": "🏅", "title": "Promotion", "desc": "You're Employee of the Month now.", "xp": 100},
	{"id": "honorable", "icon": "🖼️", "title": "Honorable Mention", "desc": "Find your name on Gary's wall.", "xp": 10},
	{"id": "lights_out", "icon": "🚨", "title": "Lights Out ", "desc": "Switch off the alarm.", "xp": 25},
	{"id": "riot_ready", "icon": "🛡️", "title": "Riot Ready", "desc": "Put on the riot gear.", "xp": 25},
	{"id": "birthday", "icon": "🎁", "title": "Happy Birthday, Nash", "desc": "Find Marisol's gift.", "xp": 25},
	{"id": "scavenger", "icon": "🗄️", "title": "Scavenger", "desc": "Search 40 things in one night.", "xp": 50},
	{"id": "front_door", "icon": "🚪", "title": "Front Door", "desc": "Escape through the front doors.", "xp": 50},
	{"id": "back_door", "icon": "🚚", "title": "Back Door", "desc": "Escape through the loading dock.", "xp": 100},
	{"id": "fire_drill", "icon": "🔥", "title": "Fire Drill", "desc": "Escape through the fire exit.", "xp": 100},
	{"id": "three_ways", "icon": "🗝️", "title": "Three Ways Out", "desc": "Escape all three ways.", "xp": 200},
	{"id": "veteran", "icon": "🌅", "title": "Night Shift Veteran", "desc": "Escape on Hard.", "xp": 150},
	{"id": "party_animal", "icon": "🥳", "title": "Party Animal", "desc": "Wear a party hat. It's still a party.", "xp": 25},
	{"id": "head_chef", "icon": "👨‍🍳", "title": "Head Chef", "desc": "Wear the cook's hat.", "xp": 25},
]
