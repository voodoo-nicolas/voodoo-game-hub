extends RefCounted

## Pure movement/collision math for Geometry Wars, kept free of any Node/rendering
## code so it can be exercised headlessly. Entities are plain Dictionaries:
## enemy = {id, type, pos, vel, hp, t, warm, ...}, bullet = {pos, vel, life},
## crystal ("geom") = {pos, age, v}, mine = {pos, age}, king zone = {pos, r, ...}.
##
## Everything is measured in grid squares: `U` is one square in pixels (the
## view shows 19 squares top to bottom, like the original's 29 x 19 map; the
## maps themselves are bigger and the camera follows the ship), and speeds are
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
##   well     gravity well     a black hole. Asleep it drifts at you with a
##                             gentle pull; shot, it wakes and hauls in
##                             enemies, shots and you, swallows what reaches
##                             it and swells with each one -- overfed, it pops
##                             into a swarm of protons
##   proton   cyan ring        the little circles a well bursts into; they
##                             chase you until shot
##   ufo      red saucer       one fast pass at you; worth a fortune
##   repulsor blue rhino       aims for 2 s, then charges at ~2.5x your speed;
##                             its orange front shrugs off shots (and slows it),
##                             only a hit from behind kills it
##   nufo     green saucer     a horde crossing the map in a straight line
##   gate     bar, orange ends the ends kill you; fly through the middle and it
##                             explodes, taking everything near it with it.
##                             Shots bounce off it as gold shots worth 4x
##   golden   golden gate      the same, worth far more, gone after 7 s
##   layer    mine layer       hops at random and drops mines; a mine you touch
##                             (or shoot) blows up the enemies around it

static var U := 30.0

const PLAYER_TOP_SPEED := 9.5

const POINTS := {
	"grunt": 10, "wanderer": 5, "duck": 5, "rocket": 15, "neutron": 10, "gear": 10,
	"mayfly": 5, "weaver": 25, "spinner": 25, "mini": 10, "snake": 35, "well": 500,
	"proton": 10, "ufo": 2800, "repulsor": 425, "nufo": 300, "gate": 50, "golden": 500,
	"layer": 50,
}
## How many geoms a kill drops (a well drops more for what it swallowed).
const GEOMS := {
	"grunt": 2, "wanderer": 2, "duck": 2, "rocket": 4, "neutron": 2, "gear": 1,
	"mayfly": 1, "weaver": 2, "spinner": 2, "mini": 1, "snake": 7, "well": 3,
	"proton": 1, "ufo": 2, "repulsor": 8, "nufo": 1, "gate": 6, "golden": 20,
	"layer": 2,
}
## Radius of each enemy in squares (a gate's is the radius of each end).
const RADIUS := {
	"grunt": 0.5, "wanderer": 0.5, "duck": 0.5, "rocket": 0.5, "neutron": 0.5, "gear": 0.5,
	"mayfly": 0.3, "weaver": 0.5, "spinner": 0.55, "mini": 0.35, "snake": 0.45, "well": 0.8,
	"proton": 0.35, "ufo": 0.7, "repulsor": 0.7, "nufo": 0.45, "gate": 0.42, "golden": 0.42,
	"layer": 0.55,
}
const COLORS := {
	"grunt": Color(0.25, 0.65, 1.0), "wanderer": Color(0.8, 0.35, 1.0), "duck": Color(1.0, 0.4, 0.85),
	"rocket": Color(1.0, 0.5, 0.15), "neutron": Color(0.2, 1.0, 0.8), "gear": Color(1.0, 0.85, 0.2),
	"mayfly": Color(0.65, 0.55, 1.0), "weaver": Color(0.35, 1.0, 0.35), "spinner": Color(1.0, 0.35, 0.55),
	"mini": Color(1.0, 0.45, 0.65), "snake": Color(0.3, 0.7, 1.0), "well": Color(1.0, 0.45, 0.2),
	"proton": Color(0.4, 0.9, 1.0), "ufo": Color(1.0, 0.2, 0.35), "repulsor": Color(0.35, 0.55, 1.0),
	"nufo": Color(0.55, 1.0, 0.3), "gate": Color(1.0, 0.55, 0.15), "golden": Color(1.0, 0.85, 0.25),
	"layer": Color(0.9, 1.0, 0.45),
}

