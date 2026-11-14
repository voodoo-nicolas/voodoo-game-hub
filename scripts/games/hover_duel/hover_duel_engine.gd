extends RefCounted

## Hover Duel: two hovercraft fight one-on-one over a top-down map of
## grass, hills, rivers, sea and rock. Pure simulation in world units
## (W x H, y grows downwards), stepped by the game; no Nodes, headless-testable.
##
## Terrain: a height field (0..1) on a GW x GH grid. Below `sea` = water
## (craft hover over it, but it is slippery). Above `rock` = cliffs nobody
## can fly into or shoot through. In between, height matters: climbing slows
## a craft, and a shot flies at the height it was fired from, so a hill
## between two craft stops the shots of the one below (high ground wins).

const GW := 240
const GH := 180
const CELL := 8.0
const W := GW * CELL          # 1920
const H := GH * CELL          # 1440
const DT := 1.0 / 60.0
const HOVER := 0.08           # how high above the ground a craft's shots fly (small bumps don't stop them)
const CRAFT_R := 20.0
const SHOT_SPEED := 760.0
const SHOT_LIFE := 0.85
const MISSILE_SPEED := 430.0
const MISSILE_TURN := 3.2     # rad / s
const MISSILE_LIFE := 3.2
const MISSILE_DMG := 24.0
const MINE_DMG := 32.0
const MINE_R := 34.0
const MINE_ARM := 1.0
const PICKUP_EVERY := 11.0
const PICKUP_MAX := 3
const LAVA_DPS := 9.0
const KINDS := ["repair", "missiles", "mines", "shield"]

## Craft types. speed (units/s), accel, turn (rad/s), hp, cd (s between
## shots), dmg per shot, missiles / mines at the start.
const CRAFTS := {
	"skimmer": {"name": "Skimmer", "speed": 330.0, "accel": 620.0, "turn": 4.2, "hp": 100.0, "cd": 0.22, "dmg": 6.0, "missiles": 3, "mines": 2},
	"gnat": {"name": "Gnat", "speed": 360.0, "accel": 700.0, "turn": 4.8, "hp": 70.0, "cd": 0.25, "dmg": 5.0, "missiles": 1, "mines": 1},
	"hornet": {"name": "Hornet", "speed": 340.0, "accel": 640.0, "turn": 4.4, "hp": 90.0, "cd": 0.2, "dmg": 6.0, "missiles": 2, "mines": 1},
	"barge": {"name": "Barge", "speed": 250.0, "accel": 420.0, "turn": 3.0, "hp": 170.0, "cd": 0.3, "dmg": 8.0, "missiles": 2, "mines": 3},
	"stingray": {"name": "Stingray", "speed": 380.0, "accel": 760.0, "turn": 4.6, "hp": 95.0, "cd": 0.18, "dmg": 6.0, "missiles": 3, "mines": 1},
	"bulwark": {"name": "Bulwark", "speed": 270.0, "accel": 470.0, "turn": 3.3, "hp": 220.0, "cd": 0.26, "dmg": 9.0, "missiles": 4, "mines": 3},
	"wraith": {"name": "Wraith", "speed": 400.0, "accel": 820.0, "turn": 5.0, "hp": 120.0, "cd": 0.16, "dmg": 7.0, "missiles": 4, "mines": 2},
	"warden": {"name": "Warden", "speed": 320.0, "accel": 640.0, "turn": 4.2, "hp": 300.0, "cd": 0.15, "dmg": 8.0, "missiles": 6, "mines": 4},
}

