extends RefCounted

## Frog Crossing: hop across the busy road, then ride the logs over the river
## into one of the five homes at the top. Fill all five to advance a level.
## Three lives, 30 seconds per life. Pure simulation on an 11×13 grid.

const COLS := 11
const ROWS := 13            # row 0 = homes, 1-5 river, 6 bank, 7-11 road, 12 start
const HOMES := [1, 3, 5, 7, 9]
const LIFE_TIME := 30.0

var lanes: Array = []       # index = row: {kind, speed, objects: [{x, len}]}
var frog := Vector2(5, 12)  # x can be fractional while riding a log
var homes: Array = [false, false, false, false, false]
var lives: int = 3
var score: int = 0
var level: int = 1
var time_left: float = LIFE_TIME
var best_row: int = 12
var over: bool = false
var death_flash: float = 0.0

func reset() -> void:
	lives = 3
	score = 0
	level = 1
	over = false
	homes = [false, false, false, false, false]
	_build_lanes()
	_respawn()

func _build_lanes() -> void:
	lanes.clear()
	for r in ROWS:
		lanes.append({"kind": "safe", "speed": 0.0, "objects": []})
	var mult := 1.0 + (level - 1) * 0.18
	var river := [[1.2, 3, 3], [-0.9, 4, 2], [1.6, 2, 3], [-1.1, 5, 2], [0.8, 3, 3]]
	for i in 5:
		var spec: Array = river[i]
		lanes[1 + i] = _lane("river", spec[0] * mult, spec[1], spec[2])
	var road := [[-1.4, 1, 3], [1.0, 2, 2], [-2.0, 1, 2], [1.3, 1, 3], [-0.9, 2, 2]]
	for i in 5:
		var spec: Array = road[i]
		lanes[7 + i] = _lane("road", spec[0] * mult, spec[1], spec[2])

func _lane(kind: String, speed: float, length: int, count: int) -> Dictionary:
	var objs: Array = []
	var span := float(COLS + 4)
	for k in count:
		objs.append({"x": k * span / count + randf_range(0, 1.5), "len": length})
	return {"kind": kind, "speed": speed, "objects": objs}

func _respawn() -> void:
	frog = Vector2(5, 12)
	best_row = 12
	time_left = LIFE_TIME

func hop(d: Vector2i) -> void:
	if over:
		return
	var nx: float = round(frog.x) + d.x if d.x != 0 else frog.x
	var ny: float = frog.y + d.y
	if nx < 0 or nx > COLS - 1 or ny < 0 or ny > ROWS - 1:
		return
	frog = Vector2(nx, ny)
	if int(ny) < best_row:
		best_row = int(ny)
		score += 10
	if int(ny) == 0:
		_land_home()

func _land_home() -> void:
	var col := int(round(frog.x))
	var slot := HOMES.find(col)
	if slot == -1 or homes[slot]:
		_die()
		return
	homes[slot] = true
	score += 50 + int(time_left) * 2
	if not homes.has(false):
		score += 200
		level += 1
		homes = [false, false, false, false, false]
		_build_lanes()
	_respawn()

func _die() -> void:
	lives -= 1
	death_flash = 0.6
	if lives <= 0:
		over = true
		return
	_respawn()

## Wrapped distance test: does [x, x+len) cover position p in a lane that
## loops over COLS + 4 cells?
static func _covers(obj: Dictionary, p: float, margin: float) -> bool:
	var span := float(COLS + 4)
	var start: float = fposmod(obj.x, span) - 2.0
	for shift in [-span, 0.0, span]:
		var a: float = start + shift
		if p + margin > a and p - margin < a + obj.len:
			return true
	return false

func step(delta: float) -> void:
	if over:
		return
	death_flash = max(0.0, death_flash - delta)
	for lane in lanes:
		for o in lane.objects:
			o.x += lane.speed * delta
	time_left -= delta
	if time_left <= 0.0:
		_die()
		return
	var row := int(frog.y)
	var lane: Dictionary = lanes[row]
	var cx := frog.x + 0.5
	if lane.kind == "road":
		for o in lane.objects:
			if _covers(o, cx, 0.3):
				_die()
				return
	elif lane.kind == "river":
		var riding := false
		for o in lane.objects:
			if _covers(o, cx, -0.1):
				riding = true
				break
		if not riding:
			_die()
			return
		frog.x += lane.speed * delta
		if frog.x < -0.4 or frog.x > COLS - 0.6:
			_die()

## Screen-space cell x of an object's left edge (can be off-grid).
static func object_x(obj: Dictionary) -> float:
	return fposmod(obj.x, float(COLS + 4)) - 2.0