const WARM_TIME := 0.9
const WELL_HP := 20
const WELL_RANGE := 7.0
const WELL_BURST_AT := 12
## A sleeping well's pull, as a share of an awake one's (strength, range).
const WELL_SLEEP_PULL := 0.3
const WELL_SLEEP_RANGE := 0.6
const SNAKE_SEGMENTS := 9
const SNAKE_GAP := 0.55
const DODGE_RANGE := 3.0

const CRYSTAL_LIFE := 3.0
const CRYSTAL_MAGNET := 4.0
const CRYSTAL_PICKUP := 0.9
const CRYSTAL_PULL := 14.0

## Gates: half the bar's length, the blast when one goes up, a golden one's life.
const GATE_HALF := 2.1
const GATE_BLAST := 4.5
const GOLDEN_LIFE := 7.0
## Mines: when a layer drops one, how long it lasts, its blast.
const MINE_EVERY := 1.7
const MINE_LIFE := 22.0
const MINE_ARM := 0.5
const MINE_BLAST := 3.6
const MINE_RADIUS := 0.35
const MAX_MINES := 40
## Repulsor: aims this long, then charges this fast for this long.
const REPULSOR_AIM := 2.0
const REPULSOR_SPEED := 24.0
const REPULSOR_CHARGE := 0.75

## Types that reflect off the walls (others clamp, rockets turn round).
const BOUNCERS := ["wanderer", "neutron", "gear", "proton", "weaver", "spinner", "mini"]
## Types that fly in from outside the map and leave it again.
const FLYBYS := ["ufo", "nufo"]
## Not shootable: bullets bounce off gates instead.
const GATES := ["gate", "golden"]

static func radius_of(type: String) -> float:
	return float(RADIUS.get(type, 0.5)) * U

## An enemy's own radius: a well is bigger for everything it has eaten.
static func radius_e(e: Dictionary) -> float:
	if e.type == "well":
		return radius_of("well") * well_scale(e)
	return radius_of(e.type)

## How swollen a well is (1 = empty).
static func well_scale(e: Dictionary) -> float:
	return 1.0 + float(e.get("eaten", 0)) * 0.07

## A well's reach in squares: it grows as it eats.
static func well_range(e: Dictionary) -> float:
	var r := WELL_RANGE * (1.0 + float(e.get("eaten", 0)) * 0.05)
	return r if e.get("active", false) else r * WELL_SLEEP_RANGE

## How many protons an overfed well bursts into.
static func burst_count(eaten: int) -> int:
	return 7 + int(eaten * 0.6)

static func color_of(type: String) -> Color:
	return COLORS.get(type, Color.WHITE)

# ---------- spawning ----------

## Which types can appear `elapsed` seconds into Evolved, with weights.
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
	if elapsed > 45.0:
		table["gate"] = 0.6
	if elapsed > 55.0:
		table["snake"] = 1.0
	if elapsed > 65.0:
		table["layer"] = 0.4
	if elapsed > 70.0:
		table["gear"] = 0.6
	if elapsed > 85.0:
		table["well"] = 0.7
	if elapsed > 100.0:
		table["repulsor"] = 0.5
	if elapsed > 120.0:
		table["nufo"] = 0.25
	if elapsed > 140.0:
		table["ufo"] = 0.15
	return table

