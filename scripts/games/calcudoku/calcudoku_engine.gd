extends RefCounted

## Calcudoku: fill an n×n grid with 1..n, no repeats in any row or column, so
## that each outlined cage's numbers combine (with the cage's operation) to
## its target. Puzzles are regenerated until a solver finds exactly one
## solution (bounded effort; the win check itself only checks the rules).
## Pure logic, no Nodes.

var n: int = 4
var solution: Array = []   # n*n
var cage_of: Array = []    # n*n -> cage index
var cages: Array = []      # [{cells: Array[int], op: String, target: int}]
var values: Array = []     # player's entries, 0 = blank

var _budget: int = 0

func new_puzzle(size: int, rng_seed: int = -1) -> void:
	n = size
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	for attempt in 25:
		_make_solution(rng)
		_make_cages(rng)
		if count_solutions(2, 60000) == 1:
			break
	values.clear()
	values.resize(n * n)
	values.fill(0)

func _make_solution(rng: RandomNumberGenerator) -> void:
	var rows: Array = range(n)
	var cols: Array = range(n)
	var syms: Array = range(1, n + 1)
	_shuffle(rows, rng)
	_shuffle(cols, rng)
	_shuffle(syms, rng)
	solution.clear()
	solution.resize(n * n)
	for r in n:
		for c in n:
			solution[r * n + c] = syms[(rows[r] + cols[c]) % n]

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _make_cages(rng: RandomNumberGenerator) -> void:
	cage_of.clear()
	cage_of.resize(n * n)
	cage_of.fill(-1)
	cages.clear()
	var order: Array = range(n * n)
	_shuffle(order, rng)
	for start in order:
		if cage_of[start] != -1:
			continue
		var roll := rng.randf()
		var target_size := 1 if roll < 0.1 else (2 if roll < 0.55 else (3 if roll < 0.9 else 4))
		var cells: Array = [start]
		cage_of[start] = cages.size()
		while cells.size() < target_size:
			var options: Array = []
			for cell in cells:
				for nb in _neighbors(cell):
					if cage_of[nb] == -1 and not options.has(nb):
						options.append(nb)
			if options.is_empty():
				break
			var pick: int = options[rng.randi_range(0, options.size() - 1)]
			cage_of[pick] = cages.size()
			cells.append(pick)
		cages.append(_make_op(cells, rng))

func _neighbors(i: int) -> Array:
	var r := i / n
	var c := i % n
	var out: Array = []
	if r > 0: out.append(i - n)
	if r < n - 1: out.append(i + n)
	if c > 0: out.append(i - 1)
	if c < n - 1: out.append(i + 1)
	return out

func _make_op(cells: Array, rng: RandomNumberGenerator) -> Dictionary:
	var nums: Array = []
	for cell in cells:
		nums.append(solution[cell])
	if cells.size() == 1:
		return {"cells": cells, "op": "", "target": nums[0]}
	if cells.size() == 2:
		var a: int = max(nums[0], nums[1])
		var b: int = min(nums[0], nums[1])
		if a % b == 0 and rng.randf() < 0.5:
			return {"cells": cells, "op": "÷", "target": a / b}
		var roll := rng.randf()
		if roll < 0.45:
			return {"cells": cells, "op": "−", "target": a - b}
		elif roll < 0.75:
			return {"cells": cells, "op": "+", "target": a + b}
		return {"cells": cells, "op": "×", "target": a * b}
	var prod := 1
	var total := 0
	for v in nums:
		prod *= v
		total += v
	if rng.randf() < 0.5 and prod <= 500:
		return {"cells": cells, "op": "×", "target": prod}
	return {"cells": cells, "op": "+", "target": total}

## Does the cage accept these numbers? `complete` = every cell is filled.
static func cage_ok(cage: Dictionary, nums: Array, complete: bool) -> bool:
	var target: int = cage.target
	match cage.op:
		"":
			return not complete or nums[0] == target
		"+":
			var s := 0
			for v in nums:
				s += v
			return s == target if complete else s < target
		"×":
			var p := 1
			for v in nums:
				p *= v
			return p == target if complete else target % p == 0
		"−":
			return not complete or abs(nums[0] - nums[1]) == target
		"÷":
			if not complete:
				return true
			var a: int = max(nums[0], nums[1])
			var b: int = min(nums[0], nums[1])
			return a % b == 0 and a / b == target
	return false

## Counts solutions up to `limit`, giving up (returning limit) after `budget`
## search steps so a hard layout can't stall the game.
func count_solutions(limit: int, budget: int) -> int:
	_budget = budget
	var grid: Array = []
	grid.resize(n * n)
	grid.fill(0)
	var found := _search(grid, 0, limit)
	return limit if _budget <= 0 else found

func _search(grid: Array, idx: int, limit: int) -> int:
	if idx == n * n:
		return 1
	_budget -= 1
	if _budget <= 0:
		return limit
	var r := idx / n
	var c := idx % n
	var found := 0
	for v in range(1, n + 1):
		var clash := false
		for k in n:
			if grid[r * n + k] == v or grid[k * n + c] == v:
				clash = true
				break
		if clash:
			continue
		grid[idx] = v
		var cage: Dictionary = cages[cage_of[idx]]
		var nums: Array = []
		var complete := true
		for cell in cage.cells:
			if grid[cell] == 0:
				complete = false
			else:
				nums.append(grid[cell])
		if cage_ok(cage, nums, complete):
			found += _search(grid, idx + 1, limit - found)
			if found >= limit:
				grid[idx] = 0
				return found
		grid[idx] = 0
	return found

## Indices of filled cells that repeat a number in their row or column.
func conflicts() -> Array:
	var out: Array = []
	for i in n * n:
		var v: int = values[i]
		if v == 0:
			continue
		var r := i / n
		var c := i % n
		for k in n:
			if (k != c and values[r * n + k] == v) or (k != r and values[k * n + c] == v):
				out.append(i)
				break
	return out

func cage_satisfied(ci: int) -> bool:
	var nums: Array = []
	for cell in cages[ci].cells:
		if values[cell] == 0:
			return false
		nums.append(values[cell])
	return cage_ok(cages[ci], nums, true)

func is_solved() -> bool:
	if values.has(0) or not conflicts().is_empty():
		return false
	for ci in cages.size():
		if not cage_satisfied(ci):
			return false
	return true
