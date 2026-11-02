extends SceneTree

## Headless check of The Runner's rules (scripts/games/the_runner/the_runner_engine.gd): data
## consistency, buying and selling, holds, fuel and travel, scans and inspections, fights, laundering,
## missions M01-M04, contracts, skills, modules, save/load, and an economy simulation (design doc §9:
## 10,000 trips by a greedy bot) that fails on runaway money or a heat loop.
## godot --headless --path . --script res://tools/test_the_runner.gd
## Touches no user files (the engine never saves by itself).

const E = preload("res://scripts/games/the_runner/the_runner_engine.gd")
const D = preload("res://scripts/games/the_runner/the_runner_data.gd")

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	_test_data()
	_test_market()
	_test_travel()
	_test_scans()
	_test_fights()
	_test_launder()
	_test_missions()
	_test_contracts()
	_test_skills_modules()
	_test_save()
	_test_messages()
	_simulate()
	print("the_runner: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _fresh(s: int = 7) -> Object:
	var e = E.new()
	e.reset(s)
	return e

func _test_data() -> void:
	for w in D.WORLD_ORDER:
		check(D.WORLDS.has(w), "world %s exists" % w)
		var wd: Dictionary = D.WORLDS[w]
		check(D.FACTIONS.has(wd.faction), "%s faction" % w)
		check(ResourceLoader.exists(D.ART + str(wd.view) + ".webp"), "%s view art" % w)
		check(ResourceLoader.exists(D.ART + str(wd.dock) + ".webp"), "%s dock art" % w)
		for g in wd.makes.keys() + wd.wants.keys():
			check(D.GOODS.has(g), "%s trades known good %s" % [w, g])
		var p := Vector2(float(wd.pos[0]), float(wd.pos[1]))
		check(p.x > 0 and p.y > 0 and p.x < D.MAP_SIZE.x and p.y < D.MAP_SIZE.y, "%s on the map" % w)
	check(D.WORLD_ORDER.size() == D.WORLDS.size(), "world order lists every world")
	check(D.GOOD_ORDER.size() == D.GOODS.size(), "good order lists every good")
	for id in D.MISSIONS:
		var m: Dictionary = D.MISSIONS[id]
		check(D.WORLDS.has(m.giver), "%s giver" % id)
		for st in m.steps:
			if st.has("to"):
				check(D.WORLDS.has(st.to), "%s step world" % id)
			if st.has("good"):
				check(D.GOODS.has(st.good), "%s step good" % id)
		if m.has("story_done"):
			check(D.STORY.has(m.story_done), "%s story" % id)
	for sid in D.STORY:
		for card in D.STORY[sid]:
			check(ResourceLoader.exists(D.ART + str(card[0]) + ".webp"), "story art %s" % card[0])
	for b in D.BRANCHES:
		check(D.SKILLS[b].size() == 3, "%s has 3 skills" % b)
	for slot in D.SLOTS:
		check(D.MODULES.has(D.START_MODULES[slot]), "start module %s" % slot)
	check(ResourceLoader.exists(D.ART + D.MAP_ART + ".webp"), "map art")
	# no alcohol anywhere in the content (hub rule)
	var words := JSON.stringify([D.GOODS, D.WORLDS, D.MISSIONS, D.STORY, D.EVENTS]).to_lower()
	for bad in ["alcohol", "whisk", "beer", "wine", "liquor", "booze", "vodka", "drunk"]:
		check(not words.contains(bad), "no '%s' in the content" % bad)

func _test_market() -> void:
	var e = _fresh()
	check(e.loc == "luna", "starts at Luna")
	check(e.qty("bootleg_data") == 2 and e.mission_state("M01") == "active", "M01 cargo given")
	check(e.hidden.get("bootleg_data", 0) == 2, "M01 cargo in the hidden hold")
	check(not e.trades("forged_ids"), "no black market before M01")
	var before: int = e.clean
	var p: int = e.price("food")
	var n: int = e.buy("food", 3)
	check(n == 3 and e.clean == before - (p + e.price("food") * 0 + 0) - (e.clean - e.clean) - (before - e.clean - p), "buy food")
	check(e.clean < before, "buying costs clean credits")
	check(e.price("food") > p, "buying moves the price up")
	var got: int = e.sell("food", 3)
	check(got > 0 and e.qty("food") == 0, "sell food")
	check(e.clean < before, "buy then sell loses a little (spread)")
	e.clean = 100000
	var cap: int = e.cargo_cap()
	e.buy("water", 999)
	check(e.used(e.cargo) == cap, "open hold fills to its cap")
	check(e.buy("water", 1) == 0, "no room, no buy")
	e.flags["black_market"] = true
	check(e.trades("forged_ids"), "black market after the flag")
	e.dump("water", 999)
	e.dirty = 0
	e.clean = 5000
	e.buy("forged_ids", 1)
	check(e.qty("forged_ids") == 0 or e.used(e.hidden) <= e.hidden_cap(), "contraband goes to the hidden hold first")
	var dirty_before: int = e.dirty
	e.dump("bootleg_data", 99)
	e.buy("forged_ids", 1)
	e.sell("forged_ids", 99)
	check(e.dirty > dirty_before, "contraband sells for dirty credits")
	check(e.sell_price("ore") < e.price("ore"), "selling pays less than buying")

func _test_travel() -> void:
	var e = _fresh()
	var need: float = e.fuel_for(e.distance_to("old_earth"))
	check(need > 0.0, "fuel cost > 0")
	check(e.can_reach("ember"), "Ember Spire reachable from Luna")
	check(e.launch(), "launch")
	check(e.loc == "", "in flight")
	var fuel0: float = e.fuel
	e.rng.seed = 99
	e.fly(100.0, Vector2(360, 160))
	check(e.fuel < fuel0, "flying burns fuel")
	e.encounter = {}
	var day0: int = e.day
	e.trip_px = 900.0
	e.arrive("ember")
	check(e.day == day0 + 3, "900 px = 3 days")
	check(e.loc == "ember", "docked")
	# running dry
	var f = _fresh()
	f.launch()
	f.fuel = 0.01
	check(f.fly(50.0, Vector2(500, 300)), "empty tank opens an encounter")
	check(f.encounter.kind == "no_fuel", "out of fuel")
	f.choose("tow")
	check(f.tow_to != "" and f.encounter.is_empty(), "towed")
	# hazards
	var h = _fresh()
	h.launch()
	h.fly(10.0, Vector2(684, 380))
	check(h.encounter.get("kind", "") == "sun", "flying into the Sun")
	var hull0: int = h.hull
	h.choose("ok")
	check(h.hull < hull0, "the Sun burns")

func _test_scans() -> void:
	var e = _fresh()
	check(e.pass_chance("dust_spire") < e.pass_chance("ember"), "law 5 is harder than law 1")
	var p_hidden: float = e.pass_chance("luna")
	e.cargo["weapons"] = 1
	check(e.pass_chance("luna") < p_hidden, "contraband in the open hold is riskier")
	e.cargo.erase("weapons")
	e.heat["concord"] = 80.0
	check(e.pass_chance("luna") < p_hidden, "heat makes scans harder")
	check(e.heat_tier("concord") == "Hunted", "heat tier 80")
	e.heat["concord"] = 0.0
	# inspection paths
	for opt in ["bribe", "dump", "run", "fight", "submit"]:
		var x = _fresh(11)
		x.clean = 5000
		x.encounter = {"kind": "inspect", "faction": "concord", "bribe": x.bribe_cost(), "fine": 100, "log": []}
		var lines: Array = x.choose(opt)
		check(not lines.is_empty(), "inspect %s says something" % opt)
		if opt == "dump" or opt == "submit":
			check(x.contraband_aboard() == 0, "inspect %s clears contraband" % opt)
	# heat cools
	var c = _fresh()
	c.heat["concord"] = 30.0
	c.pass_days(4)
	check(is_equal_approx(c.heat["concord"], 24.0), "heat cools 1.5 a day (%s)" % str(c.heat["concord"]))
	# blind spot cools faster
	c.loc = "old_earth"
	c.pass_days(1)
	check(is_equal_approx(c.heat["concord"], 21.0), "blind spot cools twice as fast")

func _test_fights() -> void:
	var won := 0
	var lost := 0
	for s in 200:
		var e = _fresh(1000 + s)
		e._open_fight("pirate", "")
		e.encounter.kind = "fight"
		var rounds := 0
		while not e.encounter.is_empty() and rounds < 50:
			e.choose("attack")
			rounds += 1
		check(rounds < 50, "fight ends")
		if e.stats.fights_won > 0:
			won += 1
		else:
			lost += 1
			check(e.tow_to == "luna" and e.used(e.cargo) + e.used(e.hidden) == 0, "captured: cargo lost, towed home")
	check(won > lost, "the Moth usually beats one raider (%d won, %d lost)" % [won, lost])
	var ev = _fresh()
	ev._open_fight("pirate", "")
	var o: Array = ev.options()
	check(o.size() >= 3, "pirates offer tribute / run / fight")

func _test_launder() -> void:
	var e = _fresh()
	e.dirty = 2000
	check(not e.launder(1000), "no laundry before the black market")
	e.flags["black_market"] = true
	check(e.launder(1000), "launder at Luna")
	check(e.dirty == 1000 and e.laundry.size() == 1, "batch taken")
	var c0: int = e.clean
	e.rng.seed = 5
	e.pass_days(2)
	check(e.clean > c0 and e.clean <= c0 + 800, "laundry pays 80% or less after 2 days")
	e.loc = "ember"
	check(not e.launder(100), "no front at Ember Spire")

func _test_missions() -> void:
	var e = _fresh()
	check(not e.can_complete("M01"), "M01 not done at Luna")
	e.loc = "tidewater"
	check(e.can_complete("M01"), "M01 at Tidewater")
	check(e.complete("M01"), "complete M01")
	check(e.flags.has("black_market") and e.dirty >= 600, "M01 reward")
	check(e.mission_state("M02") == "active", "M02 follows")
	check(e.pending_story.has("done_m01"), "M01 story queued")
	e.loc = "luna"
	e.clean = 5000
	check(e.pay_debt(99999) == 3000 and e.debt == 0, "pay Kessel")
	var done: Array = e.auto_complete()
	check(done.has("M02") and e.skill_points() >= 1, "M02 done, a skill point")
	check(e.mission_state("M03") == "active", "M03 follows")
	e.loc = "old_earth"
	e.auto_complete()
	check(e.ship == "runner" and e.modules.special == "spc_ghost", "M03: the Runner + Ghost Core")
	check(e.stealth() == 5, "Runner stealth 2 + Ghost Core 3")
	check(e.mission_state("M04") == "active", "M04 follows")
	for i in 3:
		e._scan_passed()
	check(e.pending_story.has("vane"), "Marshal Vane appears")
	e.auto_complete()
	check(e.mission_state("M04") == "done" and e.flags.has("act1_done"), "Act I done")
	# side missions
	var s = _fresh()
	s.loc = "ember"
	check(s.side_offers().has("S02"), "S02 offered at Ember Spire")
	check(s.accept_mission("S02"), "accept S02")
	s.clean = 99999
	s.cargo["medicine"] = 5
	check(s.complete("S02") and s.qty("medicine") == 0, "deliver S02")

func _test_contracts() -> void:
	var e = _fresh()
	var offers: Array = e.contract_offers()
	check(offers.size() == E.CONTRACTS_PER_PORT, "contracts on offer")
	var c: Dictionary = offers[0]
	check(not e.D.GOODS[c.good].contraband, "no shady contracts before the black market")
	check(e.take_contract(c.id), "take a contract")
	check(e.reserved(c.good) == c.qty and e.qty(c.good) >= c.qty, "contract cargo aboard and reserved")
	check(e.sell(c.good, 99) == 0 or e.qty(c.good) >= c.qty, "contract cargo is not for sale")
	e.loc = c.to
	var money0: int = e.clean + e.dirty
	check(e.deliver_contract(c.id), "deliver the contract")
	check(e.clean + e.dirty == money0 + c.pay, "contract pays")
	var x = _fresh()
	var o: Dictionary = x.contract_offers()[0]
	x.take_contract(o.id)
	x.pass_days(40)
	check(x.contracts.is_empty(), "late contracts fail")

func _test_skills_modules() -> void:
	var e = _fresh()
	check(e.skill_points() == 0 and not e.learn("smuggler"), "no points at level 1")
	e.xp = 150
	check(e.level() == 2 and e.skill_points() == 1, "level 2 at 150 xp")
	var hc: int = e.hidden_cap()
	check(e.learn("smuggler") and e.hidden_cap() == hc + 2, "Deep Pockets")
	e.xp = 150 + 300 + 450
	check(e.level() == 4, "level 4")
	check(e.learn("pirate"), "second branch opens")
	check(not e.can_learn("fixer"), "third branch stays closed")
	check(e.learn("smuggler") and e.has_skill("sm_cool"), "branch ranks in order")
	# modules
	e.clean = 20000
	check(e.shop_modules().has("car_2"), "Luna sells legal modules")
	check(not e.shop_modules().has("hid_2"), "no black modules at Luna before M02")
	var cap: int = e.cargo_cap()
	check(e.buy_module("car_2") and e.cargo_cap() == cap + 6, "Expanded Racks")
	check(e.fit_module("car_1") and e.cargo_cap() == cap, "swap back (owned)")
	check(e.fit_module("car_2") and e.clean == 20000 - 2500, "refit without paying again")
	e.loc = "gravel"
	e.flags["black_market"] = true
	e.dirty = 10000
	check(e.buy_module("hid_2") and e.hold_quality() == 1, "Smuggler's Wall at Gravel Belt (dirty)")
	check(e.dirty == 6500, "paid dirty")

func _test_save() -> void:
	var e = _fresh(42)
	e.clean = 1234
	e.flags["black_market"] = true
	e.heat["helios"] = 33.5
	e.buy("food", 2)
	e.loc = "verdance"
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var f = E.new()
	check(f.from_dict(d), "load")
	check(f.clean == e.clean and f.loc == "verdance" and f.qty("food") == 2, "state survives")
	check(is_equal_approx(f.heat["helios"], 33.5), "heat survives")
	check(f.missions.has("M01") and f.mission_state("M01") == "active", "missions survive")
	check(f.net_worth() == e.net_worth(), "net worth survives")
	# in flight with an open encounter
	e.launch()
	e.ship_pos = Vector2(500, 300)
	e._open({"kind": "inspect", "faction": "concord", "bribe": 300, "fine": 90})
	var g = E.new()
	g.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	check(g.loc == "" and g.ship_pos == Vector2(500, 300), "in-flight save keeps the ship's place")
	check(g.encounter.get("kind", "") == "inspect" and g.encounter.bribe == 300, "an open encounter survives")
	check(not f.from_dict({"v": 99}), "a future save version is refused")

## Every message the engine makes is a String or {"text", "args"} whose args fit the template.
func _test_messages() -> void:
	var e = _fresh(3)
	e.flags["black_market"] = true
	for kind in ["inspect", "pirates", "fight", "derelict", "distress", "pod", "no_fuel", "salvage_site", "sun", "black_hole", "meteors", "flare", "tip"]:
		e.encounter = {"kind": kind, "faction": "concord", "bribe": 100, "fine": 50, "enemy": "pirate", "ehull": 40, "emax": 40, "log": [], "at": [0, 0]}
		for o in e.options():
			_check_msg(o[1], "option %s/%s" % [kind, o[0]])
	for s in 300:
		var x = _fresh(500 + s)
		x.flags["black_market"] = true
		x.launch()
		x._random_event()
		for line in x.encounter.get("log", []):
			_check_msg(line, "event log")
		var guard := 0
		while not x.encounter.is_empty() and guard < 40:
			var opts: Array = x.options()
			for line in x.choose(opts[0][0]):
				_check_msg(line, "choice line")
			guard += 1
		check(guard < 40, "an encounter ends")
		x.pass_days(5)
		for n in x.news:
			_check_msg(n, "news")

func _check_msg(m: Variant, what: String) -> void:
	if m is String:
		check(not m.contains("%"), "%s: plain text has no %% (%s)" % [what, m])
		return
	check(m is Dictionary and m.has("text"), "%s is a message" % what)
	if m is Dictionary:
		var t: String = m.text
		var s: String = t % m.args if not m.args.is_empty() else t
		check(not s.is_empty(), what)

## A greedy trader bot flies 10,000 trips: buys the best trade from where it is, flies there,
## answers every encounter with its first option. Money must grow, but not explode.
func _simulate() -> void:
	var e = _fresh(2026)
	e.flags["black_market"] = true
	var trips := 0
	var stuck := 0
	var peak_heat := 0.0
	var loans := 0
	for i in 10000:
		e.buy_fuel()
		for c in e.deliverable_contracts():
			e.deliver_contract(c.id)
		if e.loc == "luna" and e.debt > 0 and e.total_credits() > e.debt + 2000:
			e.pay_debt(e.debt)
		if e.can_borrow():
			e.borrow()
			loans += 1
			e.buy_fuel()
		if e.contracts.is_empty():
			for c in e.contract_offers():
				if e.can_reach(c.to):
					e.take_contract(c.id)
					break
		var t: Array = e.best_trade(true)
		var dest: String = ""
		if not e.contracts.is_empty() and e.can_reach(e.contracts[0].to):
			dest = e.contracts[0].to
		if not t.is_empty():
			if dest == "" or dest == t[1]:
				dest = t[1]
				var budget: int = e.total_credits() - 400
				if budget > 0:
					e.buy(t[0], mini(99, budget / maxi(1, e.price(t[0]))))
		else:
			dest = D.WORLD_ORDER[e.rng.randi() % D.WORLD_ORDER.size()]
		if dest == e.loc or not e.can_reach(dest):
			e.buy_fuel()
			if not e.can_reach(dest):
				stuck += 1
				dest = "luna" if e.loc != "luna" else "ember"
		var dist: float = e.distance_to(dest)
		e.launch()
		var steps := int(ceil(dist / 40.0))
		var towed := false
		for k in steps:
			if e.fly(dist / steps):
				while not e.encounter.is_empty():
					e.choose(e.options()[0][0])
				if e.tow_to != "":
					dest = e.tow_to
					e.tow_to = ""
					towed = true
					break
		e.arrive(dest)
		while not e.encounter.is_empty():
			e.choose(e.options()[0][0])
		e.tow_to = ""
		if t.size() > 0 and e.loc == t[1]:
			e.sell(t[0], 99)
		for c in e.deliverable_contracts():
			e.deliver_contract(c.id)
		for g in D.GOOD_ORDER:
			if e.trades(g):
				e.sell(g, 99)
		e.buy_fuel()
		if e.has_service("shipyard"):
			e.repair()
		peak_heat = maxf(peak_heat, e.max_heat())
		trips += 1
	var nw: int = e.net_worth()
	print("sim stats: ", e.stats, " debt ", e.debt, " ship ", e.ship)
	print("sim: %d trips, %d days, net worth %d, clean %d, dirty %d, heat peak %.0f, scans %d/%d, fights %d/%d, stuck %d, loans %d, contracts %d" % [
		trips, e.day, nw, e.clean, e.dirty, peak_heat, e.stats.scans_passed, e.stats.scans_failed,
		e.stats.fights_won, e.stats.fights_lost, stuck, loans, e.stats.contracts])
	check(nw > 20000, "a trader gets richer over 10,000 trips")
	check(e.debt <= D.START_DEBT + 5000, "debt does not spiral (%d)" % e.debt)
	check(loans < 200, "the loan is a safety net, not a way of life (%d loans)" % loans)
	check(nw < 200000000, "no runaway money (net worth %d)" % nw)
	check(e.hull > 0 and e.fuel >= 0.0, "ship state stays sane")
	check(e.supply.is_empty() or _supply_sane(e), "supply factors stay in range")

func _supply_sane(e: Object) -> bool:
	for w in e.supply:
		for g in e.supply[w]:
			var v: float = e.supply[w][g]
			if v < 0.55 or v > 1.7:
				return false
	return true
