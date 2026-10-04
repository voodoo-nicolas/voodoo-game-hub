extends RefCounted

## Cannon Duel: two cannons on hilly, destructible ground take turns
## firing shells over it. Set the angle and power, mind the wind, and blow
## the other cannon's armour to zero. Shells dig craters, and a cannon
## whose ground is blown away drops down. Pure simulation in world units
## (W x H, y grows downwards), stepped by the game.

const W := 720.0
const H := 1000.0
const COLS := 181              # ground heights, one every STEP units
const STEP := W / (COLS - 1)
const GRAVITY := 620.0
const POWER_K := 8.6           # launch speed per point of power
const DT := 1.0 / 60.0
const TANK_R := 22.0           # hit radius around a cannon's middle
const MAX_HP := 100
const MOVE_FUEL := 70.0        # how far a cannon may drive per turn
const DRIVE_SPEED := 90.0
const MAX_SLOPE := 1.4         # steeper than this and the cannon can't climb
## name, blast radius, damage at the centre, shells, spread (degrees), starting ammo (-1 = unlimited)
const WEAPONS := [
	{"name": "Shell", "r": 38.0, "dmg": 42.0, "n": 1, "spread": 0.0, "ammo": -1},
	{"name": "Mega Bomb", "r": 72.0, "dmg": 62.0, "n": 1, "spread": 0.0, "ammo": 2},
	{"name": "Triple Shot", "r": 30.0, "dmg": 26.0, "n": 3, "spread": 5.0, "ammo": 2},
]
const WIND_MAX := 140.0

var ground: PackedFloat32Array = PackedFloat32Array()
var tanks: Array = []          # {"x", "y", "angle" (deg, 0 = right, 90 = up), "power", "hp", "ammo": [..], "weapon", "fuel"}
var turn: int = 0              # whose go: 0 or 1
var wind: float = 0.0          # horizontal acceleration
var shots: Array = []          # flying shells: {"p", "v", "w" (weapon), "trail": [...]}
var winner: int = -1           # -1 playing, 0 / 1, 2 = both destroyed
var shots_fired: int = 0
var last_hits: Array = []      # damage dealt by the last volley, per tank
var rng := RandomNumberGenerator.new()

