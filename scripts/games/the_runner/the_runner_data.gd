extends RefCounted

## The Runner's content as data: goods, worlds, factions, ships, modules, skills, missions, events and
## the story cards. The owner's design doc (docs/runner/GAME_DESIGN_THE_RUNNER.md §0) asks for JSON
## files under /data; the hub's translation tool reads English text from .gd files only, so the same
## tables live here as constants (docs/runner/DECISIONS.md D-3). No content is hard-coded in the
## engine or the screens: add a good, a world or a mission here.
## Every name and line is English; screens show them through tr().

const ART := "res://games/the_runner/art/"

## The system map: system_1.webp, 1365 x 768. Positions are the picture's own planets, measured by
## bright-spot detection (not guessed); "r" is the planet's radius there.
const MAP_ART := "system_1"
const MAP_SIZE := Vector2(1365, 768)
## Places on the map that are not worlds: flying through them costs hull or fuel.
const HAZARDS := [
	{"id": "sun", "name": "The Sun", "pos": [684, 380], "r": 112, "kind": "sun"},
	{"id": "black_hole", "name": "The Maw", "pos": [930, 393], "r": 34, "kind": "black_hole"},
]

## Credits: "clean" (legal, ¢) and "dirty" (black market, ◆).
const GOODS := {
	"water": {"name": "Ice water", "base": 40, "vol": 0.20, "contraband": false},
	"food": {"name": "Hydroponic food", "base": 60, "vol": 0.20, "contraband": false},
	"ore": {"name": "Raw ore", "base": 80, "vol": 0.25, "contraband": false},
	"alloys": {"name": "Alloys", "base": 150, "vol": 0.25, "contraband": false},
	"medicine": {"name": "Med kits", "base": 220, "vol": 0.30, "contraband": false},
	"electronics": {"name": "Electronics", "base": 300, "vol": 0.30, "contraband": false},
	"forged_ids": {"name": "Forged IDs", "base": 500, "vol": 0.35, "contraband": true},
	"bootleg_data": {"name": "Bootleg data", "base": 420, "vol": 0.35, "contraband": true},
	"weapons": {"name": "Unlicensed weapons", "base": 700, "vol": 0.35, "contraband": true},
	"stolen_tech": {"name": "Stolen tech", "base": 900, "vol": 0.40, "contraband": true},
	"relics": {"name": "Hollow relics", "base": 1200, "vol": 0.45, "contraband": true},
}
const GOOD_ORDER := ["water", "food", "ore", "alloys", "medicine", "electronics",
	"forged_ids", "bootleg_data", "weapons", "stolen_tech", "relics"]

## "police": the faction scans ships and keeps heat on you.
const FACTIONS := {
	"concord": {"name": "Concord of Worlds", "police": true},
	"helios": {"name": "Helios Dominion", "police": true},
	"free_haven": {"name": "Free Haven Syndicate", "police": false},
	"deepfolk": {"name": "Deepfolk Collective", "police": false},
	"quiet_star": {"name": "Order of the Quiet Star", "police": false},
	"scrapper_kings": {"name": "Scrapper Kings", "police": false},
	"nobody": {"name": "No one", "police": false},
}
const POLICE := ["concord", "helios"]

