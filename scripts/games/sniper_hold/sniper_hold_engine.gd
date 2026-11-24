extends RefCounted

## The Hunt (id sniper_hold) -- pure logic, no Nodes (headless-testable: tools/test_sniper_hold.gd).
##
## The world is one fixed valley, W x H world units (16:9). Depth is in metres: an animal at
## distance d stands on the ground line ground_y(d) and is drawn PX_M / d world units per metre.
## That makes 1 mil (1 m at 1000 m) exactly PX_M / 1000 world units at every distance, so the
## scope's mil-dots are real: a hold of 2 dots is 2 m at 1000 m, 1 m at 500 m.
##
## Sway: the aim wanders on a slow Lissajous curve whose size follows the breath cycle
## (inhale -> exhale -> a short natural pause where it is calm). Holding the breath calms it
## to a tenth for a few seconds; then the lungs give out, the sway grows and you must breathe.
## Every heartbeat gives a small kick. The game draws the view at aim = camera + sway().
##
## Ballistics (Normal, Hard): the rifle is zeroed at ZERO_M. A bullet flies at MUZZLE m/s, so
## far shots land low (drop) and drift with the wind; the animal keeps moving while the bullet
## flies (lead it). Easy: no drop, no wind. Shots resolve when the bullet arrives.

const W := 1600.0
const H := 900.0
const HORIZON := 470.0
const K_GROUND := 31200.0       # ground_y(d) = HORIZON + K_GROUND / d
const PX_M := 6000.0            # world units per metre at 1 m (scale(d) = PX_M / d)
const MIL := PX_M / 1000.0      # 1 mil in world units, at any distance
const MUZZLE := 850.0           # m/s
const GRAVITY := 9.81
const ZERO_M := 200.0
const D_MIN := 70.0
const D_MAX := 660.0
const BOLT_TIME := 1.1          # seconds to work the bolt after a shot
const WIND_K := 0.35            # drift (m) = wind (m/s) * flight time^2 * WIND_K (a game simplification)

const DIFFS := ["Easy", "Normal", "Hard"]
const SWAY_AMP := [3.6, 5.2, 7.0]        # world units (MIL = 6)
const HOLD_MAX := [5.0, 4.0, 3.0]        # seconds of held breath
const DIFF_MULT := [1.0, 1.5, 2.0]       # Open Season score multiplier
const ENVS := ["dawn", "noon", "autumn", "dusk", "winter"]

## Animal kinds: size in metres, speeds (m/s), points. "legal": false = protected everywhere.
const KINDS := {
	"buck": {"len": 1.6, "h": 1.0, "walk": 1.1, "run": 11.0, "pts": 150, "legal": true},
	"doe": {"len": 1.45, "h": 0.92, "walk": 1.0, "run": 10.5, "pts": 100, "legal": true},
	"fawn": {"len": 0.95, "h": 0.62, "walk": 1.0, "run": 9.0, "pts": -200, "legal": false},
	"boar": {"len": 1.4, "h": 0.85, "walk": 0.9, "run": 8.0, "pts": 140, "legal": true},
	"fox": {"len": 0.75, "h": 0.4, "walk": 1.3, "run": 9.5, "pts": 90, "legal": true},
	"hare": {"len": 0.55, "h": 0.32, "walk": 0.0, "run": 8.5, "pts": 70, "legal": true},
}
const KIND_NAMES := {"buck": "Stag", "doe": "Doe", "fawn": "Fawn", "boar": "Boar", "fox": "Fox", "hare": "Hare"}

