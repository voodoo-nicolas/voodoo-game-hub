extends SceneTree

## Headless check of Red Mist's logic: geometry round-trips, ballistics numbers,
## the sway is calm in the breath's pause and while the breath is held, a dead-on
## shot hits (with Normal's dial and Hard's hold-over), a miss scares, drums
## blow up their neighbours, every contract places its targets, the save
## round-trips, survival ends on 3 escapes.
## godot --headless --path . --script res://tools/test_red_mist.gd

const E = preload("res://scripts/games/red_mist/red_mist_engine.gd")

var fails := 0

func _init() -> void:
	_geometry()
	_ballistics()
	_sway()
	_contracts()
	_shooting()
	_drum()
	_save()
	_survival()
	_civilian()
	_convoy()
	_clock()
	_kit()
	_cover()
	print("RED MIST TEST: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _geometry() -> void:
	for d in [100.0, 250.0, 600.0, 950.0]:
		_ok(absf(E.depth_at_y(E.ground_y(d)) - d) < 0.01, "depth_at_y(ground_y(%d))" % d)
	_ok(E.ground_y(82.0) > E.H * 0.99, "the ground reaches the bottom of the picture near 82 m")
	_ok(E.depth_at_y(E.HORIZON - 10.0) == 0.0, "sky has no range")

func _ballistics() -> void:
	_ok(absf(E.drop_mils(300.0)) < 0.001, "zeroed at 300 m")
	_ok(E.drop_mils(100.0) < 0.0, "high at 100 m with a 300 m zero")
	var d600 := E.drop_mils(600.0)
	_ok(d600 > 3.0 and d600 < 4.5, "600 m drop ~3.7 mils (got %.2f)" % d600)
	var d1000 := E.drop_mils(1000.0)
	_ok(d1000 > 8.0 and d1000 < 12.0, "1000 m drop ~10 mils (got %.2f)" % d1000)
	var w := E.wind_mils(600.0, 4.0)
	_ok(w > 0.7 and w < 1.3, "4 m/s at 600 m ~1 mil (got %.2f)" % w)
	_ok(E.wind_mils(600.0, -4.0) < 0.0, "wind from the other side drifts the other way")
	print("drop 300/600/900: %.2f %.2f %.2f mils; wind 4 m/s at 600: %.2f mils; tof 900: %.2f s" % [E.drop_mils(300.0), d600, E.drop_mils(900.0), w, E.tof(900.0)])

func _sway() -> void:
	var e := E.new()
	e.reset("contract", 1, 0)
	var moving_max := 0.0
	var pause_max := 0.0
	for i in 420:  # 4.2 s, one breath
		e.step(0.01)
		var s: float = e.sway_mils().length()
		if e.breath_phase() < E.BREATH_MOVE:
			moving_max = maxf(moving_max, s)
		elif e.breath_phase() > E.BREATH_MOVE + 0.05:
			pause_max = maxf(pause_max, s)
	_ok(moving_max > 2.0, "the breath moves the aim (max %.2f mils)" % moving_max)
	_ok(pause_max < 0.8, "the pause is calm (max %.2f mils)" % pause_max)
	print("sway: breathing max %.2f mils, pause max %.2f mils" % [moving_max, pause_max])
	# Hold the breath mid-inhale: calm within half a second, gasp after HOLD_MAX.
	e.reset("contract", 1, 0)
	for i in 80:
		e.step(0.01)
	e.hold_breath(true)
	for i in 100:
		e.step(0.01)
	var held := 0.0
	for i in 200:
		e.step(0.01)
		held = maxf(held, e.sway_mils().length())
	_ok(held < 0.7, "held breath is steady (max %.2f)" % held)
	_ok(e.steady() > 0.75, "steady() high while holding (%.2f)" % e.steady())
	for i in 400:
		e.step(0.01)
	_ok(not e.holding and e.gasp_t > 0.0, "the breath runs out after %.1f s" % E.HOLD_MAX)
	e.hold_breath(true)
	_ok(not e.holding, "can't hold again while gasping")
	# Shots raise the heart.
	var h0: float = e.heart
	e.mag = 5
	e.ammo = 5
	e.bolt_t = 0.0
	e.reload_t = 0.0
	e.fire(Vector2(10, 10))
	_ok(e.heart > h0, "a shot raises the heart")

func _contracts() -> void:
	var e := E.new()
	_ok(E.CONTRACTS.size() == E.LOCATIONS.size() * E.PER_PLACE, "5 contracts per place (%d)" % E.CONTRACTS.size())
	for c in E.CONTRACTS.size():
		var cd := E.contract_def(c)
		_ok(E.chapter_of(c) == E.LOCATIONS.find(cd.loc), "contract %d sits in its place's chapter" % (c + 1))
		for lv in 3:
			e.reset("contract", lv, c)
			var want: int = cd.n
			_ok(e.count_targets() >= mini(want, 3), "contract %d level %d places targets (%d of %d)" % [c + 1, lv, e.count_targets(), want])
			var prim := 0
			var civ := 0
			for tg in e.targets:
				if tg.primary:
					prim += 1
				if tg.civ:
					civ += 1
				elif tg.state != "walk":
					_ok(float(tg.d) >= float(cd.near) and float(tg.d) <= float(cd.far), "contract %d target in range (%d)" % [c + 1, int(tg.d)])
			_ok(prim == (0 if cd.goal == "convoy" else 1), "contract %d: %d officer(s) for goal %s" % [c + 1, prim, cd.goal])
			_ok(civ == int(cd.civ), "contract %d civilians %d of %d" % [c + 1, civ, int(cd.civ)])
			_ok(e.trucks_total() == int(cd.trucks), "contract %d trucks" % (c + 1))
			_ok(e.ammo > e.count_targets() + e.trucks_total(), "contract %d spare rounds" % (c + 1))
			_ok((e.limit > 0.0) == (int(cd.limit) > 0), "contract %d clock" % (c + 1))
	e.reset("daily", 1, 0, 20261120)
	_ok(e.count_targets() >= 3, "daily places targets")
	var e2 := E.new()
	e2.reset("daily", 1, 0, 20261120)
	_ok(e2.loc == e.loc and e2.contract == e.contract and e2.targets.size() == e.targets.size() and float(e2.targets[0].x) == float(e.targets[0].x), "daily is the same for everyone")
	# Every road is drivable: a truck gets from one end to the other.
	for lc in E.LOCATIONS:
		e.reset("survival", 1, 0, 5, lc)
		_ok(e.loc == lc, "survival in %s" % lc)
		_ok(e.road_length() > 100.0, "%s road %.0f m" % [lc, e.road_length()])

## Aim dead on the officer's chest: Easy and Normal hit as is; Hard needs the hold-over.
func _shooting() -> void:
	for lv in 3:
		var e := E.new()
		e.reset("contract", lv, 5)
		var tg := _officer(e)
		e.wind_base = 3.0
		e.wind = 3.0
		var d: float = tg.d
		var foot: Vector2 = e.target_pos(tg)
		var chest := foot + Vector2(0, -1.25 * E.upm(d))
		var aim := chest
		if lv == 2:
			aim -= e.impact_mils(d, 0.0) * E.MIL
		elif lv == 1:
			aim -= Vector2(E.wind_mils(d, e.wind), 0.0) * E.MIL
		var r: Dictionary = e.fire(aim, d)
		_ok(r.get("kind", "") == "target" and int(r.id) == int(tg.id), "level %d: aimed shot hits the officer (%s)" % [lv, str(r.get("kind", "?"))])
		for i in 300:
			e.step(0.01)
		_ok(tg.state in ["down", "gone"] and float(tg.down_t) > 0.0 and e.kills == 1, "level %d: the officer falls when the bullet lands (%s, %d)" % [lv, tg.state, e.kills])
		_ok(e.score >= 300, "level %d: an officer is worth double (%d)" % [lv, e.score])
	# Hard without hold-over at 600 m+ misses low.
	var e := E.new()
	e.reset("contract", 2, 18)
	var tg := _officer(e)
	var far: float = tg.d
	var r: Dictionary = e.fire(e.target_pos(tg) + Vector2(0, -1.25 * E.upm(far)), far)
	if far > 500.0:
		_ok(r.get("kind", "") != "target" or int(r.id) != int(tg.id), "Hard: no hold-over at %d m misses" % int(far))
	# A miss next to someone sends them into cover.
	e.reset("contract", 1, 0)
	var g: Dictionary = e.targets[0]
	e.wind_base = 0.0
	e.wind = 0.0
	var beside: Vector2 = e.target_pos(g) + Vector2(2.0 * E.upm(g.d), -0.2 * E.upm(g.d))
	var m: Dictionary = e.fire(beside, g.d)
	_ok(m.get("kind", "") == "miss", "a shot beside a target misses")
	_ok(g.state == "cover", "the near miss sends it into cover (%s)" % g.state)
	_ok(e.alarm > 0.0, "shots raise the alarm")
	# Bolt: no second shot at once.
	_ok(e.fire(beside, g.d).is_empty(), "the bolt must cycle")
	for i in 120:
		e.step(0.01)
	_ok(not e.fire(beside, g.d).is_empty(), "fires again after the bolt")

func _officer(e) -> Dictionary:
	for tg in e.targets:
		if tg.primary:
			return tg
	return e.targets[0]

func _drum() -> void:
	var e := E.new()
	e.reset("contract", 0, 0)
	var drum: Dictionary = {}
	for pr in e.props:
		if pr.kind == "drum":
			drum = pr
			break
	var tg: Dictionary = e.targets[0]
	tg.x = drum.x + 2.0 * E.upm(drum.d)
	tg.d = drum.d
	tg.h = 0.0
	tg.state = "idle"
	tg.cover = 0.0
	tg.primary = false
	var aim := Vector2(drum.x, E.ground_y(drum.d) - 0.45 * E.upm(drum.d))
	var r: Dictionary = e.fire(aim, drum.d)
	_ok(r.get("kind", "") == "drum", "the drum is hit (%s)" % r.get("kind", "?"))
	for i in 100:
		e.step(0.01)
	_ok(not drum.alive and tg.state == "down", "the drum blows up the guard beside it")

func _save() -> void:
	var e := E.new()
	e.reset("contract", 1, 7)
	for i in 250:
		e.step(0.02)
	e.fire(Vector2(1200, 600), 400.0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 := E.new()
	e2.from_dict(d)
	_ok(e2.loc == e.loc and e2.targets.size() == e.targets.size() and e2.ammo == e.ammo and e2.shots == e.shots, "save round-trips")
	_ok(absf(float(e2.targets[0].x) - float(e.targets[0].x)) < 0.01, "save keeps positions")
	for i in 100:
		e2.step(0.05)
	_ok(true, "a loaded game steps")

func _survival() -> void:
	var e := E.new()
	e.reset("survival", 1, 0, 99)
	_ok(e.ammo == -1, "survival has endless rounds")
	var steps := 0
	while not e.over and steps < 60000:
		e.step(0.05)
		steps += 1
	_ok(e.over and e.reason == "escapes" and e.escapes >= 3, "survival ends after 3 escapes (%s, %d)" % [e.reason, e.escapes])
	print("survival: over after %.0f s, wave %d" % [e.t, e.wave])

func _civilian() -> void:
	var e := E.new()
	e.reset("contract", 1, 7)
	var cv: Dictionary = {}
	for tg in e.targets:
		if tg.civ:
			cv = tg
			break
	_ok(not cv.is_empty(), "contract 8 has a civilian")
	if cv.is_empty():
		return
	e.wind_base = 0.0
	e.wind = 0.0
	cv.state = "idle"
	var chest: Vector2 = e.target_pos(cv) + Vector2(0, -1.25 * E.upm(cv.d))
	var r: Dictionary = e.fire(chest, cv.d)
	_ok(r.get("kind", "") == "civilian", "a shot at a civilian hits him (%s)" % r.get("kind", "?"))
	for i in 200:
		e.step(0.01)
	_ok(e.over and not e.won and e.reason == "civilian", "hitting a civilian ends the contract (%s)" % e.reason)
	_ok(e.kills == 0, "a civilian is not a kill")

func _convoy() -> void:
	var e := E.new()
	e.reset("contract", 1, 3)
	_ok(e.goal == "convoy" and e.trucks_total() == 1, "contract 4 is a convoy")
	var tr: Dictionary = {}
	for pr in e.props:
		if pr.kind == "truck":
			tr = pr
	for i in 800:
		e.step(0.01)
		if tr.state == "drive":
			break
	_ok(tr.state == "drive", "the truck sets off")
	for i in 100:
		e.step(0.01)
	e.wind_base = 0.0
	e.wind = 0.0
	var d: float = tr.d
	var foot: Vector2 = e.truck_pos(tr, E.tof(d))
	var spots: Array = e.truck_spots(tr, foot)
	var r: Dictionary = e.fire(spots[1], d)
	_ok(r.get("kind", "") == "cab", "a shot through the cab window (%s)" % r.get("kind", "?"))
	for i in 200:
		e.step(0.01)
	_ok(tr.state == "stopped" and e.stopped == 1, "the truck stops (%s)" % tr.state)
	# A truck nobody stops gets away and the convoy contract fails.
	e.reset("contract", 1, 3)
	var steps := 0
	while not e.over and steps < 20000:
		e.step(0.02)
		steps += 1
	_ok(e.over and e.reason == "convoy", "an escaped truck fails the convoy (%s)" % e.reason)

func _clock() -> void:
	var e := E.new()
	e.reset("contract", 1, 6)
	_ok(e.goal == "timed" and e.limit > 0.0, "contract 7 is timed")
	var steps := 0
	while not e.over and steps < 20000:
		e.step(0.05)
		steps += 1
	_ok(e.over and (e.reason == "time" or e.reason == "escaped"), "the clock runs out (%s after %.0f s)" % [e.reason, e.t])

func _kit() -> void:
	var e := E.new()
	e.reset("contract", 1, 0)
	var s0: float = 0.0
	for i in 420:
		e.step(0.01)
		s0 = maxf(s0, e.sway_mils().length())
	e.set_kit({"bipod": 3, "bolt": 3, "supp": 3})
	e.reset("contract", 1, 0)
	var s1: float = 0.0
	for i in 420:
		e.step(0.01)
		s1 = maxf(s1, e.sway_mils().length())
	_ok(s1 < s0 * 0.8, "the bipod steadies the aim (%.2f -> %.2f mils)" % [s0, s1])
	e.fire(Vector2(10, 10))
	_ok(absf(e.bolt_t - 0.65) < 0.01, "the bolt upgrade cycles faster (%.2f s)" % e.bolt_t)
	_ok(e.alarm < 9.0 * 0.5, "the suppressor keeps the alarm down (%.1f)" % e.alarm)
	for key in E.UPGRADES:
		_ok((E.UPGRADES[key].cost as Array).size() == 3, "%s has 3 prices" % key)

func _cover() -> void:
	var e := E.new()
	e.reset("contract", 0, 0)
	var u := E.upm(210.0)
	var r: Dictionary = e.fire(Vector2(640.0, E.ground_y(210.0) - 1.2 * u), 210.0)
	_ok(r.get("kind", "") == "miss" and r.get("blocked", false), "a shot into a cabin wall is blocked (%s)" % str(r))
	e.bolt_t = 0.0
	var r2: Dictionary = e.fire(Vector2(1200.0, 120.0), 0.0)
	_ok(not r2.get("blocked", false), "a shot into the sky isn't blocked")
