extends SceneTree

## Headless check of the Color Sort engine: campaign levels are seeded and always
## solvable (checked with the real solver), pours obey the rules, undo works.
## godot --headless --path . --script res://tools/test_color_sort.gd

const E = preload("res://scripts/games/color_sort/color_sort_engine.gd")
const S = preload("res://scripts/games/color_sort/color_sort_solver.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	# Spec ramp: colours never shrink, 14 only very late, vials <= 18, cap 3..6.
	var prev_colors := 0
	for n in range(1, 400):
		var sp: Dictionary = E.spec_for(n)
		if sp.colors < prev_colors and E.tier_of(n) == E.tier_of(n - 1) and n > 1:
			fails += 1
			print("FAIL: colours shrink inside a tier at ", n)
		prev_colors = sp.colors
		if sp.colors + sp.empty > E.MAX_VIALS or sp.cap < 3 or sp.cap > 6 or sp.colors > E.MAX_COLORS:
			fails += 1
			print("FAIL: spec out of range at ", n)
	if E.spec_for(100).colors > 10 or E.spec_for(1000).colors != 14:
		fails += 1
		print("FAIL: colour ramp")
	# Generated levels: shape, counts, determinism, solvable.
	for n in [1, 2, 6, 8, 12, 15, 21, 40, 42, 51, 75, 91, 120, 125, 132, 141, 200, 300]:
		e.load_level(n)
		var sp: Dictionary = E.spec_for(n)
		var k: int = sp.center
		if e.tubes.size() != sp.vials or sp.vials > E.MAX_VIALS or e.cap != sp.cap or e.center_order.size() != k or not e.center.is_empty():
			fails += 1
			print("FAIL: shape at ", n)
		var counts := {}
		for t in e.tubes:
			if t.size() > e.cap:
				fails += 1
				print("FAIL: overfull vial at ", n)
			for c in t:
				counts[c] = int(counts.get(c, 0)) + 1
		if counts.size() != sp.colors:
			fails += 1
			print("FAIL: colours at ", n)
		for c in counts:
			if counts[c] != (e.center_seg if c in e.center_order else e.cap):
				fails += 1
				print("FAIL: layer count at ", n)
		if e.solved():
			fails += 1
			print("FAIL: starts solved at ", n)
		if k > 0 and (e.center_seg != e.cap * 3 / 2 or e.center_need() != e.center_order[0]):
			fails += 1
			print("FAIL: central vial setup at ", n)
		for ci in e.center_order:
			if not counts.has(ci):
				fails += 1
				print("FAIL: centre colour missing from the small vials at ", n)
		var again = E.new()
		again.load_level(n)
		if again.tubes != e.tubes:
			fails += 1
			print("FAIL: not reproducible at ", n)
		var r: Dictionary = S.solve(e.tubes, e.cap, 60000, 3.0, e._center_info())
		if not r.ok:
			fails += 1
			print("FAIL: solver found no solution at level ", n, " (", r.nodes, " nodes)")
		else:
			# Replay the solution on a fresh engine: it must really solve the level.
			var play = E.new()
			play.load_level(n)
			for m in r.moves:
				if not play.do_move(m[0], m[1]):
					fails += 1
					print("FAIL: solver move illegal at ", n)
					break
			if not play.solved():
				fails += 1
				print("FAIL: solver path does not solve ", n)
			if r.moves.size() > e.gen_moves:
				pass  # allowed: weighted search may be longer than the scramble
		if e.par <= 0:
			fails += 1
			print("FAIL: no par at ", n)
	# Exact optimum on a tiny board.
	var tiny = E.new()
	tiny.cap = 2
	tiny.tubes = [[0, 1], [1, 0], []]
	var ro: Dictionary = S.solve(tiny.tubes, 2, 5000, 1.0)
	if not ro.ok or not ro.optimal or ro.moves.size() != 3:
		fails += 1
		print("FAIL: optimal solve, got ", ro)
	# Central vial rules.
	e.cap = 4
	e.tubes = [[1, 0, 0], [1, 0], [], [2, 2]]
	e.center_order = [0, 1]
	e.center_seg = 3
	e.center = []
	if e.center_need() != 0 or e.pour_amount(0, E.CENTER) != 2 or e.pour_amount(1, E.CENTER) != 1 or e.pour_amount(3, E.CENTER) != 0 or e.pour_amount(2, E.CENTER) != 0:
		fails += 1
		print("FAIL: centre pour amounts")
	e.moves = 0
	e.history = []
	e.do_move(0, E.CENTER)
	if e.center != [0, 0] or e.tubes[0] != [1] or e.center_need() != 0:
		fails += 1
		print("FAIL: centre pour 1 ", e.center)
	e.do_move(1, E.CENTER)
	if e.center != [0, 0, 0] or e.center_need() != 1 or e.pour_amount(1, E.CENTER) != 1 or e.pour_amount(3, E.CENTER) != 0:
		fails += 1
		print("FAIL: centre second block ", e.center)
	if not e.undo() or e.center != [0, 0] or e.tubes[1] != [1, 0] or e.moves != 1:
		fails += 1
		print("FAIL: centre undo")
	e.center = [0, 0, 0, 1, 1, 1]
	e.tubes = [[2, 2, 2, 2], [], [3, 3, 3, 3]]
	if not e.solved() or not e.center_full():
		fails += 1
		print("FAIL: centre solved")
	e.center = [0, 0, 0, 1, 1]
	if e.solved():
		fails += 1
		print("FAIL: solved with centre not full")
	e.center_order = []
	e.center_seg = 0
	e.center = []
	# Rules: run pours, partial pours, undo.
	e.cap = 4
	e.tubes = [[0, 1, 1], [1], [], [0, 0, 0, 0]]
	if e.pour_amount(0, 1) != 2 or e.can_move(0, 3) or e.pour_amount(0, 2) != 2 or e.can_move(0, 0) or e.can_move(2, 0):
		fails += 1
		print("FAIL: can_move / pour_amount")
	e.tubes = [[0, 1, 1], [1, 1, 1], [], []]
	if e.pour_amount(0, 1) != 1:
		fails += 1
		print("FAIL: partial pour")
	e.tubes = [[0, 1, 1], [1], [], [0, 0, 0, 0]]
	e.moves = 0
	e.history = []
	if not e.do_move(0, 1) or e.tubes[1] != [1, 1, 1] or e.tubes[0] != [0] or e.moves != 1:
		fails += 1
		print("FAIL: do_move")
	if not e.undo() or e.tubes[0] != [0, 1, 1] or e.tubes[1] != [1] or e.moves != 0:
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
	e.cap = 3
	e.tubes = [[0, 0, 0], [1, 1, 1], []]
	if not e.solved():
		fails += 1
		print("FAIL: solved at cap 3")
	# Stars.
	e.par = 20
	if e.stars_for(20) != 3 or e.stars_for(23) != 3 or e.stars_for(24) != 2 or e.stars_for(32) != 2 or e.stars_for(33) != 1:
		fails += 1
		print("FAIL: stars")
	# Old difficulty buttons still work.
	for lvl in 4:
		e.new_game(lvl)
		if e.tubes.size() != E.LEVELS[lvl].colors + E.LEVELS[lvl].empty or e.solved():
			fails += 1
			print("FAIL: classic level ", lvl)
	# Save round trip, incl. an old-format history entry.
	e.load_level(30)
	for a in e.tubes.size():
		for b in e.tubes.size():
			if e.moves == 0 and e.can_move(a, b):
				e.do_move(a, b)
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.tubes != e.tubes or e2.moves != e.moves or e2.cap != e.cap or e2.level_no != 30:
		fails += 1
		print("FAIL: save round trip")
	var old := {"level": 1, "tubes": [[0, 0], [1], [1, 1, 1], []], "moves": 1, "history": [[2, 1]], "extra": 0}
	if not E.new().from_dict(old):
		fails += 1
		print("FAIL: old save")
	print("color_sort: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
