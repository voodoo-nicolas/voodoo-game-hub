extends RefCounted

## Pure movement/collision math for Geometry Wars, kept free of any Node/rendering
## code so it can be exercised headlessly. Entities are plain Dictionaries:
## enemy = {id, type, pos, vel, hp, t, warm, ...}, bullet = {pos, vel, life},
## crystal ("geom") = {pos, age, v}.
##
## Everything is measured in grid squares: `U` is one square in pixels (the
## arena is 19 squares tall, like the original's 29 x 19 map), and speeds are
## written in squares per second. The player's top speed is 9.5 squares/s.
##
## Enemies (behaviour follows the community enemy guide):
##   wanderer purple pinwheel  drifts 3 sq/s, new heading each second (favours
##                             its current one), bounces off walls
##   duck     pink square      hops one square a second, slowly follows you
##   rocket   orange arrow     straight line 10 sq/s, turns round at the wall
##   neutron  teal ring        straight line 8 sq/s, perfect wall reflection
##   gear     golden cross     hunts geoms; eats them and speeds up; pops
##   grunt    blue diamond     chases you; gets faster the longer it lives
##   mayfly   tiny triangle    comes in hordes, glides at you; a bullet pierces
##   weaver   green square     chases with inertia and dodges your bullets
##   spinner  pink X box       fast chaser with inertia; splits into 3 minis
##   mini     small spinner    the child of a spinner
##   snake    blue head + body only the head can be killed, the body eats shots
##   well     gravity well     shoot it to wake it: it pulls everything in
##   proton   cyan ring        what an overfed well bursts into
##   ufo      red saucer       one fast pass at you; worth a fortune

static var U := 30.0

const PLAYER_TOP_SPEED := 9.5

const POINTS := {
	"grunt": 10, "wanderer": 5, "duck": 5, "rocket": 15, "neutron": 10, "gear": 10,
	"mayfly": 5, "weaver": 25, "spinner": 25, "mini": 10, "snake": 35, "well": 500,
	"proton": 10, "ufo": 2800,
}
## How many geoms a kill drops (a well drops more for what it swallowed).
const GEOMS := {
	"grunt": 2, "wanderer": 2, "duck": 2, "rocket": 4, "neutron": 2, "gear": 1,
	"mayfly": 1, "weaver": 2, "spinner": 2, "mini": 1, "snake": 7, "well": 3,
	"proton": 1, "ufo": 2,
}
## Radius of each enemy in squares.
const RADIUS := {
	"grunt": 0.5, "wanderer": 0.5, "duck": 0.5, "rocket": 0.5, "neutron": 0.5, "gear": 0.5,
	"mayfly": 0.3, "weaver": 0.5, "spinner": 0.55, "mini": 0.35, "snake": 0.45, "well": 0.8,
	"proton": 0.35, "ufo": 0.7,
}
const COLORS := {
	"grunt": Color(0.25, 0.65, 1.0), "wanderer": Color(0.8, 0.35, 1.0), "duck": Color(1.0, 0.4, 0.85),
	"rocket": Color(1.0, 0.5, 0.15), "neutron": Color(0.2, 1.0, 0.8), "gear": Color(1.0, 0.85, 0.2),
	"mayfly": Color(0.65, 0.55, 1.0), "weaver": Color(0.35, 1.0, 0.35), "spinner": Color(1.0, 0.35, 0.55),
	"mini": Color(1.0, 0.45, 0.65), "snake": Color(0.3, 0.7, 1.0), "well": Color(1.0, 0.45, 0.2),
	"proton": Color(0.4, 0.9, 1.0), "ufo": Color(1.0, 0.2, 0.35),
}

const WARM_TIME := 0.9
const WELL_HP := 20
const WELL_RANGE := 7.0
const WELL_BURST_AT := 12
const SNAKE_SEGMENTS := 9
const SNAKE_GAP := 0.55
const DODGE_RANGE := 3.0

const CRYSTAL_LIFE := 3.0
const CRYSTAL_MAGNET := 4.0
const CRYSTAL_PICKUP := 0.9
const CRYSTAL_PULL := 14.0

## Types that reflect off the walls (others clamp, rockets turn round).
const BOUNCERS := ["wanderer", "neutron", "gear", "proton", "weaver", "spinner", "mini"]

static func radius_of(type: String) -> float:
	return float(RADIUS.get(type, 0.5)) * U

