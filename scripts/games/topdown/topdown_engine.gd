extends RefCounted

## Top-down adventure (working title) -- pure game logic, no Nodes, headless-testable.
## Fixed 60 Hz step: call tick(input) once per physics frame.
## Every number comes from docs/topdown/SPEC.md (section 9 "Our game") unless marked
## "ours": those are placeholders we chose because the spec has not traced them yet.
## Units: pixels and frames; health in eighths of a heart.

const TILE := 16
const HERO_HALF := 6.0  # ours: 12x12 hero box (SPEC §4: collision box not traced)

# Speeds in px/frame: [straight, diagonal per axis] (SPEC §1.2)
const SPEED_WALK := [1.5, 1.0]
const SPEED_SLOW := [1.25, 0.8125]  # charging the sword; also walking in grass
const SPEED_GRASS_SLOW := [1.0, 0.5]
const SPEED_DASH := [4.0, 2.625]
const SPEED_GRASS_DASH := [3.0, 1.5]

const DASH_WINDUP := 30  # frames (SPEC §1.5)
const SWING_POSES := [2, 1, 1, 1, 1, 4, 1, 1, 2]  # 14 frames (SPEC §2.1)
const RESWING_FROM_POSE := 4
const BEAM_POSE := 5
const CHARGE_READY := 48  # frames after the swing (SPEC §2.2)
const CHARGE_CAP := 64
const SPIN_POSES := [4, 10, 4, 2, 2, 2, 2, 2, 2, 2, 2, 6]  # 40 frames

const RECOIL_FRAMES := 19  # SPEC §3.3
const RECOIL_SPEED := 1.5
const HOP_SPEED := 0.75
const GRAVITY := 0.125
const HURT_FRAMES := 58  # SPEC §3.4
const BEEP_EVERY := 32  # SPEC §3.6
const REFILL_STEP_FRAMES := 8  # ours: SPEC §3.7 step timing not traced
const MAX_HEARTS := 20

# Contact damage in eighths: DAMAGE[class][armour] (SPEC §3.2)
const DAMAGE := [[2, 1, 1], [4, 4, 4], [0, 0, 0], [8, 4, 2], [8, 8, 8],
	[16, 8, 4], [32, 16, 8], [32, 24, 16], [24, 16, 8], [64, 48, 24]]

# Ours (SPEC §2.3 / §4 not traced yet): enemy roster, enemy health, sword damage, hit reaction.
const ENEMY_KINDS := {
	"blob": {"hp": 2, "speed": 0.5, "damage_class": 1, "half": 6.0},
	"charger": {"hp": 3, "speed": 0.75, "charge_speed": 2.5, "damage_class": 3, "half": 7.0},
}
const ENEMY_HIT_FRAMES := 16
const ENEMY_KNOCK_SPEED := 2.0
const ENEMY_KNOCK_FRAMES := 8
const DASH_BOUNCE_FRAMES := 16  # ours: SPEC §1.5 wall bounce not traced
const DASH_BOUNCE_SPEED := 1.0
const HEART_DROP_CHANCE := 0.35

enum S { WALK, WINDUP, DASH, SWING, CHARGE, SPIN, RECOIL, DEAD }

# Room: rows of characters. '#' wall, '.' floor, ',' grass, 'P' hero start, 'b'/'c' enemies.
var grid: Array = []  # Array of PackedByteArray-like strings
var cols := 0
var rows := 0

# Hero
var pos := Vector2.ZERO
var z := 0.0
var vz := 0.0
var facing := Vector2i(0, 1)
var state: int = S.WALK
var timer := 0  # per-state countdown
var pose := 0
var pose_left := 0
var released_in_swing := false
var charge := 0
var dash_dir := Vector2i.ZERO
var recoil_vel := Vector2.ZERO
var hp := 24
var max_hp := 24
var armour := 0
var sword_level := 1
var hurt := 0
var refill := 0
var refill_wait := 0
var beep_wait := 0
var frame := 0
var dead := false

