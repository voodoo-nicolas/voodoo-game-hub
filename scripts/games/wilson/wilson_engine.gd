extends RefCounted

## Beached: the rules (no Nodes, headless-testable). Time is the real clock: everything is stored as
## absolute unix timestamps and `advance(to, online)` plays the island forward in steps, so a phone that
## was closed for two days is caught up exactly like one that stayed open (GDD §15: "store absolute end
## timestamps, never tick counters"). `online` = the app is open and showing the island; offline the
## chill rules apply (GDD §5: Food / Water / Energy never drop below 15, HP never drops).
##
## Actions: `enqueue(kind, target, extra)` adds to the queue (max 5). The head starts when Johnny is
## free (energy is paid then, the duration is fixed then: low energy x1.5, Rested /1.1) and finishes at
## its absolute end time. Sleep and naps are a state (`sleep`), not a queue item, once they start.
## Events for the screen (thought bubbles, sounds, quest pop-ups) collect in `events`; the game drains it.

const D = preload("res://scripts/games/wilson/wilson_data.gd")
const Astro = preload("res://scripts/games/wilson/wilson_sky.gd")
const Quests = preload("res://scripts/games/wilson/wilson_quests.gd")
const Projects = preload("res://scripts/games/wilson/wilson_projects.gd")
const Pastimes = preload("res://scripts/games/wilson/wilson_pastimes.gd")

const SAVE_VERSION := 1
const STEP := 600.0  # simulation step, seconds

var t := 0.0                 # unix seconds the island has reached
var tz := 0                  # local time offset, seconds (Time.get_time_zone_from_system().bias * 60)
var hemisphere := "south"
var cname := ""              # the castaway's name, typed by the player ("" = unnamed)
var look := "male1"          # the castaway's look (8 sheets, picked on a new island)
var start_day := 0           # local day index of Day 1
var bars := {"hp": 100.0, "food": 100.0, "water": 100.0, "energy": 100.0}
var mood := 60.0
var slots: Array = []        # [{id, n}], at most `slot_count`
var slot_count := 12
var ground := {}             # overflow when the bag is full: id -> n (pulled back in when room frees)
var structures := {}         # id -> {built: t, ...}; campfire: fuel_until
var debris := {}             # id -> true while it lies on the beach
var palms := {}              # id -> {coco: float, felled: t or 0}
var spots := {}              # id -> stock (float)
var queue: Array = []        # [{kind, target, extra, start, end, energy, consumed}]
var sleep := {}              # {kind: sleep|nap|collapse|faint, bed, start, until}
var naps := {"day": -1, "n": 0}
var buffs := {}              # name -> until (t): rested, sandy, nausea
var flags := {}
var quest := ""              # the active tutorial quest id ("" = all done)
var tut := -1                # guided opening (D.TUT index; -1 = off / finished). The game turns it on for a new island.
var quests_done: Array = []
var xp := {}
var gags: Array = []
var decor: Array = []
var unlocked: Array = []     # recipes unlocked by quest rewards
var discovered: Array = []   # tier 3-4 recipes found by combining (M3)
var fire_fails := 0
var catches := 0
var raw_eaten := 0
var streak := {"last": -1, "count": 0, "best": 0, "grace_week": -1}
var dstats := {}             # today's counters (daily quests)
var dq: Array = []           # today's three daily quest ids
var dq_done: Array = []
var projects := {}           # Grand Projects being built: id -> {start, done}
var pinned := ""             # wishlist: the pinned project id
var stats := {}              # counters the side quests watch (wilson_quests.gd)
var side_done: Array = []    # finished side quest ids
var _was_low := false
var tallies: Array = []      # local day indexes scratched on the stump
var weather := "clear"
var weather_auto := false    # true = the controller drives `weather` (the game sets it); the debug panel can force one
var wseed := 1               # weather + tide seed (per island)
var tide_off := 0.0          # minutes: tide phase offset (seeded)
var shore := {"last_day": 0, "pile": {}, "no_rare": 0, "no_mythic": 0, "bottles": 0}
var journal: Array = []      # [{t, text, args, away}]
var rng := RandomNumberGenerator.new()
var events: Array = []       # transient: [{type, ...}] for the screen
var _online := true
var _low := {}               # bar -> true while its low-bar line has been said

# ================================================================ setup

## A fresh island at time `now` (Day 1 = the local day of `now`).
func reset(now: float, tz_seconds: int = 0, hemi: String = "south", seed_value: int = 0, look_id: String = "male1") -> void:
	t = now
	look = look_id
	cname = ""
	tz = tz_seconds
	hemisphere = hemi
	start_day = day_index(now)
	bars = {"hp": 100.0, "food": 80.0, "water": 70.0, "energy": D.START_ENERGY}
	mood = 55.0
	slots = []
	slot_count = int(D.balance().get("inventory", {}).get("start_slots", 12))
	ground = {}
	structures = {}
	debris = {}
	for id in D.DEBRIS:
		debris[id] = true
	palms = {}
	for id in D.PALMS:
		palms[id] = {"coco": float(D.PALM_COCONUTS), "felled": 0.0}
	spots = {}
	for id in D.SPOTS:
		spots[id] = float(D.SPOTS[id].max)
	queue = []
	sleep = {}
	naps = {"day": -1, "n": 0}
	buffs = {}
	flags = {}
	quest = "T01"
	tut = -1
	quests_done = []
	xp = {}
	gags = []
	decor = []
	unlocked = []
	discovered = []
	fire_fails = 0
	catches = 0
	raw_eaten = 0
	tallies = []
	stats = {}
	side_done = []
	projects = {}
	pinned = ""
	dstats = {}
	dq = []
	dq_done = []
	streak = {"last": -1, "count": 0, "best": 0, "grace_week": -1}
	_was_low = false
	weather = "clear"
	weather_auto = false
	wseed = (seed_value if seed_value != 0 else int(now)) & 0x7fffffff
	tide_off = float(wseed % int(D.TIDE_MIN))
	shore = {"last_day": start_day, "pile": {}, "no_rare": 0, "no_mythic": 0, "bottles": 0}
	journal = []
	events = []
	_low = {}
	rng.seed = seed_value if seed_value != 0 else int(now) ^ 0x5eed
	log_entry("Day 1. Washed up on a rock with palm trees. Wreckage everywhere. Great.")

# ================================================================ time helpers

func local_t(at: float = -1.0) -> float:
	return (t if at < 0.0 else at) + tz

func day_index(at: float = -1.0) -> int:
	return int(floor(local_t(at) / 86400.0))

func hour(at: float = -1.0) -> float:
	return fposmod(local_t(at), 86400.0) / 3600.0

func day_number() -> int:
	return day_index() - start_day + 1

func doy(at: float = -1.0) -> int:
	var d := Time.get_datetime_dict_from_unix_time(int(local_t(at)))
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	return int(floor((local_t(at) - jan1) / 86400.0)) + 1

func sunrise_h(at: float = -1.0) -> float:
	return Astro.sunrise(doy(at), hemisphere)

func sunset_h(at: float = -1.0) -> float:
	return Astro.sunset(doy(at), hemisphere)

func is_day(at: float = -1.0) -> bool:
	var h := hour(at)
	return h >= sunrise_h(at) and h < sunset_h(at)

## Unix time of the next local `h` o'clock after `at`.
func next_hour(h: float, at: float = -1.0) -> float:
	var base := t if at < 0.0 else at
	var now_h := hour(base)
	var dh := fposmod(h - now_h, 24.0)
	if dh < 0.0001:
		dh = 24.0
	return base + dh * 3600.0

# ================================================================ sky events, forecast checks (M4 follow-up)

func is_full_moon(at: float = -1.0) -> bool:
	return absf(Astro.moon_phase(t if at < 0.0 else at) - 0.5) < D.FULL_MOON_WIDTH

## A rare, bigger storm: a storm spell that the island's seed marks as tropical.
func is_tropical(at: float = -1.0) -> bool:
	var x := t if at < 0.0 else at
	if weather_at(x) != "storm" and weather != "storm":
		return false
	return _hf(wseed, int(floor(x / D.WEATHER_BLOCK_S)) + 777) < D.TROPICAL_CHANCE

## A new-moon day the seed makes an eclipse day (the sky dims around noon).
func is_eclipse_day(day: int = -999999) -> bool:
	var d := day_index() if day == -999999 else day
	var ph := Astro.moon_phase(float(d) * 86400.0 + 43200.0 - tz)
	if ph > 0.03 and ph < 0.97:
		return false
	return _hf(wseed, d * 13 + 5) < D.ECLIPSE_CHANCE

## 0..0.7: how much the sun is covered right now (a smooth dip 11:30-13:30 on an eclipse day).
func eclipse_amount() -> float:
	if not is_eclipse_day():
		return 0.0
	var h := hour()
	return 0.7 * clampf(1.0 - absf(h - 12.5) / 1.0, 0.0, 1.0)

# ================================================================ login streak (GDD section 12)

func _week_of(day: int) -> int:
	return int(floor(float(day) / 7.0))

## Called when the player opens the island (not by offline catch-up). Counts a day, forgives one
## missed day a week (the "grace tide"), pays the calendar day's reward. Returns the day count.
func checkin() -> int:
	var today := day_index()
	var last := int(streak.last)
	if last == today:
		return int(streak.count)
	var gap := today - last
	var graced := false
	if last < 0:
		streak.count = 1
	elif gap == 1:
		streak.count = int(streak.count) + 1
	elif gap == 2 and int(streak.grace_week) != _week_of(today):
		streak.count = int(streak.count) + 1
		streak.grace_week = _week_of(today)
		graced = true
	else:
		streak.count = 1
	streak.last = today
	streak.best = maxi(int(streak.best), int(streak.count))
	stats["streak_best"] = int(streak.best)
	var day_n := (int(streak.count) - 1) % int(D.balance().get("login", {}).get("streak_days", 30)) + 1
	give_list(D.STREAK_REWARDS.get(day_n, [["stick", 2]]))
	var bonus := day_n in D.STREAK_BONUS_DAYS
	if bonus:
		shore["bonus_rolls"] = int(shore.get("bonus_rolls", 0)) + 1
	if graced:
		log_entry("The grace tide: one missed day does not break the streak.")
	log_entry("Streak day %d. The island noticed you came back.", [int(streak.count)])
	_check_side()
	events.append({"type": "streak", "count": int(streak.count), "day": day_n, "bonus": bonus, "graced": graced})
	return int(streak.count)

# ================================================================ pastimes