static func color_of(type: String) -> Color:
	return COLORS.get(type, Color.WHITE)

# ---------- spawning ----------

## Which types can appear `elapsed` seconds in, with weights.
static func spawn_table(elapsed: float) -> Dictionary:
	var table := {"grunt": 4.0, "wanderer": 3.0, "duck": 2.0}
	if elapsed > 12.0:
		table["weaver"] = 2.0
		table["neutron"] = 1.5
	if elapsed > 25.0:
		table["rocket"] = 1.2
		table["mayfly"] = 0.9
	if elapsed > 35.0:
		table["spinner"] = 2.0
	if elapsed > 55.0:
		table["snake"] = 1.0
	if elapsed > 70.0:
		table["gear"] = 0.6
	if elapsed > 85.0:
		table["well"] = 0.7
	if elapsed > 140.0:
		table["ufo"] = 0.15
	return table

static func spawn_type(elapsed: float) -> String:
	var table := spawn_table(elapsed)
	var total := 0.0
	for k in table:
		total += table[k]
	var roll := randf() * total
	for k in table:
		roll -= table[k]
		if roll <= 0.0:
			return k
	return "grunt"

## A random spot at least `min_dist` squares from the player.
static func spawn_point(arena_size: Vector2, player_pos: Vector2, min_dist: float = 7.0) -> Vector2:
	var p := Vector2(randf() * arena_size.x, randf() * arena_size.y)
	for i in 12:
		if p.distance_to(player_pos) >= min_dist * U:
			break
		p = Vector2(randf() * arena_size.x, randf() * arena_size.y)
	return p

## One spawn event: usually a single enemy, sometimes a group (a mayfly horde
## from a corner, a line of rockets). Ids are left 0 for the caller to fill.
static func spawn_group(arena_size: Vector2, elapsed: float, player_pos: Vector2) -> Array:
	var type := spawn_type(elapsed)
	var out: Array = []
	match type:
		"mayfly":
			var corner := Vector2(0.0 if randf() < 0.5 else arena_size.x, 0.0 if randf() < 0.5 else arena_size.y)
			for i in 12 + randi() % 8:
				var off := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * U
				var p := (corner + off).clamp(Vector2.ZERO, arena_size)
				out.append(make_enemy(0, "mayfly", p, WARM_TIME + randf() * 0.3))
		"rocket":
			var side := randi() % 4
			var dir: Vector2 = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP][side]
			var perp := Vector2(-dir.y, dir.x)
			var start := Vector2(arena_size.x * 0.5, arena_size.y * 0.5) - dir * (arena_size * 0.5 - Vector2(U, U)) * 0.98
			var count := 3 + randi() % 3
			var center_shift := randf_range(-0.25, 0.25)
			for i in count:
				var p := start + perp * ((i - (count - 1) / 2.0) * 1.3 * U) + perp * center_shift * arena_size.length()
				p = p.clamp(Vector2(U * 0.5, U * 0.5), arena_size - Vector2(U * 0.5, U * 0.5))
				var r := make_enemy(0, "rocket", p, WARM_TIME)
				r.dir = dir
				out.append(r)
		"ufo":
			var edge := randi() % 4
			var p := Vector2.ZERO
			match edge:
				0: p = Vector2(randf() * arena_size.x, U * 0.5)
				1: p = Vector2(randf() * arena_size.x, arena_size.y - U * 0.5)
				2: p = Vector2(U * 0.5, randf() * arena_size.y)
				_: p = Vector2(arena_size.x - U * 0.5, randf() * arena_size.y)
			var u := make_enemy(0, "ufo", p, 1.1)
			u.aim = player_pos
			out.append(u)
		_:
			out.append(make_enemy(0, type, spawn_point(arena_size, player_pos), WARM_TIME))
	return out