## Contracts (Campaign): env, targets {kind: n}, forbidden kinds, rounds, seconds, d range, max wind m/s,
## difficulty used for sway/ballistics.
const CONTRACTS := [
	{"env": "dawn", "take": {"hare": 1}, "forbid": [], "rounds": 5, "time": 120, "d": [80, 180], "wind": 0, "diff": 0},
	{"env": "noon", "take": {"fox": 1}, "forbid": [], "rounds": 5, "time": 120, "d": [90, 220], "wind": 1, "diff": 0},
	{"env": "autumn", "take": {"doe": 1}, "forbid": ["fawn"], "rounds": 5, "time": 120, "d": [100, 240], "wind": 1, "diff": 0},
	{"env": "dusk", "take": {"boar": 1}, "forbid": [], "rounds": 5, "time": 120, "d": [100, 250], "wind": 2, "diff": 1},
	{"env": "winter", "take": {"hare": 2}, "forbid": [], "rounds": 6, "time": 140, "d": [100, 260], "wind": 2, "diff": 1},
	{"env": "dawn", "take": {"buck": 1}, "forbid": ["doe", "fawn"], "rounds": 5, "time": 150, "d": [140, 300], "wind": 2, "diff": 1},
	{"env": "noon", "take": {"fox": 2}, "forbid": ["hare"], "rounds": 6, "time": 150, "d": [120, 320], "wind": 3, "diff": 1},
	{"env": "autumn", "take": {"boar": 2}, "forbid": ["fawn"], "rounds": 6, "time": 150, "d": [150, 340], "wind": 3, "diff": 1},
	{"env": "dusk", "take": {"doe": 2}, "forbid": ["buck", "fawn"], "rounds": 6, "time": 150, "d": [160, 360], "wind": 3, "diff": 1},
	{"env": "winter", "take": {"buck": 1, "boar": 1}, "forbid": ["fawn"], "rounds": 6, "time": 160, "d": [180, 380], "wind": 4, "diff": 1},
	{"env": "dawn", "take": {"hare": 3}, "forbid": ["fox"], "rounds": 7, "time": 160, "d": [150, 380], "wind": 4, "diff": 1},
	{"env": "noon", "take": {"buck": 2}, "forbid": ["doe", "fawn"], "rounds": 6, "time": 170, "d": [200, 420], "wind": 4, "diff": 1},
	{"env": "autumn", "take": {"fox": 1, "hare": 1, "boar": 1}, "forbid": ["fawn"], "rounds": 7, "time": 180, "d": [180, 420], "wind": 5, "diff": 2},
	{"env": "dusk", "take": {"boar": 2}, "forbid": ["doe", "fawn"], "rounds": 5, "time": 170, "d": [220, 460], "wind": 5, "diff": 2},
	{"env": "winter", "take": {"doe": 2}, "forbid": ["buck", "fawn"], "rounds": 5, "time": 170, "d": [240, 480], "wind": 5, "diff": 2},
	{"env": "dawn", "take": {"fox": 2}, "forbid": ["hare"], "rounds": 5, "time": 170, "d": [250, 500], "wind": 6, "diff": 2},
	{"env": "noon", "take": {"buck": 1}, "forbid": ["doe", "fawn"], "rounds": 3, "time": 150, "d": [350, 540], "wind": 6, "diff": 2},
	{"env": "autumn", "take": {"hare": 2}, "forbid": ["fox"], "rounds": 4, "time": 170, "d": [280, 520], "wind": 6, "diff": 2},
	{"env": "dusk", "take": {"buck": 1, "doe": 1}, "forbid": ["fawn"], "rounds": 4, "time": 170, "d": [300, 560], "wind": 7, "diff": 2},
	{"env": "winter", "take": {"boar": 3}, "forbid": ["fawn"], "rounds": 5, "time": 190, "d": [300, 580], "wind": 7, "diff": 2},
	{"env": "dawn", "take": {"fox": 1, "boar": 1}, "forbid": ["doe", "fawn"], "rounds": 3, "time": 170, "d": [380, 600], "wind": 7, "diff": 2},
	{"env": "noon", "take": {"hare": 1}, "forbid": ["fox"], "rounds": 2, "time": 150, "d": [450, 620], "wind": 8, "diff": 2},
	{"env": "autumn", "take": {"buck": 2}, "forbid": ["doe", "fawn"], "rounds": 3, "time": 200, "d": [420, 640], "wind": 8, "diff": 2},
	{"env": "dusk", "take": {"buck": 1, "boar": 1, "fox": 1}, "forbid": ["doe", "fawn", "hare"], "rounds": 4, "time": 220, "d": [420, 650], "wind": 9, "diff": 2},
]

var rng := RandomNumberGenerator.new()
var mode := "season"            # "season" (Open Season), "contract", "practice"
var diff := 1
var level := 0                  # contract index
var env := "dawn"
var d_range := [D_MIN, 420.0]
var wind_max := 4.0
var seed_used := 1

