extends SceneTree

## Headless check of the Fastest Finger engine.
## godot --headless --path . --script res://tools/test_fastest_finger.gd

const E = preload("res://scripts/games/fastest_finger/fastest_finger_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	for ch in 4:
		for pl in [2, 3, 4]:
			e.new_game(pl, ch)
			var guard := 0
			while e.match_winner() < 0 and guard < 200:
				guard += 1
				e.new_round()
				if e.phase != "ready": fails += 1; print("FAIL: phase ready")
				e.begin_wait()
				if e.kind == "reaction":
					if e.phase != "wait": fails += 1; print("FAIL: wait")
					if e.tap_pad(0) != "early" or not e.locked[0]: fails += 1; print("FAIL: early")
					e.go()
					if e.phase != "live": fails += 1; print("FAIL: go")
					if e.tap_pad(0) != "ignored": fails += 1; print("FAIL: locked tap")
					var p: int = 1
					if e.tap_pad(p) != "win" or e.winner != p: fails += 1; print("FAIL: pad win")
					if e.tap_pad(2 % pl) == "win": fails += 1; print("FAIL: second winner")
				else:
					if e.phase != "live": fails += 1; print("FAIL: live ", e.kind)
					for p in pl:
						var opts: Array = e.options[p]
						if e.kind == "math":
							if opts.size() != 3 or opts.count(opts[e.correct[p]]) != 1: fails += 1; print("FAIL: math options")
						else:
							if opts.count(e.shape_odd) != 1 or opts[e.correct[p]] != e.shape_odd: fails += 1; print("FAIL: odd options")
					# everyone wrong -> round ends with nobody
					var wrong_idx: int = (e.correct[0] + 1) % e.options[0].size()
					if e.tap_option(0, wrong_idx) != "wrong": fails += 1; print("FAIL: wrong")
					if e.tap_option(0, e.correct[0]) != "ignored": fails += 1; print("FAIL: locked option")
					var who: int = 1
					if e.tap_option(who, e.correct[who]) != "win" or e.winner != who: fails += 1; print("FAIL: option win")
					if e.tap_option(2 % pl, e.correct[2 % pl]) == "win" and 2 % pl != who: fails += 1; print("FAIL: second option winner")
			if e.match_winner() != 1: fails += 1; print("FAIL: match winner ", e.match_winner(), " ch ", ch)
	# all locked ends the round without a winner
	e.new_game(2, 1)
	e.new_round()
	e.begin_wait()
	e.tap_option(0, (e.correct[0] + 1) % 3)
	e.tap_option(1, (e.correct[1] + 1) % 3)
	if not e.round_over() or e.winner != -1: fails += 1; print("FAIL: nobody round")
	print("fastest_finger: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
