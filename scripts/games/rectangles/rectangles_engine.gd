extends RefCounted

## Rectangles (working title Gridmaster) -- board state. Split the grid into rectangles:
## each holds exactly one number and has that many cells. Any valid tiling wins; the
## stored solution is only used for hints. Pure logic, headless-testable.

const Solver = preload("res://scripts/games/rectangles/rectangles_solver.gd")

var rows: int = 0
var cols: int = 0
var clues: Array = []      # [{"r", "c", "n"}]
var solution: Array = []   # [{"r", "c", "h", "w"}] from the generator
var puzzle_id: String = ""
var difficulty: int = 1
var placed: Array = []     # [[r, c, h, w], ...] in placing order
var undo_stack: Array = [] # earlier copies of `placed`
var clue_at: Array = []    # cell -> clue index or -1

func load_puzzle(p: Dictionary) -> bool:
	var size: Array = p.get("size", [])
	if size.size() != 2:
		return false
	rows = int(size[0])
	cols = int(size[1])
	clues = []
	for cl in p.get("clues", []):
		clues.append({"r": int(cl.r), "c": int(cl.c), "n": int(cl.n)})
	solution = []
	for s in p.get("solution", []):
		solution.append({"r": int(s.r), "c": int(s.c), "h": int(s.h), "w": int(s.w)})
	puzzle_id = str(p.get("id", ""))
	difficulty = int(p.get("difficulty", 1))
	clue_at = Solver.clue_grid(rows, cols, clues)
	placed = []
	undo_stack = []
	return clue_sum() == rows * cols

func puzzle_dict() -> Dictionary:
	return {"id": puzzle_id, "size": [rows, cols], "clues": clues, "solution": solution, "difficulty": difficulty}

func clue_sum() -> int:
	var t := 0
	for cl in clues:
		t += int(cl.n)
	return t

## The rectangle spanning two corner cells, whichever way the drag went.
func rect_from(a: Vector2i, b: Vector2i) -> Array:
	var r0 := mini(a.y, b.y)
	var c0 := mini(a.x, b.x)
	return [r0, c0, absi(a.y - b.y) + 1, absi(a.x - b.x) + 1]

## Clue index if `rc` holds exactly one clue and its area equals it, else -1.
func clue_of(rc: Array) -> int:
	var found := -1
	for i in Solver.cells_of(rc, cols):
		var k: int = clue_at[i]
		if k >= 0:
			if found >= 0:
				return -1
			found = k
	if found < 0 or int(clues[found].n) != rc[2] * rc[3]:
		return -1
	return found

func is_valid(rc: Array) -> bool:
	return clue_of(rc) >= 0

func _overlaps(a: Array, b: Array) -> bool:
	return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]

## Places a valid rectangle; rectangles it overlaps are removed. False if not valid.
func place(rc: Array) -> bool:
	if not is_valid(rc):
		return false
	for p in placed:
		if p == rc:
			return false
	_push_undo()
	var keep: Array = []
	for p in placed:
		if not _overlaps(p, rc):
			keep.append(p)
	keep.append(rc.duplicate())
	placed = keep
	return true

## Index into `placed` of the rectangle covering a cell, or -1.
func placed_at(cell: Vector2i) -> int:
	for i in placed.size():
		var p: Array = placed[i]
		if cell.y >= p[0] and cell.y < p[0] + p[2] and cell.x >= p[1] and cell.x < p[1] + p[3]:
			return i
	return -1

func remove_at(cell: Vector2i) -> bool:
	var i := placed_at(cell)
	if i < 0:
		return false
	_push_undo()
	placed.remove_at(i)
	return true

func reset() -> bool:
	if placed.is_empty():
		return false
	_push_undo()
	placed = []
	return true

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	placed = undo_stack.pop_back()
	return true

func _push_undo() -> void:
	undo_stack.append(placed.duplicate(true))
	if undo_stack.size() > 200:
		undo_stack.pop_front()

## Progress counter: valid rectangles on the board (all placed ones are valid).
func placed_count() -> int:
	return placed.size()

func covered_count() -> int:
	var t := 0
	for p in placed:
		t += p[2] * p[3]
	return t

## Won: every cell covered by valid, non-overlapping rectangles. Any tiling counts.
func solved() -> bool:
	if covered_count() != rows * cols or placed.size() != clues.size():
		return false
	var seen := {}
	for p in placed:
		var k := clue_of(p)
		if k < 0 or seen.has(k):
			return false
		seen[k] = true
	return true

## Clue index -> rect from the stored solution.
func solution_by_clue() -> Dictionary:
	var out := {}
	for s in solution:
		var rc := [s.r, s.c, s.h, s.w]
		var k := clue_of(rc)
		if k >= 0:
			out[k] = rc
	return out

## A shape from the correct fill of the current board: first the right shape for a number the
## player placed wrongly, then the next one logic proves from their correct ones. [] if none.
func hint_rect() -> Array:
	var sol := solution_by_clue()
	var good := {}
	var wrong: Array = []
	for p in placed:
		var k := clue_of(p)
		if k >= 0 and sol.has(k) and sol[k] == p:
			good[k] = p
		else:
			wrong.append(p)
	# First fix the current board: the right shape for a wrongly placed rectangle's number.
	for p in wrong:
		var k := clue_of(p)
		if k >= 0 and sol.has(k):
			return sol[k]
	var res := Solver.logic_solve(rows, cols, clues, good)
	for st in res.steps:
		var k: int = st[0]
		if sol.has(k) and sol[k] == st[1]:
			return st[1]
	for k in sol:
		if not good.has(k):
			return sol[k]
	return []

## "6 = 1×6, 2×3, 3×2, 6×1": every height × width for a clue (the factor helper).
static func shapes(n: int) -> Array:
	var out: Array = []
	for h in range(1, n + 1):
		if n % h == 0:
			out.append(Vector2i(n / h, h))  # x = width, y = height
	return out

func to_dict() -> Dictionary:
	return {"puzzle": puzzle_dict(), "placed": placed}

func from_dict(d: Dictionary) -> bool:
	if not d.has("puzzle") or not load_puzzle(d.puzzle):
		return false
	placed = []
	for p in d.get("placed", []):
		var rc := [int(p[0]), int(p[1]), int(p[2]), int(p[3])]
		if is_valid(rc):
			placed.append(rc)
	return true
