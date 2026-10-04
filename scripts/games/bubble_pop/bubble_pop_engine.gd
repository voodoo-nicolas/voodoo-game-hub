extends RefCounted

## Bubble Pop: a honeycomb of coloured bubbles hangs from the ceiling. A
## fired bubble sticks where it lands; three or more of one colour touching
## pop, and anything left hanging from nothing falls. Pure logic, no Nodes.
##
## The grid has ROWS rows of COLS cells; a "shifted" row sits half a bubble
## to the right and holds COLS - 1. Neighbouring rows always alternate, so a
## bubble touches two cells in the row above and two below.

const COLS := 10
const ROWS := 14
## A bubble resting on this row (or below) ends the game.
const LOSE_ROW := 12
const START_ROWS := 6
const EMPTY := -1

var grid: Array = []      # ROWS arrays of COLS ints (colour or EMPTY)
var shifted: Array = []   # per row
var colors: int = 5
var score: int = 0

func reset(n_colors: int, rng: RandomNumberGenerator) -> void:
	colors = n_colors
	score = 0
	grid = []
	shifted = []
	for r in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill(EMPTY)
		grid.append(row)
		shifted.append(r % 2 == 1)
	for i in START_ROWS:
		push_row(rng)

func row_len(r: int) -> int:
	return COLS - 1 if shifted[r] else COLS

func valid(r: int, c: int) -> bool:
	return r >= 0 and r < ROWS and c >= 0 and c < row_len(r)

func at(r: int, c: int) -> int:
	return grid[r][c] if valid(r, c) else EMPTY

## Everything moves down a row and a new full row appears at the top.
## Returns false if that pushed a bubble onto the losing line.
func push_row(rng: RandomNumberGenerator) -> bool:
	var top_shift: bool = not shifted[0]
	grid.pop_back()
	shifted.pop_back()
	var row: Array = []
	row.resize(COLS)
	row.fill(EMPTY)
	shifted.push_front(top_shift)
	for c in (COLS - 1 if top_shift else COLS):
		row[c] = rng.randi_range(0, colors - 1)
	grid.push_front(row)
	return not lost()

func neighbours(r: int, c: int) -> Array:
	var out: Array = [[r, c - 1], [r, c + 1]]
	# A shifted row's cell c sits between c and c+1 of the rows next to it.
	var a := c if shifted[r] else c - 1
	for rr in [r - 1, r + 1]:
		out.append([rr, a])
		out.append([rr, a + 1])
	return out.filter(func(p): return valid(p[0], p[1]))

## Centre of a cell, in bubble radii, from the top-left of the board.
func center(r: int, c: int) -> Vector2:
	return Vector2(1.0 + 2.0 * c + (1.0 if shifted[r] else 0.0), 1.0 + r * sqrt(3.0))

func count() -> int:
	var n := 0
	for row in grid:
		for v in row:
			if v != EMPTY:
				n += 1
	return n

## Colours still on the board (what the shooter may load).
func colors_present() -> Array:
	var seen := {}
	for row in grid:
		for v in row:
			if v != EMPTY:
				seen[v] = true
	return seen.keys()

## Can a bubble rest in this empty cell (touching the ceiling or a bubble)?
func can_rest(r: int, c: int) -> bool:
	if not valid(r, c) or grid[r][c] != EMPTY:
		return false
	if r == 0:
		return true
	for p in neighbours(r, c):
		if grid[p[0]][p[1]] != EMPTY:
			return true
	return false

## Puts a bubble down and settles the board. Returns
## {"popped": [[r, c, colour]...], "dropped": [[r, c, colour]...], "points": int}.
func place(r: int, c: int, color: int) -> Dictionary:
	grid[r][c] = color
	var res := {"popped": [], "dropped": [], "points": 0}
	var group := _flood(r, c, func(rr, cc): return grid[rr][cc] == color)
	if group.size() < 3:
		return res
	for p in group:
		res.popped.append([p[0], p[1], color])
		grid[p[0]][p[1]] = EMPTY
	# Whatever no longer hangs from the ceiling falls.
	var held := {}
	for c0 in row_len(0):
		if grid[0][c0] != EMPTY and not held.has(Vector2i(0, c0)):
			for p in _flood(0, c0, func(rr, cc): return grid[rr][cc] != EMPTY):
				held[Vector2i(p[0], p[1])] = true
	for rr in ROWS:
		for cc in row_len(rr):
			if grid[rr][cc] != EMPTY and not held.has(Vector2i(rr, cc)):
				res.dropped.append([rr, cc, grid[rr][cc]])
				grid[rr][cc] = EMPTY
	# 10 a pop; falling bubbles are worth more the more of them fall.
	res.points = res.popped.size() * 10 + res.dropped.size() * (20 + 5 * res.dropped.size())
	score += res.points
	return res

func _flood(r: int, c: int, ok: Callable) -> Array:
	var seen := {Vector2i(r, c): true}
	var todo: Array = [[r, c]]
	var out: Array = []
	while not todo.is_empty():
		var p: Array = todo.pop_back()
		out.append(p)
		for q in neighbours(p[0], p[1]):
			var k := Vector2i(q[0], q[1])
			if not seen.has(k) and ok.call(q[0], q[1]):
				seen[k] = true
				todo.append(q)
	return out

func lost() -> bool:
	for r in range(LOSE_ROW, ROWS):
		for v in grid[r]:
			if v != EMPTY:
				return true
	return false