var t := 0.0
var time_left := 180.0
var rounds := 10
var score := 0
var shots := 0
var hits := 0
var clean := 0                  # vital-zone takes
var misses := 0
var longest := 0.0
var taken := {}                 # kind -> n
var strikes := 0                # protected / forbidden animals hit (contract: 1 = failed)
var over := false
var won := false
var end_reason := ""            # "done", "time", "ammo", "forbidden"

var wind := 0.0                 # m/s, + = blowing to the right
var _wind_target := 0.0
var _wind_t := 0.0

var holding := false
var lungs := 1.0                # 1 = full breath available to hold
var gasp := 0.0                 # > 0: out of breath, can't hold
var held := 0.0                 # seconds of the current hold
var heart_rate := 70.0
var _heart_phase := 0.0
var bolt := 0.0                 # > 0: working the bolt

var animals: Array = []         # dicts, see _spawn()
var cover: Array = []           # [x, d, half width m, height m]: bushes, rocks, logs, trunks (set by the game)
var bullets: Array = []         # {"aim": [x, y], "t": arrival time, "d": metres}
var _next_id := 1
var _spawn_t := 0.0

# ---------------------------------------------------------------- setup

func reset(p_mode: String, p_diff: int, p_level: int, p_seed: int) -> void:
	seed_used = p_seed
	rng.seed = p_seed
	mode = p_mode
	level = clampi(p_level, 0, CONTRACTS.size() - 1)
	t = 0.0
	score = 0
	shots = 0
	hits = 0
	clean = 0
	misses = 0
	longest = 0.0
	taken = {}
	strikes = 0
	over = false
	won = false
	end_reason = ""
	holding = false
	lungs = 1.0
	gasp = 0.0
	held = 0.0
	heart_rate = 70.0
	_heart_phase = 0.0
	bolt = 0.0
	animals = []
	bullets = []
	_next_id = 1
	_spawn_t = 3.0
	_wind_t = 0.0
	if mode == "contract":
		var c: Dictionary = CONTRACTS[level]
		diff = int(c.diff)
		env = str(c.env)
		rounds = int(c.rounds)
		time_left = float(c.time)
		d_range = [float(c.d[0]), float(c.d[1])]
		wind_max = float(c.wind)
	else:
		diff = clampi(p_diff, 0, 2)
		env = ENVS[rng.randi() % ENVS.size()]
		rounds = 10 if mode == "season" else 999
		time_left = 180.0 if mode == "season" else 0.0
		d_range = [D_MIN, [300.0, 460.0, 620.0][diff]]
		wind_max = [0.0, 4.0, 8.0][diff]
	if diff == 0:
		wind_max = 0.0
	wind = rng.randf_range(-wind_max, wind_max)
	_wind_target = wind
	# A few animals already in the meadow, more walk in later.
	for i in 4:
		_spawn(true)
	_ensure_targets()

## Contract helpers.
func targets() -> Dictionary:
	if mode == "contract":
		return CONTRACTS[level].take
	return {}

func forbidden() -> Array:
	if mode == "contract":
		return CONTRACTS[level].forbid
	return ["fawn"]

func remaining(kind: String) -> int:
	return maxi(0, int(targets().get(kind, 0)) - int(taken.get(kind, 0)))

func is_target(kind: String) -> bool:
	if mode == "contract":
		return remaining(kind) > 0
	return bool(KINDS[kind].legal)

# ---------------------------------------------------------------- geometry

static func ground_y(d: float) -> float:
	return HORIZON + K_GROUND / d

## Distance (m) of the ground seen at world height y; INF above the far edge of the meadow.
static func dist_at_y(y: float) -> float:
	if y <= HORIZON + K_GROUND / D_MAX * 0.6:
		return INF
	return K_GROUND / (y - HORIZON)

static func scale_at(d: float) -> float:
	return PX_M / d

## Seconds the bullet takes to reach d metres.
static func flight(d: float) -> float:
	return d / MUZZLE

## How far below the crosshair (metres) the bullet is at d, rifle zeroed at ZERO_M.
func drop_m(d: float) -> float:
	if diff == 0:
		return 0.0
	var tf := flight(d)
	var tz := flight(ZERO_M)
	return 0.5 * GRAVITY * tf * tf - 0.5 * GRAVITY * tz * tz * d / ZERO_M

