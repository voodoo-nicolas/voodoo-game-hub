extends RefCounted

## Barrel Climb: climb six slanted girders to the top while the Bone King
## throws barrels down at you. Barrels roll along each girder, drop off its
## open end onto the one below, and sometimes take a ladder down. Jump over
## them for points, grab the hammer to smash them, reach the doll at the top
## to clear the level. Pure simulation in world units (W x H), stepped by
## the game; y grows downwards and an object's y is its feet / bottom.

const W := 720.0
const H := 1040.0
const FLOORS := 6             # girders 0 (bottom) .. 5 (the King's)
const GOAL := 6               # the small platform at the very top
const SLOPE := 26.0           # how much each girder drops across its width
const GAP := 84.0             # the open end barrels fall off
const SPEED := 165.0          # player walk
const CLIMB := 120.0
const JUMP_V := 340.0
const GRAVITY := 950.0
const PLAYER_H := 36.0
const BARREL_R := 14.0
const LADDER_GRAB := 18.0
const BONUS_START := 5000
const BONUS_STEP := 100       # lost every BONUS_EVERY seconds
const BONUS_EVERY := 2.0
const HAMMER_TIME := 9.0
const START_X := 110.0
const KING_X := 70.0
const GOAL_X0 := 250.0
const GOAL_X1 := 470.0
const GOAL_LADDER_X := 300.0
## Starting difficulty: Easy / Normal / Hard.
const DIFFS := [
	{"speed": 120.0, "every": 3.4, "ladder": 0.18},
	{"speed": 145.0, "every": 2.8, "ladder": 0.28},
	{"speed": 175.0, "every": 2.2, "ladder": 0.38},
]

var diff: int = 1
var level: int = 1
var lives: int = 3
var score: int = 0
var bonus: int = BONUS_START
var state := "play"           # play, dead, won, over

var ladders: Array = []       # {"x", "lo", "hi"}
var barrels: Array = []       # see _spawn_barrel()
var hammer: Dictionary = {}   # {"x", "floor"} while not picked up
var hammer_t: float = 0.0

# player
var px: float = START_X
var py: float = 0.0
var pfloor: int = 0
var mode := "walk"            # walk, climb, air
var vx: float = 0.0
var vy: float = 0.0
var facing: int = 1
var climb_ladder: Dictionary = {}
var walk_t: float = 0.0       # for the leg animation

var _throw_t: float = 1.5
var _bonus_t: float = 0.0
var _next_id: int = 0
var rng := RandomNumberGenerator.new()

