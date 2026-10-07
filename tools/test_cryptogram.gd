extends SceneTree

## Headless check of the Cryptogram engine.
## godot --headless --path . --script res://tools/test_cryptogram.gd

const E = preload("res://scripts/games/cryptogram/cryptogram_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	e.load_quotes()
	if e.quotes.en.size() < 30 or e.quotes.es.size() < 30:
		fails += 1; print("FAIL: quotes missing")
	for es in [false, true]:
		for lvl in 3:
			for r in 25:
				e.new_game(lvl, es)
				# nothing maps to itself, mapping is one-to-one, decode round-trips
				var seen := {}
				for p in e.cipher:
					if p == e.cipher[p] or seen.has(e.cipher[p]):
						fails += 1; print("FAIL: cipher ", p); break
					seen[e.cipher[p]] = true
				var back := ""
				for ch in e.encoded:
					back += e.truth.get(ch, ch)
				if back != e.plain:
					fails += 1; print("FAIL: round trip ", e.plain)
				for ch in e.plain:
					if ch >= "A" and ch <= "Z" or ch == "Ñ":
						continue
					if E.normalize(ch) != ch:
						fails += 1; print("FAIL: accent left ", ch)
				if e.solved():
					fails += 1; print("FAIL: solved at start")
				# solving by hints
				var guard := 0
				while not e.solved() and guard < 40:
					guard += 1
					if e.hint() == "":
						break
				if not e.solved():
					fails += 1; print("FAIL: hints don't solve ", e.plain)
	# one guess per cipher letter
	e.new_game(0, false)
	var cl: Array = e.cipher_letters()
	e.set_guess(cl[0], "Q")
	e.set_guess(cl[1], "Q")
	if e.guess[cl[0]] != "" or e.guess[cl[1]] != "Q":
		fails += 1; print("FAIL: guess uniqueness")
	e.set_guess(cl[1], "")
	if e.guess[cl[1]] != "":
		fails += 1; print("FAIL: clear")
	# correct guesses solve, wrong ones are reported
	e.new_game(1, true)
	for c in e.cipher_letters():
		e.set_guess(c, e.truth[c])
	if not e.solved() or not e.wrong_letters().is_empty():
		fails += 1; print("FAIL: manual solve")
	var c0: String = e.cipher_letters()[0]
	e.guess[c0] = "Z" if e.truth[c0] != "Z" else "Y"
	if e.wrong_letters() != [c0]:
		fails += 1; print("FAIL: wrong_letters")
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.encoded != e.encoded or e2.guess != e.guess:
		fails += 1; print("FAIL: save round trip")
	print("cryptogram: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
