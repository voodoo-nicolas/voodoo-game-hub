extends SceneTree

## Headless check of the Hidato engine.
## godot --headless --path . --script res://tools/test_hidato.gd

const E = preload("res://scripts/games/hidato/hidato_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	for lvl in 4:
		for g in 12:
			e.new_game(lvl)
			var n: int = e.total()
			# The solution is a permutation of 1..N where consecutive numbers touch.
			var seen := {}
			for v in e.solution:
				seen[v] = true
			if seen.size() != n:
				fails += 1
				print("FAIL: solution not a permutation")
			for k in range(1, n):
				var a: int = e.solution.find(k)
				var b: int = e.solution.find(k + 1)
				if not e.adjacent(a, b):
					fails += 1
					print("FAIL: path break at ", k)
					break
			# Givens match the solution and include 1 and N.
			var givens := 0
			for i in n:
				if e.given[i]:
					givens += 1
					if e.grid[i] != e.solution[i]:
						fails += 1
						print("FAIL: given mismatch")
			if not e.given[e.solution.find(1)] or not e.given[e.solution.find(n)]:
				fails += 1
				print("FAIL: 1 and N must be given")
			if givens < 2 or givens > n / 2 + 1:
				fails += 1
				print("FAIL: givens count ", givens, " of ", n)
			if e.solved():
				fails += 1
				print("FAIL: solved at start")
			# Filling in the solution solves it.
			for i in n:
				if not e.given[i]:
					e.set_cell(i, e.solution[i])
			if not e.solved():
				fails += 1
				print("FAIL: solution doesn't solve")
	# Moving a number, given protection, conflicts.
	e.new_game(0)
	var free: Array = []
	for i in e.total():
		if not e.given[i]:
			free.append(i)
	var one: int = e.cell_of(1)
	if e.set_cell(one, 5):
		fails += 1
		print("FAIL: edited a given")
	var need: int = 2
	while e.grid.has(need):
		need += 1
	e.set_cell(free[0], need)
	e.set_cell(free[1], need)
	if e.grid[free[0]] != 0 or e.grid[free[1]] != need:
		fails += 1
		print("FAIL: number should move")
	e.set_cell(free[1], 0)
	if e.grid[free[1]] != 0:
		fails += 1
		print("FAIL: clear")
	# Two numbers in a row placed far apart conflict.
	e.new_game(1)
	var far_a := -1
	var far_b := -1
	for i in e.total():
		for j in e.total():
			if not e.given[i] and not e.given[j] and i != j and not e.adjacent(i, j):
				far_a = i
				far_b = j
	var k := 2
	while e.grid.has(k) or e.grid.has(k + 1):
		k += 1
		if k >= e.total() - 1:
			break
	if k < e.total() - 1:
		e.set_cell(far_a, k)
		e.set_cell(far_b, k + 1)
		if not e.conflicts().has(far_a) or not e.conflicts().has(far_b):
			fails += 1
			print("FAIL: conflict not found")
	# Hints fill with the solution.
	e.new_game(2)
	var before: int = e.filled_count()
	var h: int = e.hint()
	if h < 0 or e.grid[h] != e.solution[h] or e.filled_count() != before + 1:
		fails += 1
		print("FAIL: hint")
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.grid != e.grid or e2.solution != e.solution or e2.given != e.given:
		fails += 1
		print("FAIL: save round trip")
	print("hidato: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
