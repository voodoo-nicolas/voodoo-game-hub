extends SceneTree

## Headless checks for Block Escape: engine rules + every one of the 300 levels is
## solvable (greedy: any block that can get out, does; removing blocks never hurts).
## godot --headless --path . --script res://tools/test_block_escape.gd

const E = preload("res://scripts/games/block_escape/block_escape_engine.gd")
const Gen = preload("res://scripts/games/block_escape/block_escape_gen.gd")

var fails := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

## Greedy solve: walk a free block to its gate along the flood, remove it, repeat.
func _solve(e) -> bool:
	var guard := 0
	while not e.solved() and guard < 500:
		guard += 1
		var h: Array = e.hint()
		if h.is_empty():
			return false
		var bi: int = h[0]
		var steps := 0
		while e.exit_now(bi) < 0 and steps < 200:
			steps += 1
			var fl: Dictionary = e.flood(e.blocks[bi], e.occupancy(), bi)
			var here: int = fl.get(e.blocks[bi].pos, 999)
			var moved := false
			for di in 4:
				var q: Vector2i = e.blocks[bi].pos + E.DIRS[di]
				if fl.has(q) and int(fl[q]) < here and e.step(bi, di):
					moved = true
					break
			if not moved:
				return false
		e.remove(bi)
	return e.solved()

func _init() -> void:
	# Rules on a hand-made 3x3: red bar at the top row, red gate on top cols 0-1.
	var e = E.new()
	e.load_puzzle({"rows": 3, "cols": 3, "gates": [{"side": 0, "start": 0, "len": 2, "color": 0}],
		"blocks": [{"color": 0, "cells": [[0, 0], [1, 0]], "pos": [1, 2]},
			{"color": 1, "cells": [[0, 0]], "pos": [2, 1], "lock": 1}]})
	_check(e.exit_now(0) < 0, "bar not at gate yet")
	_check(not e.step(0, 1), "bar blocked by the right wall")
	_check(not e.can_move(1), "chained dot can't move")
	_check(e.step(0, 3), "bar slides left")
	_check(e.step(0, 0) and e.step(0, 0), "bar slides up twice")
	_check(e.exit_now(0) == 0, "bar at its gate")
	e.remove(0)
	_check(e.can_move(1), "chain off after one exit")
	var axis = E.new()
	axis.load_puzzle({"rows": 2, "cols": 2, "gates": [], "blocks": [{"color": 0, "cells": [[0, 0]], "pos": [0, 0], "axis": 1}]})
	_check(not axis.step(0, 2) and axis.step(0, 1), "H block only slides sideways")
	var round_trip = E.new()
	round_trip.load_puzzle(JSON.parse_string(JSON.stringify(e.to_dict())))
	_check(round_trip.left() == 1 and round_trip.escaped == 1, "save round trip")

	var t0 := Time.get_ticks_msec()
	var worst := 0
	var last_blocks := 0
	for lvl in range(1, Gen.LEVELS + 1):
		var s := Time.get_ticks_msec()
		var p := Gen.generate(lvl, Gen.seed_for(lvl))
		worst = maxi(worst, Time.get_ticks_msec() - s)
		var g = E.new()
		g.load_puzzle(p)
		_check(g.blocks.size() >= 2, "level %d has blocks" % lvl)
		_check(g.hint().size() > 0, "level %d has a first move" % lvl)
		var colours := {}
		for gt in g.gates:
			colours[gt.color] = true
		for b in g.blocks:
			_check(colours.has(b.color), "level %d block colour has a gate" % lvl)
		_check(_solve(g), "level %d solvable" % lvl)
		if lvl % 50 == 0 or lvl <= 3:
			print("level %3d  %dx%d  blocks %2d  gates %2d  time %3ds" % [lvl, p.cols, p.rows, p.blocks.size(), p.gates.size(), p.time])
		last_blocks = p.blocks.size()
	var again := Gen.generate(123, 123 * 7919 + 17)
	_check(JSON.stringify(again) == JSON.stringify(Gen.generate(123, 123 * 7919 + 17)), "deterministic")
	print("300 levels in %d ms (worst %d ms)" % [Time.get_ticks_msec() - t0, worst])
	print("FAILS: %d" % fails if fails else "ALL OK")
	quit(1 if fails else 0)