static func pick(table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var roll := randf() * total
	for k in table:
		roll -= float(table[k])
		if roll <= 0.0:
			return k
	return "grunt"

static func spawn_type(elapsed: float) -> String:
	return pick(spawn_table(elapsed))

## A random spot at least `min_dist` squares from the player. On a big map most
## spawns land within `near` squares of the ship, so the fight stays on screen.
static func spawn_point(arena_size: Vector2, player_pos: Vector2, min_dist: float = 7.0, near: float = 16.0) -> Vector2:
	var box := Rect2(Vector2.ZERO, arena_size)
	if randf() < 0.75:
		box = Rect2(player_pos - Vector2(near, near) * U, Vector2(near, near) * 2.0 * U).intersection(box)
	var p := box.position + Vector2(randf() * box.size.x, randf() * box.size.y)
	for i in 14:
		if p.distance_to(player_pos) >= min_dist * U:
			break
		p = box.position + Vector2(randf() * box.size.x, randf() * box.size.y)
	return p

## One spawn event: usually a single enemy, sometimes a group (a mayfly horde
## from a corner, a line of rockets). Ids are left 0 for the caller to fill.
static func spawn_group(arena_size: Vector2, elapsed: float, player_pos: Vector2, table: Dictionary = {}) -> Array:
	var type := pick(table) if not table.is_empty() else spawn_type(elapsed)
	return spawn_of(type, arena_size, player_pos)

static func spawn_of(type: String, arena_size: Vector2, player_pos: Vector2, count: int = 0) -> Array:
	var out: Array = []
	match type:
		"mayfly":
			var corner := horde_corner(arena_size, player_pos)
			for i in (count if count > 0 else 12 + randi() % 8):
				var off := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * U
				var p := (corner + off).clamp(Vector2.ZERO, arena_size)
				out.append(make_enemy(0, "mayfly", p, WARM_TIME + randf() * 0.3))
		"rocket":
			out = rocket_line(arena_size, player_pos, count if count > 0 else 3 + randi() % 3)
		"ufo":
			var edge := randi() % 4
			var p := Vector2.ZERO
			var near := (player_pos + Vector2(randf_range(-10, 10), randf_range(-8, 8)) * U).clamp(Vector2.ZERO, arena_size)
			match edge:
				0: p = Vector2(near.x, U * 0.5)
				1: p = Vector2(near.x, arena_size.y - U * 0.5)
				2: p = Vector2(U * 0.5, near.y)
				_: p = Vector2(arena_size.x - U * 0.5, near.y)
			var u := make_enemy(0, "ufo", p, 1.1)
			u.aim = player_pos
			out.append(u)
		"nufo":
			out = nufo_horde(arena_size, player_pos, count if count > 0 else 7 + randi() % 5)
		"gate", "golden":
			var p := spawn_point(arena_size, player_pos, 5.0, 12.0)
			p = p.clamp(Vector2(GATE_HALF, GATE_HALF) * U, arena_size - Vector2(GATE_HALF, GATE_HALF) * U)
			out.append(make_enemy(0, type, p, WARM_TIME))
		_:
			out.append(make_enemy(0, type, spawn_point(arena_size, player_pos), WARM_TIME))
	return out

## The arena corner a horde pours from: one of the corners of the stretch of
## map around the player (on a big map, the real corners are far away).
static func horde_corner(arena_size: Vector2, player_pos: Vector2) -> Vector2:
	var half := Vector2(14.0, 9.0) * U
	var box := Rect2(player_pos - half, half * 2.0).intersection(Rect2(Vector2.ZERO, arena_size))
	return box.position + Vector2(box.size.x if randf() < 0.5 else 0.0, box.size.y if randf() < 0.5 else 0.0)

## A line of rockets charging in from one wall, across the player's row/column.
static func rocket_line(arena_size: Vector2, player_pos: Vector2, count: int) -> Array:
	var out: Array = []
	var side := randi() % 4
	var dir: Vector2 = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP][side]
	var perp := Vector2(-dir.y, dir.x)
	var start := Vector2.ZERO
	match side:
		0: start = Vector2(U * 0.6, player_pos.y)
		1: start = Vector2(arena_size.x - U * 0.6, player_pos.y)
		2: start = Vector2(player_pos.x, U * 0.6)
		_: start = Vector2(player_pos.x, arena_size.y - U * 0.6)
	start += perp * randf_range(-3.0, 3.0) * U
	for i in count:
		var p := start + perp * ((i - (count - 1) / 2.0) * 1.3 * U)
		p = p.clamp(Vector2(U * 0.5, U * 0.5), arena_size - Vector2(U * 0.5, U * 0.5))
		var r := make_enemy(0, "rocket", p, WARM_TIME)
		r.dir = dir
		out.append(r)
	return out

