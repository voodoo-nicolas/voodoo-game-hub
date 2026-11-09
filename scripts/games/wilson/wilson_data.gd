extends RefCounted

## Beached: data. The owner's JSON (games/wilson/data/*.json: daynight, balance, items, recipes,
## tutorial_quests) is read at runtime and cached; everything below is the game's own tuning that the
## design docs leave open (each marked with where it came from). Decisions: docs/wilson/DECISIONS.md.

const DATA_DIR := "res://games/wilson/data/"

static var _cache := {}

## One of the owner's data files, parsed (cached). Empty dictionary if missing.
static func json(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var out := {}
	var f := FileAccess.open(DATA_DIR + name + ".json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			out = parsed
	_cache[name] = out
	return out

static func balance() -> Dictionary:
	return json("balance")

static var _items := {}
static func items() -> Dictionary:
	if _items.is_empty():
		for it in json("items").get("items", []):
			_items[it.id] = it
	return _items

static func item(id: String) -> Dictionary:
	return items().get(id, {})

static var _recipes := {}
static func recipes() -> Dictionary:
	if _recipes.is_empty():
		for r in json("recipes").get("recipes", []):
			_recipes[r.id] = r
	return _recipes

static func recipe(id: String) -> Dictionary:
	return recipes().get(id, {})

## The recipe that builds structure `sid` (or makes item `iid`), if any.
static func recipe_for(out_id: String) -> Dictionary:
	for r in recipes().values():
		if r.out == out_id:
			return r
	return {}

static func debris_loot(id: String) -> Array:
	return json("recipes").get("debris_loot", {}).get(id, [])

static func quests() -> Array:
	return json("tutorial_quests").get("quests", [])

static func quest(id: String) -> Dictionary:
	for q in quests():
		if q.id == id:
			return q
	return {}

static func is_spanish() -> bool:
	return TranslationServer.get_locale().begins_with("es")

## An item's name in the player's language (items.json carries en/es).
static func item_name(id: String) -> String:
	var it := item(id)
	if it.is_empty():
		return STRUCTURE_NAMES.get(id, id)
	return str(it.get("es" if is_spanish() else "en", id))

static func quest_name(q: Dictionary) -> String:
	return str(q.get("es" if is_spanish() else "en", q.get("id", "")))

# ------------------------------------------------------------------ game tuning (not in the JSON)

## Crafting tiers (M3: all four). Tiers 1-2 are known from the start; tier 3-4 recipes are found by
## combining two of their materials in the bag (GDD §10 "Little-Alchemy style"), then show on 🔨.
const MAX_TIER := 4
const KNOWN_TIERS := 2

## Tool wear (GDD §10 "tool durability"): uses before it breaks. One use = one action that needs it.
const TOOL_USES := {"knife": 40, "stone_axe": 8, "fishing_pole": 30, "spear": 20, "shovel": 15,
	"coconut_bowl": 25, "spark_kit": 12}
## Fresh food spoils (GDD §10) after this many hours in the bag and turns into fish guts (compost,
## bait later). Dried / salted food keeps. A smokehouse makes fresh food last 4x as long.
const SPOIL_H := {"fish_small": 24.0, "fish_big": 24.0, "fish_cooked": 48.0}
const SMOKEHOUSE_SPOIL_MULT := 4.0
## Water structures: drinks they hold, water per drink, how they fill.
const WATER_MAX := 4
const WATER_PER_DRINK := 25.0
const RAIN_FILL_PER_H := {"drizzle": 0.5, "rain": 1.0, "storm": 2.0}
const STILL_H := 3.0            # the water still makes one drink every 3 h of daylight
## Fish trap: one catch every 6 h, holds 3.
const TRAP_H := 6.0
const TRAP_MAX := 3
const TRAP_TABLE := [["fish_small", 80], ["fish_big", 12], ["boot", 4], ["seaweed", 4]]

## Skills (GDD §10). Level n needs 10 * n * (n + 1) / 2 XP (10, 30, 60...), max 10; each level makes
## that skill's actions 3 % faster. Weather-sense comes with the weather controller (M4).
const SKILLS := ["foraging", "woodcutting", "fishing", "fire", "cooking", "carpentry", "tinkering", "weather sense"]
## (Trailing spaces = distinct i18n keys: "Fire" / "Drink" already mean something else in other games.)
const SKILL_NAMES := {"foraging": "Foraging", "woodcutting": "Woodcutting", "fishing": "Fishing ", "fire": "Fire ",
	"cooking": "Cooking ", "carpentry": "Carpentry", "tinkering": "Tinkering", "weather sense": "Weather sense"}
const SKILL_MAX := 10
const SKILL_SPEED := 0.03
const ACT_SKILL := {"gather": "foraging", "shake": "foraging", "haul": "foraging", "seawater": "foraging",
	"chop": "woodcutting", "fish": "fishing", "empty_trap": "fishing", "light": "fire", "fuel": "fire"}

## Which skill a recipe trains.
static func recipe_skill(r: Dictionary) -> String:
	if r.get("id", "") == "spark_kit":
		return "fire"
	if r.get("station", "") == "campfire":
		return "cooking"
	if int(r.get("tier", 1)) >= 4:
		return "tinkering"
	return "carpentry"

## Recipes a quest hands out (tutorial_quests.json "reward.recipe"): locked until then.
static func reward_recipes() -> Array:
	var out := []
	for q in quests():
		var r: String = str(q.get("reward", {}).get("recipe", ""))
		if r != "":
			out.append(r)
	return out

## Structures (recipes.json out_type "structure") have no entry in items.json: their names live here
## (English; Spanish via es.json).
const STRUCTURE_NAMES := {
	"campfire": "Campfire", "hammock": "Hammock", "frond_bed": "Frond bed",
	"frond_shelter": "Frond shelter", "tent": "Tent", "crafting_stump": "Crafting stump",
	"rain_catcher": "Rain catcher", "fish_trap": "Fish trap", "drying_rack": "Drying rack",
	"sos_flag": "SOS flag", "garden_plot": "Garden plot", "canopy": "Canopy",
	"water_still": "Water still", "smokehouse": "Smokehouse", "kiln": "Kiln", "sundial": "Sundial",
	"raft_section": "Raft section",
}

## Island layout in plate pixels (art/ref/ref_05_clean_plate = games/wilson/art/plate.webp, 1376x768).
const W := 1376.0
const H := 768.0
const HORIZON_Y := 327.0
## Walkable depth lanes (KICKOFF M1: 2-3 lanes): y and the x range of each.
const LANES := [
	{"y": 398.0, "x0": 300.0, "x1": 800.0},      # owner, 2026-11-09: more walkable ground, closer to the back palms
	{"y": 470.0, "x0": 165.0, "x1": 1060.0},
	{"y": 535.0, "x0": 190.0, "x1": 1210.0},
]
## Where Johnny wakes up on Day 1.
const START_POS := Vector2(640, 482)
const WALK_SPEED := 150.0  # plate pixels per second (walking is free: balance "walk": 0)

## Palms (GDD §13): A and B hold the hammock, C and D are for chopping.
const PALMS := {
	"A": {"pos": Vector2(445, 382), "top": Vector2(428, 240), "choppable": false},
	"B": {"pos": Vector2(600, 382), "top": Vector2(615, 240), "choppable": false},
	"C": {"pos": Vector2(1150, 330), "top": Vector2(1135, 190), "choppable": true},
	"D": {"pos": Vector2(1222, 440), "top": Vector2(1268, 285), "choppable": true},
}
## Where Johnny stands to work a palm.
const PALM_STAND := {"A": Vector2(470, 432), "B": Vector2(575, 432), "C": Vector2(1035, 482), "D": Vector2(1170, 535)}
const PALM_COCONUTS := 3          # coconuts a palm holds
const COCONUT_REGROW_H := 8.0     # one coconut back every 8 h
const PALM_REGROW_DAYS := 7.0     # GDD §13: saplings regrow in ~7 days

## Wreck debris on Day 1 (ref_04_island_debris): sprite, position, and the stand spot.
const DEBRIS := {
	"planks": {"pos": Vector2(262, 468), "stand": Vector2(330, 482), "scale": 0.62},
	"crate": {"pos": Vector2(528, 492), "stand": Vector2(600, 535), "scale": 0.62},
	"barrel": {"pos": Vector2(712, 520), "stand": Vector2(780, 535), "scale": 0.6},
	"sailcloth": {"pos": Vector2(585, 566), "stand": Vector2(640, 535), "scale": 0.6},
	"oar": {"pos": Vector2(330, 566), "stand": Vector2(380, 535), "scale": 0.62},
}

## Gather spots (CRAFTING.md Tier 0: pick up at spots, 2-5 min each). Amount per trip, stock, regrowth.
const SPOTS := {
	"stones": {"pos": Vector2(248, 518), "stand": Vector2(280, 535), "item": "stone", "n": 3, "max": 30, "per_h": 3.0, "min": 3},
	"sticks": {"pos": Vector2(505, 418), "stand": Vector2(505, 432), "item": "stick", "n": 3, "max": 24, "per_h": 2.0, "min": 3},
	"fronds": {"pos": Vector2(395, 420), "stand": Vector2(400, 432), "item": "frond", "n": 4, "max": 30, "per_h": 2.0, "min": 3},
	"dry_fronds": {"pos": Vector2(690, 418), "stand": Vector2(690, 432), "item": "dry_frond", "n": 2, "max": 10, "per_h": 1.0, "min": 3},
	"shells": {"pos": Vector2(1010, 538), "stand": Vector2(990, 535), "item": "shell", "n": 2, "max": 16, "per_h": 1.0, "min": 3},
	"seaweed": {"pos": Vector2(820, 578), "stand": Vector2(820, 535), "item": "seaweed", "n": 2, "max": 12, "per_h": 1.0, "min": 3},
}
## The shallows (fishing, seawater) and the sealed rock (GDD §13: cave opens in M7).
const SHALLOWS := {"pos": Vector2(420, 590), "stand": Vector2(420, 535)}
const CAVE := {"pos": Vector2(1012, 385), "stand": Vector2(960, 482)}
## Shore delivery pile (daily, CRAFTING.md §2).
const SHORE := {"pos": Vector2(905, 568), "stand": Vector2(905, 535)}
## Camp: where each structure goes (placeholder art), and where Johnny stands to build/use it.
const CAMP := {
	"campfire": {"pos": Vector2(640, 512), "stand": Vector2(700, 535)},
	"frond_bed": {"pos": Vector2(470, 500), "stand": Vector2(520, 482)},
	"hammock": {"pos": Vector2(522, 372), "stand": Vector2(522, 432)},
	"frond_shelter": {"pos": Vector2(345, 470), "stand": Vector2(400, 482)},
	"crafting_stump": {"pos": Vector2(770, 480), "stand": Vector2(730, 482)},
	"rain_catcher": {"pos": Vector2(830, 458), "stand": Vector2(820, 482)},
	"drying_rack": {"pos": Vector2(900, 488), "stand": Vector2(880, 482)},
	"fish_trap": {"pos": Vector2(520, 600), "stand": Vector2(520, 535)},
	"sos_flag": {"pos": Vector2(1100, 515), "stand": Vector2(1080, 535)},
	"garden_plot": {"pos": Vector2(980, 500), "stand": Vector2(960, 482)},
	"canopy": {"pos": Vector2(1060, 495), "stand": Vector2(1040, 482)},
	"tent": {"pos": Vector2(700, 452), "stand": Vector2(700, 482)},
	"water_still": {"pos": Vector2(945, 470), "stand": Vector2(925, 482)},
	"smokehouse": {"pos": Vector2(1140, 512), "stand": Vector2(1110, 535)},
	"kiln": {"pos": Vector2(250, 520), "stand": Vector2(285, 535)},
	"sundial": {"pos": Vector2(880, 552), "stand": Vector2(880, 535)},
	"raft_section": {"pos": Vector2(640, 600), "stand": Vector2(640, 535)},
	# Grand Projects (wilson_projects.gd keys), 2026-11-08
	"treehouse": {"pos": Vector2(215, 482), "stand": Vector2(265, 482)},
	"spyglass_tower": {"pos": Vector2(290, 440), "stand": Vector2(330, 432)},
	"shellphone": {"pos": Vector2(790, 545), "stand": Vector2(760, 535)},
	"coconut_radio": {"pos": Vector2(850, 552), "stand": Vector2(830, 535)},
	"windmill": {"pos": Vector2(1205, 548), "stand": Vector2(1150, 535)},
	"lighthouse": {"pos": Vector2(1120, 545), "stand": Vector2(1085, 535)},
	"glider": {"pos": Vector2(345, 548), "stand": Vector2(320, 535)},
	"submarine": {"pos": Vector2(1170, 595), "stand": Vector2(1170, 535)},
}
## Structures drawn from the owner's camp-builds sheet: [sprite, width on screen in plate pixels,
## lift (hanging hammock)].
const CAMP_ART := {"tent": ["tent", 140.0, 0.0], "hammock": ["hammock", 180.0, 6.0],
	"garden_plot": ["garden_plot", 108.0, 0.0], "crafting_stump": ["crafting_stump", 66.0, 0.0],
	"water_still": ["water_still", 70.0, 0.0], "drying_rack": ["drying_rack", 96.0, 0.0],
	"frond_bed": ["frond_bed", 104.0, -6.0], "rain_catcher": ["rain_catcher", 50.0, 0.0],
	# Grand Projects: [sprite, width, lift, folder] (grand.jpg -> art/projects/). Cellar, Desalinator,
	# Museum and Shrine have no art yet: they work but are not drawn.
	"treehouse": ["treehouse", 190.0, 0.0, "projects"], "spyglass_tower": ["spyglass_tower", 62.0, 0.0, "projects"],
	"shellphone": ["shellphone", 70.0, 0.0, "projects"], "coconut_radio": ["coconut_radio", 64.0, 0.0, "projects"],
	"windmill": ["windmill", 96.0, 0.0, "projects"], "lighthouse": ["lighthouse", 62.0, 0.0, "projects"],
	"glider": ["glider", 110.0, 0.0, "projects"], "submarine": ["submarine", 96.0, 0.0, "projects"]}
## Recipe stations -> where the work happens (recipes.json "station").
const STATIONS := {
	"camp": Vector2(600, 482), "anchors": Vector2(522, 432), "shallows": Vector2(520, 535),
	"beach": Vector2(1000, 535), "garden": Vector2(960, 482),
}
## A station that is a structure: it must be built first.
const STATION_STRUCTURE := {"campfire": "campfire", "stump": "crafting_stump", "rack": "drying_rack", "kiln": "kiln"}

## Action timings and costs the design leaves open (real minutes; energy from balance.json where it
## has a key: haul / chop / fish / craft / explore / walk).
const ACT := {
	# minutes are REAL minutes (0.1 = 6 s). Early actions are quick on purpose (owner, 2026-11-09);
	# energy is per action, scaled down with the time (the old 10-minute hauls cost 10).
	"haul": {"min": 0.35, "energy": 4.0},
	"gather": {"min": 0.2, "energy": 1.5},
	"shake": {"min": 0.2, "energy": 1.5},
	"chop": {"min": 6.0, "energy": 6.0},
	"fish": {"min": 3.0, "energy": 3.0},
	"seawater": {"min": 0.1, "energy": 1.0},
	"inspect": {"min": 0.1, "energy": 0.0},
	"fuel": {"min": 0.1, "energy": 0.0},
	"light": {"min": 0.25, "energy": 2.0},
	"tally": {"min": 0.1, "energy": 0.0},
	"shore": {"min": 0.5, "energy": 3.0},
	"nap": {"min": 30.0, "energy": 0.0},
	"empty_trap": {"min": 0.3, "energy": 1.0},
}
## Crafting: tier 1-2 recipes take this fraction of the design's minutes (tiers 3-4 keep theirs).
const CRAFT_EARLY_MULT := 0.2
## What chopping a palm gives (CRAFTING.md: trunk from chopped palms).
const CHOP_LOOT := [["trunk", 2], ["frond", 6], ["stick", 4]]
## Fishing (GDD §5 / QUESTS S19 boot): weights out of 100. The first catch is always a small fish.
const FISH_TABLE := [["fish_small", 70], ["fish_big", 8], ["boot", 5], ["tin_can", 5], ["seaweed", 7], ["", 5]]
## Campfire fuel: hours one item adds; a new fire starts with 3 h.
const FUEL_H := {"stick": 0.5, "driftwood": 2.0, "dry_frond": 0.25, "trunk": 4.0, "plank": 1.5}
const FIRE_START_H := 3.0
## T05: "3+ funny fails first". The first fire always fails this many times.
const FIRST_FIRE_FAILS := 3
const FIRE_FAIL_CHANCE := 0.25

## Eating and drinking (GDD §5 lists the foods; amounts are ours). nausea = chance; raw fish's first
## time always (T04 gag).
const FOOD := {
	"coconut": {"verb": "drink", "food": 8, "water": 20, "gives": [["coconut_shell", 1], ["husk_fiber", 3]]},
	"fish_small": {"verb": "eat", "food": 12, "water": 0, "nausea": 0.4},
	"fish_big": {"verb": "eat", "food": 22, "water": 0, "nausea": 0.4},
	"fish_cooked": {"verb": "eat", "food": 25, "water": 0, "gives": [["fish_bone", 1]]},
	"fish_dried": {"verb": "eat", "food": 20, "water": -5},
}
const NAUSEA_WATER := -10.0
const NAUSEA_H := 3.0

## Sleeping and asleep drain: food / water drain at half speed while asleep or napping (design gap).
const SLEEP_DRAIN_MULT := 0.5
## Beds from worst to best (balance.json sleep_restore_per_h keys + frond_shelter from the errata).
const BED_RANK := ["sand", "frond_bed", "hammock", "frond_shelter", "tent", "tent_mattress", "treehouse"]
const SHADED_BEDS := ["hammock", "frond_shelter", "tent", "tent_mattress", "treehouse"]
const SHELTERED_BEDS := ["frond_shelter", "tent", "tent_mattress", "treehouse"]
const RESTED_H := 16.0           # how long the Rested buff lasts
const SANDY_H := 8.0             # how long Sandy lasts
const COLLAPSE_WAKE_ENERGY := 40.0  # collapse: sleeps on the sand until this much energy
const FAINT_WAKE_HP := 25.0      # HP 0: wakes next morning with this much HP
const DAY_NAP_MAX_H := 4.0       # "Sleep" by day: until rested, at most this long
const QUEUE_MAX := 5             # KICKOFF M1
const LOW_BAR := 25.0            # a bar under this pulses + a thought bubble
## Shore delivery: what never washes ashore (made on the island, or cave-only).
const NOT_ASHORE := ["stone", "sand", "seawater", "fish_guts", "husk_fiber", "coconut_shell", "trunk",
	"dry_frond", "clay", "wax", "fish_small", "fish_bone", "bait", "fish_big"]
const RARITY_LETTER := {"common": "C", "uncommon": "U", "rare": "R", "mythic": "M"}

## Weather states (GDD §8). The controller (M4) is deterministic: engine.weather_at(t).
const WEATHER := ["clear", "cloudy", "overcast", "drizzle", "rain", "storm", "fog", "wind", "heatwave", "cold_snap"]
const RAINY := ["drizzle", "rain", "storm"]
## Sea motion per weather (0..1): the water shader's amplitude.
const SEA := {"clear": 0.35, "cloudy": 0.45, "overcast": 0.5, "drizzle": 0.55, "rain": 0.65, "storm": 1.0,
	"fog": 0.3, "wind": 0.8, "heatwave": 0.25, "cold_snap": 0.5}

## What to do for each tutorial quest (the HUD's goal line; quests themselves: tutorial_quests.json).
const QUEST_HINTS := {
	"T01": "Tap the castaway. Someone has to get this day started.",
	"T02": "Tap the wrecked crate to open it.",
	"T03": "🔨 Craft a fishing pole (stick + rope + hook, needs the knife).",
	"T04": "Tap the shallows to fish.",
	"T05": "Make a spark kit, then build a campfire (8 stones, 5 sticks).",
	"T06": "Salvage the sailcloth, then hang the hammock between palms A and B.",
	"T07": "Shake a palm for a coconut, then drink it from the 🎒 bag.",
	"T08": "Make a stone axe, then chop palm C (right of the rocks).",
	"T09": "Build a frond shelter (25 fronds, 6 sticks, 4 rope).",
	"T10": "The sea brings a bottle every morning. Haul it in and open it.",
	"T11": "Take a power nap in the shade.",
	"T12": "Build a crafting stump, then scratch a tally mark on it.",
}

const DEBRIS_NAMES := {"crate": "wrecked crate", "planks": "pile of planks", "sailcloth": "torn sailcloth",
	"barrel": "old barrel", "oar": "broken oar"}

## The tutorial's journal lines (tutorial_quests.json "journal_en"), listed here so `hub.py i18n` finds
## them: the journal shows them through tr(). Keep in step with the JSON (tools/test_wilson.gd checks).
const QUEST_JOURNAL := [
	"Day 1. Still here. Shocking.",
	"A crate. Contents: rope, a hook, a knife. Christmas came early.",
	"I made a fishing pole. Humanity is proud.",
	"Ate it raw. Regretted it instantly.",
	"Fire. After a lot of failing. Do not ask how many times.",
	"Hammock. Five stars. Would swing again.",
	"Coconut water: the sea's apology.",
	"Tree: 0. Me: 1.",
	"A roof! Civilization is back, baby.",
	"Mail! No bills. Best island ever.",
	"30 minutes of nothing. Perfect.",
	"Day counter started. Cheerful.",
]

# ------------------------------------------------------------------ lines (DIALOGUE.md, EN; ES in es.json)

const LINES := {
	"wake": ["Another day in paradise. Said no one, ever.", "Oh good, you're back. I was talking to the coconut.",
		"I've decided the sea owes me money."],
	"day1": ["Day 1. Still here. Shocking."],
	"idle": ["If I stare at the horizon long enough, it'll blink.", "I name this rock Gary.", "Seagull: 1. Me: 0.",
		"Is that a ship? ...No. Cloud. Always a cloud."],
	"fire_fail": ["Humanity's first invention. I'm failing humanity's first invention.", "Fire! ...Smoke. It's mostly smoke.",
		"Spark. Spark. Spark. Nothing. Classic."],
	"fire_ok": ["Warm. Finally, something on this island likes me."],
	"fish": ["Fish are just wet vegetarians with attitude.", "Dinner is served. By me. To me. Five stars."],
	"boot": ["Got one! ...It's a boot."],
	"nothing": ["The fish sent their regrets."],
	"food": ["My stomach is filing a complaint."],
	"water": ["Thirsty. The ocean mocks me."],
	"energy": ["Tired. Not 'sleepy' tired. 'Existential' tired.", "I'd kill for a nap. Or just a nap."],
	"hp": ["I don't feel great. Like, medically."],
	"sleep_sand": ["Sand. In places sand should not be."],
	"sleep_hammock": ["Five stars. Would swing again."],
	"sleep_roof": ["A roof! I've gone full civilization."],
	"rested": ["Full energy. Still stranded."],
	"collapse": ["Nope. Floor time."],
	"faint": ["Everything is... spinny."],
	"craft": ["Rope. The duct tape of the sea.", "I made a thing. The thing is... a thing.",
		"Engineer? No. Stubborn? Absolutely."],
	"nausea": ["Raw fish. Bold choice. Wrong choice."],
	"seawater": ["Salt water makes you thirstier. Even I know that."],
	"cave": ["The rock is breathing. Probably the wind. Probably."],
	"full": ["No room. My pockets have a limit, unlike my problems."],
	"bottle": ["Mail! No bills. Best island ever.", "A bottle. Please be a pizza menu."],
	"shore": ["The sea delivered. No signature needed."],
	"chop": ["Timber! ...Sorry, tree."],
	"tally": ["One more line. Art, really."],
	"rain": ["Free shower. Finally, a perk."],
	"storm": ["The sky is yelling at me. Rude."],
	"heat": ["I'm now the color of regret."],
	"cold": ["I'd trade my dignity for a blanket."],
	"fog": ["Ah yes. Visibility: zero. Mood: matching."],
	"busy": ["One thing at a time. Five, tops."],
	"combine_none": ["Those two don't go together. I checked. Twice.", "Nope. That's just two things touching.",
		"Science says no."],
	"discover": ["Eureka. Or sunstroke. Either way, a new recipe.", "I'm basically an inventor now."],
	"broke": ["And it broke. Of course it broke."],
	"spoiled": ["Something in my bag smells like a decision I regret."],
	"no_nap": ["Two naps a day. Even I have standards."],
}

## Curated bottle notes (B08 "Message of the Day" style; checked facts, GDD §1 pillar 6).
const BOTTLE_NOTES := [
	"Fun fact: high tide comes back about every 12 h 25 min.",
	"Fun fact: the Moon goes from new to new in about 29.5 days.",
	"Never drink seawater: the salt makes your body lose more water than you drank.",
	"Coconut water is safe to drink straight from a young green coconut.",
	"A reef knot joins two ropes of the same thickness. Right over left, then left over right.",
	"Smoke by day and fire by night are the classic signals for rescue.",
	"Fish spoil fast in the heat: cook them, or dry them in the sun and wind.",
]

## --- Weather controller + tides (M4, GDD section 4 and 8) ---
const WEATHER_BLOCK_S := 10800.0   # a spell of weather lasts 3 h (two blocks can merge into one 6 h spell)
const FORECAST_BASE_H := 12        # barometer (GDD section 8)
const FORECAST_PER_LEVEL_H := 3    # weather sense extends it
const TIDE_MIN := 745.0            # 12 h 25 min
const LOW_TIDE := 0.2              # level under this = low tide (the reef shows)
## Weights per season (summer / autumn / winter / spring of the player's hemisphere).
const WEATHER_WEIGHTS := {
	"summer": {"clear": 30, "cloudy": 15, "overcast": 8, "drizzle": 6, "rain": 8, "storm": 8, "fog": 3, "wind": 10, "heatwave": 12},
	"autumn": {"clear": 25, "cloudy": 20, "overcast": 14, "drizzle": 10, "rain": 10, "storm": 5, "fog": 8, "wind": 8},
	"winter": {"clear": 22, "cloudy": 18, "overcast": 14, "drizzle": 8, "rain": 8, "storm": 4, "fog": 8, "wind": 8, "cold_snap": 10},
	"spring": {"clear": 30, "cloudy": 18, "overcast": 8, "drizzle": 8, "rain": 10, "storm": 5, "fog": 5, "wind": 14},
}
const WEATHER_ICON := {"clear": "☀", "cloudy": "⛅", "overcast": "☁", "drizzle": "🌦", "rain": "🌧", "storm": "⛈",
	"fog": "🌫", "wind": "💨", "heatwave": "🔥", "cold_snap": "❄"}
const WEATHER_NAMES := {"clear": "Clear sky", "cloudy": "Cloudy", "overcast": "Overcast", "drizzle": "Drizzle", "rain": "Rain",
	"storm": "Storm", "fog": "Fog", "wind": "Windy", "heatwave": "Heatwave", "cold_snap": "Cold snap"}
## Low tide uncovers the reef: one extra find when gathering shells or seaweed.
const REEF_SPOTS := ["shells", "seaweed"]
const REEF_TABLE := [["shell", 38], ["seaweed", 24], ["salt", 14], ["sea_glass", 12], ["conch_shell", 7], ["bottle", 4], ["pearl", 1]]
## Fog brings more bottles; rain makes fish bite; wind shakes coconuts down faster.
const FOG_EXTRA_BOTTLE := 1
const RAIN_FISH_BONUS := 0.12      # chance a "nothing" becomes a catch while it rains
const WIND_REGROW_MULT := 2.0

## --- Grand Projects (wilson_projects.gd) ---
const TREEHOUSE_RATE := 26.0       # 20 energy an hour x1.3 (GDD / CRAFTING.md GP07)
const DESALINATOR_THIRST := 0.4    # thirst drains 60 % slower
const CELLAR_SLOTS := 20
const SHRINE_LUCK := 1.1           # uncommon / rare / mythic weights x1.1 on the shore roll
const TOWER_FORECAST_H := 6

## --- Sky events, streak, curated bottles (2026-11-09) ---
const TROPICAL_CHANCE := 0.15      # of storm spells, a rare "tropical" one (GDD section 8): 3 extra shore rolls
const ECLIPSE_CHANCE := 0.35       # of new-moon days
const FULL_MOON_WIDTH := 0.035     # phase within this of 0.5 = full moon
const MOON_FISH_CHANCE := 0.2      # a full-moon night catch is a pearl
## Login streak (balance.json login): rewards by day of the 30-day calendar; 7 / 14 / 28 add a shore roll.
const STREAK_BONUS_DAYS := [7, 14, 28]
const STREAK_REWARDS := {
	1: [["stick", 3]], 2: [["frond", 4]], 3: [["stone", 4]], 4: [["shell", 3]], 5: [["rope", 1]],
	6: [["seaweed", 3]], 7: [["sea_glass", 1]], 8: [["stick", 4]], 9: [["frond", 5]], 10: [["salt", 2]],
	11: [["stone", 5]], 12: [["rope", 1]], 13: [["shell", 4]], 14: [["charcoal", 2]], 15: [["stick", 5]],
	16: [["frond", 6]], 17: [["fish_oil", 1]], 18: [["stone", 6]], 19: [["rope", 2]], 20: [["cloth_scrap", 2]],
	21: [["sea_glass", 1]], 22: [["stick", 6]], 23: [["frond", 6]], 24: [["nail", 2]], 25: [["rope", 2]],
	26: [["salt", 3]], 27: [["shell", 5]], 28: [["pearl", 1]], 29: [["plank", 1]], 30: [["amber", 1]],
}
const BOTTLE_PEN_PALS := ["Marta (island 4)", "Old Bram", "Someone called Dot", "A very polite gull", "Captain Nobody", "Priya (island 9)"]
const TIER2_NEEDS_TIER1 := 2       # craft tree: tier-2 recipes appear after two tier-1 things are made

## Day 1 checklist (owner, 2026-11-09: "collect some stuff quickly, make the basic base, enough to use up
## your energy and go to bed"). Shown on the HUD goal line before the tutorial quests; the tutorial still runs.
const START_ENERGY := 65.0
const INTRO := [
	{"key": "got:stone", "need": 8, "hint": "Gather pebbles", "long": "Collect some pebbles: ✋ in the castaway's menu, or tap the stones."},
	{"key": "got:stick", "need": 6, "hint": "Gather sticks", "long": "Collect some sticks."},
	{"key": "got:frond", "need": 10, "hint": "Gather palm fronds", "long": "Collect palm fronds."},
	{"key": "made:frond_bed", "need": 1, "hint": "Craft a frond bed", "long": "Make a frond bed in 🔨 Craft."},
	{"key": "slept", "need": 1, "hint": "Go to bed", "long": "Tired? Go to bed: 💤 (or the Y button)."},
]

## The guided opening (owner, 2026-11-09): the HUD builds up one part at a time. `show` = the parts that
## appear when the step starts: a, b, bag, craft, hp, food, water, energy, mood, clock, journal, pause.
## `reqs` = [stat key, amount]; `card` = a "Got it" card explains the HUD part. `short` is the HUD line
## (under 5 words); `long` is the journal's fuller text.
const TUT := [
	{"id": "walk", "short": "Learn to walk", "long": "Push the left stick to walk around the beach.", "reqs": [["tut:walk", 1]]},
	{"id": "buttons", "short": "Learn the buttons", "long": "A uses what is close. B goes back. Press A, then B.", "reqs": [["tut:ab", 1]], "show": ["a", "b"]},
	{"id": "pebble", "short": "Pick up a pebble", "long": "Walk to the stones on the left and press A.", "reqs": [["got:stone", 1]], "objective": ["spot:stones"]},
	{"id": "bag", "short": "Open your inventory", "long": "Tap the backpack, top right.", "reqs": [["tut:bag", 1]], "show": ["bag"]},
	{"id": "pebbles", "short": "Gather more pebbles", "long": "A campfire needs plenty of stones. Keep picking them up.", "reqs": [["got:stone", 9]], "objective": ["spot:stones"]},
	{"id": "wood", "short": "Collect wood", "long": "Six sticks from the pile in the middle, and one dry frond from the pile on the right.", "reqs": [["got:stick", 6], ["got:dry_frond", 1]], "objective": ["spot:sticks", "spot:dry_fronds"]},
	{"id": "spark", "short": "Make a spark kit", "long": "Open the hammer button, top right. Craft a spark kit first.", "reqs": [["made:spark_kit", 1]], "show": ["craft"], "objective": ["craft"]},
	{"id": "fire", "short": "Build a campfire", "long": "Craft a campfire: 8 stones and 5 sticks.", "reqs": [["ev:structure_built:campfire", 1]], "objective": ["craft"]},
	{"id": "hp", "short": "Meet your health", "long": "Health. Look after the other bars and it looks after you.", "card": true, "show": ["hp"]},
	{"id": "food", "short": "Meet your hunger", "long": "Food. Fish, coconuts and cooked meals fill it.", "card": true, "show": ["food"]},
	{"id": "water", "short": "Meet your thirst", "long": "Water. Coconuts and rain catchers fill it. The sea does not.", "card": true, "show": ["water"]},
	{"id": "energy", "short": "Meet your energy", "long": "Energy. Work uses it. Sleep in a bed brings it back.", "card": true, "show": ["energy"]},
	{"id": "mood", "short": "Watch your mood", "long": "Mood. A good mood makes everything a little better.", "card": true, "show": ["mood"]},
	{"id": "clock", "short": "Check the day", "long": "The day counter. The island runs on real time, even while you are away.", "card": true, "show": ["clock"]},
	{"id": "journal", "short": "Open your journal", "long": "Tap the notebook, top right. Quests and news live there.", "reqs": [["tut:journal", 1]], "show": ["journal", "pause"]},
]

## HUD quest lines (under 5 words); the journal keeps the full QUEST_HINTS text.
const QUEST_SHORT := {
	"T01": "Wake up", "T02": "Open the crate", "T03": "Craft a fishing pole", "T04": "Catch a fish",
	"T05": "Build a campfire", "T06": "Hang a hammock", "T07": "Drink a coconut", "T08": "Chop a palm",
	"T09": "Build a shelter", "T10": "Open a bottle", "T11": "Take a nap", "T12": "Tally your days",
}
