extends RefCounted

## The people of the Spiral (design doc v2, docs/runner/GAME_DESIGN_THE_RUNNER_V2.md §3, §5, §7, §8,
## §10, §11): races, good perks and flaws, the ten factions and their rep bonuses, the Paragon and
## Outlaw bars, the 16 recruitable crew and every quest with its reward values. The doc's tables are
## the source of truth; quest steps (what you actually do) are filled in here (DECISIONS D-26).
## Perk effects ("fx") are additive fractions on a stat (0.15 = +15%); stats are read by the engine's
## stat(). Every name and line is English; screens show them through tr().

# ================================================================ races (§3)

## "playable": false = NPC only (Sskarn). "homes": the home faction(s) you may pick at creation.
const RACES := {
	"terran": {"name": "Terran", "type": "Human", "playable": true, "homes": ["terran_concord", "black_meridian"],
		"perks": ["G05", "G30"], "flaw": "B12", "hostile": [], "color": "8fc9ff",
		"flavor": "Adaptable, everywhere, expensive crew."},
	"synthari": {"name": "Synthari", "type": "Cyborg / AI", "playable": true, "homes": ["synthesis"],
		"perks": ["G04", "G18"], "flaw": "B06", "hostile": ["mycelari", "noctari"], "color": "7dfff0",
		"flavor": "Machine minds and cyborgs; they calculate everything."},
	"kestrai": {"name": "Kestrai", "type": "Avian", "playable": true, "homes": ["high_aerie"],
		"perks": ["G03", "G24"], "flaw": "B01", "hostile": ["sskarn"], "color": "ffd27a",
		"flavor": "Hollow-boned sky-nomads; the best flyers."},
	"sskarn": {"name": "Sskarn", "type": "Feral reptilian", "playable": false, "homes": ["hunt_guilds"],
		"perks": ["G01", "G22"], "flaw": "B03", "hostile": ["kestrai"], "color": "ff8a5a",
		"flavor": "Predator mercenaries; they take any contract."},
	"mycelari": {"name": "Mycelari", "type": "Fungal", "playable": true, "homes": ["bloom"],
		"perks": ["G25", "G17"], "flaw": "B11", "hostile": ["synthari", "thalassi", "verdanti"], "color": "d9a8ff",
		"flavor": "Hive-mycelium: consume, regrow, spread."},
	"verdanti": {"name": "Verdanti", "type": "Plant-like", "playable": true, "homes": ["verdant_canopy"],
		"perks": ["G13", "G11"], "flaw": "B09", "hostile": ["mycelari"], "color": "7ddc6a",
		"flavor": "Living trees: tough, efficient, slow."},
	"thalassi": {"name": "Thalassi", "type": "Aquatic humanoid", "playable": true, "homes": ["thalassi_deepcourt"],
		"perks": ["G28", "G12"], "flaw": "B08", "hostile": ["mycelari", "ssaryn"], "color": "4fb8ff",
		"flavor": "Deep-water cartographers; surface money confuses them."},
	"ssaryn": {"name": "Ssaryn", "type": "Reptilian humanoid", "playable": true, "homes": ["sunscale_covenant", "ashscale_warbands"],
		"perks": ["G06", "G14"], "flaw": "B14", "hostile": ["thalassi"], "color": "ffb547",
		"flavor": "Two clans, one blood, one old war."},
	"noctari": {"name": "Noctari", "type": "Shadow humanoid", "playable": true, "homes": ["veilbound"],
		"perks": ["G02", "G08"], "flaw": "B07", "hostile": ["synthari"], "color": "b38cff",
		"flavor": "Dim-world dwellers: forgers, spies, thieves."},
}
const RACE_ORDER := ["terran", "synthari", "kestrai", "mycelari", "verdanti", "thalassi", "ssaryn", "noctari", "sskarn"]
const GENDERS := ["Male", "Female", "Non-binary", "Other"]
## Optional synergy (§3.1): +3% to a stat while both races are aboard. "any" = with any other race.
const SYNERGY := [["terran", "any", "faction_gain"], ["synthari", "verdanti", "hull"], ["kestrai", "thalassi", "speed"],
	["mycelari", "noctari", "stealth"], ["ssaryn", "sskarn", "boarding"]]
const SYNERGY_BONUS := 0.03

# ================================================================ perks (§5)