## Sideways drift (metres) at d: + = to the right.
func drift_m(d: float) -> float:
	if diff == 0:
		return 0.0
	var tf := flight(d)
	return wind * tf * tf * WIND_K

## Holdover in mils: x + = aim right (into a wind from the right), y + = aim higher.
func hold_mils(d: float) -> Vector2:
	return Vector2(-drift_m(d), drop_m(d)) / d * 1000.0

# ---------------------------------------------------------------- breath & sway

## 0..1 through a 4.6 s breath: inhale 0-0.4, exhale 0.4-0.8, natural pause 0.8-1.
func breath_phase() -> float:
	return fposmod(t / 4.6, 1.0)

## How much the aim moves right now (1 = normal).
func sway_level() -> float:
	if gasp > 0.0:
		return 1.9
	if holding:
		var k := held / float(HOLD_MAX[diff])
		return lerpf(0.1, 0.25, k * k)
	if breath_phase() >= 0.8:
		return 0.38
	return 1.0

## The aim's offset from the camera centre, in world units.
func sway() -> Vector2:
	var a := float(SWAY_AMP[diff]) * sway_level()
	var s := Vector2(
		sin(t * 1.13) + 0.55 * sin(t * 2.31 + 1.0) + 0.25 * sin(t * 4.7 + 2.0),
		0.75 * sin(t * 1.71 + 0.5) + 0.4 * sin(t * 3.07) + 0.2 * sin(t * 5.3 + 1.3)) * a * 0.55
	# Breathing lifts the rifle as the chest rises and lowers it as it falls.
	if not holding and gasp <= 0.0:
		var p := breath_phase()
		var lift := 0.0
		if p < 0.4:
			lift = -sin(p / 0.4 * PI * 0.5)
		elif p < 0.8:
			lift = -cos((p - 0.4) / 0.4 * PI * 0.5)
		s.y += lift * a * 0.9
	# Heartbeat: a short upward kick.
	var hb := fposmod(_heart_phase, 1.0)
	if hb < 0.12:
		s.y -= sin(hb / 0.12 * PI) * a * (0.12 if holding else 0.2)
	return s

func set_hold(on: bool) -> void:
	if on and (gasp > 0.0 or lungs < 0.15 or over):
		on = false
	if on and not holding:
		held = 0.0
	holding = on

func can_fire() -> bool:
	return not over and bolt <= 0.0 and rounds > 0

# ---------------------------------------------------------------- loop

## Advances the world; returns events: {"type": "hit"|"miss"|"over", ...}.
func step(dt: float) -> Array:
	var ev: Array = []
	if dt <= 0.0:
		return ev
	t += dt
	_heart_phase += dt * heart_rate / 60.0
	if bolt > 0.0:
		bolt = maxf(0.0, bolt - dt)
	# Breath.
	if holding:
		held += dt
		lungs = maxf(0.0, lungs - dt / float(HOLD_MAX[diff]))
		heart_rate = minf(110.0, heart_rate + dt * 6.0)
		if lungs <= 0.0:
			holding = false
			gasp = 1.6
	else:
		if gasp > 0.0:
			gasp = maxf(0.0, gasp - dt)
		lungs = minf(1.0, lungs + dt / 3.0)
		heart_rate = maxf(70.0, heart_rate - dt * 4.0)
	# The wind changes now and then.
	_wind_t -= dt
	if _wind_t <= 0.0:
		_wind_t = rng.randf_range(6.0, 14.0)
		_wind_target = clampf(wind + rng.randf_range(-wind_max, wind_max) * 0.6, -wind_max, wind_max)
	wind = move_toward(wind, _wind_target, dt * 0.4)
	# Bullets arrive.
	for b in bullets.duplicate():
		if t >= float(b.t):
			bullets.erase(b)
			ev.append(_resolve(b))
	_step_animals(dt)
	# Spawning keeps the meadow alive.
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = rng.randf_range(4.0, 8.0)
		if _alive_count() < 6:
			_spawn(false)
	_ensure_targets()
	# Clock and rounds.
	if not over and mode != "practice":
		if time_left > 0.0:
			time_left = maxf(0.0, time_left - dt)
		if time_left <= 0.0 and bullets.is_empty():
			_finish("time", ev)
		elif rounds <= 0 and bullets.is_empty():
			_finish("ammo", ev)
	return ev