## Waves mode: a whole wall of rockets sweeping in from one side, with a gap
## somewhere to slip through (`gap` squares wide; 0 = solid).
static func rocket_wall(arena_size: Vector2, side: int, gap: float = 3.0) -> Array:
	var out: Array = []
	var dir: Vector2 = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP][side]
	var along := arena_size.y if side < 2 else arena_size.x
	var n := int(along / (1.25 * U))
	var gap_at := randf_range(0.15, 0.85) * along
	for i in n:
		var s := (i + 0.5) * along / n
		if gap > 0.0 and absf(s - gap_at) < gap * U * 0.5:
			continue
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(U * 0.6, s)
			1: p = Vector2(arena_size.x - U * 0.6, s)
			2: p = Vector2(s, U * 0.6)
			_: p = Vector2(s, arena_size.y - U * 0.6)
		var r := make_enemy(0, "rocket", p, WARM_TIME)
		r.dir = dir
		out.append(r)
	return out

## A NUFO horde: a loose column just outside one edge, all flying the same way
## across the map near the player.
static func nufo_horde(arena_size: Vector2, player_pos: Vector2, count: int) -> Array:
	var out: Array = []
	var side := randi() % 4
	var dir: Vector2 = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP][side]
	var perp := Vector2(-dir.y, dir.x)
	var start := Vector2.ZERO
	match side:
		0: start = Vector2(-1.5 * U, player_pos.y)
		1: start = Vector2(arena_size.x + 1.5 * U, player_pos.y)
		2: start = Vector2(player_pos.x, -1.5 * U)
		_: start = Vector2(player_pos.x, arena_size.y + 1.5 * U)
	for i in count:
		var p := start - dir * randf_range(0.0, 3.0) * U + perp * ((i - (count - 1) / 2.0) * 1.4 + randf_range(-0.3, 0.3)) * U
		var e := make_enemy(0, "nufo", p, 0.0)
		e.fly = dir
		out.append(e)
	return out

## Gravity wells / enemies in a ring around a point (campaign "ring" events).
static func ring_of(type: String, center: Vector2, radius: float, count: int, arena_size: Vector2) -> Array:
	var out: Array = []
	for i in count:
		var a := TAU * i / count
		var p := (center + Vector2(cos(a), sin(a)) * radius * U).clamp(Vector2(U, U) * 0.5, arena_size - Vector2(U, U) * 0.5)
		out.append(make_enemy(0, type, p, WARM_TIME + i * 0.02))
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
			e.aim = pos  # spawn_of() aims it at the player
		"repulsor":
			e.dir = dir
			e.state = "aim"
			e.st = REPULSOR_AIM * randf_range(0.6, 1.0)
		"nufo":
			e.fly = Vector2.RIGHT
			e.phase = randf() * TAU
		"gate", "golden":
			e.ang = randf() * PI
			e.spin = randf_range(0.25, 0.6) * (1.0 if randf() < 0.5 else -1.0)
			e.vel = dir * randf_range(0.8, 1.6) * U
			if type == "golden":
				e.life = GOLDEN_LIFE
		"layer":
			e.step_t = randf() * 0.6
			e.move_t = 0.0
			e.lay_t = MINE_EVERY * randf_range(0.5, 1.0)
	return e

