extends RefCounted

## Block Collapse (the "same game"): tap a group of two or more touching
## blocks of one colour to clear it. Blocks above fall down; empty columns
## close up to the left. A group of n scores (n - 2)^2; clearing the whole
## board is +1000. The game ends when no group is left. Pure logic.
## grid[x][y]: column x, y = 0 at the bottom; -1 = empty.

const EMPTY := -1
const CLEAR_BONUS := 1000

var cols: int = 10
var rows: int = 12
var colors: int = 4
var grid: Array = []
var score: int = 0
var history: Array = []  # [grid copy, score] for Undo

func new_board(w: int, h: int, n_colors: int, rng: RandomNumberGenerator) -> void:
	cols = w
	rows = h
	colors = n_colors
	grid = []
	for x in w:
		var col: Array = []
		for y in h:
			col.append(rng.randi_range(0, n_colors - 1))
		grid.append(col)
	score = 0
	history = []

func at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return EMPTY
	return grid[x][y]

func group(x: int, y: int) -> Array:
	var c := at(x, y)
	if c == EMPTY:
		return []
	var seen := {Vector2i(x, y): true}
	var todo: Array = [Vector2i(x, y)]
	var out: Array = []
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		out.append(p)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if not seen.has(q) and at(q.x, q.y) == c:
				seen[q] = true
				todo.append(q)
	return out

static func points_for(n: int) -> int:
	return (n - 2) * (n - 2)

## Clears the group at (x, y); returns the number of blocks removed (0 if
## it was a single block or empty).
func remove(x: int, y: int) -> int:
	var g := group(x, y)
	if g.size() < 2:
		return 0
	history.append([_copy(), score])
	for p in g:
		grid[p.x][p.y] = EMPTY
	# Gravity inside each column, then close up empty columns.
	var new_grid: Array = []
	for col in grid:
		var kept: Array = col.filter(func(v): return v != EMPTY)
		if kept.is_empty():
			continue
		while kept.size() < rows:
			kept.append(EMPTY)
		new_grid.append(kept)
	while new_grid.size() < cols:
		var empty: Array = []
		empty.resize(rows)
		empty.fill(EMPTY)
		new_grid.append(empty)
	grid = new_grid
	score += points_for(g.size())
	if remaining() == 0:
		score += CLEAR_BONUS
	return g.size()

func undo() -> bool:
	if history.is_empty():
		return false
	var h: Array = history.pop_back()
	grid = h[0]
	score = h[1]
	return true

func _copy() -> Array:
	var out: Array = []
	for col in grid:
		out.append(col.duplicate())
	return out

func remaining() -> int:
	var n := 0
	for col in grid:
		for v in col:
			if v != EMPTY:
				n += 1
	return n

func has_moves() -> bool:
	for x in cols:
		for y in rows:
			var c := at(x, y)
			if c != EMPTY and (at(x + 1, y) == c or at(x, y + 1) == c):
				return true
	return false