## Map themes: the generator's knobs. sea / rock = height thresholds,
## rivers = how many are carved, liquid = "water" or "lava", ice = slippery land.
const THEMES := {
	"valley": {"name": "Green Valley", "sea": 0.30, "rock": 0.86, "rivers": 2, "liquid": "water", "ice": false, "bias": 0.06},
	"isles": {"name": "Stone Isles", "sea": 0.52, "rock": 0.72, "rivers": 0, "liquid": "water", "ice": false, "bias": -0.02},
	"highlands": {"name": "Highlands", "sea": 0.22, "rock": 0.78, "rivers": 1, "liquid": "water", "ice": false, "bias": 0.12},
	"desert": {"name": "Dune Sea", "sea": 0.20, "rock": 0.84, "rivers": 1, "liquid": "water", "ice": false, "bias": 0.08},
	"glacier": {"name": "Glacier", "sea": 0.34, "rock": 0.80, "rivers": 2, "liquid": "water", "ice": true, "bias": 0.04},
	"volcano": {"name": "Ash Fields", "sea": 0.30, "rock": 0.76, "rivers": 2, "liquid": "lava", "ice": false, "bias": 0.06},
}

## Campaign: 12 battles, one rival each, harder as you go.
## ai = 0 easy .. 3 expert. Every third battle is a boss.
const CAMPAIGN := [
	{"theme": "valley", "seed": 1101, "foe": "gnat", "ai": 0, "rival": "Dash"},
	{"theme": "valley", "seed": 1207, "foe": "hornet", "ai": 0, "rival": "Pip"},
	{"theme": "isles", "seed": 2311, "foe": "barge", "ai": 1, "rival": "Old Mossback", "boss": true},
	{"theme": "isles", "seed": 2417, "foe": "stingray", "ai": 1, "rival": "Reef"},
	{"theme": "highlands", "seed": 3121, "foe": "hornet", "ai": 1, "rival": "Crag"},
	{"theme": "highlands", "seed": 3229, "foe": "bulwark", "ai": 2, "rival": "The Mountain", "boss": true},
	{"theme": "desert", "seed": 4133, "foe": "stingray", "ai": 2, "rival": "Mirage"},
	{"theme": "desert", "seed": 4241, "foe": "gnat", "ai": 2, "rival": "Sidewinder"},
	{"theme": "glacier", "seed": 5147, "foe": "wraith", "ai": 2, "rival": "Frost", "boss": true},
	{"theme": "glacier", "seed": 5253, "foe": "bulwark", "ai": 3, "rival": "Avalanche"},
	{"theme": "volcano", "seed": 6163, "foe": "wraith", "ai": 3, "rival": "Cinder"},
	{"theme": "volcano", "seed": 6271, "foe": "warden", "ai": 3, "rival": "The Warden", "boss": true},
]

## ai level: aim error (rad), reaction (s), how often it uses specials, how much it leads shots
const AI := [
	{"err": 0.30, "react": 0.55, "special": 0.15, "lead": 0.0},
	{"err": 0.17, "react": 0.35, "special": 0.35, "lead": 0.5},
	{"err": 0.09, "react": 0.22, "special": 0.6, "lead": 0.85},
	{"err": 0.04, "react": 0.14, "special": 0.85, "lead": 1.0},
]

var theme_id := "valley"
var theme: Dictionary = THEMES.valley
var map_seed: int = 1
var hgt: PackedFloat32Array = PackedFloat32Array()
var crafts: Array = []        # {"p","v","a","hp","max","type","cd","missiles","mines","shield","ai"(-1 human),"think","plan","alive","hit_t","name"}
var shots: Array = []         # {"p","v","z","o"(owner),"t","dmg"}
var missiles: Array = []      # {"p","v","o","t","target"}
var mines: Array = []         # {"p","o","t"}
var pickups: Array = []       # {"p","kind","t"}
var pickup_t: float = 0.0
var winner: int = -1          # -1 playing, 0 / 1, 2 = both gone
var time: float = 0.0
var rng := RandomNumberGenerator.new()
var events: Array = []        # filled by step(): ["shot", i], ["hit", i, pos], ["boom", pos, size], ["wall", pos], ["pick", i, kind], ["missile", i], ["mine", i], ["dead", i]

# ---------- setup ----------

