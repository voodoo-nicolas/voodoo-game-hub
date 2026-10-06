extends RefCounted

## Every way to play, as data: the classic modes and the campaign's levels
## share one format, read by geometry_wars_game.gd.
##
##   map     [w, h] in grid squares, before MAP_SCALE (the view shows 19
##           squares top to bottom, so most maps are bigger than the screen
##           and the camera follows; the tiny ones stay tiny)
##   lives   0 = unlimited (Deadline)       bombs   at the start (0 = none)
##   bomb_every / life_every   points per extra bomb / life (0 = never)
##   time    seconds on the clock (0 = none); "survive" levels end when it runs out
##   goal    "endless" (classic) | "survive" | "kills" n | "gates" n | "geoms" n | "boss"
##   gun     false = Pacifism (no shooting)
##   king    true = you can only shoot inside a zone, enemies can't enter one
##   gates   [every s, max on the map]: gates keep appearing
##   waves   [every s at the start, every s at the end]: walls of rockets
##   spawn   "ramp" (Evolved's table, growing with time) or {type: weight}
##   rate    [interval at the start, at the end, seconds to get there]
##   events  [[at s, repeat every s (0 = once), what, arg, n]...] where what is
##           horde (mayflies/protons from a corner), cluster (a pack at an edge
##           spot), ring (around the player), line (rockets), wall (rocket wall,
##           arg = gap), nufo, ufo, spawn (n of a type), gates / golden, boss
##           (arg = kind, n = 1 for a hard one)
##   target  the score for the third star (stars: 1 for finishing, 1 more
##           for not losing a life, 1 more for reaching the target)
##   grid    the world's colour

const WORLDS := [
	{"name": "Neon Shallows", "grid": Color(0.18, 0.4, 0.9)},
	{"name": "Pink Nebula", "grid": Color(0.75, 0.2, 0.75)},
	{"name": "Acid Fields", "grid": Color(0.3, 0.8, 0.25)},
	{"name": "Solar Forge", "grid": Color(0.95, 0.5, 0.15)},
	{"name": "Void Core", "grid": Color(0.5, 0.3, 1.0)},
	{"name": "Ultimate", "grid": Color(1.0, 0.2, 0.3)},
]
const LEVELS_PER_WORLD := 6
## Every map but the deliberately tiny ones is this much bigger than written.
const MAP_SCALE := 1.5
const TINY_MAP := 22
## Ultimate is world 6, opened by clearing level 30; it has 10 levels.
const ULTIMATE_FIRST := 31

const CLASSIC := {
	"evolved": {"title": "Evolved", "map": [48, 30], "lives": 3, "bombs": 3, "bomb_every": 2500, "life_every": 50000,
		"goal": "endless", "spawn": "ramp", "rate": [1.8, 0.55, 90.0], "stat": "Best score"},
	"deadline": {"title": "Deadline", "map": [44, 28], "lives": 0, "bombs": 0, "time": 180, "goal": "endless",
		"spawn": "ramp", "rate": [1.2, 0.4, 70.0], "ramp_speed": 1.6, "stat": "Best score (Deadline)"},
	"pacifism": {"title": "Pacifism", "map": [40, 26], "lives": 1, "bombs": 0, "gun": false, "goal": "endless",
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.5, 9],
		"events": [[2.0, 2.4, "cluster", "grunt", 6], [40.0, 9.0, "horde", "grunt", 8]], "stat": "Best score (Pacifism)"},
	"king": {"title": "King", "map": [44, 28], "lives": 3, "bombs": 0, "king": true, "goal": "endless",
		"spawn": "ramp", "rate": [1.5, 0.5, 90.0], "stat": "Best score (King)"},
	"waves": {"title": "Waves", "map": [48, 26], "lives": 1, "bombs": 3, "bomb_every": 5000, "goal": "endless",
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "waves": [6.0, 2.2],
		"events": [[3.0, 4.5, "line", "", 5]], "stat": "Best score (Waves)"},
	"claustro": {"title": "Claustrophobia", "map": [22, 13], "lives": 3, "bombs": 3, "bomb_every": 4000, "goal": "endless",
		"spawn": "ramp", "rate": [1.0, 0.35, 70.0], "stat": "Best score (Claustrophobia)"},
	"bossrush": {"title": "Boss Rush", "map": [44, 28], "lives": 3, "bombs": 3, "bomb_every": 20000, "goal": "boss",
		"spawn": {"grunt": 3, "wanderer": 2, "weaver": 1}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.0, 0, "boss", "queen", 0]], "rush": [["serpent", 0], ["lord", 0], ["titan", 0], ["queen", 1], ["titan", 1]],
		"stat": "Best score (Boss Rush)"},
}

