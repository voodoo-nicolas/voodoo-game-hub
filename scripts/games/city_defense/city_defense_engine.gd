extends RefCounted

## City Defense: enemy missiles streak down at six cities. Tap the sky and
## the nearest of three bases fires an interceptor there; it bursts into a
## fireball that destroys any missile it touches (and their own blasts set
## off more). Survive each wave; leftover cities and ammo score a bonus.
## Pure simulation in world units (no Nodes), stepped by the game.

const CITIES := 6
const BASES := 3
const AMMO := 10
const BLAST_R := 62.0
const BLAST_TIME := 1.1        # grow then shrink
const INTERCEPTOR_SPEED := 760.0
const CITY_BONUS := 100
const AMMO_BONUS := 5
const NEW_CITY_EVERY := 10000

var size := Vector2(720, 1000)
var ground: float = 900.0
var cities: Array = []     # {"x", "alive"}
var bases: Array = []      # {"x", "ammo", "alive"}
var enemies: Array = []    # {"p", "from", "to", "v", "split_at"}
var shots: Array = []      # {"p", "to", "v"}
var blasts: Array = []     # {"p", "t", "enemy": bool}
var wave: int = 0
var score: int = 0
var to_launch: int = 0
var launch_timer: float = 0.0
var spare_cities: int = 0
var next_city: int = NEW_CITY_EVERY
var over := false
var between := false        # wave done, bonus counted, waiting for the next
var rng := RandomNumberGenerator.new()

