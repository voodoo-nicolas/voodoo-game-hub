extends RefCounted

## Nonogram (picture logic puzzle). The numbers beside each row / above each
## column are the lengths of its runs of filled cells, in order. Puzzles are
## random pictures that are regenerated until pure line-by-line logic can
## solve them, so no guessing is ever needed. Pure logic, no Nodes.

const UNKNOWN := -1
const EMPTY := 0
const FILLED := 1
const MARKED := 2   # player's "definitely empty" X

var n: int = 10
var solution: Array = []   # n*n of 0/1
var row_clues: Array = []
var col_clues: Array = []
var cells: Array = []      # player's grid: EMPTY / FILLED / MARKED

func new_puzzle(size: int, rng_seed: int = -1) -> void:
	n = size
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	for attempt in 60:
		_random_solution(rng)
		_make_clues()
		if is_line_solvable():
			break
	cells.clear()
	cells.resize(n * n)
	cells.fill(EMPTY)

func _random_solution(rng: RandomNumberGenerator) -> void:
	solution.clear()
	for i in n * n:
		solution.append(1 if rng.randf() < 0.6 else 0)

static func clue_of(line: Array) -> Array:
	var out: Array = []
	var run := 0
	for v in line:
		if v == FILLED:
			run += 1
		elif run > 0:
			out.append(run)
			run = 0
	if run > 0:
		out.append(run)
	return out

func _row(grid: Array, r: int) -> Array:
	return grid.slice(r * n, r * n + n)

func _col(grid: Array, c: int) -> Array:
	var out: Array = []
	for r in n:
		out.append(grid[r * n + c])
	return out

func _make_clues() -> void:
	row_clues.clear()
	col_clues.clear()
	for i in n:
		row_clues.append(clue_of(_row(solution, i)))
		col_clues.append(clue_of(_col(solution, i)))

## Every cell is decided by repeatedly intersecting all placements of each line.
func is_line_solvable() -> bool:
	var g: Array = []
	g.resize(n * n)
	g.fill(UNKNOWN)
	var changed := true
	while changed:
		changed = false
		for horizontal in [true, false]:
			for i in n:
				var line: Array = _row(g, i) if horizontal else _col(g, i)
				if not line.has(UNKNOWN):
					continue
				var clue: Array = row_clues[i] if horizontal else col_clues[i]
				var solved = solve_line(clue, line)
				if solved == null:
					return false
				for k in n:
					if solved[k] != line[k]:
						changed = true
						g[i * n + k if horizontal else k * n + i] = solved[k]
	return not g.has(UNKNOWN)

## Returns the line with every cell fixed that all valid placements agree on,
## or null if no placement fits.
static func solve_line(clue: Array, line: Array) -> Variant:
	var size := line.size()
	var can_fill: Array = []
	var can_empty: Array = []
	can_fill.resize(size)
	can_fill.fill(false)
	can_empty.resize(size)
	can_empty.fill(false)
	var cur: Array = []
	cur.resize(size)
	cur.fill(EMPTY)
	var count := [0]
	_place(clue, 0, 0, cur, line, can_fill, can_empty, count)
	if count[0] == 0:
		return null
	var out: Array = []
	for k in size:
		if can_fill[k] and not can_empty[k]:
			out.append(FILLED)
		elif can_empty[k] and not can_fill[k]:
			out.append(EMPTY)
		else:
			out.append(UNKNOWN)
	return out

static func _place(clue: Array, bi: int, start: int, cur: Array, line: Array, can_fill: Array, can_empty: Array, count: Array) -> void:
	var size := line.size()
	if bi == clue.size():
		for k in range(start, size):
			if line[k] == FILLED:
				return
		count[0] += 1
		for k in size:
			if k < start and cur[k] == FILLED:
				can_fill[k] = true
			else:
				can_empty[k] = true
		return
	var remaining := 0
	for j in range(bi, clue.size()):
		remaining += clue[j] + (1 if j > bi else 0)
	var length: int = clue[bi]
	for s in range(start, size - remaining + 1):
		# cells start..s-1 must be able to be empty
		if s > start and line[s - 1] == FILLED:
			break
		var ok := true
		for k in range(s, s + length):
			if line[k] == EMPTY:
				ok = false
				break
		if not ok:
			continue
		if s + length < size and line[s + length] == FILLED:
			continue
		for k in range(start, s):
			cur[k] = EMPTY
		for k in range(s, s + length):
			cur[k] = FILLED
		if s + length < size:
			cur[s + length] = EMPTY
		_place(clue, bi + 1, min(s + length + 1, size), cur, line, can_fill, can_empty, count)

func get_cell(r: int, c: int) -> int:
	return cells[r * n + c]

func set_cell(r: int, c: int, v: int) -> void:
	cells[r * n + c] = v

## Solved when the player's filled cells produce every clue -- any picture
## that fits the numbers counts, even if it differs from the generated one.
func is_solved() -> bool:
	for i in n:
		if clue_of(_row(cells, i)) != row_clues[i]:
			return false
		if clue_of(_col(cells, i)) != col_clues[i]:
			return false
	return true

func row_done(r: int) -> bool:
	return clue_of(_row(cells, r)) == row_clues[r]

func col_done(c: int) -> bool:
	return clue_of(_col(cells, c)) == col_clues[c]