func _alive_count() -> int:
	var n := 0
	for a in animals:
		if a.state != "down":
			n += 1
	return n

## Contracts: every still-needed kind has at least one live animal in the meadow.
func _ensure_targets() -> void:
	if mode != "contract" or over:
		return
	for k in targets():
		if remaining(k) <= 0:
			continue
		var have := false
		for a in animals:
			if a.kind == k and a.state != "down" and a.state != "flee":
				have = true
		if not have:
			_spawn(false, k)

func _pick_kind() -> String:
	var pool: Array = ["buck", "doe", "doe", "boar", "fox", "hare", "hare"]
	if mode == "contract":
		for k in targets():
			if remaining(k) > 0:
				pool.append(k)
				pool.append(k)
		for k in forbidden():
			if k != "fawn":
				pool.append(k)
	return pool[rng.randi() % pool.size()]

## A new animal. `inside` = already in the meadow (start of a hunt), else it walks in from a side.
func _spawn(inside: bool, kind: String = "") -> void:
	if kind == "":
		kind = _pick_kind()
	var d := rng.randf_range(float(d_range[0]), float(d_range[1]))
	var dir := 1 if rng.randf() < 0.5 else -1
	var s := scale_at(d)
	var x := rng.randf_range(W * 0.12, W * 0.88) if inside else (-40.0 - s * 1.2 if dir > 0 else W + 40.0 + s * 1.2)
	var a := {
		"id": _next_id, "kind": kind, "x": x, "d": d, "dir": dir,
		"state": "graze" if inside else "walk", "st": rng.randf_range(2.0, 6.0) if inside else rng.randf_range(7.0, 12.0),
		"phase": rng.randf() * TAU, "speed": 0.0, "fall": 0.0, "zone": "",
	}
	_next_id += 1
	animals.append(a)
	# A doe sometimes has her fawn with her (protected: never shoot it).
	if kind == "doe" and rng.randf() < 0.45:
		var f := a.duplicate()
		f.id = _next_id
		_next_id += 1
		f.kind = "fawn"
		f.x = x - dir * s * 1.9
		f.d = d + 2.0
		f.phase = rng.randf() * TAU
		animals.append(f)

func _step_animals(dt: float) -> void:
	for a in animals.duplicate():
		var k: Dictionary = KINDS[a.kind]
		var s := scale_at(a.d)
		a.phase += dt
		match a.state:
			"down":
				a.fall = minf(1.0, a.fall + dt * 2.5)
				a.st -= dt
				if a.st <= 0.0:
					animals.erase(a)
				continue
			"walk":
				if a.kind == "hare":
					# Hares hop in short bursts.
					a.speed = 3.2 if fposmod(a.phase, 1.6) < 0.35 else move_toward(a.speed, 0.0, dt * 12.0)
				else:
					a.speed = move_toward(a.speed, float(k.walk), dt * 2.0)
				a.st -= dt
				if a.st <= 0.0:
					a.state = "graze"
					a.st = rng.randf_range(2.5, 7.0)
			"graze":
				a.speed = move_toward(a.speed, 0.0, dt * 3.0)
				a.st -= dt
				if a.st <= 0.0:
					a.state = "walk"
					a.st = rng.randf_range(3.0, 9.0)
					if rng.randf() < 0.3:
						a.dir = -a.dir
			"alert":
				a.speed = move_toward(a.speed, 0.0, dt * 4.0)
				a.st -= dt
				if a.st <= 0.0:
					a.state = "graze"
					a.st = rng.randf_range(1.5, 4.0)
			"flee":
				a.speed = move_toward(a.speed, float(k.run), dt * 9.0)
		a.x += a.dir * a.speed * s * dt
		# Wandering animals turn back at the meadow's edges; fleeing ones leave.
		if a.state == "flee":
			var margin := 60.0 + s * 2.0
			if a.x < -margin or a.x > W + margin:
				animals.erase(a)
		elif a.state == "walk" and ((a.x < W * 0.05 and a.dir < 0) or (a.x > W * 0.95 and a.dir > 0)):
			a.dir = -a.dir

