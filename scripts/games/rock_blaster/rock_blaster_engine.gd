extends RefCounted

## Rock Blaster: a ship drifts through a field of space rocks that wraps at
## the edges. Shots split big rocks into two medium ones, medium into two
## small, small into dust. Clear the field for the next, bigger wave.
## Pure simulation (positions in world units, no Nodes), stepped by the game.

const SHIP_R := 14.0
const ROCK_R := [46.0, 26.0, 14.0]       # big, medium, small
const ROCK_POINTS := [20, 50, 100]
const ROCK_SPEED := [42.0, 70.0, 105.0]
const BULLET_SPEED := 520.0
const BULLET_LIFE := 0.9
const FIRE_GAP := 0.18
const THRUST := 330.0
const DRAG := 0.55          # fraction of speed kept per second
const MAX_SPEED := 340.0
const TURN_RATE := 9.0      # radians/s the ship turns towards where it's aiming
const SAFE_TIME := 2.2
const EXTRA_LIFE_EVERY := 10000

var size := Vector2(720, 1000)
var ship_pos := Vector2.ZERO
var ship_vel := Vector2.ZERO
var ship_angle := -PI / 2.0   # pointing up
var safe: float = 0.0          # invulnerable seconds left
var alive := true
var respawn: float = 0.0
var lives: int = 3
var score: int = 0
var wave: int = 0
var rocks: Array = []    # {"p": Vector2, "v": Vector2, "s": 0..2, "shape": PackedVector2Array, "rot": float, "spin": float}
var bullets: Array = []  # {"p", "v", "t"}
var cooldown: float = 0.0
var over := false
var next_life: int = EXTRA_LIFE_EVERY
var rng := RandomNumberGenerator.new()

func reset(world: Vector2, seed_: int = -1) -> void:
	size = world
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	lives = 3
	score = 0
	wave = 0
	over = false
	next_life = EXTRA_LIFE_EVERY
	bullets = []
	_spawn_ship()
	next_wave()

func _spawn_ship() -> void:
	ship_pos = size / 2.0
	ship_vel = Vector2.ZERO
	ship_angle = -PI / 2.0
	safe = SAFE_TIME
	alive = true

func next_wave() -> void:
	wave += 1
	rocks = []
	for i in mini(3 + wave, 10):
		var p := Vector2.ZERO
		# Start well away from the ship.
		for tries in 20:
			p = Vector2(rng.randf() * size.x, rng.randf() * size.y)
			if p.distance_to(ship_pos) > 220.0:
				break
		rocks.append(_rock(p, 0))

func _rock(p: Vector2, s: int) -> Dictionary:
	var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
	var speed: float = ROCK_SPEED[s] * rng.randf_range(0.7, 1.3) * (1.0 + 0.06 * (wave - 1))
	var shape := PackedVector2Array()
	var n := 9 + s
	for k in n:
		shape.append(Vector2.RIGHT.rotated(TAU * k / n) * rng.randf_range(0.72, 1.08))
	return {"p": p, "v": dir * speed, "s": s, "shape": shape, "rot": rng.randf() * TAU, "spin": rng.randf_range(-1.5, 1.5)}

## One frame. `aim` = where the player is pointing (or null), `thrust` and
## `fire` booleans. Returns events: [["boom", pos, size], ["hit"], ["shot"], ["wave"], ["life"]].
func step(dt: float, aim: Variant, thrust: bool, fire: bool) -> Array:
	var events: Array = []
	if over:
		return events
	if not alive:
		respawn -= dt
		if respawn <= 0.0 and lives > 0:
			_spawn_ship()
	else:
		if aim != null:
			var want: float = (Vector2(aim) - ship_pos).angle()
			ship_angle = rotate_toward(ship_angle, want, TURN_RATE * dt)
		if thrust:
			ship_vel += Vector2.RIGHT.rotated(ship_angle) * THRUST * dt
		ship_vel *= pow(DRAG, dt)
		if ship_vel.length() > MAX_SPEED:
			ship_vel = ship_vel.normalized() * MAX_SPEED
		ship_pos = _wrap(ship_pos + ship_vel * dt)
		safe = maxf(0.0, safe - dt)
		cooldown -= dt
		if fire and cooldown <= 0.0:
			cooldown = FIRE_GAP
			var dir := Vector2.RIGHT.rotated(ship_angle)
			bullets.append({"p": ship_pos + dir * SHIP_R, "v": dir * BULLET_SPEED + ship_vel * 0.5, "t": BULLET_LIFE})
			events.append(["shot"])
	for b in bullets:
		b.p = _wrap(b.p + b.v * dt)
		b.t -= dt
	bullets = bullets.filter(func(b): return b.t > 0.0)
	for r in rocks:
		r.p = _wrap(r.p + r.v * dt)
		r.rot += r.spin * dt
	# Bullets against rocks.
	var new_rocks: Array = []
	for r in rocks:
		var hit := false
		for b in bullets:
			if b.t > 0.0 and _dist(b.p, r.p) < ROCK_R[r.s]:
				b.t = 0.0
				hit = true
				break
		if hit:
			_add_score(ROCK_POINTS[r.s], events)
			events.append(["boom", r.p, r.s])
			if r.s < 2:
				for k in 2:
					var child := _rock(r.p, r.s + 1)
					child.v = (r.v + child.v).limit_length(ROCK_SPEED[r.s + 1] * 1.6)
					new_rocks.append(child)
		else:
			new_rocks.append(r)
	rocks = new_rocks
	bullets = bullets.filter(func(b): return b.t > 0.0)
	# Rocks against the ship.
	if alive and safe <= 0.0:
		for r in rocks:
			if _dist(ship_pos, r.p) < ROCK_R[r.s] + SHIP_R * 0.7:
				alive = false
				lives -= 1
				respawn = 1.6
				events.append(["hit"])
				events.append(["boom", ship_pos, 0])
				if lives <= 0:
					over = true
				break
	if rocks.is_empty():
		next_wave()
		safe = maxf(safe, 1.2)
		events.append(["wave"])
	return events

func _add_score(pts: int, events: Array) -> void:
	score += pts
	if score >= next_life:
		next_life += EXTRA_LIFE_EVERY
		lives += 1
		events.append(["life"])

func _wrap(p: Vector2) -> Vector2:
	return Vector2(fposmod(p.x, size.x), fposmod(p.y, size.y))

## Distance on the wrapping field.
func _dist(a: Vector2, b: Vector2) -> float:
	var d := (a - b).abs()
	d.x = minf(d.x, size.x - d.x)
	d.y = minf(d.y, size.y - d.y)
	return d.length()
