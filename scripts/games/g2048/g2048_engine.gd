extends RefCounted

const SIZE := 4

var grid: Array = []  # 4x4 of int, 0 = empty
var score: int = 0

func _init() -> void:
	reset()

func reset() -> void:
	grid = []
	for r in range(SIZE):
		grid.append([0, 0, 0, 0])
	score = 0
	_add_random_tile()
	_add_random_tile()

func _add_random_tile() -> void:
	var empties: Array = []
	for r in range(SIZE):
		for c in range(SIZE):
			if grid[r][c] == 0:
				empties.append(Vector2i(r, c))
	if empties.is_empty():
		return
	var pos: Vector2i = empties[randi() % empties.size()]
	grid[pos.x][pos.y] = 4 if randf() < 0.1 else 2

## dir: "left", "right", "up", "down". Returns true if the board actually changed.
func move(dir: String) -> bool:
	var before: Array = grid.duplicate(true)

	match dir:
		"left":
			for r in range(SIZE):
				grid[r] = _slide_row(grid[r])
		"right":
			for r in range(SIZE):
				var reversed: Array = grid[r].duplicate()
				reversed.reverse()
				var slid: Array = _slide_row(reversed)
				slid.reverse()
				grid[r] = slid
		"up":
			for c in range(SIZE):
				var col: Array = []
				for r in range(SIZE):
					col.append(grid[r][c])
				col = _slide_row(col)
				for r in range(SIZE):
					grid[r][c] = col[r]
		"down":
			for c in range(SIZE):
				var col: Array = []
				for r in range(SIZE):
					col.append(grid[r][c])
				col.reverse()
				col = _slide_row(col)
				col.reverse()
				for r in range(SIZE):
					grid[r][c] = col[r]

	var changed: bool = grid != before
	if changed:
		_add_random_tile()
	return changed

func _slide_row(row: Array) -> Array:
	var vals: Array = []
	for v in row:
		if v != 0:
			vals.append(v)
	var i := 0
	while i < vals.size() - 1:
		if vals[i] == vals[i + 1]:
			vals[i] *= 2
			score += vals[i]
			vals.remove_at(i + 1)
		i += 1
	while vals.size() < SIZE:
		vals.append(0)
	return vals

func can_move() -> bool:
	for r in range(SIZE):
		for c in range(SIZE):
			if grid[r][c] == 0:
				return true
			if c < SIZE - 1 and grid[r][c] == grid[r][c + 1]:
				return true
			if r < SIZE - 1 and grid[r][c] == grid[r + 1][c]:
				return true
	return false

func has_2048() -> bool:
	for row in grid:
		for v in row:
			if v >= 2048:
				return true
	return false
