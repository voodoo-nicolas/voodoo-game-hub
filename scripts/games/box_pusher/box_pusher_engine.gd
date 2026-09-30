extends RefCounted

## Box Pusher: walk around the warehouse and push every box onto a goal.
## You can push one box at a time and never pull. Levels are generated from
## the level number by playing the game backwards (starting solved, then
## *pulling* boxes off their goals), so every level is solvable by
## construction. Pure logic, no Nodes.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var w: int = 8
var h: int = 8
var walls: Dictionary = {}    # Vector2i -> true
var goals: Dictionary = {}
var boxes: Dictionary = {}
var player := Vector2i.ZERO
var start_boxes: Dictionary = {}
var start_player := Vector2i.ZERO
var moves: int = 0
var pushes: int = 0
var history: Array = []       # [player, moved_box_from or null, moved_box_to]

func load_level(level: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * level + 12345
	var box_count: int = clampi(2 + level / 4, 2, 5)
	var size: int = clampi(7 + level / 5, 7, 10)
	for attempt in 200:
		if _generate(rng, size, box_count, 40 + level * 6):
			break
	start_boxes = boxes.duplicate()
	start_player = player
	restart()

func restart() -> void:
	boxes = start_boxes.duplicate()
	player = start_player
	moves = 0
	pushes = 0
	history.clear()

func is_floor(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and not walls.has(p)

func move(d: Vector2i) -> bool:
	var to := player + d
	if not is_floor(to):
		return false
	if boxes.has(to):
		var beyond := to + d
		if not is_floor(beyond) or boxes.has(beyond):
			return false
		boxes.erase(to)
		boxes[beyond] = true
		history.append([player, to, beyond])
		pushes += 1
	else:
		history.append([player, null, null])
	player = to
	moves += 1
	return true

func undo() -> bool:
	if history.is_empty():
		return false
	var h_: Array = history.pop_back()
	player = h_[0]
	if h_[1] != null:
		boxes.erase(h_[2])
		boxes[h_[1]] = true
		pushes -= 1
	moves -= 1
	return true

func is_solved() -> bool:
	for b in boxes:
		if not goals.has(b):
			return false
	return true

# ---------- generation ----------

func _generate(rng: RandomNumberGenerator, size: int, box_count: int, steps: int) -> bool:
	w = size
	h = size
	walls.clear()
	goals.clear()
	boxes.clear()
	for y in h:
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 or rng.randf() < 0.16:
				walls[Vector2i(x, y)] = true
	var floor_cells := _largest_region()
	if floor_cells.size() < box_count * 5 + 8:
		return false
	# Everything outside the main region becomes wall.
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if not floor_cells.has(p):
				walls[p] = true
	var cells: Array = floor_cells.keys()
	_shuffle(cells, rng)
	for i in box_count:
		goals[cells[i]] = true
		boxes[cells[i]] = true
	player = cells[box_count]
	# Play backwards: walk around, sometimes pulling the box behind you.
	for i in steps * 6:
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var to := player + d
		if not is_floor(to) or boxes.has(to):
			continue
		var behind := player - d
		if boxes.has(behind) and rng.randf() < 0.7:
			boxes.erase(behind)
			boxes[player] = true
		player = to
	for b in boxes:
		if goals.has(b):
			return false
	return true

func _largest_region() -> Dictionary:
	var best: Dictionary = {}
	var seen: Dictionary = {}
	for y in h:
		for x in w:
			var s := Vector2i(x, y)
			if walls.has(s) or seen.has(s):
				continue
			var region := {s: true}
			seen[s] = true
			var stack: Array = [s]
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				for d in DIRS:
					var q: Vector2i = p + d
					if is_floor(q) and not seen.has(q):
						seen[q] = true
						region[q] = true
						stack.append(q)
			if region.size() > best.size():
				best = region
	return best

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