## Good perks (31) and flaws (15). "fx": stat -> additive fraction. Flags (1 = on): hack (disable one
## enemy system per battle), lucky (once per run, ignore a failed scan or a capture), scare (weak
## enemies flee earlier), first_shot (you fire first), reveal (every world's prices in the Map tab),
## quest_slots (more active quests).
const PERKS := {
	"G01": {"name": "Bounty Hunter", "kind": "good", "desc": "+50% credits on Bounty missions", "fx": {"bounty_credits": 0.5}},
	"G02": {"name": "Stealthy", "kind": "good", "desc": "+15% stealth (scan pass chance)", "fx": {"stealth": 0.15}},
	"G03": {"name": "Pilot", "kind": "good", "desc": "+15% ship speed, +10% evasion", "fx": {"speed": 0.15, "evasion": 0.10}},
	"G04": {"name": "Engineer", "kind": "good", "desc": "Repairs −30% cost, 40% faster", "fx": {"repair_cost": -0.30, "repair_speed": 0.40}},
	"G05": {"name": "Master Negotiator", "kind": "good", "desc": "+10% credits from missions", "fx": {"mission_credits": 0.10}},
	"G06": {"name": "Sharpshooter", "kind": "good", "desc": "+15% weapon accuracy", "fx": {"accuracy": 0.15}},
	"G07": {"name": "Heavy Gunner", "kind": "good", "desc": "+15% turret damage", "fx": {"turret_damage": 0.15}},
	"G08": {"name": "Smuggler's Hold", "kind": "good", "desc": "+25% hidden cargo capacity", "fx": {"hidden_cap": 0.25}},
	"G09": {"name": "Haggler", "kind": "good", "desc": "−10% buy prices, +10% sell prices", "fx": {"buy_price": -0.10, "sell_price": 0.10}},
	"G10": {"name": "Prospector", "kind": "good", "desc": "+25% rare element find chance, +15% scanner range", "fx": {"rare_find": 0.25, "scanner_range": 0.15}},
	"G11": {"name": "Navigator", "kind": "good", "desc": "−20% fuel use, +10% jump range", "fx": {"fuel_use": -0.20, "tank": 0.10}},
	"G12": {"name": "Shieldwright", "kind": "good", "desc": "+20% shield capacity and recharge", "fx": {"shield": 0.20, "shield_regen": 0.20}},
	"G13": {"name": "Iron Hull", "kind": "good", "desc": "+20% hull HP", "fx": {"hull": 0.20}},
	"G14": {"name": "Boarder", "kind": "good", "desc": "+25% boarding success, +15% boarding loot", "fx": {"boarding": 0.25, "boarding_loot": 0.15}},
	"G15": {"name": "Silver Tongue", "kind": "good", "desc": "Bribes cost −30%, bribe success +15%", "fx": {"bribe_cost": -0.30, "bribe_success": 0.15}},
	"G16": {"name": "Quartermaster", "kind": "good", "desc": "+15% cargo capacity", "fx": {"cargo_cap": 0.15}},
	"G17": {"name": "Field Medic", "kind": "good", "desc": "Hull self-repairs 1%/min in flight; crew injuries heal 2×", "fx": {"hull_regen": 0.01, "heal": 1.0}},
	"G18": {"name": "Hacker", "kind": "good", "desc": "Enemy lock-on −20%; disable 1 enemy system per battle", "fx": {"enemy_lock": -0.20, "hack": 1}},
	"G19": {"name": "Lucky", "kind": "good", "desc": "+10% loot rarity; once per run, ignore a critical failure", "fx": {"loot": 0.10, "lucky": 1}},
	"G20": {"name": "Charismatic", "kind": "good", "desc": "+10% faction points gained", "fx": {"faction_gain": 0.10}},
	"G21": {"name": "Inspiring", "kind": "good", "desc": "+25% crew loyalty", "fx": {"crew_loyalty": 0.25}},
	"G22": {"name": "Intimidating", "kind": "good", "desc": "+25% raid tribute; weak enemies flee earlier", "fx": {"raid_tribute": 0.25, "scare": 1}},
	"G23": {"name": "Cold Reactor", "kind": "good", "desc": "Energy weapon cooldown −15%", "fx": {"cooldown": -0.15}},
	"G24": {"name": "Dodge Master", "kind": "good", "desc": "+20% evasion", "fx": {"evasion": 0.20}},
	"G25": {"name": "Cargo Scrapper", "kind": "good", "desc": "+30% salvage yield from wrecks", "fx": {"salvage": 0.30}},
	"G26": {"name": "Tactician", "kind": "good", "desc": "First-shot initiative; +10% allied damage", "fx": {"first_shot": 1, "ally_damage": 0.10}},
	"G27": {"name": "Fence Contact", "kind": "good", "desc": "Black-market sells +15%; laundering fee −10%", "fx": {"black_sell": 0.15, "launder_fee": -0.10}},
	"G28": {"name": "Cartographer", "kind": "good", "desc": "Reveals extra map; survey data sells +30%", "fx": {"reveal": 1, "survey": 0.30}},
	"G29": {"name": "Veteran", "kind": "good", "desc": "+10% XP", "fx": {"xp": 0.10}},
	"G30": {"name": "Efficient Refit", "kind": "good", "desc": "Ship upgrades cost −10%", "fx": {"upgrade_cost": -0.10}},
	"G31": {"name": "Contract Broker", "kind": "good", "desc": "+1 active quest slot", "fx": {"quest_slots": 1}},
	"B01": {"name": "Brittle", "kind": "flaw", "desc": "−15% hull HP", "fx": {"hull": -0.15}},
	"B02": {"name": "Spendthrift", "kind": "flaw", "desc": "+10% buy prices", "fx": {"buy_price": 0.10}},
	"B03": {"name": "Short Fuse", "kind": "flaw", "desc": "Bribe cost +25%", "fx": {"bribe_cost": 0.25}},
	"B04": {"name": "Conspicuous", "kind": "flaw", "desc": "−15% stealth", "fx": {"stealth": -0.15}},
	"B05": {"name": "Fuel Guzzler", "kind": "flaw", "desc": "+25% fuel use", "fx": {"fuel_use": 0.25}},
	"B06": {"name": "Cold Logic", "kind": "flaw", "desc": "−20% crew loyalty", "fx": {"crew_loyalty": -0.20}},
	"B07": {"name": "Glass Jaw", "kind": "flaw", "desc": "−15% shield capacity", "fx": {"shield": -0.15}},
	"B08": {"name": "Poor Haggler", "kind": "flaw", "desc": "−8% sell prices", "fx": {"sell_price": -0.08}},
	"B09": {"name": "Slow Reflexes", "kind": "flaw", "desc": "−15% evasion", "fx": {"evasion": -0.15}},
	"B10": {"name": "Cumbersome Cargo", "kind": "flaw", "desc": "−10% cargo capacity", "fx": {"cargo_cap": -0.10}},
	"B11": {"name": "Marked", "kind": "flaw", "desc": "+15% heat gain", "fx": {"heat_gain": 0.15}},
	"B12": {"name": "Needs Upkeep", "kind": "flaw", "desc": "+20% crew wages", "fx": {"crew_wages": 0.20}},
	"B13": {"name": "Fragile Systems", "kind": "flaw", "desc": "Repairs +20% cost", "fx": {"repair_cost": 0.20}},
	"B14": {"name": "Stubborn", "kind": "flaw", "desc": "−20% flee success", "fx": {"flee": -0.20}},
	"B15": {"name": "Gullible", "kind": "flaw", "desc": "Trap events twice as likely", "fx": {"trap_chance": 1.0}},
}
const GOOD_PERKS := ["G01", "G02", "G03", "G04", "G05", "G06", "G07", "G08", "G09", "G10", "G11", "G12", "G13",
	"G14", "G15", "G16", "G17", "G18", "G19", "G20", "G21", "G22", "G23", "G24", "G25", "G26", "G27", "G28",
	"G29", "G30", "G31"]
const FLAWS := ["B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B09", "B10", "B11", "B12", "B13", "B14", "B15"]
## §5.3: any single stat bonus capped at +60% (good perks and bonuses), flaws at −40%.
const GOOD_CAP := 0.6
const FLAW_CAP := 0.4
## Flags are on/off (or counts), never capped or halved.
const FLAG_STATS := ["hack", "lucky", "scare", "first_shot", "reveal", "quest_slots"]
## Cursed cargo / Faustian bargains (§5.2): the unused flaws come from events. A curse lasts this many days.
const CURSE_FLAWS := ["B02", "B04", "B05", "B10", "B13", "B15"]
const CURSE_DAYS := 6

# ================================================================ factions (§7)

