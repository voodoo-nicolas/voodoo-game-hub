extends RefCounted

## Every way to play, as data: the classic modes and the campaign's levels
## share one format, read by geometry_wars_game.gd.
##
##   map     [w, h] in grid squares, before MAP_SCALE (the view shows 19
##           squares top to bottom, so most maps are bigger than the screen
##           and the camera follows; the tiny ones stay tiny)
##   lives   0 = unlimited (Deadline)       bombs   at the start (0 = none)
##   bomb_every / life_every   points to the first extra bomb / life (0 = never);
##                             each later one costs more (game EXTRA_GROWTH)
##   time    seconds on the clock (0 = none). Time Attack ends when it runs
##           out; a campaign "survive" level is cleared then and goes on
##           (overtime) until you run out of lives or tap Finish
##   goal    "endless" (classic) | "survive" | "kills" n | "boss" (Boss Rush)
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
##           (arg = kind, n = its tier: 1 the first boss .. 8 the last; bosses
##           grow bigger and stronger with it, Bosses header)
##   stars   [points for ★★, points for ★★★]: ★ is clearing the level
##   hint    a line shown at the start (the first levels teach the controls)
##   grid    the world's colour
##
## The campaign (owner, 2026-10-07): levels 1 and 2 teach flying, then
## bombs; from level 3 every level is "survive the clock", and the stars are
## points -- the clock running out clears the level, but the swarm keeps
## coming and every point still counts toward ★★ / ★★★. Every sixth level
## has a boss; beating it (not just outlasting it) opens a classic mode
## (MODE_UNLOCK), and the first one also the first familiar.

const WORLDS := [
	{"name": "Neon Shallows", "grid": Color(0.18, 0.4, 0.9)},
	{"name": "Pink Nebula", "grid": Color(0.75, 0.2, 0.75)},
	{"name": "Acid Fields", "grid": Color(0.3, 0.8, 0.25)},
	{"name": "Solar Forge", "grid": Color(0.95, 0.5, 0.15)},
	{"name": "Void Core", "grid": Color(0.5, 0.3, 1.0)},
	{"name": "Underworld", "grid": Color(1.0, 0.2, 0.3)},
]
const LEVELS_PER_WORLD := 6
## Every map but the deliberately tiny ones is this much bigger than written.
const MAP_SCALE := 1.5
const TINY_MAP := 22
## The Underworld is world 6, opened by clearing level 30; it has 10 levels.
const ULTIMATE_FIRST := 31

## The classic modes and the campaign level whose boss opens each one
## (owner, 2026-10-07: only Endless and the Campaign at first; beating a
## boss unlocks a mode). Endless is always open.
const MODE_UNLOCK := {"deadline": 6, "pacifism": 12, "waves": 18, "king": 24, "claustro": 30, "bossrush": 40}
const MODE_ORDER := ["deadline", "pacifism", "waves", "king", "claustro", "bossrush"]
const MODE_ICONS := {"evolved": "💀", "deadline": "⏱", "pacifism": "✋", "king": "🕯", "waves": "🐃", "claustro": "⚰", "bossrush": "☠"}

const CLASSIC := {
	"evolved": {"title": "Endless", "map": [48, 30], "lives": 3, "bombs": 3, "bomb_every": 20000, "life_every": 100000,
		"goal": "endless", "spawn": "ramp", "rate": [1.8, 0.55, 90.0], "stat": "Best score"},
	"deadline": {"title": "Time Attack", "map": [44, 28], "lives": 0, "bombs": 0, "time": 180, "goal": "endless",
		"spawn": "ramp", "rate": [1.2, 0.4, 70.0], "ramp_speed": 1.6, "stat": "Best score (Time Attack)"},
	"pacifism": {"title": "Unarmed", "map": [40, 26], "lives": 1, "bombs": 0, "gun": false, "goal": "endless",
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.5, 9],
		"events": [[2.0, 2.4, "cluster", "grunt", 6], [40.0, 9.0, "horde", "grunt", 8]], "stat": "Best score (Unarmed)"},
	"king": {"title": "Sanctuary", "map": [44, 28], "lives": 3, "bombs": 0, "king": true, "goal": "endless",
		"spawn": "ramp", "rate": [1.5, 0.5, 90.0], "stat": "Best score (Sanctuary)"},
	"waves": {"title": "Stampede", "map": [48, 26], "lives": 1, "bombs": 3, "bomb_every": 15000, "goal": "endless",
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "waves": [6.0, 2.2],
		"events": [[3.0, 4.5, "line", "", 5]], "stat": "Best score (Stampede)"},
	"claustro": {"title": "Coffin", "map": [22, 13], "lives": 3, "bombs": 3, "bomb_every": 15000, "goal": "endless",
		"spawn": "ramp", "rate": [1.0, 0.35, 70.0], "stat": "Best score (Coffin)"},
	# One boss after another, each a tier bigger (the Gravity Lord, the
	# hardest for the owner, comes late).
	"bossrush": {"title": "Boss Rush", "map": [44, 28], "lives": 3, "bombs": 3, "bomb_every": 40000, "goal": "boss",
		"spawn": {"grunt": 3, "wanderer": 2, "weaver": 1}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.0, 0, "boss", "queen", 1]],
		"rush": [["serpent", 2], ["scorpion", 3], ["titan", 4], ["watcher", 5], ["warden", 6], ["lord", 7]],
		"stat": "Best score (Boss Rush)"},
}

