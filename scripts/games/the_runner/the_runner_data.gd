extends RefCounted

## The Runner's world as data: goods, sectors and planets, hull tiers, parts, the skill tree, market
## events, enemy ships and the story cards. The people of the Spiral (races, perks, factions, crew,
## quests) live in the_runner_spiral.gd. The owner's design doc v2 (docs/runner/
## GAME_DESIGN_THE_RUNNER_V2.md §0) asks for JSON files under /data; the hub's translation tool reads
## English text from .gd files only, so the same tables live here as constants (DECISIONS D-3).
## No content is hard-coded in the engine or the screens. Every name and line is English; screens
## show them through tr().

const ART := "res://games/the_runner/art/"

## Design doc v2 §0 config flags.
const CONFIG := {"starting_perk_picks": 2, "crew_flaw_strength": 0.5, "perk_stack_cap": 2,
	"battle_mode": "realtime", "faction_rep_min": -500, "faction_rep_max": 1000}

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

## Heat (0..100) with the Luminary Accord's patrols: every Paragon world scans ships (design doc v2
## §8: Outlaw actions raise Heat). One bar for the whole Accord (DECISIONS D-21).
const POLICE := ["accord"]

## Sectors (design doc v2 §9). Each is one of the owner's orbit pictures; planets sit on the
## picture's own planets (positions in that picture's pixels). "gate": the jump point to the other
## sectors. "unlock": the flag that opens the sector ("" = open from the start). Hollow Deep (Act III)
## is listed but locked: not built yet.
const SECTORS := {
	"cradle_reach": {"name": "Cradle Reach", "map": "system_1", "size": [1365, 768], "gate": [1261, 400],
		"unlock": "", "hazards": [
			{"id": "sun", "name": "Cradle Sun", "pos": [684, 380], "r": 112, "kind": "sun"},
			{"id": "maw", "name": "The Maw", "pos": [930, 393], "r": 34, "kind": "black_hole"}]},
	"veil_expanse": {"name": "Veil Expanse", "map": "system_2", "size": [1408, 768], "gate": [95, 690],
		"unlock": "act1_done", "hazards": [
			{"id": "pale_star", "name": "The Pale Star", "pos": [703, 368], "r": 100, "kind": "sun"}]},
	"ember_drift": {"name": "Ember Drift", "map": "system_3", "size": [1408, 768], "gate": [95, 690],
		"unlock": "act1_done", "hazards": [
			{"id": "white_star", "name": "Ember Star", "pos": [703, 368], "r": 68, "kind": "sun"}]},
	"hollow_deep": {"name": "Hollow Deep", "map": "system_blackhole", "size": [1408, 792], "gate": [100, 700],
		"unlock": "act3", "hazards": [],
		"planned": ["Hollow Gate Alpha", "Architect Ruins", "The Ledger Core"]},
}
const SECTOR_ORDER := ["cradle_reach", "veil_expanse", "ember_drift", "hollow_deep"]

