extends SceneTree

const E = preload("res://scripts/games/ancient_assassins/ancient_assassins_engine.gd")
var fails := 0

func ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	# 1. Maps are sane for many seeds and all styles.
	for s in 300:
		var e = E.new()
		e.reset(s)
		ok(e.ground.size() == E.COLS, "cols")
		for f in e.fighters:
			ok(f.y > 300 and f.y < E.H - 20, "fighter y %s seed %d" % [f.y, s])
			ok(f.hp == 100, "hp")
		ok(e.fighters[0].x < e.fighters[1].x, "order")
		for pl in e.pillars:
			ok(pl.top > 150, "pillar top")
		ok(absf(e.wind) <= E.WIND_MAX, "wind range")
	# 2. Same seed = same map and same wind sequence.
	var a = E.new(); a.reset(1234)
	var b = E.new(); b.reset(1234)
	ok(a.ground == b.ground and a.pillars == b.pillars, "map determinism")
	for n in 20:
		ok(a.wind_for(n) == b.wind_for(n), "wind determinism")
	var winds := {}
	for n in 40:
		winds[a.wind_for(n)] = true
	ok(winds.size() > 8, "wind varies")
	# 3. Zones.
	var z = E.new(); z.reset(5)
	var f0: Dictionary = z.fighters[1]
	ok(z.zone_at(1, Vector2(f0.x, f0.y - 108)) == "head", "head zone")
	ok(z.zone_at(1, Vector2(f0.x, f0.y - 75)) == "body", "body zone")
	ok(z.zone_at(1, Vector2(f0.x, f0.y - 20)) == "legs", "legs zone")
	ok(z.zone_at(1, Vector2(f0.x + 40, f0.y - 75)) == "", "miss zone")
	print("maps ok %d ms" % (Time.get_ticks_msec() - t0))
	# 4. Calm wind: CPU Expert hits a lot; Easy hits less. A whole match ends.
	var hits := [0, 0, 0, 0]
	var tries := 30
	for lvl in 4:
		for s in tries:
			var e = E.new()
			e.reset(1000 + s)
			e.turn = 0
			var plan: Dictionary = e.cpu_aim(0, lvl)
			e.pick_weapon(0, plan.weapon)
			e.set_aim(0, plan.angle, plan.power)
			e.throw()
			var res := []
			for k in 2000:
				res = e.step(1.0 / 60.0)
				if not res.is_empty():
					break
			if not res.is_empty() and res[0].kind == "hit" and res[0].f == 1:
				hits[lvl] += 1
	print("cpu %d ms for %d aims" % [Time.get_ticks_msec() - t0, tries * 4])
	print("first-throw hit rate by level (of %d): %s" % [tries, hits])
	ok(hits[3] >= hits[0], "expert >= easy")
	ok(hits[3] > tries * 0.4, "expert hits often")
	# 5. Prediction matches the real throw.
	var pr = E.new(); pr.reset(77)
	for k in 20:
		var ang := 20.0 + k * 3.0
		var pw := 55.0 + k
		var pred: Dictionary = pr.predict(0, ang, pw, k % 3)
		var r = E.new(); r.reset(77)
		r.pick_weapon(0, k % 3)
		r.set_aim(0, ang, pw)
		r.throw()
		var res := []
		for n in 3000:
			res = r.step(1.0 / 60.0)
			if not res.is_empty():
				break
		if res[0].kind == "out":
			ok(pred.out, "pred out %d" % k)
		else:
			ok((res[0].p as Vector2).distance_to(pred.p) < 0.01, "pred matches real %d: %s vs %s" % [k, res[0].p, pred.p])
	# 6. Full CPU vs CPU matches end with a winner; save/load round trip.
	var turns_total := 0
	for s in 30:
		var e = E.new()
		e.reset(5000 + s)
		var n := 0
		while not e.is_over() and n < 80:
			var plan: Dictionary = e.cpu_aim(e.turn, 1)
			e.pick_weapon(e.turn, plan.weapon)
			e.set_aim(e.turn, plan.angle, plan.power)
			e.throw()
			while not e.shot.is_empty():
				e.step(1.0 / 30.0)
			e.settle()
			n += 1
			if n == 3:
				var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
				var c = E.new()
				ok(c.from_dict(d), "from_dict")
				ok(JSON.stringify(c.snapshot()) == JSON.stringify(e.snapshot()), "snapshot round trip")
		ok(e.is_over(), "match ends seed %d after %d" % [s, n])
		turns_total += n
	print("avg throws per Normal vs Normal match: %.1f" % (turns_total / 30.0))
	# 7. Ammo.
	var am = E.new(); am.reset(9)
	am.pick_weapon(0, 1); am.throw(); am.shot = {}
	am.pick_weapon(0, 1); am.throw(); am.shot = {}
	ok(am.fighters[0].ammo[1] == 0 and not am.pick_weapon(0, 1), "axe ammo runs out")
	ok(am.fighters[0].weapon == 0, "falls back to javelin")
	print("time %d ms, fails %d" % [Time.get_ticks_msec() - t0, fails])
	quit(1 if fails else 0)