var enemies: Array = []  # Array of Dictionary
var pickups: Array = []  # Array of Dictionary {pos}
var beams: Array = []  # Array of Dictionary {pos, dir}
var events: Array = []  # names the view turns into sounds/effects, cleared each tick
var kills := 0

var rng := RandomNumberGenerator.new()
var _prev_sword := false
var _prev_dash := false

func load_room(lines: Array, seed_value: int = 1) -> void:
	rng.seed = seed_value
	grid = []
	enemies = []
	pickups = []
	beams = []
	rows = lines.size()
	cols = 0
	for r in rows:
		var line: String = lines[r]
		cols = max(cols, line.length())
	for r in rows:
		var line: String = lines[r]
		var row := ""
		for c in cols:
			var ch: String = line[c] if c < line.length() else "#"
			var centre := Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)
			match ch:
				"P":
					pos = centre
					ch = "."
				"b", "c":
					_spawn_enemy("blob" if ch == "b" else "charger", centre)
					ch = "."
			row += ch
		grid.append(row)

func new_game(lines: Array, seed_value: int = 1) -> void:
	max_hp = 24
	hp = max_hp
	armour = 0
	sword_level = 1
	hurt = 0
	refill = 0
	kills = 0
	dead = false
	frame = 0
	state = S.WALK
	z = 0.0
	vz = 0.0
	facing = Vector2i(0, 1)
	load_room(lines, seed_value)

func _spawn_enemy(kind: String, at: Vector2) -> void:
	var k: Dictionary = ENEMY_KINDS[kind]
	enemies.append({"kind": kind, "pos": at, "hp": int(k.hp), "half": float(k.half),
		"dir": Vector2i.ZERO, "wait": rng.randi_range(10, 60), "hit": 0,
		"knock": Vector2.ZERO, "knock_left": 0, "charging": false})

# --- tiles ---

func tile_at(c: int, r: int) -> String:
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return "#"
	return grid[r][c]

func solid_at(p: Vector2) -> bool:
	return tile_at(int(floor(p.x / TILE)), int(floor(p.y / TILE))) == "#"

func box_hits_wall(centre: Vector2, half: float) -> bool:
	var e := half - 0.01
	for corner in [Vector2(-e, -e), Vector2(e, -e), Vector2(-e, e), Vector2(e, e)]:
		if solid_at(centre + corner):
			return true
	return false

## Moves a box axis by axis; returns which axes were blocked.
func move_box(centre: Vector2, half: float, delta: Vector2) -> Dictionary:
	var p := centre
	var blocked_x := false
	var blocked_y := false
	if delta.x != 0.0:
		var nx := p + Vector2(delta.x, 0)
		if box_hits_wall(nx, half):
			blocked_x = true
		else:
			p = nx
	if delta.y != 0.0:
		var ny := p + Vector2(0, delta.y)
		if box_hits_wall(ny, half):
			blocked_y = true
		else:
			p = ny
	return {"pos": p, "x": blocked_x, "y": blocked_y}

func in_grass() -> bool:
	return tile_at(int(floor(pos.x / TILE)), int(floor(pos.y / TILE))) == ","

# --- the frame ---

## input: {"dir": Vector2i (-1..1 each axis), "sword": bool held, "dash": bool held}
func tick(input: Dictionary) -> void:
	events = []
	frame += 1
	if dead:
		return
	var dir: Vector2i = input.get("dir", Vector2i.ZERO)
	var sword: bool = input.get("sword", false)
	var dash: bool = input.get("dash", false)
	var sword_pressed := sword and not _prev_sword
	var dash_pressed := dash and not _prev_dash
	_prev_sword = sword
	_prev_dash = dash

	match state:
		S.WALK:
			if sword_pressed:
				_start_swing()
				_tick_swing(sword, false)  # the press frame is the swing's first frame
			elif dash_pressed:
				state = S.WINDUP
				timer = DASH_WINDUP
			else:
				_walk(dir, SPEED_SLOW if in_grass() else SPEED_WALK, true)
		S.WINDUP:
			_tick_windup(dir, dash)
		S.DASH:
			_tick_dash(dir)
		S.SWING:
			_tick_swing(sword, sword_pressed)
		S.CHARGE:
			_tick_charge(dir, sword)
		S.SPIN:
			_tick_spin()
		S.RECOIL:
			_tick_recoil()

	_tick_beams()
	_tick_enemies()
	_hero_contacts()
	_tick_pickups()
	_tick_health()