# ---------- movement ----------

## Moves everything one step. Returns events the caller must act on:
## {kind: "well_burst", pos, n} (an overfed well, already removed),
## {kind: "gear_pop", pos} (a gear that ate its fill, already removed),
## {kind: "gulp", pos, n} (an awake well swallowed something),
## {kind: "mine", pos} (a layer dropped a mine), {kind: "charge", pos}
## (a repulsor started a charge), {kind: "gate_gone", pos} (a golden gate
## timed out, already removed).
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
			"layer":
				e.step_t = float(e.step_t) - delta
				if e.step_t <= 0.0:
					e.step_t = 0.6
					e.move_t = 0.25
					var cardinals := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
					vel = (cardinals[randi() % 4] as Vector2) * U / 0.25
				if e.move_t > 0.0:
					e.move_t = float(e.move_t) - delta
					if e.move_t <= 0.0:
						vel = Vector2.ZERO
				e.lay_t = float(e.lay_t) - delta
				if e.lay_t <= 0.0:
					e.lay_t = MINE_EVERY
					events.append({"kind": "mine", "pos": pos})
			"rocket":
				e.slow = move_toward(float(e.slow), 1.0, delta / 0.8)
				vel = (e.dir as Vector2) * 10.0 * U * float(e.slow)
			"repulsor":
				e.st = float(e.st) - delta
				var face: Vector2 = e.dir
				if e.state == "aim":
					# Turn to face the player, drifting to a stop.
					if chase != Vector2.ZERO:
						face = face.slerp(chase, clampf(delta * 3.0, 0.0, 1.0)).normalized()
					vel = vel.move_toward(Vector2.ZERO, 14.0 * U * delta)
					if e.st <= 0.0:
						e.state = "charge"
						e.st = REPULSOR_CHARGE
						vel = face * REPULSOR_SPEED * U
						events.append({"kind": "charge", "pos": pos})
				else:
					vel = vel.move_toward(Vector2.ZERO, (6.0 if e.state == "charge" else 30.0) * U * delta)
					if e.st <= 0.0:
						e.state = "aim"
						e.st = REPULSOR_AIM
				e.dir = face
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
			"nufo":
				var fly: Vector2 = e.fly
				var side := Vector2(-fly.y, fly.x)
				vel = fly * 6.0 * U + side * sin(float(e.t) * 2.2 + float(e.phase)) * 1.2 * U
			"gate", "golden":
				e.ang = float(e.ang) + float(e.spin) * delta
				if e.type == "golden":
					e.life = float(e.life) - delta
					if e.life <= 0.0:
						events.append({"kind": "gate_gone", "pos": pos})
						enemies.remove_at(i)
						continue
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
		if e.type in FLYBYS:
			var out: bool = e.pos.x < -4.0 * U or e.pos.y < -4.0 * U or e.pos.x > arena_size.x + 4.0 * U or e.pos.y > arena_size.y + 4.0 * U
			if out and float(e.t) > 1.5:
				enemies.remove_at(i)
	_wells(enemies, delta, events)
	return events