## Fires at `aim` (world units). Returns false if the rifle can't fire now.
func fire(aim: Vector2) -> bool:
	if not can_fire():
		return false
	shots += 1
	if mode != "practice":
		rounds -= 1
	bolt = BOLT_TIME
	# Flight time: to the nearest animal near the line of fire, else to the ground under the aim.
	var d := dist_at_y(aim.y)
	var hit_d := d if d < INF else 900.0
	for a in animals:
		if a.state == "down":
			continue
		var s := scale_at(a.d)
		if absf(aim.x - a.x) < s * 2.0 and absf(aim.y - (ground_y(a.d) - s)) < s * 2.0:
			hit_d = minf(hit_d, float(a.d))
	bullets.append({"aim": [aim.x, aim.y], "t": t + flight(minf(hit_d, 900.0)), "d": hit_d})
	# The crack makes every animal look up.
	for a in animals:
		if a.state in ["walk", "graze"]:
			a.state = "alert"
			a.st = rng.randf_range(1.5, 3.0)
	return true

## Where the bullet actually is when it reaches distance d (world units).
func impact_point(aim: Vector2, d: float) -> Vector2:
	return aim + Vector2(drift_m(d), drop_m(d)) * scale_at(d)

## Body parts in metres (x towards the head, y up from the ground), shared with the drawing.
func parts(a: Dictionary) -> Dictionary:
	var k: Dictionary = KINDS[a.kind]
	var L: float = k.len
	var h: float = k.h
	var head := Vector2(L * 0.62, h * 1.32)
	var hr := h * 0.17
	if a.kind == "boar":
		head = Vector2(L * 0.6, h * 0.72)
		hr = h * 0.24
	elif a.kind in ["fox", "hare"]:
		head = Vector2(L * 0.58, h * 1.05)
		hr = h * 0.26
	if a.state == "graze":
		if a.kind in ["buck", "doe", "fawn"]:
			head = Vector2(L * 0.68, h * 0.25)
		elif a.kind == "hare":
			head.y -= h * 0.25
	var body := Vector2(0.0, h * 0.78)
	var body_r := Vector2(L * 0.5, h * 0.3)
	if a.kind in ["buck", "doe", "fawn"]:
		body = Vector2(0.0, h * 0.8)
		body_r = Vector2(L * 0.46, h * 0.25)
	return {
		"body": body, "body_r": body_r,
		"head": head, "head_r": hr,
		"vital": Vector2(L * 0.22, h * 0.76), "vital_r": h * 0.19,
	}

## Which part of the animal (if any) a world point is in: "vital", "head", "body" or "".
func zone_at(a: Dictionary, p: Vector2) -> String:
	var s := scale_at(a.d)
	var l := Vector2((p.x - a.x) / s * a.dir, (ground_y(a.d) - p.y) / s)
	var pt := parts(a)
	if l.distance_to(pt.vital) <= float(pt.vital_r):
		return "vital"
	if l.distance_to(pt.head) <= float(pt.head_r):
		return "head"
	var q: Vector2 = (l - (pt.body as Vector2)) / (pt.body_r as Vector2)
	if q.length() <= 1.0:
		return "body"
	return ""

func _resolve(b: Dictionary) -> Dictionary:
	var aim := Vector2(b.aim[0], b.aim[1])
	# Nearest animal first: it shields anything behind it.
	var order := animals.filter(func(a): return a.state != "down")
	order.sort_custom(func(a, c): return a.d < c.d)
	var stop := _cover_hit(aim, 900.0)
	for a in order:
		var p := impact_point(aim, a.d)
		var z := zone_at(a, p)
		if z != "":
			if stop.size() > 0 and float(stop[1]) < float(a.d):
				break
			return _take(a, z, p)
	# A miss: where did it land?
	var gd: float = float(b.d) if float(b.d) < 900.0 else 650.0
	var blocked := false
	if stop.size() > 0 and float(stop[1]) < gd + 1.0:
		gd = float(stop[1])
		blocked = true
	var p2 := impact_point(aim, gd)
	misses += 1
	# Animals close to the impact bolt.
	for a in animals:
		if a.state == "down":
			continue
		if absf(p2.x - a.x) < scale_at(a.d) * 6.0 and absf(a.d - gd) < 120.0:
			a.state = "flee"
			a.dir = 1 if a.x >= p2.x else -1
	return {"type": "miss", "pos": [p2.x, p2.y], "d": gd, "blocked": blocked}