static func speed_vector(dir: Vector2i, row: Array) -> Vector2:
	if dir == Vector2i.ZERO:
		return Vector2.ZERO
	var s: float = row[1] if dir.x != 0 and dir.y != 0 else row[0]
	return Vector2(dir.x * s, dir.y * s)

func _walk(dir: Vector2i, row: Array, turn: bool) -> void:
	if dir == Vector2i.ZERO:
		return
	if turn:
		# Facing follows the stick; on a diagonal keep the axis already faced (no flicker).
		if dir.x != 0 and dir.y != 0:
			if not ((facing.x != 0 and facing.x == dir.x) or (facing.y != 0 and facing.y == dir.y)):
				facing = Vector2i(0, dir.y)
		else:
			facing = dir
	pos = move_box(pos, HERO_HALF, speed_vector(dir, row)).pos

func _tick_windup(dir: Vector2i, dash_held: bool) -> void:
	# Footsteps every 16 frames in the first half, every 8 in the second (SPEC §1.5).
	var every := 16 if timer > DASH_WINDUP / 2 else 8
	if timer % every == 0:
		events.append("step")
	timer -= 1
	if timer > 0:
		return
	if not dash_held:
		state = S.WALK
		return
	dash_dir = dir if dir != Vector2i.ZERO else facing
	if dir != Vector2i.ZERO and not (dir.x != 0 and dir.y != 0):
		facing = dir
	state = S.DASH
	events.append("dash")

func _tick_dash(dir: Vector2i) -> void:
	if dir != Vector2i.ZERO and dir != dash_dir:
		state = S.WALK
		return
	var row: Array = SPEED_GRASS_DASH if in_grass() else SPEED_DASH
	var res := move_box(pos, HERO_HALF, speed_vector(dash_dir, row))
	pos = res.pos
	if (res.x and dash_dir.x != 0) or (res.y and dash_dir.y != 0):
		events.append("bonk")
		_start_recoil(-Vector2(dash_dir).normalized() * DASH_BOUNCE_SPEED, DASH_BOUNCE_FRAMES)
		return
	if sword_level >= 1:
		_sword_hits(_front_box(14.0, 10.0))

func _start_swing() -> void:
	state = S.SWING
	pose = 0
	pose_left = SWING_POSES[0]
	released_in_swing = false
	charge = 0
	events.append("swing")

func _tick_swing(held: bool, pressed: bool) -> void:
	if not held:
		released_in_swing = true
	if pose >= RESWING_FROM_POSE and released_in_swing and pressed:
		_start_swing()
		_tick_swing(held, false)
		return
	if pose >= 1:
		_sword_hits(_swing_box())
	pose_left -= 1
	if pose_left > 0:
		return
	pose += 1
	if pose == BEAM_POSE:
		_maybe_beam()
	if pose < SWING_POSES.size():
		pose_left = SWING_POSES[pose]
		return
	if held:
		state = S.CHARGE
		charge = 0
	else:
		state = S.WALK

func _maybe_beam() -> void:
	if sword_level >= 2 and hp > max_hp - 4 and beams.is_empty():
		beams.append({"pos": pos + Vector2(facing) * 12.0, "dir": facing})
		events.append("beam")

