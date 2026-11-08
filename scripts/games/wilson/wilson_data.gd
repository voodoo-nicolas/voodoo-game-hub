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

## Crafting tiers built so far (KICKOFF M2: Tier 1-2).
const MAX_TIER := 2

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
	{"y": 432.0, "x0": 330.0, "x1": 760.0},
	{"y": 482.0, "x0": 175.0, "x1": 1040.0},
	{"y": 535.0, "x0": 200.0, "x1": 1190.0},
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
	"tent": {"pos": Vector2(345, 470), "stand": Vector2(400, 482)},
	"crafting_stump": {"pos": Vector2(770, 480), "stand": Vector2(730, 482)},
	"rain_catcher": {"pos": Vector2(830, 458), "stand": Vector2(820, 482)},
	"drying_rack": {"pos": Vector2(900, 488), "stand": Vector2(880, 482)},
	"fish_trap": {"pos": Vector2(520, 600), "stand": Vector2(520, 535)},
	"sos_flag": {"pos": Vector2(1100, 515), "stand": Vector2(1080, 535)},
	"garden_plot": {"pos": Vector2(980, 500), "stand": Vector2(960, 482)},
	"canopy": {"pos": Vector2(1060, 495), "stand": Vector2(1040, 482)},
}
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
	"haul": {"min": 5.0, "cost": "haul"},
	"gather": {"min": 3.0, "energy": 2.0},
	"shake": {"min": 4.0, "energy": 2.0},
	"chop": {"min": 30.0, "cost": "chop"},
	"fish": {"min": 15.0, "cost": "fish"},
	"seawater": {"min": 2.0, "energy": 1.0},
	"inspect": {"min": 1.0, "energy": 0.0},
	"fuel": {"min": 1.0, "energy": 0.0},
	"light": {"min": 3.0, "energy": 2.0},
	"tally": {"min": 1.0, "energy": 0.0},
	"shore": {"min": 5.0, "cost": "haul"},
	"nap": {"min": 30.0, "energy": 0.0},
}
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
const BED_RANK := ["sand", "frond_bed", "hammock", "frond_shelter", "tent", "tent_mattress"]
const SHADED_BEDS := ["hammock", "frond_shelter", "tent", "tent_mattress"]
const SHELTERED_BEDS := ["frond_shelter", "tent", "tent_mattress"]
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

## Weather states (GDD §8). M2 only uses them through the debug panel; the controller is M4.
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