## law 0 (lawless) .. 5 (total surveillance). "black": has a black market. "blind": the Ledger can't
## see it (heat cools twice as fast). "makes" / "wants": price factors (below 1 = cheap here).
## "pos" / "r": on system_1.webp. "view": arrival picture, "dock": the port picture.
const WORLDS := {
	"luna": {"name": "Luna Port", "desc": "The Moon. Where everyone went when Earth died.",
		"faction": "concord", "law": 3, "black": true, "blind": false, "pos": [340, 130], "r": 40,
		"view": "moon", "dock": "port_moon", "services": ["market", "shipyard", "fixer", "front", "fuel"],
		"makes": {"food": 0.8, "electronics": 0.85}, "wants": {"ore": 1.25, "water": 1.3, "relics": 1.2}},
	"old_earth": {"name": "Old Earth", "desc": "A dead world in a ring of wrecks. Nobody comes here. That's the point.",
		"faction": "nobody", "law": 0, "black": false, "blind": true, "pos": [1089, 637], "r": 42,
		"view": "earth", "dock": "earth", "services": ["salvage"], "makes": {}, "wants": {}},
	"ember": {"name": "Ember Spire", "desc": "Lava fields and Deepfolk smelters.",
		"faction": "deepfolk", "law": 1, "black": true, "blind": false, "pos": [391, 260], "r": 16,
		"view": "world_fire", "dock": "port_hangar", "services": ["market", "fuel", "fixer"],
		"makes": {"ore": 0.6, "alloys": 0.8}, "wants": {"food": 1.4, "water": 1.5, "medicine": 1.3, "weapons": 1.35}},
	"frostline": {"name": "Frostline", "desc": "An ice colony under Concord guard. Cold, strict and hungry.",
		"faction": "concord", "law": 4, "black": false, "blind": false, "pos": [311, 345], "r": 16,
		"view": "world_ice", "dock": "port_dock", "services": ["market", "fuel", "fixer"],
		"makes": {"water": 0.5}, "wants": {"food": 1.35, "medicine": 1.6, "electronics": 1.2}},
	"verdance": {"name": "Verdance", "desc": "A jungle world. Free Haven runs the docks and asks no questions.",
		"faction": "free_haven", "law": 1, "black": true, "blind": false, "pos": [1000, 187], "r": 16,
		"view": "world_jungle", "dock": "port_hangar", "services": ["market", "shipyard", "fixer", "fuel"],
		"makes": {"food": 0.6, "medicine": 0.8}, "wants": {"forged_ids": 1.5, "weapons": 1.3, "electronics": 1.3}},
	"sporefall": {"name": "Sporefall", "desc": "Giant fungus forests. The Quiet Star monks pay well for relics.",
		"faction": "quiet_star", "law": 2, "black": true, "blind": false, "pos": [1261, 400], "r": 16,
		"view": "world_fungus", "dock": "port_dock", "services": ["market", "fixer", "fuel"],
		"makes": {"medicine": 0.6}, "wants": {"relics": 1.8, "bootleg_data": 1.3, "alloys": 1.2}},
	"dust_spire": {"name": "Dust Spire", "desc": "A Helios company city in the desert. Rich, watched, thirsty.",
		"faction": "helios", "law": 5, "black": true, "blind": false, "pos": [522, 529], "r": 16,
		"view": "world_sandy", "dock": "port_moon", "services": ["market", "shipyard", "fuel"],
		"makes": {"electronics": 0.6, "alloys": 0.9}, "wants": {"ore": 1.3, "water": 1.45, "forged_ids": 1.6, "bootleg_data": 1.4}},
	"tidewater": {"name": "Tidewater", "desc": "An ocean world of floating towns and quiet smugglers.",
		"faction": "free_haven", "law": 2, "black": true, "blind": false, "pos": [392, 457], "r": 16,
		"view": "world_water", "dock": "port_hangar", "services": ["market", "fixer", "fuel"],
		"makes": {"water": 0.7, "food": 0.7}, "wants": {"alloys": 1.3, "electronics": 1.4, "bootleg_data": 1.5}},
	"gravel": {"name": "Gravel Belt", "desc": "Asteroid rubble held by the Scrapper Kings. Lawless.",
		"faction": "scrapper_kings", "law": 0, "black": true, "blind": true, "pos": [724, 116], "r": 14,
		"view": "world_asteroid", "dock": "port_dock", "services": ["market", "shipyard", "fixer", "fuel"],
		"makes": {"stolen_tech": 0.6, "weapons": 0.6}, "wants": {"food": 1.5, "medicine": 1.5, "forged_ids": 1.3}},
	"canyon": {"name": "Red Canyon", "desc": "Deepfolk mines. They dig up more than ore here.",
		"faction": "deepfolk", "law": 1, "black": true, "blind": false, "pos": [792, 560], "r": 14,
		"view": "world_rocky", "dock": "port_hangar", "services": ["market", "fixer", "fuel"],
		"makes": {"ore": 0.5, "relics": 0.75}, "wants": {"electronics": 1.3, "food": 1.3, "weapons": 1.2}},
}
const WORLD_ORDER := ["luna", "old_earth", "ember", "frostline", "verdance", "sporefall", "dust_spire",
	"tidewater", "gravel", "canyon"]
