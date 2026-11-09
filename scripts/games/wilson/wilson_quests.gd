extends RefCounted

## Side quests (M5, QUESTS.md): gentle, never timed, never lost. They run beside the tutorial and all
## count from the moment they are listed. Each one watches one counter in `engine.stats`:
##   "ev:<event>"        every _emit (caught, gathered, drank, ate, nap_taken, bottle_opened, ...)
##   "ev:<event>:<id>"   the same with the item / structure id (caught:fish_big, structure_built:tent)
##   "made:<recipe id>"  a recipe finished (item or structure)
##   "wx:<weather>"      that weather started on the island
##   "reef", "low_tides" low-tide finds, low tides seen
## reward: {"xp": {skill: n}, "items": [[id, n]], "gag": id, "decor": id, "title": text}
## Quests whose systems are not built yet (bottle mail, cave, Grand Projects, escape gags) are in
## docs/wilson/DECISIONS.md under "Not built yet".

const LIST := [
	{"id": "S01", "en": "Salt of the Earth", "es": "Sal de la tierra", "goal": "Make salt.", "stat": "made:salt", "need": 1,
		"reward": {"items": [["salt", 2]], "xp": {"cooking": 3}}},
	{"id": "S02", "en": "Rain Check", "es": "Chubasco pendiente", "goal": "Build a rain catcher.", "stat": "made:rain_catcher", "need": 1,
		"reward": {"xp": {"carpentry": 4}}},
	{"id": "S03", "en": "Dry Spell", "es": "Racha seca", "goal": "Dry a fish.", "stat": "made:dry_fish", "need": 1,
		"reward": {"items": [["fish_dried", 1]], "xp": {"cooking": 3}}},
	{"id": "S04", "en": "Clean Living", "es": "Vida limpia", "goal": "Build the water still.", "stat": "made:water_still", "need": 1,
		"reward": {"xp": {"tinkering": 4}}},
	{"id": "S05", "en": "Fish Whisperer", "es": "Susurrador de peces", "goal": "Catch 10 fish.", "stat": "ev:caught", "need": 10,
		"reward": {"xp": {"fishing": 10}, "items": [["bait", 3]]}},
	{"id": "S06", "en": "Trap Door", "es": "Trampilla", "goal": "Build a fish trap.", "stat": "made:fish_trap", "need": 1,
		"reward": {"xp": {"fishing": 4}}},
	{"id": "S07", "en": "Sunburn Season", "es": "Temporada de quemaduras", "goal": "Build a canopy.", "stat": "made:canopy", "need": 1,
		"reward": {"xp": {"carpentry": 4}}},
	{"id": "S09", "en": "Storm Survivor", "es": "Superviviente de tormentas", "goal": "Live through a storm.", "stat": "wx:storm", "need": 1,
		"reward": {"items": [["plank", 3]], "gag": "storm_hair"}},
	{"id": "S10", "en": "Low Tide Treasure", "es": "Tesoro de la marea baja", "goal": "Find 5 reef items at low tide.", "stat": "reef", "need": 5,
		"reward": {"items": [["sea_glass", 2]], "xp": {"foraging": 6}}},
	{"id": "S12", "en": "Compost Happens", "es": "El compost ocurre", "goal": "Make compost.", "stat": "made:compost", "need": 1,
		"reward": {"xp": {"foraging": 3}}},
	{"id": "S13", "en": "Charcoal Artist", "es": "Artista del carbón", "goal": "Make charcoal.", "stat": "made:charcoal", "need": 1,
		"reward": {"xp": {"fire": 4}, "items": [["charcoal", 2]]}},
	{"id": "S18", "en": "Bowl Over", "es": "Bol sobre bol", "goal": "Make 3 coconut bowls.", "stat": "made:coconut_bowl", "need": 3,
		"reward": {"xp": {"carpentry": 4}}},
	{"id": "S19", "en": "Boot Camp", "es": "Campamento de botas", "goal": "Fish up a boot.", "stat": "ev:caught:boot", "need": 1,
		"reward": {"gag": "boot_camp"}},
	{"id": "S22", "en": "Big Catch", "es": "Gran captura", "goal": "Catch a big fish.", "stat": "ev:caught:fish_big", "need": 1,
		"reward": {"items": [["fish_oil", 1]], "decor": "fish_trophy"}},
	{"id": "S15", "en": "Hoarder", "es": "Acumulador", "goal": "Get your bag up to 32 slots.", "stat": "capacity", "need": 32,
		"reward": {"items": [["cloth_scrap", 2]]}},
	{"id": "S16", "en": "Pole Position", "es": "Pole position", "goal": "Sleep on 5 kinds of bed.", "stat": "bed_kinds", "need": 5,
		"reward": {"gag": "bed_tester"}},
	{"id": "S17", "en": "Midnight Snack", "es": "Picoteo de medianoche", "goal": "Cook a meal at night.", "stat": "night_cook", "need": 1,
		"reward": {"xp": {"cooking": 4}}},
	{"id": "W03", "en": "Fog of War", "es": "Niebla de guerra", "goal": "Sit through a fog.", "stat": "wx:fog", "need": 1,
		"reward": {"items": [["bottle", 1]]}},
	{"id": "W04", "en": "Heatwave Hobbies", "es": "Pasatiempos de ola de calor", "goal": "Survive a heatwave.", "stat": "wx:heatwave", "need": 1,
		"reward": {"xp": {"weather sense": 5}}},
	{"id": "W05", "en": "Winter-ish", "es": "Casi invierno", "goal": "Survive a cold snap.", "stat": "wx:cold_snap", "need": 1,
		"reward": {"decor": "warm_blanket"}},
	{"id": "W07", "en": "Tide Table", "es": "Tabla de mareas", "goal": "See 4 low tides.", "stat": "low_tides", "need": 4,
		"reward": {"xp": {"weather sense": 8}, "decor": "tide_chart"}},
	{"id": "W11", "en": "Weather Watcher", "es": "Vigía del tiempo", "goal": "Sit through rain, wind and fog.", "stat": "wx_kinds", "need": 3,
		"reward": {"xp": {"weather sense": 6}}},
	{"id": "A04", "en": "Hermit Fashion", "es": "Moda ermitaña", "goal": "Make a frond hat.", "stat": "made:frond_hat", "need": 1,
		"reward": {"decor": "hat_hook"}},
	{"id": "A11", "en": "Sunday Roast", "es": "Asado dominical", "goal": "Cook 5 meals.", "stat": "made:cook_fish", "need": 5,
		"reward": {"xp": {"cooking": 8}}},
]

static func get_quest(id: String) -> Dictionary:
	for q in LIST:
		if q.id == id:
			return q
	return {}

static func quest_name(q: Dictionary) -> String:
	return str(q.get("es" if TranslationServer.get_locale().begins_with("es") else "en", q.id))