## The campaign. Ids are 1..40; LEVELS[i - 1] is level i.
const LEVELS := [
	# --- World 1: Neon Shallows ---
	{"name": "First Light", "map": [30, 19], "time": 60, "goal": "survive",
		"spawn": {"grunt": 4, "wanderer": 3, "duck": 1}, "rate": [1.6, 0.9, 60.0], "target": 10000},
	{"name": "Wander Lust", "map": [34, 20], "goal": "kills", "n": 80,
		"spawn": {"wanderer": 5, "grunt": 2, "weaver": 1}, "rate": [1.2, 0.7, 60.0],
		"events": [[10.0, 15.0, "ring", "wanderer", 10]], "target": 9700},
	{"name": "Gatekeeper", "map": [34, 22], "goal": "gates", "n": 12,
		"spawn": {"grunt": 4, "wanderer": 2}, "rate": [1.4, 0.8, 60.0], "gates": [3.0, 5], "target": 14000},
	{"name": "Spin Cycle", "map": [36, 22], "time": 75, "goal": "survive",
		"spawn": {"spinner": 3, "weaver": 2, "grunt": 2}, "rate": [1.5, 0.75, 70.0], "target": 180000},
	{"name": "Swarm Season", "map": [40, 24], "time": 75, "goal": "survive",
		"spawn": {"grunt": 3, "wanderer": 2}, "rate": [1.6, 0.9, 70.0],
		"events": [[5.0, 9.0, "horde", "mayfly", 16]], "target": 48000},
	{"name": "Hive Queen", "map": [36, 24], "goal": "boss",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [3.0, 2.2, 60.0],
		"events": [[1.5, 0, "boss", "queen", 0]], "target": 47000},
	# --- World 2: Pink Nebula ---
	{"name": "Peace Talks", "map": [34, 22], "goal": "gates", "n": 20, "gun": false, "bombs": 0,
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.6, 8],
		"events": [[2.0, 2.6, "cluster", "grunt", 5]], "target": 17000},
	{"name": "Rocket Rain", "map": [44, 24], "time": 75, "goal": "survive",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [2.0, 1.2, 60.0],
		"events": [[3.0, 3.5, "line", "", 5], [20.0, 12.0, "wall", "4", 0]], "target": 490000},
	{"name": "Snake Pit", "map": [40, 26], "goal": "kills", "n": 70,
		"spawn": {"snake": 3, "grunt": 3, "duck": 1}, "rate": [1.4, 0.8, 70.0], "target": 22000},
	{"name": "Geom Rush", "map": [40, 26], "goal": "geoms", "n": 200,
		"spawn": {"grunt": 3, "wanderer": 3, "gear": 1, "weaver": 1}, "rate": [1.1, 0.55, 60.0], "target": 67000},
	{"name": "Crown Zones", "map": [40, 26], "time": 80, "goal": "survive", "king": true, "bombs": 0,
		"spawn": {"grunt": 4, "weaver": 2, "spinner": 1}, "rate": [1.3, 0.6, 70.0], "target": 20000},
	{"name": "Serpent King", "map": [40, 26], "goal": "boss",
		"spawn": {"grunt": 2, "duck": 2}, "rate": [3.0, 2.2, 60.0],
		"events": [[1.5, 0, "boss", "serpent", 0]], "target": 100000},
	# --- World 3: Acid Fields ---
	{"name": "Event Horizon", "map": [44, 28], "time": 80, "goal": "survive",
		"spawn": {"grunt": 3, "wanderer": 3, "spinner": 1}, "rate": [1.2, 0.6, 70.0],
		"events": [[4.0, 14.0, "spawn", "well", 2]], "target": 360000},
	{"name": "Mine Field", "map": [44, 28], "goal": "kills", "n": 110,
		"spawn": {"layer": 2, "grunt": 4, "weaver": 1}, "rate": [1.1, 0.55, 70.0], "target": 55000},
	{"name": "Rhino Charge", "map": [44, 26], "time": 75, "goal": "survive",
		"spawn": {"repulsor": 2, "grunt": 3, "wanderer": 2}, "rate": [1.5, 0.8, 70.0], "target": 700000},
	{"name": "Tight Squeeze", "map": [20, 12], "time": 70, "goal": "survive",
		"spawn": {"grunt": 4, "wanderer": 2, "weaver": 2, "spinner": 1}, "rate": [1.0, 0.45, 60.0], "target": 250000},
	{"name": "Saucer Storm", "map": [48, 28], "goal": "kills", "n": 100,
		"spawn": {"grunt": 3, "neutron": 2}, "rate": [1.3, 0.7, 60.0],
		"events": [[4.0, 10.0, "nufo", "", 9], [30.0, 25.0, "ufo", "", 1]], "target": 200000},
	{"name": "Gravity Lord", "map": [44, 28], "goal": "boss",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.5, 0, "boss", "lord", 0]], "target": 340000},
	# --- World 4: Solar Forge ---
	{"name": "Golden Hour", "map": [44, 28], "goal": "gates", "n": 15,
		"spawn": {"grunt": 4, "spinner": 1, "weaver": 1}, "rate": [1.1, 0.6, 60.0], "gates": [3.0, 5],
		"events": [[6.0, 9.0, "golden", "", 1]], "target": 210000},
	{"name": "Full Spectrum", "map": [48, 30], "time": 90, "goal": "survive",
		"spawn": "ramp", "ramp_speed": 1.6, "rate": [1.2, 0.5, 80.0], "target": 3700000},
	{"name": "Wall of Fire", "map": [48, 26], "time": 80, "goal": "survive",
		"spawn": {"grunt": 2}, "rate": [2.5, 1.5, 60.0], "waves": [5.5, 2.5], "target": 1300000},
	{"name": "Pacifist's Path", "map": [44, 28], "goal": "gates", "n": 30, "gun": false, "bombs": 0,
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.3, 9],
		"events": [[2.0, 2.0, "cluster", "grunt", 6], [30.0, 10.0, "horde", "grunt", 8]], "target": 27000},
	{"name": "Proton Storm", "map": [44, 28], "goal": "kills", "n": 150,
		"spawn": {"spinner": 3, "grunt": 3, "weaver": 2}, "rate": [1.0, 0.5, 60.0],
		"events": [[5.0, 12.0, "spawn", "well", 2], [15.0, 15.0, "horde", "proton", 8]], "target": 84000},
	{"name": "Titan", "map": [44, 28], "goal": "boss",
		"spawn": {"grunt": 2, "weaver": 1}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.5, 0, "boss", "titan", 0]], "target": 480000},
	# --- World 5: Void Core ---
	{"name": "Chaos Theory", "map": [52, 32], "time": 100, "goal": "survive",
		"spawn": "ramp", "ramp_speed": 2.2, "rate": [1.0, 0.4, 80.0], "target": 11000000},
	{"name": "King's Gambit", "map": [44, 28], "time": 90, "goal": "survive", "king": true, "bombs": 0,
		"spawn": {"grunt": 3, "repulsor": 1, "weaver": 2, "spinner": 1}, "rate": [1.2, 0.5, 80.0], "target": 160000},
	{"name": "Hornet Nest", "map": [48, 30], "goal": "kills", "n": 200,
		"spawn": {"snake": 2, "gear": 1, "grunt": 3}, "rate": [1.1, 0.5, 70.0],
		"events": [[3.0, 7.0, "horde", "mayfly", 18]], "target": 69000},
	{"name": "Shrinking Room", "map": [18, 11], "time": 80, "goal": "survive",
		"spawn": {"spinner": 2, "weaver": 3, "grunt": 3, "neutron": 1}, "rate": [0.9, 0.4, 70.0], "target": 750000},
	{"name": "Gate Storm", "map": [48, 30], "goal": "gates", "n": 35,
		"spawn": "ramp", "ramp_speed": 1.5, "rate": [1.1, 0.5, 80.0], "gates": [2.0, 7],
		"events": [[10.0, 12.0, "golden", "", 1]], "target": 16000000},
	{"name": "Final Stand", "map": [48, 30], "goal": "boss",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [3.0, 2.2, 60.0],
		"events": [[1.5, 0, "boss", "lord", 0], [2.5, 0, "boss", "titan", 0]], "target": 370000},
	# --- World 6: Ultimate ---
	{"name": "Overdrive", "map": [56, 34], "time": 90, "goal": "survive", "lives": 2,
		"spawn": "ramp", "ramp_speed": 3.0, "rate": [0.8, 0.32, 70.0], "target": 10000000},
	{"name": "Silent Running", "map": [44, 28], "goal": "gates", "n": 40, "gun": false, "bombs": 0, "lives": 1,
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.2, 9],
		"events": [[1.5, 1.6, "cluster", "grunt", 7], [20.0, 8.0, "horde", "grunt", 10]], "target": 140000},
	{"name": "Queen's Fury", "map": [40, 26], "goal": "boss", "lives": 2,
		"spawn": {"grunt": 3, "spinner": 1}, "rate": [2.4, 1.6, 60.0],
		"events": [[1.5, 0, "boss", "queen", 1]], "target": 480000},
	{"name": "Hunters", "map": [48, 30], "goal": "kills", "n": 250, "lives": 2,
		"spawn": {"weaver": 3, "repulsor": 2, "spinner": 3, "grunt": 2}, "rate": [0.9, 0.45, 70.0], "target": 660000},
	{"name": "Serpent's Wrath", "map": [44, 28], "goal": "boss", "lives": 2,
		"spawn": {"grunt": 3, "snake": 1}, "rate": [2.4, 1.6, 60.0],
		"events": [[1.5, 0, "boss", "serpent", 1]], "target": 3700000},
	{"name": "Black Hole Sun", "map": [48, 30], "time": 90, "goal": "survive", "lives": 2,
		"spawn": {"grunt": 3, "spinner": 2, "wanderer": 2}, "rate": [0.9, 0.45, 70.0],
		"events": [[3.0, 9.0, "spawn", "well", 3], [12.0, 12.0, "horde", "proton", 10]], "target": 1500000},
	{"name": "Minefield II", "map": [52, 30], "goal": "kills", "n": 250, "lives": 2,
		"spawn": {"layer": 3, "grunt": 3, "spinner": 1}, "rate": [0.9, 0.45, 70.0],
		"events": [[5.0, 8.0, "nufo", "", 10]], "target": 700000},
	{"name": "Crown of Thorns", "map": [44, 28], "time": 100, "goal": "survive", "king": true, "bombs": 0, "lives": 2,
		"spawn": {"grunt": 3, "weaver": 2, "spinner": 2}, "rate": [1.0, 0.45, 80.0], "waves": [8.0, 4.0], "target": 45000},
	{"name": "Golden Gauntlet", "map": [52, 32], "goal": "gates", "n": 25, "lives": 2,
		"spawn": "ramp", "ramp_speed": 2.5, "rate": [0.9, 0.4, 80.0], "gates": [3.0, 5],
		"events": [[4.0, 5.0, "golden", "", 1]], "target": 7400000},
	{"name": "Twin Terror", "map": [52, 32], "goal": "boss", "lives": 3,
		"spawn": {"grunt": 3, "weaver": 1}, "rate": [2.4, 1.6, 60.0],
		"events": [[1.5, 0, "boss", "titan", 1], [2.5, 0, "boss", "queen", 1]], "target": 6800000},
]

