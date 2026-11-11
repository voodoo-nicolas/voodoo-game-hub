extends RefCounted

## Grand Projects (M6 in this build; GDD / CRAFTING.md section 4): long save-ups of rare materials. Paying the
## materials starts a build that takes `days` real days (an absolute end time; Johnny keeps doing
## other things), then the project stands on the island for good and its effect applies.
## The finished project is stored in engine.structures under its `key`, so beds / effects can test it.
##
## Not built (owner, 2026-11-08): GP09 slingshot + GP10 seagull express (bottle mail), GP11 beach arcade
## (hub tie-in), GP12 home cinema (needs wax candles + mirrors, not in the item list).
## Substitutions: GP08 "brass fitting" = brass tube, GP13 "palm ribs" = sticks.

const LIST := [
	{"id": "GP01", "key": "shellphone", "en": "Shellphone", "es": "Caracolófono", "days": 1.0,
		"mats": [["conch_shell", 1], ["sea_glass", 2], ["copper_wire", 3], ["battery", 1], ["tar", 1], ["pearl", 1]],
		"effect": "Shows the moon, sunrise, sunset and weather in the sea report."},
	{"id": "GP02", "key": "windmill", "en": "Windmill", "es": "Molino de viento", "days": 2.0,
		"mats": [["plank", 12], ["sailcloth", 2], ["rope", 8], ["copper_wire", 4], ["magnet", 2]],
		"effect": "Power for the radio. Lamps burn longer."},
	{"id": "GP03", "key": "coconut_radio", "en": "Coconut Radio", "es": "Radio de coco", "days": 1.0, "needs": "GP02",
		"mats": [["coconut_shell", 2], ["copper_wire", 2], ["magnet", 1], ["radio_tube", 1], ["rope", 2]],
		"effect": "Radio Mysterious: a new broadcast every morning, and a better mood."},
	{"id": "GP04", "key": "desalinator", "en": "Desalinator", "es": "Desalinizadora", "days": 2.0,
		"mats": [["sea_glass", 6], ["barrel", 2], ["copper_tube", 2], ["tar", 2], ["bamboo_bundle", 1]],
		"effect": "Fresh water without rain: thirst drains 60% slower."},
	{"id": "GP05", "key": "spyglass_tower", "en": "Spyglass Tower", "es": "Torre del catalejo", "days": 2.0,
		"mats": [["plank", 6], ["bamboo_bundle", 2], ["spyglass", 1], ["rope", 6], ["stone", 20]],
		"effect": "Forecast 6 h further, with or without a barometer. Spots ships."},
	{"id": "GP06", "key": "cellar", "en": "Cellar", "es": "Bodega", "days": 2.0,
		"mats": [["plank", 12], ["clay_jar", 6], ["salt", 20], ["stone", 30]],
		"effect": "Food never spoils. 20 more bag slots."},
	{"id": "GP07", "key": "treehouse", "en": "Treehouse", "es": "Casa del árbol", "days": 3.0,
		"mats": [["plank", 24], ["bamboo_bundle", 3], ["rope", 20], ["frond", 40], ["nail", 50]],
		"effect": "The best bed on the island (26 energy an hour), storm-proof."},
	{"id": "GP08", "key": "lighthouse", "en": "Lighthouse of Nonsense", "es": "Faro del disparate", "days": 3.0,
		"mats": [["stone", 60], ["plank", 20], ["sea_glass", 6], ["fish_oil", 10], ["brass_tube", 2]],
		"effect": "A beacon that attracts ships. They always leave."},
	{"id": "GP13", "key": "glider", "en": "Glider: Escape Plan Z", "es": "Planeador: Plan Z de escape", "days": 2.0,
		"mats": [["sailcloth", 4], ["plank", 10], ["rope", 10], ["stick", 10], ["bamboo_pole", 10]],
		"effect": "An escape attempt. It will not work. Earns a plaque."},
	{"id": "GP14", "key": "submarine", "en": "Barrel Submarine", "es": "Submarino de barril", "days": 2.0,
		"mats": [["barrel", 3], ["tar", 6], ["sea_glass", 1], ["copper_tube", 2], ["rope", 6]],
		"effect": "An escape attempt. It will not work. Earns a plaque."},
	{"id": "GP15", "key": "museum", "en": "Museum of Failure", "es": "Museo del fracaso", "days": 1.0, "plaques": 2,
		"mats": [["stone", 20]],
		"effect": "Shows off every failed escape. A better mood."},
	{"id": "GP16", "key": "shrine", "en": "Golden Coconut Shrine", "es": "Santuario del coco dorado", "days": 1.0,
		"mats": [["golden_coconut", 1], ["amber", 1], ["old_coin", 5]],
		"effect": "10% better luck on the daily shore delivery."},
]

## Radio Mysterious: one a morning (index = day number).
const BROADCASTS := [
	"Radio Mysterious: a man reads the shipping forecast to nobody. It is soothing.",
	"Radio Mysterious: a song about a coconut. Possibly written about me.",
	"Radio Mysterious: static, then a cough, then more static.",
	"Radio Mysterious: tonight's tides, read very slowly by someone who has never seen the sea.",
	"Radio Mysterious: a recipe for fish. I know that recipe.",
	"Radio Mysterious: three beeps. Nobody has ever explained the three beeps.",
	"Radio Mysterious: a lullaby in a language I almost recognise.",
]

## Spyglass Tower: a ship, once a day.
const SHIPS := [
	"A ship on the horizon. It did not see me. It never does.",
	"A plane, very high. I waved. It was polite about it.",
	"A cargo ship, miles away. Someone on deck might have looked up.",
	"A sail. Or a cloud. The spyglass is not conclusive.",
]

## The beacon draws a boat. It never stays.
const LIGHTHOUSE_FAILS := [
	"The beacon drew a fishing boat. It turned around when it saw the lighthouse. Hurtful.",
	"A ship came close, read the lighthouse sign, and left. The sign says SERVICES.",
	"The beacon worked. The ship waved. The ship kept going.",
]

static func get_project(id: String) -> Dictionary:
	for p in LIST:
		if p.id == id:
			return p
	return {}

static func project_name(p: Dictionary) -> String:
	return str(p.get("es" if TranslationServer.get_locale().begins_with("es") else "en", p.id))

## Where a missing material comes from, for the wishlist (rarity letter of items.json).
static func source_hint(rarity: String) -> String:
	match rarity:
		"C":
			return "Gather it on the beach."
		"U":
			return "Shore delivery, or salvage from the wreck."
		"R":
			return "Rare: shore delivery, reef at low tide, bottles."
		"M":
			return "Mythic: a very lucky shore delivery."
		"T":
			return "Craft it."
	return "Gather it on the beach."