## Planets. law 0 (lawless) .. 5 (total surveillance). "black": has a black market. "blind": the
## Ledger can't see it (heat cools twice as fast). "makes" / "wants": price factors (below 1 = cheap
## here). "faction": who holds it ("none" = independent). "view": arrival picture, "dock": port picture.
## Services: market, shipyard, fixer (contracts), front (laundry), fuel, salvage, office (faction office:
## rep repair), collector (Mother Kessel's debt).
const WORLDS := {
	# ---- Sector 1: Cradle Reach (start)
	"cradle_station": {"name": "Cradle Station", "sector": "cradle_reach",
		"desc": "The hub of the Reach: a Concord station where every lane starts. Kessel's collector keeps an office by the docks.",
		"faction": "terran_concord", "law": 3, "black": true, "blind": false, "pos": [340, 130], "r": 40,
		"view": "moon", "dock": "port_moon", "services": ["market", "shipyard", "fixer", "front", "fuel", "office", "collector"],
		"makes": {"food": 0.8, "electronics": 0.85}, "wants": {"ore": 1.25, "water": 1.3, "relics": 1.2}},
	"scrapyard_gamma": {"name": "Scrapyard Gamma", "sector": "cradle_reach",
		"desc": "A dead world in a ring of wrecks. Nobody comes here. That's the point.",
		"faction": "none", "law": 0, "black": true, "blind": true, "pos": [1089, 637], "r": 42,
		"view": "earth", "dock": "port_dock", "services": ["market", "salvage", "fuel"],
		"makes": {"stolen_tech": 0.7, "alloys": 0.8, "ore": 0.8}, "wants": {"food": 1.4, "water": 1.3, "medicine": 1.3}},
	"frostline": {"name": "Frostline", "sector": "cradle_reach",
		"desc": "An ice colony under Concord guard. Cold, strict and hungry.",
		"faction": "terran_concord", "law": 4, "black": false, "blind": false, "pos": [311, 345], "r": 16,
		"view": "world_ice", "dock": "port_dock", "services": ["market", "fuel", "fixer"],
		"makes": {"water": 0.5}, "wants": {"food": 1.35, "medicine": 1.6, "electronics": 1.2}},
	"port_vermillion": {"name": "Port Vermillion", "sector": "cradle_reach",
		"desc": "A lava-lit pirate haven. Every crew in the Reach drinks from the same rumours here.",
		"faction": "none", "law": 1, "black": true, "blind": false, "pos": [391, 260], "r": 16,
		"view": "world_fire", "dock": "port_hangar", "services": ["market", "shipyard", "fuel", "fixer"],
		"makes": {"ore": 0.6, "weapons": 0.7}, "wants": {"food": 1.4, "water": 1.5, "medicine": 1.3, "forged_ids": 1.35}},
	"brass_garden": {"name": "Brass Garden", "sector": "cradle_reach",
		"desc": "The Verdant Canopy's jungle world: brass domes over living forests.",
		"faction": "verdant_canopy", "law": 2, "black": false, "blind": false, "pos": [1000, 187], "r": 16,
		"view": "world_jungle", "dock": "port_hangar", "services": ["market", "fixer", "fuel", "office"],
		"makes": {"food": 0.6, "medicine": 0.8}, "wants": {"alloys": 1.3, "electronics": 1.3, "ore": 1.2}},
	# ---- Sector 2: Veil Expanse (Paragon heartland)
	"aerie_spire": {"name": "Aerie Spire", "sector": "veil_expanse",
		"desc": "The Kestrai sky-city, a spire in the rings of a gas giant. Fast ships, faster pilots.",
		"faction": "high_aerie", "law": 3, "black": false, "blind": false, "pos": [1015, 270], "r": 55,
		"view": "world_rocky", "dock": "port_dock", "services": ["market", "shipyard", "fixer", "fuel", "office"],
		"makes": {"electronics": 0.8, "alloys": 0.9}, "wants": {"food": 1.4, "medicine": 1.3, "ore": 1.2}},
	"chorus_nebula": {"name": "Chorus Nebula", "sector": "veil_expanse",
		"desc": "A singing nebula around a pale moon. The Deepcourt listens to it and writes down every note.",
		"faction": "thalassi_deepcourt", "law": 2, "black": false, "blind": false, "pos": [1240, 110], "r": 45,
		"view": "sky_milkyway", "dock": "port_hangar", "services": ["market", "fixer", "fuel"],
		"makes": {"medicine": 0.8, "water": 0.8}, "wants": {"electronics": 1.35, "alloys": 1.2}},
	"abyssal_reef": {"name": "Abyssal Reef", "sector": "veil_expanse",
		"desc": "An ocean giant. The Thalassi Deepcourt rules from cities on the sea floor.",
		"faction": "thalassi_deepcourt", "law": 3, "black": false, "blind": false, "pos": [1040, 455], "r": 85,
		"view": "world_water", "dock": "port_hangar", "services": ["market", "shipyard", "fixer", "fuel", "office"],
		"makes": {"water": 0.5, "food": 0.7}, "wants": {"alloys": 1.3, "electronics": 1.4, "ore": 1.25}},
	"sunken_orbital": {"name": "Sunken Orbital", "sector": "veil_expanse",
		"desc": "A Concord orbital half-dragged into a blue world's sky. The workers keep it flying.",
		"faction": "terran_concord", "law": 3, "black": false, "blind": false, "pos": [352, 472], "r": 52,
		"view": "world_asteroid", "dock": "port_dock", "services": ["market", "fixer", "fuel", "shipyard"],
		"makes": {"alloys": 0.75, "ore": 0.8}, "wants": {"medicine": 1.45, "food": 1.3, "water": 1.2}},
	"halcyon_core": {"name": "Halcyon Core", "sector": "veil_expanse",
		"desc": "A white world wrapped in servers. The Synthesis thinks here, all at once.",
		"faction": "synthesis", "law": 5, "black": false, "blind": false, "pos": [120, 397], "r": 35,
		"view": "world_ice", "dock": "port_moon", "services": ["market", "shipyard", "fixer", "fuel", "office"],
		"makes": {"electronics": 0.55, "alloys": 0.85}, "wants": {"ore": 1.35, "water": 1.3, "food": 1.1}},
	"sunspire_citadel": {"name": "Sunspire Citadel", "sector": "veil_expanse",
		"desc": "A fortress on a burning world, home of the Sunscale Covenant and its duels of honour.",
		"faction": "sunscale_covenant", "law": 4, "black": false, "blind": false, "pos": [885, 362], "r": 35,
		"view": "world_sandy", "dock": "port_moon", "services": ["market", "fixer", "fuel", "office"],
		"makes": {"alloys": 0.8, "ore": 0.85}, "wants": {"medicine": 1.5, "food": 1.3, "electronics": 1.25}},
	# ---- Sector 3: Ember Drift (Outlaw heartland)
	"drift_market": {"name": "Drift Market", "sector": "ember_drift",
		"desc": "A grey moon of tents and docks. The Veilbound sell everything here, including secrets.",
		"faction": "veilbound", "law": 1, "black": true, "blind": false, "pos": [807, 393], "r": 22,
		"view": "world_asteroid", "dock": "port_hangar", "services": ["market", "shipyard", "fixer", "fuel", "office"],
		"makes": {"forged_ids": 0.6, "bootleg_data": 0.7}, "wants": {"food": 1.4, "electronics": 1.3, "weapons": 1.25}},
	"bloomfall": {"name": "Bloomfall", "sector": "ember_drift",
		"desc": "A pale giant under a skin of fungus. The Bloom grows everywhere it lands.",
		"faction": "bloom", "law": 1, "black": true, "blind": false, "pos": [1040, 455], "r": 85,
		"view": "world_fungus", "dock": "port_dock", "services": ["market", "fixer", "fuel", "office"],
		"makes": {"medicine": 0.6, "food": 0.7}, "wants": {"relics": 1.6, "alloys": 1.25, "bootleg_data": 1.3}},
	"wreck_of_the_starlight": {"name": "Wreck of the Starlight", "sector": "ember_drift",
		"desc": "A liner that died in the rubble years ago. Salvagers pick at it; the Ledger never looks.",
		"faction": "none", "law": 0, "black": false, "blind": true, "pos": [1150, 428], "r": 16,
		"view": "hazard_meteors", "dock": "port_dock", "services": ["salvage", "fuel"], "makes": {}, "wants": {}},
	"meridian_station": {"name": "Meridian Station", "sector": "ember_drift",
		"desc": "The Black Meridian Syndicate's blue jewel. Mother Kessel runs it from the top floor.",
		"faction": "black_meridian", "law": 2, "black": true, "blind": false, "pos": [352, 472], "r": 52,
		"view": "port_moon", "dock": "port_moon", "services": ["market", "shipyard", "fixer", "front", "fuel", "office"],
		"makes": {"electronics": 0.8, "forged_ids": 0.8}, "wants": {"weapons": 1.3, "stolen_tech": 1.3, "food": 1.25}},
	"the_gilded_rock": {"name": "The Gilded Rock", "sector": "ember_drift",
		"desc": "A casino on a hot rock. The house always wins, unless the house is rigged.",
		"faction": "veilbound", "law": 1, "black": true, "blind": false, "pos": [885, 362], "r": 35,
		"view": "world_sandy", "dock": "port_hangar", "services": ["market", "fixer", "fuel"],
		"makes": {"electronics": 0.9}, "wants": {"relics": 1.5, "stolen_tech": 1.4, "medicine": 1.3, "food": 1.2}},
	"null_point": {"name": "Null Point", "sector": "ember_drift",
		"desc": "A cold world nobody claims, where the Ledger's lines go dark.",
		"faction": "none", "law": 0, "black": true, "blind": true, "pos": [120, 397], "r": 35,
		"view": "sky_dragon", "dock": "port_dock", "services": ["market", "fuel", "shipyard"],
		"makes": {"stolen_tech": 0.6, "weapons": 0.6}, "wants": {"food": 1.5, "water": 1.4, "medicine": 1.5}},
	"brimstone_reach": {"name": "Brimstone Reach", "sector": "ember_drift",
		"desc": "Red rock and contracts. The Sskarn Hunt-Guilds sell a hunt to anyone who pays.",
		"faction": "hunt_guilds", "law": 1, "black": true, "blind": false, "pos": [445, 612], "r": 55,
		"view": "world_fire", "dock": "port_hangar", "services": ["market", "fixer", "fuel", "office", "shipyard"],
		"makes": {"weapons": 0.6, "ore": 0.6}, "wants": {"food": 1.4, "medicine": 1.4, "electronics": 1.3}},
	"the_cinder_fort": {"name": "The Cinder Fort", "sector": "ember_drift",
		"desc": "Queen Vask's ringed fortress. Tribute goes in; raiders come out.",
		"faction": "ashscale_warbands", "law": 2, "black": true, "blind": false, "pos": [1015, 270], "r": 55,
		"view": "world_rocky", "dock": "port_dock", "services": ["market", "fixer", "fuel", "office"],
		"makes": {"ore": 0.5, "alloys": 0.8}, "wants": {"food": 1.45, "water": 1.4, "medicine": 1.35, "forged_ids": 1.3}},
}
const WORLD_ORDER := ["cradle_station", "scrapyard_gamma", "frostline", "port_vermillion", "brass_garden",
	"aerie_spire", "chorus_nebula", "abyssal_reef", "sunken_orbital", "halcyon_core", "sunspire_citadel",
	"drift_market", "bloomfall", "wreck_of_the_starlight", "meridian_station", "the_gilded_rock", "null_point",
	"brimstone_reach", "the_cinder_fort"]
