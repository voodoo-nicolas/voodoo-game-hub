extends RefCounted

## Pure movement/collision math for Geometry Wars, kept free of any Node/rendering
## code so it can be exercised headlessly. Entities are plain Dictionaries:
## enemy = {id, type, pos: Vector2, vel: Vector2, hp, t}, bullet = {id, pos, vel},
## crystal = {pos: Vector2, age: float}.
##
## Enemy types (more join as the game goes on, see spawn_type()):
##   seeker   pink diamond     chases you
##   wanderer orange square    drifts and bounces off the walls
##   weaver   green square     chases you but sidesteps bullets
##   splitter purple pinwheel  wanders; breaks into 3 fast minis when shot
##   mini     small purple     fast chaser born from a splitter
##   dart     yellow arrow     lines up on you, then charges in a straight line
##   tank     red hexagon      slow chaser that takes 3 hits

const SEEKER_SPEED := 90.0
const WANDERER_SPEED := 110.0
const WEAVER_SPEED := 120.0
const SPLITTER_SPEED := 80.0
const MINI_SPEED := 170.0
const DART_SPEED := 330.0
const TANK_SPEED := 55.0
const TANK_HP := 3
const DODGE_RANGE := 90.0
## Seconds a dart waits (turning to face you) between charges.
const DART_AIM_TIME := 1.1

const POINTS := {"seeker": 10, "wanderer": 10, "weaver": 20, "splitter": 15, "mini": 5, "dart": 15, "tank": 30}

const CRYSTAL_LIFE := 3.0
const CRYSTAL_MAGNET := 130.0
const CRYSTAL_PICKUP := 26.0
const CRYSTAL_PULL := 420.0

## Which types can appear `elapsed` seconds in, with weights.
static func spawn_table(elapsed: float) -> Dictionary:
	var table := {"seeker": 4.0, "wanderer": 3.0}
	if elapsed > 15.0:
		table["weaver"] = 2.0
	if elapsed > 30.0:
		table["splitter"] = 1.5
	if elapsed > 45.0:
		table["dart"] = 1.5
	if elapsed > 70.0:
		table["tank"] = 1.0
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
	return "seeker"

static func spawn_enemy(id: int, arena_size: Vector2, elapsed: float = 0.0) -> Dictionary:
	var edge := randi() % 4
	var pos: Vector2
	match edge:
		0: pos = Vector2(randf() * arena_size.x, 0)
		1: pos = Vector2(randf() * arena_size.x, arena_size.y)
		2: pos = Vector2(0, randf() * arena_size.y)
		_: pos = Vector2(arena_size.x, randf() * arena_size.y)
	return make_enemy(id, spawn_type(elapsed), pos)

static func make_enemy(id: int, type: String, pos: Vector2) -> Dictionary:
	var vel := Vector2.ZERO
	if type == "wanderer" or type == "splitter":
		var angle := randf() * TAU
		vel = Vector2(cos(angle), sin(angle)) * (WANDERER_SPEED if type == "wanderer" else SPLITTER_SPEED)
	return {"id": id, "type": type, "pos": pos, "vel": vel, "hp": TANK_HP if type == "tank" else 1, "t": 0.0}

static func update_enemies(enemies: Array, player_pos: Vector2, arena_size: Vector2, delta: float, bullets: Array = []) -> void:
	for e in enemies:
		e.t = float(e.get("t", 0.0)) + delta
		var to_player: Vector2 = player_pos - e.pos
		var chase: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO
		match e.type:
			"seeker":
				e.vel = chase * SEEKER_SPEED
			"mini":
				e.vel = chase * MINI_SPEED
			"tank":
				e.vel = chase * TANK_SPEED
			"weaver":
				e.vel = chase * WEAVER_SPEED + _dodge(e.pos, bullets) * WEAVER_SPEED * 1.6
			"dart":
				# Aim (crawl toward you) for a moment, then charge straight.
				if e.t >= DART_AIM_TIME and e.get("charging", false) == false:
					e.charging = true
					e.vel = chase * DART_SPEED
				elif not e.get("charging", false):
					e.vel = chase * 30.0
		e.pos += e.vel * delta
		if e.type in ["wanderer", "splitter", "dart"]:
			var bounced := false
			if e.pos.x < 0 or e.pos.x > arena_size.x:
				e.vel.x = -e.vel.x
				e.pos.x = clamp(e.pos.x, 0, arena_size.x)
				bounced = true
			if e.pos.y < 0 or e.pos.y > arena_size.y:
				e.vel.y = -e.vel.y
				e.pos.y = clamp(e.pos.y, 0, arena_size.y)
				bounced = true
			if bounced and e.type == "dart":  # stop at the wall and line up again
				e.charging = false
				e.t = 0.0
		else:
			e.pos.x = clamp(e.pos.x, -20, arena_size.x + 20)
			e.pos.y = clamp(e.pos.y, -20, arena_size.y + 20)

