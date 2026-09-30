extends RefCounted

## Kakuro: fill white cells with 1-9 so each horizontal/vertical run adds up
## to the clue on its left/above, with no digit repeated inside a run.
## Layouts are random (180° symmetric, every run 2+ cells long). A small,
## bounded solver prefers a layout with a single answer when it finds one
## quickly; the win check only checks the rules, so any answer that fits counts.
## Pure logic, no Nodes.

var size: int = 8               # including the clue row/column
var white: Array = []           # size*size bools
var runs: Array = []            # [{cells: Array[int], sum: int, across: bool, clue_cell: int}]
var cell_runs: Array = []       # size*size -> [across_run or -1, down_run or -1]
var solution: Array = []
var values: Array = []          # player's entries, 0 = blank

var _budget: int = 0

func new_puzzle(total_size: int, rng_seed: int = -1) -> void:
	size = total_size
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	for attempt in 8:
		_make_pattern(rng)
		if not _fill(rng):
			continue
		if count_solutions(2, 3000) == 1:
			break
	values.clear()
	values.resize(size * size)
	values.fill(0)

# ---------- layout ----------

func _make_pattern(rng: RandomNumberGenerator) -> void:
	for attempt in 400:
		white.clear()
		white.resize(size * size)
		white.fill(false)
		for r in range(1, size):
			for c in range(1, size):
				white[r * size + c] = true
		var inner := (size - 1) * (size - 1)
		var blacks := int(inner * rng.randf_range(0.18, 0.28))
		var placed := 0
		while placed < blacks:
			var r := rng.randi_range(1, size - 1)
			var c := rng.randi_range(1, size - 1)
			if not white[r * size + c]:
				continue
			white[r * size + c] = false
			white[(size - r) * size + (size - c)] = false  # symmetric partner
			placed += 2
		if _pattern_ok():
			_index_runs()
			return
	# Fallback that always works: a plain block with a black diagonal band.
	white.fill(false)
	for r in range(1, size):
		for c in range(1, size):
			white[r * size + c] = abs(r - c) != 3
	_index_runs()

func _run_len(i: int, step: int, limit_check: bool) -> int:
	var n := 1
	var k := i - step
	while k >= 0 and white[k] and (step == size or k / size == i / size):
		n += 1
		k -= step
	k = i + step
	while k < size * size and white[k] and (step == size or k / size == i / size):
		n += 1
		k += step
	return n

func _pattern_ok() -> bool:
	var count := 0
	var first := -1
	for i in size * size:
		if not white[i]:
			continue
		count += 1
		if first < 0:
			first = i
		var h := _run_len(i, 1, true)
		var v := _run_len(i, size, true)
		if h < 2 or v < 2 or h > 9 or v > 9:
			return false
	if count < (size - 1) * (size - 1) / 2:
		return false
	# every white cell connected
	var seen := {first: true}
	var stack: Array = [first]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for nb in [i - 1, i + 1, i - size, i + size]:
			if nb < 0 or nb >= size * size or seen.has(nb) or not white[nb]:
				continue
			if (nb == i - 1 or nb == i + 1) and nb / size != i / size:
				continue
			seen[nb] = true
			stack.append(nb)
	return seen.size() == count

func _index_runs() -> void:
	runs.clear()
	cell_runs.clear()
	for i in size * size:
		cell_runs.append([-1, -1])
	for across in [true, false]:
		var step := 1 if across else size
		for i in size * size:
			if not white[i]:
				continue
			var prev := i - step
			var starts: bool = prev < 0 or not white[prev] or (across and prev / size != i / size)
			if not starts:
				continue
			var cells: Array = []
			var k := i
			while k < size * size and white[k] and (not across or k / size == i / size):
				cells.append(k)
				k += step
			for cell in cells:
				cell_runs[cell][0 if across else 1] = runs.size()
			runs.append({"cells": cells, "sum": 0, "across": across, "clue_cell": prev})

func _fill(rng: RandomNumberGenerator) -> bool:
	solution.clear()
	solution.resize(size * size)
	solution.fill(0)
	var cells: Array = []
	for i in size * size:
		if white[i]:
			cells.append(i)
	_budget = 20000
	if not _fill_from(cells, 0, rng):
		return false
	for run in runs:
		var s := 0
		for cell in run.cells:
			s += solution[cell]
		run.sum = s
	return true

func _fill_from(cells: Array, idx: int, rng: RandomNumberGenerator) -> bool:
	if idx == cells.size():
		return true
	_budget -= 1
	if _budget <= 0:
		return false
	var cell: int = cells[idx]
	var digits: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	for i in range(8, 0, -1):
		var j := rng.randi_range(0, i)
		var t = digits[i]
		digits[i] = digits[j]
		digits[j] = t
	for d in digits:
		if _used_in_runs(solution, cell, d):
			continue
		solution[cell] = d
		if _fill_from(cells, idx + 1, rng):
			return true
		solution[cell] = 0
	return false

func _used_in_runs(grid: Array, cell: int, d: int) -> bool:
	for ri in cell_runs[cell]:
		if ri < 0:
			continue
		for other in runs[ri].cells:
			if other != cell and grid[other] == d:
				return true
	return false

# ---------- uniqueness ----------

func count_solutions(limit: int, budget: int) -> int:
	_budget = budget
	var grid: Array = []
	grid.resize(size * size)
	grid.fill(0)
	var cells: Array = []
	for i in size * size:
		if white[i]:
			cells.append(i)
	var found := _search(grid, cells, 0, limit)
	return limit if _budget <= 0 else found

func _search(grid: Array, cells: Array, idx: int, limit: int) -> int:
	if idx == cells.size():
		return 1
	_budget -= 1
	if _budget <= 0:
		return limit
	var cell: int = cells[idx]
	var found := 0
	for d in range(1, 10):
		if _used_in_runs(grid, cell, d):
			continue
		grid[cell] = d
		if _runs_feasible(grid, cell):
			found += _search(grid, cells, idx + 1, limit - found)
			if found >= limit:
				grid[cell] = 0
				return found
		grid[cell] = 0
	return found

func _runs_feasible(grid: Array, cell: int) -> bool:
	for ri in cell_runs[cell]:
		if ri < 0:
			continue
		var run: Dictionary = runs[ri]
		var s := 0
		var empty := 0
		for other in run.cells:
			if grid[other] == 0:
				empty += 1
			else:
				s += grid[other]
		var lo := empty * (empty + 1) / 2
		var hi := empty * (19 - empty) / 2
		if s + lo > run.sum or s + hi < run.sum:
			return false
	return true

# ---------- player state ----------

func run_complete_ok(ri: int) -> bool:
	var s := 0
	var seen := {}
	for cell in runs[ri].cells:
		var v: int = values[cell]
		if v == 0 or seen.has(v):
			return false
		seen[v] = true
		s += v
	return s == runs[ri].sum

## Filled cells whose digit repeats inside one of their runs.
func conflicts() -> Array:
	var out: Array = []
	for i in size * size:
		if white[i] and values[i] != 0 and _used_in_runs(values, i, values[i]):
			out.append(i)
	return out

func is_solved() -> bool:
	for ri in runs.size():
		if not run_complete_ok(ri):
			return false
	return true