static func count() -> int:
	return LEVELS.size()

## Level `id` (1-based) as a full rule set, with defaults filled in.
static func level(id: int) -> Dictionary:
	var l: Dictionary = (LEVELS[id - 1] as Dictionary).duplicate(true)
	l.id = id
	l.world = world_of(id)
	l.campaign = true
	l.title = l.name
	return _defaults(l, (WORLDS[l.world] as Dictionary).grid)

static func classic(mode: String) -> Dictionary:
	var m: Dictionary = (CLASSIC[mode] as Dictionary).duplicate(true)
	m.mode = mode
	m.campaign = false
	return _defaults(m, (WORLDS[0] as Dictionary).grid)

static func _defaults(r: Dictionary, grid: Color) -> Dictionary:
	var d := {"lives": 3, "bombs": 3, "bomb_every": 0, "life_every": 0, "time": 0, "gun": true, "king": false,
		"gates": [], "waves": [], "events": [], "ramp_speed": 1.0, "n": 0, "target": 0, "grid": grid}
	for k in d:
		if not r.has(k):
			r[k] = d[k]
	var m: Array = r.map
	if int(m[0]) > TINY_MAP:
		r.map = [int(round(float(m[0]) * MAP_SCALE)), int(round(float(m[1]) * MAP_SCALE))]
	return r

