extends SceneTree

## Headless check of the Sevens engine: legal plays, passing, and full games
## between computers always finish with every card accounted for.
## godot --headless --path . --script res://tools/test_sevens.gd

const E = preload("res://scripts/games/sevens/sevens_engine.gd")

func _init() -> void:
	var fails := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var e = E.new()
	e.new_game(1, rng)
	var starter: int = e.turn
	if not E.SEVEN_DIAMONDS in e.hands[starter]:
		fails += 1
		print("FAIL: starter")
	if e.legal(starter) != [E.SEVEN_DIAMONDS]:
		fails += 1
		print("FAIL: first play must be the 7 of diamonds ", e.legal(starter))
	if e.pass_turn(starter):
		fails += 1
		print("FAIL: passed with a legal play")
	if not e.play(starter, E.SEVEN_DIAMONDS) or e.low[2] != 7 or e.high[2] != 7:
		fails += 1
		print("FAIL: opening play")
	for lvl in 3:
		for g in 60:
			e.new_game(lvl, rng)
			var guard := 0
			while e.winner < 0 and guard < 2000:
				guard += 1
				var p: int = e.turn
				var c: int = e.cpu_play(p)
				if c < 0:
					if not e.pass_turn(p):
						fails += 1
						print("FAIL: couldn't pass")
						break
				elif not e.play(p, c):
					fails += 1
					print("FAIL: cpu illegal ", c)
					break
			if e.winner < 0:
				fails += 1
				print("FAIL: game never ended")
				continue
			if e.hands[e.winner].size() != 0:
				fails += 1
				print("FAIL: winner still has cards")
			var on_table := 0
			for s in 4:
				if e.high[s] > 0:
					on_table += e.high[s] - e.low[s] + 1
			var in_hands := 0
			for h in e.hands:
				in_hands += h.size()
			if on_table + in_hands != 52 or on_table != e.plays:
				fails += 1
				print("FAIL: card count ", on_table, " ", in_hands, " ", e.plays)
	print("sevens: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