## types: [type0, type1]; ai: [-1 or level, -1 or level].
func reset(theme_: String, seed_: int, types: Array, ai: Array) -> void:
	theme_id = theme_ if THEMES.has(theme_) else "valley"
	theme = THEMES[theme_id]
	map_seed = seed_
	rng.seed = seed_
	_make_map()
	crafts = []
	var spots := _start_spots()
	for i in 2:
		var c: Dictionary = CRAFTS.get(types[i], CRAFTS.skimmer)
		var p: Vector2 = spots[i]
		crafts.append({"p": p, "v": Vector2.ZERO, "a": (spots[1 - i] - p).angle(), "hp": c.hp, "max": c.hp,
			"type": types[i] if CRAFTS.has(types[i]) else "skimmer", "cd": 0.0, "missiles": c.missiles, "mines": c.mines,
			"shield": 0.0, "ai": int(ai[i]), "think": 0.0, "plan": Vector2.ZERO, "alive": true, "hit_t": 0.0,
			"fire": false, "wiggle": rng.randf() * TAU, "last_d": 1e9, "stuck": 0.0, "detour": 0.0, "detour_a": 0.0})
	shots = []
	missiles = []
	mines = []
	pickups = []
	pickup_t = PICKUP_EVERY * 0.5
	winner = -1
	time = 0.0
	rng.randomize()   # the map is the seed's; the battle's luck is fresh

func _make_map() -> void:
	hgt.resize(GW * GH)
	# Value noise: a few octaves of smoothly blended random lattices.
	var octaves := [[8, 0.55], [16, 0.27], [32, 0.13], [64, 0.05]]
	var lattices: Array = []
	for o in octaves:
		var n: int = o[0]
		var lat := PackedFloat32Array()
		lat.resize((n + 2) * (n + 2))
		for j in lat.size():
			lat[j] = rng.randf()
		lattices.append(lat)
	for y in GH:
		for x in GW:
			var v := 0.0
			for oi in octaves.size():
				var n: int = octaves[oi][0]
				var fx := float(x) / GW * n
				var fy := float(y) / GH * n * float(GH) / GW
				var ix := int(fx)
				var iy := int(fy)
				var tx := _smooth(fx - ix)
				var ty := _smooth(fy - iy)
				var lat: PackedFloat32Array = lattices[oi]
				var s := n + 2
				var a := lerpf(lat[iy * s + ix], lat[iy * s + ix + 1], tx)
				var b := lerpf(lat[(iy + 1) * s + ix], lat[(iy + 1) * s + ix + 1], tx)
				v += lerpf(a, b, ty) * octaves[oi][1]
			hgt[y * GW + x] = clampf((v - 0.5) * 1.6 + 0.5 + theme.bias, 0.0, 1.0)
	for r in int(theme.rivers):
		_carve_river()
	# A border of rock so nobody leaves the map.
	for y in GH:
		for x in GW:
			if x < 2 or y < 2 or x >= GW - 2 or y >= GH - 2:
				hgt[y * GW + x] = 1.0

func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

## A river wanders from one edge to the opposite one, cutting below sea level.
func _carve_river() -> void:
	var horiz := rng.randf() < 0.5
	var p := Vector2(0, rng.randf_range(0.2, 0.8) * GH) if horiz else Vector2(rng.randf_range(0.2, 0.8) * GW, 0)
	var dir := 0.0 if horiz else PI / 2.0
	var base_dir := dir
	var width := rng.randf_range(2.2, 3.6)
	for step in 600:
		dir = clampf(dir + rng.randf_range(-0.35, 0.35), base_dir - 0.9, base_dir + 0.9)
		p += Vector2.RIGHT.rotated(dir) * 1.0
		if p.x < 0 or p.y < 0 or p.x >= GW or p.y >= GH:
			break
		var r := int(ceil(width)) + 1
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x < 0 or y < 0 or x >= GW or y >= GH:
					continue
				var d := Vector2(dx, dy).length()
				if d <= width:
					var depth: float = theme.sea - 0.04 - (width - d) * 0.015
					hgt[y * GW + x] = minf(hgt[y * GW + x], depth)
				elif d <= width + 1.5:
					hgt[y * GW + x] = minf(hgt[y * GW + x], theme.sea + 0.02)