const START_WORLD := "luna"

## Base ships. The Moth is what you start with; the Runner comes with mission M03.
const SHIPS := {
	"moth": {"name": "The Moth", "desc": "A tired courier. It flies. Mostly.",
		"cargo": 8, "hidden": 2, "tank": 12, "hull": 60, "stealth": 0, "guns": 1, "sprite": "moth"},
	"runner": {"name": "The Runner", "desc": "Old Marrow's ship. Fast, quiet, and the Ledger can't see it.",
		"cargo": 14, "hidden": 4, "tank": 18, "hull": 100, "stealth": 2, "guns": 2, "sprite": "runner"},
}

const SLOTS := ["engine", "cargo", "hidden", "shields", "weapons", "scanner", "special"]
const SLOT_NAMES := {"engine": "Engine", "cargo": "Cargo racks", "hidden": "Hidden hold", "shields": "Shields",
	"weapons": "Weapons", "scanner": "Scanner", "special": "Special"}
## "money": what pays for it ("clean" legal shipyards, "dirty" black-market ones). "shop": "legal" or
## "black" (Gravel Belt, Verdance after M02). Effects: fuel (fuel use factor), cargo, hidden, quality
## (hidden hold), shield, dmg (weapon factor), scan (scan pass bonus), sniff (shows patrol risk),
## stealth, flee (escape bonus).
const MODULES := {
	"eng_1": {"slot": "engine", "name": "Ion Drive", "price": 0, "money": "clean", "shop": "", "fuel": 1.0},
	"eng_2": {"slot": "engine", "name": "Fusion Drive", "price": 3000, "money": "clean", "shop": "legal", "fuel": 0.8, "flee": 0.05},
	"eng_3": {"slot": "engine", "name": "Rift Skimmer", "price": 9000, "money": "dirty", "shop": "black", "fuel": 0.6, "flee": 0.12},
	"car_1": {"slot": "cargo", "name": "Standard Racks", "price": 0, "money": "clean", "shop": "", "cargo": 0},
	"car_2": {"slot": "cargo", "name": "Expanded Racks", "price": 2500, "money": "clean", "shop": "legal", "cargo": 6},
	"car_3": {"slot": "cargo", "name": "Cargo Spine", "price": 8000, "money": "clean", "shop": "legal", "cargo": 12},
	"hid_1": {"slot": "hidden", "name": "False Floor", "price": 0, "money": "clean", "shop": "", "hidden": 0, "quality": 0},
	"hid_2": {"slot": "hidden", "name": "Smuggler's Wall", "price": 3500, "money": "dirty", "shop": "black", "hidden": 4, "quality": 1},
	"hid_3": {"slot": "hidden", "name": "Phase Locker", "price": 12000, "money": "dirty", "shop": "black", "hidden": 8, "quality": 2},
	"shd_1": {"slot": "shields", "name": "Deflector", "price": 0, "money": "clean", "shop": "", "shield": 0},
	"shd_2": {"slot": "shields", "name": "Aegis Shield", "price": 4000, "money": "clean", "shop": "legal", "shield": 20},
	"shd_3": {"slot": "shields", "name": "Bastion Shield", "price": 11000, "money": "clean", "shop": "legal", "shield": 45},
	"wpn_1": {"slot": "weapons", "name": "Pulse Cannon", "price": 0, "money": "clean", "shop": "", "dmg": 1.0},
	"wpn_2": {"slot": "weapons", "name": "Rail Gun", "price": 5000, "money": "dirty", "shop": "black", "dmg": 1.5},
	"wpn_3": {"slot": "weapons", "name": "Plasma Lance", "price": 14000, "money": "dirty", "shop": "black", "dmg": 2.0},
	"scn_1": {"slot": "scanner", "name": "Basic Scanner", "price": 0, "money": "clean", "shop": "", "scan": 0.0},
	"scn_2": {"slot": "scanner", "name": "Patrol Sniffer", "price": 3000, "money": "clean", "shop": "legal", "scan": 0.05, "sniff": true},
	"scn_3": {"slot": "scanner", "name": "Ledger Tap", "price": 9000, "money": "dirty", "shop": "black", "scan": 0.10, "sniff": true},
	"spc_0": {"slot": "special", "name": "Empty", "price": 0, "money": "clean", "shop": ""},
	"spc_ecm": {"slot": "special", "name": "ECM Jammer", "price": 6000, "money": "dirty", "shop": "black", "flee": 0.25},
	"spc_ghost": {"slot": "special", "name": "Ghost Core", "price": 0, "money": "clean", "shop": "", "stealth": 3},
}
const START_MODULES := {"engine": "eng_1", "cargo": "car_1", "hidden": "hid_1", "shields": "shd_1",
	"weapons": "wpn_1", "scanner": "scn_1", "special": "spc_0"}