func reset(seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	_make_ground()
	tanks = []
	for i in 2:
		var x := rng.randf_range(70.0, 150.0) if i == 0 else rng.randf_range(W - 150.0, W - 70.0)
		_flatten(x, 30.0)
		var ammo: Array = []
		for wpn in WEAPONS:
			ammo.append(wpn.ammo)
		tanks.append({"x": x, "y": ground_at(x), "angle": 50.0 if i == 0 else 130.0, "power": 62.0,
			"hp": MAX_HP, "ammo": ammo, "weapon": 0, "fuel": MOVE_FUEL})
	turn = 0
	winner = -1
	shots = []
	shots_fired = 0
	_new_wind()

func _make_ground() -> void:
	ground = PackedFloat32Array()
	ground.resize(COLS)
	var base := rng.randf_range(640.0, 720.0)
	var waves: Array = []
	for i in 4:
		waves.append([rng.randf_range(0.5, 3.5) * (i + 1), rng.randf_range(0.0, TAU), rng.randf_range(20.0, 90.0) / (i + 1)])
	# A hill in the middle so shots have to arc.
	var hill := rng.randf_range(120.0, 260.0)
	for i in COLS:
		var t := float(i) / (COLS - 1)
		var y := base
		for wv in waves:
			y += sin(t * wv[0] * PI + wv[1]) * wv[2]
		y -= hill * exp(-pow((t - 0.5) / 0.16, 2.0))
		ground[i] = clampf(y, 330.0, H - 60.0)

func _flatten(x: float, half: float) -> void:
	var y := ground_at(x)
	for i in COLS:
		if absf(i * STEP - x) <= half:
			ground[i] = y

func _new_wind() -> void:
	wind = roundf(rng.randf_range(-WIND_MAX, WIND_MAX) / 10.0) * 10.0

func ground_at(x: float) -> float:
	var f := clampf(x / STEP, 0.0, COLS - 1.0)
	var i := mini(int(f), COLS - 2)
	return lerpf(ground[i], ground[i + 1], f - i)

func is_over() -> bool:
	return winner != -1

## The barrel's tip: where shells start.
func muzzle(i: int) -> Vector2:
	var t: Dictionary = tanks[i]
	var a := deg_to_rad(t.angle)
	return Vector2(t.x, t.y - 14.0) + Vector2(cos(a), -sin(a)) * 26.0

func set_aim(i: int, angle: float, power: float) -> void:
	tanks[i].angle = clampf(angle, 0.0, 180.0)
	tanks[i].power = clampf(power, 10.0, 100.0)

## Next weapon that still has ammo.
func cycle_weapon(i: int) -> void:
	var t: Dictionary = tanks[i]
	for k in WEAPONS.size():
		var w: int = (t.weapon + 1 + k) % WEAPONS.size()
		if t.ammo[w] != 0:
			t.weapon = w
			return

## Drive along the ground while there's fuel; returns true if it moved.
func drive(i: int, dir: int, dt: float) -> bool:
	var t: Dictionary = tanks[i]
	if t.fuel <= 0.0 or dir == 0:
		return false
	var nx := clampf(t.x + dir * DRIVE_SPEED * dt, 20.0, W - 20.0)
	var climb: float = t.y - ground_at(nx)   # positive = uphill
	if climb > MAX_SLOPE * absf(nx - t.x) + 0.5:
		return false
	t.fuel = maxf(0.0, t.fuel - absf(nx - t.x))
	t.x = nx
	t.y = ground_at(nx)
	return true

func fire() -> void:
	var t: Dictionary = tanks[turn]
	var w: int = t.weapon
	if t.ammo[w] == 0:
		w = 0
	if t.ammo[w] > 0:
		t.ammo[w] -= 1
	var wpn: Dictionary = WEAPONS[w]
	shots = []
	last_hits = [0, 0]
	for k in wpn.n:
		var a := deg_to_rad(t.angle + (k - (wpn.n - 1) / 2.0) * wpn.spread)
		var v: Vector2 = Vector2(cos(a), -sin(a)) * t.power * POWER_K
		shots.append({"p": muzzle(turn), "v": v, "w": w, "trail": [muzzle(turn)]})
	shots_fired += 1
	if t.ammo[t.weapon] == 0:
		t.weapon = 0

## Advances the shells by dt. Returns explosions this step:
## [{"p": Vector2, "r": float, "hit": [tank indices damaged]}].
func step(dt: float) -> Array:
	var booms: Array = []
	var t := 0.0
	while t < dt and not shots.is_empty():
		var h := minf(DT, dt - t)
		t += h
		var keep: Array = []
		for s in shots:
			var res := _advance(s, h)
			if res == "":
				keep.append(s)
			elif res == "boom":
				booms.append(_explode(s.p, s.w))
		shots = keep
	return booms

## One physics tick of a shell: "", "boom" or "gone".
func _advance(s: Dictionary, h: float) -> String:
	s.v += Vector2(wind, GRAVITY) * h
	s.p += s.v * h
	if s.has("trail"):
		var tr: Array = s.trail
		if tr.is_empty() or (tr[tr.size() - 1] as Vector2).distance_to(s.p) > 10.0:
			tr.append(s.p)
	if s.p.x < -60.0 or s.p.x > W + 60.0 or s.p.y > H:
		return "gone"
	for i in tanks.size():
		var c := Vector2(tanks[i].x, tanks[i].y - 10.0)
		if s.p.distance_to(c) < TANK_R * 0.8:
			return "boom"
	if s.p.x >= 0.0 and s.p.x <= W and s.p.y >= ground_at(s.p.x):
		return "boom"
	return ""

func _explode(p: Vector2, w: int) -> Dictionary:
	var wpn: Dictionary = WEAPONS[w]
	var r: float = wpn.r
	# Dig the crater: the circle's overlap is removed, what was above falls in.
	for i in COLS:
		var dx := i * STEP - p.x
		if absf(dx) >= r:
			continue
		var s := sqrt(r * r - dx * dx)
		var top := p.y - s
		var bottom := p.y + s
		if ground[i] < bottom:
			var removed := minf(bottom - maxf(ground[i], top), 2.0 * s)
			ground[i] = minf(H - 4.0, ground[i] + maxf(0.0, removed))
	var hit: Array = []
	for i in tanks.size():
		var c := Vector2(tanks[i].x, tanks[i].y - 10.0)
		var d := p.distance_to(c)
		var reach: float = r + TANK_R
		if d < reach:
			var dmg := int(roundf(wpn.dmg * clampf(1.15 - d / reach, 0.15, 1.0)))
			tanks[i].hp = maxi(0, tanks[i].hp - dmg)
			last_hits[i] += dmg
			hit.append(i)
	return {"p": p, "r": r, "hit": hit}

## After a volley: cannons drop onto what's left of the ground (a long fall
## hurts), the game may be over, else the other side's turn with new wind.
func settle() -> void:
	for i in tanks.size():
		var gy := ground_at(tanks[i].x)
		var drop: float = gy - tanks[i].y
		if drop > 50.0:
			var dmg := int((drop - 50.0) / 6.0)
			tanks[i].hp = maxi(0, tanks[i].hp - dmg)
			last_hits[i] += dmg
		tanks[i].y = gy
	var dead := [tanks[0].hp <= 0, tanks[1].hp <= 0]
	if dead[0] and dead[1]:
		winner = 2
	elif dead[0]:
		winner = 1
	elif dead[1]:
		winner = 0
	else:
		turn = 1 - turn
		tanks[turn].fuel = MOVE_FUEL
		_new_wind()

## Where a shot with this aim would land (no side effects): the explosion
## point, or a far-off point if it leaves the field.
func predict(i: int, angle: float, power: float) -> Vector2:
	var a := deg_to_rad(angle)
	var p: Vector2 = muzzle(i)
	var v: Vector2 = Vector2(cos(a), -sin(a)) * power * POWER_K
	var acc := Vector2(wind, GRAVITY) * DT
	var c0 := Vector2(tanks[0].x, tanks[0].y - 10.0)
	var c1 := Vector2(tanks[1].x, tanks[1].y - 10.0)
	var hr2 := (TANK_R * 0.8) * (TANK_R * 0.8)
	var lowest := H
	for g in ground:
		lowest = minf(lowest, g)
	for n in 2400:
		v += acc
		p += v * DT
		if p.x < -60.0 or p.x > W + 60.0 or p.y > H:
			return Vector2(-9999, -9999)
		if p.distance_squared_to(c0) < hr2 or p.distance_squared_to(c1) < hr2:
			return p
		if p.y >= lowest and p.x >= 0.0 and p.x <= W and p.y >= ground_at(p.x):
			return p
	return p

## The computer's aim at the other cannon. level 0..2 = Easy, Normal, Hard.
## Returns {"angle", "power", "weapon"}.
func cpu_aim(i: int, level: int) -> Dictionary:
	var target := Vector2(tanks[1 - i].x, tanks[1 - i].y - 10.0)
	var left: bool = target.x < tanks[i].x
	var best := {"angle": 135.0 if left else 45.0, "power": 60.0, "d": INF}
	var a0 := 95.0 if left else 10.0
	var a1 := 170.0 if left else 85.0
	var a := a0
	while a <= a1:
		var p := 30.0
		while p <= 100.0:
			var d := predict(i, a, p).distance_to(target)
			if d < best.d:
				best = {"angle": a, "power": p, "d": d}
			p += 5.0
		a += 6.0
	# Refine around the best coarse shot.
	var coarse: Dictionary = best.duplicate()
	for da in range(-3, 4):
		for dp in range(-3, 4):
			var aa: float = coarse.angle + da
			var pp: float = clampf(coarse.power + dp, 10.0, 100.0)
			var d := predict(i, aa, pp).distance_to(target)
			if d < best.d:
				best = {"angle": aa, "power": pp, "d": d}
	var noise: Array = [[6.5, 9.0], [3.2, 4.5], [1.6, 2.2]][clampi(level, 0, 2)]
	var weapon := 0
	var ammo: Array = tanks[i].ammo
	if level >= 1 and best.d < 30.0:
		if ammo[1] != 0 and (level == 2 or rng.randf() < 0.5):
			weapon = 1
		elif ammo[2] != 0 and rng.randf() < 0.5:
			weapon = 2
	return {"angle": clampf(best.angle + rng.randf_range(-noise[0], noise[0]), 0.0, 180.0),
		"power": clampf(best.power + rng.randf_range(-noise[1], noise[1]), 10.0, 100.0), "weapon": weapon}

# ---------- save / load ----------

func to_dict() -> Dictionary:
	var g: Array = []
	for v in ground:
		g.append(snappedf(v, 0.1))
	return {"ground": g, "tanks": tanks.duplicate(true), "turn": turn, "wind": wind, "shots_fired": shots_fired}

func from_dict(d: Dictionary) -> void:
	ground = PackedFloat32Array()
	for v in d.ground:
		ground.append(float(v))
	tanks = []
	for t in d.tanks:
		var ammo: Array = []
		for a in t.ammo:
			ammo.append(int(a))
		tanks.append({"x": float(t.x), "y": float(t.y), "angle": float(t.angle), "power": float(t.power),
			"hp": int(t.hp), "ammo": ammo, "weapon": int(t.weapon), "fuel": float(t.fuel)})
	turn = int(d.turn)
	wind = float(d.wind)
	shots_fired = int(d.get("shots_fired", 0))
	shots = []
	winner = -1