## Wall handling for one enemy: writes the new pos/vel back into it.
static func _walls(e: Dictionary, pos: Vector2, vel: Vector2, arena_size: Vector2) -> void:
	if e.type in FLYBYS:
		e.pos = pos
		e.vel = vel
		return
	var lo := Vector2.ZERO
	var hi := arena_size
	if e.type in GATES:
		# The bar's middle stays inside; its ends may poke past a wall.
		lo = Vector2(U, U)
		hi = arena_size - Vector2(U, U)
	var hit_x := pos.x < lo.x or pos.x > hi.x
	var hit_y := pos.y < lo.y or pos.y > hi.y
	pos = pos.clamp(lo, hi)
	if hit_x or hit_y:
		if e.type in BOUNCERS or e.type in GATES:
			if hit_x:
				vel.x = -vel.x
			if hit_y:
				vel.y = -vel.y
		elif e.type == "repulsor":
			# The hardest bounce in the game, then a skid.
			if hit_x:
				vel.x = -vel.x * 1.1
			if hit_y:
				vel.y = -vel.y * 1.1
			e.state = "skid"
			e.st = 0.9
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
		if w.type != "well" or w.warm > 0.0:
			continue
		var awake: bool = w.active
		var rng := well_range(w) * U
		var core := radius_e(w) + 0.4 * U
		var k := 1.0 if awake else WELL_SLEEP_PULL
		for ei in range(enemies.size() - 1, -1, -1):
			var e: Dictionary = enemies[ei]
			if ei == wi or e.type == "well" or e.type in GATES or e.type in FLYBYS or e.warm > 0.0:
				continue
			var off: Vector2 = w.pos - e.pos
			var d: float = off.length()
			if d > rng:
				continue
			if d < core and awake:
				enemies.remove_at(ei)
				w.eaten = int(w.eaten) + 1
				events.append({"kind": "gulp", "pos": w.pos, "n": int(w.eaten)})
				if ei < wi:
					wi -= 1
				continue
			e.pos += off / maxf(d, 1.0) * (3.0 + 5.0 * (1.0 - d / rng)) * k * U * delta
		if int(w.eaten) >= WELL_BURST_AT:
			events.append({"kind": "well_burst", "pos": w.pos, "n": burst_count(int(w.eaten))})
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

## Pull on the player from wells (sleeping ones gently), in pixels per second.
static func well_pull(enemies: Array, p: Vector2) -> Vector2:
	var pull := Vector2.ZERO
	for w in enemies:
		if w.type != "well" or w.warm > 0.0:
			continue
		var off: Vector2 = w.pos - p
		var d: float = off.length()
		var rng := well_range(w) * U
		if d < rng and d > 1.0:
			pull += off / d * 5.5 * U * (1.0 - d / rng) * (1.0 if w.active else WELL_SLEEP_PULL)
	return pull

## The two ends of a gate's bar.
static func gate_ends(g: Dictionary) -> Array:
	var d := Vector2(cos(float(g.ang)), sin(float(g.ang))) * GATE_HALF * U
	return [g.pos - d, g.pos + d]

## True if the ship flew through the middle of a gate between p0 and p1
## (the deadly ends don't count).
static func gate_crossed(g: Dictionary, p0: Vector2, p1: Vector2) -> bool:
	if g.warm > 0.0 or p0.distance_squared_to(p1) < 0.0001:
		return false
	var d := Vector2(cos(float(g.ang)), sin(float(g.ang))) * (GATE_HALF - 0.35) * U
	return Geometry2D.segment_intersects_segment(p0, p1, g.pos - d, g.pos + d) != null

## Moves bullets, bends them around active wells (and any extra `benders`:
## [{pos, range (px), pull}] from a boss), bounces them off gates as gold
## shots, and drops spent ones (out of range or outside the arena).
static func update_bullets(bullets: Array, arena_size: Vector2, delta: float, enemies: Array = [], benders: Array = []) -> void:
	var gates: Array = []
	var wells: Array = []
	for e in enemies:
		if e.type in GATES and e.warm <= 0.0:
			gates.append(e)
		elif e.type == "well" and e.active:
			wells.append({"pos": e.pos, "range": 6.0 * U * well_scale(e), "pull": 60.0})
	wells.append_array(benders)
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		var v: Vector2 = b.vel
		for w in wells:
			var off: Vector2 = w.pos - b.pos
			var d: float = off.length()
			var rng: float = w.range
			if d < rng and d > 1.0:
				v = (v + off / d * float(w.pull) * U * (1.0 - d / rng) * delta).normalized() * v.length()
		var from: Vector2 = b.pos
		var to: Vector2 = from + v * delta
		for g in gates:
			var ends := gate_ends(g)
			var hit = Geometry2D.segment_intersects_segment(from, to, ends[0], ends[1])
			if hit != null:
				var along: Vector2 = (ends[1] - ends[0]).normalized()
				var n := Vector2(-along.y, along.x)
				v = v - 2.0 * v.dot(n) * n
				to = (hit as Vector2) + v.normalized() * 2.0
				b.gold = true
				b.life = maxf(float(b.get("life", 1.0)), 0.6)
				break
		b.vel = v
		b.pos = to
		b.life = float(b.get("life", 1.0)) - delta
		var p: Vector2 = b.pos
		if b.life <= 0.0 or p.x < -20 or p.x > arena_size.x + 20 or p.y < -20 or p.y > arena_size.y + 20:
			bullets.remove_at(i)