func reset(p_diff: int = 1, seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	diff = clampi(p_diff, 0, DIFFS.size() - 1)
	level = 1
	lives = 3
	score = 0
	new_level()

# ---------- the stage ----------

static func floor_dir(i: int) -> int:
	return 1 if i % 2 == 1 else -1   # which way barrels roll

static func floor_x0(i: int) -> float:
	if i == GOAL:
		return GOAL_X0
	if i == 0:
		return 0.0
	return 0.0 if floor_dir(i) > 0 else GAP

static func floor_x1(i: int) -> float:
	if i == GOAL:
		return GOAL_X1
	if i == 0:
		return W
	return W - GAP if floor_dir(i) > 0 else W

static func floor_base(i: int) -> float:
	return 120.0 if i == GOAL else 990.0 - i * 150.0

## The top of girder i at x (girders lean down the way barrels roll).
static func y_at(i: int, x: float) -> float:
	var base := floor_base(i)
	if i == GOAL:
		return base
	var x0 := floor_x0(i)
	var x1 := floor_x1(i)
	var t := clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	if floor_dir(i) < 0:
		t = 1.0 - t
	return base - SLOPE / 2.0 + SLOPE * t

func new_level() -> void:
	ladders = []
	for i in FLOORS - 1:
		var lo := maxf(floor_x0(i), floor_x0(i + 1)) + 50.0
		var hi := minf(floor_x1(i), floor_x1(i + 1)) - 50.0
		var a := 0.0
		var b := 0.0
		for tries in 50:
			a = rng.randf_range(lo, hi)
			b = rng.randf_range(lo, hi)
			if absf(a - b) > 170.0:
				break
		ladders.append({"x": a, "lo": i, "hi": i + 1})
		ladders.append({"x": b, "lo": i, "hi": i + 1})
	ladders.append({"x": GOAL_LADDER_X, "lo": FLOORS - 1, "hi": GOAL})
	var hf := 2 if level % 2 == 1 else 3
	hammer = {"x": rng.randf_range(floor_x0(hf) + 120.0, floor_x1(hf) - 120.0), "floor": hf}
	bonus = BONUS_START
	_respawn()

func _respawn() -> void:
	barrels = []
	px = START_X
	pfloor = 0
	py = y_at(0, px)
	mode = "walk"
	vx = 0.0
	vy = 0.0
	facing = 1
	hammer_t = 0.0
	climb_ladder = {}
	_throw_t = 1.2
	_bonus_t = 0.0
	state = "play"

func barrel_speed() -> float:
	return minf(300.0, DIFFS[diff].speed + 14.0 * (level - 1))

func throw_every() -> float:
	return maxf(1.0, DIFFS[diff].every - 0.22 * (level - 1))

func ladder_chance() -> float:
	return minf(0.65, DIFFS[diff].ladder + 0.05 * (level - 1))

# ---------- one frame ----------

## move: -1 / 0 / 1, vert: -1 up / 0 / 1 down, jump: pressed this frame.
## Returns the frame's events: "jump", "over" (jumped a barrel), "smash",
## "hammer", "hit", "timeout", "win", "throw", "land".
func step(dt: float, move: int, vert: int, jump: bool) -> Array:
	var ev: Array = []
	if state != "play":
		return ev
	_bonus_t += dt
	while _bonus_t >= BONUS_EVERY:
		_bonus_t -= BONUS_EVERY
		bonus = maxi(0, bonus - BONUS_STEP)
		if bonus == 0:
			_die(ev, "timeout")
			return ev
	if hammer_t > 0.0:
		hammer_t = maxf(0.0, hammer_t - dt)
	_step_player(dt, move, vert, jump, ev)
	if state != "play":
		return ev
	_throw_t -= dt
	if _throw_t <= 0.0:
		_throw_t = throw_every() * rng.randf_range(0.75, 1.3)
		_spawn_barrel()
		ev.append("throw")
	_step_barrels(dt, ev)
	return ev

func _step_player(dt: float, move: int, vert: int, jump: bool, ev: Array) -> void:
	if move != 0:
		facing = move
	match mode:
		"walk":
			var l := _ladder_here(vert)
			if not l.is_empty() and hammer_t <= 0.0:
				mode = "climb"
				climb_ladder = l
				px = l.x
				py += 2.0 * vert   # step onto the ladder
				return
			if jump and hammer_t <= 0.0:
				mode = "air"
				vy = -JUMP_V
				vx = move * SPEED
				ev.append("jump")
				return
			px = clampf(px + move * SPEED * dt, floor_x0(pfloor) + 12.0, floor_x1(pfloor) - 12.0)
			py = y_at(pfloor, px)
			if move != 0:
				walk_t += dt
			if not hammer.is_empty() and hammer.floor == pfloor and absf(hammer.x - px) < 24.0:
				hammer = {}
				hammer_t = HAMMER_TIME
				ev.append("hammer")
		"climb":
			var top := y_at(climb_ladder.hi, px)
			var bottom := y_at(climb_ladder.lo, px)
			py += vert * CLIMB * dt
			if vert != 0:
				walk_t += dt
			if py <= top:
				py = top
				pfloor = climb_ladder.hi
				mode = "walk"
				if pfloor == GOAL:
					state = "won"
					score += bonus
					ev.append("win")
			elif py >= bottom:
				py = bottom
				pfloor = climb_ladder.lo
				mode = "walk"
		"air":
			vy += GRAVITY * dt
			px = clampf(px + vx * dt, floor_x0(pfloor) + 12.0, floor_x1(pfloor) - 12.0)
			py += vy * dt
			var g := y_at(pfloor, px)
			if vy > 0.0 and py >= g:
				py = g
				mode = "walk"
				ev.append("land")

## A ladder the player can get on from here: up from its bottom, down from its top.
func _ladder_here(vert: int) -> Dictionary:
	if vert == 0:
		return {}
	for l in ladders:
		if absf(l.x - px) > LADDER_GRAB:
			continue
		if vert < 0 and l.lo == pfloor:
			return l
		if vert > 0 and l.hi == pfloor:
			return l
	return {}

func _spawn_barrel() -> void:
	var f := FLOORS - 1
	_next_id += 1
	barrels.append({"id": _next_id, "x": KING_X + 70.0, "y": y_at(f, KING_X + 70.0), "floor": f, "mode": "roll",
		"vx": 0.0, "vy": 0.0, "ladder": {}, "seen": {}, "jumped": false, "spin": 0.0})

func _step_barrels(dt: float, ev: Array) -> void:
	var speed := barrel_speed()
	var keep: Array = []
	for b in barrels:
		match b.mode:
			"roll":
				var d := floor_dir(b.floor)
				var old_x: float = b.x
				b.x += d * speed * dt
				b.spin += d * speed * dt / BARREL_R
				# Passing the top of a ladder going down: maybe take it.
				for l in ladders:
					if l.hi == b.floor and l.hi != GOAL and not b.seen.has(l.x) and (old_x - l.x) * (b.x - l.x) <= 0.0:
						b.seen[l.x] = true
						if rng.randf() < ladder_chance():
							b.mode = "ladder"
							b.ladder = l
							b.x = l.x
							break
				if b.mode == "roll":
					if b.x < floor_x0(b.floor) or b.x > floor_x1(b.floor):
						if b.floor == 0:
							continue   # into the oil drum
						b.mode = "fall"
						b.vx = d * speed * 0.45
						b.vy = 0.0
					else:
						b.y = y_at(b.floor, b.x)
			"fall":
				b.vy += GRAVITY * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				b.spin += b.vx * dt / BARREL_R
				var below: int = b.floor - 1
				if below >= 0 and b.x >= floor_x0(below) and b.x <= floor_x1(below) and b.y >= y_at(below, b.x):
					b.floor = below
					b.y = y_at(below, b.x)
					b.mode = "roll"
				elif b.y > H + 60.0:
					continue
			"ladder":
				b.y += speed * 0.7 * dt
				var bottom := y_at(b.ladder.lo, b.x)
				if b.y >= bottom:
					b.y = bottom
					b.floor = b.ladder.lo
					b.mode = "roll"
		# Against the player.
		var bc := Vector2(b.x, b.y - BARREL_R)
		var pc := Vector2(px, py - PLAYER_H / 2.0)
		if hammer_t > 0.0 and absf(bc.x - (px + facing * 22.0)) < 34.0 and absf(bc.y - (py - 30.0)) < 40.0:
			score += 300
			ev.append("smash")
			continue
		if bc.distance_to(pc) < BARREL_R + 12.0:
			_die(ev, "hit")
			return
		if mode == "air" and not b.jumped and absf(b.x - px) < 18.0 and b.y - BARREL_R * 2.0 > py - 4.0 and b.y - py < 80.0:
			b.jumped = true
			score += 100
			ev.append("over")
		keep.append(b)
	barrels = keep

func _die(ev: Array, why: String) -> void:
	state = "dead"
	lives -= 1
	ev.append(why)

## After the pause that follows a death or a cleared level.
func next() -> void:
	if state == "won":
		level += 1
		new_level()
	elif state == "dead":
		if lives <= 0:
			state = "over"
		else:
			var keep_bonus := bonus
			_respawn()
			bonus = maxi(keep_bonus, BONUS_START / 2) if keep_bonus > 0 else BONUS_START / 2
