extends RefCounted

## Pure movement/collision math for Geometry Wars, kept free of any Node/rendering
## code so it can be exercised headlessly. Entities are plain Dictionaries:
## enemy = {id, type, pos: Vector2, vel: Vector2}, bullet = {id, pos: Vector2, vel: Vector2}.

const SEEKER_SPEED := 90.0
const WANDERER_SPEED := 110.0

static func spawn_enemy(id: int, arena_size: Vector2) -> Dictionary:
	var edge := randi() % 4
	var pos: Vector2
	match edge:
		0: pos = Vector2(randf() * arena_size.x, 0)
		1: pos = Vector2(randf() * arena_size.x, arena_size.y)
		2: pos = Vector2(0, randf() * arena_size.y)
		_: pos = Vector2(arena_size.x, randf() * arena_size.y)

	var type := "seeker" if randf() < 0.5 else "wanderer"
	var vel := Vector2.ZERO
	if type == "wanderer":
		var angle := randf() * TAU
		vel = Vector2(cos(angle), sin(angle)) * WANDERER_SPEED

	return {"id": id, "type": type, "pos": pos, "vel": vel}

static func update_enemies(enemies: Array, player_pos: Vector2, arena_size: Vector2, delta: float) -> void:
	for e in enemies:
		if e.type == "seeker":
			var dir: Vector2 = player_pos - e.pos
			if dir.length() > 0.001:
				e.vel = dir.normalized() * SEEKER_SPEED
		e.pos += e.vel * delta
		if e.type == "wanderer":
			if e.pos.x < 0 or e.pos.x > arena_size.x:
				e.vel.x = -e.vel.x
				e.pos.x = clamp(e.pos.x, 0, arena_size.x)
			if e.pos.y < 0 or e.pos.y > arena_size.y:
				e.vel.y = -e.vel.y
				e.pos.y = clamp(e.pos.y, 0, arena_size.y)

## Removes bullets that have drifted outside the arena (plus a small margin).
static func update_bullets(bullets: Array, arena_size: Vector2, delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		bullets[i].pos += bullets[i].vel * delta
		var p: Vector2 = bullets[i].pos
		if p.x < -20 or p.x > arena_size.x + 20 or p.y < -20 or p.y > arena_size.y + 20:
			bullets.remove_at(i)

## Removes any bullet/enemy pair within hit_dist of each other (one enemy per bullet).
## Returns the world position of each kill, for spawning death particles.
static func resolve_bullet_hits(bullets: Array, enemies: Array, hit_dist: float) -> Array:
	var kill_positions: Array = []
	for bi in range(bullets.size() - 1, -1, -1):
		var hit := false
		for ei in range(enemies.size() - 1, -1, -1):
			if bullets[bi].pos.distance_to(enemies[ei].pos) <= hit_dist:
				kill_positions.append(enemies[ei].pos)
				enemies.remove_at(ei)
				hit = true
				break
		if hit:
			bullets.remove_at(bi)
	return kill_positions

static func player_hit(player_pos: Vector2, enemies: Array, hit_dist: float) -> bool:
	for e in enemies:
		if player_pos.distance_to(e.pos) <= hit_dist:
			return true
	return false
