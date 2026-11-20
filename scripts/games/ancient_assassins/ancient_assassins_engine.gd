extends RefCounted

## Ancient Assassins: two assassins stand on the ruins of an old-world city
## and take turns throwing at each other -- javelin, throwing axe, chakram.
## Hold, pull back to aim, release to throw. Gravity bends the arc, the wind
## pushes it sideways (more for light weapons), and where it lands matters:
## a head hit does double damage, a leg hit a little over half.
## Pure simulation in world units (W x H, y grows downwards), no Nodes.
##
## Online play: both phones run the same throw from the same whole-number aim
## (tenths of a degree / of a power point), and the wind of every turn comes
## from the match seed, so the two copies agree; the host's state wins if they
## ever don't (see snapshot()).

const W := 1600.0
const H := 900.0
const COLS := 201
const STEP := W / (COLS - 1)
## One physics tick (the CPU's predictions use the same one, so its aim is true).
const DT := 1.0 / 90.0
const MAX_HP := 100
## Wind: horizontal acceleration in units/s², times the weapon's "wind" factor.
const WIND_MAX := 200.0
const FIGHTER_H := 120.0
## Damage multiplier per body zone.
const ZONE_MULT := {"head": 2.0, "body": 1.0, "legs": 0.6}
## Launch speed = power x speed. g = gravity. wind = how much the wind pushes it
## (heavy axe 0.45, light chakram 1.6). ammo -1 = unlimited.
const WEAPONS := [
	{"name": "Javelin", "speed": 13.0, "g": 700.0, "wind": 1.0, "dmg": 34, "ammo": -1},
	{"name": "Throwing Axe", "speed": 11.0, "g": 900.0, "wind": 0.45, "dmg": 46, "ammo": 2},
	{"name": "Chakram", "speed": 15.0, "g": 520.0, "wind": 1.6, "dmg": 26, "ammo": 3},
]
## Map styles: 0 = valley, 1 = hill in the middle, 2 = columns.
const STYLES := 3
const MAX_STUCK := 24

var ground: PackedFloat32Array = PackedFloat32Array()
var pillars: Array = []        # {"x", "w", "top"}: stone columns from "top" down to the ground
var style: int = 0
var fighters: Array = []       # {"x", "y" (feet), "hp", "char", "ammo": [..], "weapon", "facing" (1 right / -1 left)}
var aim: Array = []            # per fighter: [angle tenths of a degree (0 = right, 900 = up), power tenths (100..1000)]
var turn: int = 0
var winner: int = -1           # -1 playing, else the fighter left standing
var seed_: int = 0
var throws: int = 0            # throws so far this match (picks each turn's wind)
var wind: float = 0.0
var wind_max: float = WIND_MAX
var shot: Dictionary = {}      # in flight: {"p", "prev", "v", "w", "owner", "age", "spin", "trail"}
var stuck: Array = []          # landed weapons, for drawing: {"p", "a", "w", "f" (-1 or fighter), "off"}
var last_hit: Dictionary = {}  # the last throw's hit: {"f", "zone", "dmg"} or {}
var rng := RandomNumberGenerator.new()
var acc: float = 0.0           # time not yet simulated (see step())

## opts: "dist" (distance between the two, default random 1000-1250),
## "style" (0-2, default random), "wind_max", "hp" ([a, b]), "chars" ([a, b]).
func reset(p_seed: int = -1, opts: Dictionary = {}) -> void:
	if p_seed < 0:
		rng.randomize()
		p_seed = rng.randi() % 1000000000
	seed_ = p_seed
	rng.seed = seed_
	style = int(opts.get("style", rng.randi() % STYLES))
	wind_max = float(opts.get("wind_max", WIND_MAX))
	var dist: float = float(opts.get("dist", rng.randf_range(1000.0, 1250.0)))
	var xs := [W / 2.0 - dist / 2.0, W / 2.0 + dist / 2.0]
	_make_map(xs)
	var hp: Array = opts.get("hp", [MAX_HP, MAX_HP])
	var chars: Array = opts.get("chars", [0, 1])
	fighters = []
	aim = []
	for i in 2:
		var ammo: Array = []
		for wpn in WEAPONS:
			ammo.append(int(wpn.ammo))
		fighters.append({"x": xs[i], "y": ground_at(xs[i]), "hp": int(hp[i]), "char": int(chars[i]),
			"ammo": ammo, "weapon": 0, "facing": 1 if i == 0 else -1})
		aim.append([450 if i == 0 else 1350, 700])
	turn = 0
	winner = -1
	throws = 0
	shot = {}
	stuck = []
	last_hit = {}
	wind = wind_for(0)

