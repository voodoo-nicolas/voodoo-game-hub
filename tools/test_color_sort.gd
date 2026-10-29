extends SceneTree

## Headless check of the Color Sort engine: campaign levels are seeded and always
## solvable (checked with the real solver), pours obey the rules, undo works.
## godot --headless --path . --script res://tools/test_color_sort.gd

const E = preload("res://scripts/games/color_sort/color_sort_engine.gd")
const S = preload("res://scripts/games/color_sort/color_sort_solver.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	# Spec ramp: colours never shrink, the top count only very late, vials <= MAX_VIALS, cap 3..6.
	var prev_colors := 0
	for n in range(1, 400):
		var sp: Dictionary = E.spec_for(n)
		if sp.colors < prev_colors and E.tier_of(n) == E.tier_of(n - 1) and n > 1 and n % 50 != 0 and (n - 1) % 50 != 0:
			fails += 1
			print("FAIL: colours shrink inside a tier at ", n)
		prev_colors = sp.colors
		if sp.colors + sp.empty > E.MAX_VIALS or sp.cap < 3 or sp.cap > 6 or sp.colors > E.MAX_COLORS:
			fails += 1
			print("FAIL: spec out of range at ", n)
	if E.spec_for(99).colors > 10 or E.spec_for(1000).colors != E.MAX_COLORS:
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
		var r: Dictionary = S.solve(e.tubes, e.cap, 60000, 3.0, e._center_info(), e._solver_rules())
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
	# Special levels: the solver (which knows the rules) finds a way, and the engine
	# accepts every one of its pours, the drain and the locks included.
	var specials: Array = []
	for n in range(10, 301, 10):
		specials.append(n)
	specials.append_array([27, 54, 81, 108])
	for n in specials:
		var sp2: Dictionary = E.spec_for(n)
		var lv = E.new()
		lv.load_level(n)
		if sp2.special != "" and lv.rules.is_empty() and lv.attempt_used != -1:
			fails += 1
			print("FAIL: special level without rules at ", n)
		var r2: Dictionary = S.solve(lv.tubes, lv.cap, 80000, 3.0, lv._center_info(), lv._solver_rules())
		if not r2.ok:
			fails += 1
			print("FAIL: special level unsolved ", n, " ", lv.rules)
			continue
		var pl = E.new()
		pl.load_level(n)
		for m in r2.moves:
			if not pl.do_move(m[0], m[1]):
				fails += 1
				print("FAIL: engine refused solver move at special level ", n)
				break
		if not pl.solved():
			fails += 1
			print("FAIL: special level not solved by replay ", n)
		if int(lv.rules.get("cap_moves", 0)) > 0 and lv.rules.cap_moves < lv.par:
			fails += 1
			print("FAIL: move cap below par at ", n)
	# Rule semantics by hand.
	var rl = E.new()
	rl.cap = 3
	rl.tubes = [[0, 0], [0], [1, 1, 1], []]
	rl.rules = {"locks": [{"v": 1, "pours": 2}, {"v": 3, "after": 2, "cork": true}], "blocked": [[0, 3]]}
	if not rl.is_locked(1) or rl.can_move(0, 1) or rl.can_move(1, 0) or rl.lock_pours_left(1) != 2:
		fails += 1
		print("FAIL: pours lock")
	if not rl.is_locked(3) and rl.tubes[2].size() == 3:
		pass
	rl.tubes = [[0, 0], [0], [1, 1], []]
	if not rl.is_locked(3) or rl.can_move(2, 3):
		fails += 1
		print("FAIL: cork lock")
	rl.tubes = [[0, 0], [0], [1, 1, 1], []]
	if rl.is_locked(3) or not rl.can_move(2, 3) or rl.can_move(0, 3):
		fails += 1
		print("FAIL: cork pops / blocked pair")
	rl.moves = 2
	if rl.is_locked(1) or not rl.can_move(0, 1):
		fails += 1
		print("FAIL: pours lock opens")
	# Drain: every 2nd pour the full-less central vial leaks a layer back.
	var dr = E.new()
	dr.cap = 3
	dr.tubes = [[2], [0, 0], [1, 1, 1], []]
	dr.center_order = [0]
	dr.center_seg = 4
	dr.center = [0, 0]
	dr.rules = {"drain": 2}
	dr.do_move(2, 3)
	if dr.center.size() != 2 or dr.moves != 1:
		fails += 1
		print("FAIL: drain before its turn")
	dr.do_move(1, E.CENTER)
	# 2nd pour: centre got 2 more (4 = full) so no leak
	if dr.center.size() != 4:
		fails += 1
		print("FAIL: drain when full ", dr.center)
	dr.undo()
	dr.center = [0, 0, 0]
	dr.tubes = [[2], [0], [1, 1, 1], []]
	dr.moves = 1
	dr.history = []
	dr.do_move(3, 3) if false else null
	dr.tubes = [[2], [0], [], [1, 1, 1]]
	dr.do_move(0, 2)   # 2nd pour -> leak: centre 3 -> 2, a 0 goes to the first vial with room
	if dr.center.size() != 2 or dr.tubes[0] != [0]:
		fails += 1
		print("FAIL: drain leak ", dr.center, dr.tubes)
	dr.undo()
	if dr.center.size() != 3 or dr.tubes[0] != [2] or dr.moves != 1:
		fails += 1
		print("FAIL: drain undo ", dr.center, dr.tubes)
	# Mystery: layers under the top run stay hidden until exposed.
	var my = E.new()
	my.cap = 3
	my.tubes = [[0, 1, 1], [2, 2], [], [2, 0]]
	my.rules = {"mystery": true}
	my._finish_deal()
	if my.hidden != [1, 0, 0, 1] or not my.is_hidden(0, 0) or my.is_hidden(0, 1) or my.is_hidden(3, 1):
		fails += 1
		print("FAIL: mystery hidden ", my.hidden)
	my.do_move(0, 2)
	if my.hidden[0] != 0:
		fails += 1
		print("FAIL: mystery reveal ", my.hidden)
	my.reset()
	if my.hidden != [1, 0, 0, 1]:
		fails += 1
		print("FAIL: mystery reset")
	# Move cap.
	var mc = E.new()
	mc.cap = 3
	mc.tubes = [[0, 1], [1, 0], []]
	mc.rules = {"cap_moves": 1}
	mc.do_move(0, 2)
	if not mc.failed() or mc.moves_left() != 0:
		fails += 1
		print("FAIL: move cap")
	# Rules survive a save.
	var sv = E.new()
	sv.load_level(50)
	var sv2 = E.new()
	if not sv2.from_dict(JSON.parse_string(JSON.stringify(sv.to_dict()))) or sv2.rules != sv.rules or sv2.hidden != sv.hidden:
		fails += 1
		print("FAIL: rules save round trip")
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