## "bloc": paragon (the Luminary Accord), outlaw (the Eclipse Pact) or neutral. "rivals_lore": lore only,
## never an automatic penalty (§7.4). "bonuses": at 50 / 75 / 100% rep (§7.5), each a text and its fx
## (keys ending "@home" act only at that faction's worlds; "ability": a once-per-run battle call;
## "perk": a free perk).
const FACTIONS := {
	"terran_concord": {"name": "Terran Concord", "bloc": "paragon", "race": "terran", "home": "cradle_station",
		"leader": "Commissioner Hale Okonkwo", "ideology": "Law, order, trade", "rivals_lore": ["black_meridian"],
		"bonuses": {
			"50": {"text": "−15% repair cost at Concord ports; safe dock", "fx": {"repair_cost@home": -0.15, "safe_dock@home": 1}},
			"75": {"text": "Escort wing: 2 patrol ships assist once per run", "fx": {"ability": "escort_wing"}},
			"100": {"text": "Commissioner's Writ: heat decays 2× in Concord space", "fx": {"heat_decay@home": 1.0}}}},
	"synthesis": {"name": "The Synthesis", "bloc": "paragon", "race": "synthari", "home": "halcyon_core",
		"leader": "Prime Node-Ø", "ideology": "Logic, shared mind", "rivals_lore": ["bloom"],
		"bonuses": {
			"50": {"text": "+10% scanner range", "fx": {"scanner_range": 0.10}},
			"75": {"text": "+10% energy weapon damage", "fx": {"energy_damage": 0.10}},
			"100": {"text": "Node Link: hull self-repairs 2%/min; free Hacker perk", "fx": {"hull_regen": 0.02, "perk": "G18"}}}},
	"high_aerie": {"name": "The High Aerie", "bloc": "paragon", "race": "kestrai", "home": "aerie_spire",
		"leader": "Matriarch Sorrel Highwind", "ideology": "Freedom of the sky, rescue", "rivals_lore": ["ashscale_warbands"],
		"bonuses": {
			"50": {"text": "+10% ship speed", "fx": {"speed": 0.10}},
			"75": {"text": "Wingmates: 2 Aerie fighters assist once per run", "fx": {"ability": "wingmates"}},
			"100": {"text": "Skyborn: +15% evasion; free Dodge Master perk", "fx": {"evasion": 0.15, "perk": "G24"}}}},
	"verdant_canopy": {"name": "Verdant Canopy", "bloc": "paragon", "race": "verdanti", "home": "brass_garden",
		"leader": "Elder Oak-of-Seven-Winters", "ideology": "Growth, patience, restoration", "rivals_lore": ["bloom"],
		"bonuses": {
			"50": {"text": "+10% hull HP", "fx": {"hull": 0.10}},
			"75": {"text": "−15% fuel use", "fx": {"fuel_use": -0.15}},
			"100": {"text": "Heartwood: +20% hull HP; hull self-regen", "fx": {"hull": 0.20, "hull_regen": 0.01}}}},
	"thalassi_deepcourt": {"name": "Thalassi Deepcourt", "bloc": "paragon", "race": "thalassi", "home": "abyssal_reef",
		"leader": "Tide-Queen Maren Silverdeep", "ideology": "Knowledge, balance, depths", "rivals_lore": ["ashscale_warbands"],
		"bonuses": {
			"50": {"text": "+10% shield capacity", "fx": {"shield": 0.10}},
			"75": {"text": "Reveals 5 extra systems on map", "fx": {"reveal": 1}},
			"100": {"text": "Deep Blessing: +20% shields; survey data sells +30%", "fx": {"shield": 0.20, "survey": 0.30}}}},
	"sunscale_covenant": {"name": "Sunscale Covenant", "bloc": "paragon", "race": "ssaryn", "home": "sunspire_citadel",
		"leader": "Warden Ixara Sunscale", "ideology": "Honor, duels, protection", "rivals_lore": ["ashscale_warbands"],
		"bonuses": {
			"50": {"text": "+10% weapon accuracy", "fx": {"accuracy": 0.10}},
			"75": {"text": "Honor-duel challenges unlock (big rewards)", "fx": {"duels": 1}},
			"100": {"text": "Sunscale Banner: +10% damage; +15% crew loyalty", "fx": {"weapon_damage": 0.10, "crew_loyalty": 0.15}}}},
	"black_meridian": {"name": "Black Meridian Syndicate", "bloc": "outlaw", "race": "terran", "home": "meridian_station",
		"leader": "Mother Kessel", "ideology": "Profit, debt, protection", "rivals_lore": ["terran_concord"],
		"bonuses": {
			"50": {"text": "Black-market sells +10%", "fx": {"black_sell": 0.10}},
			"75": {"text": "Laundering fee −20%", "fx": {"launder_fee": -0.20}},
			"100": {"text": "Syndicate Seat: debts cleared; +1 smuggling-route slot", "fx": {"clear_debt": 1, "route_slots": 1}}}},
	"bloom": {"name": "The Bloom", "bloc": "outlaw", "race": "mycelari", "home": "bloomfall",
		"leader": "The Sporemother", "ideology": "Consume and spread", "rivals_lore": ["synthesis", "verdant_canopy"],
		"bonuses": {
			"50": {"text": "+15% salvage yield", "fx": {"salvage": 0.15}},
			"75": {"text": "Spore cloud ability: enemy accuracy −20%", "fx": {"ability": "spore_cloud"}},
			"100": {"text": "Hive Link: crew injuries heal 2×; +25% salvage", "fx": {"heal": 1.0, "salvage": 0.25}}}},
	"veilbound": {"name": "The Veilbound", "bloc": "outlaw", "race": "noctari", "home": "drift_market",
		"leader": "The Veiled Broker", "ideology": "Secrets, forgery, leverage", "rivals_lore": ["synthesis"],
		"bonuses": {
			"50": {"text": "+10% stealth", "fx": {"stealth": 0.10}},
			"75": {"text": "Forged IDs last 2×", "fx": {"forged_ids": 1}},
			"100": {"text": "Shadow Cloak: once per run, vanish from a battle", "fx": {"ability": "shadow_cloak"}}}},
	"ashscale_warbands": {"name": "Ashscale Warbands", "bloc": "outlaw", "race": "ssaryn", "home": "the_cinder_fort",
		"leader": "Queen Vask", "ideology": "Conquest, tribute, raids", "rivals_lore": ["sunscale_covenant", "high_aerie", "thalassi_deepcourt"],
		"bonuses": {
			"50": {"text": "+15% raid tribute", "fx": {"raid_tribute": 0.15}},
			"75": {"text": "+15% boarding success", "fx": {"boarding": 0.15}},
			"100": {"text": "Warband Banner: call a raid fleet once per run", "fx": {"ability": "raid_fleet"}}}},
	"hunt_guilds": {"name": "Sskarn Hunt-Guilds", "bloc": "neutral", "race": "sskarn", "home": "brimstone_reach",
		"leader": "The Guildmasters", "ideology": "Contracts for anyone who pays", "rivals_lore": [],
		"bonuses": {
			"50": {"text": "+15% bounty credits", "fx": {"bounty_credits": 0.15}},
			"75": {"text": "+1 active quest slot", "fx": {"quest_slots": 1}},
			"100": {"text": "Guild Master: top-tier bounty board unlocks", "fx": {"guild_master": 1}}}},
	"none": {"name": "Independent", "bloc": "neutral", "race": "", "home": "", "leader": "", "ideology": "", "rivals_lore": [], "bonuses": {}},
}
const FACTION_ORDER := ["terran_concord", "synthesis", "high_aerie", "verdant_canopy", "thalassi_deepcourt",
	"sunscale_covenant", "black_meridian", "bloom", "veilbound", "ashscale_warbands", "hunt_guilds"]
const ACCORD := ["terran_concord", "synthesis", "high_aerie", "verdant_canopy", "thalassi_deepcourt", "sunscale_covenant"]
const PACT := ["black_meridian", "bloom", "veilbound", "ashscale_warbands"]
const BLOC_NAMES := {"paragon": "The Luminary Accord", "outlaw": "The Eclipse Pact", "neutral": "Neutral"}
## §7.4. Rep in faction points (FP): 1,000 FP = 100%.
const REP_START := 100           # 10% with your home faction
const REP_QUESTS := 100          # 10%: faction quests unlock
const REP_SAFE := 250            # 25%: safe port + 5% discount
const REP_DISCOUNT := 500        # 50%: 10% discount
const REP_HOSTILE := -250        # below -25%: their ships attack on sight, ports closed
const REP_BUY_STEP := 100        # rep repair: +10% ...
const REP_BUY_PRICE := 1000      # ... for 1,000 credits ...
const REP_BUY_MAX := 500         # ... only up to +50%
const REP_PENALTY_PRICES := 0.20 # below 0%: +20% prices