## A sideways push away from the nearest bullet heading this way.
static func _dodge(pos: Vector2, bullets: Array) -> Vector2:
	var push := Vector2.ZERO
	for b in bullets:
		var off: Vector2 = pos - b.pos
		var d: float = off.length()
		if d > DODGE_RANGE or d < 0.001:
			continue
		var heading: Vector2 = b.vel.normalized()
		if heading.dot(off) <= 0.0:
			continue  # already past us
		var side := Vector2(-heading.y, heading.x)
		push += side * signf(side.dot(off) if side.dot(off) != 0.0 else 1.0) * (1.0 - d / DODGE_RANGE)
	return push.limit_length(1.0)

## Removes bullets that have drifted outside the arena (plus a small margin).
static func update_bullets(bullets: Array, arena_size: Vector2, delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		bullets[i].pos += bullets[i].vel * delta
		var p: Vector2 = bullets[i].pos
		if p.x < -20 or p.x > arena_size.x + 20 or p.y < -20 or p.y > arena_size.y + 20:
			bullets.remove_at(i)

## Each bullet damages the first enemy within hit_dist; an enemy at 0 hp is
## removed. Returns one {pos, type} per kill (for points, crystals, particles
## and splitting).
static func resolve_bullet_hits(bullets: Array, enemies: Array, hit_dist: float) -> Array:
	var kills: Array = []
	for bi in range(bullets.size() - 1, -1, -1):
		var hit := false
		for ei in range(enemies.size() - 1, -1, -1):
			var e: Dictionary = enemies[ei]
			var r: float = hit_dist * (1.3 if e.type == "tank" else (0.7 if e.type == "mini" else 1.0))
			if bullets[bi].pos.distance_to(e.pos) <= r:
				e.hp = int(e.get("hp", 1)) - 1
				if e.hp <= 0:
					kills.append({"pos": e.pos, "type": e.type})
					enemies.remove_at(ei)
				hit = true
				break
		if hit:
			bullets.remove_at(bi)
	return kills

static func player_hit(player_pos: Vector2, enemies: Array, hit_dist: float) -> bool:
	for e in enemies:
		var r: float = hit_dist * (1.3 if e.type == "tank" else (0.7 if e.type == "mini" else 1.0))
		if player_pos.distance_to(e.pos) <= r:
			return true
	return false

## Ages crystals, pulls nearby ones toward the ship, and returns how many the
## ship picked up this frame. Crystals older than CRYSTAL_LIFE vanish.
static func update_crystals(crystals: Array, player_pos: Vector2, delta: float) -> int:
	var picked := 0
	for i in range(crystals.size() - 1, -1, -1):
		var c: Dictionary = crystals[i]
		c.age += delta
		var off: Vector2 = player_pos - c.pos
		var d: float = off.length()
		if d <= CRYSTAL_PICKUP:
			picked += 1
			crystals.remove_at(i)
			continue
		if c.age >= CRYSTAL_LIFE:
			crystals.remove_at(i)
			continue
		if d < CRYSTAL_MAGNET:
			c.pos += off.normalized() * minf(d, CRYSTAL_PULL * delta * (1.0 - d / CRYSTAL_MAGNET + 0.3))
	return picked
