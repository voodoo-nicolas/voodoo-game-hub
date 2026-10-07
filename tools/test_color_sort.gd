extends SceneTree

## Headless check of the Color Sort engine: puzzles are always solvable (checked
## with a real solver), moves obey the rules, undo works.
## godot --headless --path . --script res://tools/test_color_sort.gd

const E = preload("res://scripts/games/color_sort/color_sort_engine.gd")

## Depth-first search over single-ball moves with a visited set. Returns true if solvable.
func _solve(e, limit: int) -> bool:
	var seen := {}
	var stack: Array = [[]]
	var count := 0
	var start_tubes: Array = e.tubes.duplicate(true)
	var path_states: Array = []
	var queue: Array = [start_tubes]
	var head := 0
	seen[_key(start_tubes)] = true
	while head < queue.size() and count < limit:
		var state: Array = queue[head]
		head += 1
		count += 1
		var probe = E.new()
		probe.tubes = state
		if probe.solved():
			return true
		for a in state.size():
			for b in state.size():
				if probe.can_move(a, b):
					var next: Array = state.duplicate(true)
					next[b].append(next[a].pop_back())
					var k := _key(next)
					if not seen.has(k):
						seen[k] = true
						queue.append(next)
	return false

func _key(tubes: Array) -> String:
	var parts: Array = []
	for t in tubes:
		parts.append(",".join(PackedStringArray(t.map(func(x): return str(x)))))
	parts.sort()
	return "|".join(PackedStringArray(parts))

func _init() -> void:
	var fails := 0
	var e = E.new()
	for lvl in 4:
		for g in 6:
			e.new_game(lvl)
			var n: int = E.LEVELS[lvl].colors
			if e.tubes.size() != n + E.LEVELS[lvl].empty:
				fails += 1
				print("FAIL: tube count")
			var counts := {}
			for t in e.tubes:
				if t.size() > E.CAP:
					fails += 1
					print("FAIL: overfull tube")
				for c in t:
					counts[c] = int(counts.get(c, 0)) + 1
			if counts.size() != n:
				fails += 1
				print("FAIL: colours ", counts.size())
			for c in counts:
				if counts[c] != E.CAP:
					fails += 1
					print("FAIL: ball count of colour ", c)
			if e.solved():
				fails += 1
				print("FAIL: starts solved")
	# Solvability by a real search on the smaller levels.
	for lvl in 2:
		for g in 5:
			e.new_game(lvl)
			if not _solve(e, 200000):
				fails += 1
				print("FAIL: unsolved puzzle at level ", lvl)
	# Rules.
	e.tubes = [[0, 1], [1], [], [0, 0, 0, 0]]
	if not e.can_move(0, 1) or e.can_move(0, 3) or not e.can_move(0, 2) or e.can_move(0, 0) or e.can_move(2, 0):
		fails += 1
		print("FAIL: can_move")
	e.moves = 0
	e.history = []
	if not e.do_move(0, 1) or e.tubes[1] != [1, 1] or e.tubes[0] != [0] or e.moves != 1:
		fails += 1
		print("FAIL: do_move")
	if not e.undo() or e.tubes[0] != [0, 1] or e.tubes[1] != [1] or e.moves != 0:
		fails += 1
		print("FAIL: undo")
	e.tubes = [[0, 0, 0, 0], [1, 1, 1, 1], []]
	if not e.solved():
		fails += 1
		print("FAIL: solved")
	e.tubes = [[0, 0, 0], [1, 1, 1, 1], [0]]
	if e.solved():
		fails += 1
		print("FAIL: not solved")
	e.new_game(1)
	e.do_move(0, e.tubes.size() - 1) if e.can_move(0, e.tubes.size() - 1) else null
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.tubes != e.tubes or e2.moves != e.moves:
		fails += 1
		print("FAIL: save round trip")
	print("color_sort: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
