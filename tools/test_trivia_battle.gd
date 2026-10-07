extends SceneTree

## Headless check of the Trivia Battle engine.
## godot --headless --path . --script res://tools/test_trivia_battle.gd

const E = preload("res://scripts/games/trivia_battle/trivia_battle_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	if not e.load_bank():
		fails += 1
		print("FAIL: bank")
	for t in E.TOPICS:
		if e.question_count(t) < 25:
			fails += 1
			print("FAIL: few questions in ", t)
		for q in e.bank[t]:
			for lang in ["en", "es"]:
				if q[lang].size() != 5:
					fails += 1
					print("FAIL: bad question ", q)
				var uniq := {}
				for c in q[lang].slice(1, 5):
					uniq[c] = true
				if uniq.size() != 4:
					fails += 1
					print("FAIL: duplicate answers ", q[lang][0])
	for lang in [false, true]:
		for pl in [2, 3, 4]:
			for topic in ["mixed", "science"]:
				e.new_game(pl, topic, lang)
				if e.total() != E.QUESTIONS:
					fails += 1
					print("FAIL: total ", e.total())
				while not e.is_over():
					e.new_round()
					for p in pl:
						var o: Array = e.options[p]
						if o.size() != 4 or o[e.correct[p]] != e.answer_text():
							fails += 1
							print("FAIL: options")
					e.begin()
					if e.tap_option(0, (e.correct[0] + 1) % 4) != "wrong":
						fails += 1
						print("FAIL: wrong tap")
					if e.tap_option(0, e.correct[0]) != "ignored":
						fails += 1
						print("FAIL: locked player tapped")
					if e.tap_option(1, e.correct[1]) != "win" or e.winner != 1:
						fails += 1
						print("FAIL: win")
					if e.tap_option(pl - 1, e.correct[pl - 1]) != "ignored":
						fails += 1
						print("FAIL: second winner")
					e.next_round()
				if e.scores[1] != E.QUESTIONS or e.match_winner() != 1:
					fails += 1
					print("FAIL: scores ", e.scores)
	e.new_game(2, "mixed", false)
	e.new_round()
	e.begin()
	e.tap_option(0, (e.correct[0] + 1) % 4)
	e.tap_option(1, (e.correct[1] + 1) % 4)
	if e.phase != "done" or e.winner != -1:
		fails += 1
		print("FAIL: everyone wrong")
	print("trivia_battle: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
