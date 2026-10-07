extends SceneTree

## Headless check of the Word Ladder engine: every level makes solvable ladders
## whose par matches a real shortest path, and hints/undo/scoring behave.
## godot --headless --path . --script res://tools/test_word_ladder.gd

const E = preload("res://scripts/games/word_ladder/word_ladder_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	e.load_words()
	for lvl in 3:
		for r in 6:
			e.new_round(lvl)
			var g2 := 0
			while not e.is_over() and g2 < 60:
				g2 += 1
				if e.solved():
					e.finish_ladder()
				else:
					e.hint()
			if e.puzzles.size() != E.ROUND:
				fails += 1; print("FAIL: round size ", e.puzzles.size())
			for p in e.puzzles:
				var pth: Array = e.path(p.start, p.end)
				if pth.size() - 1 != p.par or p.par < 1:
					fails += 1; print("FAIL: par ", p)
				if p.start.length() != E.LEVELS[lvl].len or not e.is_word(p.start) or not e.is_word(p.end):
					fails += 1; print("FAIL: words ", p)
	# Play a whole round by hints only.
	e.new_round(1)
	var guard := 0
	while not e.is_over() and guard < 200:
		guard += 1
		if e.solved():
			e.finish_ladder()
		else:
			if e.hint() == "":
				fails += 1; print("FAIL: hint empty"); break
	if not e.is_over():
		fails += 1; print("FAIL: round not finished")
	# Manual play: optimal path scores 100, one wasted step costs 15.
	e.new_round(0)
	var pth2: Array = e.path(e.current().start, e.current().end)
	for i in range(1, pth2.size()):
		if e.try_step(pth2[i]) != "ok":
			fails += 1; print("FAIL: step ", pth2[i])
	if not e.solved() or not e.is_perfect() or e.points_now() != 100:
		fails += 1; print("FAIL: perfect scoring ", e.points_now())
	# Rule checks.
	e.new_round(0)
	var s: String = e.current().start
	if e.try_step(s) != "same": fails += 1; print("FAIL: same")
	if e.try_step("zzz") != "not_one": fails += 1; print("FAIL: not_one")
	var changed := "x" + s.substr(1)
	if is_word(e, changed) == false and e.try_step(changed) != "not_word" and changed != s:
		fails += 1; print("FAIL: not_word ", changed)
	# Save round trip.
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	e2.load_words()
	if not e2.from_dict(d) or e2.chain != e.chain or e2.puzzles.size() != e.puzzles.size():
		fails += 1; print("FAIL: save round trip")
	print("word_ladder: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

func is_word(e, w: String) -> bool:
	return e.is_word(w)