# ================================================================ alignment (§8)

## Two independent bars, 0..100, never decrease. Milestones: [points, title, text, fx].
const BAR_MILESTONES := {
	"paragon": [
		[10, "Respected", "Paragon-port repairs −10%; Paragon crew wages −10%", {"repair_cost@paragon": -0.10, "crew_wages@paragon": -0.10}],
		[30, "Defender", "+10% shields; piracy encounters −25% in Accord space", {"shield": 0.10, "piracy@paragon": -0.25}],
		[50, "Champion", "+25% crew loyalty; +5% all ship stats; unlock Beacon refit", {"crew_loyalty": 0.25, "all_ship": 0.05, "beacon": 1}],
		[75, "Paragon Hero", "Free repairs at Accord ports; bounty rewards +25%; call allied fleet (1×/run)", {"free_repair@paragon": 1, "bounty_credits": 0.25, "ability": "allied_fleet"}],
		[100, "Legend of the Spiral", "Unlocks Unify the Spiral endgame; allied captains join fleet", {"unify": 1}],
	],
	"outlaw": [
		[10, "Notorious", "Raid tribute +15%; black-market access everywhere", {"raid_tribute": 0.15, "black_everywhere": 1}],
		[30, "Menace", "+10% weapon damage; heat decays faster in lawless space", {"weapon_damage": 0.10, "heat_decay@lawless": 1.0}],
		[50, "Warlord", "+25% loot; unlock ship hijacking; weak enemies surrender", {"loot": 0.25, "hijack": 1, "surrender": 1}],
		[75, "Terror", "Bounty hunters spawn as nemeses (epic loot); unlock Dread refit", {"nemesis": 1, "dread": 1}],
		[100, "Scourge of the Stars", "Unlocks Rule the Spiral endgame; worlds can be made tributaries", {"rule": 1}],
	],
}
const BAR_CREW_GATE := 3            # crew of a bloc join only with that bar >= 3
const CLASH_LOYALTY := 15           # Paragon + Outlaw crew aboard: -15 loyalty each

## Battle calls from rep and milestones (once per run each). "allies": ships that fly in for a while.
const ABILITIES := {
	"escort_wing": {"name": "Escort wing", "icon": "🛡", "allies": 2, "secs": 16.0, "dmg": 5},
	"wingmates": {"name": "Wingmates", "icon": "🪶", "allies": 2, "secs": 16.0, "dmg": 6},
	"raid_fleet": {"name": "Raid fleet", "icon": "🏴", "allies": 3, "secs": 18.0, "dmg": 6},
	"allied_fleet": {"name": "Allied fleet", "icon": "✨", "allies": 3, "secs": 20.0, "dmg": 7},
	"spore_cloud": {"name": "Spore cloud", "icon": "🍄", "secs": 12.0},
	"shadow_cloak": {"name": "Shadow Cloak", "icon": "🌑"},
}

# ================================================================ crew (§10)

