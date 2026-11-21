extends SceneTree

## Ancient Assassins engine (3D): maps, determinism, hit zones, prediction =
## the real throw, the computer's aim by level, whole matches, save round trip.
##   godot --headless --path . --script res://tools/test_ancient_assassins.gd

const E = preload("res://scripts/games/ancient_assassins/ancient_assassins_engine.gd")
var fails := 0

func ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func _run_throw(e, i: int, yaw: float, pitch: float, w: int) -> Dictionary:
	e.turn = i
	e.pick_weapon(i, w)
	e.set_aim(i, yaw, pitch)
	e.throw()
	for n in 4000:
		var res: Array = e.step(1.0 / 60.0)
		if not res.is_empty():
			return res[0]
	return {}

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	for s in 200:
		var e = E.new()
		e.reset(s)
		ok(e.fighters[0].z < e.fighters[1].z, "order")
		ok(absf(e.wind) <= E.WIND_MAX + 0.001, "wind range")
		for f in e.fighters:
			ok(f.hp == 100 and f.y > 0.5, "fighter")
	var a = E.new(); a.reset(1234)
	var b = E.new(); b.reset(1234)
	ok(JSON.stringify(a.snapshot()) == JSON.stringify(b.snapshot()), "map determinism")
	var winds := {}
	for n in 40:
		ok(a.wind_for(n) == b.wind_for(n), "wind determinism")
		winds[a.wind_for(n)] = true
	ok(winds.size() > 8, "wind varies")
	var z = E.new(); z.reset(5)
	var f1: Vector3 = z.feet(1)
	ok(z.zone_at(1, f1 + Vector3(0, E.HEAD_Y, 0)) == "head", "head")
	ok(z.zone_at(1, f1 + Vector3(0, 1.2, 0)) == "body", "body")
	ok(z.zone_at(1, f1 + Vector3(0, 0.4, 0)) == "legs", "legs")
	ok(z.zone_at(1, f1 + Vector3(0.6, 1.2, 0)) == "", "miss")
	print("maps ok %d ms" % (Time.get_ticks_msec() - t0))
	# Prediction = the real throw, at an odd frame rate.
	for k in 20:
		var e = E.new(); e.reset(77)
		var yaw := -10.0 + k
		var pitch := 5.0 + k * 1.5
		var pred: Dictionary = e.predict(0, yaw, pitch, k % 3)
		var r := _run_throw(e, 0, yaw, pitch, k % 3)
		if r.kind == "out":
			ok(pred.out, "pred out %d" % k)
		else:
			ok((r.p as Vector3).distance_to(pred.p) < 0.001, "pred %d: %s vs %s" % [k, r.p, pred.p])
	# The computer by level: first-throw hits.
	var hits := [0, 0, 0, 0]
	var tries := 30
	var t1 := Time.get_ticks_msec()
	for lvl in 4:
		for s in tries:
			var e = E.new(); e.reset(1000 + s)
			var plan: Dictionary = e.cpu_aim(0, lvl)
			var r := _run_throw(e, 0, plan.yaw, plan.pitch, plan.weapon)
			if r.get("kind", "") == "hit" and r.f == 1:
				hits[lvl] += 1
	print("cpu %d ms per aim" % ((Time.get_ticks_msec() - t1) / (tries * 4)))
	print("first-throw hit rate by level (of %d): %s" % [tries, hits])
	ok(hits[3] > hits[0], "expert > easy")
	ok(hits[3] >= tries * 0.4, "expert hits often")
	# Whole matches end; save round trip.
	var total := 0
	for s in 20:
		var e = E.new(); e.reset(5000 + s)
		var n := 0
		while not e.is_over() and n < 80:
			var plan: Dictionary = e.cpu_aim(e.turn, 1)
			e.pick_weapon(e.turn, plan.weapon)
			e.set_aim(e.turn, plan.yaw, plan.pitch)
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
		ok(e.is_over(), "match ends seed %d" % s)
		total += n
	print("avg throws per Normal vs Normal match: %.1f" % (total / 20.0))
	var am = E.new(); am.reset(9)
	am.pick_weapon(0, 1); am.throw(); am.shot = {}
	am.pick_weapon(0, 1); am.throw(); am.shot = {}
	ok(am.fighters[0].ammo[1] == 0 and not am.pick_weapon(0, 1), "axe ammo runs out")
	print("time %d ms, fails %d" % [Time.get_ticks_msec() - t0, fails])
	quit(1 if fails else 0)
