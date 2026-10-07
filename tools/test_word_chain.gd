extends SceneTree

## Headless check of the Word Chain engine: the computer's words are always legal,
## chains link up, nothing repeats, and a game ends when somebody is stumped.
## godot --headless --path . --script res://tools/test_word_chain.gd

const E = preload("res://scripts/games/word_chain/word_chain_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	e.load_words()
	if e.valid.size() < 50000 or e.common_by_first.size() < 15:
		fails += 1; print("FAIL: lists ", e.valid.size(), " ", e.common_by_first.size())
	for lvl in 3:
		var longest := 0
		for g in 12:
			e.new_game("cpu", lvl)
			var guard := 0
			while not e.is_over() and guard < 400:
				guard += 1
				# the "human" is the same picker at the hard setting
				var w: String = e.cpu_pick()
				if w == "":
					e.lose_turn("stumped")
					break
				if e.play(w) != "ok":
					fails += 1; print("FAIL: illegal cpu word ", w, " need ", e.need); break
			longest = maxi(longest, e.chain.size())
			var prev := ""
			var seen := {}
			for en in e.chain:
				if prev != "" and en.word[0] != prev[prev.length() - 1]:
					fails += 1; print("FAIL: chain link ", prev, " ", en.word)
				if seen.has(en.word):
					fails += 1; print("FAIL: repeat ", en.word)
				seen[en.word] = true
				prev = en.word
			if not e.is_over():
				fails += 1; print("FAIL: game never ended at level ", lvl)
		print("level ", lvl, " longest chain ", longest)
	e.new_game("two", 0)
	var n: String = e.need
	if e.check("ab") != "short": fails += 1; print("FAIL: short")
	if e.check("zzz") != "letter" and n != "z": fails += 1; print("FAIL: letter")
	var ok_word: String = e.by_first[n][0]
	if e.check(ok_word) != "ok": fails += 1; print("FAIL: ok ", ok_word)
	e.play(ok_word)
	if e.check(ok_word) != "letter" and e.check(ok_word) != "used": fails += 1; print("FAIL: used")
	if e.turn != 1: fails += 1; print("FAIL: turn")
	e.lose_turn("timeout")
	if e.winner != 0 or not e.is_over(): fails += 1; print("FAIL: winner")
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	e2.load_words()
	if not e2.from_dict(d) or e2.chain != e.chain or e2.need != e.need or e2.winner != 0:
		fails += 1; print("FAIL: save round trip")
	print("word_chain: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
