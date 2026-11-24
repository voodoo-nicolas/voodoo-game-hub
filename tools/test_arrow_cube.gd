extends SceneTree

## Headless test for scripts/games/arrow_cube/arrow_cube_engine.gd
##   godot --headless --path . --script res://tools/test_arrow_cube.gd
## Pass `-- full` to check all 500 levels (slow) instead of a sample.

const E = preload("res://scripts/games/arrow_cube/arrow_cube_engine.gd")

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _initialize() -> void:
	_keys()
	_walk()
	_rules()
	_levels("full" in OS.get_cmdline_user_args())
	print("arrow_cube: %s" % ("OK" if fails == 0 else "%d FAILS" % fails))
	quit(1 if fails > 0 else 0)

func _keys() -> void:
	for p in [Vector3i(0, 0, 0), Vector3i(-1, 5, 23), Vector3i(31, -2, 0)]:
		for nd in 6:
			var k := E.key(p, nd)
			ok(E.key_pos(k) == p and E.key_normal(k) == nd, "key round trip %s %d" % [p, nd])

## Walking: 4 steps round a 1-block cube with wraps everywhere returns to the start; every
## step is reversible; surface counts are right.
func _walk() -> void:
	var e := E.new()
	e.set_shape([[0, 0, 0]], 3)
	ok(e.cells.size() == 54, "cube n=3 has 54 cells, got %d" % e.cells.size())
	for x in e.convex_edges():
		e.wraps[x] = true
	ok(e.convex_edges().size() == 12, "cube has 12 edges")
	var start := E.key(Vector3i(1, 2, 1), 2)  # top centre
	var cur := start
	var dir := 0
	for i in 12:
		var s := e.step(cur, dir)
		cur = int(s[0])
		dir = int(s[1])
	ok(cur == start and dir == 0, "12 steps round a 3-cube come back")
	for k in e.cells:
		for d in 6:
			if E.axis(d) == E.axis(E.key_normal(k)):
				continue
			var s := e.step(k, d)
			ok(e.cells.has(int(s[0])), "step lands on a surface cell")
			var back := e.step(int(s[0]), E.opp(int(s[1])))
			ok(int(back[0]) == k and int(back[1]) == E.opp(d), "step reverses")
	# concave: an L shape
	var l := E.new()
	l.set_shape(E.SHAPES.ell, 3)
	ok(l.cells.size() == 14 * 9, "ell surface 14 faces, got %d" % (l.cells.size() / 9))
	for k in l.cells:
		for d in 6:
			if E.axis(d) == E.axis(E.key_normal(k)):
				continue
			var s := l.step(k, d)
			ok(l.cells.has(int(s[0])), "ell step lands on surface")

func _rules() -> void:
	var e := E.new()
	e.set_shape([[0, 0, 0]], 3)
	# two arrows on the top face (normal +y = 2), both pointing +x (dir 0)
	var a := e.add_arrow(E.KIND_ONE, [E.key(Vector3i(0, 2, 1), 2), E.key(Vector3i(1, 2, 1), 2)], [{"at": E.key(Vector3i(1, 2, 1), 2), "dir": 0}])
	var b := e.add_arrow(E.KIND_ONE, [E.key(Vector3i(2, 2, 1), 2)], [{"at": E.key(Vector3i(2, 2, 1), 2), "dir": 0}])
	ok(e.preview(int(a.id)).result == "blocked", "a is blocked by b")
	ok(e.preview(int(b.id)).result == "exit", "b exits over the cliff")
	ok(e.free_arrows() == [int(b.id)], "only b is free")
	var r := e.tap(int(a.id))
	ok(not r.moved and e.hearts == 2, "bump costs a heart")
	e.tap(int(b.id))
	ok(e.tap(int(a.id)).moved and e.won(), "then a leaves and the level is clear")
	ok(e.undo() and e.arrows.size() == 1, "undo brings a back")
	# stop: c points +x from (0,2,0); stop at (2,2,0)
	var f := E.new()
	f.set_shape([[0, 0, 0]], 3)
	var c := f.add_arrow(E.KIND_ONE, [E.key(Vector3i(0, 2, 0), 2)], [{"at": E.key(Vector3i(0, 2, 0), 2), "dir": 0}])
	f.stops[E.key(Vector3i(2, 2, 0), 2)] = true
	var t := f.tap(int(c.id))
	ok(t.result == "stop" and f.arrows.size() == 1 and f.stops.is_empty(), "stop parks the arrow")
	ok(int(f.arrows[0].cells[0]) == E.key(Vector3i(2, 2, 0), 2), "parked on the stop cell")
	ok(f.tap(int(c.id)).result == "exit" and f.won(), "then it leaves")
	# wrap: with the +x top edge wrapping, the ray goes down the side and on round
	var w := E.new()
	w.set_shape([[0, 0, 0]], 3)
	var g := w.add_arrow(E.KIND_ONE, [E.key(Vector3i(0, 2, 1), 2)], [{"at": E.key(Vector3i(0, 2, 1), 2), "dir": 0}])
	w.wraps[E.edge_key(Vector3i.ZERO, 2, 0)] = true
	var pv := w.preview(int(g.id))
	ok(pv.result == "exit" and pv.paths[0].size() == 5, "wrap: 2 on top + 3 down the side, got %d" % pv.paths[0].size())
	# save round trip
	var s := E.new()
	s.load_level(130)
	var d := s.to_save()
	var s2 := E.new()
	ok(s2.from_save(JSON.parse_string(JSON.stringify(d))), "save loads")
	ok(s2.arrows.size() == s.arrows.size() and s2.cells.size() == s.cells.size(), "save keeps arrows")

func _levels(full: bool) -> void:
	var picks: Array = range(1, E.LEVEL_COUNT + 1) if full else [1, 2, 10, 25, 45, 80, 81, 120, 160, 200, 300, 400, 500, 501, 507]
	var t0 := Time.get_ticks_msec()
	var worst := 0
	for lv in picks:
		var t1 := Time.get_ticks_msec()
		var e := E.new()
		e.load_level(lv)
		var gen_ms := Time.get_ticks_msec() - t1
		worst = maxi(worst, gen_ms)
		var arrows := e.arrows.size()
		ok(arrows >= 3, "level %d has %d arrows" % [lv, arrows])
		ok(not e.free_arrows().is_empty() or e.any_move(), "level %d has a first move" % lv)
		# determinism
		var e2 := E.new()
		e2.load_level(lv)
		ok(JSON.stringify(e2.level_dict()) == JSON.stringify(e.level_dict()), "level %d is the same twice" % lv)
		# solvable by the solver
		var sol := e.solve_first(20000)
		ok(not sol.is_empty(), "level %d solvable" % lv)
		# no arrow cell overlap, heads on own cells
		var seen := {}
		for a in e.arrows:
			for c in a.cells:
				ok(not seen.has(c), "level %d overlap" % lv)
				seen[c] = true
			for h in a.heads:
				ok(a.cells.has(h.at), "level %d head on arrow" % lv)
		if not full or lv % 50 == 0:
			var kinds := {}
			for a in e.arrows:
				kinds[a.kind] = int(kinds.get(a.kind, 0)) + 1
			print("  L%d n=%d blocks=%d cells=%d arrows=%d %s stops=%d wraps=%d free=%d  %dms" % [lv, e.n, e.voxels.size(),
				e.cells.size(), arrows, kinds, e.stops.size(), e.wraps.size(), e.free_arrows().size(), gen_ms])
	print("  levels: %d in %d ms, slowest %d ms" % [picks.size(), Time.get_ticks_msec() - t0, worst])
