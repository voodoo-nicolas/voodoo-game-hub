extends SceneTree

## Headless check of The Runner's rules (design doc v2): data consistency (races, perks, factions,
## crew, quests, sectors, art), the perk engine (stacking, caps, flaws), faction rep and the two
## bars, quests (story chain, choices, picks, battles), crew (gates, clash, wages), hull tiers and
## parts, travel between sectors and flight time, scans, real-time battles (the sim, headless),
## save/load, every message's format, and an economy simulation (10,000 trips by a greedy bot that
## fights its battles with the sim's autopilot) that fails on runaway money or a debt spiral.
## godot --headless --path . --script res://tools/test_the_runner.gd
## Touches no user files (the engine never saves by itself).

const E = preload("res://scripts/games/the_runner/the_runner_engine.gd")
const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const S = preload("res://scripts/games/the_runner/the_runner_spiral.gd")
const B = preload("res://scripts/games/the_runner/the_runner_battle.gd")

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	_test_data()
	_test_perks()
	_test_factions()
	_test_market()
	_test_travel()
	_test_scans()
	_test_battles()
	_test_launder()
	_test_quests()
	_test_expansion()
	_test_crew()
	_test_contracts()
	_test_skills_modules()
	_test_save()
	_test_messages()
	_simulate()
	print("the_runner: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _fresh(s: int = 7, cap: Dictionary = {}) -> Object:
	var e = E.new()
	e.reset(s, cap)
	return e

## Runs the open battle with the sim's autopilot and hands the result to the engine.
func _fight(e: Object, seed_v: int = 1) -> String:
	if e.encounter.get("kind", "") == "battle_offer":
		e.choose("fight")
	if e.encounter.get("kind", "") != "battle":
		return ""
	var b = B.new()
	b.setup(e.battle_player(), e.battle_enemies(), seed_v)
	var t := 0
	while b.outcome == "" and t < 30 * 240:
		b.tick(1.0 / 30.0, b.autopilot_move())
		t += 1
	var out: String = b.outcome if b.outcome != "" else "fled"
	e.end_battle(out, b.result_info())
	return out

func _test_data() -> void:
	check(S.GOOD_PERKS.size() == 31, "31 good perks")
	check(S.FLAWS.size() == 15, "15 flaws")
	check(S.PERKS.size() == 46, "46 perks in all")
	var playable := 0
	for r in S.RACE_ORDER:
		var rd: Dictionary = S.RACES[r]
		if rd.playable:
			playable += 1
		check(rd.perks.size() == 2 and S.PERKS[rd.perks[0]].kind == "good" and S.PERKS[rd.perks[1]].kind == "good", "%s has 2 good perks" % r)
		check(S.PERKS[rd.flaw].kind == "flaw", "%s flaw" % r)
		for h in rd.hostile:
			check(S.RACES[h].hostile.has(r), "hostility %s-%s goes both ways" % [r, h])
		for f in rd.homes:
			check(S.FACTIONS.has(f), "%s home faction %s" % [r, f])
	check(playable == 8 and not S.RACES.sskarn.playable, "8 playable races, Sskarn NPC only")
	check(S.ACCORD.size() == 6 and S.PACT.size() == 4 and S.FACTION_ORDER.size() == 11, "6 Accord + 4 Pact + Hunt-Guilds")
	for f in S.FACTION_ORDER:
		var fd: Dictionary = S.FACTIONS[f]
		check(fd.bonuses.has("50") and fd.bonuses.has("75") and fd.bonuses.has("100"), "%s has 50/75/100 bonuses" % f)
		check(D.WORLDS.has(fd.home), "%s home world" % f)
		for t in fd.bonuses:
			var p := str(fd.bonuses[t].fx.get("perk", ""))
			check(p == "" or S.PERKS.has(p), "%s free perk" % f)
			var a := str(fd.bonuses[t].fx.get("ability", ""))
			check(a == "" or S.ABILITIES.has(a), "%s ability %s" % [f, a])
	check(S.CREW.size() == 16, "16 crew")
	for c in S.CREW_ORDER:
		var cd: Dictionary = S.CREW[c]
		var rd: Dictionary = S.RACES[cd.race]
		check(rd.perks.has(cd.racial), "%s racial perk is one of the race's" % c)
		check(S.PERKS[cd.personal].kind == "good", "%s personal perk" % c)
		check(cd.quirk == rd.flaw, "%s quirk = race flaw" % c)
		check(D.WORLDS.has(cd.planet), "%s planet" % c)
		check(S.QUESTS.has(c) and S.QUESTS[c].recruit == c and S.QUESTS[c].giver == cd.planet, "%s discovery quest at their planet" % c)
	check(S.QUEST_ORDER.size() == S.QUESTS.size(), "quest order lists every quest")
	for id in S.QUESTS:
		var q: Dictionary = S.QUESTS[id]
		check(D.WORLDS.has(q.giver) or (q.giver == "any" and q.has("crew")), "%s giver" % id)
		var st: Dictionary = q.step
		if st.type == "tour":
			check(st.to.size() >= 2 and st.to.all(func(w): return D.WORLDS.has(w)), "%s tour worlds" % id)
		elif st.type == "jump":
			check(D.SECTORS.has(st.to), "%s jump sector" % id)
		elif st.has("to"):
			check(D.WORLDS.has(st.to), "%s step world" % id)
		if st.has("good"):
			check(D.GOODS.has(st.good), "%s step good" % id)
		if st.has("enemy"):
			check(D.ENEMIES.has(st.enemy), "%s enemy" % id)
		for f in q.get("faction", {}):
			check(S.FACTIONS.has(f), "%s faction %s" % [id, f])
		for c in q.get("choices", []):
			for f in c.get("faction", {}):
				check(S.FACTIONS.has(f), "%s choice faction %s" % [id, f])
		if q.has("story"):
			check(D.STORY.has(q.story), "%s story" % id)
	# capstones: +150 to every faction of the bloc
	for f in S.ACCORD:
		check(int(S.QUESTS.P14.faction[f]) == 150, "P14 +150 %s" % f)
	for f in S.PACT:
		check(int(S.QUESTS.O14.faction[f]) == 150, "O14 +150 %s" % f)
	# planets and sectors (§9: 5 + 6 + 8 + 3 = 22)
	var count := {}
	for w in D.WORLD_ORDER:
		check(D.WORLDS.has(w), "world %s exists" % w)
		var wd: Dictionary = D.WORLDS[w]
		count[wd.sector] = int(count.get(wd.sector, 0)) + 1
		check(S.FACTIONS.has(wd.faction), "%s faction" % w)
		check(ResourceLoader.exists(D.ART + str(wd.view) + ".webp"), "%s view art" % w)
		check(ResourceLoader.exists(D.ART + str(wd.dock) + ".webp"), "%s dock art" % w)
		for g in wd.makes.keys() + wd.wants.keys():
			check(D.GOODS.has(g), "%s trades known good %s" % [w, g])
		var z: Array = D.SECTORS[wd.sector].size
		check(float(wd.pos[0]) > 0 and float(wd.pos[1]) > 0 and float(wd.pos[0]) < float(z[0]) and float(wd.pos[1]) < float(z[1]), "%s on its map" % w)
	check(count.get("cradle_reach", 0) == 5 and count.get("veil_expanse", 0) == 6 and count.get("ember_drift", 0) == 8 and count.get("hollow_deep", 0) == 3, "5 / 6 / 8 / 3 planets")
	check(D.WORLD_ORDER.size() == 22, "22 planets in all")
	for s in D.SECTOR_ORDER:
		check(ResourceLoader.exists(D.ART + str(D.SECTORS[s].map) + ".webp"), "%s map art" % s)
	check(D.WORLD_ORDER.size() == D.WORLDS.size(), "world order lists every world")
	check(D.GOOD_ORDER.size() == D.GOODS.size(), "good order lists every good")
	for sid in D.STORY:
		for card in D.STORY[sid]:
			check(ResourceLoader.exists(D.ART + str(card[0]) + ".webp"), "story art %s" % card[0])
	for b in D.BRANCHES:
		check(D.SKILLS[b].size() == 3, "%s has 3 skills" % b)
	for slot in D.SLOTS:
		check(D.MODULES.has(D.START_MODULES[slot]), "start module %s" % slot)
	check(D.TIERS.size() == 4 and int(D.TIERS[1].cost) == 25000 and int(D.TIERS[2].cost) == 150000 and int(D.TIERS[3].cost) == 1000000, "hull tier costs")
	for t in 4:
		check(int(D.TIERS[t].crew) == t + 1, "tier %d crew slots" % (t + 1))
	for id in D.ENEMIES:
		check(ResourceLoader.exists("res://media/common/sprites/" + str(D.ENEMIES[id].sprite) + ".png"), "%s sprite" % id)
	# no alcohol anywhere in the content (hub rule)
	var words := JSON.stringify([D.GOODS, D.WORLDS, D.STORY, D.EVENTS, S.QUESTS, S.CREW, S.RACES, S.FACTIONS]).to_lower()
	for bad in ["alcohol", "whisk", "beer", "wine", "liquor", "booze", "vodka", "drunk"]:
		check(not words.contains(bad), "no '%s' in the content" % bad)

func _test_perks() -> void:
	var t = _fresh(1, {"race": "terran", "picks": ["G09", "G16"]})
	check(is_equal_approx(t.stat("mission_credits"), 0.10), "Terran: Master Negotiator")
	check(is_equal_approx(t.stat("crew_wages"), 0.20), "Terran: Needs Upkeep")
	check(is_equal_approx(t.stat("sell_price"), 0.10) and is_equal_approx(t.stat("buy_price"), -0.10), "Haggler pick")
	check(is_equal_approx(t.stat("cargo_cap"), 0.15), "Quartermaster pick")
	check(t.cargo_cap() == int(round(8 * 1.15)), "cargo cap with Quartermaster")
	# stacking: the same perk twice = 150%, a third adds nothing
	var k = _fresh(1, {"race": "kestrai", "picks": ["G03", "G13"]})
	check(is_equal_approx(k.stat("speed"), 0.15 * 1.5), "Pilot twice = +22.5% speed")
	check(is_equal_approx(k.stat("hull"), 0.20 - 0.15), "Iron Hull pick + Brittle")
	k.crew.append({"id": "C15", "loyalty": 60})   # Rook: Pilot again
	k._invalidate()
	check(is_equal_approx(k.stat("speed"), 0.15 * 1.5), "a third Pilot adds nothing")
	# the +60% cap
	var c = _fresh(1, {"race": "kestrai", "picks": ["G24", "G03"]})
	c.rep["high_aerie"] = 1000
	c._invalidate()
	check(c.stat("evasion") <= S.GOOD_CAP + 0.0001, "evasion capped at +60%% (%s)" % c.stat("evasion"))
	check(c.perk_list().any(func(p): return p[0] == "G24" and p[2] == "high_aerie"), "Aerie 100% gives Dodge Master")
	# crew quirks at half strength
	var q = _fresh(1, {"race": "terran", "picks": ["G09", "G16"]})
	q.crew.append({"id": "C01", "loyalty": 60})
	q._invalidate()
	check(is_equal_approx(q.stat("crew_loyalty"), -0.20 * 0.5), "Pip's Cold Logic at 50%")
	check(is_equal_approx(q.stat("salvage"), 0.30), "Pip's Cargo Scrapper")
	# flaws cap at -40%
	var f = _fresh(1, {"race": "kestrai"})
	f.curses["B01"] = 99
	f.crew.append({"id": "C04", "loyalty": 60})
	f._invalidate()
	check(f.stat("hull") >= -S.FLAW_CAP - 0.0001, "flaws cap at -40%% (%s)" % f.stat("hull"))
	# Sskarn can't be picked
	var s = _fresh(1, {"race": "sskarn"})
	check(s.captain.race == "terran", "Sskarn is NPC only")
	var h = _fresh(1, {"race": "ssaryn", "home": "ashscale_warbands"})
	check(h.rep_of("ashscale_warbands") == 100 and h.rep_of("sunscale_covenant") == 0, "start at 10% with the chosen home")

func _test_factions() -> void:
	var e = _fresh()
	check(e.rep_of("terran_concord") == 100 and e.rep_pct("terran_concord") == 10, "10% = 100 FP")
	var p0: int = e.price("food")
	e.rep["terran_concord"] = 500
	e._invalidate()
	check(e.price("food") < p0, "50% rep: discount at Concord ports")
	e.rep["terran_concord"] = -100
	check(e.price("food") > p0, "below 0: +20% prices")
	check(not e.quest_offers().any(func(o): return o[1].is_empty() and S.QUESTS[o[0]].kind == "paragon"), "below 0: no faction quests")
	e.rep["terran_concord"] = -300
	check(e.port_closed() and not e.has_service("market") and e.has_service("fuel"), "below -25%: port closed (fuel still sells)")
	e.rep["terran_concord"] = 0
	check(e.add_rep("terran_concord", 2000) == 1000, "rep caps at 100%")
	check(e.add_rep("terran_concord", -5000) == -1500, "rep floors at -50%")
	check(e.add_rep("none", 50) == 0, "independents have no rep")
	# Charismatic
	var c = _fresh(1, {"race": "terran", "picks": ["G20", "G09"]})
	check(c.add_rep("synthesis", 100) == 110, "Charismatic: +10% FP")
	check(c.add_rep("synthesis", -100) == -100, "Charismatic doesn't soften losses")
	# rep repair
	var r = _fresh()
	r.clean = 10000
	check(r.can_buy_rep("terran_concord") and r.buy_rep("terran_concord") and r.rep_of("terran_concord") == 200, "buy +10% rep for 1,000")
	r.rep["terran_concord"] = 450
	check(not r.can_buy_rep("terran_concord"), "rep can't be bought past 50%")
	check(not r.can_buy_rep("synthesis"), "rep is bought at the faction's own office")
	# bonuses
	var b = _fresh()
	b.rep["synthesis"] = 1000
	b._invalidate()
	check(b.perk_list().any(func(p): return p[0] == "G18"), "Synthesis 100%: free Hacker")
	check(b.stat("hull_regen") > 0.0, "Node Link regen")
	b.rep["synthesis"] = 900
	b._invalidate()
	check(not b.perk_list().any(func(p): return p[0] == "G18" and p[2] == "synthesis"), "bonus lost when rep drops")
	var m = _fresh()
	m.rep["black_meridian"] = 990
	m.add_rep("black_meridian", 10)
	check(m.debt == 0, "Syndicate Seat clears debts")
	var t = _fresh()
	t.rep["terran_concord"] = 750
	t._invalidate()
	check(t.calls().has("escort_wing"), "Concord 75%: escort wing")
	# bars
	var a = _fresh()
	a.add_bar("paragon", 12)
	a.add_bar("outlaw", 4)
	check(a.bars.paragon == 12 and a.bars.outlaw == 4, "two independent bars")
	check(a.title_of("paragon") == "Respected", "Paragon 10: Respected")
	a.add_bar("paragon", 500)
	check(a.bars.paragon == 100, "bars cap at 100")
	check(a.calls().has("allied_fleet"), "Paragon 75: allied fleet")
	check(a.flag("unify"), "Paragon 100: Unify the Spiral unlocked")
	a.add_bar("outlaw", 6)
	check(a.black_market_open("frostline") == false, "black market still needs the flag")
	a.flags["black_market"] = true
	check(a.black_market_open("frostline"), "Notorious: black market everywhere")

func _test_market() -> void:
	var e = _fresh()
	check(e.loc == "cradle_station", "starts at Cradle Station")
	check(e.qty("food") == 3 and e.quest_state("N01") == "active", "N01 cargo given")
	check(not e.trades("forged_ids"), "no black market before N01")
	var before: int = e.clean
	var p: int = e.price("water")
	check(e.buy("water", 3) == 3 and e.clean < before, "buy water")
	check(e.price("water") > p, "buying moves the price up")
	check(e.sell("water", 3) > 0 and e.qty("water") == 0, "sell water")
	check(e.sell("food", 3) == 0 and e.qty("food") == 3, "quest cargo is not for sale")
	e.clean = 100000
	var cap: int = e.cargo_cap()
	e.buy("water", 999)
	check(e.used(e.cargo) == cap, "open hold fills to its cap")
	check(e.buy("water", 1) == 0, "no room, no buy")
	e.flags["black_market"] = true
	check(e.trades("forged_ids"), "black market after the flag")
	e.dump("water", 999)
	var dirty_before: int = e.dirty
	e.buy("forged_ids", 1)
	check(e.hidden.get("forged_ids", 0) == 1, "contraband goes to the hidden hold first")
	e.sell("forged_ids", 99)
	check(e.dirty > dirty_before - 1, "contraband sells for dirty credits")
	check(e.sell_price("ore") < e.price("ore"), "selling pays less than buying")

func _test_travel() -> void:
	var e = _fresh()
	check(e.can_reach("frostline"), "Frostline reachable from Cradle Station")
	check(not e.can_reach("aerie_spire"), "other sectors aren't reachable by flight")
	var t1: float = e.flight_seconds(e.distance_to("port_vermillion"))
	var t2: float = e.flight_seconds(e.distance_to("brass_garden"))
	check(t1 >= 19.9 and t1 <= 45.0 and t2 > t1, "flight time 20-45 s, farther = longer (%.1f, %.1f)" % [t1, t2])
	var k = _fresh(1, {"race": "kestrai"})
	check(k.flight_seconds(300.0) < e.flight_seconds(300.0), "Pilot flies faster")
	check(e.launch() and e.loc == "", "launch")
	var fuel0: float = e.fuel
	e.fly(100.0, Vector2(330, 160))
	check(e.fuel < fuel0, "flying burns fuel")
	e.encounter = {}
	var day0: int = e.day
	e.trip_px = 900.0
	e.arrive("frostline")
	while not e.encounter.is_empty():
		if e.encounter.kind == "battle" or e.encounter.kind == "battle_offer":
			_fight(e)
		else:
			e.choose(e.options()[0][0])
	check(e.day == day0 + 3, "900 px = 3 days")
	check(e.loc == "frostline", "docked")
	# gates
	var g = _fresh()
	g.launch()
	g.ship_pos = g.gate_pos()
	check(g.at_gate(), "at the gate")
	check(not g.jump("veil_expanse"), "the Veil Expanse is shut before the Rift Key")
	g.flags["rift_key"] = true
	check(g.jump("veil_expanse") and g.sector == "veil_expanse", "jump to the Veil Expanse")
	check(g.worlds_in(g.sector).has("aerie_spire") and g.ship_pos == g.gate_pos(), "arrive at the Veil Expanse's gate")
	check(not g.sector_open("hollow_deep"), "the Hollow Deep stays locked")
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
	check(h.encounter.get("kind", "") == "sun", "flying into the star")
	var hull0: int = h.hull
	h.choose("ok")
	check(h.hull < hull0, "the star burns")

func _test_scans() -> void:
	var e = _fresh()
	check(e.pass_chance("frostline") < e.pass_chance("port_vermillion"), "law 4 is harder than law 1")
	var p_hidden: float = e.pass_chance("cradle_station")
	e.cargo["weapons"] = 1
	check(e.pass_chance("cradle_station") < p_hidden, "contraband in the open hold is riskier")
	e.cargo.erase("weapons")
	var n = _fresh(1, {"race": "noctari"})
	check(n.pass_chance("cradle_station") > p_hidden, "Stealthy Noctari pass more scans")
	e.heat["accord"] = 80.0
	check(e.pass_chance("cradle_station") < p_hidden, "heat makes scans harder")
	check(e.heat_tier() == "Hunted", "heat tier 80")
	check(e.scan_chance("meridian_station") == 0.0, "no Accord scans in Pact ports")
	e.heat["accord"] = 0.0
	for opt in ["bribe", "bluff", "dump", "run", "fight", "submit"]:
		var x = _fresh(11)
		x.clean = 5000
		x.encounter = {"kind": "inspect", "faction": "accord", "bribe": x.bribe_cost(), "fine": 100, "log": []}
		var lines: Array = x.choose(opt)
		check(not lines.is_empty(), "inspect %s says something" % opt)
	var c = _fresh()
	c.heat["accord"] = 30.0
	c.pass_days(4)
	check(is_equal_approx(c.heat["accord"], 24.0), "heat cools 1.5 a day (%s)" % str(c.heat["accord"]))
	c.loc = "scrapyard_gamma"
	c.pass_days(1)
	check(is_equal_approx(c.heat["accord"], 21.0), "blind spot cools twice as fast")
	var m = _fresh(1, {"race": "mycelari"})
	m.add_heat("accord", 10)
	check(is_equal_approx(m.heat_of(), 11.5), "Marked: +15% heat")

func _test_battles() -> void:
	var won := 0
	var runs := 200
	for s in runs:
		var e = _fresh(1000 + s)
		e._open_battle("pirate", "")
		var o := _fight(e, s + 1)
		if o in ["won", "boarded"]:
			won += 1
		elif o == "lost":
			check(e.tow_to == "cradle_station" and e.used(e.cargo) + e.used(e.hidden) == 0, "captured: cargo lost, towed home")
	check(won > runs * 0.6, "the Moth usually beats one raider (%d of %d)" % [won, runs])
	var lost := 0
	for s in 100:
		var e = _fresh(3000 + s)
		e._open_battle("accord_cruiser", "")
		if _fight(e, s + 7) in ["lost", "fled"]:
			lost += 1
	check(lost > 80, "a Moth can't take an Accord cruiser (%d of 100 lost or fled)" % lost)
	# a refitted Runner with crew beats the capstone war-wing more often than not
	var wins := 0
	for s in 60:
		var e = _fresh(5000 + s, {"race": "ssaryn", "home": "sunscale_covenant", "picks": ["G07", "G12"]})
		e.ship = "runner"
		e.tier = 4
		e.modules.weapons = "wpn_3"
		e.modules.shields = "shd_3"
		e.hull = e.max_hull()
		e._invalidate()
		e._open_battle("ashscale_armada", "")
		if _fight(e, s + 3) in ["won", "boarded"]:
			wins += 1
	check(wins > 30, "a Cruiser with good parts beats the war-wing (%d of 60)" % wins)
	# duels don't kill
	var d = _fresh()
	d.hull = 5
	d._open_battle("duelist", "")
	var od := _fight(d, 9)
	check(od in ["duel_lost", "won"] and d.hull >= 1 and d.tow_to == "", "a duel never captures you (%s)" % od)
	# abilities
	var b = B.new()
	var p := {"hull": 100, "max_hull": 100, "shield": 20, "guns": 2, "dmg": 6.0, "cd": 1.1, "acc": 0.7, "eva": 0.1,
		"speed": 230.0, "shield_regen": 4.0, "flee": 1.0, "boarding": 0.5, "hack": true, "calls": ["wingmates", "shadow_cloak"]}
	b.setup(p, [{"hull": 60, "shield": 0, "guns": 1, "dmg": 6.0, "acc": 0.6, "eva": 0.1, "speed": 150.0, "board": true}], 4)
	check(b.use("hack") and b.foes[0].hacked > 0.0 and not b.ready("hack"), "hack once per battle")
	check(b.use("wingmates") and b.allies.size() == 2 and not b.ready("wingmates"), "wingmates once")
	check(b.use("flee") and b.flee_t > 0.0, "flee charges")
	for i in 120:
		b.tick(1.0 / 30.0)
	check(b.outcome == "fled", "flee with 100% chance escapes")
	var c = B.new()
	c.setup(p, [{"hull": 60, "shield": 0, "guns": 1, "dmg": 6.0, "acc": 0.6, "eva": 0.1, "speed": 150.0}], 4)
	check(c.use("shadow_cloak") and c.outcome == "cloaked", "Shadow Cloak vanishes")
	var e2 = _fresh()
	e2.rep["veilbound"] = 1000
	e2._invalidate()
	e2._open_battle("pirate", "")
	e2.end_battle("cloaked", {"hull": 50, "used_calls": ["shadow_cloak"]})
	check(not e2.call_ready("shadow_cloak"), "a call is gone for the rest of the run")

func _test_launder() -> void:
	var e = _fresh()
	e.dirty = 2000
	check(not e.launder(1000), "no laundry before the black market")
	e.flags["black_market"] = true
	check(e.launder(1000), "launder at Cradle Station")
	check(e.dirty == 1000 and e.laundry.size() == 1, "batch taken")
	var c0: int = e.clean
	e.rng.seed = 5
	e.pass_days(2)
	check(e.clean > c0 and e.clean <= c0 + 800, "laundry pays 80% or less after 2 days")
	e.loc = "frostline"
	check(not e.launder(100), "no front at Frostline")
	var f = _fresh(1, {"race": "terran", "picks": ["G27", "G09"]})
	check(f.launder_rate() > e.launder_rate(), "Fence Contact: lower laundering fee")

func _test_quests() -> void:
	var e = _fresh()
	check(not e.can_complete("N01"), "N01 not done at Cradle Station")
	e.loc = "frostline"
	check(e.can_complete("N01"), "N01 at Frostline")
	check(not e.complete("N01").is_empty(), "complete N01")
	check(e.flags.has("black_market") and e.qty("food") == 0, "N01 reward + cargo handed over")
	check(e.quest_state("N02") == "active", "N02 follows")
	e.loc = "cradle_station"
	e.clean = 5000
	check(e.pay_debt(99999) == 3000 and e.debt == 0, "pay Kessel's collector")
	var done: Array = e.auto_complete()
	check(done.has("N02") and e.skill_points() >= 1 and e.rep_of("black_meridian") >= 50, "N02 done: a skill point, Meridian +50")
	e.loc = "scrapyard_gamma"
	e.auto_complete()
	check(e.ship == "runner" and e.tier == 1 and e.stealth() == 5, "N03: the Runner, Skiff + Ghost Core")
	for i in 3:
		e._scan_passed()
	check(e.pending_story.has("vane"), "Marshal Vane appears")
	e.auto_complete()
	check(e.quest_state("N04") == "done" and e.quest_state("N10") == "active" and not e.flags.has("act1_done"), "N04 done, Marrow's Cache next (Act I ends at N12)")
	# crew quest C01: salvage three times, Pip joins
	check(e.quest_offers().any(func(o): return o[0] == "C01" and o[1].is_empty()), "C01 offered at Scrapyard Gamma")
	check(e.accept_quest("C01"), "accept C01")
	for i in 3:
		e.start_salvage()
		e.choose("salvage")
		while not e.encounter.is_empty():
			if e.encounter.kind == "battle":
				_fight(e)
			else:
				e.choose(e.options()[0][0])
	e.auto_complete()
	check(e.quest_state("C01") == "done" and not e.crew_member("C01").is_empty(), "C01: Pip joins")
	check(e.quest_offers().any(func(o): return o[0] == "N06"), "N06 appears after C01")
	# faction gate: Paragon quests need 10% rep
	var g = _fresh(1, {"race": "noctari"})
	var p01: Array = g.quest_offers().filter(func(o): return o[0] == "P01")
	check(not p01.is_empty() and not p01[0][1].is_empty(), "P01 needs 10% Concord rep")
	g.rep["terran_concord"] = 100
	check(g.quest_block("P01").is_empty(), "P01 opens at 10%")
	# quest slots
	g.rep["terran_concord"] = 300
	g.accept_quest("P01")
	g.accept_quest("P10")
	g.accept_quest("P13")
	check(g.side_active() == 3 and not g.quest_block("F02").is_empty(), "3 quest slots")
	var cb = _fresh(1, {"race": "terran", "picks": ["G31", "G09"]})
	check(cb.quest_slots() == 4, "Contract Broker: +1 slot")
	# explicit deltas only: a Paragon quest touches only the factions it lists
	var x = _fresh()
	x.rep["terran_concord"] = 200
	x.accept_quest("P13")
	x.loc = "meridian_station"
	var before: Dictionary = x.rep.duplicate()
	x.complete("P13")
	for f in S.FACTION_ORDER:
		if f != "terran_concord" and f != "black_meridian":
			check(x.rep[f] == before[f], "P13 leaves %s alone" % f)
	check(x.rep.terran_concord == 350 and x.rep.black_meridian == -100 and x.bars.paragon == 1, "P13 deltas + PP")
	# choices (§11.5)
	var y = _fresh()
	y.rep["verdant_canopy"] = 100
	y.loc = "brass_garden"
	check(y.accept_quest("P12"), "accept Famine Relief")
	y.loc = "frostline"
	y.cargo["food"] = 6
	check(y.needs_hand_in("P12") and y.complete("P12").is_empty(), "a choice is needed")
	var d0: int = y.dirty
	check(not y.complete("P12", 1).is_empty() and y.bars.outlaw == 1 and y.rep.verdant_canopy == 0 and y.dirty > d0, "3x markup: Outlaw +1, Verdant -100")
	# picks
	var z = _fresh()
	z.clean = 9000
	check(z.accept_quest("F02"), "accept Peace Offering")
	check(z.complete("F02", -1, "nobody").is_empty(), "a faction must be picked")
	check(not z.complete("F02", -1, "bloom").is_empty() and z.rep.bloom == 100 and z.clean == 7000, "Peace Offering: pay 2,000, Bloom +100")
	# battle quests
	var w = _fresh()
	w.rep["terran_concord"] = 200
	w.accept_quest("P02")
	w.loc = ""
	w.trip_px = 400.0
	w.arrive("brass_garden")
	check(w.encounter.get("kind", "") == "battle_offer" and w.encounter.quest == "P02", "docking opens the quest's battle")
	var ow := _fight(w, 5)
	if ow in ["won", "boarded"]:
		w.auto_complete()
		check(w.quest_state("P02") == "done", "won battle completes the quest")
	# Hive Debt: hand her over loses the recruit
	var hd = _fresh()
	hd.loc = "null_point"
	check(hd.accept_quest("C13"), "accept Hive Debt")
	hd.loc = "drift_market"
	hd.complete("C13", 1)
	check(hd.lost_crew.has("C13") and not hd.recruitable.has("C13"), "handed over: Quill never joins")

## Quest Expansion v2.2 (docs/runner/RUNNER_QUESTS_EXPANSION.md): counts, the doc's credits, the
## Act I chain to the Rift Key, the main spine to the endings, the new steps / prereqs / rewards, and
## a driver that takes and hands in every quest in the game.
func _test_expansion() -> void:
	# counts: 56 + 88 = 144 (the doc counts M13a / b / c as one quest: 146 entries here)
	var by := {}
	for id in S.QUESTS:
		var pre: String = id.substr(0, 2) if id.begins_with("CL") else id.substr(0, 1)
		by[pre] = int(by.get(pre, 0)) + 1
	check(S.QUESTS.size() == 146, "146 quest entries (144 + M13's two other branches): %d" % S.QUESTS.size())
	check(by.get("N", 0) == 12 and by.get("M", 0) == 13 and by.get("P", 0) == 28 and by.get("O", 0) == 28, "N 12, M 11 (+2 branches), P 28, O 28: %s" % str(by))
	check(by.get("F", 0) == 12 and by.get("C", 0) == 16 and by.get("CL", 0) == 16 and by.get("T", 0) == 12 and by.get("S", 0) == 9, "F 12, C 16, CL 16, T 12, S 9")
	# the doc's credits, quest by quest (a choice that costs is a "cost", not credits)
	var cr := {"N07": 600, "N08": 1500, "N09": 800, "N10": 1200, "N11": 0, "N12": 0, "M05": 2000, "M06": 8000, "M07": 5000,
		"M08": 0, "M09": 12000, "M10": 15000, "M11": 10000, "M12": 0, "M13a": 20000, "M13b": 20000, "M13c": 20000,
		"M14": 40000, "M15": 100000, "P15": 3500, "P16": 6000, "P17": 2800, "P18": 5000, "P19": 5500, "P20": 6000,
		"P21": 5000, "P22": 6500, "P23": 3500, "P24": 4500, "P25": 8000, "P26": 7000, "P27": 1500, "P28": 30000,
		"O15": 3500, "O16": 5000, "O17": 6000, "O18": 8000, "O19": 9000, "O20": 6000, "O21": 12000, "O22": 10000,
		"O23": 9000, "O24": 14000, "O25": 15000, "O26": 4000, "O27": 18000, "O28": 40000, "F07": 2500, "F08": 4000,
		"F09": 3500, "F10": 1000, "F11": 3000, "F12": 0, "CL01": 1500, "CL02": 3500, "CL03": 4000, "CL04": 4500,
		"CL05": 3500, "CL06": 4000, "CL07": 5000, "CL08": 4500, "CL09": 6000, "CL10": 5000, "CL11": 5500, "CL12": 5000,
		"CL13": 5000, "CL14": 6000, "CL15": 4000, "CL16": 8000, "T01": 2000, "T02": 7000, "T03": 6500, "T04": 9000,
		"T05": 8000, "T06": 6000, "T07": 7500, "T08": 3000, "T09": 6500, "T10": 30000, "T11": 35000, "T12": 6000,
		"S01": 4000, "S02": 6000, "S03": 4500, "S04": 7000, "S05": 5500, "S06": 5500, "S07": 6000, "S08": 6000, "S09": 6500}
	for id in cr:
		check(S.QUESTS.has(id), "%s exists" % id)
		if S.QUESTS.has(id):
			var q: Dictionary = S.QUESTS[id]
			var c := int(q.get("credits", 0))
			if c == 0 and q.has("choices"):
				c = int(q.choices[0].get("credits", 0))
			check(c == int(cr[id]), "%s pays %d (doc), got %d" % [id, cr[id], c])
	for id in ["O15", "O16", "O17", "O18", "O19", "O20", "O21", "O22", "O23", "O24", "O25", "O26", "O27", "O28", "CL09", "CL10", "CL11", "CL12", "CL13", "CL14", "T04", "T09", "S09", "M13b"]:
		check(str(S.QUESTS[id].get("money", "")) == "dirty", "%s pays dirty (d)" % id)
	check(int(S.QUESTS.N11.choices[0].cost) == 8000 and int(S.QUESTS.N12.choices[0].cost) == 5000 and int(S.QUESTS.M09.choices[2].cost) == 20000, "N11 8,000 / N12 5,000 / M09 20,000")
	check(int(S.QUESTS.M08.step.amount) == 4000 and int(S.QUESTS.F12.step.amount) == 5000, "M08 costs 4,000, F12 5,000")
	for f in S.ACCORD:
		check(int(S.QUESTS.P28.faction[f]) == 100, "P28 +100 %s" % f)
	check(int(S.QUESTS.P28.faction.ashscale_warbands) == -250, "P28 Ashscale -250")
	for f in S.PACT:
		check(int(S.QUESTS.O28.faction[f]) == 100, "O28 +100 %s" % f)
	check(int(S.QUESTS.O28.faction.terran_concord) == -250 and int(S.QUESTS.O28.faction.sunscale_covenant) == -100, "O28 Concord -250, Sunscale -100")
	for id in S.QUESTS:
		var q: Dictionary = S.QUESTS[id]
		if q.has("crew"):
			check(S.CREW.has(q.crew) and q.giver == "any", "%s: a crew loyalty quest" % id)
		if q.has("race"):
			check(S.RACES.has(q.race) and q.has("race_bonus"), "%s: species quest with a bonus" % id)
		if q.has("part"):
			check(D.MODULES.has(q.part), "%s part" % id)
		for w in [q.get("safe_dock", ""), q.get("tributary", "")]:
			check(w == "" or D.WORLDS.has(w), "%s world %s" % [id, w])
		for c in q.get("choices", []):
			for g in c.get("needs", {}):
				check(D.GOODS.has(g), "%s needs a known good" % id)
		if q.get("pick", "") is Array:
			for f in q.pick:
				check(S.FACTIONS.has(f), "%s pick %s" % [id, f])
	for cid in S.CREW:
		check(E._loyalty_quest(cid) != "", "%s has a loyalty quest" % cid)

	# ---- Act I: N03 opens N04 + N09, N04 leads to N10, the Rift Key opens the gates
	var a = _fresh()
	a.quests["N01"] = {"state": "done", "progress": 0}
	a.quests["N02"] = {"state": "done", "progress": 0}
	a.quests["N03"] = {"state": "active", "progress": 0}
	a.loc = "scrapyard_gamma"
	a.auto_complete()
	check(a.quest_state("N04") == "active" and a.quest_state("N09") == "active", "N03 opens N04 and First Blood")
	for i in 3:
		a._scan_passed()
	a.auto_complete()
	check(a.quest_state("N10") == "active" and not a.flags.has("act1_done"), "N04 leads to Marrow's Cache, Act I not over")
	check(not a.sector_open("veil_expanse"), "gates still shut")
	a.quests["N10"].progress = 1
	a.auto_complete()
	check(a.owned.has("eng_3") and a.quest_state("N11") == "active", "N10: a Rift Skimmer, N11 follows")
	a.loc = "frostline"
	a.clean = 100
	a.dirty = 0
	check(a.can_complete("N11") and a.needs_hand_in("N11"), "N11 is a choice at Frostline")
	check(not a.choice_block("N11", 0).is_empty() and a.complete("N11", 0).is_empty(), "can't buy the key without 8,000")
	var h0: float = a.heat_of()
	check(not a.complete("N11", 1).is_empty(), "steal the key")
	check(a.flags.has("rift_key") and a.sector_open("veil_expanse") and a.sector_open("ember_drift") and not a.sector_open("hollow_deep"), "the Rift Key opens two gates")
	check(a.heat_of() >= h0 + 20.0 and a.rep_of("terran_concord") <= 0 and a.bars.outlaw == 1, "stealing: heat, Concord -100, Outlaw +1")
	check(a.quest_state("N12") == "active" and a.quest_state("M05") == "active", "N12 and M05 follow")
	a.loc = "cradle_station"
	check(not a.complete("N12", 1).is_empty() and a.flags.has("kessel_nemesis") and a.flags.has("act1_done"), "burn Kessel's ledger: Act I done, Kessel hunts you")
	check(not a.can_borrow(), "no more loans from Kessel")
	# M05: through the gate, dock anywhere in the Veil Expanse
	a.sector = "veil_expanse"
	a.loc = "aerie_spire"
	check(a.can_complete("M05") and not a.choice_block("M05", 2).is_empty(), "M05 done in the Veil; the forged pass needs a crate")
	a.hidden["forged_ids"] = 1
	check(a.choice_block("M05", 2).is_empty() and not a.complete("M05", 2).is_empty() and a.qty("forged_ids") == 0, "forged pass handed over")
	check(a.quest_state("M06") == "active", "M06 follows")
	var st0: float = a.stat("stealth")
	a.quests["M06"].progress = 1
	a.auto_complete()
	check(a.nodes == 1 and is_equal_approx(a.stat("stealth"), st0 + 0.10), "Blind Node I: +10%% stealth (%.2f -> %.2f)" % [st0, a.stat("stealth")])
	a.loc = "the_gilded_rock"
	check(a.complete("M07", -1, "bloom").is_empty(), "M07: only the four patrons")
	check(not a.complete("M07", -1, "veilbound").is_empty() and a.quest_state("M08") == "active", "M07: Veilbound patron")
	a.clean = 4000
	a.auto_complete()
	check(a.complete("M08").size() >= 0 and a.flags.has("safehouse") and a.clean == 0, "M08: pay 4,000 for a safehouse")
	var hs = _fresh()
	hs.heat["accord"] = 50.0
	hs.loc = "cradle_station"
	hs.pass_days(1)
	var cool1: float = 50.0 - hs.heat_of()
	hs.flags["safehouse"] = true
	hs.heat["accord"] = 50.0
	hs.pass_days(1)
	check(is_equal_approx(50.0 - hs.heat_of(), cool1 * 2.0), "safehouse: heat cools twice as fast")
	a.loc = "null_point"
	a.quests["M09"] = {"state": "active", "progress": 0}
	check(not a.complete("M09", 0).is_empty() and a.nodes == 2 and a.quest_state("M10") == "active", "M09 heist: node II, Vask's Gambit")
	check(a.flags.has("core_stolen") and not a.ghost_core(), "Vask stole the Ghost Core")
	var s_lost: int = a.stealth()
	a.quests["M10"].progress = 1
	a.loc = "the_cinder_fort"
	check(not a.complete("M10", 0).is_empty() and a.ghost_core() and a.stealth() == s_lost + D.GHOST_STEALTH, "M10: the Core is back")
	a.quests["M11"].progress = 1
	a.auto_complete()
	check(a.nodes == 3 and a.quest_state("M12") == "active", "three nodes, M12")
	a.loc = "scrapyard_gamma"
	a.complete("M12", 2)
	# M13: the musters (one of three)
	a.loc = "sunspire_citadel"
	var m13: Array = a.quest_offers().filter(func(o): return o[0] == "M13a")
	check(not m13.is_empty() and not m13[0][1].is_empty(), "Muster of Light shows, locked")
	a.bars.paragon = 50
	for f in ["terran_concord", "synthesis", "high_aerie"]:
		a.rep[f] = 600
	a._invalidate()
	check(a.quest_block("M13a").is_empty() and a.accept_quest("M13a"), "Muster of Light opens at Paragon 50 + 3 Accord at 50%")
	a.loc = "the_cinder_fort"
	check(not a.quest_offers().any(func(o): return o[0] == "M13b"), "one muster only")
	a.loc = "sunspire_citadel"
	a.cargo["alloys"] = 8
	check(a.pick_options("M13a").size() == 3 and a.pick_count("M13a") == 3, "pick among the Accord factions at 50%")
	check(a.complete("M13a", -1, "terran_concord,synthesis").is_empty(), "three must be picked")
	check(not a.complete("M13a", -1, "terran_concord,synthesis,high_aerie").is_empty() and a.rep.synthesis == 700, "M13a: +100 to the three")
	check(a.sector_open("hollow_deep") and a.quest_state("M14") == "active", "the Hollow Deep opens, M14")
	a.quests["M14"].progress = 1
	a.auto_complete()
	check(a.quest_state("M15") == "active", "M15")
	a.quests["M15"].progress = 1
	a.loc = "the_ledger_core"
	a.sector = "hollow_deep"
	check(a.needs_hand_in("M15") and not a.choice_block("M15", 0).is_empty() and not a.choice_block("M15", 1).is_empty(), "Unify and Rule need 100 on a bar")
	check(not a.choice_block("M15", 2).is_empty(), "The Ghost needs Pip, Halcyon and Quill")
	for cid in S.GHOST_CREW:
		a.quests[cid] = {"state": "done", "progress": 0}
	check(a.choice_block("M15", 2).is_empty(), "The Ghost opens")
	check(not a.complete("M15", 2).is_empty() and a.ending == "ghost" and a.pending_story.has("ending_ghost") and a.stats.endings == 1, "ending: The Ghost")
	var u = _fresh()
	u.bars.paragon = 100
	for f in ["terran_concord", "synthesis", "high_aerie", "verdant_canopy"]:
		u.rep[f] = 750
	check(u.ending_block("unify").is_empty() and not u.ending_block("rule").is_empty() and not u.ending_block("ghost").is_empty(), "Unify the Spiral: Paragon 100 + 4 Accord at 75%")

	# ---- tours, loyalty, species, the odd rewards
	var t = _fresh()
	t.rep["high_aerie"] = 300
	t.loc = "aerie_spire"
	t.sector = "veil_expanse"
	check(t.accept_quest("P17"), "accept Wind Courier")
	for w in ["sunspire_citadel", "abyssal_reef", "chorus_nebula"]:
		t._quest_arrival(w)
		t.encounter = {}
	t.loc = "chorus_nebula"
	check(not t.can_complete("P17") and t.quest_progress("P17") == [3, 4], "three of four nests")
	t._quest_arrival("aerie_spire")
	t.loc = "aerie_spire"
	t.auto_complete()
	check(t.quest_state("P17") == "done", "Wind Courier done")
	var l = _fresh()
	l.crew = [{"id": "C04", "loyalty": 60}]
	l._invalidate()
	check(not l.quest_offers().any(func(o): return o[0] == "CL04"), "no loyalty quest before three quests together")
	l.crew[0]["q"] = 3
	check(l.quest_offers().any(func(o): return o[0] == "CL04" and o[1].is_empty()), "Wingmates offered at any dock")
	var before := 0.0
	for p in l.perk_list():
		if p[0] == S.CREW.C04.personal:
			before = float(p[1])
	l.accept_quest("CL04")
	l.quests["CL04"].progress = 1
	l.auto_complete()
	var after := 0.0
	var quirk := 0.0
	for p in l.perk_list():
		if p[0] == S.CREW.C04.personal:
			after = float(p[1])
		if p[0] == S.CREW.C04.quirk and p[2] == "C04":
			quirk = float(p[1])
	check(before == 1.0 and after == 1.5 and quirk == 0.25 and l.crew_rank("C04") == 2, "Rank II: perk x1.5, quirk 25%")
	check(int(l.crew[0].loyalty) >= 85, "loyalty +25")
	var sp = _fresh(1, {"race": "terran", "picks": ["G02", "G03"]})
	sp.accept_quest("S01")
	sp.loc = "frostline"
	var c0: int = sp.clean
	sp.complete("S01", 0)
	var want := int(round(4600 * (1.0 + sp.stat("mission_credits"))))
	check(sp.clean - c0 == want, "Terran: +15%% on Family Business, then the mission perks (%d, want %d)" % [sp.clean - c0, want])
	var sy = _fresh(1, {"race": "synthari"})
	sy.loc = "halcyon_core"
	sy.accept_quest("S02")
	check(sy.can_complete("S02"), "Synthari skip Mirror Mind's trap")
	sy.auto_complete()
	check(sy.owned.has("spc_nanites"), "and get Repair Nanites")
	var nx = _fresh(1, {"race": "noctari"})
	nx.loc = "drift_market"
	nx.accept_quest("S09")
	check(nx.qty("forged_ids") == 2 and nx.can_complete("S09"), "Noctari: the forged IDs are free")
	var fz = _fresh()
	fz.rep["terran_concord"] = -150
	fz.heat["accord"] = 70.0
	fz.loc = "port_vermillion"
	check(fz.quest_block("F12").is_empty() and fz.accept_quest("F12"), "Clean Slate only below Concord -10%")
	fz.clean = 5000
	fz.auto_complete()
	fz.complete("F12")
	check(fz.heat_of() == 0.0 and fz.rep_of("terran_concord") == -50 and fz.clean == 0, "F12: 5,000, heat 0, Concord +100")
	var sd = _fresh()
	sd.flags["safe_dock"] = "frostline"
	check(not sd.scans_here("frostline") and sd.scans_here("cradle_station"), "P27: Frostline never scans you")
	var tb = _fresh()
	tb.tributaries = ["sunken_orbital"]
	var d0: int = tb.dirty
	tb.pass_days(2)
	check(tb.dirty - d0 == 2 * S.TRIBUTE_PER_DAY, "O25: tribute every day")
	var fr = _fresh()
	fr.ship = "runner"
	fr.flags["free_refit"] = true
	fr.clean = 0
	check(fr.refit_price() == 0 and fr.refit() and fr.tier == 2 and not fr.flags.has("free_refit"), "T01: one free refit")
	check(fr.refit_price() > 0, "only one")
	var bn = _fresh()
	bn.crew = [{"id": "C02", "loyalty": 15}]
	bn.heat["accord"] = 100.0
	bn.cargo["food"] = 4
	bn.pass_days(1)
	check(bn.flags.has("burned") and bn.crew.is_empty() and bn.pending_story.has("burned") and bn.cargo.is_empty(), "Burned: the crew sells you out")
	# an old v2 save (gates opened by N04 then) keeps its gates and moves on to N12 / M05
	var old = _fresh()
	for id in ["N01", "N02", "N03", "N04"]:
		old.quests[id] = {"state": "done", "progress": 0}
	old.flags["act1_done"] = true
	var d: Dictionary = old.to_dict()
	d.erase("nodes")
	var mg = E.new()
	check(mg.from_dict(d), "old v2 save loads")
	check(mg.flags.has("rift_key") and mg.sector_open("veil_expanse") and mg.quest_state("M05") == "active" and mg.quest_state("N12") == "active" and mg.quest_state("N09") == "active", "old save: gates stay open, N09 / N12 / M05 start")

	# ---- the bosses can be beaten with the ship you'd have by then (the sim's autopilot, 10 seeds)
	check(_win_rate(1, 1, "vault_guard") >= 0.7, "M06's vault drones: a Skiff with stock parts")
	check(_win_rate(2, 2, "vask_flagship") >= 0.5, "M10 Queen Vask: a Courier with mid parts")
	check(_win_rate(3, 2, "hollow_drones") >= 0.7, "M14 sentinels: a Corvette")
	check(_win_rate(3, 3, "auditor") >= 0.5, "M15 AUDITOR: a Corvette with the best parts")
	check(_win_rate(1, 1, "auditor") == 0.0, "AUDITOR is no pushover")

	# ---- every quest can be taken (where it is offered) and handed in
	for id in S.QUEST_ORDER:
		_drive_quest(id)

func _win_rate(tier: int, lv: int, enemy: String, n: int = 10) -> float:
	var wins := 0
	for s in n:
		var e = _fresh(100 + s)
		e.ship = "runner"
		e.tier = tier
		e.modules.weapons = "wpn_%d" % lv
		e.modules.shields = "shd_%d" % lv
		e.modules.engine = "eng_%d" % lv
		e.hull = e.max_hull()
		e._open_battle(enemy, "test")
		if _fight(e, s) in ["won", "boarded"]:
			wins += 1
	return float(wins) / n

func _drive_quest(id: String) -> void:
	var q: Dictionary = S.QUESTS[id]
	var e = _fresh(11, {"race": str(q.get("race", "terran")) if S.RACES.get(str(q.get("race", "")), {}).get("playable", false) else "terran"})
	e.clean = 200000
	e.flags["rift_key"] = true
	e.flags["act3"] = true
	var pre: Dictionary = q.get("prereq", {})
	for d in pre.get("done", []):
		e.quests[str(d)] = {"state": "done", "progress": 0}
	for b in pre.get("bar_min", {}):
		e.bars[b] = int(pre.bar_min[b])
	for f in pre.get("rep_min", {}):
		e.rep[f] = int(pre.rep_min[f])
	for f in pre.get("rep_max", {}):
		e.rep[f] = int(pre.rep_max[f]) - 10
	if pre.has("bloc_rep"):
		for f in (S.ACCORD if pre.bloc_rep.bloc == "paragon" else S.PACT):
			e.rep[f] = maxi(e.rep_of(f), int(pre.bloc_rep.fp))
	e.nodes = int(pre.get("nodes", 0))
	if pre.has("aboard"):
		e.crew.append({"id": str(pre.aboard), "loyalty": 60})
	if q.has("crew"):
		e.crew.append({"id": str(q.crew), "loyalty": 60, "q": S.LOYAL_QUESTS})
	var gf: String = e.quest_faction(id)
	if gf != "" and gf != "none" and not pre.has("rep_max"):
		e.rep[gf] = maxi(e.rep_of(gf), S.REP_QUESTS)
	e._invalidate()
	e.loc = "cradle_station" if str(q.giver) == "any" else str(q.giver)
	e.sector = e.sector_of(e.loc)
	if q.kind == "main" and not q.get("board", false):
		e.quests[id] = {"state": "active", "progress": 0}
		if q.has("on_accept"):
			e.flags[str(q.on_accept)] = true
	else:
		check(e.quest_offers().any(func(o): return o[0] == id), "%s offered at %s" % [id, e.loc])
		check(e.quest_block(id).is_empty(), "%s can be taken: %s" % [id, str(e.quest_block(id))])
		check(e.accept_quest(id), "%s accepted" % id)
	if e.quest_state(id) != "active":
		return
	var st: Dictionary = q.step
	match str(st.type):
		"deliver":
			e.loc = str(st.to)
			e.cargo[st.good] = int(e.cargo.get(st.good, 0)) + int(st.qty)
		"reach":
			e.loc = str(st.to)
		"jump":
			e.sector = str(st.to)
			e.loc = e.worlds_in(e.sector)[0]
		"tour":
			e.quests[id]["visited"] = Array(st.to).duplicate()
			e.loc = str(st.to[-1])
		"battle":
			e.quests[id].progress = 1
			e.loc = str(st.to)
		"scans", "fights", "salvage":
			e.quests[id].progress = int(st.n)
		"pay":
			e.debt = 0
		"crew":
			e.crew.append({"id": "C01", "loyalty": 60})
	e.sector = e.sector_of(e.loc)
	var choice := -1
	if q.get("endings", false):
		e.bars.paragon = 100
		for f in S.ACCORD:
			e.rep[f] = 800
		choice = 0
	elif q.has("choices"):
		choice = 0
		for g in q.choices[0].get("needs", {}):
			e.cargo[g] = int(q.choices[0].needs[g])
	var picks := ""
	if q.has("pick"):
		picks = ",".join(e.pick_options(id).slice(0, e.pick_count(id)))
	check(e.can_complete(id), "%s can be handed in (%s)" % [id, st.type])
	var lines: Array = e.complete(id, choice, picks)
	check(e.quest_state(id) == "done" and not lines.is_empty(), "%s handed in" % id)
	for line in lines:
		_check_msg(line, "%s reward line" % id)

func _test_crew() -> void:
	var e = _fresh(1, {"race": "synthari"})
	e.recruitable = ["C09", "C02", "C05"]
	e.clean = 20000
	e.loc = "drift_market"
	check(not e.hire_block("C09").is_empty(), "Sable (Noctari) refuses a Synthari captain")
	e.loc = "frostline"
	check(not e.hire_block("C02").is_empty(), "Marisol needs Paragon 3")
	e.bars.paragon = 3
	check(e.hire_block("C02").is_empty() and e.hire("C02"), "hire Marisol")
	e.loc = "brass_garden"
	check(not e.hire_block("C05").is_empty(), "the Moth has one crew slot")
	e.ship = "runner"
	e.tier = 2
	check(e.hire("C05") and e.crew.size() == 2, "Courier: two crew")
	check(e.stat("cargo_cap") > 0.0, "Oren's Quartermaster counts")
	var wage: int = e.crew_wage("C02")
	check(wage > int(S.CREW.C02.wage) - 1, "Terran crew wage with Needs Upkeep (%d)" % wage)
	# ideology clash
	var c = _fresh(1, {"race": "terran"})
	c.ship = "runner"
	c.tier = 2
	c.bars = {"paragon": 5, "outlaw": 5}
	c.recruitable = ["C02", "C14"]
	c.clean = 20000
	c.loc = "frostline"
	c.hire("C02")
	var l_alone: int = c._loyalty_target("C02")
	c.loc = "meridian_station"
	c.hire("C14")
	check(c.clash("C02") and c._loyalty_target("C02") == l_alone - S.CLASH_LOYALTY, "Paragon + Outlaw crew: -15 loyalty")
	# unpaid crew leave
	var u = _fresh()
	u.crew = [{"id": "C02", "loyalty": 10}]
	u.clean = 0
	u.dirty = 0
	u.pass_days(3)
	check(u.crew.is_empty() and u.recruitable.has("C02"), "unpaid crew walk")
	check(c.dismiss("C14") and c.recruitable.has("C14"), "dismiss")

func _test_contracts() -> void:
	var e = _fresh()
	var offers: Array = e.contract_offers()
	check(offers.size() == E.CONTRACTS_PER_PORT, "contracts on offer")
	var c: Dictionary = {}
	for o in offers:
		if o.kind == "carry":
			c = o
	if c.is_empty():
		return
	check(not D.GOODS[c.good].contraband, "no shady contracts before the black market")
	check(e.take_contract(c.id), "take a contract")
	check(e.reserved(c.good) >= c.qty, "contract cargo reserved")
	e.loc = c.to
	var money0: int = e.clean + e.dirty
	var rep0: int = e.rep_of("terran_concord")
	check(e.deliver_contract(c.id), "deliver the contract")
	check(e.clean + e.dirty == money0 + c.pay, "contract pays")
	check(e.rep_of("terran_concord") == rep0 + S.CONTRACT_FP, "issuer +50 FP")
	var x = _fresh()
	var o: Dictionary = x.contract_offers()[0]
	x.take_contract(o.id)
	x.pass_days(40)
	check(x.contracts.is_empty(), "late contracts fail")
	# every third Paragon job: +1 Paragon
	var y = _fresh()
	for i in 3:
		y.contracts.append({"id": "t%d" % i, "kind": "carry", "good": "water", "qty": 1, "from": "cradle_station", "to": "frostline",
			"pay": 100, "money": "clean", "due": 99, "issuer": "terran_concord"})
		y.cargo["water"] = int(y.cargo.get("water", 0)) + 1
	y.loc = "frostline"
	for i in 3:
		y.deliver_contract("t%d" % i)
	check(y.bars.paragon == 1, "3 Paragon contracts = Paragon +1")

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
	e.clean = 20000
	check(e.shop_modules().has("car_2"), "Cradle Station sells legal parts")
	check(not e.shop_modules().has("hid_2"), "no black parts at Cradle before N02")
	var cap: int = e.cargo_cap()
	check(e.buy_module("car_2") and e.cargo_cap() > cap, "Expanded Racks")
	check(e.fit_module("car_1") and e.cargo_cap() == cap, "swap back (owned)")
	var cl: int = e.clean
	check(e.fit_module("car_2") and e.clean == cl, "refit without paying again")
	check(e.buy_module("spc_tractor") and e.specials == ["spc_tractor"], "a special part")
	check(not e.buy_module("spc_nanites"), "the Moth has one special socket")
	# refits (§6)
	check(e.refit_price() == -1, "the Moth can't be refitted")
	e = _fresh(1, {"race": "kestrai"})
	e.ship = "runner"
	e.tier = 1
	e.clean = 30000
	e.loc = "cradle_station"
	var hull1: int = e.max_hull()
	check(e.refit_price() == 25000 and e.refit() and e.tier == 2 and e.max_hull() > hull1 and e.crew_slots() == 2, "refit to Courier")
	check(e.sockets("weapons") == 3 and e.guns() == 3, "Courier: 3 weapon sockets")
	var t = _fresh(1, {"race": "terran"})
	t.ship = "runner"
	check(t.refit_price() == 22500, "Efficient Refit: -10%")

func _test_save() -> void:
	var e = _fresh(42, {"name": "Ana", "gender": "Female", "race": "thalassi", "picks": ["G09", "G15"]})
	e.clean = 1234
	e.flags["black_market"] = true
	e.heat["accord"] = 33.5
	e.buy("water", 2)
	e.rep["bloom"] = -120
	e.bars = {"paragon": 7, "outlaw": 2}
	e.crew = [{"id": "C01", "loyalty": 55}]
	e.curses = {"B05": 9}
	e.ship = "runner"
	e.tier = 3
	e.loc = "frostline"
	e._invalidate()
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var f = E.new()
	check(f.from_dict(d), "load")
	check(f.captain.name == "Ana" and f.captain.race == "thalassi" and f.captain.picks == ["G09", "G15"], "captain survives")
	check(f.clean == e.clean and f.loc == "frostline" and f.qty("water") == 2, "state survives")
	check(is_equal_approx(f.heat_of(), 33.5), "heat survives")
	check(f.rep.bloom == -120 and f.bars.paragon == 7 and f.crew[0].loyalty == 55 and f.tier == 3, "rep, bars, crew, tier survive")
	check(f.quest_state("N01") == "active", "quests survive")
	check(f.net_worth() == e.net_worth() and is_equal_approx(f.stat("fuel_use"), e.stat("fuel_use")), "net worth and stats survive")
	e.launch()
	e.ship_pos = Vector2(500, 300)
	e._open({"kind": "inspect", "faction": "accord", "bribe": 300, "fine": 90})
	var g = E.new()
	g.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	check(g.loc == "" and g.ship_pos == Vector2(500, 300), "in-flight save keeps the ship's place")
	check(g.encounter.get("kind", "") == "inspect" and g.encounter.bribe == 300, "an open encounter survives")
	check(not f.from_dict({"v": 1}), "a v1 save (the old galaxy) is refused")
	check(E.save_version({"v": 1}) == 1, "the game can tell a v1 save")

## Every message the engine makes is a String or {"text", "args"} whose args fit the template.
func _test_messages() -> void:
	var e = _fresh(3)
	e.flags["black_market"] = true
	e.dirty = 500
	e.cargo["food"] = 2
	e.hidden["weapons"] = 1
	for kind in ["inspect", "pirates", "battle_offer", "derelict", "distress", "pod", "bargain", "no_fuel", "salvage_site", "sun", "black_hole", "meteors", "flare", "tip"]:
		e.encounter = {"kind": kind, "faction": "accord", "bribe": 100, "fine": 50, "enemy": "pirate", "log": [], "at": [0, 0], "curse": "B02", "cash": 900}
		for o in e.options():
			_check_msg(o[1], "option %s/%s" % [kind, o[0]])
	for id in S.QUESTS:
		_check_msg(e.quest_block(id), "quest block")
	for c in S.CREW:
		_check_msg(e.hire_block(c), "hire block")
	for s in 300:
		var x = _fresh(500 + s)
		x.flags["black_market"] = true
		x.hidden["forged_ids"] = 1
		x.launch()
		x._random_event()
		for line in x.encounter.get("log", []):
			_check_msg(line, "event log")
		var guard := 0
		while not x.encounter.is_empty() and guard < 40:
			if x.encounter.kind == "battle":
				var b = B.new()
				b.setup(x.battle_player(), x.battle_enemies(), s)
				var t := 0
				while b.outcome == "" and t < 6000:
					b.tick(1.0 / 30.0, b.autopilot_move())
					t += 1
				for line in x.end_battle(b.outcome if b.outcome != "" else "fled", b.result_info()):
					_check_msg(line, "battle line")
			else:
				var opts: Array = x.options()
				var pick: int = s % opts.size()
				for line in x.choose(opts[pick][0]):
					_check_msg(line, "choice line")
			guard += 1
		check(guard < 40, "an encounter ends")
		x.pass_days(5)
		for n in x.news:
			_check_msg(n, "news")
	var q = _fresh()
	q.rep["terran_concord"] = 300
	q.accept_quest("P13")
	q.loc = "meridian_station"
	for line in q.complete("P13"):
		_check_msg(line, "quest reward line")

func _check_msg(m: Variant, what: String) -> void:
	if m is Dictionary and m.is_empty():
		return
	if m is String:
		check(not m.contains("%"), "%s: plain text has no %% (%s)" % [what, m])
		return
	check(m is Dictionary and m.has("text"), "%s is a message" % what)
	if m is Dictionary:
		var t: String = m.text
		var s: String = t % m.args if not m.args.is_empty() else t
		check(not s.is_empty(), what)

## A greedy trader bot flies 10,000 trips in the Cradle Reach: buys the best trade from where it is,
## flies there, answers every encounter with its first option and fights battles with the sim's
## autopilot. Money must grow, but not explode.
func _simulate() -> void:
	var e = _fresh(2026)
	e.flags["black_market"] = true
	var trips := 0
	var stuck := 0
	var peak_heat := 0.0
	var loans := 0
	var battles := 0
	for i in 10000:
		e.buy_fuel()
		for c in e.deliverable_contracts():
			e.deliver_contract(c.id)
		if e.has_service("collector") and e.debt > 0 and e.total_credits() > e.debt + 2000:
			e.pay_debt(e.debt)
		if e.can_borrow():
			e.borrow()
			loans += 1
			e.buy_fuel()
		if e.contracts.is_empty():
			for c in e.contract_offers():
				if c.kind == "carry" and e.can_reach(c.to):
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
			var ws: Array = e.worlds_in(e.sector)
			dest = ws[e.rng.randi() % ws.size()]
		if dest == e.loc or not e.can_reach(dest):
			e.buy_fuel()
			if not e.can_reach(dest):
				stuck += 1
				dest = "cradle_station" if e.loc != "cradle_station" else "frostline"
		var dist: float = e.distance_to(dest)
		e.launch()
		var steps := int(ceil(dist / 40.0))
		for k in steps:
			if e.fly(dist / steps, e.ship_pos.lerp(e.pos_of(dest), float(k + 1) / steps), 1.0):
				battles += _resolve(e)
				if e.tow_to != "":
					dest = e.tow_to
					e.tow_to = ""
					break
		e.arrive(dest)
		battles += _resolve(e)
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
	print("sim: %d trips, %d days, net worth %d, clean %d, dirty %d, heat peak %.0f, scans %d/%d, battles %d (won %d, lost %d), stuck %d, loans %d, contracts %d, rep %s, bars %s" % [
		trips, e.day, nw, e.clean, e.dirty, peak_heat, e.stats.scans_passed, e.stats.scans_failed,
		battles, e.stats.fights_won, e.stats.fights_lost, stuck, loans, e.stats.contracts, str(e.rep), str(e.bars)])
	check(nw > 20000, "a trader gets richer over 10,000 trips")
	check(e.debt <= S.START_DEBT + 5000, "debt does not spiral (%d)" % e.debt)
	check(loans < 200, "the loan is a safety net, not a way of life (%d loans)" % loans)
	check(nw < 200000000, "no runaway money (net worth %d)" % nw)
	check(e.hull > 0 and e.fuel >= 0.0, "ship state stays sane")
	check(_supply_sane(e), "supply factors stay in range")

## Answers every open encounter (battles with the autopilot). Returns battles fought.
func _resolve(e: Object) -> int:
	var n := 0
	var guard := 0
	while not e.encounter.is_empty() and guard < 20:
		guard += 1
		if e.encounter.kind == "battle":
			n += 1
			_fight(e, e.rng.randi())
		else:
			e.choose(e.options()[0][0])
	return n

func _supply_sane(e: Object) -> bool:
	for w in e.supply:
		for g in e.supply[w]:
			var v: float = e.supply[w][g]
			if v < 0.55 or v > 1.7:
				return false
	return true