const START_WORLD := "cradle_station"
const HUB_WORLD := "cradle_station"   # Kessel's collector, the tow and the safety net

## Ships (design doc v2 §6). The Moth is the rented skiff you start with; Old Marrow's Runner comes with
## quest N03, starts as a Skiff and is refitted through the tiers. It keeps its Ghost Core through
## every refit. Part slots: how many weapons / engines / shields / special parts are fitted.
const SHIPS := {
	"moth": {"name": "The Moth", "desc": "Kessel's rented skiff. It flies. Mostly.", "tier": 1,
		"cargo": 8, "hidden": 2, "tank": 12, "hull": 60, "stealth": 0, "crew": 1,
		"weapons": 1, "engines": 1, "shields": 1, "special": 1, "ghost": false},
}
const TIERS := [
	{"tier": 1, "name": "Skiff", "mk": "Runner Mk I", "cost": 0, "crew": 1, "weapons": 2, "engines": 1, "shields": 1, "special": 1,
		"cargo": 14, "hidden": 4, "tank": 18, "hull": 100, "stealth": 2},
	{"tier": 2, "name": "Courier", "mk": "Runner Mk II", "cost": 25000, "crew": 2, "weapons": 3, "engines": 2, "shields": 2, "special": 2,
		"cargo": 22, "hidden": 6, "tank": 24, "hull": 160, "stealth": 2},
	{"tier": 3, "name": "Corvette", "mk": "Runner Mk III", "cost": 150000, "crew": 3, "weapons": 4, "engines": 2, "shields": 3, "special": 3,
		"cargo": 34, "hidden": 9, "tank": 30, "hull": 260, "stealth": 1},
	{"tier": 4, "name": "Cruiser", "mk": "Runner Mk IV", "cost": 1000000, "crew": 4, "weapons": 6, "engines": 3, "shields": 4, "special": 4,
		"cargo": 50, "hidden": 14, "tank": 40, "hull": 420, "stealth": 1},
]
## The Runner's Ghost Core: hides it from the Ledger.
const GHOST_STEALTH := 3

