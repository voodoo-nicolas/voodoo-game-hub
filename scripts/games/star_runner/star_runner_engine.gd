extends RefCounted

## Star Runner: a rail shooter. The ship flies forward on its own; the
## player steers it across the screen while it fires ahead. Things come at
## it out of the distance: fighters, rocks, towers, rings to fly through,
## and a boss at the end of every stage. Pure logic: x / y across the view
## (y grows downwards, the ground is at GROUND_Y), z = distance ahead of the
## ship (the ship is at z 0, things appear at FAR).

const X_MAX := 1.6
const Y_MIN := -1.15
const Y_MAX := 1.0
const GROUND_Y := 1.45
const FAR := 60.0
const LASER_SPEED := 70.0
const FIRE_EVERY := 0.16
const STAGE_TIME := 48.0      # seconds of flying before the boss
const MAX_SHIELD := 100
const BOMB_REACH := 45.0
## Easy / Normal / Hard.
const DIFFS := [
	{"fire": 0.75, "dmg": 0.85, "spawn": 0.85},
	{"fire": 1.25, "dmg": 1.35, "spawn": 1.05},
	{"fire": 1.7, "dmg": 1.75, "spawn": 1.25},
]
## Stage looks cycle: planet (towers on the ground), rock belt, deep space.
const STAGES := ["planet", "belt", "space"]

var diff: int = 1
var stage: int = 1
var score: int = 0
var ships: int = 3
var shield: int = MAX_SHIELD
var bombs: int = 3
var state := "play"           # play, dead, clear, over
var ship := Vector2(0.0, 0.45)
var ship_vx: float = 0.0      # for banking
var objects: Array = []       # {"kind", "x", "y", "z", "r", "hp", "t", "sway", "cool", "hit"}
var lasers: Array = []        # {"x", "y", "z"}
var bolts: Array = []         # {"x", "y", "z", "vx", "vy", "vz"}
var boss: Dictionary = {}
var stage_t: float = 0.0
var speed: float = 24.0
var invuln: float = 0.0
var travelled: float = 0.0    # for the scrolling ground
var stage_kills: int = 0
var _fire_t: float = 0.0
var _spawn_t: float = 1.0
var rng := RandomNumberGenerator.new()

func reset(p_diff: int = 1, seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	diff = clampi(p_diff, 0, DIFFS.size() - 1)
	stage = 1
	score = 0
	ships = 3
	bombs = 3
	start_stage()

func look() -> String:
	return STAGES[(stage - 1) % STAGES.size()]

func start_stage() -> void:
	objects = []
	lasers = []
	bolts = []
	boss = {}
	stage_t = 0.0
	stage_kills = 0
	speed = 24.0 + minf(16.0, (stage - 1) * 2.5)
	shield = MAX_SHIELD
	ship = Vector2(0.0, 0.45)
	invuln = 1.5
	_spawn_t = 1.2
	state = "play"

## Moves the ship by d (in view units), kept inside the flying box.
func steer(d: Vector2) -> void:
	var old := ship.x
	ship = Vector2(clampf(ship.x + d.x, -X_MAX, X_MAX), clampf(ship.y + d.y, Y_MIN, Y_MAX))
	ship_vx = lerpf(ship_vx, (ship.x - old) * 30.0, 0.5)

func bomb() -> bool:
	if bombs <= 0 or state != "play":
		return false
	bombs -= 1
	var keep: Array = []
	for o in objects:
		if o.z < BOMB_REACH and o.kind != "tower" and o.kind != "ring":
			score += _points(o.kind)
		else:
			keep.append(o)
	objects = keep
	bolts = []
	if not boss.is_empty():
		_damage_boss(8)
	return true

func _points(kind: String) -> int:
	return {"fighter": 100, "rock": 60, "ace": 250}.get(kind, 0)

# ---------- one frame ----------

## Returns events: "fire", "kill", "hit" (we hit something that survived),
## "hurt", "ring", "boss", "boss_hit", "boss_down", "dead", "clear".
func step(dt: float) -> Array:
	var ev: Array = []
	if state != "play":
		return ev
	stage_t += dt
	travelled += speed * dt
	invuln = maxf(0.0, invuln - dt)
	ship_vx = lerpf(ship_vx, 0.0, minf(1.0, dt * 6.0))
	_fire_t -= dt
	if _fire_t <= 0.0:
		_fire_t = FIRE_EVERY
		for sx in [-0.12, 0.12]:
			lasers.append({"x": ship.x + sx, "y": ship.y + 0.02, "z": 0.5})
		ev.append("fire")
	_spawn(dt, ev)
	_step_objects(dt, ev)
	_step_boss(dt, ev)
	_step_lasers(dt, ev)
	_step_bolts(dt, ev)
	if shield <= 0 and state == "play":
		state = "dead"
		ships -= 1
		ev.append("dead")
	return ev

func _spawn(dt: float, ev: Array) -> void:
	if stage_t >= STAGE_TIME:
		if boss.is_empty() and objects.is_empty():
			_spawn_boss()
			ev.append("boss")
		return
	_spawn_t -= dt
	if _spawn_t > 0.0:
		return
	var d: Dictionary = DIFFS[diff]
	_spawn_t = rng.randf_range(0.9, 1.6) / (d.spawn * (1.0 + 0.08 * (stage - 1)))
	var lk := look()
	var r := rng.randf()
	if r < 0.12:
		_add("ring", rng.randf_range(-1.2, 1.2), rng.randf_range(-0.8, 0.8), 0.55, 1)
	elif lk == "planet" and r < 0.45:
		# A row of towers with a gap to fly through.
		var gap := rng.randi_range(0, 3)
		for k in 4:
			if k != gap:
				_add("tower", -1.5 + k * 1.0, 0.0, 0.42, 99)
	elif lk == "belt" and r < 0.55:
		for k in rng.randi_range(1, 3):
			_add("rock", rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 0.9), rng.randf_range(0.3, 0.5), 3)
	elif r < 0.85:
		# A squadron in a line or a V.
		var n := rng.randi_range(3, 5)
		var cy := rng.randf_range(-0.8, 0.5)
		var v := rng.randf() < 0.5
		for k in n:
			var off := k - (n - 1) / 2.0
			var o := _add("fighter", off * 0.6, cy + (absf(off) * 0.25 if v else 0.0), 0.3, 1)
			o.z += absf(off) * 2.0 if v else 0.0
			o.sway = rng.randf_range(0.6, 1.4)
	else:
		var o := _add("ace", rng.randf_range(-1.0, 1.0), rng.randf_range(-0.8, 0.4), 0.34, 4)
		o.sway = 2.0