static func make_enemy(id: int, type: String, pos: Vector2, warm: float = 0.0) -> Dictionary:
	# Saves from before the v0.24 enemy set.
	match type:
		"seeker", "tank":
			type = "grunt"
		"splitter":
			type = "spinner"
		"dart":
			type = "rocket"
	var angle := randf() * TAU
	var dir := Vector2(cos(angle), sin(angle))
	var e := {"id": id, "type": type, "pos": pos, "vel": Vector2.ZERO, "hp": 1, "t": 0.0, "warm": warm}
	match type:
		"wanderer":
			e.vel = dir * 3.0 * U
			e.turn_t = randf()
		"neutron":
			e.vel = dir * 8.0 * U
		"duck":
			e.step_t = randf()
			e.move_t = 0.0
		"rocket":
			e.dir = dir
			e.slow = 1.0
		"gear":
			e.vel = dir * 2.0 * U
			e.eaten = 0
		"mayfly":
			e.phase = randf() * TAU
		"snake":
			var segs: Array = []
			for i in SNAKE_SEGMENTS:
				segs.append(pos - dir * SNAKE_GAP * U * (i + 1))
			e.segs = segs
		"well":
			e.hp = WELL_HP
			e.active = false
			e.eaten = 0
		"ufo":
			e.aim = pos  # spawn_group() aims it at the player
	return e

# ---------- movement ----------

## Moves everything one step. Returns events the caller must act on:
## {kind: "well_burst", pos, n} (an overfed well, already removed),
## {kind: "gear_pop", pos} (a gear that ate its fill, already removed).
static func update_enemies(enemies: Array, player_pos: Vector2, arena_size: Vector2, delta: float, bullets: Array = [], crystals: Array = []) -> Array:
	var events: Array = []
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		e.t = float(e.t) + delta
		if e.warm > 0.0:
			e.warm = float(e.warm) - delta
			continue
		var pos: Vector2 = e.pos
		var vel: Vector2 = e.vel
		var to_player: Vector2 = player_pos - pos
		var chase: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO
		match e.type:
			"grunt":
				vel = chase * grunt_speed(e.t) * U
			"wanderer":
				e.turn_t = float(e.turn_t) - delta
				if e.turn_t <= 0.0:
					e.turn_t = 1.0
					# A bell curve around "keep going": a U-turn is out of reach.
					vel = vel.rotated(clampf(randfn(0.0, 0.5), -1.5, 1.5))
			"duck":
				e.step_t = float(e.step_t) - delta
				if e.step_t <= 0.0:
					e.step_t = 1.0
					e.move_t = 0.3
					vel = _duck_dir(to_player) * U / 0.3
				if e.move_t > 0.0:
					e.move_t = float(e.move_t) - delta
					if e.move_t <= 0.0:
						vel = Vector2.ZERO
			"rocket":
				e.slow = move_toward(float(e.slow), 1.0, delta / 0.8)
				vel = (e.dir as Vector2) * 10.0 * U * float(e.slow)
			"gear":
				var best := -1
				var best_d := INF
				for ci in crystals.size():
					var d: float = pos.distance_to(crystals[ci].pos)
					if d < best_d:
						best_d = d
						best = ci
				var speed := (2.0 + float(e.eaten) * 0.9) * U
				if best >= 0:
					if best_d < 0.7 * U:
						crystals.remove_at(best)
						e.eaten = int(e.eaten) + 1
						if e.eaten >= 8:
							events.append({"kind": "gear_pop", "pos": pos})
							enemies.remove_at(i)
							continue
					else:
						vel = vel.move_toward((crystals[best].pos - pos).normalized() * speed, 8.0 * U * delta)
				elif vel.length() > 0.01:
					vel = vel.normalized() * minf(speed, 4.0 * U)
			"mayfly":
				vel = chase.rotated(sin(float(e.t) * 4.0 + float(e.phase)) * 1.1) * 3.5 * U
			"weaver":
				var want := chase * 7.5 * U + _dodge(pos, bullets) * 7.5 * U * 1.6
				vel = vel.move_toward(want, 20.0 * U * delta).limit_length(10.0 * U)
			"spinner":
				vel = vel.move_toward(chase * 9.0 * U, 11.0 * U * delta).limit_length(11.0 * U)
			"mini":
				vel = vel.move_toward(chase * 7.0 * U, 16.0 * U * delta).limit_length(9.0 * U)
			"proton":
				vel = vel.move_toward(chase * 13.0 * U, 22.0 * U * delta)
			"snake":
				vel = chase.rotated(sin(float(e.t) * 3.0) * 0.9) * 5.0 * U
			"well":
				vel = chase * (0.6 if e.active else 1.2) * U
			"ufo":
				if not e.has("fly"):
					var aim: Vector2 = e.aim
					e.fly = (aim - pos).normalized() if aim.distance_to(pos) > 1.0 else Vector2.DOWN
				vel = (e.fly as Vector2) * 22.0 * U
		pos += vel * delta
		_walls(e, pos, vel, arena_size)
		if e.type == "snake":
			var prev: Vector2 = e.pos
			var segs: Array = e.segs
			for k in segs.size():
				var s: Vector2 = segs[k]
				var off := s - prev
				if off.length() > SNAKE_GAP * U:
					s = prev + off.normalized() * SNAKE_GAP * U
				segs[k] = s
				prev = s
		if e.type == "ufo":
			var out: bool = e.pos.x < -3.0 * U or e.pos.y < -3.0 * U or e.pos.x > arena_size.x + 3.0 * U or e.pos.y > arena_size.y + 3.0 * U
			if out:
				enemies.remove_at(i)
	_wells(enemies, delta, events)
	return events