func reset(world: Vector2, seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	resize(world)
	cities = []
	bases = []
	for i in CITIES:
		cities.append({"x": 0.0, "alive": true})
	for i in BASES:
		bases.append({"x": 0.0, "ammo": AMMO, "alive": true})
	_place()
	score = 0
	wave = 0
	spare_cities = 0
	next_city = NEW_CITY_EVERY
	over = false
	start_wave()

func resize(world: Vector2) -> void:
	size = world
	ground = size.y - 70.0
	if not cities.is_empty():
		_place()

## Bases at the left, middle and right; three cities in each gap.
func _place() -> void:
	var w := size.x
	var bx := [w * 0.07, w * 0.5, w * 0.93]
	for i in BASES:
		bases[i].x = bx[i]
	var cx := [w * 0.19, w * 0.29, w * 0.39, w * 0.61, w * 0.71, w * 0.81]
	for i in CITIES:
		cities[i].x = cx[i]

func start_wave() -> void:
	wave += 1
	between = false
	for b in bases:
		b.ammo = AMMO
		b.alive = true
	enemies = []
	shots = []
	blasts = []
	to_launch = 8 + wave * 3
	launch_timer = 1.0

func speed() -> float:
	return 55.0 + wave * 9.0

func _targets() -> Array:
	var out: Array = []
	for c in cities:
		if c.alive:
			out.append(Vector2(c.x, ground))
	for b in bases:
		if b.alive:
			out.append(Vector2(b.x, ground))
	return out

func _launch(from: Vector2) -> void:
	var t := _targets()
	if t.is_empty():
		return
	var to: Vector2 = t[rng.randi_range(0, t.size() - 1)]
	var split := -1.0
	if wave >= 3 and rng.randf() < 0.18:
		split = rng.randf_range(ground * 0.25, ground * 0.5)
	enemies.append({"p": from, "from": from, "to": to, "v": (to - from).normalized() * speed() * rng.randf_range(0.85, 1.2), "split_at": split})

## Fire at a point in the sky from the nearest base that still has ammo.
func fire(at: Vector2) -> bool:
	if over or between or at.y > ground - 30.0:
		return false
	var best := -1
	var best_d := INF
	for i in BASES:
		var b: Dictionary = bases[i]
		if b.alive and b.ammo > 0:
			var d := absf(b.x - at.x)
			if d < best_d:
				best_d = d
				best = i
	if best < 0:
		return false
	bases[best].ammo -= 1
	var from := Vector2(bases[best].x, ground - 18.0)
	shots.append({"p": from, "to": at, "v": (at - from).normalized() * INTERCEPTOR_SPEED})
	return true

func blast_radius(b: Dictionary) -> float:
	var k: float = b.t / BLAST_TIME
	return BLAST_R * (sin(k * PI)) * (0.7 if b.enemy else 1.0)

## One frame. Events: ["boom", pos], ["city", index], ["base", index], ["kill"], ["wave_done", bonus], ["city_back"], ["over"].
func step(dt: float) -> Array:
	var ev: Array = []
	if over or between:
		return ev
	if to_launch > 0:
		launch_timer -= dt
		if launch_timer <= 0.0:
			launch_timer = rng.randf_range(0.35, 1.3) / (1.0 + wave * 0.08)
			var n := mini(to_launch, rng.randi_range(1, 2 + wave / 3))
			for k in n:
				_launch(Vector2(rng.randf() * size.x, -10.0))
			to_launch -= n
	for s in shots:
		var step_v: Vector2 = s.v * dt
		if s.p.distance_to(s.to) <= step_v.length():
			s.p = s.to
			s.done = true
			blasts.append({"p": s.to, "t": 0.0, "enemy": false})
			ev.append(["boom", s.to])
		else:
			s.p += step_v
	shots = shots.filter(func(s): return not s.get("done", false))
	for b in blasts:
		b.t += dt
	blasts = blasts.filter(func(b): return b.t < BLAST_TIME)
	var survivors: Array = []
	for e in enemies:
		e.p += e.v * dt
		var killed := false
		for b in blasts:
			if e.p.distance_to(b.p) < blast_radius(b):
				killed = true
				break
		if killed:
			score += 25
			_check_city_back(ev)
			blasts.append({"p": e.p, "t": 0.0, "enemy": true})
			ev.append(["kill"])
			continue
		if e.split_at > 0.0 and e.p.y >= e.split_at:
			e.split_at = -1.0
			for k in 2:
				var t := _targets()
				if not t.is_empty():
					var to: Vector2 = t[rng.randi_range(0, t.size() - 1)]
					survivors.append({"p": e.p, "from": e.p, "to": to, "v": (to - e.p).normalized() * e.v.length(), "split_at": -1.0})
		if e.p.y >= ground or e.p.distance_to(e.to) < 6.0:
			_hit_ground(e.to, ev)
			continue
		survivors.append(e)
	enemies = survivors
	if to_launch == 0 and enemies.is_empty() and blasts.is_empty() and shots.is_empty():
		_end_wave(ev)
	return ev

func _hit_ground(at: Vector2, ev: Array) -> void:
	blasts.append({"p": at, "t": 0.0, "enemy": true})
	ev.append(["boom", at])
	for i in CITIES:
		if cities[i].alive and absf(cities[i].x - at.x) < 24.0:
			cities[i].alive = false
			ev.append(["city", i])
	for i in BASES:
		if bases[i].alive and absf(bases[i].x - at.x) < 24.0:
			bases[i].alive = false
			bases[i].ammo = 0
			ev.append(["base", i])

func _check_city_back(ev: Array) -> void:
	if score >= next_city:
		next_city += NEW_CITY_EVERY
		spare_cities += 1
		ev.append(["city_back"])

func cities_left() -> int:
	var n := 0
	for c in cities:
		if c.alive:
			n += 1
	return n

func _end_wave(ev: Array) -> void:
	if cities_left() == 0:
		over = true
		ev.append(["over"])
		return
	var ammo := 0
	for b in bases:
		ammo += b.ammo
	var bonus := cities_left() * CITY_BONUS * mini(wave, 6) + ammo * AMMO_BONUS * mini(wave, 6)
	score += bonus
	_check_city_back(ev)
	# Spare cities rebuild ruined ones.
	for c in cities:
		if not c.alive and spare_cities > 0:
			c.alive = true
			spare_cities -= 1
	between = true
	ev.append(["wave_done", bonus])