## Skill tree: the six specializations of the design doc §7.2. The first branch you spend a point in
## is your primary, the second your secondary; the others stay closed. Each branch: 3 ranks in order.
const BRANCHES := ["smuggler", "pirate", "fixer", "forger", "enforcer", "launderer"]
const BRANCH_NAMES := {"smuggler": "Smuggler", "pirate": "Pirate", "fixer": "Fixer", "forger": "Forger",
	"enforcer": "Enforcer", "launderer": "Launderer"}
const BRANCH_ICONS := {"smuggler": "📦", "pirate": "🏴", "fixer": "🤝", "forger": "🪪", "enforcer": "🛡", "launderer": "🧺"}
const SKILLS := {
	"smuggler": [
		{"id": "sm_hold", "name": "Deep Pockets", "desc": "+2 hidden hold space."},
		{"id": "sm_cool", "name": "Cool Head", "desc": "+10% to pass every scan."},
		{"id": "sm_lanes", "name": "Ghost Lanes", "desc": "Heat cools twice as fast."},
	],
	"pirate": [
		{"id": "pi_board", "name": "Boarding Crew", "desc": "+25% damage in fights."},
		{"id": "pi_salvage", "name": "Scavenger", "desc": "+50% from salvage and wrecks."},
		{"id": "pi_fear", "name": "Black Flag", "desc": "Pirates may flee from you."},
	],
	"fixer": [
		{"id": "fx_tongue", "name": "Silver Tongue", "desc": "Bribes cost 25% less."},
		{"id": "fx_contacts", "name": "Contacts", "desc": "One more contract and +15% contract pay."},
		{"id": "fx_favors", "name": "Favors Owed", "desc": "A bribe also lowers your heat."},
	],
	"forger": [
		{"id": "fo_papers", "name": "Clean Papers", "desc": "+8% to pass every scan."},
		{"id": "fo_spoof", "name": "Ledger Spoof", "desc": "You gain 25% less heat."},
		{"id": "fo_ghost", "name": "Ghost Identity", "desc": "Once per run: wipe your Concord heat (Stats tab)."},
	],
	"enforcer": [
		{"id": "en_armor", "name": "Armor Plating", "desc": "+20 hull."},
		{"id": "en_gunnery", "name": "Gunnery", "desc": "+1 gun."},
		{"id": "en_warlord", "name": "Warlord", "desc": "Win a fight: +50% loot."},
	],
	"launderer": [
		{"id": "la_books", "name": "Clean Books", "desc": "Laundering keeps 8% more."},
		{"id": "la_fast", "name": "Fast Wash", "desc": "Laundered money is ready in 1 day."},
		{"id": "la_offshore", "name": "Offshore", "desc": "No audits at your front."},
	],
}

