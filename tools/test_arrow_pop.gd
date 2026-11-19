extends SceneTree

## Headless check of the Arrow Pop engine: all levels are seeded, solvable, ramp up,
## and the rules hold (an arrow never pops another colour; a bump costs a heart).
## godot --headless --path . --script res://tools/test_arrow_pop.gd

const E = preload("res://scripts/games/arrow_pop/arrow_pop_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	var t0 := Time.get_ticks_msec()
	var slowest := 0
	var sum_depth := [0, 0, 0, 0]
	var sum_fill := [0.0, 0.0, 0.0, 0.0]
	for n in range(1, E.LEVEL_COUNT + 1):
		var t := Time.get_ticks_msec()
		e.load_level(n)
		slowest = maxi(slowest, Time.get_ticks_msec() - t)
		var d: int = e.depth()
		if d < 1:
			fails += 1
			print("FAIL: level %d not solvable (depth %d)" % [n, d])
		var q: int = mini(3, (n - 1) * 4 / E.LEVEL_COUNT)
		sum_depth[q] += d
		sum_fill[q] += 1.0 - float(e.count(E.EMPTY)) / (e.w * e.h)
		# Same level twice = same board.
		var a: Array = e.kind.duplicate()
		var c: Array = e.col.duplicate()
		e.load_level(n)
		if a != e.kind or c != e.col:
			fails += 1
			print("FAIL: level %d not deterministic" % n)
		# Play it out with free arrows only: never a heart lost, ends won.
		var guard := 0
		while not e.won() and guard < 500:
			var free: Array = e.free_arrows()
			if free.is_empty():
				break
			var r: Dictionary = e.fire(free[0])
			for p in r.pops:
				pass
			guard += 1
		if not e.won() or e.hearts != E.MAX_HEARTS or e.stars() != 3:
			fails += 1
			print("FAIL: level %d playthrough" % n)
	for q in 4:
		print("quarter %d: avg depth %.1f, avg fill %.2f" % [q + 1, sum_depth[q] / 80.0, sum_fill[q] / 80.0])
	print("320 levels in %d ms (slowest %d ms)" % [Time.get_ticks_msec() - t0, slowest])

	# Rules on a hand-made board: 3x1 row  [R arrow →][B bubble][R bubble]
	e.w = 3
	e.h = 1
	e.kind = [E.ARROW, E.BUBBLE, E.BUBBLE]
	e.col = [0, 1, 0]
	e.dir = [1, 0, 0]
	e.hearts = 3
	e.mistakes = 0
	var r: Dictionary = e.fire(0)
	if r.ok or r.block != 1 or e.hearts != 2 or e.kind[2] != E.BUBBLE or e.kind[0] != E.ARROW:
		fails += 1
		print("FAIL: an arrow passed a bubble of another colour")
	e.col[1] = 0
	r = e.fire(0)
	if not r.ok or r.pops != [1, 2] or not e.won():
		fails += 1
		print("FAIL: same-colour pops")
	if e.stars() != 2:
		fails += 1
		print("FAIL: stars after one slip")
	# An arrow blocks another arrow, even of the same colour.
	e.kind = [E.ARROW, E.ARROW, E.EMPTY]
	e.col = [0, 0, 0]
	e.dir = [1, 1, 0]
	if e.check(0).ok or not e.check(1).ok:
		fails += 1
		print("FAIL: arrow blocking")
	# Save round trip.
	e.load_level(150)
	var e2 = E.new()
	if not e2.from_dict(e.to_dict()) or e2.kind != e.kind or e2.level_no != 150:
		fails += 1
		print("FAIL: save round trip")
	if e2.from_dict({"w": 3, "h": 3, "kind": [0]}):
		fails += 1
		print("FAIL: bad save accepted")

	print("arrow_pop: %s" % ("OK" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails else 0)
