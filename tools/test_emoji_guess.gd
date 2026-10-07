extends SceneTree

## Headless check of the Emoji Guess engine.
## godot --headless --path . --script res://tools/test_emoji_guess.gd

const E = preload("res://scripts/games/emoji_guess/emoji_guess_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	e.load_data()
	for lang in [false, true]:
		for t in 3:
			var pool_n: int = e.data["es" if lang else "en"][["easy", "normal", "hard"][t]].size()
			if pool_n < E.ROUND:
				fails += 1; print("FAIL: too few puzzles ", lang, t, pool_n)
			e.new_game(t, 3, lang)
			if e.queue.size() != E.ROUND: fails += 1; print("FAIL: queue size")
			var seen := {}
			for i in e.queue:
				if seen.has(i): fails += 1; print("FAIL: repeat puzzle")
				seen[i] = true
			var turns := 0
			while not e.is_over():
				var p: Dictionary = e.puzzle()
				if p.e == "" or p.a.is_empty() or e.pattern().is_empty() or e.answer() == "":
					fails += 1; print("FAIL: bad puzzle ", p)
				if e.check("zzz xyz"): fails += 1; print("FAIL: wrong answer accepted")
				for a in p.a:
					if not e.check(str(a).to_upper() + "!"): fails += 1; print("FAIL: variant rejected ", a)
				e.hint()
				e.hint()
				if e.points_now() != 40 and e.answer().length() > 2: fails += 1; print("FAIL: hint cost ", e.points_now())
				if e.prefix().length() > e.answer().length() - 1: fails += 1; print("FAIL: prefix")
				var who: int = e.current
				var before: int = e.scores[who]
				e.solve_current()
				if e.scores[who] <= before: fails += 1; print("FAIL: no points")
				turns += 1
				if e.current != (who + 1) % 3: fails += 1; print("FAIL: turn order")
			if turns != E.ROUND: fails += 1; print("FAIL: turns")
	if E.normalize("Muñeco de Nieve!") != "munecodenieve": fails += 1; print("FAIL: normalize")
	e.new_game(1, 2, false)
	e.scores = [100, 100]
	if e.winner() != -1: fails += 1; print("FAIL: tie")
	e.scores = [100, 130]
	if e.winner() != 1: fails += 1; print("FAIL: winner")
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	e2.load_data()
	if not e2.from_dict(d) or e2.queue != e.queue or e2.scores != e.scores:
		fails += 1; print("FAIL: save round trip")
	print("emoji_guess: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