## Wall handling for one enemy: writes the new pos/vel back into it.
static func _walls(e: Dictionary, pos: Vector2, vel: Vector2, arena_size: Vector2) -> void:
	if e.type == "ufo":
		e.pos = pos
		e.vel = vel
		return
	var hit_x := pos.x < 0.0 or pos.x > arena_size.x
	var hit_y := pos.y < 0.0 or pos.y > arena_size.y
	pos = pos.clamp(Vector2.ZERO, arena_size)
	if hit_x or hit_y:
		if e.type in BOUNCERS:
			if hit_x:
				vel.x = -vel.x
			if hit_y:
				vel.y = -vel.y
		elif e.type == "rocket":
			e.dir = -(e.dir as Vector2)  # about face, crawl, then charge again
			e.slow = 0.1
	e.pos = pos
	e.vel = vel

## Active gravity wells haul in every other enemy; one that reaches the core
## is swallowed, and an overfed well bursts into protons.
static func _wells(enemies: Array, delta: float, events: Array) -> void:
	for wi in range(enemies.size() - 1, -1, -1):
		if wi >= enemies.size():
			continue
		var w: Dictionary = enemies[wi]
		if w.type != "well" or not w.active or w.warm > 0.0:
			continue
		for ei in range(enemies.size() - 1, -1, -1):
			var e: Dictionary = enemies[ei]
			if ei == wi or e.type == "well" or e.warm > 0.0:
				continue
			var off: Vector2 = w.pos - e.pos
			var d: float = off.length()
			if d > WELL_RANGE * U:
				continue
			if d < 0.9 * U:
				enemies.remove_at(ei)
				w.eaten = int(w.eaten) + 1
				if ei < wi:
					wi -= 1
				continue
			e.pos += off / d * (3.0 + 5.0 * (1.0 - d / (WELL_RANGE * U))) * U * delta
		if int(w.eaten) >= WELL_BURST_AT:
			events.append({"kind": "well_burst", "pos": w.pos, "n": 6 + randi() % 4})
			enemies.remove_at(wi)

## Grunts start at 4 squares/s, match the player after a minute, and keep
## getting faster (about 20 squares/s after two).
static func grunt_speed(age: float) -> float:
	if age < 60.0:
		return 4.0 + 5.5 * age / 60.0
	return PLAYER_TOP_SPEED + 10.5 * minf(1.0, (age - 60.0) / 60.0)

## A duck hops along one axis, usually the one toward the player.
static func _duck_dir(to_player: Vector2) -> Vector2:
	var cardinals := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	if randf() < 0.3:
		return cardinals[randi() % 4]
	var horizontal := absf(to_player.x) > absf(to_player.y)
	if randf() < 0.25:
		horizontal = not horizontal
	if horizontal:
		return Vector2.RIGHT if to_player.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if to_player.y > 0.0 else Vector2.UP

## A sideways push away from the nearest bullet heading this way.
static func _dodge(pos: Vector2, bullets: Array) -> Vector2:
	var push := Vector2.ZERO
	var range_px := DODGE_RANGE * U
	for b in bullets:
		var off: Vector2 = pos - b.pos
		var d: float = off.length()
		if d > range_px or d < 0.001:
			continue
		var heading: Vector2 = b.vel.normalized()
		if heading.dot(off) <= 0.0:
			continue  # already past us
		var side := Vector2(-heading.y, heading.x)
		push += side * signf(side.dot(off) if side.dot(off) != 0.0 else 1.0) * (1.0 - d / range_px)
	return push.limit_length(1.0)

