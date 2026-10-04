extends RefCounted

## Moon Lander: steer a lander down onto a flat pad between the mountains.
## Gravity pulls it down; the engine pushes it the way its nose points and
## burns fuel. Touch down slowly and upright on a pad to land (narrow pads
## score more). Pure simulation in world units, stepped by the game.

const GRAVITY_BASE := 26.0
const THRUST := 70.0
const TURN := 2.4             # radians / second
const FUEL_BURN := 9.0        # per second of thrust
const SAFE_VY := 42.0
const SAFE_VX := 26.0
const SAFE_TILT := 0.22       # radians
const LANDER_H := 18.0        # from centre to feet
const MULTS := [2, 3, 5]

var size := Vector2(704, 1000)
var terrain: PackedVector2Array = PackedVector2Array()
var pads: Array = []          # {"x0", "x1", "y", "mult"}
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var angle: float = 0.0        # 0 = upright, + = clockwise
var fuel: float = 0.0
var level: int = 1
var landers: int = 3
var score: int = 0
var state := "flying"         # flying, landed, crashed, over
var last_pad: Dictionary = {}
var rng := RandomNumberGenerator.new()

func reset(world: Vector2, seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	size = world
	level = 1
	landers = 3
	score = 0
	new_terrain()

func gravity() -> float:
	return GRAVITY_BASE * (1.0 + 0.08 * (level - 1))

func new_terrain() -> void:
	var w := size.x
	var floor_y := size.y - 40.0
	var top_y := size.y * 0.55
	var n := 22
	var step := w / n
	var heights: Array = []
	for i in n + 1:
		heights.append(rng.randf_range(top_y, floor_y))
	# Three pads at random places: narrower pads pay more.
	pads = []
	var used := {}
	for mult in MULTS:
		var cells := 3 if mult == 2 else (2 if mult == 3 else 1)
		for tries in 40:
			var i0 := rng.randi_range(1, n - cells - 1)
			var clash := false
			for k in range(i0 - 1, i0 + cells + 2):
				if used.has(k):
					clash = true
			if clash:
				continue
			var y: float = heights[i0]
			for k in range(i0, i0 + cells + 1):
				heights[k] = y
				used[k] = true
			pads.append({"x0": i0 * step, "x1": (i0 + cells) * step, "y": y, "mult": mult})
			break
	terrain = PackedVector2Array()
	for i in n + 1:
		terrain.append(Vector2(i * step, heights[i]))
	_spawn()

func _spawn() -> void:
	pos = Vector2(rng.randf_range(size.x * 0.35, size.x * 0.8), 175.0)  # below the readouts
	vel = Vector2(rng.randf_range(-30.0, 30.0), 0.0)
	angle = 0.0
	fuel = maxf(60.0, 140.0 - (level - 1) * 8.0)
	state = "flying"

func ground_at(x: float) -> float:
	for i in terrain.size() - 1:
		var a := terrain[i]
		var b := terrain[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(0.001, b.x - a.x))
	return size.y

func pad_under(x: float) -> Dictionary:
	for p in pads:
		if x - 8.0 >= p.x0 and x + 8.0 <= p.x1:
			return p
	return {}

## One frame: turn = -1 / 0 / 1, thrust on or off. Returns "landed",
## "crashed" or "" (still flying).
func step(dt: float, turn: int, thrust: bool) -> String:
	if state != "flying":
		return ""
	angle = clampf(angle + turn * TURN * dt, -PI / 2.0, PI / 2.0)
	vel.y += gravity() * dt
	if thrust and fuel > 0.0:
		vel += Vector2(sin(angle), -cos(angle)) * THRUST * dt
		fuel = maxf(0.0, fuel - FUEL_BURN * dt)
	pos += vel * dt
	if pos.x < 0.0 or pos.x > size.x:
		pos.x = clampf(pos.x, 0.0, size.x)
		vel.x = -vel.x * 0.4
	if pos.y < 10.0:
		pos.y = 10.0
		vel.y = maxf(vel.y, 0.0)
	var feet := pos.y + LANDER_H
	if feet >= ground_at(pos.x) or feet >= ground_at(pos.x - 10.0) or feet >= ground_at(pos.x + 10.0):
		var pad := pad_under(pos.x)
		if not pad.is_empty() and vel.y <= SAFE_VY and absf(vel.x) <= SAFE_VX and absf(angle) <= SAFE_TILT:
			state = "landed"
			last_pad = pad
			pos.y = pad.y - LANDER_H
			score += landing_points()
			return "landed"
		state = "crashed"
		landers -= 1
		return "crashed"
	return ""

func landing_points() -> int:
	if last_pad.is_empty():
		return 0
	var softness := clampf(1.0 - vel.y / SAFE_VY, 0.0, 1.0)
	return int(50 * last_pad.mult + fuel * 2.0 + softness * 50.0)

## After a landing: the next level; after a crash: try again (or game over).
func next() -> void:
	if state == "landed":
		level += 1
		new_terrain()
	elif state == "crashed":
		if landers <= 0:
			state = "over"
		else:
			_spawn()

func altitude() -> float:
	return maxf(0.0, ground_at(pos.x) - pos.y - LANDER_H)