## Two open spots far apart (searched along opposite corners).
func _start_spots() -> Array:
	var out: Array = []
	var corners := [Vector2(0.2, 0.75), Vector2(0.8, 0.25)] if rng.randf() < 0.5 else [Vector2(0.2, 0.25), Vector2(0.8, 0.75)]
	for c in corners:
		var best := Vector2(W * c.x, H * c.y)
		var found := false
		for ring in 40:
			for k in 12:
				var p := Vector2(W * c.x, H * c.y) + Vector2.RIGHT.rotated(TAU * k / 12.0) * ring * 18.0
				if _open(p, CRAFT_R * 2.5):
					best = p
					found = true
					break
			if found:
				break
		if not found:
			_clear_around(best)
		out.append(best)
	return out

func _open(p: Vector2, r: float) -> bool:
	for k in 8:
		if is_rock(p + Vector2.RIGHT.rotated(TAU * k / 8.0) * r) or is_rock(p):
			return false
	return true

func _clear_around(p: Vector2) -> void:
	var cx := int(p.x / CELL)
	var cy := int(p.y / CELL)
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var x := clampi(cx + dx, 2, GW - 3)
			var y := clampi(cy + dy, 2, GH - 3)
			hgt[y * GW + x] = minf(hgt[y * GW + x], theme.sea + 0.1)

# ---------- terrain queries ----------

## Raw terrain height at a world point (bilinear).
func height_at(p: Vector2) -> float:
	var fx := clampf(p.x / CELL - 0.5, 0.0, GW - 1.001)
	var fy := clampf(p.y / CELL - 0.5, 0.0, GH - 1.001)
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	var a := lerpf(hgt[iy * GW + ix], hgt[iy * GW + ix + 1], tx)
	var b := lerpf(hgt[(iy + 1) * GW + ix], hgt[(iy + 1) * GW + ix + 1], tx)
	return lerpf(a, b, ty)

## The surface a craft rides on: liquid is flat at sea level.
func surface_at(p: Vector2) -> float:
	return maxf(height_at(p), theme.sea)

func is_rock(p: Vector2) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
		return true
	return height_at(p) >= theme.rock

func is_liquid(p: Vector2) -> bool:
	return height_at(p) < theme.sea

func cell(x: int, y: int) -> float:
	return hgt[clampi(y, 0, GH - 1) * GW + clampi(x, 0, GW - 1)]

## Would a shot fired at height z from a to b get there? (hills and rock stop it)
func line_clear(a: Vector2, b: Vector2, z: float) -> bool:
	var n := int(a.distance_to(b) / (CELL * 1.5)) + 1
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		if is_rock(p) or surface_at(p) > z:
			return false
	return true

# ---------- stepping ----------

## inputs[i] = {"move": Vector2 (0..1 length), "fire": bool, "missile": bool, "mine": bool};
## AI craft ignore theirs. Returns events.
func step(dt: float, inputs: Array) -> Array:
	events = []
	if winner >= 0:
		_step_effects(dt)
		return events
	time += dt
	for i in 2:
		var c: Dictionary = crafts[i]
		if not c.alive:
			continue
		var inp: Dictionary = _ai_input(i, dt) if c.ai >= 0 else (inputs[i] if i < inputs.size() else {})
		_drive(i, inp.get("move", Vector2.ZERO), dt)
		c.cd = maxf(0.0, c.cd - dt)
		c.shield = maxf(0.0, c.shield - dt)
		c.hit_t = maxf(0.0, c.hit_t - dt)
		if inp.get("fire", false) and c.cd <= 0.0:
			_fire(i)
		if inp.get("missile", false):
			fire_missile(i)
		if inp.get("mine", false):
			drop_mine(i)
		if theme.liquid == "lava" and is_liquid(c.p):
			_damage(i, LAVA_DPS * dt, c.p, false)
	_step_effects(dt)
	_step_pickups(dt)
	_check_end()
	return events