## Heat (0..100) per police faction.
const HEAT_TIERS := [[20, "Ignored"], [40, "Watched"], [60, "Wanted"], [80, "Hunted"], [101, "Public Enemy"]]

## Missions. Steps: deliver {good, qty, to} (hand over at that world's dock), pay {amount} (to Kessel,
## at Luna), reach {to}, scans {n} (pass n scans carrying contraband), fights {n} (win n fights).
## "give": cargo handed to you when you accept. "story": a card shown on accept / on done.
const MISSIONS := {
	"M01": {"kind": "main", "title": "Cold Cargo", "giver": "luna",
		"brief": "Mother Kessel hands you two crates of bootleg data. Hide them, fly them to Tidewater, don't get scanned.",
		"give": {"bootleg_data": 2}, "steps": [{"type": "deliver", "good": "bootleg_data", "qty": 2, "to": "tidewater"}],
		"reward": {"dirty": 600, "xp": 60, "unlock": "black_market"}, "next": "M02",
		"story_done": "done_m01"},
	"M02": {"kind": "main", "title": "Kessel's Terms", "giver": "luna",
		"brief": "You still owe Mother Kessel 3,000. Clean or dirty, she doesn't care. Pay her at Luna Port.",
		"steps": [{"type": "pay", "amount": 3000}],
		"reward": {"xp": 120, "points": 1, "unlock": "black_shipyard"}, "next": "M03", "story_done": "done_m02"},
	"M03": {"kind": "main", "title": "Dead Man's Ship", "giver": "luna",
		"brief": "A coded message: coordinates in the wreck ring of Old Earth, and a name. Old Marrow.",
		"steps": [{"type": "reach", "to": "old_earth"}],
		"reward": {"xp": 150, "ship": "runner", "module": "spc_ghost"}, "next": "M04", "story_done": "done_m03"},
	"M04": {"kind": "main", "title": "Ghost in the Net", "giver": "old_earth",
		"brief": "Marrow said they can't see you. Prove it: get through three scans with contraband aboard.",
		"steps": [{"type": "scans", "n": 3}],
		"reward": {"xp": 300, "clean": 2000, "unlock": "act1_done"}, "next": "", "story_done": "done_m04"},
	"S01": {"kind": "side", "title": "Wrong Vending Machine", "giver": "luna",
		"brief": "Luna Port's vending AI sells the wrong things. Its owner wants 4 crates of electronics to rebuild it.",
		"steps": [{"type": "deliver", "good": "electronics", "qty": 4, "to": "luna"}],
		"reward": {"clean": 1700, "xp": 40}},
	"S02": {"kind": "side", "title": "Lava Courier", "giver": "ember",
		"brief": "An eruption hurt the smelter crews of Ember Spire. Bring 5 med kits.",
		"steps": [{"type": "deliver", "good": "medicine", "qty": 5, "to": "ember"}],
		"reward": {"clean": 1800, "xp": 50, "cred": 5}},
	"S03": {"kind": "side", "title": "Cold Snap", "giver": "frostline",
		"brief": "Frostline's greenhouses froze. They need 6 crates of food before the ration day.",
		"steps": [{"type": "deliver", "good": "food", "qty": 6, "to": "frostline"}],
		"reward": {"clean": 1200, "xp": 40}},
	"S04": {"kind": "side", "title": "Relic Run", "giver": "sporefall",
		"brief": "A monk of the Quiet Star wants two Hollow relics, no questions asked. Red Canyon digs them up.",
		"steps": [{"type": "deliver", "good": "relics", "qty": 2, "to": "sporefall"}],
		"reward": {"dirty": 3500, "xp": 80, "cred": 5}},
	"S05": {"kind": "side", "title": "Honor Among Thieves", "giver": "gravel",
		"brief": "Queen Vask's people want to see if you can fight. Beat one pirate crew.",
		"steps": [{"type": "fights", "n": 1}],
		"reward": {"dirty": 2000, "xp": 60, "infamy": 8}},
}
const MAIN_ORDER := ["M01", "M02", "M03", "M04"]
const SIDE_ORDER := ["S01", "S02", "S03", "S04", "S05"]
const START_DEBT := 3000

