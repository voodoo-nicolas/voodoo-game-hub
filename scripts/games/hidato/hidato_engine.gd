extends RefCounted

## Hidato: fill the grid with the numbers 1 to N so that every number is next
## to the following one (sideways, up, down or diagonally). A few numbers are
## given. Pure logic, no Nodes. A puzzle is a random winding path through the
## whole grid with some of its numbers shown; any complete valid path that
## matches the given numbers counts as a solution.

## grid size and share of numbers given, per level
const LEVELS := [
	{"size": 4, "given": 0.40},
	{"size": 5, "given": 0.30},
	{"size": 6, "given": 0.24},
	{"size": 7, "given": 0.20},
]

var level: int = 0
var size: int = 4
var solution: Array = []     # cell index -> number
var given: Array = []        # cell index -> bool
var grid: Array = []         # cell index -> number or 0

func total() -> int:
	return size * size

func new_game(lvl: int) -> void:
	level = clampi(lvl, 0, LEVELS.size() - 1)
	size = int(LEVELS[level].size)
	var path: Array = _make_path()
	solution = []
	for i in total():
		solution.append(0)
	for k in path.size():
		solution[path[k]] = k + 1
	given = []
	grid = []
	for i in total():
		given.append(false)
		grid.append(0)
	var nums: Array = []
	for k in range(2, total()):
		nums.append(k)
	nums.shuffle()
	var extra: int = int(round(total() * float(LEVELS[level].given))) - 2
	var chosen: Array = [1, total()]
	chosen.append_array(nums.slice(0, maxi(0, extra)))
	for k in chosen:
		var idx: int = path[k - 1]
		given[idx] = true
		grid[idx] = k

func neighbors(i: int) -> Array:
	var out: Array = []
	var r: int = i / size
	var c: int = i % size
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var rr: int = r + dr
			var cc: int = c + dc
			if rr >= 0 and rr < size and cc >= 0 and cc < size:
				out.append(rr * size + cc)
	return out

func adjacent(a: int, b: int) -> bool:
	return a != b and absi(a / size - b / size) <= 1 and absi(a % size - b % size) <= 1

## A random path that visits every cell once (king moves), found with
## Warnsdorff's rule plus a random tie-break; falls back to a snake.
func _make_path() -> Array:
	for attempt in 40:
		var start: int = randi() % total()
		var visited := {start: true}
		var path: Array = [start]
		var cur := start
		var ok := true
		while path.size() < total():
			var best: Array = []
			var best_deg := 99
			for nb in neighbors(cur):
				if visited.has(nb):
					continue
				var deg := 0
				for n2 in neighbors(nb):
					if not visited.has(n2):
						deg += 1
				if deg < best_deg:
					best_deg = deg
					best = [nb]
				elif deg == best_deg:
					best.append(nb)
			if best.is_empty():
				ok = false
				break
			cur = best[randi() % best.size()]
			visited[cur] = true
			path.append(cur)
		if ok:
			return path
	var snake: Array = []
	for r in size:
		for c in size:
			snake.append(r * size + (c if r % 2 == 0 else size - 1 - c))
	return snake

func cell_of(n: int) -> int:
	return grid.find(n)

## Numbers not on the board yet, in order.
func remaining() -> Array:
	var out: Array = []
	for k in range(1, total() + 1):
		if not grid.has(k):
			out.append(k)
	return out

## Puts `v` (0 clears) in cell i. A number lives in one cell only, so it moves if it was elsewhere.
func set_cell(i: int, v: int) -> bool:
	if given[i]:
		return false
	if v < 0 or v > total():
		return false
	if v > 0:
		var at: int = cell_of(v)
		if at >= 0:
			if given[at]:
				return false
			grid[at] = 0
	grid[i] = v
	return true

func is_complete() -> bool:
	return not grid.has(0)

## Cells whose number and the next one are both placed but not touching.
func conflicts() -> Array:
	var out: Array = []
	for k in range(1, total()):
		var a: int = cell_of(k)
		var b: int = cell_of(k + 1)
		if a >= 0 and b >= 0 and not adjacent(a, b):
			if not out.has(a):
				out.append(a)
			if not out.has(b):
				out.append(b)
	return out

func solved() -> bool:
	return is_complete() and conflicts().is_empty() and _all_numbers_once()

func _all_numbers_once() -> bool:
	for k in range(1, total() + 1):
		if grid.count(k) != 1:
			return false
	return true

func filled_count() -> int:
	var n := 0
	for v in grid:
		if v > 0:
			n += 1
	return n

## Fills one empty cell with its solution number. Returns the cell, or -1 if none.
func hint() -> int:
	var empties: Array = []
	for i in total():
		if grid[i] == 0:
			empties.append(i)
	if empties.is_empty():
		return -1
	var i: int = empties[randi() % empties.size()]
	var v: int = solution[i]
	var at: int = cell_of(v)
	if at >= 0 and not given[at]:
		grid[at] = 0
	if at >= 0 and given[at]:
		return -1
	grid[i] = v
	given[i] = true
	return i

func to_dict() -> Dictionary:
	return {"level": level, "solution": solution, "given": given, "grid": grid}

func from_dict(d: Dictionary) -> bool:
	level = clampi(int(d.get("level", 0)), 0, LEVELS.size() - 1)
	size = int(LEVELS[level].size)
	var sol = d.get("solution", [])
	var gv = d.get("given", [])
	var gr = d.get("grid", [])
	if sol.size() != total() or gv.size() != total() or gr.size() != total():
		return false
	solution = []
	given = []
	grid = []
	for i in total():
		solution.append(int(sol[i]))
		given.append(bool(gv[i]))
		grid.append(int(gr[i]))
	return true
