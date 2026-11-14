extends SceneTree

## Hover Duel engine test: every campaign map builds with open start spots,
## AI vs AI battles end, nobody ends inside rock, save round-trips.
## godot --headless --path . --script res://tools/test_hover_duel.gd

func _init() -> void:
	var E = load("res://scripts/games/hover_duel/hover_duel_engine.gd")
	var fails := 0
	var t0 := Time.get_ticks_msec()
	var ends := 0
	var total_t := 0.0
	for lv in E.CAMPAIGN.size():
		var b: Dictionary = E.CAMPAIGN[lv]
		for trial in 2:
			var e = E.new()
			e.reset(b.theme, b.seed, ["skimmer", b.foe], [2, b.ai])
			for c in e.crafts:
				if e._blocked(c.p):
					print("FAIL start in rock lv", lv); fails += 1
			var steps := 0
			while not e.is_over() and steps < 60 * 180:
				e.step(E.DT, [{}, {}])
				steps += 1
				for c in e.crafts:
					if c.alive and e.is_rock(c.p):
						print("FAIL inside rock lv", lv, " ", c.p); fails += 1; steps = 999999
			if e.is_over():
				ends += 1
			print("lv %d %s: %.0f s winner %d hp %.0f/%.0f  %d ms" % [lv, b.theme, steps * E.DT, e.winner, e.crafts[0].hp, e.crafts[1].hp, Time.get_ticks_msec() - t0])
			total_t += steps * E.DT
			var d: Dictionary = e.to_dict()
			var e2 = E.new()
			e2.from_dict(JSON.parse_string(JSON.stringify(d)))
			if absf(e2.crafts[0].hp - e.crafts[0].hp) > 0.01 or e2.hgt != e.hgt:
				print("FAIL save round trip lv", lv); fails += 1
	print("battles ended: %d / 24, avg %.0f s, %d ms" % [ends, total_t / 24.0, Time.get_ticks_msec() - t0])
	if ends < 20:
		print("FAIL too many stalemates"); fails += 1
	print("FAILS: ", fails)
	quit(1 if fails else 0)