## "" when the pastime can start now, else why not.
func pastime_block(id: String, self_q = null) -> String:
	var p := Pastimes.get_pastime(id)
	if p.is_empty():
		return "No such pastime."
	for q in queue:
		if q.kind == "pastime" and q.target == id and not is_same(q, self_q):
			return "Already queued."
	var h := hour()
	var need := str(p.get("needs", ""))
	if need != "" and count(need) <= 0:
		return "Needs a %s." % D.item_name(need)
	if p.has("needs_any"):
		var any := false
		for sid in p.needs_any:
			if structures.has(sid):
				any = true
		if not any:
			return "Nothing to tidy yet."
	match id:
		"fan_fire":
			if not fire_lit():
				return "The fire is not lit."
		"stargaze":
			if is_day():
				return "Only after dark."
			if weather in ["rain", "drizzle", "storm", "fog", "overcast"]:
				return "Too cloudy to see the stars."
		"yoga":
			var rise := sunrise_h()
			if h < rise - 0.5 or h > rise + 1.5:
				return "Only around sunrise."
		"crab_race":
			if not is_day():
				return "The crabs sleep at night."
			if weather == "storm":
				return "No racing in a storm."
		"sandcastle":
			if weather in D.RAINY:
				return "Rain ruins sandcastles."
		"coconut_friend":
			if flags.get("coco", false):
				return "Coco is already your friend."
			if count("coconut") <= 0:
				return "Needs a %s." % D.item_name("coconut")
			if count("charcoal") <= 0 and count("stick") <= 0:
				return "Needs charcoal or a stick to draw with."
		"chat":
			if not flags.get("coco", false):
				return "You have no coconut friend yet."
		"swim":
			if weather == "storm":
				return "Not in a storm. I like breathing."
			if weather == "cold_snap":
				return "Too cold for a swim."
		"sunset":
			var sset := sunset_h()
			if h < sset - 1.0 or h > sset + 0.5:
				return "Only around sunset."
			if weather in ["rain", "storm", "fog", "overcast"]:
				return "Too cloudy to see the sunset."
	return ""

func _finish_pastime(id: String) -> void:
	var p := Pastimes.get_pastime(id)
	if p.is_empty():
		return
	var lines: Array = p.lines
	var line: String = lines[(int(stats.get("pastime:" + id, 0)) + day_index()) % lines.size()]
	if p.has("loot"):
		var table: Array = p.loot.duplicate()
		if id == "comb" and is_low_tide():
			table.append(["pearl", 2])
			table.append(["sea_glass", 8])
		var got := _roll(table)
		if got != "":
			add(got, 1)
			_got(got, 1)
			_xp("foraging", 1)
			log_entry("%s Found: %s.", ["#" + line, "@" + got])
			line = ""
		else:
			log_entry("%s Nothing found.", ["#" + line])
			line = ""
	if p.has("give"):
		give_list(p.give)
		for pair in p.give:
			_got(str(pair[0]), int(pair[1]))
		_xp("foraging", 1)
	if str(p.get("wear", "")) != "":
		_wear(str(p.wear))
	match id:
		"swim":
			buffs.erase("sandy")
		"coconut_friend":
			remove("coconut", 1)
			if count("charcoal") > 0:
				remove("charcoal", 1)
			flags["coco"] = true
		"fan_fire":
			structures.campfire.fuel_until = maxf(float(structures.campfire.get("fuel_until", 0.0)), t) + 1200.0
		"skip_stone":
			var skips := 1 + rng.randi() % 9
			stats["skip_best"] = maxi(int(stats.get("skip_best", 0)), skips)
			log_entry("Skipped a stone: %d bounces. A personal best." if skips >= 7 else "Skipped a stone: %d bounces.", [skips])
			line = ""
		"crab_race":
			if rng.randf() < 0.5:
				bump("crab_win")
				line = "Won the crab race. My crab was the one that did not run away. That counts."
				if not "crab_champ" in gags:
					gags.append("crab_champ")
		"sandcastle":
			if not "sandcastle" in decor:
				decor.append("sandcastle")
		"draw":
			if not "sand_portrait" in decor:
				decor.append("sand_portrait")
	mood = clampf(mood + float(p.mood), 0.0, 100.0)
	if line != "":
		log_entry("%s", ["#" + line])
	events.append({"type": "pastime", "id": id})
	if str(p.get("group", "")) == "quick":
		bump("odd_jobs")
	bump("pastime:" + id)
	if id == "stargaze" or id == "yoga":
		_xp("weather sense", 1)

# ================================================================ Grand Projects

func powered() -> bool:
	return structures.has("windmill")

## A Grand Project shows on the craft screen once you hold every one of its materials (or it is pinned,
## being built, or built).
func project_visible(p: Dictionary) -> bool:
	if structures.has(str(p.key)) or projects.has(str(p.id)) or pinned == str(p.id):
		return true
	# owner, 2026-11-10: no previews of the grand designs. Shown only once every material has been held at
	# least once (the amount may still be short), never during the opening, like the recipes.
	if tut >= 0:
		return false
	for m in p.mats:
		if count(str(m[0])) <= 0:
			return false
	return true

## [[id, have, need]] for every material still short.
func project_missing(id: String) -> Array:
	var out: Array = []
	for m in Projects.get_project(id).get("mats", []):
		var have := count(str(m[0]))
		if have < int(m[1]):
			out.append([str(m[0]), have, int(m[1])])
	return out

## "" when the build can start now, else why not.
func project_block(id: String) -> String:
	var p := Projects.get_project(id)
	if p.is_empty():
		return "No such project."
	if structures.has(p.key):
		return "Already built."
	if projects.has(id):
		return "Already under construction."
	if not projects.is_empty():
		return "Only one build at a time. Two hands."
	var need: String = str(p.get("needs", ""))
	if need != "" and not structures.has(str(Projects.get_project(need).key)):
		return "Needs the %s first." % Projects.get_project(need).en
	if int(p.get("plaques", 0)) > int(stats.get("escape_fails", 0)):
		return "Needs more failed escapes."
	if not project_missing(id).is_empty():
		return "Missing materials."
	return ""

func start_project(id: String) -> String:
	var why := project_block(id)
	if why != "":
		return why
	var p := Projects.get_project(id)
	for m in p.mats:
		remove(str(m[0]), int(m[1]))
	projects[id] = {"start": t, "done": t + float(p.days) * 86400.0}
	log_entry("Started building: %s.", ["~" + str(p.en)])
	events.append({"type": "project", "id": id})
	return ""

func project_progress(id: String) -> float:
	if not projects.has(id):
		return 1.0 if structures.has(str(Projects.get_project(id).get("key", ""))) else 0.0
	var pr: Dictionary = projects[id]
	return clampf((t - float(pr.start)) / maxf(1.0, float(pr.done) - float(pr.start)), 0.0, 1.0)

func _projects_tick() -> void:
	if projects.is_empty():
		return
	for id in projects.keys():
		if t >= float(projects[id].done) - 0.001:
			projects.erase(id)
			_project_done(Projects.get_project(id))

func _project_done(p: Dictionary) -> void:
	structures[p.key] = {"built": t}
	if not p.key in decor:
		decor.append(p.key)
	log_entry("Finished building: %s.", ["~" + str(p.en)])
	events.append({"type": "project_done", "id": p.id})
	bump("project:" + str(p.key))
	if p.key == "glider":
		bump("escape_fails")
		if not "glider_fail" in gags:
			gags.append("glider_fail")
		log_entry("Launched the glider. It flew for four seconds. The sea was very close and very wet.")
	elif p.key == "submarine":
		bump("escape_fails")
		if not "submarine_fail" in gags:
			gags.append("submarine_fail")
		log_entry("Launched the submarine. It sank, as designed by no one. I came back up. The barrel did not.")
	elif p.key == "shrine":
		log_entry("The shrine hums. The shore feels a little friendlier.")

## Once each morning: the radio, a ship in the spyglass, the lighthouse's bad luck.
func _project_daily(today: int) -> void:
	var n := today - start_day
	if is_eclipse_day(today):
		bump("eclipse")
		shore.pile["meteorite_shard"] = int(shore.pile.get("meteorite_shard", 0)) + 1
		log_entry("An eclipse today. At noon the sky went dark and something shiny fell on the beach.")
		if not "eclipse_day" in gags:
			gags.append("eclipse_day")
	if is_full_moon():
		mood = clampf(mood + 6.0, 0.0, 100.0)
		log_entry("Full moon tonight. Everything looks silver. Even the debris.")
	if structures.has("coconut_radio") and powered():
		log_entry("%s", ["#" + Projects.BROADCASTS[n % Projects.BROADCASTS.size()]])
	if structures.has("spyglass_tower"):
		log_entry("%s", ["#" + Projects.SHIPS[n % Projects.SHIPS.size()]])
	if structures.has("lighthouse") and n % 3 == 0:
		log_entry("%s", ["#" + Projects.LIGHTHOUSE_FAILS[(n / 3) % Projects.LIGHTHOUSE_FAILS.size()]])
		if not "beacon_fail" in gags:
			gags.append("beacon_fail")

# ================================================================ what the player can read off

## The clock, the tide and the moon exist from the start but nobody tells him (owner, 2026-11-09): the
## hour needs a sundial (or the Shellphone), the tide a tide chart (quest W07) or the Shellphone.
func knows_time() -> bool:
	return structures.has("sundial") or structures.has("shellphone")

func knows_tide() -> bool:
	return "tide_chart" in decor or structures.has("shellphone")

# ================================================================ weather + tides (M4)

