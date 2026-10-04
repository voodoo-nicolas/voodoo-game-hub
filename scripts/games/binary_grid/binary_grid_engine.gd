extends RefCounted

## Binary Grid (takuzu): fill every cell with one of two colours so that
## no row or column has three of a colour in a row, and every row and
## column has as many of one colour as the other. Each puzzle has exactly
## one solution. Pure logic, no Nodes. Cells: -1 empty, 0, 1.

const EMPTY := -1

var n: int = 6
var cells: Array = []     # current board, n*n
var given: Array = []     # bool: part of the puzzle (can't be changed)
var solution: Array = []
var moves: int = 0

func new_puzzle(size: int, rng: RandomNumberGenerator) -> void:
	n = size
	var full: Array = []
	full.resize(n * n)
	full.fill(EMPTY)
	_fill_random(full, 0, rng)
	solution = full.duplicate()
	# Take cells away one at a time while the rules alone still fill the
	# board back in: the solution stays unique and never needs a guess.
	var puzzle := solution.duplicate()
	var order: Array = range(n * n)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	for i in order:
		var keep: int = puzzle[i]
		puzzle[i] = EMPTY
		if not _solves_by_logic(puzzle):
			puzzle[i] = keep
	cells = puzzle.duplicate()
	given = []
	for v in puzzle:
		given.append(v != EMPTY)
	moves = 0

## Backtracking fill used to make a random solved grid.
func _fill_random(g: Array, i: int, rng: RandomNumberGenerator) -> bool:
	if i == n * n:
		return true
	var first := rng.randi_range(0, 1)
	for v in [first, 1 - first]:
		g[i] = v
		if _ok_at(g, i) and _fill_random(g, i + 1, rng):
			return true
	g[i] = EMPTY
	return false

## Rules that can be checked as soon as cell i is set.
func _ok_at(g: Array, i: int) -> bool:
	var x := i % n
	var y := i / n
	var v: int = g[i]
	# Three in a row through (x, y)?
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		for start in range(-2, 1):
			var same := 0
			for k in 3:
				var xx: int = x + d.x * (start + k)
				var yy: int = y + d.y * (start + k)
				if xx >= 0 and yy >= 0 and xx < n and yy < n and g[yy * n + xx] == v:
					same += 1
			if same == 3:
				return false
	# Too many of one colour in the row or column?
	var row_c := 0
	var col_c := 0
	for k in n:
		if g[y * n + k] == v:
			row_c += 1
		if g[k * n + x] == v:
			col_c += 1
	return row_c <= n / 2 and col_c <= n / 2

## How many solutions `g` has, stopping at `limit`.
func count_solutions(g: Array, limit: int) -> int:
	var work := g.duplicate()
	if not _propagate(work):
		return 0
	var i := work.find(EMPTY)
	if i < 0:
		return 1
	var total := 0
	for v in [0, 1]:
		var next := work.duplicate()
		next[i] = v
		if _ok_at(next, i):
			total += count_solutions(next, limit - total)
			if total >= limit:
				return total
	return total

func _solves_by_logic(g: Array) -> bool:
	var work := g.duplicate()
	return _propagate(work) and not work.has(EMPTY)

## Fills cells the rules force (pairs, gaps, full counts). False on a contradiction.
func _propagate(g: Array) -> bool:
	var changed := true
	while changed:
		changed = false
		for i in g.size():
			if g[i] != EMPTY:
				continue
			var can0 := _can(g, i, 0)
			var can1 := _can(g, i, 1)
			if not can0 and not can1:
				return false
			if can0 != can1:
				g[i] = 0 if can0 else 1
				changed = true
	return true

func _can(g: Array, i: int, v: int) -> bool:
	g[i] = v
	var ok := _ok_at(g, i)
	g[i] = EMPTY
	return ok

## Tap: empty -> 0 -> 1 -> empty. Givens don't change.
func cycle(i: int) -> bool:
	if given[i]:
		return false
	cells[i] = 0 if cells[i] == EMPTY else (1 if cells[i] == 0 else EMPTY)
	moves += 1
	return true

## Cells breaking a rule right now (three in a row, or too many in a line).
func errors() -> Dictionary:
	var bad := {}
	for i in cells.size():
		if cells[i] != EMPTY and not _ok_at(cells, i):
			bad[i] = true
	return bad

func solved() -> bool:
	return not cells.has(EMPTY) and errors().is_empty()

## A hint: a cell the rules force right now (or any wrong cell).
func hint() -> int:
	for i in cells.size():
		if cells[i] != EMPTY and cells[i] != solution[i]:
			return i
	for i in cells.size():
		if cells[i] == EMPTY and _can(cells, i, 0) != _can(cells, i, 1):
			return i
	return cells.find(EMPTY)