## The campaign. Ids are 1..40; LEVELS[i - 1] is level i.
const LEVELS := [
	# --- World 1: Neon Shallows ---
	{"name": "First Light", "map": [30, 19], "goal": "kills", "n": 30, "bombs": 0,
		"spawn": {"grunt": 3, "wanderer": 4}, "rate": [1.7, 1.1, 60.0], "stars": [1200, 2200],
		"hint": "Left stick: fly · Right stick: aim and fire"},
	{"name": "First Blast", "map": [32, 20], "goal": "kills", "n": 60,
		"spawn": {"grunt": 4, "wanderer": 2, "duck": 2}, "rate": [1.4, 0.9, 60.0],
		"events": [[9.0, 14.0, "ring", "grunt", 10]], "stars": [9000, 15000],
		"hint": "💣 Surrounded? Tap the red bar: a bomb clears the screen"},
	{"name": "Wander Lust", "map": [34, 20], "time": 60, "goal": "survive",
		"spawn": {"wanderer": 5, "grunt": 2, "weaver": 1}, "rate": [1.2, 0.7, 60.0],
		"events": [[10.0, 15.0, "ring", "wanderer", 10]], "stars": [34000, 140000],
		"hint": "When the clock runs out, keep going: every point counts for the stars"},
	{"name": "Seal Keeper", "map": [34, 22], "time": 70, "goal": "survive",
		"spawn": {"grunt": 4, "wanderer": 2}, "rate": [1.4, 0.8, 60.0], "gates": [3.0, 5], "stars": [65000, 270000],
		"hint": "Fly through the middle of a seal to blow up everything near it"},
	{"name": "Spin Cycle", "map": [36, 22], "time": 75, "goal": "survive",
		"spawn": {"spinner": 3, "weaver": 2, "grunt": 2}, "rate": [1.5, 0.75, 70.0],
		"events": [[20.0, 16.0, "horde", "mayfly", 14]], "stars": [280000, 1100000]},
	{"name": "Hive Queen", "map": [36, 24], "time": 90, "goal": "survive",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [3.0, 2.2, 60.0],
		"events": [[1.5, 0, "boss", "queen", 1]], "stars": [280000, 1200000]},
	# --- World 2: Pink Nebula ---
	{"name": "Peace Talks", "map": [34, 22], "time": 60, "goal": "survive", "gun": false, "bombs": 0,
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.6, 8],
		"events": [[2.0, 2.6, "cluster", "grunt", 5]], "stars": [13000, 54000]},
	{"name": "Rocket Rain", "map": [44, 24], "time": 75, "goal": "survive",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [2.0, 1.2, 60.0],
		"events": [[3.0, 3.5, "line", "", 5], [20.0, 12.0, "wall", "4", 0]], "stars": [580000, 2400000]},
	{"name": "Snake Pit", "map": [40, 26], "time": 75, "goal": "survive",
		"spawn": {"snake": 3, "grunt": 3, "duck": 1}, "rate": [1.4, 0.8, 70.0], "stars": [150000, 630000]},
	{"name": "Soul Rush", "map": [40, 26], "time": 80, "goal": "survive",
		"spawn": {"grunt": 3, "wanderer": 3, "gear": 1, "weaver": 1}, "rate": [1.1, 0.55, 60.0], "stars": [95000, 400000]},
	{"name": "Holy Ground", "map": [40, 26], "time": 80, "goal": "survive", "king": true, "bombs": 0,
		"spawn": {"grunt": 4, "weaver": 2, "spinner": 1}, "rate": [1.3, 0.6, 70.0], "stars": [15000, 50000]},
	{"name": "Serpent King", "map": [40, 26], "time": 100, "goal": "survive",
		"spawn": {"grunt": 2, "duck": 2}, "rate": [3.0, 2.2, 60.0],
		"events": [[1.5, 0, "boss", "serpent", 2]], "stars": [300000, 1200000]},
	# --- World 3: Acid Fields ---
	{"name": "Event Horizon", "map": [44, 28], "time": 80, "goal": "survive",
		"spawn": {"grunt": 3, "wanderer": 3, "spinner": 1}, "rate": [1.2, 0.6, 70.0],
		"events": [[4.0, 14.0, "spawn", "well", 2]], "stars": [410000, 1700000]},
	{"name": "Mine Field", "map": [44, 28], "time": 80, "goal": "survive",
		"spawn": {"layer": 2, "grunt": 4, "weaver": 1}, "rate": [1.1, 0.55, 70.0], "stars": [160000, 670000]},
	{"name": "Rhino Charge", "map": [44, 26], "time": 75, "goal": "survive",
		"spawn": {"repulsor": 2, "grunt": 3, "wanderer": 2}, "rate": [1.5, 0.8, 70.0], "stars": [430000, 1800000]},
	{"name": "Tight Squeeze", "map": [20, 12], "time": 70, "goal": "survive",
		"spawn": {"grunt": 4, "wanderer": 2, "weaver": 2, "spinner": 1}, "rate": [1.0, 0.45, 60.0], "stars": [400000, 1700000]},
	{"name": "Saucer Storm", "map": [48, 28], "time": 85, "goal": "survive",
		"spawn": {"grunt": 3, "neutron": 2}, "rate": [1.3, 0.7, 60.0],
		"events": [[4.0, 10.0, "nufo", "", 9], [30.0, 25.0, "ufo", "", 1]], "stars": [810000, 3400000]},
	{"name": "Bone Scorpion", "map": [44, 28], "time": 100, "goal": "survive",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.5, 0, "boss", "scorpion", 3]], "stars": [1200000, 4800000],
		"hint": "Break both claws, then hit the stinger while the tail whips; the head last"},
	# --- World 4: Solar Forge ---
	{"name": "Golden Hour", "map": [44, 28], "time": 85, "goal": "survive",
		"spawn": {"grunt": 4, "spinner": 1, "weaver": 1}, "rate": [1.1, 0.6, 60.0], "gates": [3.0, 5],
		"events": [[6.0, 9.0, "golden", "", 1]], "stars": [560000, 2300000]},
	{"name": "Full Spectrum", "map": [48, 30], "time": 90, "goal": "survive",
		"spawn": "ramp", "ramp_speed": 1.6, "rate": [1.2, 0.5, 80.0], "stars": [1100000, 4600000]},
	{"name": "Wall of Fire", "map": [48, 26], "time": 80, "goal": "survive",
		"spawn": {"grunt": 2}, "rate": [2.5, 1.5, 60.0], "waves": [5.5, 2.5], "stars": [1400000, 5900000]},
	{"name": "Empty Hands", "map": [44, 28], "time": 80, "goal": "survive", "gun": false, "bombs": 0,
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.3, 9],
		"events": [[2.0, 2.0, "cluster", "grunt", 6], [30.0, 10.0, "horde", "grunt", 8]], "stars": [25000, 100000]},
	{"name": "Proton Storm", "map": [44, 28], "time": 90, "goal": "survive",
		"spawn": {"spinner": 3, "grunt": 3, "weaver": 2}, "rate": [1.0, 0.5, 60.0],
		"events": [[5.0, 12.0, "spawn", "well", 2], [15.0, 15.0, "horde", "proton", 8]], "stars": [1800000, 7600000]},
	{"name": "The Watcher", "map": [44, 28], "time": 110, "goal": "survive",
		"spawn": {"grunt": 2, "weaver": 1}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.5, 0, "boss", "watcher", 4]], "stars": [620000, 2600000],
		"hint": "The Watcher's beam can't pass the tombstones: hide behind one"},
	# --- World 5: Void Core ---
	{"name": "Chaos Theory", "map": [52, 32], "time": 100, "goal": "survive",
		"spawn": "ramp", "ramp_speed": 2.2, "rate": [1.0, 0.4, 80.0], "stars": [6300000, 26000000]},
	{"name": "Last Rites", "map": [44, 28], "time": 90, "goal": "survive", "king": true, "bombs": 0,
		"spawn": {"grunt": 3, "repulsor": 1, "weaver": 2, "spinner": 1}, "rate": [1.2, 0.5, 80.0], "stars": [120000, 400000]},
	{"name": "Hornet Nest", "map": [48, 30], "time": 90, "goal": "survive",
		"spawn": {"snake": 2, "gear": 1, "grunt": 3}, "rate": [1.1, 0.5, 70.0],
		"events": [[3.0, 7.0, "horde", "mayfly", 18]], "stars": [720000, 3000000]},
	{"name": "Shrinking Room", "map": [18, 11], "time": 80, "goal": "survive",
		"spawn": {"spinner": 2, "weaver": 3, "grunt": 3, "neutron": 1}, "rate": [0.9, 0.4, 70.0], "stars": [1400000, 6000000]},
	{"name": "Seal Storm", "map": [48, 30], "time": 95, "goal": "survive",
		"spawn": "ramp", "ramp_speed": 1.5, "rate": [1.1, 0.5, 80.0], "gates": [2.0, 7],
		"events": [[10.0, 12.0, "golden", "", 1]], "stars": [5100000, 21000000]},
	{"name": "The Warden", "map": [48, 30], "time": 120, "goal": "survive",
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [3.0, 2.2, 60.0],
		"events": [[1.5, 0, "boss", "warden", 5]], "stars": [1000000, 4000000],
		"hint": "Break the four crystals in the corners to drop the Warden's shield"},
	# --- World 6: Underworld ---
	{"name": "Overdrive", "map": [56, 34], "time": 90, "goal": "survive", "lives": 2,
		"spawn": "ramp", "ramp_speed": 3.0, "rate": [0.8, 0.32, 70.0], "stars": [7200000, 30000000]},
	{"name": "Silent Running", "map": [44, 28], "time": 70, "goal": "survive", "gun": false, "bombs": 0, "lives": 3,
		"spawn": {}, "rate": [99.0, 99.0, 1.0], "gates": [1.2, 9],
		"events": [[1.5, 2.0, "cluster", "grunt", 6], [20.0, 10.0, "horde", "grunt", 8]], "stars": [35000, 150000]},
	{"name": "Titan", "map": [44, 28], "time": 110, "goal": "survive", "lives": 3,
		"spawn": {"grunt": 2, "weaver": 1}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.5, 0, "boss", "titan", 6]], "stars": [400000, 1700000]},
	{"name": "Hunters", "map": [48, 30], "time": 90, "goal": "survive", "lives": 2,
		"spawn": {"weaver": 3, "repulsor": 2, "spinner": 3, "grunt": 2}, "rate": [1.0, 0.55, 70.0], "stars": [4500000, 19000000]},
	{"name": "Gravity Lord", "map": [44, 28], "time": 110, "goal": "survive", "lives": 3,
		"spawn": {"grunt": 2, "wanderer": 2}, "rate": [3.0, 2.0, 60.0],
		"events": [[1.5, 0, "boss", "lord", 7]], "stars": [960000, 4000000]},
	{"name": "Black Hole Sun", "map": [48, 30], "time": 90, "goal": "survive", "lives": 2,
		"spawn": {"grunt": 3, "spinner": 2, "wanderer": 2}, "rate": [0.9, 0.45, 70.0],
		"events": [[3.0, 9.0, "spawn", "well", 3], [12.0, 12.0, "horde", "proton", 10]], "stars": [2500000, 10000000]},
	{"name": "Minefield II", "map": [52, 30], "time": 100, "goal": "survive", "lives": 2,
		"spawn": {"layer": 3, "grunt": 3, "spinner": 1}, "rate": [0.9, 0.45, 70.0],
		"events": [[5.0, 8.0, "nufo", "", 10]], "stars": [3100000, 13000000]},
	{"name": "Crown of Thorns", "map": [44, 28], "time": 100, "goal": "survive", "king": true, "bombs": 0, "lives": 2,
		"spawn": {"grunt": 3, "weaver": 2, "spinner": 2}, "rate": [1.0, 0.45, 80.0], "waves": [8.0, 4.0], "stars": [35000, 110000]},
	{"name": "Golden Gauntlet", "map": [52, 32], "time": 100, "goal": "survive", "lives": 2,
		"spawn": "ramp", "ramp_speed": 2.5, "rate": [0.9, 0.4, 80.0], "gates": [3.0, 5],
		"events": [[4.0, 5.0, "golden", "", 1]], "stars": [7400000, 31000000]},
	{"name": "Twin Terror", "map": [52, 32], "time": 130, "goal": "survive", "lives": 3,
		"spawn": {}, "rate": [99.0, 99.0, 1.0],
		"events": [[1.5, 0, "boss", "watcher", 8], [25.0, 0, "boss", "warden", 8]], "stars": [600000, 2500000]},
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
		"gates": [], "waves": [], "events": [], "ramp_speed": 1.0, "n": 0, "stars": [0, 0], "hint": "", "grid": grid}
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