## Part models. One model per kind is fitted to every socket of that kind (2 weapon sockets with a
## Rail Gun = two rail guns). Specials are separate parts, one per special socket.
const SLOTS := ["engine", "cargo", "hidden", "shields", "weapons", "scanner"]
const SLOT_NAMES := {"engine": "Engines", "cargo": "Cargo racks", "hidden": "Hidden hold", "shields": "Shields",
	"weapons": "Weapons", "scanner": "Scanner", "special": "Special"}
## "money": what pays for it ("clean" legal shipyards, "dirty" black-market ones). "shop": "legal" or
## "black". Effects: fuel (fuel use factor), cargo, hidden, quality (hidden hold), shield (per socket),
## dmg (per shot factor), energy (energy weapon: Cold Reactor and the Synthesis cut its cooldown),
## scan (scan pass bonus), sniff (shows patrol risk), stealth, flee (escape bonus), speed,
## salvage, regen (hull per minute in flight).
const MODULES := {
	"eng_1": {"slot": "engine", "name": "Ion Drive", "price": 0, "money": "clean", "shop": "", "fuel": 1.0},
	"eng_2": {"slot": "engine", "name": "Fusion Drive", "price": 3000, "money": "clean", "shop": "legal", "fuel": 0.8, "flee": 0.05, "speed": 0.05},
	"eng_3": {"slot": "engine", "name": "Rift Skimmer", "price": 9000, "money": "dirty", "shop": "black", "fuel": 0.6, "flee": 0.12, "speed": 0.10},
	"car_1": {"slot": "cargo", "name": "Standard Racks", "price": 0, "money": "clean", "shop": "", "cargo": 0},
	"car_2": {"slot": "cargo", "name": "Expanded Racks", "price": 2500, "money": "clean", "shop": "legal", "cargo": 6},
	"car_3": {"slot": "cargo", "name": "Cargo Spine", "price": 8000, "money": "clean", "shop": "legal", "cargo": 12},
	"hid_1": {"slot": "hidden", "name": "False Floor", "price": 0, "money": "clean", "shop": "", "hidden": 0, "quality": 0},
	"hid_2": {"slot": "hidden", "name": "Smuggler's Wall", "price": 3500, "money": "dirty", "shop": "black", "hidden": 4, "quality": 1},
	"hid_3": {"slot": "hidden", "name": "Phase Locker", "price": 12000, "money": "dirty", "shop": "black", "hidden": 8, "quality": 2},
	"shd_1": {"slot": "shields", "name": "Deflector", "price": 0, "money": "clean", "shop": "", "shield": 8},
	"shd_2": {"slot": "shields", "name": "Aegis Shield", "price": 4000, "money": "clean", "shop": "legal", "shield": 20},
	"shd_3": {"slot": "shields", "name": "Bastion Shield", "price": 11000, "money": "clean", "shop": "legal", "shield": 40},
	"wpn_1": {"slot": "weapons", "name": "Pulse Cannon", "price": 0, "money": "clean", "shop": "", "dmg": 1.0, "energy": true},
	"wpn_2": {"slot": "weapons", "name": "Rail Gun", "price": 5000, "money": "dirty", "shop": "black", "dmg": 1.5, "energy": false},
	"wpn_3": {"slot": "weapons", "name": "Plasma Lance", "price": 14000, "money": "dirty", "shop": "black", "dmg": 2.0, "energy": true},
	"scn_1": {"slot": "scanner", "name": "Basic Scanner", "price": 0, "money": "clean", "shop": "", "scan": 0.0},
	"scn_2": {"slot": "scanner", "name": "Patrol Sniffer", "price": 3000, "money": "clean", "shop": "legal", "scan": 0.05, "sniff": true},
	"scn_3": {"slot": "scanner", "name": "Ledger Tap", "price": 9000, "money": "dirty", "shop": "black", "scan": 0.10, "sniff": true},
	"spc_ecm": {"slot": "special", "name": "ECM Jammer", "price": 6000, "money": "dirty", "shop": "black", "flee": 0.25},
	"spc_veil": {"slot": "special", "name": "Veil Plating", "price": 8000, "money": "dirty", "shop": "black", "stealth": 1},
	"spc_tractor": {"slot": "special", "name": "Tractor Beam", "price": 5000, "money": "clean", "shop": "legal", "salvage": 0.25},
	"spc_nanites": {"slot": "special", "name": "Repair Nanites", "price": 7000, "money": "clean", "shop": "legal", "regen": 0.01},
}
const START_MODULES := {"engine": "eng_1", "cargo": "car_1", "hidden": "hid_1", "shields": "shd_1",
	"weapons": "wpn_1", "scanner": "scn_1"}