## Pull on the player from active wells, in pixels per second.
static func well_pull(enemies: Array, p: Vector2) -> Vector2:
	var pull := Vector2.ZERO
	for w in enemies:
		if w.type != "well" or not w.active or w.warm > 0.0:
			continue
		var off: Vector2 = w.pos - p
		var d: float = off.length()
		if d < WELL_RANGE * U and d > 1.0:
			pull += off / d * 5.0 * U * (1.0 - d / (WELL_RANGE * U))
	return pull

## Moves bullets, bends them around active wells, and drops spent ones
## (out of range or outside the arena).
static func update_bullets(bullets: Array, arena_size: Vector2, delta: float, enemies: Array = []) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		var v: Vector2 = b.vel
		for w in enemies:
			if w.type == "well" and w.active:
				var off: Vector2 = w.pos - b.pos
				var d: float = off.length()
				if d < 6.0 * U and d > 1.0:
					v = (v + off / d * 60.0 * U * (1.0 - d / (6.0 * U)) * delta).normalized() * v.length()
		b.vel = v
		b.pos += v * delta
		b.life = float(b.get("life", 1.0)) - delta
		var p: Vector2 = b.pos
		if b.life <= 0.0 or p.x < -20 or p.x > arena_size.x + 20 or p.y < -20 or p.y > arena_size.y + 20:
			bullets.remove_at(i)

# ---------- collisions ----------

## Each bullet hits the first enemy it touches. Returns one
## {pos, type, eaten} per kill. A snake's body soaks shots up, a well takes
## many (and wakes up), and a bullet flies straight through mayflies.
static func resolve_bullet_hits(bullets: Array, enemies: Array, bullet_r: float) -> Array:
	var kills: Array = []
	for bi in range(bullets.size() - 1, -1, -1):
		var bpos: Vector2 = bullets[bi].pos
		var spent := false
		for ei in range(enemies.size() - 1, -1, -1):
			var e: Dictionary = enemies[ei]
			if e.warm > 0.0:
				continue
			var r := radius_of(e.type) + bullet_r
			if bpos.distance_to(e.pos) <= r:
				if e.type == "mayfly":
					kills.append({"pos": e.pos, "type": "mayfly", "eaten": 0})
					enemies.remove_at(ei)
					continue  # pierces
				e.hp = int(e.hp) - 1
				if e.type == "well":
					e.active = true
				if e.hp <= 0:
					kills.append({"pos": e.pos, "type": e.type, "eaten": int(e.get("eaten", 0))})
					enemies.remove_at(ei)
				spent = true
				break
			if e.type == "snake":
				for s in e.segs:
					if bpos.distance_to(s) <= 0.3 * U + bullet_r:
						spent = true  # absorbed
						break
				if spent:
					break
		if spent:
			bullets.remove_at(bi)
	return kills

## Kills every active enemy within `radius` of `pos` (a well going up).
static func blast(enemies: Array, pos: Vector2, radius: float) -> Array:
	var kills: Array = []
	for ei in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[ei]
		if e.warm > 0.0 or e.pos.distance_to(pos) > radius:
			continue
		kills.append({"pos": e.pos, "type": e.type, "eaten": int(e.get("eaten", 0))})
		enemies.remove_at(ei)
	return kills

static func player_hit(player_pos: Vector2, enemies: Array, player_r: float) -> bool:
	for e in enemies:
		if e.warm > 0.0:
			continue
		if player_pos.distance_to(e.pos) <= radius_of(e.type) + player_r:
			return true
		if e.type == "snake":
			for s in e.segs:
				if player_pos.distance_to(s) <= 0.3 * U + player_r:
					return true
	return false

## Ages geoms, pulls nearby ones toward the ship, and returns the total value
## picked up this frame (each plain geom is worth +1 multiplier, big ones +10).
## Geoms older than CRYSTAL_LIFE vanish.
static func update_crystals(crystals: Array, player_pos: Vector2, delta: float) -> int:
	var picked := 0
	var magnet := CRYSTAL_MAGNET * U
	for i in range(crystals.size() - 1, -1, -1):
		var c: Dictionary = crystals[i]
		c.age += delta
		var off: Vector2 = player_pos - c.pos
		var d: float = off.length()
		if d <= CRYSTAL_PICKUP * U:
			picked += int(c.get("v", 1))
			crystals.remove_at(i)
			continue
		if c.age >= CRYSTAL_LIFE:
			crystals.remove_at(i)
			continue
		if d < magnet:
			c.pos += off.normalized() * minf(d, CRYSTAL_PULL * U * delta * (1.0 - d / magnet + 0.3))
	return picked