## The nearest cover the bullet runs into before `max_d`: [x, d] or [].
func _cover_hit(aim: Vector2, max_d: float) -> Array:
	var best: Array = []
	for cv in cover:
		var d: float = cv[1]
		if d >= max_d or (best.size() > 0 and d >= float(best[1])):
			continue
		var p := impact_point(aim, d)
		var s := scale_at(d)
		var gy := ground_y(d)
		if absf(p.x - float(cv[0])) <= float(cv[2]) * s and p.y <= gy and p.y >= gy - float(cv[3]) * s:
			best = [cv[0], d]
	return best

func _take(a: Dictionary, zone: String, p: Vector2) -> Dictionary:
	a.state = "down"
	a.zone = zone
	a.fall = 0.0
	a.st = 14.0
	var kind: String = a.kind
	var d: float = a.d
	var ok := is_target(kind) and not (kind in forbidden())
	var pts := 0
	var label := ""
	if not ok:
		strikes += 1
		pts = -200 if mode != "practice" else 0
		label = "Protected!" if not bool(KINDS[kind].legal) else "Wrong animal!"
	else:
		hits += 1
		if zone == "vital":
			clean += 1
		longest = maxf(longest, d)
		taken[kind] = int(taken.get(kind, 0)) + 1
		var zm: float = {"vital": 2.0, "head": 1.5, "body": 1.0}[zone]
		pts = int(round((float(KINDS[kind].pts) * zm + d * 0.5) * (DIFF_MULT[diff] if mode == "season" else 1.0)))
		if mode == "practice":
			pts = 0
		label = {"vital": "Clean shot", "head": "Head shot", "body": "Body shot"}[zone]
	score = maxi(0, score + pts)
	# Everything else runs.
	for o in animals:
		if o != a and o.state != "down":
			o.state = "flee"
			o.dir = 1 if o.x >= a.x else -1
	return {"type": "hit", "kind": kind, "zone": zone, "d": d, "pts": pts, "ok": ok, "label": label, "pos": [p.x, p.y], "id": a.id}

func contract_done() -> bool:
	if mode != "contract":
		return false
	for k in targets():
		if remaining(k) > 0:
			return false
	return true

## Contracts end on the first protected / forbidden hit, or when every target is taken.
## The game calls this once the hit has been shown (so the last animal falls first).
func check_end() -> Array:
	var ev: Array = []
	if over or mode != "contract":
		return ev
	if strikes > 0:
		_finish("forbidden", ev)
	elif contract_done() and bullets.is_empty():
		won = true
		_finish("done", ev)
	return ev

func _finish(reason: String, ev: Array) -> void:
	if over:
		return
	over = true
	end_reason = reason
	holding = false
	if mode == "season":
		won = true
	ev.append({"type": "over", "reason": reason})

## Contract stars: 1 done, +1 no missed shots, +1 every take a clean shot.
func stars() -> int:
	if mode != "contract" or not won:
		return 0
	var s := 1
	if misses == 0:
		s += 1
	if clean == hits and hits > 0:
		s += 1
	return s

# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {
		"mode": mode, "diff": diff, "level": level, "env": env, "seed": seed_used, "t": t,
		"time_left": time_left, "rounds": rounds, "score": score, "shots": shots, "hits": hits,
		"clean": clean, "misses": misses, "longest": longest, "taken": taken, "strikes": strikes,
		"wind": wind,
	}

func from_dict(dd: Dictionary) -> void:
	reset(str(dd.get("mode", "season")), int(dd.get("diff", 1)), int(dd.get("level", 0)), int(dd.get("seed", 1)) + 7)
	env = str(dd.get("env", env))
	t = float(dd.get("t", 0.0))
	time_left = float(dd.get("time_left", time_left))
	rounds = int(dd.get("rounds", rounds))
	score = int(dd.get("score", 0))
	shots = int(dd.get("shots", 0))
	hits = int(dd.get("hits", 0))
	clean = int(dd.get("clean", 0))
	misses = int(dd.get("misses", 0))
	longest = float(dd.get("longest", 0.0))
	taken = {}
	var tk = dd.get("taken", {})
	if tk is Dictionary:
		for k in tk:
			taken[str(k)] = int(tk[k])
	strikes = int(dd.get("strikes", 0))
	wind = clampf(float(dd.get("wind", 0.0)), -wind_max, wind_max)
	_wind_target = wind
	_ensure_targets()