## Enemy shots (bosses): straight lines, gone at the walls.
static func update_enemy_bullets(ebullets: Array, arena_size: Vector2, delta: float) -> void:
	for i in range(ebullets.size() - 1, -1, -1):
		var b: Dictionary = ebullets[i]
		b.pos += (b.vel as Vector2) * delta
		b.life = float(b.life) - delta
		var p: Vector2 = b.pos
		if b.life <= 0.0 or p.x < -U or p.x > arena_size.x + U or p.y < -U or p.y > arena_size.y + U:
			ebullets.remove_at(i)

# ---------- collisions ----------

## Each bullet hits the first enemy it touches. Returns one
## {pos, type, eaten, gold} per kill (gold = a shot that bounced off a gate,
## worth 4x). A snake's body soaks shots up, a well takes many (and wakes up),
## a repulsor's front shrugs them off, and a bullet flies straight through
## mayflies.
static func resolve_bullet_hits(bullets: Array, enemies: Array, bullet_r: float) -> Array:
	var kills: Array = []
	if bullets.is_empty() or enemies.is_empty():
		return kills
	# Positions and reach of every shootable enemy in packed arrays: the
	# per-pair test is the hot loop of a crowded screen.
	var pos := PackedVector2Array()
	var reach := PackedFloat32Array()
	var idx := PackedInt32Array()
	var max_r := 0.0
	for ei in enemies.size():
		var e: Dictionary = enemies[ei]
		if e.warm > 0.0 or e.type in GATES:
			continue
		var r := radius_e(e) + bullet_r
		if e.type == "snake":
			r += SNAKE_GAP * U * SNAKE_SEGMENTS  # its body can soak shots far from the head
		pos.append(e.pos)
		reach.append(r)
		idx.append(ei)
		max_r = maxf(max_r, r)
	var gone := {}
	var dead_rows := PackedInt32Array()
	for bi in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[bi]
		var bpos: Vector2 = b.pos
		var gold: bool = b.get("gold", false)
		var spent := false
		for k in pos.size():
			if gone.has(k):
				continue
			var off := bpos - pos[k]
			if absf(off.x) > reach[k] or absf(off.y) > reach[k]:
				continue
			var e: Dictionary = enemies[idx[k]]
			var r := radius_e(e) + bullet_r
			if off.length_squared() <= r * r:
				if e.type == "mayfly":
					kills.append({"pos": e.pos, "type": "mayfly", "eaten": 0, "gold": gold})
					gone[k] = true
					dead_rows.append(idx[k])
					continue  # pierces
				if e.type == "repulsor" and off.dot(e.dir) > -0.15 * U:
					# The armoured front: the shot is wasted and slows it down.
					e.vel = (e.vel as Vector2) * 0.82 - (e.dir as Vector2) * 0.6 * U
					spent = true
					break
				e.hp = int(e.hp) - 1
				if e.type == "well":
					e.active = true
				if e.hp <= 0:
					kills.append({"pos": e.pos, "type": e.type, "eaten": int(e.get("eaten", 0)), "gold": gold})
					gone[k] = true
					dead_rows.append(idx[k])
				spent = true
				break
			if e.type == "snake":
				for sg in e.segs:
					if bpos.distance_squared_to(sg) <= (0.3 * U + bullet_r) * (0.3 * U + bullet_r):
						spent = true  # absorbed
						break
				if spent:
					break
		if spent:
			bullets.remove_at(bi)
	if not dead_rows.is_empty():
		dead_rows.sort()
		for i in range(dead_rows.size() - 1, -1, -1):
			enemies.remove_at(dead_rows[i])
	return kills

