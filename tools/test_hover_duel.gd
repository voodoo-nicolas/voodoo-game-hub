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
	# Objectives: daily / weekly roll over by date, finish once, pay medals once.
	var G = load("res://scripts/games/hover_duel/hover_duel_goals.gd")
	var g = G.new()
	g.roll(20000)
	var d: Dictionary = g.daily()
	var got: Array = g.add_battle({d.stat: d.need}, 20000)
	if not got.has("daily") or int(g.data.medals) < G.DAILY_MEDALS:
		print("FAIL daily not done"); fails += 1
	var m: int = int(g.data.medals)
	g.add_battle({d.stat: 99}, 20000)
	if int(g.data.medals) != m:
		print("FAIL daily paid twice"); fails += 1
	g.roll(20001)
	if g.data.day_done or int(g.data.day_n) != 0:
		print("FAIL day did not roll"); fails += 1
	if G.week_of(20000) == G.week_of(20000 + 7):
		print("FAIL week did not roll"); fails += 1
	var w: Dictionary = g.weekly()
	if not g.add_battle({w.stat: w.need}, 20001).has("weekly"):
		print("FAIL weekly not done"); fails += 1
	if not g.paint_unlocked(0) or g.paint_unlocked(5):
		print("FAIL paints"); fails += 1
	var Story = load("res://scripts/games/hover_duel/hover_duel_story.gd")
	if Story.CHAPTERS.size() != E.CAMPAIGN.size():
		print("FAIL story chapters"); fails += 1
	print("battles ended: %d / 24, avg %.0f s, %d ms" % [ends, total_t / 24.0, Time.get_ticks_msec() - t0])
	if ends < 20:
		print("FAIL too many stalemates"); fails += 1
	print("FAILS: ", fails)
	quit(1 if fails else 0)
