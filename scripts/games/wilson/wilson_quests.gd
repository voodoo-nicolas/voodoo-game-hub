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
	{"id": "G01", "en": "Call Me Maybe", "es": "Llámame, tal vez", "goal": "Build the Shellphone.", "stat": "project:shellphone", "need": 1,
		"reward": {"xp": {"tinkering": 10}}},
	{"id": "G02", "en": "Wind of Change", "es": "Vientos de cambio", "goal": "Build the Windmill.", "stat": "project:windmill", "need": 1,
		"reward": {"xp": {"carpentry": 10}}},
	{"id": "G03", "en": "Tune In", "es": "Sintonizá", "goal": "Build the Coconut Radio.", "stat": "project:coconut_radio", "need": 1,
		"reward": {"xp": {"tinkering": 10}}},
	{"id": "G04", "en": "Pure Genius", "es": "Puro genio", "goal": "Build the Desalinator.", "stat": "project:desalinator", "need": 1,
		"reward": {"xp": {"tinkering": 10}}},
	{"id": "G05", "en": "Eagle Eye", "es": "Ojo de águila", "goal": "Build the Spyglass Tower.", "stat": "project:spyglass_tower", "need": 1,
		"reward": {"xp": {"weather sense": 10}}},
	{"id": "G06", "en": "Cold Storage", "es": "Cámara fría", "goal": "Build the Cellar.", "stat": "project:cellar", "need": 1,
		"reward": {"xp": {"cooking": 10}}},
	{"id": "G07", "en": "Up in the Trees", "es": "Allá arriba en los árboles", "goal": "Build the Treehouse.", "stat": "project:treehouse", "need": 1,
		"reward": {"xp": {"carpentry": 15}}},
	{"id": "G08", "en": "Beacon of Nonsense", "es": "Faro del sinsentido", "goal": "Build the Lighthouse.", "stat": "project:lighthouse", "need": 1,
		"reward": {"xp": {"tinkering": 15}}},
	{"id": "G13", "en": "Plan Z", "es": "Plan Z", "goal": "Launch the glider.", "stat": "project:glider", "need": 1,
		"reward": {"gag": "plan_z"}},
	{"id": "G14", "en": "Yellow Barrel", "es": "Barril amarillo", "goal": "Launch the submarine.", "stat": "project:submarine", "need": 1,
		"reward": {"gag": "yellow_barrel"}},
	{"id": "G15", "en": "Hall of Shame", "es": "Salón de la vergüenza", "goal": "Build the Museum of Failure.", "stat": "project:museum", "need": 1,
		"reward": {"decor": "plaque_wall"}},
	{"id": "S11", "en": "Seeds of Doubt", "es": "Semillas de duda", "goal": "Make a seed plot.", "stat": "made:seed_plot", "need": 1,
		"reward": {"xp": {"foraging": 4}}},
	{"id": "E01", "en": "Raft #1", "es": "Balsa n.º 1", "goal": "Build a raft section.", "stat": "made:raft_section", "need": 1,
		"reward": {"gag": "raft_shark"}},
	{"id": "E02", "en": "Raft #2 (Improved)", "es": "Balsa n.º 2 (mejorada)", "goal": "Build a second raft section.", "stat": "made:raft_section", "need": 2,
		"reward": {"gag": "raft_wave"}},
	{"id": "E04", "en": "SOS in the Sand", "es": "SOS en la arena", "goal": "Make an SOS flag.", "stat": "made:sos_flag", "need": 1,
		"reward": {"gag": "sos_tide"}},
	{"id": "A06", "en": "Talent Show", "es": "Show de talentos", "goal": "Make a drum.", "stat": "made:drum", "need": 1,
		"reward": {"gag": "crab_audience"}},
	{"id": "W08", "en": "Star Gazer", "es": "Mirastrellas", "goal": "Stargaze on 3 nights.", "stat": "pastime:stargaze", "need": 3,
		"reward": {"xp": {"weather sense": 8}, "gag": "constellation_names"}},
	{"id": "W09", "en": "Sunrise Club", "es": "Club del amanecer", "goal": "Stretch at sunrise 3 times.", "stat": "pastime:yoga", "need": 3,
		"reward": {"decor": "sunrise_mat"}},
	{"id": "A01", "en": "Coconut Friend", "es": "Amigo coco", "goal": "Make a coconut friend.", "stat": "pastime:coconut_friend", "need": 1,
		"reward": {"gag": "coconut_friend"}},
	{"id": "A03", "en": "Sandcastle Mansion", "es": "Mansión de arena", "goal": "Build 3 sandcastles.", "stat": "pastime:sandcastle", "need": 3,
		"reward": {"decor": "sand_mansion"}},
	{"id": "A05", "en": "Philosopher", "es": "Filósofo", "goal": "Stare at the horizon.", "stat": "pastime:horizon", "need": 1,
		"reward": {"xp": {"weather sense": 3}}},
	{"id": "A07", "en": "Crab Wars", "es": "Guerra de cangrejos", "goal": "Win a crab race.", "stat": "crab_win", "need": 1,
		"reward": {"gag": "crab_wars"}},
	{"id": "A08", "en": "Self-Portrait", "es": "Autorretrato", "goal": "Draw in the sand.", "stat": "pastime:draw", "need": 1,
		"reward": {"decor": "sand_art"}},
	{"id": "A10", "en": "Yoga on the Beach", "es": "Yoga en la playa", "goal": "Stretch at sunrise.", "stat": "pastime:yoga", "need": 1,
		"reward": {"xp": {"fire": 2}}},
	{"id": "W01", "en": "Cloud Reader", "es": "Lector de nubes", "goal": "See 5 forecasts come true.", "stat": "forecast_ok", "need": 5,
		"reward": {"xp": {"weather sense": 10}}},
	{"id": "W02", "en": "The Big One", "es": "La grande", "goal": "Live through a tropical storm.", "stat": "tropical", "need": 1,
		"reward": {"items": [["old_coin", 1]], "gag": "tropical_storm"}},
	{"id": "W06", "en": "Moon Fishing", "es": "Pesca lunar", "goal": "Catch something shiny on a full moon night.", "stat": "moon_fish", "need": 1,
		"reward": {"items": [["amber", 1]]}},
	{"id": "W10", "en": "Eclipse Day", "es": "Día de eclipse", "goal": "Be on the island for an eclipse.", "stat": "eclipse", "need": 1,
		"reward": {"gag": "eclipse_day", "decor": "meteorite_dish"}},
	{"id": "B08", "en": "Message of the Day", "es": "Mensaje del día", "goal": "Find a recipe in a bottle.", "stat": "recipe_bottles", "need": 1,
		"reward": {"xp": {"tinkering": 5}}},
	{"id": "L07", "en": "Regular", "es": "Habitual", "goal": "Come back 7 days in a row.", "stat": "streak_best", "need": 7,
		"reward": {"items": [["sea_glass", 2]]}},
	{"id": "L28", "en": "Local", "es": "Local", "goal": "Come back 28 days in a row.", "stat": "streak_best", "need": 28,
		"reward": {"items": [["pearl", 1]], "decor": "welcome_mat"}},
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