## 0-based world index of a level.
static func world_of(id: int) -> int:
	if id >= ULTIMATE_FIRST:
		return 5
	return (id - 1) / LEVELS_PER_WORLD

static func world_levels(w: int) -> Array:
	var out: Array = []
	if w == 5:
		for id in range(ULTIMATE_FIRST, count() + 1):
			out.append(id)
	else:
		for i in LEVELS_PER_WORLD:
			out.append(w * LEVELS_PER_WORLD + i + 1)
	return out

static func is_boss(id: int) -> bool:
	return str((LEVELS[id - 1] as Dictionary).goal) == "boss"

## Stars for a finished level: 1 for finishing, 1 for not losing a life,
## 1 for reaching its score target.
static func stars_for(id: int, score: int, deaths: int) -> int:
	var target := int((LEVELS[id - 1] as Dictionary).target)
	return 1 + (1 if deaths == 0 else 0) + (1 if score >= target else 0)

## What the player has to do, in words (translated).
static func goal_text(r: Dictionary) -> String:
	var tr_ := func(s: String) -> String: return str(TranslationServer.translate(s))
	match str(r.goal):
		"survive":
			return tr_.call("Survive %d seconds") % int(r.time)
		"kills":
			return tr_.call("Destroy %d enemies") % int(r.n)
		"gates":
			return tr_.call("Fly through %d gates") % int(r.n)
		"geoms":
			return tr_.call("Collect %d geoms") % int(r.n)
		"boss":
			var names: PackedStringArray = []
			for ev in r.events:
				if str(ev[2]) == "boss":
					names.append(tr_.call(_boss_name(str(ev[3]))))
			return tr_.call("Defeat %s") % " + ".join(names)
	return tr_.call("Score as much as you can")

static func _boss_name(kind: String) -> String:
	return {"queen": "Hive Queen", "serpent": "Serpent King", "lord": "Gravity Lord", "titan": "Titan"}.get(kind, "Boss")

## Rule notes shown on a level's card ("No gun", "1 life"...), translated.
static func rule_notes(r: Dictionary) -> String:
	var tr_ := func(s: String) -> String: return str(TranslationServer.translate(s))
	var notes: PackedStringArray = []
	if not r.gun:
		notes.append(tr_.call("No gun: fly through gates to blow enemies up"))
	if r.king:
		notes.append(tr_.call("You can only shoot inside a zone"))
	if not (r.waves as Array).is_empty():
		notes.append(tr_.call("Walls of rockets"))
	if int(r.lives) == 1:
		notes.append(tr_.call("1 life"))
	elif int(r.lives) > 1:
		notes.append(tr_.call("%d lives") % int(r.lives))
	if int(r.bombs) == 0:
		notes.append(tr_.call("No bombs"))
	return " · ".join(notes)