## Skill tree (kept beside v2's perks, owner 2026-11-07): the six specializations of the first
## design doc §7.2, the XP level-up track. The first branch you spend a point in is your primary, the
## second your secondary; the others stay closed. Each branch: 3 ranks in order.
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
		{"id": "fo_ghost", "name": "Ghost Identity", "desc": "Once per run: wipe your heat (Stats tab)."},
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

## Heat (0..100).
const HEAT_TIERS := [[20, "Ignored"], [40, "Watched"], [60, "Wanted"], [80, "Hunted"], [101, "Public Enemy"]]

## Market events: a world's prices move for a few days. "goods": which goods ("contraband" / "legal" /
## an id), "mult": price factor, "law": extra law level while it lasts.
const EVENTS := [
	{"id": "crackdown", "name": "Crackdown", "text": "Accord crackdown at %s: contraband sells high, patrols everywhere.", "goods": "contraband", "mult": 1.4, "law": 1},
	{"id": "festival", "name": "Festival", "text": "Festival on %s: food and med kits in demand.", "goods": "festival", "mult": 1.5, "law": 0},
	{"id": "shortage", "name": "Shortage", "text": "Shortage of %s on %s: prices up.", "goods": "one", "mult": 1.8, "law": 0},
	{"id": "glut", "name": "Glut", "text": "Too much %s on %s: prices down.", "goods": "one", "mult": 0.6, "law": 0},
	{"id": "strike", "name": "Strike", "text": "Miners' strike on %s: ore and alloys up.", "goods": "strike", "mult": 1.5, "law": 0},
]