func _drive(i: int, move: Vector2, dt: float) -> void:
	var c: Dictionary = crafts[i]
	var spec: Dictionary = CRAFTS[c.type]
	var m := move.limit_length(1.0)
	if m.length() > 0.08:
		# Turn towards the stick, thrust harder the better we face it.
		var want := m.angle()
		var diff := wrapf(want - c.a, -PI, PI)
		c.a = wrapf(c.a + clampf(diff, -spec.turn * dt, spec.turn * dt), -PI, PI)
		var facing := maxf(0.0, cos(diff))
		c.v += Vector2.RIGHT.rotated(c.a) * spec.accel * m.length() * (0.35 + 0.65 * facing) * dt
	# Hills: climbing slows, going down speeds up.
	var here := surface_at(c.p)
	var grad := Vector2(surface_at(c.p + Vector2(CELL, 0)) - surface_at(c.p - Vector2(CELL, 0)),
		surface_at(c.p + Vector2(0, CELL)) - surface_at(c.p - Vector2(0, CELL))) / (2.0 * CELL)
	c.v -= grad * 15000.0 * dt
	# Friction: liquid and ice are slippery.
	var slick: bool = is_liquid(c.p) or (theme.ice and here > theme.sea + 0.05)
	var fr := 0.9 if slick else 2.6
	c.v *= maxf(0.0, 1.0 - fr * dt)
	var top: float = spec.speed * (1.1 if slick else 1.0)
	c.v = c.v.limit_length(top)
	var np: Vector2 = c.p + c.v * dt
	if _blocked(np):
		# Slide along the cliff: try each axis, else bounce.
		var nx := Vector2(np.x, c.p.y)
		var ny := Vector2(c.p.x, np.y)
		var speed: float = c.v.length()
		if not _blocked(nx):
			np = nx
			c.v.y *= -0.3
		elif not _blocked(ny):
			np = ny
			c.v.x *= -0.3
		else:
			np = c.p
			c.v *= -0.4
		if speed > 220.0:
			_damage(i, (speed - 220.0) * 0.04, c.p, false)
			events.append(["wall", c.p])
	c.p = np
	# Craft bump each other.
	var o: Dictionary = crafts[1 - i]
	if o.alive and c.p.distance_to(o.p) < CRAFT_R * 2.0:
		var push: Vector2 = (c.p - o.p).normalized() * (CRAFT_R * 2.0 - c.p.distance_to(o.p))
		if not _blocked(c.p + push):
			c.p += push
		c.v += push * 8.0

func _blocked(p: Vector2) -> bool:
	if is_rock(p):
		return true
	for k in 8:
		if is_rock(p + Vector2.RIGHT.rotated(TAU * k / 8.0) * CRAFT_R * 0.8):
			return true
	return false

func _fire(i: int) -> void:
	var c: Dictionary = crafts[i]
	var spec: Dictionary = CRAFTS[c.type]
	c.cd = spec.cd
	var dir := Vector2.RIGHT.rotated(c.a)
	var side := dir.orthogonal() * (7.0 if int(time * 1000.0 / (spec.cd * 1000.0)) % 2 == 0 else -7.0)
	shots.append({"p": c.p + dir * CRAFT_R + side, "v": dir * SHOT_SPEED + c.v * 0.5, "z": surface_at(c.p) + HOVER,
		"o": i, "t": SHOT_LIFE, "dmg": spec.dmg})
	events.append(["shot", i])

func fire_missile(i: int) -> bool:
	var c: Dictionary = crafts[i]
	if not c.alive or c.missiles <= 0 or winner >= 0:
		return false
	c.missiles -= 1
	var dir := Vector2.RIGHT.rotated(c.a)
	missiles.append({"p": c.p + dir * CRAFT_R, "v": dir * MISSILE_SPEED, "o": i, "t": MISSILE_LIFE})
	events.append(["missile", i])
	return true