# ---------- the map ----------

func _make_map(xs: Array) -> void:
	ground = PackedFloat32Array()
	ground.resize(COLS)
	pillars = []
	var lh := rng.randf_range(560.0, 690.0)
	var rh := rng.randf_range(560.0, 690.0)
	var a: float = xs[0] + 70.0
	var b: float = xs[1] - 70.0
	var mid: float
	match style:
		0:
			mid = rng.randf_range(760.0, 840.0)       # a valley between the two
		1:
			mid = rng.randf_range(400.0, 500.0)       # a hill to throw over
		_:
			mid = rng.randf_range(660.0, 740.0)       # low ground with columns
	var ph := [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)]
	for i in COLS:
		var x := i * STEP
		var y: float
		if x <= a:
			y = lh + sin(x * 0.02 + ph[0]) * 4.0
			if x < a - 160.0:  # the far edge steps down a little
				y += (a - 160.0 - x) * 0.25
		elif x >= b:
			y = rh + sin(x * 0.02 + ph[1]) * 4.0
			if x > b + 160.0:
				y += (x - b - 160.0) * 0.25
		else:
			var u := (x - a) / (b - a)
			var base := lerpf(lh, rh, smoothstep(0.0, 1.0, u))
			y = base + (mid - (lh + rh) / 2.0) * pow(sin(PI * u), 2.0) + sin(u * 11.0 + ph[0]) * 6.0
		ground[i] = clampf(y, 330.0, H - 30.0)
	# Flat footing under each fighter.
	for x in xs:
		var y := ground_at(x)
		for i in COLS:
			if absf(i * STEP - x) <= 46.0:
				ground[i] = y
	var n := 0
	if style == 2:
		n = 1 + rng.randi() % 2
	elif style == 0 and rng.randf() < 0.5:
		n = 1
	for k in n:
		var u := 0.5 if n == 1 else (0.36 if k == 0 else 0.64)
		u += rng.randf_range(-0.06, 0.06)
		var px := lerpf(a, b, u)
		var g := ground_at(px)
		pillars.append({"x": snappedf(px, 0.5), "w": 36.0, "top": snappedf(g - rng.randf_range(170.0, 290.0), 0.5)})

func ground_at(x: float) -> float:
	var f := clampf(x / STEP, 0.0, COLS - 1.0)
	var i := mini(int(f), COLS - 2)
	return lerpf(ground[i], ground[i + 1], f - i)