## Enemy ships for real-time battles (design doc v2 §1.3: enemies use the same ship system, bigger
## enemy = more parts). Per ship: hull, shield, guns (sockets), dmg (per shot), acc (hit chance),
## eva (evasion), speed (arena units / s). "ships": how many fly together. "loot": dirty credits
## (min, max) for the whole wing. "faction": whose ships ("none" = independent). "lethal": false =
## a duel, they stop at your last hull point. "board": can be boarded when crippled.
const ENEMIES := {
	"pirate": {"name": "Raiders", "faction": "none", "ships": 1, "hull": 40, "shield": 0, "guns": 1, "dmg": 6,
		"acc": 0.65, "eva": 0.10, "speed": 150, "loot": [300, 900], "sprite": "space/enemy_black_1", "board": true},
	"patrol": {"name": "Accord patrol", "faction": "terran_concord", "ships": 1, "hull": 70, "shield": 10, "guns": 2, "dmg": 5,
		"acc": 0.65, "eva": 0.10, "speed": 140, "loot": [0, 0], "sprite": "space/enemy_blue_2"},
	"hunter": {"name": "Bounty hunter", "faction": "hunt_guilds", "ships": 1, "hull": 90, "shield": 15, "guns": 2, "dmg": 6,
		"acc": 0.7, "eva": 0.15, "speed": 170, "loot": [800, 1600], "sprite": "space/enemy_red_3"},
	"duelist": {"name": "Sunscale duelist", "faction": "sunscale_covenant", "ships": 1, "hull": 80, "shield": 20, "guns": 2, "dmg": 5,
		"acc": 0.7, "eva": 0.15, "speed": 160, "loot": [0, 0], "sprite": "space/enemy_green_4", "lethal": false},
	"saboteur": {"name": "Saboteur's skiff", "faction": "none", "ships": 1, "hull": 50, "shield": 0, "guns": 1, "dmg": 6,
		"acc": 0.6, "eva": 0.15, "speed": 170, "loot": [400, 800], "sprite": "space/enemy_black_2", "board": true},
	"ashscale_raider": {"name": "Ashscale raiders", "faction": "ashscale_warbands", "ships": 2, "hull": 50, "shield": 5, "guns": 1, "dmg": 6,
		"acc": 0.65, "eva": 0.10, "speed": 150, "loot": [500, 1200], "sprite": "space/enemy_red_1", "board": true},
	"ashscale_hacker": {"name": "Ashscale hack-runner", "faction": "ashscale_warbands", "ships": 1, "hull": 60, "shield": 10, "guns": 1, "dmg": 5,
		"acc": 0.65, "eva": 0.20, "speed": 180, "loot": [300, 700], "sprite": "space/enemy_red_2"},
	"veil_rival": {"name": "Veilbound rival", "faction": "veilbound", "ships": 1, "hull": 70, "shield": 10, "guns": 2, "dmg": 5,
		"acc": 0.65, "eva": 0.20, "speed": 170, "loot": [600, 1400], "sprite": "space/enemy_black_3", "board": true},
	"raider_base": {"name": "Raider nest", "faction": "none", "ships": 3, "hull": 45, "shield": 0, "guns": 1, "dmg": 6,
		"acc": 0.6, "eva": 0.10, "speed": 140, "loot": [1500, 3000], "sprite": "space/enemy_black_4", "board": true},
	"mine_layer": {"name": "Mine-layers", "faction": "none", "ships": 2, "hull": 40, "shield": 0, "guns": 1, "dmg": 5,
		"acc": 0.6, "eva": 0.10, "speed": 120, "loot": [300, 800], "sprite": "space/enemy_black_5"},
	"hauler": {"name": "Armed hauler", "faction": "terran_concord", "ships": 1, "hull": 120, "shield": 20, "guns": 1, "dmg": 5,
		"acc": 0.6, "eva": 0.05, "speed": 100, "loot": [2000, 4000], "sprite": "space/enemy_blue_5", "board": true},
	"accord_cruiser": {"name": "Accord cruiser", "faction": "terran_concord", "ships": 1, "hull": 180, "shield": 40, "guns": 4, "dmg": 6,
		"acc": 0.65, "eva": 0.05, "speed": 110, "loot": [1000, 2500], "sprite": "space/enemy_blue_4"},
	"accord_flagship": {"name": "Accord flagship", "faction": "terran_concord", "ships": 1, "hull": 320, "shield": 60, "guns": 6, "dmg": 6,
		"acc": 0.65, "eva": 0.05, "speed": 100, "loot": [5000, 9000], "sprite": "space/enemy_blue_3"},
	"verdant_guard": {"name": "Canopy guard", "faction": "verdant_canopy", "ships": 2, "hull": 70, "shield": 15, "guns": 1, "dmg": 6,
		"acc": 0.65, "eva": 0.10, "speed": 130, "loot": [500, 1000], "sprite": "space/enemy_green_1"},
	"ashscale_armada": {"name": "Ashscale war-wing", "faction": "ashscale_warbands", "ships": 3, "hull": 90, "shield": 15, "guns": 2, "dmg": 6,
		"acc": 0.65, "eva": 0.10, "speed": 150, "loot": [3000, 6000], "sprite": "space/enemy_red_4"},
	"accord_armada": {"name": "Accord battle line", "faction": "terran_concord", "ships": 3, "hull": 110, "shield": 25, "guns": 2, "dmg": 6,
		"acc": 0.65, "eva": 0.05, "speed": 120, "loot": [4000, 8000], "sprite": "space/enemy_blue_1"},
	"warship": {"name": "Faction warships", "faction": "", "ships": 2, "hull": 80, "shield": 15, "guns": 2, "dmg": 5,
		"acc": 0.65, "eva": 0.10, "speed": 140, "loot": [400, 1000], "sprite": "space/enemy_green_2"},
}