func _add(kind: String, x: float, y: float, r: float, hp: int) -> Dictionary:
	var o := {"kind": kind, "x": x, "y": y, "z": FAR, "r": r, "hp": hp, "t": rng.randf() * TAU,
		"sway": 0.0, "cool": rng.randf_range(0.8, 2.5), "hit": 0.0, "x0": x, "y0": y}
	objects.append(o)
	return o

func _step_objects(dt: float, ev: Array) -> void:
	var d: Dictionary = DIFFS[diff]
	var keep: Array = []
	for o in objects:
		var old_z: float = o.z
		o.t += dt
		o.hit = maxf(0.0, o.hit - dt)
		var closing := speed
		match o.kind:
			"fighter", "ace":
				closing = speed * (1.15 if o.kind == "fighter" else 0.7)
				o.x = clampf(o.x0 + sin(o.t * o.sway) * 0.5, -X_MAX - 0.4, X_MAX + 0.4)
				o.y = clampf(o.y0 + cos(o.t * o.sway * 0.8) * 0.3, Y_MIN, Y_MAX)
				if o.kind == "ace":
					# Aces close in slowly and line up with the ship.
					o.x0 = lerpf(o.x0, ship.x, dt * 0.6)
					o.y0 = lerpf(o.y0, ship.y, dt * 0.6)
				o.cool -= dt * d.fire
				if o.cool <= 0.0 and o.z > 8.0 and o.z < 45.0:
					o.cool = rng.randf_range(1.6, 3.0) if o.kind == "fighter" else 0.9
					_shoot_from(o.x, o.y, o.z)
			"rock":
				o.y = o.y0 + sin(o.t * 0.7) * 0.1
		o.z -= closing * dt
		# Crossing the ship's plane: a ring is collected, anything else may hit.
		if old_z > 0.0 and o.z <= 0.0:
			var dx: float = absf(o.x - ship.x)
			var dy: float = absf(o.y - ship.y)
			if o.kind == "ring":
				if Vector2(dx, dy).length() < o.r:
					shield = mini(MAX_SHIELD, shield + 15)
					score += 50
					ev.append("ring")
			elif o.kind == "tower":
				if dx < 0.3 and ship.y > -0.2:
					_hurt(int(30 * d.dmg), ev)
			elif dx < o.r + 0.15 and dy < o.r + 0.12:
				_hurt(int((25 if o.kind != "rock" else 20) * d.dmg), ev)
				score += _points(o.kind) / 2
				continue
		if o.z < -3.0:
			continue
		keep.append(o)
	objects = keep