## The bosses a level brings, as [[kind, tier]...] (empty: no boss).
static func bosses_of(id: int) -> Array:
	var out: Array = []
	for ev in (LEVELS[id - 1] as Dictionary).get("events", []):
		if str(ev[2]) == "boss":
			out.append([str(ev[3]), maxi(1, int(ev[4]))])
	return out

static func is_boss(id: int) -> bool:
	return not bosses_of(id).is_empty()

## The first level with a boss (beating it brings the first familiar).
static func first_boss() -> int:
	for id in range(1, count() + 1):
		if is_boss(id):
			return id
	return 0

## The classic modes a boss level's victory opens.
static func modes_opened_by(id: int) -> Array:
	var out: Array = []
	for m in MODE_ORDER:
		if int(MODE_UNLOCK[m]) == id:
			out.append(m)
	return out

## Stars for a cleared level: 1 for clearing it, 1 more at each of its two
## point targets.
static func stars_for(id: int, score: int) -> int:
	var st: Array = (LEVELS[id - 1] as Dictionary).get("stars", [0, 0])
	return 1 + (1 if score >= int(st[0]) else 0) + (1 if score >= int(st[1]) else 0)

## The points the next star needs (0 = every star is in).
static func next_star_at(id: int, score: int) -> int:
	var st: Array = (LEVELS[id - 1] as Dictionary).get("stars", [0, 0])
	for s in st:
		if score < int(s):
			return int(s)
	return 0