func _tick_charge(dir: Vector2i, held: bool) -> void:
	if not held:
		if charge >= CHARGE_READY:
			state = S.SPIN
			pose = 0
			pose_left = SPIN_POSES[0]
			events.append("spin")
		else:
			state = S.WALK
		return
	if charge < CHARGE_CAP:
		charge += 1
		if charge == CHARGE_READY:
			events.append("charged")
	_walk(dir, SPEED_GRASS_SLOW if in_grass() else SPEED_SLOW, false)
	_sword_hits(_front_box(10.0, 8.0))

func _tick_spin() -> void:
	if pose >= 1:
		_sword_hits(Rect2(pos - Vector2(22, 22), Vector2(44, 44)))
	pose_left -= 1
	if pose_left > 0:
		return
	pose += 1
	if pose < SPIN_POSES.size():
		pose_left = SPIN_POSES[pose]
	else:
		state = S.WALK

func _start_recoil(vel: Vector2, frames: int) -> void:
	state = S.RECOIL
	recoil_vel = vel
	timer = frames
	vz = HOP_SPEED
	z = 0.0
	charge = 0

func _tick_recoil() -> void:
	pos = move_box(pos, HERO_HALF, recoil_vel).pos
	z += vz
	vz -= GRAVITY
	if z <= 0.0:
		z = 0.0
	timer -= 1
	# The timer waits at 1 until the hero has landed (SPEC §3.3).
	if timer < 1:
		timer = 1
	if timer == 1 and z == 0.0 and vz < 0.0:
		state = S.WALK
		events.append("land")

# --- sword boxes (ours: SPEC §2.3 hitboxes not traced) ---

func _front_box(reach: float, width: float) -> Rect2:
	var f := Vector2(facing)
	var centre := pos + f * (HERO_HALF + reach / 2.0)
	var size := Vector2(reach, width) if facing.x != 0 else Vector2(width, reach)
	return Rect2(centre - size / 2.0, size)

func _swing_box() -> Rect2:
	# Early poses sweep the side, the long pose 5 is straight ahead.
	if pose <= 3:
		var side := Vector2(-facing.y, facing.x) if facing.y != 0 else Vector2(facing.y, facing.x)
		var r := _front_box(12.0, 14.0)
		r.position += side * 6.0
		return r
	return _front_box(16.0, 10.0)

func _sword_hits(box: Rect2) -> void:
	for e in enemies:
		if e.hp <= 0 or e.hit > 0:
			continue
		if box.intersects(_enemy_rect(e)):
			_damage_enemy(e, 1, Vector2(e.pos - pos).normalized())

func _damage_enemy(e: Dictionary, amount: int, push: Vector2) -> void:
	e.hp -= amount
	e.hit = ENEMY_HIT_FRAMES
	e.knock = push * ENEMY_KNOCK_SPEED
	e.knock_left = ENEMY_KNOCK_FRAMES
	e.charging = false
	if e.hp <= 0:
		kills += 1
		events.append("enemy_die")
		if rng.randf() < HEART_DROP_CHANCE:
			pickups.append({"pos": e.pos, "kind": "heart", "life": 600})
	else:
		events.append("enemy_hit")

func _enemy_rect(e: Dictionary) -> Rect2:
	var h: float = e.half
	return Rect2(e.pos - Vector2(h, h), Vector2(h * 2, h * 2))

func hero_rect() -> Rect2:
	return Rect2(pos - Vector2(HERO_HALF, HERO_HALF), Vector2(HERO_HALF * 2, HERO_HALF * 2))

# --- beams ---

func _tick_beams() -> void:
	for b in beams.duplicate():
		b.pos += Vector2(b.dir) * 4.0
		var box := Rect2(b.pos - Vector2(4, 4), Vector2(8, 8))
		var gone := solid_at(b.pos)
		for e in enemies:
			if e.hp > 0 and e.hit == 0 and box.intersects(_enemy_rect(e)):
				_damage_enemy(e, 1, Vector2(b.dir))
				gone = true
		if gone:
			beams.erase(b)

# --- enemies (ours: SPEC has no enemy section yet) ---