func drop_mine(i: int) -> bool:
	var c: Dictionary = crafts[i]
	if not c.alive or c.mines <= 0 or winner >= 0:
		return false
	c.mines -= 1
	mines.append({"p": c.p - Vector2.RIGHT.rotated(c.a) * (CRAFT_R + 6.0), "o": i, "t": 0.0})
	events.append(["mine", i])
	return true

func _step_effects(dt: float) -> void:
	for s in shots:
		s.p += s.v * dt
		s.t -= dt
		if is_rock(s.p) or surface_at(s.p) > s.z:
			s.t = -1.0
			events.append(["wall", s.p])
			continue
		for j in 2:
			var c: Dictionary = crafts[j]
			if j != s.o and c.alive and s.p.distance_to(c.p) < CRAFT_R:
				_damage(j, s.dmg, s.p, true)
				s.t = -1.0
				break
	shots = shots.filter(func(s): return s.t > 0.0)
	for m in missiles:
		var target: Dictionary = crafts[1 - m.o]
		if target.alive:
			var want: float = (target.p - m.p).angle()
			var cur: float = m.v.angle()
			var d := clampf(wrapf(want - cur, -PI, PI), -MISSILE_TURN * dt, MISSILE_TURN * dt)
			m.v = Vector2.RIGHT.rotated(cur + d) * MISSILE_SPEED
		m.p += m.v * dt
		m.t -= dt
		if is_rock(m.p):
			m.t = -1.0
			events.append(["boom", m.p, 0.6])
		elif target.alive and m.p.distance_to(target.p) < CRAFT_R + 4.0:
			_damage(1 - m.o, MISSILE_DMG, m.p, true)
			events.append(["boom", m.p, 1.0])
			m.t = -1.0
		elif m.t <= 0.0:
			events.append(["boom", m.p, 0.5])
	missiles = missiles.filter(func(m): return m.t > 0.0)
	for mn in mines:
		mn.t += dt
		if mn.t < MINE_ARM:
			continue
		for j in 2:
			var c: Dictionary = crafts[j]
			if c.alive and mn.p.distance_to(c.p) < MINE_R:
				_damage(j, MINE_DMG, mn.p, true)
				events.append(["boom", mn.p, 1.3])
				mn.t = -99.0
				break
	mines = mines.filter(func(m): return m.t > -50.0)

func _step_pickups(dt: float) -> void:
	pickup_t -= dt
	if pickup_t <= 0.0 and pickups.size() < PICKUP_MAX:
		pickup_t = PICKUP_EVERY
		for tries in 30:
			var p := Vector2(rng.randf_range(80, W - 80), rng.randf_range(80, H - 80))
			if not _blocked(p) and not (theme.liquid == "lava" and is_liquid(p)):
				pickups.append({"p": p, "kind": KINDS[rng.randi() % KINDS.size()], "t": 0.0})
				break
	for pk in pickups:
		pk.t += dt
		for j in 2:
			var c: Dictionary = crafts[j]
			if c.alive and c.p.distance_to(pk.p) < CRAFT_R + 16.0:
				_take(j, pk.kind)
				pk.t = -1.0
				break
	pickups = pickups.filter(func(pk): return pk.t >= 0.0)

func _take(i: int, kind: String) -> void:
	var c: Dictionary = crafts[i]
	match kind:
		"repair":
			c.hp = minf(c.max, c.hp + c.max * 0.3)
		"missiles":
			c.missiles += 2
		"mines":
			c.mines += 2
		"shield":
			c.shield = 6.0
	events.append(["pick", i, kind])

func _damage(i: int, amount: float, at: Vector2, loud: bool) -> void:
	var c: Dictionary = crafts[i]
	if not c.alive or c.shield > 0.0:
		return
	c.hp -= amount
	c.hit_t = 0.25
	if loud:
		events.append(["hit", i, at])
	if c.hp <= 0.0:
		c.hp = 0.0
		c.alive = false
		events.append(["boom", c.p, 2.2])
		events.append(["dead", i])