## Market events: a world's prices move for a few days. "goods": which goods ("contraband" / "legal" /
## an id), "mult": price factor, "law": extra law level while it lasts.
const EVENTS := [
	{"id": "crackdown", "name": "Crackdown", "text": "Concord crackdown at %s: contraband sells high, patrols everywhere.", "goods": "contraband", "mult": 1.4, "law": 1},
	{"id": "festival", "name": "Festival", "text": "Festival on %s: food and med kits in demand.", "goods": "festival", "mult": 1.5, "law": 0},
	{"id": "shortage", "name": "Shortage", "text": "Shortage of %s on %s: prices up.", "goods": "one", "mult": 1.8, "law": 0},
	{"id": "glut", "name": "Glut", "text": "Too much %s on %s: prices down.", "goods": "one", "mult": 0.6, "law": 0},
	{"id": "strike", "name": "Strike", "text": "Miners' strike on %s: ore and alloys up.", "goods": "strike", "mult": 1.5, "law": 0},
]

## Enemies for fights. "hull", "dmg" per round (min, max), "loot" dirty credits (min, max).
const ENEMIES := {
	"pirate": {"name": "Scrapper raiders", "hull": 40, "dmg": [6, 12], "loot": [300, 900], "sprite": "pirate"},
	"patrol": {"name": "Concord patrol", "hull": 70, "dmg": [8, 15], "loot": [0, 0], "sprite": "patrol"},
	"hunter": {"name": "Bounty hunter", "hull": 90, "dmg": [10, 18], "loot": [800, 1600], "sprite": "hunter"},
}

## Story cards: [picture, title, lines]. Shown full screen, one line at a time.
const STORY := {
	"prologue": [
		["earth", "Earth, 2189", "The oceans boiled off. The mines ran dry. The last cities emptied in a single year."],
		["moon", "The Moon", "Everyone who could pay went up. The rest went up anyway, and owed for it."],
		["port_moon", "Luna Port", "You fly a tired courier called the Moth. You owe Mother Kessel 3,000 credits."],
		["port_moon", "Mother Kessel", "\"Run my cargo, keep your mouth shut, and pay me back. Or I sell your ship for parts.\""],
	],
	"done_m01": [
		["world_water", "Tidewater", "Nobody scanned you. The buyer paid in dirty credits: they spend on the black market, not in legal shops."],
		["world_water", "Black market", "Every port with a black market now trades with you. Clean your money at Kessel's laundry on Luna."],
	],
	"done_m02": [
		["port_moon", "Paid in full", "Kessel counts the credits twice. \"A coded message came for you. Old Earth. Ask for Marrow.\""],
	],
	"done_m03": [
		["earth", "Old Earth", "In the wreck ring, a ship hangs dark. Inside, an old smuggler is dying."],
		["ship_layout", "Old Marrow", "\"She's yours. They can't see you. Don't let them find out why.\""],
		["ship_layout", "The Runner", "You have a new ship, the Runner, with a strange core of Hollow make: the Ghost Core."],
	],
	"vane": [
		["port_dock", "Marshal Idris Vane", "\"A ship nobody can see. Interesting. I'll be watching the places you can't hide.\""],
	],
	"done_m04": [
		["sky_dragon", "Act I complete", "The Ghost Core works. Every authority, pirate and company will want it."],
		["sky_milkyway", "Black Lanes", "Act II, the other galaxies and the rest of the story come in a later update. The lanes stay open: keep running."],
	],
	"captured": [
		["port_moon", "Caught", "They took your cargo and half your dirty credits, then towed what was left of you to Luna."],
	],
}

## Net worth goal for the endgame (design doc §1).
const GOAL_NET_WORTH := 1000000000
