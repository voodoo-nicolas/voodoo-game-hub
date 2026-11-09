extends SceneTree

## Beached (wilson) acceptance tests: KICKOFF.md "Acceptance tests" + M0-M2 behaviour.
##   godot --headless --path . --script res://tools/test_wilson.gd
## Pure engine tests (no saves touched).

const D = preload("res://scripts/games/wilson/wilson_data.gd")
const Astro = preload("res://scripts/games/wilson/wilson_sky.gd")
const Engine_ = preload("res://scripts/games/wilson/wilson_engine.gd")

var fails := 0
var checks := 0

func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)

func near(a: float, b: float, eps: float, what: String) -> void:
	ok(absf(a - b) <= eps, "%s: got %.4f want %.4f" % [what, a, b])

## Unix time of a local date/time with tz = 0.
func at(y: int, m: int, d: int, h: int = 0, mi: int = 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": h, "minute": mi, "second": 0}))

## A fresh engine at a time, tz 0, fixed seed.
func fresh(t: float, hemi := "south") -> Object:
	var e = Engine_.new()
	e.reset(t, 0, hemi, 12345)
	e.bars = {"hp": 100.0, "food": 100.0, "water": 100.0, "energy": 100.0}
	e.shore.last_day = e.day_index() + 9999  # no shore deliveries in bar tests
	return e

func _init() -> void:
	test_sun()
	test_moon()
	test_keyframes()
	test_bars()
	test_sleep()
	test_nap()
	test_costs_and_tables()
	test_json()
	test_queue_offline()
	test_tutorial()
	test_save()
	test_m3_combine()
	test_m3_all_recipes()
	test_m3_wear_spoil()
	test_m3_structures()
	test_m3_skills_storage()
	test_m4_weather_tides()
	test_m5_side_quests()
	test_m5b_more_quests()
	test_m6_projects()
	test_m7_dailies()
	print("wilson: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------- M0 sky

func test_sun() -> void:
	near(Astro.sunrise(355, "south"), 5.50, 0.01, "sunrise doy 355 south")
	near(Astro.sunset(355, "south"), 19.00, 0.01, "sunset doy 355 south")
	near(Astro.sunrise(172, "south"), 7.00, 0.01, "sunrise doy 172 south")
	near(Astro.sunset(172, "south"), 17.50, 0.01, "sunset doy 172 south")
	near(Astro.sunrise(172, "north"), 5.50, 0.01, "sunrise doy 172 north")
	var e = fresh(at(2026, 12, 21, 12))
	ok(e.doy() == 355, "engine doy for 2026-12-21 = 355 (got %d)" % e.doy())

func test_moon() -> void:
	var epoch := float(Time.get_unix_time_from_datetime_string("2000-01-06T18:14:00"))
	near(epoch, Astro.MOON_EPOCH, 0.5, "moon epoch constant")
	near(Astro.moon_phase(epoch), 0.0, 1e-6, "moon phase at epoch")
	near(Astro.moon_phase(epoch + 14.765294 * 86400.0), 0.5, 1e-6, "moon phase at epoch + 14.765294 d")
	near(Astro.moon_lit(0.5), 1.0, 1e-6, "full moon fully lit")
	var mid := Astro.moon_arc(0.0, 0.5)
	near(mid.y, 1.0, 0.01, "full moon highest at midnight")

func test_keyframes() -> void:
	var kfs := Astro.keyframes(355, "south")
	ok(kfs.size() == 12, "12 keyframes")
	for i in range(1, kfs.size()):
		ok(kfs[i][0] >= kfs[i - 1][0], "keyframes sorted (%d)" % i)
	var noon := Astro.sky_at(12.25, 355, "south")
	ok(Color(noon.sky_top).is_equal_approx(Color("3d9bd6")), "noon sky_top exact")
	near(noon.intensity, 1.0, 1e-4, "noon intensity")
	var mid := Astro.sky_at(23.0, 355, "south")  # halfway late_night (22) -> midnight (24)
	near(mid.intensity, 0.35, 1e-4, "23:00 intensity between 0.35 and 0.35")
	var half := Astro.sky_at(1.5, 355, "south")  # midnight 0.35 -> deep night 0.30
	near(half.intensity, 0.325, 1e-4, "01:30 intensity lerp")
	near(Astro.star_alpha(12.0, 355, "south"), 0.0, 1e-6, "no stars at noon")
	near(Astro.star_alpha(23.0, 355, "south"), 1.0, 1e-6, "stars at 23:00")
	near(Astro.star_alpha(19.5, 355, "south"), 0.5, 1e-6, "stars half in at sunset + 30 min")

# ---------------------------------------------------------------- M2 bars

func test_bars() -> void:
	var e = fresh(at(2026, 6, 21, 8))
	e.advance(e.t + 10 * 3600.0, true)
	near(e.bars.food, 60.0, 0.01, "idle 10 h: food")
	near(e.bars.water, 50.0, 0.01, "idle 10 h: water")
	near(e.bars.energy, 70.0, 0.01, "idle 10 h: energy")
	near(e.bars.hp, 100.0, 0.01, "idle 10 h: hp")
	var o = fresh(at(2026, 6, 21, 8))
	o.advance(o.t + 48 * 3600.0, false)
	near(o.bars.food, 15.0, 0.01, "48 h offline: food floor")
	near(o.bars.water, 15.0, 0.01, "48 h offline: water floor")
	near(o.bars.energy, 15.0, 0.01, "48 h offline: energy floor")
	near(o.bars.hp, 100.0, 0.01, "48 h offline: hp unchanged")
	ok(o.sleep.is_empty(), "offline: no collapse")
	var o2 = fresh(at(2026, 6, 21, 8))
	o2.bars.hp = 70.0
	o2.bars.food = 10.0
	o2.advance(o2.t + 24 * 3600.0, false)
	near(o2.bars.food, 10.0, 0.01, "offline: a bar already under 15 stays")
	ok(o2.bars.hp >= 70.0, "offline: hp never drops")
	# online empty bar costs hp
	var z = fresh(at(2026, 6, 21, 8))
	z.bars.food = 0.0
	z.bars.water = 0.0
	z.advance(z.t + 3600.0, true)
	near(z.bars.hp, 94.0, 0.01, "online: two empty bars = -6 hp/h")
	# collapse at energy 0 online
	var c = fresh(at(2026, 6, 21, 8))
	c.bars.energy = 1.0
	c.advance(c.t + 3600.0, true)
	ok(not c.sleep.is_empty() and c.sleep.kind == "collapse", "energy 0 online: collapse")

# ---------------------------------------------------------------- M2 sleep

func test_sleep() -> void:
	# 21:00 -> 05:00 on 21 June (south: sunrise 07:00), so the whole 8 h is night.
	var want := {"sand": 48.0, "frond_bed": 88.0, "hammock": 100.0, "frond_shelter": 100.0, "tent": 100.0}
	for bed in want:
		var e = fresh(at(2026, 6, 21, 21))
		e.bars.energy = 0.0
		if bed != "sand":
			e.structures[bed] = {"built": e.t}
		e.start_sleep(bed, 8.0)
		e.advance(e.t + 8 * 3600.0, true)
		near(e.bars.energy, want[bed], 0.01, "sleep 8 h on %s from 0" % bed)
		ok(e.sleep.is_empty(), "woke after 8 h (%s)" % bed)
	near(fresh(at(2026, 6, 21, 21)).sleep_rate("hammock") * 8.0, 112.0, 0.01, "hammock 8 h uncapped = 112")
	near(fresh(at(2026, 6, 21, 21)).sleep_rate("tent") * 8.0, 136.0, 0.01, "tent 8 h uncapped = 136")
	var r = fresh(at(2026, 6, 21, 21))
	r.structures["hammock"] = {"built": r.t}
	r.bars.energy = 10.0
	r.start_sleep("hammock", 7.0)
	r.advance(r.t + 7 * 3600.0, true)
	ok(r.has_buff("rested"), "7 h on hammock: Rested")
	var s = fresh(at(2026, 6, 21, 21))
	s.bars.energy = 10.0
	s.start_sleep("sand", 7.0)
	s.advance(s.t + 7 * 3600.0, true)
	ok(s.has_buff("sandy") and not s.has_buff("rested"), "sand: Sandy, not Rested")
	# modifiers
	var d = fresh(at(2026, 6, 21, 12))
	near(d.sleep_rate("sand"), 3.0, 1e-4, "day sun x0.5 on sand")
	d.structures["hammock"] = {"built": d.t}
	near(d.sleep_rate("hammock"), 14.0, 1e-4, "day shade x1.0 in hammock")
	var w = fresh(at(2026, 6, 21, 22))
	w.weather = "rain"
	near(w.sleep_rate("frond_bed"), 5.5, 1e-4, "rain unsheltered x0.5")
	w.weather = "storm"
	near(w.sleep_rate("frond_bed"), 2.75, 1e-4, "storm unsheltered x0.25")
	near(w.sleep_rate("frond_shelter"), 15.0, 1e-4, "storm in the shelter: no penalty")
	w.weather = "heatwave"
	near(w.sleep_rate("hammock"), 14.0 * 0.8, 1e-4, "temp extreme x0.8")

func test_nap() -> void:
	var e = fresh(at(2026, 6, 21, 13))
	e.bars.energy = 40.0
	ok(e.start_nap() == "", "first nap allowed")
	e.advance(e.t + 30 * 60.0, true)
	near(e.bars.energy, 55.0, 0.01, "first nap +15")
	ok(e.start_nap() == "", "second nap allowed")
	e.advance(e.t + 30 * 60.0, true)
	near(e.bars.energy, 63.0, 0.01, "second nap +8")
	ok(e.start_nap() != "", "third nap refused")
	ok(e.enqueue("nap") != "", "third nap refused through the queue too")

# ---------------------------------------------------------------- costs, tables, data

func test_costs_and_tables() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	e.add("stone_axe", 1)
	var before: float = e.bars.energy
	ok(e.enqueue("chop", "C") == "", "chop C queued")
	near(before - e.bars.energy, 12.0, 0.001, "chop costs 12 energy")
	near(float(D.balance().action_energy_cost.chop), 12.0, 0.0, "balance chop = 12")
	ok(e.enqueue("chop", "A") != "", "palm A can't be chopped")
	var drops: Dictionary = D.balance().shore_drops
	for k in ["normal", "storm"]:
		var sum := 0
		for r in drops[k].weights:
			sum += int(drops[k].weights[r])
		ok(sum == 100, "%s drop weights sum to 100 (got %d)" % [k, sum])
	ok(drops.normal.weights.common == 70 and drops.normal.weights.uncommon == 22 and drops.normal.weights.rare == 6 and drops.normal.weights.mythic == 2, "normal 70/22/6/2")
	ok(drops.storm.weights.common == 62 and drops.storm.weights.uncommon == 25 and drops.storm.weights.rare == 10 and drops.storm.weights.mythic == 3, "storm 62/25/10/3")
	# rarity roll frequencies (10 000 rolls)
	var cnt := {"common": 0, "uncommon": 0, "rare": 0, "mythic": 0}
	for i in 10000:
		cnt[e.roll_rarity(drops.normal.weights)] += 1
	near(cnt.common / 10000.0, 0.70, 0.02, "common ~70%")
	near(cnt.rare / 10000.0, 0.06, 0.01, "rare ~6%")
	# low energy x1.5, rested /1.1
	var l = fresh(at(2026, 6, 21, 9))
	var base: float = l.duration_of("fish", "")
	l.bars.energy = 10.0
	near(l.duration_of("fish", ""), base * 1.5, 0.01, "low energy: x1.5 duration")
	l.bars.energy = 80.0
	l.buffs["rested"] = l.t + 3600.0
	near(l.duration_of("fish", ""), base / 1.1, 0.01, "rested: 10% faster")

func test_json() -> void:
	var ids := {}
	for it in D.json("items").items:
		ok(not ids.has(it.id), "no duplicate item id: %s" % it.id)
		ids[it.id] = true
		ok(it.has("en") and it.has("es"), "item %s has en + es" % it.id)
	ok(ids.size() == 75, "75 items (got %d)" % ids.size())
	var rids := {}
	for r in D.json("recipes").recipes:
		ok(not rids.has(r.id), "no duplicate recipe id: %s" % r.id)
		rids[r.id] = true
		for pair in r["in"]:
			ok(ids.has(pair[0]), "recipe %s input %s exists" % [r.id, pair[0]])
		if r.out_type == "item":
			ok(ids.has(r.out), "recipe %s output %s exists" % [r.id, r.out])
		else:
			ok(D.STRUCTURE_NAMES.has(r.out), "structure %s has a name" % r.out)
		for k in ["tool", "needs"]:
			if r.has(k):
				ok(ids.has(r[k]), "recipe %s %s %s exists" % [r.id, k, r[k]])
	ok(rids.size() == 42, "42 recipes (got %d)" % rids.size())
	for k in D.json("recipes").debris_loot:
		for pair in D.json("recipes").debris_loot[k]:
			ok(ids.has(pair[0]), "debris %s loot %s exists" % [k, pair[0]])
	var qids := {}
	for q in D.quests():
		ok(not qids.has(q.id), "no duplicate quest id")
		qids[q.id] = true
		ok(D.QUEST_HINTS.has(q.id), "quest %s has a hint" % q.id)
	ok(qids.size() == 12, "12 tutorial quests")
	for q in D.quests():
		ok(q.journal_en in D.QUEST_JOURNAL, "quest %s journal line listed for i18n" % q.id)

# ---------------------------------------------------------------- M1 queue, offline

func test_queue_offline() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	ok(e.enqueue("haul", "crate") == "", "haul crate")
	ok(e.enqueue("haul", "crate") != "", "crate twice refused")
	for id in ["planks", "barrel", "oar"]:
		ok(e.enqueue("haul", id) == "", "haul " + id)
	ok(e.enqueue("haul", "sailcloth") == "", "5th action")
	ok(e.enqueue("gather", "sticks") != "", "6th action refused (max 5)")
	var t0: float = e.t
	near(float(e.queue[0].end) - t0, 5 * 60.0, 0.5, "haul ends 5 min later (absolute)")
	# closed the app: 1 hour later everything is done, by timestamp
	e.advance(t0 + 3600.0, false)
	ok(e.queue.is_empty(), "offline: queue processed")
	ok(e.count("rope") == 6 and e.count("hook") == 1 and e.count("knife") == 1, "crate loot")
	ok(e.count("plank") == 6 and e.count("nail") == 18, "planks loot")
	ok(e.count("sailcloth") == 1 and e.count("barrel") == 1 and e.count("oar") == 1, "other debris loot")
	ok(e.debris.is_empty(), "all debris gone")
	var away := 0
	for j in e.journal:
		if j.away:
			away += 1
	ok(away >= 5, "journal logged what he did while away (%d)" % away)
	# offline queue keeps exact order and timing
	var f = fresh(at(2026, 6, 21, 9))
	f.enqueue("gather", "sticks")
	f.enqueue("gather", "stones")
	f.advance(f.t + 3 * 60.0 + 1.0, false)
	ok(f.count("stick") == 3 and f.count("stone") == 0, "first gather done at 3 min, second running")
	f.advance(f.t + 3 * 60.0, false)
	ok(f.count("stone") == 3, "second gather done at 6 min")
	# shore delivery next morning, with a bottle
	var s = Engine_.new()
	s.reset(at(2026, 6, 21, 9), 0, "south", 99)
	s.advance(at(2026, 6, 22, 10), false)
	ok(not s.shore.pile.is_empty() and s.shore.pile.get("bottle_note", 0) == 1, "day 2: shore delivery with a bottle")
	# pity: 14 days without a rare
	var p = fresh(at(2026, 6, 21, 9))
	p.shore.no_rare = 13
	p.shore.pile = {}
	p._shore_delivery()
	var rare := false
	for id in p.shore.pile:
		if D.item(id).get("r", "") in ["R", "M"]:
			rare = true
	ok(rare, "pity: day 14 without a rare gives one")
	# inventory: 12 slots, overflow on the sand, pulled back
	var b = fresh(at(2026, 6, 21, 9))
	for id in ["stick", "stone", "frond", "shell", "sand", "seaweed", "rope", "plank", "nail", "salt", "clay", "wax"]:
		b.add(id, 1)
	ok(b.slots.size() == 12, "12 slots full")
	b.add("pearl", 2)
	ok(b.ground.get("pearl", 0) == 2, "13th item type goes on the sand")
	b.remove("wax", 1)
	ok(b.count("pearl") == 2 and b.ground.is_empty(), "freed slot pulls it back")
	b.add("stick", 40)
	ok(b.count("stick") == 30 and b.ground.get("stick", 0) == 11, "stick stacks to 30, the rest on the sand")

# ---------------------------------------------------------------- M2 tutorial T01-T12 end to end

func test_tutorial() -> void:
	var e = Engine_.new()
	e.reset(at(2026, 6, 21, 8), 0, "south", 4242)
	tut = e
	_fill()
	e.tap_johnny()
	ok(e.quest == "T02", "T01 done by tapping Johnny")
	act("haul", "crate")
	ok(e.quest == "T03", "T02 done (crate)")
	ok(e.count("rope") == 6, "T02 loot not given twice (rope 6, got %d)" % e.count("rope"))
	act("haul", "barrel")
	ok(e.capacity() == 32, "barrel in the bag: 12 + 20 slots")
	act("gather", "sticks")
	act("craft", "fishing_pole")
	ok(e.quest == "T04", "T03 done")
	act("fish")
	ok(e.quest == "T05", "T04 done (first catch)")
	ok(e.count("fish_small") == 1, "first catch is a small fish")
	e.consume("fish_small")
	ok("raw_fish_nausea" in e.gags and e.has_buff("nausea"), "first raw fish: nausea gag")
	act("gather", "dry_fronds")
	for i in 3:
		act("gather", "stones")
	act("gather", "sticks")
	act("gather", "sticks")
	act("craft", "spark_kit")
	var tries := 0
	while e.quest == "T05" and tries < 6:
		tries += 1
		act("craft", "campfire")
	ok(tries == 4 and e.fire_fails == 3, "first fire: 3 fails, then lit (tries %d)" % tries)
	ok(e.fire_lit(), "fire burning")
	ok(e.quest == "T06", "T05 done")
	act("haul", "sailcloth")
	act("craft", "hammock")
	ok(e.quest == "T07", "T06 done")
	ok(e.craft_block("coconut_bowl") != "", "coconut bowl locked before T07")
	act("shake", "A")
	ok(e.consume("coconut") == "", "drink coconut")
	ok(e.quest == "T08", "T07 done")
	ok(e.craft_block("coconut_bowl") == "", "coconut bowl unlocked by T07: " + e.craft_block("coconut_bowl"))
	act("gather", "stones")
	act("craft", "stone_axe")
	act("chop", "C")
	ok(e.quest == "T09", "T08 done")
	ok(e.count("trunk") == 3, "trunk 2 from chopping + 1 reward (got %d)" % e.count("trunk"))
	# rope for the shelter: coconuts -> husk fiber -> rope (6 fiber each)
	for p in ["A", "A", "B", "B", "B"]:
		act("shake", p)
	while e.count("coconut") > 0:
		e.consume("coconut")
	for i in 4:
		act("craft", "rope_fiber")
	ok(e.count("rope") >= 4, "4 rope from coconut husk (got %d)" % e.count("rope"))
	for i in 8:
		act("gather", "fronds")
	act("gather", "sticks")
	act("craft", "frond_shelter")
	ok(e.quest == "T10", "T09 done")
	# next morning: the sea brings a bottle
	e.advance(at(2026, 6, 22, 9), false)
	_fill()
	act("shore")
	ok(e.count("bottle_note") >= 1, "a bottle arrived")
	e.consume("bottle_note")
	ok(e.quest == "T11", "T10 done")
	act("nap")
	ok(e.quest == "T12", "T11 done")
	act("craft", "crafting_stump")
	act("tally")
	ok(e.quest == "" and e.quests_done.size() == 12, "T12 done: tutorial complete (%d)" % e.quests_done.size())
	ok("tally_marks" in e.decor, "tally decor")
	ok(e.enqueue("tally") != "", "one tally per day")

var tut = null

func _fill() -> void:
	for k in ["energy", "food", "water"]:
		tut.bars[k] = maxf(tut.bars[k], 70.0)

## Queues one action and plays until it (and any sleep) is over; fails the test if it can't queue.
func act(kind: String, target: String = "") -> void:
	var why: String = tut.enqueue(kind, target)
	ok(why == "", "%s %s: %s" % [kind, target, why])
	var guard := 0
	while (not tut.queue.is_empty() or not tut.sleep.is_empty()) and guard < 50:
		guard += 1
		tut.advance(tut.t + 600.0, true)
		_fill()

# ---------------------------------------------------------------- save

func test_save() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	e.enqueue("haul", "crate")
	e.enqueue("gather", "sticks")
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var f = Engine_.new()
	ok(f.from_dict(d), "save loads")
	f.advance(f.t + 3600.0, false)
	e.advance(e.t + 3600.0, false)
	ok(f.count("rope") == e.count("rope") and f.count("stick") == e.count("stick"), "loaded save plays the same")
	near(f.bars.food, e.bars.food, 0.001, "same bars after load")

# ---------------------------------------------------------------- M3 crafting and combining

func test_m3_combine() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	var baro := D.recipe("barometer")
	ok(int(baro.tier) == 3 and not e.recipe_known(baro), "barometer (tier 3) unknown at start")
	ok(e.craft_block("barometer").begins_with("Not figured out"), "unknown recipe can't be queued")
	e.add("bottle", 1)
	e.add("seawater", 1)
	var r: Dictionary = e.combine("bottle", "seawater")
	ok(r.ok and r.recipe == "barometer" and r.discovered, "bottle + seawater discovers the barometer (%s)" % str(r))
	ok(not r.queued, "not queued without wax and a stump")
	ok(e.recipe_known(baro) and "barometer" in e.discovered, "barometer now known")
	var again: Dictionary = e.combine("bottle", "seawater")
	ok(again.ok and not again.discovered, "second combine: no new discovery")
	var none: Dictionary = e.combine("boot", "pearl")
	ok(not none.ok, "boot + pearl: nothing")
	# a known tier 1 recipe queues straight away
	var f = fresh(at(2026, 6, 21, 9))
	f.add("stick", 1)
	f.add("stone", 1)
	f.add("rope", 1)
	var q: Dictionary = f.combine("stick", "stone")
	ok(q.ok and q.queued and f.queue.size() == 1, "stick + stone queues something craftable (%s)" % str(q))
	# same item twice: two husk fiber -> rope (needs 6)
	var g = fresh(at(2026, 6, 21, 9))
	g.add("husk_fiber", 6)
	var h: Dictionary = g.combine("husk_fiber", "husk_fiber")
	ok(h.ok and h.recipe == "rope_fiber" and h.queued, "fiber + fiber = rope")
	ok(g.undiscovered().size() > 0, "some recipes left to find")

## Every one of the 42 recipes can be made: give its parts, build its station, play it through.
func test_m3_all_recipes() -> void:
	ok(D.MAX_TIER == 4, "all four tiers on")
	var made := 0
	for r in D.json("recipes").recipes:
		var e = fresh(at(2026, 6, 21, 10))
		e.unlocked.append(r.id)
		if not r.id in e.discovered:
			e.discovered.append(r.id)
		e.fire_fails = 3
		for pair in e.recipe_parts(r):
			e.add(str(pair[0]), int(pair[1]))
		var st: String = str(r.get("station", "hands"))
		if D.STATION_STRUCTURE.has(st):
			e.structures[D.STATION_STRUCTURE[st]] = {"built": e.t}
		if st == "campfire":
			e.structures["campfire"] = {"built": e.t, "fuel_until": e.t + 99999.0}
		var why: String = e.enqueue("craft", r.id)
		ok(why == "", "recipe %s queues: %s" % [r.id, why])
		e.advance(e.t + 4 * 3600.0, true)
		if r.out_type == "structure":
			ok(e.structures.has(r.out), "recipe %s built %s" % [r.id, r.out])
		else:
			ok(e.count(r.out) >= int(r.get("qty", 1)), "recipe %s made %s" % [r.id, r.out])
		made += 1
	ok(made == 42, "42 recipes made (got %d)" % made)

func test_m3_wear_spoil() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	e.add("fishing_pole", 1)
	e.catches = 1
	var uses := 0
	while e.count("fishing_pole") > 0 and uses < 100:
		e.bars.energy = 100.0
		e.enqueue("fish")
		e.advance(e.t + 20 * 60.0, true)
		uses += 1
	ok(uses == D.TOOL_USES.fishing_pole, "fishing pole breaks after %d uses (got %d)" % [D.TOOL_USES.fishing_pole, uses])
	var s = fresh(at(2026, 6, 21, 9))
	s.add("fish_small", 2)
	s.add("fish_dried", 1)
	s.advance(s.t + 23 * 3600.0, false)
	ok(s.count("fish_small") == 2, "fresh fish still fine at 23 h")
	s.advance(s.t + 2 * 3600.0, false)
	ok(s.count("fish_small") == 0 and s.count("fish_guts") == 2, "fish spoiled to guts after 24 h")
	ok(s.count("fish_dried") == 1, "dried fish keeps")
	var k = fresh(at(2026, 6, 21, 9))
	k.structures["smokehouse"] = {"built": k.t}
	k.add("fish_small", 1)
	k.advance(k.t + 90 * 3600.0, false)
	ok(k.count("fish_small") == 1, "smokehouse: fish keeps 4x longer")

func test_m3_structures() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	e.structures["rain_catcher"] = {"built": e.t}
	e.advance(e.t + 3600.0, true)
	ok(e.drink_from("rain_catcher") != "", "dry weather: no rainwater")
	e.weather = "rain"
	e.advance(e.t + 2 * 3600.0, true)
	e.bars.water = 40.0
	ok(e.drink_from("rain_catcher") == "", "rain: a drink")
	near(e.bars.water, 65.0, 0.001, "rainwater +25")
	ok(e.drink_from("rain_catcher") == "", "second drink")
	ok(e.drink_from("rain_catcher") != "", "third: empty (2 h of rain = 2 drinks)")
	var w = fresh(at(2026, 6, 21, 9))
	w.structures["water_still"] = {"built": w.t}
	w.advance(w.t + 6.1 * 3600.0, true)
	ok(w.drink_from("water_still") == "" and w.drink_from("water_still") == "", "still: 2 drinks after 6 h of sun")
	var t = fresh(at(2026, 6, 21, 9))
	t.structures["fish_trap"] = {"built": t.t}
	t.advance(t.t + 13 * 3600.0, false)
	ok(t.structures.fish_trap.catch.size() == 2, "trap: 2 catches in 13 h")
	t.advance(t.t + 30 * 3600.0, false)
	ok(t.structures.fish_trap.catch.size() == D.TRAP_MAX, "trap holds 3")
	t.bars.energy = 80.0
	ok(t.enqueue("empty_trap") == "", "empty the trap")
	t.advance(t.t + 600.0, true)
	ok(t.structures.fish_trap.catch.is_empty(), "trap emptied")

func test_m3_skills_storage() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	ok(e.skill_level("fishing") == 0, "level 0")
	e.xp["fishing"] = 10
	ok(e.skill_level("fishing") == 1, "10 xp = level 1")
	e.xp["fishing"] = 29
	ok(e.skill_level("fishing") == 1, "29 xp = level 1")
	e.xp["fishing"] = 30
	ok(e.skill_level("fishing") == 2, "30 xp = level 2")
	var base := 15.0 * 60.0
	near(e.duration_of("fish", ""), base * (1.0 - 2 * D.SKILL_SPEED), 0.01, "fishing level 2: 6% faster")
	e.xp["fishing"] = 99999
	ok(e.skill_level("fishing") == D.SKILL_MAX, "skill caps at 10")
	var c = fresh(at(2026, 6, 21, 9))
	ok(c.capacity() == 12, "12 slots")
	c.add("clay_jar", 2)
	ok(c.capacity() == 32, "two clay jars: +20")
	c.add("barrel", 1)
	ok(c.capacity() == 52, "plus a barrel: +20")

func test_m4_weather_tides() -> void:
	var a = fresh(at(2026, 6, 21, 9))
	var b = fresh(at(2026, 6, 21, 9))
	var seen := {}
	var same := true
	for i in 2000:
		var x: float = a.t + i * 3600.0
		if a.weather_at(x) != b.weather_at(x):
			same = false
		seen[a.weather_at(x)] = true
	ok(same, "weather: same seed, same sky")
	ok(seen.size() >= 7, "weather: variety (%d states)" % seen.size())
	# seasons: south hemisphere June = winter: no heatwave; December = summer: no cold snap
	var heat := false
	var cold := false
	for i in 1500:
		if a.weather_at(at(2026, 6, 1, 0) + i * 3600.0) == "heatwave":
			heat = true
		if a.weather_at(at(2026, 12, 1, 0) + i * 3600.0) == "cold_snap":
			cold = true
	ok(not heat and not cold, "weather: seasonal states only")
	a.hemisphere = "north"
	ok(a.season(at(2026, 6, 21, 9)) == "summer", "north June = summer")
	a.hemisphere = "south"
	ok(a.season(at(2026, 6, 21, 9)) == "winter", "south June = winter")
	# the controller drives the weather through advance
	var c = fresh(at(2026, 6, 21, 9))
	c.weather_auto = true
	c.advance(c.t + 48 * 3600.0, false)
	ok(c.weather == c.weather_at(c.t), "controller: weather follows the clock")
	var f = fresh(at(2026, 6, 21, 9))
	f.weather = "storm"
	f.advance(f.t + 6 * 3600.0, false)
	ok(f.weather == "storm", "forced weather stays when the controller is off")
	# tides: 745 min cycle, low about 29 % of it
	var e = fresh(at(2026, 6, 21, 9))
	near(e.tide_level(e.t), e.tide_level(e.t + 745.0 * 60.0), 0.001, "tide: period 12 h 25 min")
	var low := 0
	for i in 745:
		if e.is_low_tide(e.t + i * 60.0):
			low += 1
	ok(low > 190 and low < 240, "tide: low about 29 %% of the cycle (%d min)" % low)
	var nl: float = e.next_low_tide()
	ok(nl > e.t and e.is_low_tide(nl) and not e.is_low_tide(nl - 300.0), "next low tide found")
	# barometer forecast
	ok(e.forecast_hours() == 0, "no barometer: no forecast")
	e.add("barometer", 1)
	ok(e.forecast_hours() == D.FORECAST_BASE_H, "barometer: 12 h")
	e.xp["weather sense"] = 30
	ok(e.forecast_hours() == D.FORECAST_BASE_H + 2 * D.FORECAST_PER_LEVEL_H, "weather sense extends the forecast")
	# reef at low tide
	var g = fresh(at(2026, 6, 21, 9))
	g.t = g.next_low_tide()
	g.bars.energy = 100.0
	var before := 0
	for s in g.slots:
		before += int(s.n)
	ok(g.enqueue("gather", "shells") == "", "gather shells at low tide")
	g.advance(g.t + 1200.0, true)
	var after := 0
	for s in g.slots:
		after += int(s.n)
	ok(after >= before + 3, "low tide: gathering gives the reef find too (%d -> %d)" % [before, after])
	# fog: an extra bottle ashore
	var h = fresh(at(2026, 6, 21, 9))
	h.weather = "fog"
	h._shore_delivery()
	ok(int(h.shore.pile.get("bottle", 0)) >= D.FOG_EXTRA_BOTTLE, "fog: extra bottle")
	# save round trip keeps the seed
	var r = fresh(at(2026, 6, 21, 9))
	var r2 = r.get_script().new()
	r2.from_dict(r.to_dict())
	ok(r2.wseed == r.wseed and absf(r2.tide_off - r.tide_off) < 0.001, "save keeps weather seed + tide")

func test_m5_side_quests() -> void:
	var Q = load("res://scripts/games/wilson/wilson_quests.gd")
	var ids := {}
	var recipes := {}
	for r in D.json("recipes").recipes:
		recipes[r.id] = true
	var good := true
	for q in Q.LIST:
		if ids.has(q.id):
			good = false
		ids[q.id] = true
		if str(q.stat).begins_with("made:") and not recipes.has(str(q.stat).substr(5)):
			good = false
		for pair in q.reward.get("items", []):
			if D.item(str(pair[0])).is_empty():
				good = false
	ok(good, "side quests: unique ids, real recipes and items")
	var e = fresh(at(2026, 6, 21, 9))
	e.bump("ev:caught", 9)
	ok(not "S05" in e.side_done, "S05 not yet at 9 fish")
	e.bump("ev:caught")
	ok("S05" in e.side_done, "S05 at 10 fish")
	ok(e.count("bait") == 3 and e.skill_level("fishing") >= 1, "S05 pays bait + fishing xp")
	var n: int = e.side_done.size()
	e.bump("ev:caught", 50)
	ok(e.side_done.size() == n, "a quest pays only once")
	# real flow: salt recipe made via the queue
	var f = fresh(at(2026, 6, 21, 9))
	f.stats["made:salt"] = 0
	f.bump("made:salt")
	ok("S01" in f.side_done and f.count("salt") == 2, "S01 salt reward")
	# weather quests via the controller
	var w = fresh(at(2026, 6, 21, 9))
	w.weather_auto = true
	w.advance(w.t + 24 * 30 * 3600.0, false)
	ok(int(w.stats.get("low_tides", 0)) >= 50, "low tides counted over a month (%d)" % int(w.stats.get("low_tides", 0)))
	ok("W07" in w.side_done, "W07 tide table done")
	var r = fresh(at(2026, 6, 21, 9))
	r.bump("reef", 5)
	ok("S10" in r.side_done, "S10 reef")
	var r2 = r.get_script().new()
	r2.from_dict(r.to_dict())
	ok(r2.side_done == r.side_done and int(r2.stats.reef) == 5, "save keeps side quests + stats")

func test_m5b_more_quests() -> void:
	var e = fresh(at(2026, 6, 21, 22))
	for b in ["sand", "frond_bed", "hammock", "tent"]:
		e.start_sleep(b, 1.0)
	ok(not "S16" in e.side_done, "S16 needs 5 beds (4 so far)")
	e.start_sleep("frond_shelter", 1.0)
	ok("S16" in e.side_done, "S16 after 5 kinds of bed")
	var f = fresh(at(2026, 6, 21, 23))
	f.bump("night_cook")
	ok("S17" in f.side_done, "S17 night cook")
	var g = fresh(at(2026, 6, 21, 9))
	g.add("clay_jar", 2)
	g.add("barrel", 1)
	g._check_side()
	ok("S15" in g.side_done, "S15 at 32+ slots")

func test_m6_projects() -> void:
	var P = load("res://scripts/games/wilson/wilson_projects.gd")
	var good := true
	var keys := {}
	for p in P.LIST:
		if keys.has(p.key):
			good = false
		keys[p.key] = true
		for m in p.mats:
			if D.item(str(m[0])).is_empty():
				good = false
	ok(good, "projects: unique keys, every material is a real item")
	var e = fresh(at(2026, 6, 21, 9))
	ok(e.project_block("GP06") == "Missing materials.", "no materials yet")
	for m in P.get_project("GP06").mats:
		e.slot_count = 80
		e.add(str(m[0]), int(m[1]))
	ok(e.project_block("GP06") == "", "cellar: all materials in the bag")
	var cap0: int = e.capacity()
	ok(e.start_project("GP06") == "", "cellar build starts")
	ok(e.count("salt") == 0 and e.count("stone") == 0, "materials spent")
	ok(e.project_block("GP02") == "Only one build at a time. Two hands.", "one build at a time")
	e.advance(e.t + 1.5 * 86400.0, false)
	ok(not e.structures.has("cellar") and e.project_progress("GP06") > 0.5, "half-built after 1.5 of 2 days")
	e.advance(e.t + 0.6 * 86400.0, false)
	ok(e.structures.has("cellar") and e.projects.is_empty(), "cellar done after 2 days")
	ok(e.capacity() == 80 + D.CELLAR_SLOTS and cap0 > 80, "cellar: +20 slots (the jars were spent)")
	ok(e._spoil_at("fish_small") == 0.0, "cellar: food never spoils")
	ok("G06" in e.side_done, "G06 quest paid")
	# treehouse bed
	var t = fresh(at(2026, 6, 21, 22))
	t.structures["treehouse"] = {"built": t.t}
	ok(t.best_bed() == "treehouse", "treehouse is the best bed")
	near(t.sleep_rate("treehouse"), D.TREEHOUSE_RATE, 0.01, "treehouse: 26 an hour at night")
	t.weather = "storm"
	near(t.sleep_rate("treehouse"), D.TREEHOUSE_RATE, 0.01, "treehouse: storm-proof")
	# desalinator
	var a = fresh(at(2026, 6, 21, 9))
	var b = fresh(at(2026, 6, 21, 9))
	b.structures["desalinator"] = {"built": b.t}
	a.advance(a.t + 5 * 3600.0, false)
	b.advance(b.t + 5 * 3600.0, false)
	ok(100.0 - b.bars.water < (100.0 - a.bars.water) * 0.5, "desalinator: much slower thirst")
	# radio needs the windmill, museum needs plaques
	var r = fresh(at(2026, 6, 21, 9))
	for m in P.get_project("GP03").mats:
		r.add(str(m[0]), int(m[1]))
	ok(r.project_block("GP03") != "", "radio needs the windmill first")
	var mu = fresh(at(2026, 6, 21, 9))
	mu.slot_count = 40
	mu.add("stone", 20)
	ok(mu.project_block("GP15") == "Needs more failed escapes.", "museum needs 2 plaques")
	mu.stats["escape_fails"] = 2
	ok(mu.project_block("GP15") == "", "museum with 2 plaques")
	# glider: a gag and a plaque
	var g = fresh(at(2026, 6, 21, 9))
	g._project_done(P.get_project("GP13"))
	ok(int(g.stats.escape_fails) == 1 and "glider_fail" in g.gags, "glider fails, earns a plaque")
	# tower forecast works without a barometer
	var f = fresh(at(2026, 6, 21, 9))
	ok(f.forecast_hours() == 0, "no forecast yet")
	f.structures["spyglass_tower"] = {"built": f.t}
	ok(f.forecast_hours() == D.TOWER_FORECAST_H, "tower: 6 h forecast")
	# shrine nudges the shore roll (more rares over many days)
	var s1 = fresh(at(2026, 6, 21, 9))
	var s2 = fresh(at(2026, 6, 21, 9))
	s2.structures["shrine"] = {"built": s2.t}
	var r1 := 0
	var r2 := 0
	for i in 400:
		s1.shore.pile = {}
		s2.shore.pile = {}
		s1._shore_delivery()
		s2._shore_delivery()
		for k in s1.shore.pile:
			if D.item(k).get("r", "C") in ["R", "M"]:
				r1 += int(s1.shore.pile[k])
		for k in s2.shore.pile:
			if D.item(k).get("r", "C") in ["R", "M"]:
				r2 += int(s2.shore.pile[k])
	ok(r2 >= r1, "shrine: no fewer rares (%d vs %d)" % [r2, r1])
	# save round trip
	var sv = fresh(at(2026, 6, 21, 9))
	sv.projects = {"GP01": {"start": sv.t, "done": sv.t + 86400.0}}
	sv.pinned = "GP02"
	var sv2 = sv.get_script().new()
	sv2.from_dict(sv.to_dict())
	ok(sv2.pinned == "GP02" and sv2.projects.has("GP01"), "save keeps projects + pin")

func test_m7_dailies() -> void:
	var Q = load("res://scripts/games/wilson/wilson_quests.gd")
	var e = fresh(at(2026, 6, 21, 9))
	e.advance(e.t + 600.0, false)
	ok(e.dq.size() == 3 and e.dq[0] != e.dq[1] and e.dq[1] != e.dq[2], "3 different dailies a day")
	var first: Array = e.dq.duplicate()
	var today: int = e.day_index()
	for q in Q.DAILY:
		ok(not Q.daily(q.id).is_empty(), "daily %s defined" % q.id)
	# complete the first one by feeding its counter
	var q1: Dictionary = Q.daily(str(first[0]))
	e.bump(str(q1.stat), int(q1.need))
	ok(first[0] in e.dq_done, "daily paid when its counter is met")
	var done_n: int = e.dq_done.size()
	e.bump(str(q1.stat), 5)
	ok(e.dq_done.size() == done_n, "a daily pays once a day")
	# next day: new roll, counters reset
	e.advance(e.t + 26 * 3600.0, false)
	ok(e.day_index() > today and e.dq_done.is_empty() and e.dstats.size() <= 2, "next day resets the dailies")
	# deterministic per island + day
	var f = fresh(at(2026, 6, 21, 9))
	f._roll_dailies(today)
	ok(f.dq == first, "same island, same day, same dailies")
	# save keeps them
	var g = f.get_script().new()
	g.from_dict(f.to_dict())
	ok(g.dq == f.dq, "save keeps the dailies")
	# new E / S / A quests
	var h = fresh(at(2026, 6, 21, 9))
	h.bump("made:raft_section")
	ok("E01" in h.side_done and not "E02" in h.side_done, "E01 first raft")
	h.bump("made:raft_section")
	ok("E02" in h.side_done, "E02 second raft")