## "fee": hiring fee (credits, clean or dirty), "wage": per day. "quest": the discovery quest.
## Racial perk, personal perk and quirk (their race flaw, at CONFIG.crew_flaw_strength) per the doc.
const CREW := {
	"C01": {"name": "Pip", "role": "salvage drone", "race": "synthari", "align": "neutral", "planet": "scrapyard_gamma",
		"racial": "G04", "personal": "G25", "quirk": "B06", "fee": 0, "wage": 0},
	"C02": {"name": "Marisol Vance", "role": "ex-Concord navigator", "race": "terran", "align": "paragon", "planet": "frostline",
		"racial": "G05", "personal": "G11", "quirk": "B12", "fee": 1500, "wage": 30},
	"C03": {"name": "Doc Imre", "role": "field medic", "race": "terran", "align": "paragon", "planet": "sunken_orbital",
		"racial": "G30", "personal": "G17", "quirk": "B12", "fee": 2500, "wage": 35},
	"C04": {"name": "Tavi Quillfeather", "role": "storm pilot", "race": "kestrai", "align": "paragon", "planet": "aerie_spire",
		"racial": "G24", "personal": "G26", "quirk": "B01", "fee": 2500, "wage": 35},
	"C05": {"name": "Oren Thornroot", "role": "agronomist-soldier", "race": "verdanti", "align": "paragon", "planet": "brass_garden",
		"racial": "G13", "personal": "G16", "quirk": "B09", "fee": 1500, "wage": 30},
	"C06": {"name": "Nerida Deepcall", "role": "reef cartographer", "race": "thalassi", "align": "paragon", "planet": "chorus_nebula",
		"racial": "G12", "personal": "G10", "quirk": "B08", "fee": 2500, "wage": 35},
	"C07": {"name": "Ravik Sunscale", "role": "duelist", "race": "ssaryn", "align": "paragon", "planet": "sunspire_citadel",
		"racial": "G06", "personal": "G21", "quirk": "B14", "fee": 3000, "wage": 40},
	"C08": {"name": "Halcyon", "role": "Synthesis node unit", "race": "synthari", "align": "paragon", "planet": "halcyon_core",
		"racial": "G18", "personal": "G23", "quirk": "B06", "fee": 3000, "wage": 40},
	"C09": {"name": "Sable", "role": "forger", "race": "noctari", "align": "outlaw", "planet": "drift_market",
		"racial": "G02", "personal": "G27", "quirk": "B07", "fee": 3000, "wage": 40},
	"C10": {"name": "Vorga Ashmaw", "role": "boarder", "race": "ssaryn", "align": "outlaw", "planet": "port_vermillion",
		"racial": "G14", "personal": "G22", "quirk": "B14", "fee": 1500, "wage": 30},
	"C11": {"name": "Dax Orlov", "role": "deserter pilot", "race": "terran", "align": "outlaw", "planet": "wreck_of_the_starlight",
		"racial": "G30", "personal": "G03", "quirk": "B12", "fee": 2500, "wage": 35},
	"C12": {"name": "Sporemother Yveth", "role": "hive-envoy", "race": "mycelari", "align": "outlaw", "planet": "bloomfall",
		"racial": "G25", "personal": "G08", "quirk": "B11", "fee": 3000, "wage": 40},
	"C13": {"name": "Tessa Quill", "role": "rogue Synthari engineer", "race": "synthari", "align": "outlaw", "planet": "null_point",
		"racial": "G04", "personal": "G07", "quirk": "B06", "fee": 3000, "wage": 40},
	"C14": {"name": "Brann Kole", "role": "ex-enforcer", "race": "terran", "align": "outlaw", "planet": "meridian_station",
		"racial": "G05", "personal": "G01", "quirk": "B12", "fee": 3000, "wage": 40},
	"C15": {"name": "Rook", "role": "exiled pirate pilot", "race": "kestrai", "align": "outlaw", "planet": "the_gilded_rock",
		"racial": "G03", "personal": "G19", "quirk": "B01", "fee": 3500, "wage": 45},
	"C16": {"name": "Gristle", "role": "hunt-guild merc", "race": "sskarn", "align": "neutral", "planet": "brimstone_reach",
		"racial": "G22", "personal": "G31", "quirk": "B03", "fee": 4000, "wage": 45},
}
const CREW_ORDER := ["C01", "C02", "C03", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11", "C12", "C13", "C14", "C15", "C16"]
const LOYALTY_START := 60
const LOYALTY_UNPAID := 8           # lost per day without wages
const LOYALTY_PAID := 1             # gained per paid day (up to 100)

# ================================================================ quests (§10.1, §11)

## Every quest: kind (main / neutral / paragon / outlaw / favor / crew), giver (world), brief, one step,
## and its rewards. Steps: deliver {good, qty, to} (hand over at that dock), reach {to}, pay {amount}
## (Kessel's debt at Cradle Station), spend {amount} (paid when you hand in), scans {n} (pass n scans
## with contraband aboard), fights {n} (win n battles), battle {to, enemy} (a battle when you dock there),
## salvage {n, at} (search wrecks), crew {n} (have n crew aboard).
## Rewards: credits + money ("clean" / "dirty"), faction (FP deltas: only the factions listed change,
## §7.4), bars {paragon, outlaw}, xp. "give": cargo handed over when you accept. "pick": a choice of
## faction when you hand in ("paragon" = any Accord faction, "any" = any faction) that gets "pick_fp".
## "choices": a decision when you hand in, each with its own rewards (§11.5). "prereq": rep_min /
## bar_min / done (quests). Faction quests also need 10% rep with the giver's faction (§7.4;
## "giver_faction" overrides the giver world's faction, "open" skips the gate for an intro quest).
## "recruit": the crew member this discovery quest opens. "story": a card set shown when done.
const QUESTS := {
	# ---- Neutral / story intro (§11.1)
	"N01": {"kind": "main", "title": "Cold Cargo", "sub": "tutorial run", "giver": "cradle_station", "who": "Dockmaster",
		"brief": "The dockmaster needs three crates of food in Frostline before the ration day. Fly them there and hand them over.",
		"give": {"food": 3}, "step": {"type": "deliver", "good": "food", "qty": 3, "to": "frostline"},
		"credits": 500, "money": "clean", "xp": 60, "unlock": "black_market", "next": "N02", "story": "done_n01"},
	"N02": {"kind": "main", "title": "Kessel's Terms", "sub": "pay the debt", "giver": "cradle_station", "who": "Mother Kessel",
		"brief": "You owe Mother Kessel 3,000. Clean or dirty, she doesn't care. Pay her collector on Cradle Station.",
		"step": {"type": "pay", "amount": 3000}, "credits": 0, "faction": {"black_meridian": 50},
		"xp": 120, "points": 1, "unlock": "black_shipyard", "next": "N03", "story": "done_n02"},
	"N03": {"kind": "main", "title": "Dead Man's Ship", "sub": "receive the Runner", "giver": "cradle_station", "who": "Old Marrow",
		"brief": "A coded message: coordinates in the wreck ring of Scrapyard Gamma, and a name. Old Marrow.",
		"step": {"type": "reach", "to": "scrapyard_gamma"}, "credits": 0, "xp": 150, "ship": "runner", "next": "N04", "story": "done_n03"},
	"N04": {"kind": "main", "title": "Ghost in the Net", "sub": "learn the Core", "giver": "scrapyard_gamma", "who": "Marrow's log",
		"brief": "Marrow said they can't see you. Prove it: get through three scans with contraband aboard.",
		"step": {"type": "scans", "n": 3}, "credits": 0, "xp": 300, "unlock": "act1_done", "story": "done_n04"},
	"N05": {"kind": "neutral", "title": "Vending Mystery I", "giver": "cradle_station", "who": "VEND-O-MATIC 9000",
		"brief": "The VEND-O-MATIC 9000 sells the wrong things. It asks, very politely, for four crates of electronics to fix itself.",
		"step": {"type": "deliver", "good": "electronics", "qty": 4, "to": "cradle_station"},
		"credits": 200, "money": "clean", "xp": 40, "junk": true},
	"N06": {"kind": "neutral", "title": "Pip's Rule", "sub": "tutorial for crew", "giver": "scrapyard_gamma", "who": "Pip",
		"brief": "Pip's rule: a ship needs a crew. Have one crew member aboard (Pip counts).",
		"step": {"type": "crew", "n": 1}, "credits": 500, "money": "clean", "xp": 40, "prereq": {"done": ["C01"]}},
	# ---- Crew discovery quests (§10.1)
	"C01": {"kind": "crew", "title": "Memory Core", "giver": "scrapyard_gamma", "recruit": "C01",
		"brief": "A broken salvage drone blinks at you. Search the wrecks of Scrapyard Gamma three times for its parts.",
		"step": {"type": "salvage", "n": 3, "at": "scrapyard_gamma"}, "credits": 800, "money": "clean", "xp": 40},
	"C02": {"kind": "crew", "title": "Cold Snap", "giver": "frostline", "recruit": "C02",
		"brief": "Frostline's heat plant is failing. Bring five crates of alloys before the colony freezes.",
		"step": {"type": "deliver", "good": "alloys", "qty": 5, "to": "frostline"},
		"credits": 1500, "money": "clean", "faction": {"terran_concord": 100}, "bars": {"paragon": 1}, "xp": 60},
	"C03": {"kind": "crew", "title": "Pressure", "giver": "sunken_orbital", "recruit": "C03",
		"brief": "Workers are trapped in a sealed section of the Sunken Orbital. Bring four med kits for the rescue team.",
		"step": {"type": "deliver", "good": "medicine", "qty": 4, "to": "sunken_orbital"},
		"credits": 2000, "money": "clean", "faction": {"terran_concord": 100}, "bars": {"paragon": 1}, "xp": 70},
	"C04": {"kind": "crew", "title": "Storm Run", "giver": "aerie_spire", "recruit": "C04",
		"brief": "An ion storm cut Aerie Spire off. Fly five med kits in through it.",
		"step": {"type": "deliver", "good": "medicine", "qty": 5, "to": "aerie_spire"},
		"credits": 2500, "money": "clean", "faction": {"high_aerie": 150}, "bars": {"paragon": 1}, "xp": 80},
	"C05": {"kind": "crew", "title": "Blight", "giver": "brass_garden", "recruit": "C05",
		"brief": "Someone is poisoning Brass Garden's crops. The trail leads to a skiff hiding in Scrapyard Gamma. Stop it.",
		"step": {"type": "battle", "to": "scrapyard_gamma", "enemy": "saboteur"},
		"credits": 2200, "money": "clean", "faction": {"verdant_canopy": 150}, "bars": {"paragon": 1}, "xp": 80},
	"C06": {"kind": "crew", "title": "Harmonics", "giver": "chorus_nebula", "recruit": "C06",
		"brief": "Record the Chorus Nebula's song without disturbing it: bring three crates of electronics for quiet recorders.",
		"step": {"type": "deliver", "good": "electronics", "qty": 3, "to": "chorus_nebula"},
		"credits": 3000, "money": "clean", "faction": {"thalassi_deepcourt": 150}, "bars": {"paragon": 1}, "xp": 90},
	"C07": {"kind": "crew", "title": "Trial of Light", "giver": "sunspire_citadel", "recruit": "C07",
		"brief": "Win a Sunscale ritual duel over the Citadel. Nobody dies: they stop at the first broken shield.",
		"step": {"type": "battle", "to": "sunspire_citadel", "enemy": "duelist"},
		"credits": 3500, "money": "clean", "faction": {"sunscale_covenant": 200, "ashscale_warbands": -100}, "bars": {"paragon": 2}, "xp": 100},
	"C08": {"kind": "crew", "title": "Firewall", "giver": "halcyon_core", "recruit": "C08",
		"brief": "An Ashscale hack-runner is attacking Halcyon Core's network from orbit. Chase it off.",
		"step": {"type": "battle", "to": "halcyon_core", "enemy": "ashscale_hacker"},
		"credits": 2800, "money": "clean", "faction": {"synthesis": 150, "ashscale_warbands": -50}, "bars": {"paragon": 1}, "xp": 90},
	"C09": {"kind": "crew", "title": "Ghost Ledger", "giver": "drift_market", "recruit": "C09",
		"brief": "A Veilbound rival stole Sable's data and runs it out of the Gilded Rock. Take it back.",
		"step": {"type": "battle", "to": "the_gilded_rock", "enemy": "veil_rival"},
		"credits": 4000, "money": "dirty", "faction": {"veilbound": 150}, "bars": {"outlaw": 1}, "xp": 100},
	"C10": {"kind": "crew", "title": "Honor Among Thieves", "giver": "port_vermillion", "recruit": "C10",
		"brief": "Two pirate crews at Port Vermillion are feuding. Settle it the old way: win two fights.",
		"step": {"type": "fights", "n": 2}, "credits": 3500, "money": "dirty",
		"faction": {"ashscale_warbands": 150}, "bars": {"outlaw": 1}, "xp": 90},
	"C11": {"kind": "crew", "title": "Dead Reckoning", "giver": "wreck_of_the_starlight", "recruit": "C11",
		"brief": "Find Dax's old squadron in the wreck field (search it twice), then decide what to do with the black box.",
		"step": {"type": "salvage", "n": 2, "at": "wreck_of_the_starlight"}, "credits": 3000, "money": "clean", "xp": 90,
		"choices": [
			{"label": "Give it to the Concord", "faction": {"terran_concord": 100}, "bars": {"paragon": 1}},
			{"label": "Sell it to the Pact", "faction": {"black_meridian": 100, "terran_concord": -100}, "bars": {"outlaw": 1}}]},
	"C12": {"kind": "crew", "title": "Ripe for Harvest", "giver": "bloomfall", "recruit": "C12",
		"brief": "Carry a spore-bloom to the supply depot at Brass Garden and let it loose.",
		"step": {"type": "reach", "to": "brass_garden"}, "credits": 3500, "money": "dirty",
		"faction": {"bloom": 150, "verdant_canopy": -100}, "bars": {"outlaw": 1}, "xp": 90},
	"C13": {"kind": "crew", "title": "Hive Debt", "giver": "null_point", "recruit": "C13",
		"brief": "Tessa Quill has a Synthari enforcer on her tail. Fly her to Drift Market, then hide her, or hand her over.",
		"step": {"type": "reach", "to": "drift_market"}, "credits": 0, "xp": 90,
		"choices": [
			{"label": "Hide her", "credits": 2800, "money": "dirty", "faction": {"veilbound": 120, "synthesis": -100}, "bars": {"outlaw": 1}},
			{"label": "Hand her over", "faction": {"synthesis": 100}, "bars": {"paragon": 1}, "recruit_lost": true}]},
	"C14": {"kind": "crew", "title": "Collections", "giver": "meridian_station", "recruit": "C14",
		"brief": "Run a protection racket with Brann Kole. The debtor hired guns: win one fight.",
		"step": {"type": "fights", "n": 1}, "credits": 4000, "money": "dirty",
		"faction": {"black_meridian": 150}, "bars": {"outlaw": 1}, "xp": 90},
	"C15": {"kind": "crew", "title": "Loaded Dice", "giver": "the_gilded_rock", "recruit": "C15",
		"brief": "Rook is the inside man. Rig the Gilded Rock's tables: bring three crates of electronics.",
		"step": {"type": "deliver", "good": "electronics", "qty": 3, "to": "the_gilded_rock"},
		"credits": 5000, "money": "dirty", "faction": {"veilbound": 150}, "bars": {"outlaw": 1}, "xp": 100},
	"C16": {"kind": "crew", "title": "Two-Sided Contract", "giver": "brimstone_reach", "recruit": "C16",
		"brief": "A hunt both blocs paid for: bring down the bounty hunter lurking at Null Point.",
		"step": {"type": "battle", "to": "null_point", "enemy": "hunter"}, "credits": 5000, "money": "clean",
		"faction": {"hunt_guilds": 100}, "xp": 100, "bounty": true},
	# ---- Paragon quests (§11.2)
	"P01": {"kind": "paragon", "title": "Medicine Run", "giver": "cradle_station",
		"brief": "Vaccines through a blockade: deliver five med kits to Frostline.",
		"step": {"type": "deliver", "good": "medicine", "qty": 5, "to": "frostline"},
		"credits": 1200, "money": "clean", "faction": {"terran_concord": 100}, "bars": {"paragon": 1}, "xp": 50},
	"P02": {"kind": "paragon", "title": "Convoy Escort", "giver": "cradle_station",
		"brief": "Escort a Concord convoy to Brass Garden. Raiders will try for it on arrival.",
		"step": {"type": "battle", "to": "brass_garden", "enemy": "pirate"},
		"credits": 1800, "money": "clean", "faction": {"terran_concord": 100}, "bars": {"paragon": 1}, "xp": 60},
	"P03": {"kind": "paragon", "title": "Pirate Nest", "giver": "cradle_station",
		"brief": "Clear the raider base hidden at Port Vermillion.",
		"step": {"type": "battle", "to": "port_vermillion", "enemy": "raider_base"},
		"credits": 4000, "money": "clean", "faction": {"terran_concord": 200, "ashscale_warbands": -100}, "bars": {"paragon": 2}, "xp": 120},
	"P04": {"kind": "paragon", "title": "Skyward Rescue", "giver": "aerie_spire",
		"brief": "A stranded flock is out of supplies. Bring four crates of food to Aerie Spire.",
		"step": {"type": "deliver", "good": "food", "qty": 4, "to": "aerie_spire"},
		"credits": 1500, "money": "clean", "faction": {"high_aerie": 100}, "bars": {"paragon": 1}, "xp": 50},
	"P05": {"kind": "paragon", "title": "Seed Ark", "giver": "brass_garden",
		"brief": "Deliver three crates of terraform seeds (food stock) to Frostline.",
		"give": {"food": 3}, "step": {"type": "deliver", "good": "food", "qty": 3, "to": "frostline"},
		"credits": 2500, "money": "clean", "faction": {"verdant_canopy": 150}, "bars": {"paragon": 1}, "xp": 60},
	"P06": {"kind": "paragon", "title": "Reef Defense", "giver": "abyssal_reef",
		"brief": "Ashscale raiders circle the Abyssal Reef. Drive them off when you dock.",
		"step": {"type": "battle", "to": "abyssal_reef", "enemy": "ashscale_raider"},
		"credits": 2200, "money": "clean", "faction": {"thalassi_deepcourt": 150, "ashscale_warbands": -75}, "bars": {"paragon": 1}, "xp": 70},
	"P07": {"kind": "paragon", "title": "Light Trial", "giver": "sunspire_citadel",
		"brief": "A ritual duel, nonlethal: win it over the Citadel.",
		"step": {"type": "battle", "to": "sunspire_citadel", "enemy": "duelist"},
		"credits": 3500, "money": "clean", "faction": {"sunscale_covenant": 200}, "bars": {"paragon": 2}, "xp": 100},
	"P08": {"kind": "paragon", "title": "Firewall", "sub": "stop a network sabotage", "giver": "halcyon_core",
		"brief": "Another hack-runner probes Halcyon Core. Stop the sabotage.",
		"step": {"type": "battle", "to": "halcyon_core", "enemy": "ashscale_hacker"},
		"credits": 2800, "money": "clean", "faction": {"synthesis": 150}, "bars": {"paragon": 1}, "xp": 80},
	"P09": {"kind": "paragon", "title": "Refugee Lanes", "giver": "sunken_orbital",
		"brief": "Low pay, good work: run refugee papers and supplies to Aerie Spire. Pick which Accord faction gets the credit.",
		"step": {"type": "reach", "to": "aerie_spire"}, "credits": 800, "money": "clean",
		"pick": "paragon", "pick_fp": 100, "bars": {"paragon": 1}, "xp": 40},
	"P10": {"kind": "paragon", "title": "Minefield Sweep", "giver": "cradle_station",
		"brief": "Mine-layers seeded the lanes near Port Vermillion. Clear them out.",
		"step": {"type": "battle", "to": "port_vermillion", "enemy": "mine_layer"},
		"credits": 2000, "money": "clean", "faction": {"terran_concord": 120}, "bars": {"paragon": 1}, "xp": 70},
	"P11": {"kind": "paragon", "title": "Break the Ransom Ring", "giver": "aerie_spire",
		"brief": "Hostages are held at the Cinder Fort. Break the ring's guard ships.",
		"step": {"type": "battle", "to": "the_cinder_fort", "enemy": "ashscale_raider"},
		"credits": 3000, "money": "clean", "faction": {"high_aerie": 200, "ashscale_warbands": -100}, "bars": {"paragon": 2}, "xp": 100},
	"P12": {"kind": "paragon", "title": "Famine Relief", "giver": "brass_garden",
		"brief": "Frostline is starving. Deliver six crates of food, then decide what to charge.",
		"step": {"type": "deliver", "good": "food", "qty": 6, "to": "frostline"}, "credits": 0, "xp": 60,
		"choices": [
			{"label": "Sell at cost", "credits": 1000, "money": "clean", "faction": {"verdant_canopy": 100}, "bars": {"paragon": 1}},
			{"label": "Sell at 3× markup", "credits": 3000, "money": "dirty", "faction": {"verdant_canopy": -100}, "bars": {"outlaw": 1}}]},
	"P13": {"kind": "paragon", "title": "Expose the Corrupt Officer", "giver": "cradle_station",
		"brief": "A Concord officer takes Syndicate money. Find the proof at Meridian Station.",
		"step": {"type": "reach", "to": "meridian_station"},
		"credits": 2500, "money": "clean", "faction": {"terran_concord": 150, "black_meridian": -100}, "bars": {"paragon": 1}, "xp": 80},
	"P14": {"kind": "paragon", "title": "Beacon Rising", "sub": "capstone", "giver": "cradle_station",
		"brief": "The Accord summit meets at Sunspire Citadel. An Ashscale war-wing is coming. Defend it.",
		"step": {"type": "battle", "to": "sunspire_citadel", "enemy": "ashscale_armada"}, "credits": 15000, "money": "clean",
		"faction": {"terran_concord": 150, "synthesis": 150, "high_aerie": 150, "verdant_canopy": 150, "thalassi_deepcourt": 150, "sunscale_covenant": 150},
		"bars": {"paragon": 3}, "xp": 400, "prereq": {"bar_min": {"paragon": 10}}},
	# ---- Outlaw quests (§11.3)
	"O01": {"kind": "outlaw", "title": "Cold Cargo", "sub": "smuggle past a patrol", "giver": "cradle_station",
		"brief": "Kessel's collector hands you two crates of bootleg data. Hide them, fly them to Frostline, don't get caught.",
		"give": {"bootleg_data": 2}, "step": {"type": "deliver", "good": "bootleg_data", "qty": 2, "to": "frostline"},
		"credits": 2000, "money": "dirty", "faction": {"black_meridian": 100, "terran_concord": -50}, "bars": {"outlaw": 1}, "xp": 60,
		"prereq": {"done": ["N01"]}, "open": true},
	"O02": {"kind": "outlaw", "title": "Protection Racket", "giver": "port_vermillion",
		"brief": "Shake down the Concord dock at Frostline. Its patrol will object.",
		"step": {"type": "battle", "to": "frostline", "enemy": "patrol"}, "credits": 3000, "money": "dirty",
		"faction": {"black_meridian": 150, "terran_concord": -100}, "bars": {"outlaw": 1}, "xp": 80, "giver_faction": "black_meridian"},
	"O03": {"kind": "outlaw", "title": "Convoy Raid", "giver": "the_cinder_fort",
		"brief": "Hit an armed hauler as it docks at the Sunken Orbital.",
		"step": {"type": "battle", "to": "sunken_orbital", "enemy": "hauler"}, "credits": 6000, "money": "dirty",
		"faction": {"ashscale_warbands": 200, "terran_concord": -100}, "bars": {"outlaw": 2}, "xp": 120},
	"O04": {"kind": "outlaw", "title": "Spore Bloom", "giver": "bloomfall",
		"brief": "Infest a rival's supplies: carry spores to the depot at Brass Garden.",
		"step": {"type": "reach", "to": "brass_garden"}, "credits": 3500, "money": "dirty",
		"faction": {"bloom": 150, "verdant_canopy": -100}, "bars": {"outlaw": 1}, "xp": 80},
	"O05": {"kind": "outlaw", "title": "Shadow Heist", "giver": "drift_market",
		"brief": "Steal a vault key from Halcyon Core. Its patrol will chase you.",
		"step": {"type": "battle", "to": "halcyon_core", "enemy": "patrol"}, "credits": 4000, "money": "dirty",
		"faction": {"veilbound": 150, "synthesis": -75}, "bars": {"outlaw": 1}, "xp": 90},
	"O06": {"kind": "outlaw", "title": "Frame Job", "giver": "meridian_station",
		"brief": "Plant evidence on a Concord rival: deliver two crates of forged IDs to Cradle Station.",
		"step": {"type": "deliver", "good": "forged_ids", "qty": 2, "to": "cradle_station"}, "credits": 2500, "money": "dirty",
		"faction": {"black_meridian": 120, "terran_concord": -100}, "bars": {"outlaw": 1}, "xp": 70},
	"O07": {"kind": "outlaw", "title": "Jailbreak", "giver": "drift_market",
		"brief": "Extract a prisoner from an Accord cruiser parked over Sunken Orbital.",
		"step": {"type": "battle", "to": "sunken_orbital", "enemy": "accord_cruiser"}, "credits": 5000, "money": "dirty",
		"faction": {"veilbound": 200, "terran_concord": -150}, "bars": {"outlaw": 2}, "xp": 140},
	"O08": {"kind": "outlaw", "title": "Hostile Takeover", "giver": "meridian_station",
		"brief": "Sabotage the Concord's station at Sunken Orbital: knock out its patrol.",
		"step": {"type": "battle", "to": "sunken_orbital", "enemy": "patrol"}, "credits": 5000, "money": "dirty",
		"faction": {"black_meridian": 150, "terran_concord": -100}, "bars": {"outlaw": 1}, "xp": 110},
	"O09": {"kind": "outlaw", "title": "Burn the Granary", "giver": "the_cinder_fort",
		"brief": "Queen Vask wants leverage over the Canopy: break the guard of Brass Garden's granary.",
		"step": {"type": "battle", "to": "brass_garden", "enemy": "verdant_guard"}, "credits": 8000, "money": "dirty",
		"faction": {"ashscale_warbands": 250, "verdant_canopy": -200}, "bars": {"outlaw": 3}, "xp": 160},
	"O10": {"kind": "outlaw", "title": "Governor for Ransom", "giver": "the_cinder_fort",
		"brief": "A Concord governor travels under cruiser guard to Cradle Station. Take the governor, then decide how it ends.",
		"step": {"type": "battle", "to": "cradle_station", "enemy": "accord_cruiser"}, "credits": 12000, "money": "dirty", "xp": 200,
		"faction": {"ashscale_warbands": 150, "veilbound": 100, "terran_concord": -200},
		"choices": [
			{"label": "Return the governor after payment", "bars": {"outlaw": 3}, "loyalty": 10},
			{"label": "Make an example of them", "bars": {"outlaw": 4}, "faction": {"terran_concord": -100}, "loyalty": -10}]},
	"O11": {"kind": "outlaw", "title": "Tribute Run", "giver": "meridian_station",
		"brief": "Collect the Syndicate's tribute from the small stations around Port Vermillion.",
		"step": {"type": "reach", "to": "port_vermillion"}, "credits": 1500, "money": "dirty",
		"faction": {"black_meridian": 100}, "bars": {"outlaw": 1}, "xp": 50},
	"O12": {"kind": "outlaw", "title": "Poison the Market", "giver": "the_gilded_rock",
		"brief": "Crash a rival's black market: flood Null Point with three crates of bootleg data.",
		"step": {"type": "deliver", "good": "bootleg_data", "qty": 3, "to": "null_point"}, "credits": 3000, "money": "dirty",
		"faction": {"veilbound": 120}, "bars": {"outlaw": 1}, "xp": 80},
	"O13": {"kind": "outlaw", "title": "Sink the Flagship", "giver": "the_cinder_fort",
		"brief": "The Accord flagship patrols Cradle Station. Bring it down.",
		"step": {"type": "battle", "to": "cradle_station", "enemy": "accord_flagship"}, "credits": 15000, "money": "dirty",
		"faction": {"ashscale_warbands": 300, "terran_concord": -200}, "bars": {"outlaw": 3}, "xp": 300},
	"O14": {"kind": "outlaw", "title": "Crown of Shadows", "sub": "capstone", "giver": "meridian_station",
		"brief": "Unite the Pact: break the Accord battle line that waits at Null Point.",
		"step": {"type": "battle", "to": "null_point", "enemy": "accord_armada"}, "credits": 25000, "money": "dirty",
		"faction": {"black_meridian": 150, "bloom": 150, "veilbound": 150, "ashscale_warbands": 150},
		"bars": {"outlaw": 4}, "xp": 500, "prereq": {"bar_min": {"outlaw": 10}}},
	# ---- Faction-only favours (§11.4): rep changes, no bar change
	"F01": {"kind": "favor", "title": "Double Agent", "giver": "cradle_station",
		"brief": "Feed the Concord false intel from Meridian: fly there and back with your eyes open.",
		"step": {"type": "reach", "to": "meridian_station"}, "credits": 2500, "money": "clean",
		"faction": {"terran_concord": 150, "black_meridian": -150}, "xp": 70},
	"F02": {"kind": "favor", "title": "Peace Offering", "giver": "cradle_station",
		"brief": "Mend a feud: pay 2,000 for a gift and pick which faction receives it.",
		"step": {"type": "spend", "amount": 2000}, "credits": 0, "pick": "any", "pick_fp": 100, "xp": 30},
	"F03": {"kind": "favor", "title": "Embargo Run", "giver": "aerie_spire",
		"brief": "Carry a banned shipment for the Aerie: three crates of unlicensed weapons, delivered to Aerie Spire.",
		"step": {"type": "deliver", "good": "weapons", "qty": 3, "to": "aerie_spire"}, "credits": 2000, "money": "clean",
		"faction": {"high_aerie": 100, "terran_concord": -50}, "xp": 60},
	"F04": {"kind": "favor", "title": "Reef Ledger", "giver": "abyssal_reef",
		"brief": "Audit the trade records the Deepcourt keeps at Sunken Orbital.",
		"step": {"type": "reach", "to": "sunken_orbital"}, "credits": 1800, "money": "clean",
		"faction": {"thalassi_deepcourt": 100}, "xp": 50},
	"F05": {"kind": "favor", "title": "Guild Contract", "giver": "brimstone_reach",
		"brief": "A hunt posted by the Hunt-Guilds: the raiders camped at Port Vermillion.",
		"step": {"type": "battle", "to": "port_vermillion", "enemy": "pirate"}, "credits": 3000, "money": "clean",
		"faction": {"hunt_guilds": 100}, "xp": 70, "bounty": true},
	"F06": {"kind": "favor", "title": "Hive Tithe", "giver": "bloomfall",
		"brief": "Carry the Bloom's spores to its outpost at Null Point.",
		"step": {"type": "reach", "to": "null_point"}, "credits": 2200, "money": "dirty",
		"faction": {"bloom": 100, "synthesis": -50}, "xp": 60},
}
const MAIN_ORDER := ["N01", "N02", "N03", "N04"]
const QUEST_ORDER := ["N01", "N02", "N03", "N04", "N05", "N06",
	"C01", "C02", "C03", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11", "C12", "C13", "C14", "C15", "C16",
	"P01", "P02", "P03", "P04", "P05", "P06", "P07", "P08", "P09", "P10", "P11", "P12", "P13", "P14",
	"O01", "O02", "O03", "O04", "O05", "O06", "O07", "O08", "O09", "O10", "O11", "O12", "O13", "O14",
	"F01", "F02", "F03", "F04", "F05", "F06"]
const START_DEBT := 3000
## Active quests besides the main story (Contract Broker and the Hunt-Guilds add more).
const QUEST_SLOTS := 3
## Procedural contracts (§11.6): FP to the issuer, FP off the target, a bar point every 3rd one.
const CONTRACT_FP := 50
const CONTRACT_BAR_EVERY := 3
