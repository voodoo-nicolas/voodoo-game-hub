extends SceneTree

## Headless test for Camera Hunter's engine (scripts/games/hue_hunt/hue_hunt_engine.gd).
##   godot --headless --path . --script res://tools/test_hue_hunt.gd
## Touches no save files.

const E = preload("res://scripts/games/hue_hunt/hue_hunt_engine.gd")

var fails := 0


func _initialize() -> void:
	if E.colors().is_empty():
		print("hue_hunt: engine failed to load")
		quit(1)
		return
	_colour_maths()
	_sampling()
	_data()
	_round_types()
	_ties()
	_plans()
	_room()
	print("hue_hunt: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)


func near(a: float, b: float, eps: float, what: String) -> void:
	ok(absf(a - b) <= eps, "%s: %f vs %f" % [what, a, b])


func _colour_maths() -> void:
	# Sharma, Wu, Dalal (2005) test pairs, kL = 1.
	var pairs := [
		[Vector3(50, 2.6772, -79.7751), Vector3(50, 0, -82.7485), 2.0425],
		[Vector3(50, 3.1571, -77.2803), Vector3(50, 0, -82.7485), 2.8615],
		[Vector3(50, 0, 0), Vector3(50, -1, 2), 2.3669],
		[Vector3(50, 2.5, 0), Vector3(73, 25, -18), 27.1492],
		[Vector3(60.2574, -34.0099, 36.2677), Vector3(60.4626, -34.1751, 39.4387), 1.2644],
		[Vector3(22.7233, 20.0904, -46.6940), Vector3(23.0331, 14.9730, -42.5619), 2.0373],
		[Vector3(90.8027, -2.0831, 1.4410), Vector3(91.1528, -1.6435, 0.0447), 1.4441],
		[Vector3(2.0776, 0.0795, -1.1350), Vector3(0.9033, -0.0636, -0.5514), 0.9082],
	]
	for p in pairs:
		near(E.de2000(p[0], p[1], 1.0), p[2], 0.0005, "de2000 %s" % str(p[0]))
		near(E.de2000(p[1], p[0], 1.0), p[2], 0.0005, "de2000 symmetric %s" % str(p[0]))
	var lab := E.to_lab(Color.html("#7f3fbf"))
	ok(E.de2000(lab, lab) == 0.0, "identical = 0")
	# kL = 2 halves a pure lightness difference
	var a := Vector3(50, 10, 10)
	var b := Vector3(60, 10, 10)
	near(E.de2000(a, b, 2.0), E.de2000(a, b, 1.0) / 2.0, 0.0001, "kL=2 halves dL")
	# sRGB -> Lab references
	var w := E.to_lab(Color(1, 1, 1))
	near(w.x, 100.0, 0.01, "white L")
	near(w.y, 0.0, 0.01, "white a")
	near(w.z, 0.0, 0.01, "white b")
	var r := E.to_lab(Color(1, 0, 0))
	near(r.x, 53.24, 0.05, "red L")
	near(r.y, 80.09, 0.05, "red a")
	near(r.z, 67.20, 0.05, "red b")
	var back := E.to_rgb(E.to_lab(Color(0.2, 0.5, 0.7)))
	near(back.r, 0.2, 0.002, "round trip r")
	near(back.b, 0.7, 0.002, "round trip b")
	ok(E.pct(0.0) == 100 and E.pct(E.PCT_ZERO_DE) == 0 and E.pct(99.0) == 0, "pct ends")
	ok(E.pct(8.0) == 80, "pct(8) = 80")
	var o := E.opposite(Vector3(60, 30, -20))
	near(E.chroma(o), E.chroma(Vector3(60, 30, -20)), 0.0001, "opposite keeps C")
	near(fposmod(E.hue(o) - E.hue(Vector3(60, 30, -20)), 360.0), 180.0, 0.0001, "opposite hue +180")


func _sampling() -> void:
	var px := []
	for i in 200:
		px.append(Color(0.4, 0.2, 0.1))
	for i in 25:
		px.append(Color(1, 1, 1))   # specular highlight
	var s := E.sample(px)
	ok(s.ok, "sample ok with a few highlights")
	near(E.de2000(s.lab, E.to_lab(Color(0.4, 0.2, 0.1))), 0.0, 0.001, "median ignores clipped pixels")
	ok(s.clipped > 0.1 and s.clipped < 0.12, "clipped share %f" % s.clipped)
	var dark := []
	for i in 100:
		dark.append(Color(0.005, 0.005, 0.005))
	ok(not E.sample(dark).ok, "all black -> retake")
	ok(not E.sample([]).ok, "empty -> retake")
	# median beats an outlier
	var noisy := []
	for i in 9:
		noisy.append(Color(0.3, 0.6, 0.3))
	noisy.append(Color(0.9, 0.1, 0.1))
	near(E.de2000(E.sample(noisy).lab, E.to_lab(Color(0.3, 0.6, 0.3))), 0.0, 0.001, "median drops outlier")


func _data() -> void:
	ok(E.colors().size() == 150, "150 colours: %d" % E.colors().size())
	var ids := {}
	for c in E.colors():
		ok(not ids.has(c[0]), "unique id " + c[0])
		ids[c[0]] = true
		ok(c[2] != "", "ES name " + c[0])
		ok(c[4] in ["easy", "medium", "hard"], "tier " + c[0])
		ok(Color.html_is_valid(c[3]), "hex " + c[0])
	ok(E.color_name("teal", true) == "verde azulado", "ES name lookup")
	ok(E.daily_color("2026-11-26") == E.daily_color("2026-11-26"), "daily stable")
	var book := {}
	ok(E.book_add(book, "teal", 80, "#008080", "2026-11-26"), "book add")
	ok(not E.book_add(book, "teal", 70, "#008080", "2026-11-27"), "book keeps better")
	ok(E.book_add(book, "teal", 90, "#008181", "2026-11-28") and book.teal.pct == 90 and book.teal.date == "2026-11-26", "book improves, first date kept")
	ok(E.time_attack_score([80, 75, 0]) == 155, "time attack sum")


func _li(player: String, t: float, spec: Dictionary, labs: Array, flagged := false) -> Dictionary:
	var s := E.score(spec, labs)
	return {"player": player, "t": t, "labs": labs, "value": s.value, "de": s.de, "close": s.close, "flagged": flagged}


func _award(res: Dictionary, award: String) -> String:
	for a in res.awards:
		if a.award == award:
			return a.player
	return ""


func _round_types() -> void:
	var teal := E.color_lab("teal")
	var off := teal + Vector3(0, 6, 0)
	var far := teal + Vector3(0, 40, 0)
	# CLASSIC: first close vs closest
	var sp := E.make_spec(E.T_CLASSIC, ["teal"])
	ok(sp.swatch and sp.taps == 1 and sp.countdown == 30.0 and sp.max_time == 90.0, "classic spec")
	var res := E.resolve(sp, [_li("A", 5, sp, [off]), _li("B", 9, sp, [teal]), _li("C", 2, sp, [far])])
	ok(_award(res, "first_close") == "A", "classic first close = A")
	ok(_award(res, "closest") == "B", "classic closest = B")
	ok(res.ranking == ["B", "A", "C"], "classic ranking %s" % str(res.ranking))
	ok(res.first_close_t == 5.0, "first close time")
	# nobody close: closest still awarded
	res = E.resolve(sp, [_li("A", 5, sp, [far]), _li("B", 9, sp, [far + Vector3(0, 5, 0)])])
	ok(_award(res, "first_close") == "" and _award(res, "closest") == "A", "closest without close")
	# flagged photo is out
	res = E.resolve(sp, [_li("A", 5, sp, [teal], true), _li("B", 9, sp, [off])])
	ok(_award(res, "closest") == "B" and _award(res, "first_close") == "B", "flagged out")
	ok(E.flag_majority(2, 3) and not E.flag_majority(1, 2) and not E.flag_majority(0, 0), "flag majority")
	# remote timer + deadline
	var rsp := E.make_spec(E.T_CLASSIC, ["teal"], {"place": "remote"})
	ok(rsp.max_time == 150.0, "remote max 150")
	ok(E.round_deadline(sp, 100.0, -1.0) == 190.0, "deadline without close")
	ok(E.round_deadline(sp, 100.0, 110.0) == 140.0, "deadline after first close")
	ok(E.round_deadline(sp, 100.0, 175.0) == 190.0, "countdown capped by max")
	# BLIND
	var bl := E.make_spec(E.T_BLIND, ["teal"])
	ok(not bl.swatch and bl.judge == "color", "blind no swatch")
	ok(E.score(bl, [teal]).de < 0.001, "blind scores like classic")
	# DUO: worse of two
	var duo := E.make_spec(E.T_DUO, ["teal", "red"])
	var red := E.color_lab("red")
	ok(duo.taps == 2 and duo.targets.size() == 2, "duo spec")
	var d := E.score(duo, [teal, red + Vector3(0, 0, 10)])
	near(d.de, E.de2000(red, red + Vector3(0, 0, 10)), 0.0001, "duo = worse dE")
	# MIX: Lab average
	var mix := E.make_spec(E.T_MIX, ["teal", "red"])
	ok(E.score(mix, [(teal + red) / 2.0]).de < 0.001, "mix target = average")
	# OPPOSITE
	var opp := E.make_spec(E.T_OPPOSITE, ["teal"])
	ok(E.score(opp, [E.opposite(teal)]).de < 0.001, "opposite target")
	ok(E.score(opp, [teal]).de > 20.0, "teal is far from its opposite")
	# SUPERLATIVE
	for kind in ["darkest", "lightest", "vivid"]:
		var su := E.make_spec(E.T_SUPERLATIVE, [], {"superlative": kind})
		ok(su.countdown == 0.0 and su.max_time == 60.0 and su.points.superlative == 2, "superlative spec")
		var grey := Vector3(50, 0, 0)
		var black := Vector3(10, 0, 0)
		var white := Vector3(95, 0, 0)
		var vivid := Vector3(50, 70, 50)
		var r2 := E.resolve(su, [_li("G", 1, su, [grey]), _li("K", 2, su, [black]), _li("W", 3, su, [white]), _li("V", 4, su, [vivid])])
		var want: String = {"darkest": "K", "lightest": "W", "vivid": "V"}[kind]
		ok(_award(r2, "superlative") == want, "superlative %s -> %s" % [kind, _award(r2, "superlative")])
		ok(_award(r2, "first_close") == "" and r2.awards.size() == 1, "superlative has no close award")
	# OBJECT: vote validity, first find, best find
	var ob := E.make_spec(E.T_OBJECT, [], {"prompt": "teacup"})
	ok(ob.judge == "vote" and ob.prompt == "teacup", "object spec")
	var lis := [
		{"player": "A", "t": 3.0, "yes": 1, "no": 2, "best_votes": 3},   # invalid
		{"player": "B", "t": 5.0, "yes": 2, "no": 2, "best_votes": 1},   # tie passes
		{"player": "C", "t": 8.0, "yes": 3, "no": 0, "best_votes": 2},
		{"player": "D", "t": 1.0, "yes": 3, "no": 0, "best_votes": 0, "flagged": true},
	]
	res = E.resolve(ob, lis)
	ok(_award(res, "first_find") == "B", "first find = earliest valid")
	ok(_award(res, "best_find") == "C", "best find = most votes among valid")
	# best find tie -> earlier
	lis[2].best_votes = 1
	ok(_award(E.resolve(ob, lis), "best_find") == "B", "best find tie -> earlier")


func _ties() -> void:
	var sp := E.make_spec(E.T_CLASSIC, ["teal"])
	var teal := E.color_lab("teal")
	var a := {"player": "A", "t": 9.0, "value": 3.0, "de": 3.0, "close": true}
	var b := {"player": "B", "t": 4.0, "value": 3.0, "de": 3.0, "close": true}
	var res := E.resolve(sp, [a, b])
	ok(_award(res, "closest") == "B", "equal dE -> earlier lock-in wins")
	ok(_award(res, "first_close") == "B", "first close = earliest")
	# superlative tie on value -> earlier
	var su := E.make_spec(E.T_SUPERLATIVE, [], {"superlative": "darkest"})
	res = E.resolve(su, [{"player": "X", "t": 7.0, "value": 10.0, "de": 0.0}, {"player": "Y", "t": 2.0, "value": 10.0, "de": 0.0}])
	ok(_award(res, "superlative") == "Y", "superlative tie -> earlier")
	var scores := E.add_awards({}, [{"player": "A", "points": 1}, {"player": "A", "points": 2}, {"player": "B", "points": 3}])
	ok(scores.A == 3 and scores.B == 3 and E.winners(scores).size() == 2, "scores + shared win")
	ok(teal != Vector3.ZERO, "teal lab")


func _plans() -> void:
	var counts := {}
	var total := 0
	for seed in 60:
		for sel in ["classic", "mixed", "chaos"]:
			var solo := seed % 2 == 0
			var plan := E.plan_match({"seed": seed, "selection": sel, "solo": solo, "objects": ["teacup", "spoon", "a circle"], "rounds": 10})
			ok(plan.size() == 10, "10 rounds")
			var seen := {}
			var labs := []
			var last := ""
			for sp in plan:
				if sel == "classic":
					ok(sp.type == E.T_CLASSIC, "classic only")
				elif sp.type != E.T_CLASSIC:
					ok(sp.type != last, "no twist twice in a row (%s)" % sp.type)
				if sel == "chaos":
					ok(sp.type != last, "chaos never repeats")
				if solo:
					ok(sp.type != E.T_OBJECT, "no object rounds solo")
				for id in sp.colors:
					ok(not seen.has(id), "no colour repeat %s" % id)
					seen[id] = true
					labs.append(E.color_lab(id))
				if sp.type in [E.T_MIX, E.T_OPPOSITE]:
					labs.append(E._lab(sp.targets[0]))
				last = sp.type
				if sel == "mixed" and not solo:
					counts[sp.type] = int(counts.get(sp.type, 0)) + 1
					total += 1
			for i in labs.size():
				for j in range(i + 1, labs.size()):
					ok(E.de2000(labs[i], labs[j], 1.0) >= E.MIN_SEPARATION, "targets apart (seed %d %s)" % [seed, sel])
	ok(E.plan_match({"seed": 5}) == E.plan_match({"seed": 5}), "plan deterministic per seed")
	var parts := []
	for k in counts:
		parts.append("%s %d%%" % [k, roundi(100.0 * counts[k] / total)])
	print("mixed multiplayer type mix: ", ", ".join(parts))


## Over the wire every state is JSON: test with that round trip.
func _wire(st: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(st))


func _lab_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _room() -> void:
	const R = preload("res://scripts/games/hue_hunt/hue_hunt_room.gd")
	var st := _wire(R.new_match({"rounds": 3}, [1, 2, 3], 7, 100.0))
	ok(st.phase == "round" and st.plan.size() == 3 and float(st.deadline) == 190.0, "room starts: local 90 s")
	var target := E._lab(R.spec(st).targets[0])
	var near := target + Vector3(0, 3, 0)
	var far := target + Vector3(0, 30, 0)
	ok(not R.lock_in(st, 9, [_lab_arr(target)], 101.0), "stranger can't lock in")
	ok(R.lock_in(st, 2, [_lab_arr(far)], 105.0), "P2 locks in (far)")
	ok(not R.lock_in(st, 2, [_lab_arr(target)], 106.0), "one lock-in per round")
	ok(float(st.first_close_t) < 0.0, "far is not close")
	ok(R.lock_in(st, 3, [_lab_arr(near)], 110.0), "P3 locks in (close)")
	ok(float(st.first_close_t) == 110.0 and float(st.deadline) == 140.0, "first close starts 30 s countdown")
	st = _wire(st)
	ok(not R.tick(st, [1, 2, 3], 120.0), "round goes on while P1 hunts")
	ok(R.tick(st, [2, 3], 121.0), "P1 gone: everyone present locked -> reveal")
	ok(st.phase == "reveal", "reveal phase")
	var aw := {}
	for a in st.awards:
		aw[a.award] = a.player
	ok(aw.get("first_close") == "3" and aw.get("closest") == "3", "P3 first close + closest: %s" % str(aw))
	ok(R.reveal_order(st) == ["2", "3"], "reveal worst first: %s" % str(R.reveal_order(st)))
	# flags: 2 of 2 other voters flag P3 -> out
	ok(not R.flag(st, 3, 3), "no self flag")
	ok(R.flag(st, 1, 3), "P1 flags P3")
	ok(not R.flag(st, 1, 3), "no double flag")
	ok(not R.flagged(st, 3), "1 of 2 is not a majority")
	ok(R.flag(st, 2, 3), "P2 flags P3")
	ok(R.flagged(st, 3), "2 of 2 flags P3")
	aw = {}
	for a in st.awards:
		aw[a.award] = a.player
	ok(aw.get("closest") == "2" and not aw.has("first_close"), "after flag: P2 closest, no first close: %s" % str(aw))
	ok(R.reveal_order(st)[0] == "3", "flagged first in reveal")
	st = _wire(st)
	ok(not R.tick(st, [1, 2, 3], 130.0), "reveal stays 25 s")
	ok(R.tick(st, [1, 2, 3], 121.0 + R.REVEAL_TIME), "reveal closes")
	ok(st.phase == "round" and int(st.round_i) == 1 and st.lockins.is_empty(), "round 2 starts clean")
	ok(int(st.scores["2"]) == 1 and int(st.scores["3"]) == 0, "points after flags: %s" % str(st.scores))
	# time-out round with no lock-ins, then the last round -> final
	ok(R.tick(st, [1, 2, 3], float(st.deadline)), "deadline ends round")
	ok(st.awards.is_empty(), "nobody locked: no awards")
	ok(R.end_reveal(st, 400.0) and int(st.round_i) == 2, "to round 3")
	var t3 := E._lab(R.spec(st).targets[0])
	R.lock_in(st, 1, [_lab_arr(t3)], 401.0)
	R.lock_in(st, 2, [_lab_arr(t3)], 402.0)
	ok(R.unlock(st, 2) and not st.lockins.has("2"), "second chance unlocks")
	ok(R.lock_in(st, 2, [_lab_arr(t3)], 403.0), "and locks again")
	ok(not R.lock_in(st, 3, [_lab_arr(t3)], float(st.deadline) + 1.0), "late lock-in refused")
	R.tick(st, [1, 2, 3], float(st.deadline))
	R.end_reveal(st, 999.0)
	ok(st.phase == "final", "final after last round")
	var stand := R.standings(st)
	ok(stand[0][0] == 1 and stand[0][1] == 2, "P1 wins on the equal-dE tie (earlier): %s" % str(stand))
	ok(R.acting_host([3, 2]) == 2 and R.acting_host([]) == 0, "acting host = lowest present seat")
	ok(int(st.ver) > 10, "ver counts changes")
	# remote timers
	var rs := R.new_match({"rounds": 1, "place": "remote"}, [1, 2], 1, 0.0)
	ok(float(rs.deadline) == 150.0, "remote round 150 s")