## Wind for the n-th throw of the match: the same on every phone (from the seed).
func wind_for(n: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = seed_ * 31 + n * 7919 + 17
	var v := r.randf_range(-1.0, 1.0)
	v = signf(v) * pow(absf(v), 0.8)  # a little more often a real wind than a calm
	return roundf(v * wind_max / 10.0) * 10.0

func is_over() -> bool:
	return winner != -1

# ---------- aiming ----------

func angle_of(i: int) -> float:
	return aim[i][0] / 10.0

func power_of(i: int) -> float:
	return aim[i][1] / 10.0

## Angle in degrees (0 = right, 90 = up), power 10..100. Kept in tenths, so
## the same aim is the same number on both phones.
func set_aim(i: int, angle: float, power: float) -> void:
	angle = fposmod(angle + 90.0, 360.0) - 90.0      # -90..270
	aim[i] = [int(roundf(angle * 10.0)), int(roundf(clampf(power, 10.0, 100.0) * 10.0))]
	if i < fighters.size():
		var c := cos(deg_to_rad(angle))
		if absf(c) > 0.05:
			fighters[i].facing = 1 if c > 0.0 else -1

## Where the throw leaves the hand.
func hand(i: int) -> Vector2:
	var f: Dictionary = fighters[i]
	var a := deg_to_rad(angle_of(i))
	return Vector2(f.x, f.y - 100.0) + Vector2(cos(a), -sin(a)) * 22.0

func cycle_weapon(i: int) -> void:
	var f: Dictionary = fighters[i]
	for k in WEAPONS.size():
		var w: int = (f.weapon + 1 + k) % WEAPONS.size()
		if f.ammo[w] != 0:
			f.weapon = w
			return

func pick_weapon(i: int, w: int) -> bool:
	if w < 0 or w >= WEAPONS.size() or fighters[i].ammo[w] == 0:
		return false
	fighters[i].weapon = w
	return true

# ---------- throwing ----------

func throw() -> void:
	var f: Dictionary = fighters[turn]
	var w: int = f.weapon
	if f.ammo[w] == 0:
		w = 0
	if f.ammo[w] > 0:
		f.ammo[w] -= 1
	var wpn: Dictionary = WEAPONS[w]
	var a := deg_to_rad(angle_of(turn))
	var p := hand(turn)
	shot = {"p": p, "prev": p, "v": Vector2(cos(a), -sin(a)) * power_of(turn) * float(wpn.speed),
		"w": w, "owner": turn, "age": 0.0, "spin": 0.0, "trail": [p]}
	acc = 0.0
	last_hit = {}
	throws += 1
	if f.ammo[f.weapon] == 0:
		f.weapon = 0

## Advances the throw by dt. Returns what happened this step, at most one of:
## {"kind": "hit", "f", "zone", "dmg", "p"} · {"kind": "stick", "p", "surface": "ground"|"stone"} · {"kind": "out"}.
## Always whole DT ticks (left-over time waits for the next frame), so a
## throw lands in the same spot at any frame rate, on any phone.
func step(dt: float) -> Array:
	var out: Array = []
	acc = minf(acc + dt, 0.25)
	while acc >= DT and not shot.is_empty():
		acc -= DT
		var res := _tick(shot, DT, true)
		if not res.is_empty():
			out.append(res)
			shot = {}
	return out

## One physics tick. Returns {} while flying, else what it hit. `real`: apply
## damage and leave the weapon stuck (false = the CPU's prediction).
func _tick(s: Dictionary, h: float, real: bool) -> Dictionary:
	var wpn: Dictionary = WEAPONS[s.w]
	s.prev = s.p
	s.v += Vector2(wind * float(wpn.wind), float(wpn.g)) * h
	s.p += s.v * h
	s.age += h
	s.spin += h * (14.0 if s.w == 1 else 22.0)
	if real:
		var tr: Array = s.trail
		if (tr[tr.size() - 1] as Vector2).distance_to(s.p) > 14.0:
			tr.append(s.p)
			if tr.size() > 40:
				tr.pop_front()
	var p: Vector2 = s.p
	if p.x < -80.0 or p.x > W + 80.0 or p.y > H + 40.0:
		return {"kind": "out"}
	# Check the end of the tick and its middle, so a fast throw can't skip a head.
	for q in [(s.prev + p) / 2.0, p]:
		for i in fighters.size():
			if absf(q.x - fighters[i].x) > 16.0 or (i == s.owner and s.age < 0.3) or fighters[i].hp <= 0:
				continue
			var zone := zone_at(i, q)
			if zone != "":
				var dmg := int(roundf(float(wpn.dmg) * float(ZONE_MULT[zone])))
				if real:
					fighters[i].hp = maxi(0, fighters[i].hp - dmg)
					last_hit = {"f": i, "zone": zone, "dmg": dmg}
					_stick(q, s, i)
				return {"kind": "hit", "f": i, "zone": zone, "dmg": dmg, "p": q}
		for pl in pillars:
			if absf(q.x - pl.x) <= pl.w / 2.0 and q.y >= pl.top:
				if real:
					_stick(q, s, -1)
				return {"kind": "stick", "p": q, "surface": "stone"}
		if q.y >= 300.0 and q.x >= 0.0 and q.x <= W and q.y >= ground_at(q.x):
			var g := Vector2(q.x, ground_at(q.x))
			if real:
				_stick(g, s, -1)
			return {"kind": "stick", "p": g, "surface": "ground"}
	return {}

## "head", "body", "legs" or "" for a point near fighter i (feet at x, y).
func zone_at(i: int, q: Vector2) -> String:
	var f: Dictionary = fighters[i]
	var head := Vector2(f.x + 1.0 * f.facing, f.y - 108.0)
	if q.distance_to(head) <= 11.0:
		return "head"
	if absf(q.x - f.x) <= 14.0:
		if q.y >= f.y - 97.0 and q.y < f.y - 52.0:
			return "body"
		if q.y >= f.y - 52.0 and q.y <= f.y:
			return "legs"
	return ""

func _stick(p: Vector2, s: Dictionary, f: int) -> void:
	var a: float = (s.v as Vector2).angle() if s.w == 0 else float(s.spin)
	var e := {"p": p, "a": a, "w": s.w, "f": f, "off": Vector2.ZERO}
	if f >= 0:
		e.off = p - Vector2(fighters[f].x, fighters[f].y)
	stuck.append(e)
	if stuck.size() > MAX_STUCK:
		stuck.pop_front()

## After a throw lands: someone may be down, else the other side's turn
## with the next wind.
func settle() -> void:
	shot = {}
	for i in fighters.size():
		if fighters[i].hp <= 0:
			winner = 1 - i
			return
	turn = 1 - turn
	wind = wind_for(throws)

# ---------- the computer ----------

## Where a throw with this aim would end (no side effects):
## {"p": Vector2, "f": fighter hit or -1, "zone": "", "out": bool}.
func predict(i: int, angle: float, power: float, w: int) -> Dictionary:
	var keep_aim: Array = aim[i]
	var keep_facing: int = fighters[i].facing
	set_aim(i, angle, power)
	var a := deg_to_rad(angle_of(i))
	var p := hand(i)
	var s := {"p": p, "prev": p, "v": Vector2(cos(a), -sin(a)) * power_of(i) * float(WEAPONS[w].speed),
		"w": w, "owner": i, "age": 0.0, "spin": 0.0}
	var res := {}
	for n in 900:
		res = _tick(s, DT, false)
		if not res.is_empty():
			break
	aim[i] = keep_aim
	fighters[i].facing = keep_facing
	if res.is_empty() or res.kind == "out":
		return {"p": s.p, "f": -1, "zone": "", "out": true}
	return {"p": res.p, "f": int(res.get("f", -1)), "zone": str(res.get("zone", "")), "out": false}

## The path a throw would take (for the 🦅 Eagle Eye help): points every few ticks.
func path(i: int, w: int) -> PackedVector2Array:
	var a := deg_to_rad(angle_of(i))
	var p := hand(i)
	var s := {"p": p, "prev": p, "v": Vector2(cos(a), -sin(a)) * power_of(i) * float(WEAPONS[w].speed),
		"w": w, "owner": i, "age": 0.0, "spin": 0.0}
	var pts := PackedVector2Array([p])
	for n in 900:
		var res := _tick(s, DT, false)
		if n % 3 == 0 or not res.is_empty():
			pts.append(s.p)
		if not res.is_empty():
			break
	return pts

## The computer's throw, worked out a few angles at a time so the screen never
## freezes: plan = cpu_plan(i, level), then call cpu_think(plan) once or more per
## frame until it returns true; the throw is then plan.angle / plan.power / plan.weapon.
## level 0..3 = Easy, Normal, Hard, Expert. Its aim sharpens over the match
## (the first throw is a sighter).
const CPU_ANGLES := [10.0, 16.0, 22.0, 28.0, 34.0, 40.0, 46.0, 52.0, 58.0, 64.0, 70.0, 76.0]

func cpu_plan(i: int, level: int) -> Dictionary:
	var j := 1 - i
	var tf: Dictionary = fighters[j]
	var want_head := level >= 2 and rng.randf() < (0.35 if level == 2 else 0.6)
	var weapon := 0
	var ammo: Array = fighters[i].ammo
	if level >= 1:
		if absf(wind) >= 120.0 and ammo[1] != 0 and rng.randf() < 0.7:
			weapon = 1
		elif absf(wind) <= 40.0 and ammo[2] != 0 and rng.randf() < 0.4:
			weapon = 2
		elif ammo[1] != 0 and rng.randf() < 0.15 * level:
			weapon = 1
	return {"i": i, "j": j, "level": level, "weapon": weapon, "k": 0,
		"target": Vector2(tf.x, tf.y - (108.0 if want_head else 74.0)),
		"dir": 1.0 if tf.x > fighters[i].x else -1.0,
		"best": {"angle": 45.0 if tf.x > fighters[i].x else 135.0, "power": 70.0, "d": INF},
		"angle": 0.0, "power": 0.0}

func cpu_think(plan: Dictionary) -> bool:
	var i: int = plan.i
	var best: Dictionary = plan.best
	if plan.k < CPU_ANGLES.size():
		var a: float = CPU_ANGLES[plan.k]
		var ang := a if plan.dir > 0.0 else 180.0 - a
		var lo := 15.0
		var hi := 100.0
		for it in 8:  # bisection on power: too short -> more, too long -> less
			var mid := (lo + hi) / 2.0
			var r := predict(i, ang, mid, plan.weapon)
			var d := _miss(r, plan.j, plan.target)
			if d < best.d:
				best.angle = ang
				best.power = mid
				best.d = d
			if r.f == plan.j:
				break
			var over: bool = r.f != i and (r.p.x - plan.target.x) * plan.dir > 0.0
			if over:
				hi = mid
			else:
				lo = mid
		plan.k += 1
		return false
	# Polish the best one, then miss on purpose by the level's amount.
	var coarse: Dictionary = best.duplicate()
	for da in [-2.0, 0.0, 2.0]:
		for dp in [-1.0, 0.0, 1.0]:
			if da == 0.0 and dp == 0.0:
				continue
			var ang: float = coarse.angle + da
			var pw: float = clampf(coarse.power + dp, 10.0, 100.0)
			var d := _miss(predict(i, ang, pw, plan.weapon), plan.j, plan.target)
			if d < best.d:
				best.angle = ang
				best.power = pw
				best.d = d
	var noise: Array = [[5.0, 7.0], [2.4, 3.4], [1.1, 1.5], [0.5, 0.7]][clampi(plan.level, 0, 3)]
	@warning_ignore("integer_division")
	var mine := (throws + (1 if i == 0 else 0)) / 2  # this fighter's throws so far
	var sharpen := maxf(0.55, 1.35 - 0.2 * mine)
	plan.angle = best.angle + rng.randf_range(-1.0, 1.0) * noise[0] * sharpen
	plan.power = clampf(best.power + rng.randf_range(-1.0, 1.0) * noise[1] * sharpen, 10.0, 100.0)
	return true

## The whole plan in one go (tests, the 🎯 help).
func cpu_aim(i: int, level: int) -> Dictionary:
	var plan := cpu_plan(i, level)
	while not cpu_think(plan):
		pass
	return {"angle": plan.angle, "power": plan.power, "weapon": plan.weapon}

func _miss(r: Dictionary, j: int, target: Vector2) -> float:
	if r.f == j:
		return 0.0 if r.zone == "head" else (target.distance_to(r.p) * 0.2)
	if r.f >= 0:
		return 5000.0  # it would hit itself
	return target.distance_to(r.p) + (400.0 if r.out else 0.0)

# ---------- save / load / online ----------

## Everything that matters about the match, JSON-safe. Weapons stuck in the
## ground aren't in it (just decoration), nor the aim (it changes while aiming).
func snapshot() -> Dictionary:
	var g: Array = []
	for v in ground:
		g.append(snappedf(v, 0.1))
	var fs: Array = []
	for f in fighters:
		fs.append({"x": f.x, "y": snappedf(f.y, 0.1), "hp": f.hp, "char": f.char, "ammo": (f.ammo as Array).duplicate(),
			"weapon": f.weapon, "facing": f.facing})
	return {"ground": g, "pillars": pillars.duplicate(true), "style": style, "fighters": fs, "turn": turn,
		"winner": winner, "seed": seed_, "throws": throws, "wind": wind, "wind_max": wind_max}

func to_dict() -> Dictionary:
	var d := snapshot()
	d["aim"] = aim.duplicate(true)
	return d

func from_dict(d: Dictionary) -> bool:
	if not (d.get("ground") is Array) or (d.ground as Array).size() != COLS or not (d.get("fighters") is Array) or (d.fighters as Array).size() != 2:
		return false
	ground = PackedFloat32Array()
	for v in d.ground:
		ground.append(float(v))
	pillars = []
	for pl in d.get("pillars", []):
		pillars.append({"x": float(pl.x), "w": float(pl.w), "top": float(pl.top)})
	style = int(d.get("style", 0))
	fighters = []
	for f in d.fighters:
		var ammo: Array = []
		for a in f.ammo:
			ammo.append(int(a))
		fighters.append({"x": float(f.x), "y": float(f.y), "hp": int(f.hp), "char": int(f.char), "ammo": ammo,
			"weapon": int(f.weapon), "facing": int(f.facing)})
	turn = int(d.get("turn", 0))
	winner = int(d.get("winner", -1))
	seed_ = int(d.get("seed", 0))
	throws = int(d.get("throws", 0))
	wind = float(d.get("wind", 0.0))
	wind_max = float(d.get("wind_max", WIND_MAX))
	if d.get("aim") is Array and (d.aim as Array).size() == 2:
		aim = [[int(d.aim[0][0]), int(d.aim[0][1])], [int(d.aim[1][0]), int(d.aim[1][1])]]
	elif aim.size() != 2:
		aim = [[450, 700], [1350, 700]]
	shot = {}
	stuck = []
	return true