## Story cards: [picture, title, lines]. Shown full screen, one line at a time. "%s" in a line is the
## captain's name.
const STORY := {
	"prologue": [
		["sky_milkyway", "The Spiral", "Eons ago the Architects seeded life across a chain of galaxies joined by Gates, and built the Ledger to record every world, trade and life."],
		["sky_dragon", "The Silence", "Then they went silent and the Gates went dark. Three hundred years ago the Gates woke up, and nine species who had never met poured through."],
		["system_1", "Two blocs", "The Luminary Accord keeps the law and the Ledger. The Eclipse Pact lives in its blind spots. The Sskarn Hunt-Guilds sell to both."],
		["port_moon", "Cradle Station", "You are %s, a small-time courier flying a rented skiff, the Moth. You owe Mother Kessel 3,000 credits."],
		["port_moon", "Kessel's collector", "\"Run the dockmaster's cargo, keep your mouth shut, and pay Mother back. Or the Moth goes for parts.\""],
	],
	"done_n01": [
		["world_ice", "Frostline", "Cargo delivered. The dockmaster knows a man who knows a man: every port with a black market will now trade with you."],
		["world_ice", "Dirty credits", "Black markets pay in dirty credits: they spend on contraband, black-market parts, bribes and debts, not in legal shops. Wash them at the laundry on Cradle Station."],
	],
	"done_n02": [
		["port_moon", "Paid in full", "The collector counts the credits twice. \"Mother's pleased. And a message came for you: Scrapyard Gamma. Ask for Marrow.\""],
	],
	"done_n03": [
		["earth", "Scrapyard Gamma", "In the wreck ring, a ship hangs dark. Inside, an old smuggler is dying."],
		["ship_layout", "Old Marrow", "\"She's yours. They can't see you. Don't let them find out why.\""],
		["ship_layout", "The Runner", "You have a new ship, the Runner, a Skiff with a strange core of Architect make: the Ghost Core. Shipyards can refit her into bigger hulls."],
	],
	"vane": [
		["port_dock", "Marshal Idris Vane", "\"A ship the Ledger can't see. Interesting. I'll be watching the places you can't hide.\""],
	],
	"done_n04": [
		["sky_dragon", "Act I complete", "The Ghost Core works. Every faction in the Spiral will want it."],
		["system_2", "The Gates open", "The gate at the edge of the Reach now takes you to the Veil Expanse (the Accord's heartland) and the Ember Drift (the Pact's)."],
		["sky_milkyway", "Fractured Lanes", "Act II, the Ledger's secret and the Hollow Deep come in a later update. Until then: build your crew, pick your side, keep running."],
	],
	"captured": [
		["port_moon", "Caught", "They took your cargo and half your dirty credits, then towed what was left of you to Cradle Station."],
	],
}

## Net worth goal (first design doc §1).
const GOAL_NET_WORTH := 1000000000