func _shoot_from(x: float, y: float, z: float) -> void:
	# Aimed where the ship is now; takes ~1.4 s to arrive.
	var t := 1.4
	bolts.append({"x": x, "y": y, "z": z, "vx": (ship.x - x) / t, "vy": (ship.y - y) / t, "vz": -z / t})

func _step_lasers(dt: float, ev: Array) -> void:
	var keep: Array = []
	for l in lasers:
		var z0: float = l.z
		l.z += LASER_SPEED * dt
		var hit := false
		for o in objects:
			if o.kind == "ring" or o.kind == "tower":
				continue
			# Both move: the laser out, the target in. Overlap in depth this frame?
			var oz: float = o.z
			if oz < z0 - 1.0 or oz > l.z + speed * dt + 1.0:
				continue
			if absf(o.x - l.x) < o.r + 0.08 and absf(o.y - l.y) < o.r + 0.08:
				hit = true
				o.hp -= 1
				o.hit = 0.15
				if o.hp <= 0:
					objects.erase(o)
					score += _points(o.kind)
					stage_kills += 1
					ev.append("kill")
				else:
					ev.append("hit")
				break
		if not hit and not boss.is_empty() and l.z >= boss.z - 1.0:
			if _boss_hit_test(l.x, l.y):
				hit = true
				ev.append("boss_hit")
				_damage_boss(1)
				if boss.hp <= 0:
					_boss_down(ev)
		if not hit and l.z < FAR:
			keep.append(l)
	lasers = keep

func _step_bolts(dt: float, ev: Array) -> void:
	var keep: Array = []
	for b in bolts:
		var z0: float = b.z
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.z += b.vz * dt
		if z0 > 0.0 and b.z <= 0.0:
			if absf(b.x - ship.x) < 0.22 and absf(b.y - ship.y) < 0.18:
				_hurt(int(10 * DIFFS[diff].dmg), ev)
			continue
		keep.append(b)
	bolts = keep

func _hurt(n: int, ev: Array) -> void:
	if invuln > 0.0:
		return
	shield = maxi(0, shield - n)
	invuln = 0.6
	ev.append("hurt")

# ---------- the boss ----------

func _spawn_boss() -> void:
	var hp := 30 + stage * 10
	boss = {"x": 0.0, "y": -0.3, "z": FAR, "t": 0.0, "hp": hp, "max": hp, "cool": 2.0, "hit": 0.0, "spin": 0.0}

func _boss_hit_test(x: float, y: float) -> bool:
	return Vector2(x - boss.x, y - boss.y).length() < 0.62

func _damage_boss(n: int) -> void:
	boss.hp -= n
	boss.hit = 0.12

func _step_boss(dt: float, ev: Array) -> void:
	if boss.is_empty():
		return
	boss.t += dt
	boss.hit = maxf(0.0, boss.hit - dt)
	boss.spin += dt * (1.0 + 2.0 * (1.0 - float(boss.hp) / boss.max))
	boss.z = maxf(22.0, boss.z - speed * 0.8 * dt)
	boss.x = sin(boss.t * 0.6) * 1.0
	boss.y = -0.25 + sin(boss.t * 0.9) * 0.45
	boss.cool -= dt * DIFFS[diff].fire
	if boss.cool <= 0.0 and boss.z <= 23.0:
		boss.cool = maxf(0.8, 2.2 - stage * 0.15)
		# A fan of bolts around the ship.
		for k in 3 + mini(stage, 4):
			var off := (k - (2 + mini(stage, 4)) / 2.0) * 0.35
			var t := 1.6
			bolts.append({"x": boss.x, "y": boss.y, "z": boss.z, "vx": (ship.x + off - boss.x) / t,
				"vy": (ship.y - boss.y) / t, "vz": -boss.z / t})
	if boss.hp <= 0:
		_boss_down(ev)

func _boss_down(ev: Array) -> void:
	if boss.is_empty():
		return
	score += 1000 + stage * 500 + shield * 5
	boss = {}
	bolts = []
	state = "clear"
	ev.append("boss_down")
	ev.append("clear")

## After the pause following a lost ship or a cleared stage.
func next() -> void:
	if state == "clear":
		stage += 1
		bombs = mini(bombs + 1, 5)
		start_stage()
	elif state == "dead":
		if ships <= 0:
			state = "over"
		else:
			# Carry on where we were, with a fresh shield.
			shield = MAX_SHIELD
			bolts = []
			invuln = 2.0
			state = "play"