## Deterministic 0..1 hash of two ints (no server; same on every device).
static func _hf(a: int, b: int) -> float:
	var x := ((a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995) & 0xffffffff
	x = ((x ^ (x >> 15)) * 0x2c1b3c6d) & 0xffffffff
	x = ((x ^ (x >> 12)) * 0x297a2d39) & 0xffffffff
	x = x ^ (x >> 15)
	return float(x & 0xffffff) / 16777216.0

## "summer" / "autumn" / "winter" / "spring" for the player's hemisphere (real calendar).
func season(at: float = -1.0) -> String:
	var m: int = Time.get_datetime_dict_from_unix_time(int(local_t(at))).month
	var north := ["winter", "winter", "spring", "spring", "spring", "summer", "summer", "summer", "autumn", "autumn", "autumn", "winter"]
	var s: String = north[m - 1]
	if hemisphere == "south":
		s = {"winter": "summer", "summer": "winter", "spring": "autumn", "autumn": "spring"}[s]
	return s

## The weather at time `at`: seeded by (island seed, 3 h block); half the time a block repeats its
## even neighbour, so spells last 3-6 h.
func weather_at(at: float) -> String:
	var block := int(floor(at / D.WEATHER_BLOCK_S))
	var b := block
	if _hf(wseed, block * 2 + 1) < 0.5:
		b = block - (block & 1)
	var table: Dictionary = D.WEATHER_WEIGHTS[season(float(b) * D.WEATHER_BLOCK_S)]
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := _hf(wseed, b * 2) * total
	for k in table:
		r -= float(table[k])
		if r < 0.0:
			return str(k)
	return "clear"

func _weather_tick() -> void:
	if forecast_hours() > 0:
		flags["fc_cover"] = t + float(forecast_hours()) * 3600.0
	var low := is_low_tide()
	if low and not _was_low:
		bump("low_tides")
	_was_low = low
	if not weather_auto:
		return
	var w := weather_at(t)
	if w == weather:
		return
	weather = w
	if float(flags.get("fc_cover", 0.0)) >= t:
		bump("forecast_ok")   # the barometer / tower saw this coming
	bump("wx:" + w)
	if w == "storm" and is_tropical():
		bump("tropical")
		log_entry("A tropical storm. The island is a lot smaller than I thought, and so am I.")
	var kinds := 0
	for k in ["rain", "wind", "fog"]:
		if int(stats.get("wx:" + k, 0)) > 0:
			kinds += 1
	stats["wx_kinds"] = kinds
	_check_side()
	if w == "storm":
		log_entry("A storm is rolling in. The palms hold on tight.")
	elif w == "fog":
		log_entry("Fog. The horizon has been cancelled.")
	elif w == "heatwave":
		log_entry("Heatwave. Even the sand is sweating.")

## 0 = lowest, 1 = highest. A full cycle is 12 h 25 min.
func tide_level(at: float = -1.0) -> float:
	var m := (t if at < 0.0 else at) / 60.0 + tide_off
	return 0.5 + 0.5 * cos(TAU * m / D.TIDE_MIN)

func is_low_tide(at: float = -1.0) -> bool:
	return tide_level(at) < D.LOW_TIDE

## Unix time the next low tide starts (steps of 5 min, within 13 h).
func next_low_tide(at: float = -1.0) -> float:
	var base := t if at < 0.0 else at
	for i in range(1, 13 * 12):
		var x := base + i * 300.0
		if is_low_tide(x) and not is_low_tide(x - 300.0):
			return x
	return base

## Hours the barometer can see ahead (0 = no barometer in the bag).
func forecast_hours() -> int:
	var base := D.FORECAST_BASE_H if count("barometer") > 0 else 0
	if structures.has("spyglass_tower"):
		base += D.TOWER_FORECAST_H
	if base <= 0:
		return 0
	return base + D.FORECAST_PER_LEVEL_H * skill_level("weather sense")

## [{t, weather}]: every change of weather inside the forecast window.
func forecast() -> Array:
	var out: Array = []
	var hrs := forecast_hours()
	var last := weather
	var x := t
	while x <= t + hrs * 3600.0:
		var w := weather_at(x)
		if w != last:
			out.append({"t": x, "weather": w})
			last = w
		x += 900.0
	return out

# ================================================================ the clock

## Plays the island forward to `to`. online = the app is open on the island.
func advance(to: float, online: bool = true) -> void:
	_online = online
	var guard := 0
	while t < to - 0.001 and guard < 200000:
		guard += 1
		_start_next()
		var nb := minf(to, t + STEP)
		var act := active()
		if not act.is_empty() and float(act.end) < nb:
			nb = maxf(float(act.end), t)
		if not sleep.is_empty() and float(sleep.until) < nb:
			nb = maxf(float(sleep.until), t)
		_integrate(nb - t)
		t = nb
		_weather_tick()
		_projects_tick()
		act = active()
		if not act.is_empty() and t >= float(act.end) - 0.001:
			queue.pop_front()
			_finish(act)
		if not sleep.is_empty():
			if t >= float(sleep.until) - 0.001:
				wake()
			elif sleep.kind == "collapse" and bars.energy >= D.COLLAPSE_WAKE_ENERGY:
				wake()
		_daily()
		if online:
			_check_collapse()
	_start_next()
	_online = true

func _integrate(dt: float) -> void:
	if dt <= 0.0:
		return
	var h := dt / 3600.0
	var b: Dictionary = D.balance().get("bars", {})
	var prev := bars.duplicate()
	var asleep := not sleep.is_empty()
	var mult := D.SLEEP_DRAIN_MULT if asleep else 1.0
	var thirst := 1.0
	if weather == "heatwave":
		thirst = D.HAT_HEAT_THIRST if count("frond_hat") > 0 else 2.0   # a hat keeps the worst of the sun off
	if structures.has("desalinator"):
		thirst *= D.DESALINATOR_THIRST  # GDD §8: heatwave doubles thirst
	bars.food -= float(b.get("food", {}).get("drain_per_h", 4)) * h * mult
	bars.water -= float(b.get("water", {}).get("drain_per_h", 5)) * h * mult * thirst
	if asleep:
		if sleep.kind != "nap":
			bars.energy += sleep_rate(str(sleep.bed)) * h
	else:
		bars.energy -= float(b.get("energy", {}).get("drain_per_h", 3)) * h
	for k in ["food", "water", "energy"]:
		bars[k] = clampf(bars[k], 0.0, 100.0)
		if not _online:
			var floor_v := float(D.balance().get("offline_floor", 15))
			bars[k] = maxf(bars[k], minf(prev[k], floor_v))
	var hp: Dictionary = b.get("hp", {})
	var req: Dictionary = hp.get("regen_requires", {})
	if prev.food > float(req.get("food_gt", 50)) and prev.water > float(req.get("water_gt", 50)) \
			and prev.energy > float(req.get("energy_gt", 30)):
		bars.hp += float(hp.get("regen_per_h", 2)) * h
	if _online:
		var empty := 0
		for k in ["food", "water", "energy"]:
			if prev[k] <= 0.0:
				empty += 1
		bars.hp -= float(hp.get("empty_bar_loss_per_h", 3)) * h * empty
	bars.hp = clampf(bars.hp, 0.0, 100.0)
	_world_tick(h)
	_mood_tick(h)
	if _online:
		_low_bar_lines()
		if bars.hp <= 0.0 and (sleep.is_empty() or sleep.kind != "faint"):
			_faint()

## Coconuts and spots grow back, felled palms regrow, the fire burns.
func _world_tick(h: float) -> void:
	for id in palms:
		var p: Dictionary = palms[id]
		if float(p.felled) > 0.0:
			if t - float(p.felled) >= D.PALM_REGROW_DAYS * 86400.0:
				p.felled = 0.0
				p.coco = 0.0
		else:
			p.coco = minf(float(D.PALM_COCONUTS), float(p.coco) + h / D.COCONUT_REGROW_H * (D.WIND_REGROW_MULT if weather in ["wind", "storm"] else 1.0))
	for id in spots:
		var s: Dictionary = D.SPOTS[id]
		spots[id] = minf(float(s.max), float(spots[id]) + float(s.per_h) * h)
	if structures.has("campfire") and weather == "storm":
		structures.campfire.fuel_until = minf(float(structures.campfire.get("fuel_until", 0.0)), t)
	for s in slots:
		var sp := float(s.get("spoil", 0.0))
		if sp > 0.0 and sp <= t:
			log_entry("The %s went bad. Fish guts now.", ["@" + str(s.id)])
			s.id = "fish_guts"
			s.erase("spoil")
			say("spoiled")
	if structures.has("rain_catcher"):
		var rc: Dictionary = structures.rain_catcher
		rc["water"] = minf(float(D.WATER_MAX), float(rc.get("water", 0.0)) + float(D.RAIN_FILL_PER_H.get(weather, 0.0)) * h)
	if structures.has("water_still") and is_day():
		var ws: Dictionary = structures.water_still
		ws["water"] = minf(float(D.WATER_MAX), float(ws.get("water", 0.0)) + h / D.STILL_H)
	if structures.has("fish_trap"):
		var ft: Dictionary = structures.fish_trap
		var prog := float(ft.get("prog", 0.0)) + h / D.TRAP_H
		var caught: Array = ft.get("catch", [])
		while prog >= 1.0:
			prog -= 1.0
			if caught.size() < D.TRAP_MAX:
				caught.append(_roll(D.TRAP_TABLE))
		ft["prog"] = prog
		ft["catch"] = caught

func _mood_tick(h: float) -> void:
	var target := 60.0
	if has_buff("rested"):
		target += 15.0
	if has_buff("sandy"):
		target -= 15.0
	if has_buff("nausea"):
		target -= 15.0
	if fire_lit() and not is_day():
		target += 10.0
	if structures.has("canopy") and is_day():
		target += 5.0
	if structures.has("sundial"):
		target += 3.0
	if powered() and structures.has("coconut_radio"):
		target += 4.0
	if structures.has("museum"):
		target += 4.0
	if not is_day() and not fire_lit() and (count("fish_oil_lamp") > 0 or count("torch") > 0):
		target += D.NIGHT_LIGHT_MOOD      # a light of his own when the fire is out
	if count("wind_chime") > 0:
		target += D.CHIME_MOOD * (2.0 if weather in ["wind", "storm"] else 1.0)
	for k in ["food", "water", "energy", "hp"]:
		if bars[k] < D.LOW_BAR:
			target -= 10.0
	mood = move_toward(mood, clampf(target, 0.0, 100.0), 10.0 * h)

func _low_bar_lines() -> void:
	for k in ["food", "water", "energy", "hp"]:
		if bars[k] < D.LOW_BAR and not _low.get(k, false):
			_low[k] = true
			say(k)
			events.append({"type": "low", "bar": k})
		elif bars[k] > D.LOW_BAR + 10.0:
			_low[k] = false

func _check_collapse() -> void:
	if sleep.is_empty() and bars.energy <= 0.0:
		_cancel_active(false)
		sleep = {"kind": "collapse", "bed": "sand", "start": t, "until": t + 12.0 * 3600.0}
		say("collapse")
		log_entry("Collapsed face-first into the sand. Energy: zero.")
		events.append({"type": "sleep"})

## HP 0 (only with the app open): faints, wakes next morning, loses the queue (GDD §5, no permadeath).
func _faint() -> void:
	_cancel_active(false)
	queue.clear()
	sleep = {"kind": "faint", "bed": "sand", "start": t, "until": next_hour(sunrise_h() + 0.5)}
	say("faint")
	log_entry("Fainted. Woke up later with sand in my ears and no memory of the plan.")
	events.append({"type": "sleep"})

# ================================================================ daily: shore delivery

func _daily() -> void:
	var today := day_index()
	if today != int(flags.get("dq_day", -1)):
		flags["dq_day"] = today
		_roll_dailies(today)
		stats["days"] = maxi(int(stats.get("days", 0)), day_number())
		_check_side()
	if today > int(flags.get("gp_day", -1)) and hour() >= sunrise_h():
		flags["gp_day"] = today
		_project_daily(today)
	if today > int(flags.get("wsense_day", -1)) and count("barometer") > 0:
		flags["wsense_day"] = today
		_xp("weather sense", 3)
	if today > int(shore.last_day) and hour() >= sunrise_h():
		shore.last_day = today
		_shore_delivery()

func _shore_delivery() -> void:
	var drops: Dictionary = D.balance().get("shore_drops", {})
	var table: Dictionary = drops.get("storm" if weather == "storm" else "normal", {})
	var rolls := int(table.get("rolls", 3)) + int(shore.get("bonus_rolls", 0)) + (3 if is_tropical() else 0)
	shore["bonus_rolls"] = 0
	var weights: Dictionary = table.get("weights", {}).duplicate()
	if structures.has("shrine"):
		for r in ["uncommon", "rare", "mythic"]:
			weights[r] = float(weights.get(r, 0)) * D.SHRINE_LUCK
	var pity: Dictionary = drops.get("pity", {})
	var got_rare := false
	var got_mythic := false
	for i in rolls:
		var rarity := roll_rarity(weights)
		if int(shore.no_mythic) + 1 >= int(pity.get("mythic_after_days", 60)) and not got_mythic:
			rarity = "mythic"
		elif int(shore.no_rare) + 1 >= int(pity.get("rare_after_days", 14)) and not got_rare and not got_mythic:
			rarity = "rare"
		if rarity == "rare":
			got_rare = true
		if rarity == "mythic":
			got_mythic = true
		var id := _shore_item(rarity)
		if id != "":
			shore.pile[id] = int(shore.pile.get(id, 0)) + 1
	shore.no_rare = 0 if (got_rare or got_mythic) else int(shore.no_rare) + 1
	shore.no_mythic = 0 if got_mythic else int(shore.no_mythic) + 1
	shore.pile["bottle_note"] = int(shore.pile.get("bottle_note", 0)) + 1 + int(shore.get("replies", 0))
	shore["replies"] = 0
	if weather == "fog":
		shore.pile["bottle"] = int(shore.pile.get("bottle", 0)) + D.FOG_EXTRA_BOTTLE
	log_entry("Something washed ashore.")
	events.append({"type": "shore"})

## Weighted pick from {"common": 70, ...}.
func roll_rarity(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in ["common", "uncommon", "rare", "mythic"]:
		r -= float(weights.get(k, 0))
		if r < 0.0:
			return k
	return "common"

func _shore_item(rarity: String) -> String:
	var letter: String = D.RARITY_LETTER.get(rarity, "C")
	var pool := []
	for id in D.items():
		if D.items()[id].r == letter and not id in D.NOT_ASHORE:
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]

# ================================================================ inventory

## Bag slots: 12 to start, +20 while a barrel is in the bag (balance.json inventory.barrel_bonus;
## CRAFTING.md §5 "barrel +20"). Turning the barrel into a rain catcher gives that room up.
func capacity() -> int:
	var inv: Dictionary = D.balance().get("inventory", {})
	return slot_count + (int(inv.get("barrel_bonus", 20)) if count("barrel") > 0 else 0) \
		+ int(inv.get("jar_bonus", 10)) * count("clay_jar") \
		+ (D.CELLAR_SLOTS if structures.has("cellar") else 0)

func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s.id == id:
			n += int(s.n)
	return n

func stack_of(id: String) -> int:
	return int(D.item(id).get("stack", 10))

## Adds to the bag; what does not fit goes on the sand (`ground`). Returns how many went on the sand.
func add(id: String, n: int) -> int:
	var left := n
	var cap := stack_of(id)
	for s in slots:
		if left <= 0:
			break
		if s.id == id and int(s.n) < cap:
			var put := mini(left, cap - int(s.n))
			s.n = int(s.n) + put
			left -= put
	var spoil := _spoil_at(id)
	if spoil > 0.0:
		for s in slots:
			if s.id == id and float(s.get("spoil", 0.0)) > 0.0:
				s.spoil = minf(float(s.spoil), spoil)
	while left > 0 and slots.size() < capacity():
		var put := mini(left, cap)
		var slot := {"id": id, "n": put}
		if spoil > 0.0:
			slot["spoil"] = spoil
		slots.append(slot)
		left -= put
	if left > 0:
		ground[id] = int(ground.get(id, 0)) + left
		say("full")
	return left

## When fresh food added now goes bad (0 = never).
func _spoil_at(id: String) -> float:
	if not D.SPOIL_H.has(id) or structures.has("cellar"):
		return 0.0
	var h: float = D.SPOIL_H[id]
	if structures.has("smokehouse"):
		h *= D.SMOKEHOUSE_SPOIL_MULT
	return t + h * 3600.0

## Uses left on the first `id` tool in the bag (-1: not a tool / none).
func tool_uses(id: String) -> int:
	if not D.TOOL_USES.has(id):
		return -1
	for s in slots:
		if s.id == id:
			return int(s.get("dur", D.TOOL_USES[id]))
	return -1

## One use of tool `id`; it breaks at 0.
func _wear(id: String) -> void:
	if not D.TOOL_USES.has(id):
		return
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.id != id:
			continue
		var left := int(s.get("dur", D.TOOL_USES[id])) - 1
		if left <= 0 and D.BLUNT.has(id):
			# a blade does not vanish: it goes blunt, and a stone puts the edge back (recipe sharpen_knife)
			slots[i] = {"id": str(D.BLUNT[id]), "n": 1}
			say("blunt")
			log_entry("The %s went blunt. A stone will put the edge back.", ["@" + id])
			events.append({"type": "broke", "id": id})
		elif left <= 0:
			slots.remove_at(i)
			_settle_ground()
			say("broke")
			log_entry("The %s broke. Of course it did.", ["@" + id])
			events.append({"type": "broke", "id": id})
		else:
			s["dur"] = left
		return

func remove(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if s.id != id:
			continue
		var take := mini(left, int(s.n))
		s.n = int(s.n) - take
		left -= take
		if int(s.n) <= 0:
			slots.remove_at(i)
	_settle_ground()
	return true

## Pulls what lies on the sand back into freed bag space.
func _settle_ground() -> void:
	for id in ground.keys():
		var n := int(ground[id])
		ground.erase(id)
		var left := 0
		var cap := stack_of(id)
		var rest := n
		for s in slots:
			if s.id == id and int(s.n) < cap and rest > 0:
				var put := mini(rest, cap - int(s.n))
				s.n = int(s.n) + put
				rest -= put
		while rest > 0 and slots.size() < capacity():
			var put := mini(rest, cap)
			var slot := {"id": id, "n": put}
			var spoil := _spoil_at(id)      # food picked back up off the sand still goes bad
			if spoil > 0.0:
				slot["spoil"] = spoil
			slots.append(slot)
			rest -= put
		left = rest
		if left > 0:
			ground[id] = left

func give_list(list: Array) -> void:
	for pair in list:
		add(str(pair[0]), int(pair[1]))

# ================================================================ eating and drinking (instant)

func can_consume(id: String) -> bool:
	return D.FOOD.has(id) and count(id) > 0

func consume(id: String) -> String:
	if id == "seawater":
		say("seawater")
		return "Salt water makes you thirstier."
	if id == "bottle_note":
		return open_bottle()
	if not can_consume(id):
		return "Can't eat that."
	var f: Dictionary = D.FOOD[id]
	if f.verb == "heal" and bars.hp >= 99.5:
		return "Nothing to patch up."
	remove(id, 1)
	bars.food = clampf(bars.food + float(f.food), 0.0, 100.0)
	bars.water = clampf(bars.water + float(f.water), 0.0, 100.0)
	if f.verb == "heal":
		bars.hp = clampf(bars.hp + float(f.get("hp", 0)), 0.0, 100.0)
		say("heal")
		events.append({"type": "heal"})
		log_entry("Patched myself up with a %s.", ["@" + id])
		_emit("healed", {"id": id})
		return ""
	if f.get("cooked", false):
		bump("cooked_eaten")
	if f.has("gives"):
		give_list(f.gives)
	var sick := false
	if f.has("nausea"):
		raw_eaten += 1
		sick = raw_eaten == 1 or rng.randf() < float(f.nausea)
	if sick:
		buffs["nausea"] = t + D.NAUSEA_H * 3600.0
		bars.water = clampf(bars.water + D.NAUSEA_WATER, 0.0, 100.0)
		say("nausea")
		if not "raw_fish_nausea" in gags:
			gags.append("raw_fish_nausea")
	var verb: String = f.verb
	events.append({"type": verb})
	log_entry("Drank a %s." if verb == "drink" else "Ate a %s.", ["@" + id])
	_emit("drank" if verb == "drink" else "ate", {"id": id})
	return ""

## The next tier 3-4 recipe the player has not found yet ("" = all found), cheapest tier first.
func _recipe_for_bottle(n: int) -> String:
	var pool: Array = []
	for r in D.recipes().values():
		if int(r.get("tier", 1)) > D.KNOWN_TIERS and not str(r.id) in discovered and not recipe_known(r):
			pool.append(r)
	if pool.is_empty():
		return ""
	pool.sort_custom(func(a, b): return [int(a.tier), str(a.id)] < [int(b.tier), str(b.id)])
	return str(pool[0].id)

func open_bottle() -> String:
	if count("bottle_note") <= 0:
		return "No bottle."
	remove("bottle_note", 1)
	add("bottle", 1)
	add("paper", 1)
	var n := int(shore.bottles)
	shore.bottles = n + 1
	say("bottle")
	var pal: String = D.BOTTLE_PEN_PALS[n % D.BOTTLE_PEN_PALS.size()]
	var found := _recipe_for_bottle(n)
	if n % 3 == 2 and found != "":
		discovered.append(found)
		var out := str(D.recipe(found).get("out", found))
		log_entry("A recipe was written on the back of the note: %s.", ["@" + out])
		events.append({"type": "note", "text": "A recipe was written on the back of the note: %s.", "args": ["@" + out]})
		bump("recipe_bottles")
	else:
		var note: String = D.BOTTLE_NOTES[n % D.BOTTLE_NOTES.size()]
		log_entry("A message in a bottle: \"%s\"", ["#" + note])
		events.append({"type": "note", "text": note})
	_emit("bottle_opened", {})
	return ""

# ================================================================ sleep and naps

func bed_available(bed: String) -> bool:
	match bed:
		"sand":
			return true
		"tent_mattress":
			return structures.has("tent") and structures.has("frond_bed")
		_:
			return structures.has(bed)

## The best bed built so far.
func best_bed() -> String:
	var best := "sand"
	for b in D.BED_RANK:
		if bed_available(b):
			best = b
	return best

## Energy per hour on `bed` right now (balance.json sleep_restore_per_h x sleep_modifiers).
func sleep_rate(bed: String, at: float = -1.0) -> float:
	var bal := D.balance()
	var rate := float(bal.get("sleep_restore_per_h", {}).get(bed, 6))
	if bed == "treehouse":
		rate = D.TREEHOUSE_RATE
	var m: Dictionary = bal.get("sleep_modifiers", {})
	var sheltered := bed in D.SHELTERED_BEDS
	if is_day(at):
		rate *= float(m.get("day_shade", 1.0)) if bed in D.SHADED_BEDS else float(m.get("day_sun", 0.5))
	if not sheltered:
		if weather == "storm":
			rate *= float(m.get("storm_unsheltered", 0.25))
		elif weather in D.RAINY:
			rate *= float(m.get("rain_unsheltered", 0.5))
	if weather in ["heatwave", "cold_snap"]:
		rate *= float(m.get("temp_extreme", 0.8))
	return rate

## How long "Sleep" lasts if started now: through the night to just after sunrise, or by day until
## rested (at most DAY_NAP_MAX_H).
func sleep_hours_for(bed: String) -> float:
	var h := hour()
	if h >= sunset_h() - 1.0 or h < sunrise_h():
		return (next_hour(sunrise_h() + 0.5) - t) / 3600.0
	var rate := maxf(1.0, sleep_rate(bed))
	return clampf((100.0 - bars.energy) / rate, 0.5, D.DAY_NAP_MAX_H)

func start_sleep(bed: String, hours: float) -> void:
	sleep = {"kind": "sleep", "bed": bed, "start": t, "until": t + hours * 3600.0}
	stats["slept:" + bed] = 1
	stats["slept"] = int(stats.get("slept", 0)) + 1
	var kinds := 0
	for b in D.balance().get("sleep_restore_per_h", {}):
		if int(stats.get("slept:" + b, 0)) > 0:
			kinds += 1
	stats["bed_kinds"] = kinds
	_check_side()
	if bed == "sand":
		say("sleep_sand")
	elif bed == "hammock":
		say("sleep_hammock")
	elif bed in D.SHELTERED_BEDS:
		say("sleep_roof")
	events.append({"type": "sleep"})

func naps_today() -> int:
	return int(naps.n) if int(naps.day) == day_index() else 0

## "" when a nap is allowed now, else why not.
func nap_block() -> String:
	var pn: Dictionary = D.balance().get("power_nap", {})
	if naps_today() >= int(pn.get("max_per_day", 2)):
		return "Two naps a day. Even I have standards."
	return ""

func start_nap() -> String:
	var why := nap_block()
	if why != "":
		say("no_nap")
		return why
	var pn: Dictionary = D.balance().get("power_nap", {})
	sleep = {"kind": "nap", "bed": "shade", "start": t, "until": t + float(pn.get("minutes", 30)) * 60.0}
	events.append({"type": "sleep"})
	return ""

func wake() -> void:
	if sleep.is_empty():
		return
	var s := sleep
	sleep = {}
	var hrs := (t - float(s.start)) / 3600.0
	match str(s.kind):
		"nap":
			var pn: Dictionary = D.balance().get("power_nap", {})
			if int(naps.day) != day_index():
				naps = {"day": day_index(), "n": 0}
			naps.n = int(naps.n) + 1
			if hrs >= float(pn.get("minutes", 30)) / 60.0 - 0.01:
				var gain := float(pn.get("energy", 15)) if int(naps.n) == 1 else float(pn.get("second_nap_energy", 8))
				bars.energy = clampf(bars.energy + gain, 0.0, 100.0)
			log_entry("Took a power nap in the shade.")
			_emit("nap_taken", {})
		"faint":
			bars.hp = maxf(bars.hp, D.FAINT_WAKE_HP)
			log_entry("Woke up. Still alive. Still here.")
		_:
			var rb: Dictionary = D.balance().get("rested_buff", {})
			var bed := str(s.bed)
			if hrs >= float(rb.get("min_sleep_h", 6)) and D.BED_RANK.find(bed) >= D.BED_RANK.find(str(rb.get("min_bed", "hammock"))):
				buffs["rested"] = t + D.RESTED_H * 3600.0
				buffs.erase("sandy")
				say("rested")
				log_entry("Slept %s h on the %s. Rested.", [snappedf(hrs, 0.1), "@" + bed])
			elif bed == "sand" and hrs >= 1.0:
				buffs["sandy"] = t + D.SANDY_H * 3600.0
				log_entry("Slept %s h on the sand. Sandy.", [snappedf(hrs, 0.1)])
			else:
				log_entry("Slept %s h.", [snappedf(hrs, 0.1)])
	events.append({"type": "wake"})

func has_buff(name: String) -> bool:
	return float(buffs.get(name, 0.0)) > t

# ================================================================ fire

func fire_lit() -> bool:
	if not structures.has("campfire"):
		return false
	return float(structures.campfire.get("fuel_until", 0.0)) > t and not weather in D.RAINY

## "lit" / "embers" (rain on a fuelled fire) / "dead" / "" (no campfire).
func fire_state() -> String:
	if not structures.has("campfire"):
		return ""
	if float(structures.campfire.get("fuel_until", 0.0)) <= t:
		return "dead"
	return "embers" if weather in D.RAINY else "lit"

## 0..1 flame size from the fuel left (3 h or more = full).
func fire_level() -> float:
	if not structures.has("campfire"):
		return 0.0
	return clampf((float(structures.campfire.get("fuel_until", 0.0)) - t) / (D.FIRE_START_H * 3600.0), 0.0, 1.0)

# ================================================================ crafting

## Can be made at all right now (tier built, quest reward received).
func recipe_unlocked(r: Dictionary) -> bool:
	if int(r.get("tier", 9)) > D.MAX_TIER:
		return false
	if r.id in D.reward_recipes() and not r.id in unlocked:
		return false
	return true

## Known: tier 1-2, or found by combining.
func recipe_known(r: Dictionary) -> bool:
	return recipe_unlocked(r) and (int(r.get("tier", 9)) <= D.KNOWN_TIERS or r.id in discovered)

## The recipes on the craft screen (known ones).
func craft_list() -> Array:
	var out := []
	for r in D.recipes().values():
		if recipe_known(r):
			out.append(r)
	return out

## Terraria-style: a recipe shows once the bag holds at least one of its materials (or tools), or
## once you have made it. Nothing is listed on an empty beach.
func craft_visible(r: Dictionary) -> bool:
	if _made(r):
		return true
	# the tree: tier 2 opens once two tier-1 things have been made
	if int(r.get("tier", 1)) >= 2 and made_in_tier(1) < D.TIER2_NEEDS_TIER1:
		return false
	# listed only when everything it needs is in the bag at least once (the amount may still be short);
	# in the opening only the spark kit and the campfire (owner, 2026-11-09: "give me the stuff as I need it")
	if tut >= 0 and not str(r.id) in ["spark_kit", "campfire"]:
		return false
	for part in recipe_parts(r):
		if count(str(part[0])) <= 0:
			return false
	return true

func _made(r: Dictionary) -> bool:
	return int(stats.get("made:" + str(r.id), 0)) > 0 or structures.has(str(r.get("out", "")))

## How many different recipes of `tier` have been made so far.
func made_in_tier(tier: int) -> int:
	var n := 0
	for r in D.recipes().values():
		if int(r.get("tier", 1)) == tier and _made(r):
			n += 1
	return n

func craft_visible_list() -> Array:
	var out := []
	for r in craft_list():
		if craft_visible(r):
			out.append(r)
	return out

## Recipes still to find (tier 3-4, not discovered).
func undiscovered() -> Array:
	var out := []
	for r in D.recipes().values():
		if recipe_unlocked(r) and not recipe_known(r):
			out.append(r)
	return out

## Everything a recipe asks for, consumed or not: [[id, n], ...].
static func recipe_parts(r: Dictionary) -> Array:
	var out: Array = r.get("in", []).duplicate()
	for key in ["tool", "needs"]:
		if str(r.get(key, "")) != "":
			out.append([str(r[key]), 1])
	return out

## Combining item `a` with item `b` in the bag (GDD §10, CRAFTING.md "combine by dragging A onto B").
## Finds a recipe that uses both (or two of `a`), discovers it if new, and queues it when everything
## is there. Returns {ok, recipe, discovered, queued, text}: `text` is an English line for the screen.
func combine(a: String, b: String) -> Dictionary:
	var best := {}
	var best_score := -1
	for r in D.recipes().values():
		if not recipe_unlocked(r):
			continue
		var ids := {}
		for pair in recipe_parts(r):
			ids[str(pair[0])] = int(pair[1])
		var fits := false
		if a == b:
			fits = int(ids.get(a, 0)) >= 2
		else:
			fits = ids.has(a) and ids.has(b)
		if not fits:
			continue
		var score := 0
		if craft_block(r.id) == "":
			score += 4
		if not recipe_known(r):
			score += 8     # a recipe still to find wins: otherwise stick + stone is always "spark kit", never the sundial
		if r.get("station", "hands") == "hands":
			score += 1
		if score > best_score:
			best_score = score
			best = r
	if best.is_empty():
		say("combine_none")
		return {"ok": false, "recipe": "", "discovered": false, "queued": false, "text": "Those two don't go together."}
	var found := false
	if not recipe_known(best):
		discovered.append(best.id)
		found = true
		_xp("tinkering", 3)
		say("discover")
		log_entry("Figured out a new recipe: %s.", ["@" + str(best.out)])
		events.append({"type": "discover", "id": best.id})
		# found, not made: the materials may be meant for something else (the only sailcloth is the hammock's)
		return {"ok": true, "recipe": best.id, "discovered": true, "queued": false, "text": ""}
	var why := enqueue("craft", best.id)
	return {"ok": true, "recipe": best.id, "discovered": found, "queued": why == "", "text": why}

## Skill level from XP: level n needs 10 * n * (n + 1) / 2.
func skill_level(skill: String) -> int:
	var x := int(xp.get(skill, 0))
	var n := 0
	while n < D.SKILL_MAX and x >= 10 * (n + 1) * (n + 2) / 2:
		n += 1
	return n

func skill_for(kind: String, target: String) -> String:
	if kind == "craft":
		return D.recipe_skill(D.recipe(target))
	return str(D.ACT_SKILL.get(kind, ""))

## Why the rain catcher / water still can't give a drink now ("" = it can).
func drink_from_block(sid: String) -> String:
	if not structures.has(sid):
		return "Nothing there."
	if float(structures[sid].get("water", 0.0)) < 1.0:
		return "Empty. Come back after some rain." if sid == "rain_catcher" else "Not enough yet. It needs sun."
	return ""

## Drinks one unit from the rain catcher or water still (instant). "" or why not.
func drink_from(sid: String) -> String:
	var why := drink_from_block(sid)
	if why != "":
		return why
	var st: Dictionary = structures[sid]
	st["water"] = float(st.water) - 1.0
	bars.water = clampf(bars.water + D.WATER_PER_DRINK, 0.0, 100.0)
	events.append({"type": "drink"})
	log_entry("Drank fresh water from the %s.", ["@" + sid])
	_emit("drank", {"id": sid})
	return ""

func _roll(table: Array) -> String:
	var total := 0.0
	for row in table:
		total += float(row[1])
	var r := rng.randf() * total
	for row in table:
		r -= float(row[1])
		if r < 0.0:
			return str(row[0])
	return str(table[0][0])

## "" when recipe `rid` can be queued now, else the reason (English, translated on screen).
func craft_block(rid: String, self_q = null) -> String:
	var r := D.recipe(rid)
	if r.is_empty() or not recipe_unlocked(r):
		return "Not known yet."
	if not recipe_known(r):
		return "Not figured out yet. Combine its materials in the bag."
	if r.out_type == "structure" and structures.has(r.out):
		return "Already built."
	for q in queue:
		if q.kind == "craft" and q.target == rid and r.out_type == "structure" and not is_same(q, self_q):
			return "Already queued."
	for pair in r.get("in", []):
		if count(str(pair[0])) < int(pair[1]):
			return "Missing materials."
	for key in ["tool", "needs"]:
		var tool: String = str(r.get(key, ""))
		if tool != "" and count(tool) <= 0:
			return "Needs a %s." % D.item_name(tool)
	var st: String = str(r.get("station", "hands"))
	if D.STATION_STRUCTURE.has(st) and not structures.has(D.STATION_STRUCTURE[st]):
		return "Needs a %s." % D.item_name(D.STATION_STRUCTURE[st])
	if st == "campfire" and not fire_lit():
		return "The fire is out."
	return ""

# ================================================================ the queue

func active() -> Dictionary:
	if queue.is_empty() or float(queue[0].get("start", 0.0)) <= 0.0:
		return {}
	return queue[0]

func busy() -> bool:
	return not active().is_empty() or not sleep.is_empty()

## Adds an action. Returns "" or why not (English).
func enqueue(kind: String, target: String = "", extra: Dictionary = {}) -> String:
	if queue.size() >= D.QUEUE_MAX:
		say("busy")
		return "The queue is full (5)."
	var why := action_block(kind, target, extra)
	if why != "":
		return why
	queue.append({"kind": kind, "target": target, "extra": extra, "start": 0.0, "end": 0.0, "energy": 0.0, "consumed": []})
	_start_next()
	return ""

func cancel(i: int) -> void:
	if i < 0 or i >= queue.size():
		return
	if i == 0 and not active().is_empty():
		_cancel_active(true)
	else:
		queue.remove_at(i)
	_start_next()

func _cancel_active(refund: bool) -> void:
	var a := active()
	if a.is_empty():
		return
	if refund:
		give_list(a.consumed)
	queue.pop_front()

## Why `kind` on `target` can't happen (checked when queued and again when it starts).
func action_block(kind: String, target: String, extra: Dictionary = {}, self_q = null) -> String:
	match kind:
		"haul":
			if not debris.get(target, false):
				return "Nothing there."
			for q in queue:
				if q.kind == "haul" and q.target == target and not is_same(q, self_q):
					return "Already queued."
		"gather":
			if float(spots.get(target, 0.0)) < 1.0:
				return "Nothing left here. Come back later."
		"shake":
			if float(palms[target].felled) > 0.0:
				return "That palm is a stump now."
		"chop":
			if not D.PALMS[target].choppable:
				return "Palms A and B hold the hammock. Not those."
			if float(palms[target].felled) > 0.0:
				return "That palm is a stump now."
			if count("stone_axe") <= 0:
				return "Needs a %s." % D.item_name("stone_axe")
		"fish":
			if count("fishing_pole") <= 0:
				return "Needs a %s." % D.item_name("fishing_pole")
		"seawater":
			if count("coconut_bowl") <= 0:
				return "Needs a %s." % D.item_name("coconut_bowl")
		"craft":
			return craft_block(target, self_q)
		"fuel":
			if not structures.has("campfire"):
				return "No campfire."
			if count(target) <= 0:
				return "Missing materials."
		"light":
			if not structures.has("campfire"):
				return "No campfire."
			if count("spark_kit") <= 0:
				return "Needs a %s." % D.item_name("spark_kit")
			if count("dry_frond") <= 0:
				return "Needs a %s." % D.item_name("dry_frond")
		"empty_trap":
			if not structures.has("fish_trap"):
				return "No fish trap."
			if structures.fish_trap.get("catch", []).is_empty():
				return "The trap is empty. Patience."
		"tally":
			if not structures.has("crafting_stump"):
				return "Needs a %s." % D.item_name("crafting_stump")
			if day_index() in tallies:
				return "Today is already scratched in."
		"shore":
			if shore.pile.is_empty():
				return "Nothing washed up yet."
		"pastime":
			return pastime_block(target, self_q)
		"spear":
			if count("spear") <= 0:
				return "Needs a %s." % D.item_name("spear")
		"plant":
			if not structures.has("garden_plot"):
				return "No garden plot."
			if garden_state() != "empty":
				return "Something is already growing."
			if count("seeds") <= 0:
				return "No seeds. The sea brings some now and then."
			for q in queue:
				if q.kind == "plant" and not is_same(q, self_q):
					return "Already queued."
		"harvest":
			if garden_state() != "ready":
				return "Not ready yet. Plants take their time."
			for q in queue:
				if q.kind == "harvest" and not is_same(q, self_q):
					return "Already queued."
		"sleep":
			if not bed_available(target):
				return "No such bed."
		"nap":
			var why := nap_block()
			if why != "":
				return why
			for q in queue:
				if q.kind == "nap" and not is_same(q, self_q):
					return "Already queued."
	return ""

func _cost(kind: String, target: String) -> float:
	if kind == "pastime":
		return float(Pastimes.get_pastime(target).get("energy", 0.0))
	if kind == "craft":
		return float(D.recipe(target).get("en", 0))
	var a: Dictionary = D.ACT.get(kind, {})
	if a.has("cost"):
		return float(D.balance().get("action_energy_cost", {}).get(a.cost, 0))
	return float(a.get("energy", 0.0))

func _minutes(kind: String, target: String) -> float:
	if kind == "pastime":
		return float(Pastimes.get_pastime(target).get("min", 10.0))
	if kind == "craft":
		var r := D.recipe(target)
		var m := float(r.get("min", 5))
		return m * (D.CRAFT_EARLY_MULT if int(r.get("tier", 1)) <= D.KNOWN_TIERS else 1.0)
	return float(D.ACT.get(kind, {}).get("min", 5.0))

## Planned duration in seconds if it started now.
func duration_of(kind: String, target: String) -> float:
	var secs := _minutes(kind, target) * 60.0
	var le: Dictionary = D.balance().get("low_energy", {})
	if bars.energy < float(le.get("threshold", 20)):
		secs *= float(le.get("duration_mult", 1.5))
	if has_buff("rested"):
		secs /= 1.0 + float(D.balance().get("rested_buff", {}).get("action_speed_bonus", 0.1))
	var sk := skill_for(kind, target)
	if sk != "":
		secs *= 1.0 - D.SKILL_SPEED * skill_level(sk)
	# mood: a happy castaway works a little faster, a miserable one drags his feet
	if mood >= D.MOOD_HIGH:
		secs *= D.MOOD_HIGH_SPEED
	elif mood < D.MOOD_LOW:
		secs *= D.MOOD_LOW_SPEED
	return secs

func energy_cost(kind: String, target: String) -> float:
	return _cost(kind, target)

func _start_next() -> void:
	while not queue.is_empty() and float(queue[0].start) <= 0.0 and sleep.is_empty():
		var q: Dictionary = queue[0]
		var why := action_block(q.kind, q.target, q.extra, q)
		if why != "":
			queue.pop_front()
			log_entry("Skipped a plan: %s", ["~" + why])
			continue
		if q.kind == "sleep":
			queue.pop_front()
			start_sleep(q.target, float(q.extra.get("hours", sleep_hours_for(q.target))))
			return
		if q.kind == "nap":
			queue.pop_front()
			start_nap()
			return
		q.start = t
		q.end = t + duration_of(q.kind, q.target)
		q.energy = _cost(q.kind, q.target)
		bars.energy = clampf(bars.energy - q.energy, 0.0, 100.0)
		q.consumed = _consume_inputs(q)
		events.append({"type": "start", "kind": q.kind, "target": q.target})
		return

func _consume_inputs(q: Dictionary) -> Array:
	var used := []
	if q.kind == "craft":
		for pair in D.recipe(q.target).get("in", []):
			remove(str(pair[0]), int(pair[1]))
			used.append([str(pair[0]), int(pair[1])])
	elif q.kind == "fuel":
		remove(q.target, 1)
		used.append([q.target, 1])
	elif q.kind == "light":
		remove("dry_frond", 1)
		used.append(["dry_frond", 1])
	elif q.kind == "plant":
		remove("seeds", 1)
		used.append(["seeds", 1])
		if count("compost") > 0:
			remove("compost", 1)
			used.append(["compost", 1])
	return used

## The garden plot: "" (none), "empty", "growing" or "ready".
func garden_state() -> String:
	if not structures.has("garden_plot"):
		return ""
	var ready := float(structures.garden_plot.get("ready", 0.0))
	if ready <= 0.0:
		return "empty"
	return "ready" if t >= ready else "growing"

## Spear fishing in the shallows: quick, no bait, a miss now and then. At low tide the fish have
## nowhere to hide (no misses, big fish twice as likely).
func _spear() -> void:
	_wear("spear")
	var table: Array = D.SPEAR_TABLE.duplicate(true)
	if is_low_tide():
		for row in table:
			if str(row[0]) == "":
				row[1] = 0
			elif str(row[0]) == "fish_big":
				row[1] = int(row[1]) * 2
	var id := _roll(table)
	if id == "":
		say("nothing")
		log_entry("Stabbed the sea. The sea did not notice.")
		return
	catches += 1
	add(id, 1)
	_xp("fishing", 2)
	say("spear")
	log_entry("Speared: %s.", ["@" + id])
	bump("speared")
	_emit("caught", {"id": id})

func _finish(q: Dictionary) -> void:
	var tgt: String = q.target
	match str(q.kind):
		"haul":
			debris.erase(tgt)
			var loot := D.debris_loot(tgt)
			give_list(loot)
			log_entry("Salvaged the %s.", ["%" + tgt])
			say("craft")
			_emit("hauled", {"id": tgt})
			if tgt == "crate":
				_emit("crate_opened", {"id": tgt})
		"empty_trap":
			var caught: Array = structures.fish_trap.get("catch", [])
			for id in caught:
				add(str(id), 1)
			log_entry("Emptied the fish trap: %d catches.", [caught.size()])
			structures.fish_trap["catch"] = []
			_xp("fishing", caught.size())
		"gather":
			var s: Dictionary = D.SPOTS[tgt]
			var n := mini(int(s.n), int(floor(float(spots[tgt]))))
			spots[tgt] = float(spots[tgt]) - n
			if n > 0:
				add(str(s.item), n)
				_got(str(s.item), n)
				_xp("foraging", 1)
				log_entry("Gathered %d %s.", [n, "@" + str(s.item)])
				_emit("gathered", {"id": str(s.item), "n": n})
				dstats[str(s.item)] = int(dstats.get(str(s.item), 0)) + n
				_check_daily()
				if tgt in D.REEF_SPOTS and is_low_tide():
					var reef := _roll(D.REEF_TABLE)
					if reef != "":
						add(reef, 1)
						bump("reef")
						log_entry("Low tide. The reef was showing: found %s.", ["@" + reef])
		"shake":
			var p: Dictionary = palms[tgt]
			if float(p.coco) >= 1.0:
				p.coco = float(p.coco) - 1.0
				add("coconut", 1)
				log_entry("Shook palm %s. One coconut. Almost on my head.", [tgt])
			else:
				add("frond", 1)
				log_entry("Shook palm %s. No coconuts. Got a frond for my trouble.", [tgt])
			bump("shakes")
			# wild bees nest in palm crowns: now and then a lump of old comb comes down (the only wax on the island)
			if int(stats.get("shakes", 0)) > 1 and rng.randf() < D.WAX_SHAKE_CHANCE:
				add("wax", 1)
				log_entry("A lump of old beeswax fell out of the palm. The bees have moved out. I checked. From a distance.")
		"chop":
			var p: Dictionary = palms[tgt]
			p.felled = t
			var coco := int(floor(float(p.coco)))
			p.coco = 0.0
			give_list(D.CHOP_LOOT)
			if coco > 0:
				add("coconut", coco)
			_wear("stone_axe")
			_xp("woodcutting", 3)
			say("chop")
			log_entry("Chopped down palm %s.", [tgt])
			_emit("tree_felled", {"tree": tgt})
		"fish":
			_fish()
		"seawater":
			add("seawater", 1)
			_wear("coconut_bowl")
			log_entry("Scooped up some seawater.")
		"craft":
			_finish_craft(q)
		"fuel":
			var c: Dictionary = structures.campfire
			c.fuel_until = maxf(float(c.get("fuel_until", 0.0)), t) + float(D.FUEL_H.get(tgt, 0.5)) * 3600.0
			log_entry("Fed the fire.")
			bump("fed_fire")
		"light":
			_wear("spark_kit")
			var fail := fire_fail_chance()
			if rng.randf() < fail:
				say("fire_fail")
				log_entry("Tried to relight the fire. Smoke, then nothing.")
			else:
				var c: Dictionary = structures.campfire
				c.fuel_until = maxf(float(c.get("fuel_until", 0.0)), t) + 1.0 * 3600.0
				_xp("fire", 2)
				say("fire_ok")
				log_entry("Relit the fire.")
				bump("relit")
		"tally":
			tallies.append(day_index())
			say("tally")
			log_entry("Scratched a tally mark on the stump: day %d.", [day_number()])
			_emit("tally_added", {})
		"shore":
			for id in shore.pile:
				add(id, int(shore.pile[id]))
			shore.pile = {}
			say("shore")
			log_entry("Hauled in what the sea brought.")
		"pastime":
			_finish_pastime(tgt)
		"spear":
			_spear()
		"plant":
			var g: Dictionary = structures.garden_plot
			var rich := false
			for pair in q.consumed:
				if str(pair[0]) == "compost":
					rich = true
			g["planted"] = t
			g["ready"] = t + D.GARDEN_GROW_H * 3600.0 * (D.COMPOST_GROW_MULT if rich else 1.0)
			g["rich"] = rich
			_xp("foraging", 2)
			log_entry("Planted seeds in compost. They looked pleased." if rich else "Planted seeds in the garden plot.")
			_emit("planted", {})
		"harvest":
			var g: Dictionary = structures.garden_plot
			var n := D.GARDEN_YIELD + (1 if g.get("rich", false) else 0)
			g.erase("planted")
			g.erase("ready")
			g.erase("rich")
			add("sweet_potato", n)
			add("seeds", 1)      # one kept back to plant again
			_xp("foraging", 4)
			say("harvest")
			log_entry("Dug up %d sweet potatoes and kept a cutting to replant.", [n])
			bump("harvests")
			_emit("harvested", {})
		"inspect":
			say("cave")
			log_entry("Listened at the big rock. It sounds hollow.")

func fire_fail_chance() -> float:
	var c := D.FIRE_FAIL_CHANCE * maxf(0.3, 1.0 - float(xp.get("fire", 0)) / 50.0)
	if bars.energy < float(D.balance().get("low_energy", {}).get("threshold", 20)):
		c *= float(D.balance().get("low_energy", {}).get("fail_mult", 1.5))
	return c

func _finish_craft(q: Dictionary) -> void:
	var r := D.recipe(q.target)
	for key in ["tool", "needs"]:
		if str(r.get(key, "")) != "":
			_wear(str(r[key]))
	if r.out == "campfire" and not structures.has("campfire"):
		if fire_fails < D.FIRST_FIRE_FAILS:
			fire_fails += 1
			give_list(q.consumed)  # the stones and sticks stay; only the spark failed
			say("fire_fail")
			log_entry("Tried to light a fire. Attempt %d. Smoke. Sadness.", [fire_fails])
			events.append({"type": "fail"})
			return
	bump("made:" + str(r.id))
	bump("crafted_any")
	if str(r.id).begins_with("cook") and not is_day():
		bump("night_cook")
	if r.out_type == "structure":
		structures[r.out] = {"built": t}
		_xp(D.recipe_skill(r), 3)
		if r.out == "campfire":
			structures.campfire.fuel_until = t + D.FIRE_START_H * 3600.0
			_xp("fire", 5)
			say("fire_ok")
		else:
			say("craft")
		log_entry("Built a %s.", ["@" + str(r.out)])
		_emit("structure_built", {"id": r.out})
	elif r.id == "bottle_post":
		# No bottle mail yet (owner, 2026-11-08): the bottle goes out to sea, and now and then one comes
		# back with tomorrow's delivery. (It used to land in the bag as a note "from a pen pal".)
		mood = clampf(mood + 3.0, 0.0, 100.0)
		if int(shore.get("replies", 0)) < D.BOTTLE_REPLY_MAX and rng.randf() < D.BOTTLE_REPLY_CHANCE:
			shore["replies"] = int(shore.get("replies", 0)) + 1
		_xp(D.recipe_skill(r), 2)
		say("bottle_sent")
		log_entry("Wrote a note, corked the bottle and threw it as far as I could. So, not far.")
		bump("bottles_sent")
		_emit("crafted", {"id": "bottle_post"})
	else:
		add(r.out, int(r.get("qty", 1)))
		_xp(D.recipe_skill(r), 2)
		say("craft")
		log_entry("Made a %s.", ["@" + str(r.out)])
		_emit("crafted", {"id": r.out})

func _fish() -> void:
	var le: Dictionary = D.balance().get("low_energy", {})
	var id := ""
	var baited := catches > 0 and count("bait") > 0
	if baited:
		remove("bait", 1)      # bait on the hook: no empty lines, big fish twice as likely
		bump("bait_used")
	if catches == 0:
		id = "fish_small"
	else:
		var table: Array = D.FISH_TABLE.duplicate(true)
		if baited:
			for row in table:
				if str(row[0]) == "":
					row[1] = 0
				elif str(row[0]) == "fish_big":
					row[1] = int(row[1]) * D.BAIT_BIG_MULT
		id = _roll(table)
		if id != "" and bars.energy < float(le.get("threshold", 20)) and rng.randf() < 0.25:
			id = ""  # tired: it got away
	if id == "" and weather in D.RAINY and rng.randf() < D.RAIN_FISH_BONUS:
		id = "fish_small"  # rain: the fish come up to bite
	if id == "":
		_wear("fishing_pole")
		say("nothing")
		log_entry("Fished for a while. Caught nothing but a tan.")
		return
	if not is_day() and is_full_moon() and rng.randf() < D.MOON_FISH_CHANCE:
		id = "pearl"
		bump("moon_fish")
		log_entry("Moonlight on the water. Something shiny took the bait.")
	catches += 1
	add(id, 1)
	_xp("fishing", 2)
	_wear("fishing_pole")
	say("boot" if id == "boot" else "fish")
	log_entry("Caught: %s.", ["@" + id])
	_emit("caught", {"id": id})

func _xp(skill: String, n: int) -> void:
	xp[skill] = int(xp.get(skill, 0)) + n

# ================================================================ quests (tutorial T01-T12)

func tap_johnny() -> void:
	_emit("tapped_johnny", {})

## Count something for the side quests and finish any that are now met.
func bump(key: String, n: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n
	dstats[key] = int(dstats.get(key, 0)) + n
	_check_side()
	_check_daily()

## Three daily quests a day, picked from the island seed (D-series).
func _roll_dailies(today: int) -> void:
	dstats = {}
	dq_done = []
	dq = []
	var pool: Array = []
	for q in Quests.DAILY:
		pool.append(q.id)
	for i in 3:
		var k := int(floor(_hf(wseed, today * 7 + i) * pool.size()))
		dq.append(pool[k])
		pool.remove_at(k)

func _check_daily() -> void:
	for id in dq:
		var q := Quests.daily(str(id))
		if q.is_empty() or id in dq_done or int(dstats.get(q.stat, 0)) < int(q.need):
			continue
		dq_done.append(id)
		give_list(q.reward)
		log_entry("Daily done: %s.", ["~" + str(q.en)])
		events.append({"type": "daily", "id": id})

## Things picked up by hand (spots, odd jobs): the Day 1 checklist counts these.
func _got(id: String, n: int) -> void:
	stats["got:" + id] = int(stats.get("got:" + id, 0)) + n
	_check_intro()

## The current Day 1 checklist step ({} when it is done): {key, need, hint, have}.
func intro_step() -> Dictionary:
	for st in D.INTRO:
		var have := int(stats.get(str(st.key), 0))
		if have < int(st.need):
			var out: Dictionary = st.duplicate()
			out["have"] = have
			return out
	return {}

## The guided opening (D.TUT): the current step with progress, {} when off or finished.
func tut_step() -> Dictionary:
	if tut < 0 or tut >= D.TUT.size():
		return {}
	var out: Dictionary = D.TUT[tut].duplicate()
	var have := 0
	var need := 0
	for r in out.get("reqs", []):
		have += mini(int(stats.get(str(r[0]), 0)), int(r[1]))
		need += int(r[1])
	out["have"] = have
	out["need"] = need
	return out

## How far into the opening we are: true when step `id` was reached (so its HUD part shows).
func tut_reached(id: String) -> bool:
	if tut < 0:
		return true
	for i in mini(tut + 1, D.TUT.size()):
		if str(D.TUT[i].id) == id or id in D.TUT[i].get("show", []):
			return true
	return false

## The game tells the engine about a tutorial action ("walk", "ab", "bag", "ack", "journal").
func tut_event(name: String) -> void:
	if tut < 0:
		return
	stats["tut:" + name] = int(stats.get("tut:" + name, 0)) + 1
	_check_tut()

func _check_tut() -> void:
	while tut >= 0 and tut < D.TUT.size():
		var st: Dictionary = D.TUT[tut]
		for r in st.get("reqs", []):
			if int(stats.get(str(r[0]), 0)) < int(r[1]):
				return
		# a step with a card waits for "Got it" (tut:ack counted per step)
		if st.get("card", false):
			var k := "tut:ack:" + str(st.id)
			if int(stats.get(k, 0)) < 1:
				return
		tut += 1
		events.append({"type": "tut", "id": st.id})
	if tut >= D.TUT.size():
		tut = -1
		events.append({"type": "tut_done"})
		tap_johnny()      # T01 ("get the day started") is what the opening was

## "Got it" on a tutorial card.
func tut_ack() -> void:
	if tut < 0 or tut >= D.TUT.size():
		return
	stats["tut:ack:" + str(D.TUT[tut].id)] = 1
	_check_tut()

func _check_intro() -> void:
	_check_tut()
	if flags.get("intro_all", false):
		return
	if intro_step().is_empty():
		flags["intro_all"] = true
		give_list([["rope", 2], ["stone", 2]])
		log_entry("Day 1 sorted: a bed, a pile of stuff, and nothing left in the tank.")
		events.append({"type": "intro_done"})

func _check_side() -> void:
	_check_intro()
	stats["capacity"] = capacity()
	for q in Quests.LIST:
		if q.id in side_done or int(stats.get(q.stat, 0)) < int(q.need):
			continue
		side_done.append(q.id)
		var rw: Dictionary = q.reward
		for k in rw.get("xp", {}):
			_xp(k, int(rw.xp[k]))
		give_list(rw.get("items", []))
		var gag: String = str(rw.get("gag", ""))
		if gag != "" and not gag in gags:
			gags.append(gag)
		var dec: String = str(rw.get("decor", ""))
		if dec != "" and not dec in decor:
			decor.append(dec)
		log_entry("Quest done: %s.", ["~" + str(q.en)])
		say("quest")
		events.append({"type": "side", "id": q.id})

func _emit(ev: String, data: Dictionary) -> void:
	stats["ev:" + ev] = int(stats.get("ev:" + ev, 0)) + 1
	dstats["ev:" + ev] = int(dstats.get("ev:" + ev, 0)) + 1
	if data.has("id"):
		var k := "ev:%s:%s" % [ev, data.id]
		stats[k] = int(stats.get(k, 0)) + 1
		dstats[k] = int(dstats.get(k, 0)) + 1
	_check_side()
	_check_daily()
	if quest == "":
		return
	var q := D.quest(quest)
	if q.is_empty():
		return
	var trig: Dictionary = q.get("trigger", {})
	if str(trig.get("event", "")) != ev:
		return
	for k in trig:
		if k == "event" or k == "any":
			continue
		if str(data.get(k, "")) != str(trig[k]):
			return
	_complete(q, ev, data)

func _complete(q: Dictionary, ev: String, data: Dictionary) -> void:
	quests_done.append(q.id)
	var rw: Dictionary = q.get("reward", {})
	for f in rw.get("flags", []):
		flags[f] = true
	for k in rw.get("xp", {}):
		_xp(k, int(rw.xp[k]))
	give_list(rw.get("items", []))
	var loot: String = str(rw.get("loot", ""))
	# T02's loot is the crate itself (recipes.json debris_loot): it was handed over when it opened.
	if loot != "" and not (ev == "crate_opened" and str(data.get("id", "")) == loot):
		give_list(D.debris_loot(loot))
	var gag: String = str(rw.get("gag", ""))
	if gag != "" and not gag in gags:
		gags.append(gag)
	var rec: String = str(rw.get("recipe", ""))
	if rec != "" and not rec in unlocked:
		unlocked.append(rec)
	var dec: String = str(rw.get("decor", ""))
	if dec != "" and not dec in decor:
		decor.append(dec)
	if q.has("journal_en"):
		log_entry(str(q.journal_en))
	var nxt: Array = q.get("next", [])
	quest = str(nxt[0]) if not nxt.is_empty() else ""
	events.append({"type": "quest", "id": q.id, "next": quest})
	_complete_if_met()

## A quest whose goal was already reached (the campfire in the opening, a fish trap built before the
## quest asked for one) completes at once.
func _complete_if_met() -> void:
	if quest == "":
		return
	var nq := D.quest(quest)
	var trig: Dictionary = nq.get("trigger", {})
	var key := "ev:" + str(trig.get("event", "-"))
	if trig.has("id"):
		key += ":" + str(trig.id)
	if nq.has("trigger") and trig.size() <= 2 and not trig.has("any") and int(stats.get(key, 0)) > 0 and (trig.size() == 1 or trig.has("id")):
		_complete(nq, str(trig.event), {})

# ================================================================ journal, lines

## args: numbers as is; "@id" = an item / structure name; "%id" = a debris name; "#text" / "~text" =
## a sentence to translate. The screen formats them (UI language at display time).
func log_entry(text: String, args: Array = []) -> void:
	journal.append({"t": t, "text": text, "args": args, "away": not _online})
	if journal.size() > 300:
		journal = journal.slice(journal.size() - 300)

func say(cat: String) -> void:
	var lines: Array = D.LINES.get(cat, [])
	if lines.is_empty():
		return
	events.append({"type": "say", "text": lines[rng.randi() % lines.size()]})

func pop_events() -> Array:
	var e := events
	events = []
	return e

# ================================================================ debug (dev panel)

func debug_set_bar(k: String, v: float) -> void:
	bars[k] = clampf(v, 0.0, 100.0)
	_low[k] = false

func debug_give(id: String, n: int) -> void:
	add(id, n)

# ================================================================ save

func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION, "t": t, "tz": tz, "hemisphere": hemisphere, "look": look, "cname": cname, "start_day": start_day,
		"bars": bars, "mood": mood, "slots": slots, "slot_count": slot_count, "ground": ground,
		"structures": structures, "debris": debris, "palms": palms, "spots": spots, "queue": queue,
		"sleep": sleep, "naps": naps, "buffs": buffs, "flags": flags, "quest": quest, "tut": tut,
		"quests_done": quests_done, "xp": xp, "gags": gags, "decor": decor, "unlocked": unlocked, "discovered": discovered,
		"fire_fails": fire_fails, "catches": catches, "raw_eaten": raw_eaten, "tallies": tallies,
		"projects": projects, "pinned": pinned, "streak": streak, "dstats": dstats, "dq": dq, "dq_done": dq_done, "weather": weather, "weather_auto": weather_auto, "stats": stats, "side_done": side_done, "wseed": wseed, "tide_off": tide_off, "shore": shore, "journal": journal, "rng_seed": str(rng.seed),
		"rng_state": str(rng.state), "low": _low,
	}

func from_dict(d: Dictionary) -> bool:
	if int(d.get("v", 0)) != SAVE_VERSION:
		return false
	t = float(d.t)
	tz = int(d.get("tz", 0))
	hemisphere = str(d.get("hemisphere", "south"))
	look = str(d.get("look", "male1"))
	cname = str(d.get("cname", ""))
	start_day = int(d.start_day)
	bars = d.bars
	mood = float(d.get("mood", 60))
	slots = d.slots
	for s in slots:
		s.n = int(s.n)
	slot_count = int(d.get("slot_count", 12))
	ground = d.get("ground", {})
	structures = d.get("structures", {})
	debris = d.get("debris", {})
	palms = d.get("palms", {})
	spots = d.get("spots", {})
	queue = d.get("queue", [])
	sleep = d.get("sleep", {})
	naps = d.get("naps", {"day": -1, "n": 0})
	buffs = d.get("buffs", {})
	flags = d.get("flags", {})
	quest = str(d.get("quest", ""))
	tut = int(d.get("tut", -1))
	quests_done = d.get("quests_done", [])
	xp = d.get("xp", {})
	gags = d.get("gags", [])
	decor = d.get("decor", [])
	unlocked = d.get("unlocked", [])
	discovered = d.get("discovered", [])
	fire_fails = int(d.get("fire_fails", 0))
	catches = int(d.get("catches", 0))
	raw_eaten = int(d.get("raw_eaten", 0))
	tallies = []
	for x in d.get("tallies", []):
		tallies.append(int(x))
	weather = str(d.get("weather", "clear"))
	weather_auto = bool(d.get("weather_auto", true))
	stats = d.get("stats", {})
	projects = d.get("projects", {})
	dstats = d.get("dstats", {})
	streak = d.get("streak", streak)
	dq = d.get("dq", [])
	dq_done = d.get("dq_done", [])
	pinned = str(d.get("pinned", ""))
	side_done = d.get("side_done", [])
	wseed = int(d.get("wseed", int(d.t) & 0x7fffffff))
	tide_off = float(d.get("tide_off", float(wseed % int(D.TIDE_MIN))))
	shore = d.get("shore", shore)
	journal = d.get("journal", [])
	_low = d.get("low", {})
	rng.seed = int(str(d.get("rng_seed", "1")))
	rng.state = int(str(d.get("rng_state", "0")))
	# a save that finished the story before it grew (T13+ added 2026-11-09) picks it up where it now goes on
	if quest == "" and not quests_done.is_empty():
		var last := D.quest(str(quests_done[-1]))
		var nxt: Array = last.get("next", [])
		if not nxt.is_empty() and not str(nxt[0]) in quests_done:
			quest = str(nxt[0])
			_complete_if_met()
	return true

## A typed name made safe: trimmed, control characters dropped, 16 characters at most.
static func clean_name(raw: String) -> String:
	var out := ""
	for i in raw.strip_edges().length():
		var c := raw.strip_edges().substr(i, 1)
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127:
			out += c
	return out.substr(0, 16).strip_edges()