## Daily quests (QUESTS.md D-series): three a day, picked by the island seed, counted from sunrise.
## Small rewards, never required. Counters live in engine.dstats (reset every day).
const DAILY := [
	{"id": "D01", "en": "Catch 3 fish today", "es": "Pescá 3 peces hoy", "stat": "ev:caught", "need": 3, "reward": [["bait", 2]]},
	{"id": "D02", "en": "Cook one meal", "es": "Cociná una comida", "stat": "made:cook_fish", "need": 1, "reward": [["salt", 1]]},
	{"id": "D03", "en": "Take 2 naps", "es": "Hacé 2 siestas", "stat": "ev:nap_taken", "need": 2, "reward": [["frond", 3]]},
	{"id": "D04", "en": "Read today's bottle", "es": "Leé la botella de hoy", "stat": "ev:bottle_opened", "need": 1, "reward": [["paper", 1]]},
	{"id": "D06", "en": "Collect 5 shells", "es": "Juntá 5 conchas", "stat": "shell", "need": 5, "reward": [["sea_glass", 1]]},
	{"id": "D07", "en": "Gather 6 sticks", "es": "Juntá 6 palitos", "stat": "stick", "need": 6, "reward": [["rope", 1]]},
	{"id": "D09", "en": "Drink 2 things", "es": "Tomá 2 bebidas", "stat": "ev:drank", "need": 2, "reward": [["coconut", 1]]},
	{"id": "D10", "en": "Craft something", "es": "Fabricá algo", "stat": "crafted_any", "need": 1, "reward": [["stick", 3]]},
]

static func daily(id: String) -> Dictionary:
	for q in DAILY:
		if q.id == id:
			return q
	return {}

static func daily_name(q: Dictionary) -> String:
	return str(q.get("es" if TranslationServer.get_locale().begins_with("es") else "en", q.id))