## Kills every active enemy within `radius` of `pos` (a well going up, a gate,
## a mine). Gates themselves survive other blasts.
static func blast(enemies: Array, pos: Vector2, radius: float) -> Array:
	var kills: Array = []
	for ei in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[ei]
		if e.warm > 0.0 or e.type in GATES or e.pos.distance_to(pos) > radius:
			continue
		kills.append({"pos": e.pos, "type": e.type, "eaten": int(e.get("eaten", 0))})
		enemies.remove_at(ei)
	return kills

static func player_hit(player_pos: Vector2, enemies: Array, player_r: float) -> bool:
	for e in enemies:
		if e.warm > 0.0:
			continue
		if e.type in GATES:
			for end in gate_ends(e):
				if player_pos.distance_to(end) <= radius_of(e.type) + player_r:
					return true
			continue
		if player_pos.distance_to(e.pos) <= radius_e(e) + player_r:
			return true
		if e.type == "snake":
			for s in e.segs:
				if player_pos.distance_to(s) <= 0.3 * U + player_r:
					return true
	return false

static func enemy_bullet_hit(player_pos: Vector2, ebullets: Array, player_r: float) -> bool:
	for b in ebullets:
		if player_pos.distance_to(b.pos) <= float(b.get("r", 0.25)) * U + player_r:
			return true
	return false

# ---------- mines ----------

## Ages mines; old ones fizzle out. Returns the indexes the player touched
## (armed ones only), highest first.
static func update_mines(mines: Array, player_pos: Vector2, player_r: float, delta: float) -> Array:
	var touched: Array = []
	for i in range(mines.size() - 1, -1, -1):
		var m: Dictionary = mines[i]
		m.age = float(m.age) + delta
		if m.age >= MINE_LIFE:
			mines.remove_at(i)
			continue
		if m.age >= MINE_ARM and player_pos.distance_to(m.pos) <= MINE_RADIUS * U + player_r:
			touched.append(i)
	return touched

## Shots that hit a mine set it off. Returns the mine indexes hit, highest first.
static func bullets_on_mines(bullets: Array, mines: Array, bullet_r: float) -> Array:
	var hit: Array = []
	for mi in range(mines.size() - 1, -1, -1):
		var m: Dictionary = mines[mi]
		if m.age < MINE_ARM:
			continue
		for bi in range(bullets.size() - 1, -1, -1):
			if (bullets[bi].pos as Vector2).distance_to(m.pos) <= MINE_RADIUS * U + bullet_r:
				bullets.remove_at(bi)
				hit.append(mi)
				break
	return hit

# ---------- King zones ----------

## Enemies can't enter a King zone: anything inside is pushed back to its rim.
static func push_out_of_zones(enemies: Array, zones: Array) -> void:
	for z in zones:
		var r: float = float(z.r) * U
		for e in enemies:
			if e.warm > 0.0 or e.type in FLYBYS:
				continue
			var off: Vector2 = e.pos - z.pos
			var d: float = off.length()
			var er := radius_of(e.type)
			if d < r + er:
				e.pos = z.pos + (off / d if d > 0.01 else Vector2.RIGHT) * (r + er)

static func in_zone(p: Vector2, zones: Array) -> int:
	for i in zones.size():
		if p.distance_to(zones[i].pos) <= float(zones[i].r) * U:
			return i
	return -1

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
