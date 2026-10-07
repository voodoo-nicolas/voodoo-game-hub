extends SceneTree

## Headless check of the Who Am I? engine.
## godot --headless --path . --script res://tools/test_who_am_i.gd

const E = preload("res://scripts/games/who_am_i/who_am_i_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	e.load_items()
	for lang in [false, true]:
		for it in e.data["es" if lang else "en"]:
			if it.k.size() != E.CLUES or str(it.n) == "" or str(it.c) == "":
				fails += 1; print("FAIL: bad item ", it.n)
		if e.data["es" if lang else "en"].size() < 20:
			fails += 1; print("FAIL: few items")
		for pl in [1, 2, 4]:
			e.new_game(pl, 1, lang)
			if e.queue.size() != E.ROUND: fails += 1; print("FAIL: queue")
			while not e.is_over():
				e.new_round()
				for p in pl:
					var o: Array = e.options[p]
					if o.size() != 4 or o.has("") or o.count(e.name_of()) != 1 or o[e.correct[p]] != e.name_of():
						fails += 1; print("FAIL: options ", o)
					var uniq := {}
					for x in o: uniq[x] = true
					if uniq.size() != 4: fails += 1; print("FAIL: dup options")
				e.begin()
				while e.reveal(): pass
				if e.clue != E.CLUES or e.points_now() != 1: fails += 1; print("FAIL: reveal")
				if e.tap_option(0, (e.correct[0] + 1) % 4) != "wrong": fails += 1; print("FAIL: wrong")
				if pl > 1:
					var who: int = pl - 1
					if e.tap_option(who, e.correct[who]) != "win" or e.winner != who: fails += 1; print("FAIL: win")
					if e.scores[who] != 1 and e.scores[who] % 1 != 0: fails += 1; print("FAIL: score")
				else:
					if not e.all_locked() or e.phase != "done": fails += 1; print("FAIL: solo lock")
				e.next_round()
	e.new_game(2, 0, false)
	e.new_round()
	e.begin()
	if e.points_now() != 5: fails += 1; print("FAIL: first clue points")
	e.reveal()
	if e.points_now() != 4: fails += 1; print("FAIL: second clue points")
	e.tap_option(1, e.correct[1])
	if e.scores[1] != 4 or e.match_winner() != 1: fails += 1; print("FAIL: scoring ", e.scores)
	print("who_am_i: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