## What the player has to do, in words (translated).
static func goal_text(r: Dictionary) -> String:
	var tr_ := func(s: String) -> String: return str(TranslationServer.translate(s))
	match str(r.goal):
		"survive":
			var g: String = tr_.call("Survive %d seconds") % int(r.time)
			var names: PackedStringArray = []
			for ev in r.events:
				if str(ev[2]) == "boss":
					names.append(tr_.call(boss_name(str(ev[3]))))
			if not names.is_empty():
				g += " · " + tr_.call("%s is here") % " + ".join(names)
			return g
		"kills":
			return tr_.call("Destroy %d enemies") % int(r.n)
		"boss":
			return tr_.call("Defeat every boss")
	return tr_.call("Score as much as you can")

static func boss_name(kind: String) -> String:
	return {"queen": "Hive Queen", "serpent": "Serpent King", "scorpion": "Bone Scorpion", "lord": "Gravity Lord",
		"titan": "Titan", "watcher": "Watcher", "warden": "Warden"}.get(kind, "Boss")

## Rule notes shown on a level's card ("No gun", "1 life"...), translated.
static func rule_notes(r: Dictionary) -> String:
	var tr_ := func(s: String) -> String: return str(TranslationServer.translate(s))
	var notes: PackedStringArray = []
	if not r.gun:
		notes.append(tr_.call("No pins: fly through seals to blow enemies up"))
	if r.king:
		notes.append(tr_.call("You can only shoot inside a sacred circle"))
	if not (r.waves as Array).is_empty():
		notes.append(tr_.call("Walls of darts"))
	if int(r.lives) == 1:
		notes.append(tr_.call("1 life"))
	elif int(r.lives) > 1:
		notes.append(tr_.call("%d lives") % int(r.lives))
	if int(r.bombs) == 0:
		notes.append(tr_.call("No bombs"))
	return " · ".join(notes)