func _tick_enemies() -> void:
	for e in enemies.duplicate():
		if e.hp <= 0:
			enemies.erase(e)
			continue
		if e.hit > 0:
			e.hit -= 1
		if e.knock_left > 0:
			e.knock_left -= 1
			e.pos = move_box(e.pos, e.half, e.knock).pos
			continue
		var k: Dictionary = ENEMY_KINDS[e.kind]
		if e.kind == "charger" and not e.charging:
			var d: Vector2 = pos - e.pos
			# Lines up with the hero, then rushes along that axis.
			if absf(d.x) < 6.0 and absf(d.y) > 8.0 and absf(d.y) < 96.0:
				e.charging = true
				e.dir = Vector2i(0, int(signf(d.y)))
			elif absf(d.y) < 6.0 and absf(d.x) > 8.0 and absf(d.x) < 96.0:
				e.charging = true
				e.dir = Vector2i(int(signf(d.x)), 0)
		if e.charging:
			var res := move_box(e.pos, e.half, Vector2(e.dir) * float(k.charge_speed))
			e.pos = res.pos
			if res.x or res.y:
				e.charging = false
				e.wait = 40
				e.dir = Vector2i.ZERO
			continue
		e.wait -= 1
		if e.wait <= 0:
			var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i.ZERO]
			e.dir = dirs[rng.randi_range(0, dirs.size() - 1)]
			e.wait = rng.randi_range(32, 96)
		var r2 := move_box(e.pos, e.half, Vector2(e.dir) * float(k.speed))
		e.pos = r2.pos
		if r2.x or r2.y:
			e.wait = 0

func _hero_contacts() -> void:
	if hurt > 0 or state == S.DEAD:
		return
	var me := hero_rect()
	for i in enemies.size():
		# Half the enemies are tested on even frames, half on odd (SPEC §3.2).
		if (i + frame) % 2 != 0:
			continue
		var e: Dictionary = enemies[i]
		if e.hp <= 0 or not me.intersects(_enemy_rect(e)):
			continue
		var cls: int = ENEMY_KINDS[e.kind].damage_class
		take_damage(DAMAGE[cls][armour], Vector2(pos - e.pos))
		return

func take_damage(amount: int, away: Vector2) -> void:
	hurt = HURT_FRAMES
	events.append("hurt")
	hp -= amount
	if hp <= 0:
		hp = 0
		refill = 0
		dead = true
		state = S.DEAD
		events.append("die")
		return
	var push := away.normalized() if away.length() > 0.01 else -Vector2(facing)
	_start_recoil(push * RECOIL_SPEED, RECOIL_FRAMES)

# --- pickups and health ---

func _tick_pickups() -> void:
	var me := hero_rect()
	for p in pickups.duplicate():
		p.life -= 1
		if me.intersects(Rect2(p.pos - Vector2(4, 4), Vector2(8, 8))):
			refill += 8
			events.append("pickup")
			pickups.erase(p)
		elif p.life <= 0:
			pickups.erase(p)

func add_heart_container() -> void:
	if max_hp < MAX_HEARTS * 8:
		max_hp += 8
		refill += 8

func _tick_health() -> void:
	if hurt > 0:
		hurt -= 1
	if refill > 0:
		refill_wait -= 1
		if refill_wait <= 0:
			refill_wait = REFILL_STEP_FRAMES
			if hp >= max_hp:
				hp = max_hp
				refill = 0
			else:
				hp = min(hp + 8, max_hp)
				refill = max(refill - 8, 0)
				events.append("heart")
		return
	beep_wait -= 1
	if hp <= low_health_line() and beep_wait <= 0:
		beep_wait = BEEP_EVERY
		events.append("beep")

func low_health_line() -> int:
	var hearts := int(max_hp / 8.0)
	if hearts <= 7:
		return 8
	if hearts <= 14:
		return 16
	return 24

## Drawn hero visible this frame? Blinks every other frame while hurt >= 4 (SPEC §3.4).
func hero_visible() -> bool:
	return hurt < 4 or frame % 2 == 0