func _check_end() -> void:
	var a: bool = crafts[0].alive
	var b: bool = crafts[1].alive
	if a and b:
		return
	winner = 2 if not a and not b else (0 if a else 1)

func is_over() -> bool:
	return winner >= 0

## A human's helper (❤ repair, campaign / vs CPU only).
func repair(i: int) -> bool:
	var c: Dictionary = crafts[i]
	if not c.alive or c.hp >= c.max:
		return false
	c.hp = c.max
	return true

# ---------- the computer pilot ----------

func _ai_input(i: int, dt: float) -> Dictionary:
	var c: Dictionary = crafts[i]
	var o: Dictionary = crafts[1 - i]
	var lv: Dictionary = AI[clampi(c.ai, 0, AI.size() - 1)]
	var out := {"move": Vector2.ZERO, "fire": false, "missile": false, "mine": false}
	if not o.alive:
		return out
	c.think -= dt
	c.detour = maxf(0.0, c.detour - dt)
	var to: Vector2 = o.p - c.p
	var dist := to.length()
	var z := surface_at(c.p) + HOVER
	if c.think <= 0.0:
		c.think = lv.react
		c.wiggle += rng.randf_range(-0.25, 0.25)
		# Where to go: hurt and a repair nearby -> fetch it; else hold ~260 away, circling.
		var goal: Vector2 = o.p
		var best_pk = null
		for pk in pickups:
			var d: float = c.p.distance_to(pk.p)
			var wants: bool = (pk.kind == "repair" and c.hp < c.max * 0.6) or d < 260.0
			if wants and (best_pk == null or d < c.p.distance_to(best_pk.p)):
				best_pk = pk
		if best_pk != null:
			goal = best_pk.p
			c.plan = (goal - c.p).normalized()
		else:
			# Pick a firing spot ~260 from the enemy with a clear line, high ground preferred.
			var best: Vector2 = c.p
			var best_score := -1e9
			for k in 10:
				var cand: Vector2 = o.p + Vector2.RIGHT.rotated(c.wiggle + TAU * k / 10.0) * 260.0
				if _blocked(cand) or (theme.liquid == "lava" and is_liquid(cand)):
					continue
				var score: float = surface_at(cand) * 3.0 - c.p.distance_to(cand) / 500.0
				if line_clear(cand, o.p, surface_at(cand) + HOVER):
					score += 3.0
				if score > best_score:
					best_score = score
					best = cand
			var radial := to.normalized()
			var tangent := radial.orthogonal() * (1.0 if sin(c.wiggle) > 0.0 else -1.0)
			if c.p.distance_to(best) > 90.0:
				c.plan = (best - c.p).normalized()
			elif dist < 180.0:
				c.plan = (-radial * 0.6 + tangent).normalized()
			else:
				c.plan = (tangent * 0.6 + radial * 0.1).normalized()
		# Not getting any closer while far apart (a cliff or lake in the way)? Take a detour.
		if (dist > 300.0 or not line_clear(c.p, o.p, z)) and dist > c.last_d - 15.0:
			c.stuck += lv.react
		else:
			c.stuck = maxf(0.0, c.stuck - lv.react)
		c.last_d = dist
		if c.stuck > 2.0:
			c.stuck = 0.0
			c.detour = 2.5
			c.detour_a = rng.randf_range(1.0, 2.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		if c.detour > 0.0:
			c.plan = to.normalized().rotated(c.detour_a)
		c.plan = _avoid(c, c.plan)
	# Face the enemy (with lead) when close enough to shoot, else face the way we go.
	var lead: Vector2 = o.p + o.v * (dist / SHOT_SPEED) * lv.lead
	var aim_dir: Vector2 = (lead - c.p).normalized().rotated(sin(time * 2.3 + i) * lv.err)
	var move: Vector2 = c.plan
	var clear := line_clear(c.p, o.p, z)
	if dist < 520.0 and clear and c.detour <= 0.0:
		# Blend: steer the nose to the target while drifting along the plan.
		var nose: Vector2 = aim_dir
		var diff := absf(wrapf(nose.angle() - c.a, -PI, PI))
		move = (nose * 0.75 + c.plan * 0.45).normalized() if diff > 0.25 else (c.plan * 0.6 + nose * 0.4).normalized()
		var facing := absf(wrapf(aim_dir.angle() - c.a, -PI, PI))
		if facing < 0.18 + lv.err:
			out.fire = true
		if c.missiles > 0 and facing < 0.6 and dist > 200.0 and rng.randf() < lv.special * dt * 0.5:
			out.missile = true
	if c.mines > 0 and dist < 160.0 and rng.randf() < lv.special * dt * 0.6:
		out.mine = true
	# Dodge mines it can see.
	for mn in mines:
		if mn.o != i and c.p.distance_to(mn.p) < MINE_R * 2.4:
			move = (move + (c.p - mn.p).normalized() * 1.5).normalized()
	out.move = move
	return out

## Bend a wanted direction away from cliffs ahead.
func _avoid(c: Dictionary, want: Vector2) -> Vector2:
	if want == Vector2.ZERO:
		return want
	for k in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.4, -2.4, PI]:
		var d := want.rotated(k)
		var ok := true
		for r in [40.0, 80.0, 120.0]:
			if is_rock(c.p + d * r):
				ok = false
				break
		if ok and not (theme.liquid == "lava" and is_liquid(c.p + d * 90.0) and not is_liquid(c.p)):
			return d
	return want

# ---------- save ----------

func to_dict() -> Dictionary:
	var cs: Array = []
	for c in crafts:
		cs.append({"p": [c.p.x, c.p.y], "v": [c.v.x, c.v.y], "a": c.a, "hp": c.hp, "max": c.max, "type": c.type,
			"missiles": c.missiles, "mines": c.mines, "shield": c.shield, "ai": c.ai, "alive": c.alive})
	var ms: Array = []
	for m in mines:
		ms.append({"p": [m.p.x, m.p.y], "o": m.o, "t": m.t})
	var ps: Array = []
	for pk in pickups:
		ps.append({"p": [pk.p.x, pk.p.y], "kind": pk.kind})
	return {"theme": theme_id, "seed": map_seed, "crafts": cs, "mines": ms, "pickups": ps, "time": time}

func from_dict(d: Dictionary) -> void:
	var cs: Array = d.get("crafts", [])
	var types := ["skimmer", "skimmer"]
	var ai := [-1, 1]
	for i in mini(2, cs.size()):
		types[i] = str(cs[i].get("type", "skimmer"))
		ai[i] = int(cs[i].get("ai", -1))
	reset(str(d.get("theme", "valley")), int(d.get("seed", 1)), types, ai)
	for i in mini(2, cs.size()):
		var s: Dictionary = cs[i]
		var c: Dictionary = crafts[i]
		c.p = Vector2(float(s.p[0]), float(s.p[1]))
		c.v = Vector2(float(s.v[0]), float(s.v[1]))
		c.a = float(s.a)
		c.hp = float(s.hp)
		c.max = float(s.get("max", c.max))
		c.missiles = int(s.missiles)
		c.mines = int(s.mines)
		c.shield = float(s.get("shield", 0.0))
		c.alive = bool(s.get("alive", true))
	for m in d.get("mines", []):
		mines.append({"p": Vector2(float(m.p[0]), float(m.p[1])), "o": int(m.o), "t": float(m.t)})
	for pk in d.get("pickups", []):
		pickups.append({"p": Vector2(float(pk.p[0]), float(pk.p[1])), "kind": str(pk.kind), "t": 0.0})
	time = float(d.get("time", 0.0))
