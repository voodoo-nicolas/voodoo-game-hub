extends SceneTree

## Beached (wilson) acceptance tests: KICKOFF.md "Acceptance tests" + M0-M2 behaviour.
##   godot --headless --path . --script res://tools/test_wilson.gd
## Pure engine tests (no saves touched).

const D = preload("res://scripts/games/wilson/wilson_data.gd")
const Astro = preload("res://scripts/games/wilson/wilson_sky.gd")
const Engine_ = preload("res://scripts/games/wilson/wilson_engine.gd")
const Quests = preload("res://scripts/games/wilson/wilson_quests.gd")
const Projects = preload("res://scripts/games/wilson/wilson_projects.gd")
const Pastimes = preload("res://scripts/games/wilson/wilson_pastimes.gd")

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
	test_m8_name()
	test_m9_pastimes_events_streak()
	test_m10_ux()
	test_m11_intro()
	test_m12_discovery()
	test_guided_opening()
	test_everything_obtainable()
	test_blunt_knife()
	test_garden()
	test_spear_bait_food()
	test_review_misc()
	test_story_chapter_two()
	test_new_quests_data()
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
	near(before - e.bars.energy, 6.0, 0.001, "chop costs 6 energy (quick-action rebalance, owner 2026-11-09)")
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
	ok(ids.size() == 88, "88 items (got %d)" % ids.size())
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
	ok(rids.size() == 53, "53 recipes (got %d)" % rids.size())
	for k in D.json("recipes").debris_loot:
		for pair in D.json("recipes").debris_loot[k]:
			ok(ids.has(pair[0]), "debris %s loot %s exists" % [k, pair[0]])
	var qids := {}
	for q in D.quests():
		ok(not qids.has(q.id), "no duplicate quest id")
		qids[q.id] = true
		ok(D.QUEST_HINTS.has(q.id), "quest %s has a hint" % q.id)
	ok(qids.size() == 20, "20 story quests")
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
	near(float(e.queue[0].end) - t0, 21.0, 0.5, "haul ends 21 s later (absolute)")
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
	f.advance(f.t + 12.0 + 1.0, false)
	ok(f.count("stick") == 3 and f.count("stone") == 0, "first gather done at 12 s, second running")
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
	ok(tries == 1 and e.fire_fails == 0, "first fire lights at once (tries %d)" % tries)
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
	ok(e.quest == "T13" and e.quests_done.size() == 12, "T12 done: the story goes on with T13 (%d)" % e.quests_done.size())
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
	# a recipe still to find comes first, and finding it never spends the materials
	var q0: Dictionary = f.combine("stick", "stone")
	ok(q0.ok and q0.discovered and q0.recipe == "sundial" and not q0.queued and f.queue.is_empty(), "stick + stone finds the sundial first (%s)" % str(q0))
	var q: Dictionary = f.combine("stick", "stone")
	ok(q.ok and q.queued and not q.discovered and f.queue.size() == 1, "stick + stone again queues something craftable (%s)" % str(q))
	# same item twice: two husk fiber -> rope (needs 6)
	var g = fresh(at(2026, 6, 21, 9))
	g.add("husk_fiber", 6)
	var h: Dictionary = g.combine("husk_fiber", "husk_fiber")
	ok(h.ok and h.recipe == "rope_fiber" and h.queued, "fiber + fiber = rope")
	ok(g.undiscovered().size() > 0, "some recipes left to find")

## Every one of the 53 recipes can be made: give its parts, build its station, play it through.
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
		elif r.id == "bottle_post":
			ok(e.count("bottle_note") == 0 and int(e.stats.get("bottles_sent", 0)) == 1, "bottle_post throws the bottle into the sea")
		else:
			ok(e.count(r.out) >= int(r.get("qty", 1)), "recipe %s made %s" % [r.id, r.out])
		made += 1
	ok(made == 53, "53 recipes made (got %d)" % made)

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
	var base := 3.0 * 60.0
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
	ok(e.side_done.count("S05") == 1 and e.count("bait") == 3 and e.side_done.size() == n + 1, "a quest pays only once (50 more fish: only the Fishmonger is new)")
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

func test_m8_name() -> void:
	ok(Engine_.clean_name("  Robin  ") == "Robin", "name: trimmed")
	ok(Engine_.clean_name("A very long castaway name indeed").length() <= 16, "name: 16 characters at most")
	ok(Engine_.clean_name("Ro\nbin\t") == "Robin", "name: control characters dropped")
	ok(Engine_.clean_name("   ") == "", "name: blank stays blank")
	var e = fresh(at(2026, 6, 21, 9))
	ok(e.cname == "", "new island: unnamed")
	e.cname = "Robin"
	var f = e.get_script().new()
	f.from_dict(e.to_dict())
	ok(f.cname == "Robin", "save keeps the name")

func test_m9_pastimes_events_streak() -> void:
	var P = load("res://scripts/games/wilson/wilson_pastimes.gd")
	# ---- pastimes
	var e = fresh(at(2026, 6, 21, 12))
	ok(e.pastime_block("stargaze") == "Only after dark.", "no stargazing at noon")
	ok(e.pastime_block("yoga") == "Only around sunrise.", "no sunrise stretch at noon")
	ok(e.pastime_block("coconut_friend") != "", "friend needs a coconut")
	ok(e.pastime_block("chat") != "", "no chat without a friend")
	ok(e.pastime_block("horizon") == "", "the horizon is always there")
	var n = fresh(at(2026, 6, 21, 22))
	n.weather = "clear"
	ok(n.pastime_block("stargaze") == "", "stargaze at night, clear sky")
	n.weather = "rain"
	ok(n.pastime_block("stargaze") == "Too cloudy to see the stars.", "no stars in rain")
	n.weather = "clear"
	n.bars.energy = 100.0
	n.mood = 40.0
	ok(n.enqueue("pastime", "stargaze") == "", "stargaze queued")
	ok(n.enqueue("pastime", "stargaze") != "", "not twice at once")
	n.advance(n.t + 3600.0, false)
	ok(n.mood > 40.0 and int(n.stats.get("pastime:stargaze", 0)) == 1, "stargaze raises the mood and counts")
	for i in 2:
		n.bump("pastime:stargaze")
	ok("W08" in n.side_done, "W08 after 3 stargazes")
	var c = fresh(at(2026, 6, 21, 9))
	c.add("coconut", 1)
	c.add("charcoal", 1)
	c.bars.energy = 100.0
	ok(c.enqueue("pastime", "coconut_friend") == "", "make a coconut friend")
	c.advance(c.t + 1800.0, false)
	ok(c.flags.get("coco", false) and c.count("coconut") == 0 and "A01" in c.side_done, "Coco exists, coconut spent, A01 paid")
	ok(c.pastime_block("chat") == "", "chat with Coco now possible")
	ok(c.pastime_block("coconut_friend") == "Coco is already your friend.", "only one Coco")
	var y = fresh(at(2026, 6, 21, 6, 30))
	var rise: float = y.sunrise_h()
	y.t = at(2026, 6, 21, 0) + rise * 3600.0 + 600.0
	ok(y.pastime_block("yoga") == "", "stretch right after sunrise")
	for p in P.LIST:
		ok(not p.lines.is_empty() and p.mood >= 0.0 and P.get_pastime(p.id) == p, "pastime %s well formed" % p.id)
	# ---- sky events
	var s1 = fresh(at(2026, 6, 21, 9))
	var s2 = fresh(at(2026, 6, 21, 9))
	var same := true
	var eclipses := 0
	var fulls := 0
	for d in range(s1.day_index(), s1.day_index() + 1200):
		if s1.is_eclipse_day(d) != s2.is_eclipse_day(d):
			same = false
		if s1.is_eclipse_day(d):
			eclipses += 1
	for i in range(0, 1200 * 24):
		if s1.is_full_moon(s1.t + i * 3600.0):
			fulls += 1
	ok(same, "eclipse days are deterministic")
	ok(eclipses >= 5 and eclipses <= 80, "eclipses are rare but happen (%d in 1200 days)" % eclipses)
	ok(fulls > 1200 * 24 * 0.04 and fulls < 1200 * 24 * 0.12, "full moon about 7%% of hours (%d)" % fulls)
	# an eclipse day: find one, check dimming + meteorite
	var ed := -1
	for d in range(s1.day_index(), s1.day_index() + 1200):
		if s1.is_eclipse_day(d):
			ed = d
			break
	var ee = fresh(at(2026, 6, 21, 9))
	ee.t = float(ed) * 86400.0 + 43200.0 - ee.tz + 1800.0
	ok(ee.eclipse_amount() > 0.4, "the sky dims at noon on an eclipse day (%.2f)" % ee.eclipse_amount())
	ee._project_daily(ed)
	ok(int(ee.shore.pile.get("meteorite_shard", 0)) == 1 and "W10" in ee.side_done, "eclipse brings a meteorite shard + W10")
	# tropical storm: shore gets 3 more rolls
	var tp = fresh(at(2026, 6, 21, 9))
	var found := -1.0
	for i in range(0, 24 * 2000, 3):
		var x: float = tp.t + i * 3600.0
		if tp.weather_at(x) == "storm" and tp.is_tropical(x):
			found = x
			break
	ok(found > 0.0, "a tropical storm exists in the sequence")
	# forecast_ok: with a barometer, a change that was forecast counts
	var fc = fresh(at(2026, 6, 21, 9))
	fc.weather_auto = true
	fc.add("barometer", 1)
	fc.advance(fc.t + 20 * 3600.0, false)
	ok(int(fc.stats.get("forecast_ok", 0)) >= 1, "forecasts that come true are counted (%d)" % int(fc.stats.get("forecast_ok", 0)))
	var nf = fresh(at(2026, 6, 21, 9))
	nf.weather_auto = true
	nf.advance(nf.t + 48 * 3600.0, false)
	ok(int(nf.stats.get("forecast_ok", 0)) == 0, "no barometer: nothing counted")
	# ---- login streak
	var st = fresh(at(2026, 6, 1, 9))
	ok(st.checkin() == 1, "first visit: day 1")
	ok(st.checkin() == 1, "same day twice: still 1")
	st.t += 86400.0
	ok(st.checkin() == 2, "next day: 2")
	st.t += 2 * 86400.0
	ok(st.checkin() == 3, "one missed day forgiven (grace tide)")
	st.t += 2 * 86400.0
	ok(st.checkin() == 1, "a second miss in the same week breaks it")
	var s7 = fresh(at(2026, 6, 1, 9))
	for i in 7:
		s7.checkin()
		s7.t += 86400.0
	ok(int(s7.streak.count) == 7 and int(s7.shore.get("bonus_rolls", 0)) == 1, "day 7: +1 shore roll")
	ok("L07" in s7.side_done, "L07 after 7 days")
	var cal := 0
	for i in range(1, 31):
		if D.STREAK_REWARDS.has(i):
			cal += 1
	ok(cal == 30, "a reward for each of the 30 calendar days")
	var sr = fresh(at(2026, 6, 1, 9))
	sr.shore["bonus_rolls"] = 2
	sr.shore.last_day = 0
	sr._shore_delivery()
	var pile := 0
	for k in sr.shore.pile:
		pile += int(sr.shore.pile[k])
	ok(int(sr.shore.get("bonus_rolls", 0)) == 0 and pile >= 5, "bonus rolls are used up (%d items)" % pile)
	# ---- curated recipe bottles
	var b = fresh(at(2026, 6, 21, 9))
	b.slot_count = 40
	for i in 3:
		b.add("bottle_note", 1)
		b.open_bottle()
	ok(b.discovered.size() == 1, "the 3rd bottle carries a recipe")
	ok("B08" in b.side_done, "B08 for a recipe in a bottle")
	var r = b.get_script().new()
	r.from_dict(b.to_dict())
	ok(r.streak.count == b.streak.count and r.discovered == b.discovered, "save keeps streak + discoveries")

func test_m10_ux() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	ok(e.craft_visible_list().is_empty(), "an empty bag: nothing to craft is listed")
	e.add("stick", 1)
	var ids := []
	for r in e.craft_visible_list():
		ids.append(str(r.id))
	ok(not "campfire" in ids, "one stick alone lists no campfire")
	e.add("stone", 1)
	e.add("dry_frond", 1)
	ids = []
	for r in e.craft_visible_list():
		ids.append(str(r.id))
	ok("spark_kit" in ids, "stick + stone + dry frond list the spark kit")
	ok(not "tent" in ids and not "frond_shelter" in ids and not "canopy" in ids, "tier 2 stays hidden at first (the tree)")
	e.add("frond", 10)
	e.add("rope", 4)
	e.stats["made:spark_kit"] = 1
	e.stats["made:rope_fiber"] = 1
	ids = []
	for r in e.craft_visible_list():
		ids.append(str(r.id))
	ok("frond_shelter" in ids, "after two tier-1 makes, tier 2 opens (frond shelter, holding fronds)")
	ok("spark_kit" in ids, "a made recipe stays listed")
	var m = fresh(at(2026, 6, 21, 9))
	m.stats["made:fishing_pole"] = 1
	var seen := false
	for r in m.craft_visible_list():
		if str(r.id) == "fishing_pole":
			seen = true
	ok(seen, "made before = listed even with an empty bag")
	# projects: shown once every material has been held
	var P = load("res://scripts/games/wilson/wilson_projects.gd")
	var pe = fresh(at(2026, 6, 21, 9))
	ok(not pe.project_visible(P.get_project("GP02")), "no windmill idea with an empty bag")
	pe.add("magnet", 1)
	ok(not pe.project_visible(P.get_project("GP02")), "one material does not preview the windmill")
	for gm in P.get_project("GP02").mats:
		pe.add(str(gm[0]), 1)
	ok(pe.project_visible(P.get_project("GP02")), "every material held shows the windmill")
	# quick actions are quick
	near(pe.duration_of("haul", "crate"), 21.0, 0.01, "haul is 21 s")
	near(pe.duration_of("pastime", "search_sand"), 10.2, 0.2, "search the sand is about 10 s")
	var quick := 0
	var PT = load("res://scripts/games/wilson/wilson_pastimes.gd")
	for p in PT.group_list("quick"):
		if float(p.min) <= 0.5:
			quick += 1
	ok(quick >= 10, "a dozen odd jobs under 30 s (%d)" % quick)
	# searching the sand really finds things over many tries
	var s = fresh(at(2026, 6, 21, 9))
	s.slot_count = 80
	s.bars.energy = 100.0
	var found := 0
	for i in 60:
		s.bars.energy = 100.0
		s.enqueue("pastime", "search_sand")
		s.advance(s.t + 30.0, false)
	for sl in s.slots:
		found += int(sl.n)
	ok(found >= 25 and found <= 55, "60 searches find a fair handful (%d)" % found)
	ok(int(s.stats.get("pastime:search_sand", 0)) == 60, "each search counts")
	# skip a stone / fan the fire need things
	ok(s.pastime_block("skip_stone") != "" or s.count("stone") > 0, "skipping needs a stone")
	var f = fresh(at(2026, 6, 21, 9))
	ok(f.pastime_block("fan_fire") == "The fire is not lit.", "fan the fire needs a lit fire")
	f.structures["campfire"] = {"built": f.t, "fuel_until": f.t + 600.0}
	f.bars.energy = 100.0
	var before: float = f.structures.campfire.fuel_until
	f.enqueue("pastime", "fan_fire")
	f.advance(f.t + 30.0, false)
	ok(f.structures.campfire.fuel_until > before + 1000.0 or f.fire_lit(), "fanning the fire gives it more fuel time")

func test_m11_intro() -> void:
	var e = Engine_.new()
	e.reset(at(2026, 6, 21, 8), 0, "south", 99)
	near(e.bars.energy, D.START_ENERGY, 0.001, "a new castaway starts a little tired")
	ok(str(e.intro_step().key) == "got:stone", "the checklist starts with pebbles")
	e.bars.energy = 65.0
	e.slot_count = 40
	var spent := 0.0
	var before: float = e.bars.energy
	# the whole Day 1 checklist, by hand
	for i in 4:
		e.enqueue("gather", "stones")
		e.advance(e.t + 13.0, false)
	ok(int(e.stats.get("got:stone", 0)) >= 8, "pebbles counted (%d)" % int(e.stats.get("got:stone", 0)))
	ok(str(e.intro_step().key) == "got:stick", "next: sticks")
	for i in 3:
		e.enqueue("gather", "sticks")
		e.advance(e.t + 13.0, false)
	ok(str(e.intro_step().key) == "got:frond", "next: fronds")
	for i in 3:
		e.enqueue("gather", "fronds")
		e.advance(e.t + 13.0, false)
	ok(int(e.stats.get("got:frond", 0)) >= 10 or str(e.intro_step().key) == "got:frond", "fronds counted")
	e.add("frond", 10)
	e.stats["got:frond"] = 10
	ok(str(e.intro_step().key) == "salvage:crate", "the crate first: it stands where the bed goes")
	e.debris["crate"] = false
	ok(str(e.intro_step().key) == "made:frond_bed", "next: the frond bed")
	e.bars.energy = 100.0
	e.enqueue("craft", "frond_bed")
	e.advance(e.t + 300.0, false)
	ok(str(e.intro_step().key) == "slept", "next: go to bed")
	e.bars.energy = 20.0
	e.start_sleep("frond_bed", 8.0)
	ok(e.intro_step().is_empty() and e.flags.get("intro_all", false), "the checklist is done after the first sleep")
	var rope: int = e.count("rope")
	e.bump("noop")
	ok(e.count("rope") == rope, "the reward is paid once")
	# day 1 really uses the energy: the checklist costs a fair share of a 65 bar
	var t = Engine_.new()
	t.reset(at(2026, 6, 21, 8), 0, "south", 98)
	t.slot_count = 60
	var e0: float = t.bars.energy
	for i in 5:
		t.enqueue("gather", "stones")
		t.advance(t.t + 13.0, false)
	for i in 5:
		t.enqueue("gather", "sticks")
		t.advance(t.t + 13.0, false)
	ok(e0 - t.bars.energy > 12.0, "ten gathers burn a real chunk of energy (%.1f)" % (e0 - t.bars.energy))

func test_m12_discovery() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	ok(not e.knows_time() and not e.knows_tide(), "a new castaway cannot read the time or the tide")
	e.structures["sundial"] = {"built": e.t}
	ok(e.knows_time() and not e.knows_tide(), "a sundial tells the time, not the tide")
	e.decor.append("tide_chart")
	ok(e.knows_tide(), "a tide chart tells the tide")
	var s = fresh(at(2026, 6, 21, 9))
	s.structures["shellphone"] = {"built": s.t}
	ok(s.knows_time() and s.knows_tide(), "the Shellphone tells both")
	# the tides still happen unseen: the low-tide counter runs and the reef still pays
	var t = fresh(at(2026, 6, 21, 9))
	t.weather_auto = true
	t.advance(t.t + 48 * 3600.0, false)
	ok(int(t.stats.get("low_tides", 0)) >= 3, "tides happen even if nobody reads them")

# ---------------------------------------------------------------- guided opening (HUD builds up step by step)

func test_guided_opening() -> void:
	var e = Engine_.new()
	e.reset(at(2026, 6, 21, 6, 30), 0, "south", 7)
	ok(e.tut == -1 and e.tut_reached("craft"), "off by default: everything is visible (old saves, tests)")
	e.tut = 0
	ok(not e.tut_reached("a") and not e.tut_reached("bag") and not e.tut_reached("hp"), "step 1: only the stick")
	ok(str(e.tut_step().id) == "walk", "first quest: walk")
	e.tut_event("walk")
	ok(e.tut_reached("a") and e.tut_reached("b") and not e.tut_reached("bag"), "step 2: A and B appear")
	e.tut_event("ab")
	ok(str(e.tut_step().id) == "pebble", "third quest: a pebble")
	e.slot_count = 40
	e.enqueue("gather", "stones")
	e.advance(e.t + 14.0, false)
	ok(str(e.tut_step().id) == "bag" and e.tut_reached("bag") and not e.tut_reached("craft"), "pebble done: the bag button appears")
	e.tut_event("bag")
	for i in 4:
		e.enqueue("gather", "stones")
		e.advance(e.t + 14.0, false)
	ok(str(e.tut_step().id) == "wood", "nine pebbles: collect wood (%s)" % str(e.tut_step().get("id")))
	for i in 3:
		e.enqueue("gather", "sticks")
		e.advance(e.t + 14.0, false)
	for i in 2:
		e.enqueue("gather", "sticks")
		e.advance(e.t + 14.0, false)
	e.enqueue("gather", "dry_fronds")
	e.advance(e.t + 14.0, false)
	ok(str(e.tut_step().id) == "spark" and e.tut_reached("craft"), "wood done: the craft button appears")
	e.add("stone", 12)
	e.add("stick", 6)
	e.add("dry_frond", 2)
	e.fire_fails = 99
	for i in 6:
		if int(e.stats.get("made:spark_kit", 0)) == 0:
			e.enqueue("craft", "spark_kit")
			e.advance(e.t + 600.0, false)
	ok(int(e.stats.get("made:spark_kit", 0)) > 0, "spark kit made")
	ok(str(e.tut_step().id) == "fire", "next: the campfire")
	e.enqueue("craft", "campfire")
	e.advance(e.t + 1200.0, false)
	ok(e.structures.has("campfire") and str(e.tut_step().id) == "hp", "campfire built: the health bar is introduced")
	ok(e.tut_reached("hp") and not e.tut_reached("food"), "only health shows so far")
	e.tut_ack()
	ok(str(e.tut_step().id) == "food", "Got it: next bar")
	for id in ["food", "water", "energy", "mood", "clock"]:
		e.tut_ack()
	ok(str(e.tut_step().id) == "journal" and e.tut_reached("pause"), "tour done: the journal")
	e.tut_event("journal")
	ok(e.tut == -1 and e.quest == "T02", "opening over: T01 done, T02 next (%s)" % e.quest)
	# the campfire was built during the opening: T05 completes the moment T04 does
	e.quest = "T04"
	e.bump("noop")
	e._complete(D.quest("T04"), "caught", {})
	ok(e.quest == "T06" and "T05" in e.quests_done, "T05 was already met by the opening (%s)" % e.quest)
	var d: Dictionary = e.to_dict()
	var e2 = Engine_.new()
	ok(e2.from_dict(d) and e2.tut == -1, "tut round trip")

# ================================================================ 2026-11-09: review round (new items, quests, fixes)

## Everything a recipe or a Grand Project asks for can be got somewhere on the island.
func test_everything_obtainable() -> void:
	var src := {}
	for id in D.SPOTS:
		src[str(D.SPOTS[id].item)] = true
	for id in D.DEBRIS:
		for pair in D.debris_loot(id):
			src[str(pair[0])] = true
	for id in ["coconut", "frond", "wax", "seawater", "fish_guts", "bottle_note", "sweet_potato", "seeds"]:
		src[id] = true      # palms, the sea, spoilage, the daily bottle, the garden (seeds: T16 / T17 rewards)
	for row in D.CHOP_LOOT:
		src[str(row[0])] = true
	for table in [D.FISH_TABLE, D.SPEAR_TABLE, D.TRAP_TABLE, D.REEF_TABLE]:
		for row in table:
			src[str(row[0])] = true
	for p in Pastimes.LIST:
		for row in p.get("loot", []):
			src[str(row[0])] = true
		for row in p.get("give", []):
			src[str(row[0])] = true
	for id in D.FOOD:
		for pair in D.FOOD[id].get("gives", []):
			src[str(pair[0])] = true
	for id in D.BLUNT.values():
		src[str(id)] = true
	src["paper"] = true      # every opened bottle
	for id in D.items():
		if str(D.items()[id].r) in ["C", "U", "R", "M"] and not id in D.NOT_ASHORE:
			src[id] = true   # the shore delivery
	# recipes: an output is reachable once all its parts are
	var grew := true
	while grew:
		grew = false
		for r in D.recipes().values():
			if r.out_type != "item" or src.has(str(r.out)):
				continue
			var all := true
			for pair in Engine_.recipe_parts(r):
				if not src.has(str(pair[0])):
					all = false
			if all:
				src[str(r.out)] = true
				grew = true
	var missing: Array = []
	for r in D.recipes().values():
		for pair in Engine_.recipe_parts(r):
			if not src.has(str(pair[0])) and not str(pair[0]) in missing:
				missing.append(str(pair[0]))
	for pr in Projects.LIST:
		for m in pr.mats:
			if not src.has(str(m[0])) and not str(m[0]) in missing:
				missing.append(str(m[0]))
	ok(missing.is_empty(), "every material has a source (missing: %s)" % str(missing))
	ok(src.has("clay") and src.has("wax"), "clay (dig for it) and wax (the palms' bees) exist on the island")

func test_blunt_knife() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	e.add("knife", 1)
	for i in D.TOOL_USES.knife:
		e._wear("knife")
	ok(e.count("knife") == 0 and e.count("blunt_knife") == 1, "a worn-out knife goes blunt, it does not vanish")
	ok(e.craft_block("coconut_bowl") != "", "a blunt knife is not a knife")
	e.add("stone", 1)
	ok(e.enqueue("craft", "sharpen_knife") == "", "sharpening queues")
	e.advance(e.t + 600.0, true)
	ok(e.count("knife") == 1 and e.count("blunt_knife") == 0 and e.tool_uses("knife") == D.TOOL_USES.knife, "sharpened: a knife with all its uses")
	ok("K01" in e.side_done, "K01 Sharp Again")
	# a hook from fish bones (the wreck only had one)
	e.add("fish_bone", 2)
	ok(e.enqueue("craft", "bone_hook") == "", "bone hook queues")
	e.advance(e.t + 600.0, true)
	ok(e.count("hook") == 1, "bone hook made")

func test_garden() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	ok(e.garden_state() == "" and e.action_block("plant", "") != "", "no garden plot: no planting")
	e.structures["garden_plot"] = {"built": e.t}
	ok(e.garden_state() == "empty" and e.action_block("plant", "").begins_with("No seeds"), "needs seeds")
	e.add("seeds", 1)
	ok(e.enqueue("plant") == "", "planting queues")
	e.advance(e.t + 60.0, true)
	ok(e.garden_state() == "growing" and e.count("seeds") == 0, "growing, seed used")
	ok(e.action_block("harvest", "") != "" and e.action_block("plant", "") != "", "no harvest and no second planting while it grows")
	e.advance(e.t + (D.GARDEN_GROW_H - 1.0) * 3600.0, false)
	ok(e.garden_state() == "growing", "still growing an hour early")
	e.advance(e.t + 2.0 * 3600.0, false)
	ok(e.garden_state() == "ready", "ready after %d h" % int(D.GARDEN_GROW_H))
	ok(e.enqueue("harvest") == "", "harvest queues")
	e.advance(e.t + 60.0, true)
	ok(e.count("sweet_potato") == D.GARDEN_YIELD and e.count("seeds") == 1 and e.garden_state() == "empty", "3 sweet potatoes, a seed back, plot empty")
	# compost: twice as fast, one more
	e.add("compost", 1)
	e.enqueue("plant")
	e.advance(e.t + 60.0, true)
	ok(e.count("compost") == 0 and bool(e.structures.garden_plot.rich), "compost dug in")
	e.advance(e.t + D.GARDEN_GROW_H * D.COMPOST_GROW_MULT * 3600.0, false)
	ok(e.garden_state() == "ready", "compost: ready in half the time")
	e.enqueue("harvest")
	e.advance(e.t + 60.0, true)
	ok(e.count("sweet_potato") == D.GARDEN_YIELD * 2 + 1, "compost: one more potato")
	# cancelling a planting gives the seed back
	var c = fresh(at(2026, 6, 21, 9))
	c.structures["garden_plot"] = {"built": c.t}
	c.add("seeds", 1)
	c.enqueue("plant")
	c.cancel(0)
	ok(c.count("seeds") == 1 and c.garden_state() == "empty", "cancelled planting refunds the seed")
	# the save keeps the plot
	e.add("seeds", 1)
	e.enqueue("plant")
	e.advance(e.t + 60.0, true)
	var e2 = Engine_.new()
	e2.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	ok(e2.garden_state() == "growing", "the garden survives a save")

func test_spear_bait_food() -> void:
	var e = fresh(at(2026, 6, 21, 9))
	ok(e.action_block("spear", "").begins_with("Needs"), "spear fishing needs a spear")
	var got := 0
	var crabs := 0
	for i in 200:
		if e.count("spear") <= 0:
			e.add("spear", 1)
		e.bars.energy = 80.0
		e.slots = e.slots.filter(func(s): return s.id == "spear")
		e.enqueue("spear")
		e.advance(e.t + 120.0, true)
	got = int(e.stats.get("speared", 0))
	crabs = int(e.stats.get("ev:caught:crab", 0))
	ok(got > 120 and got < 200 and crabs > 20, "spear: mostly hits, some misses, some crabs (%d / 200, %d crabs)" % [got, crabs])
	ok(int(e.stats.get("ev:caught", 0)) == got and "P01" in e.side_done and "P04" in e.side_done, "spear catches count as catches; P01 and P04 done")
	# bait: never an empty line, one bait per cast
	var b = fresh(at(2026, 6, 21, 9))
	b.catches = 1
	b.add("bait", 20)
	var empty := 0
	for i in 20:
		if b.count("fishing_pole") <= 0:
			b.add("fishing_pole", 1)
		b.bars.energy = 80.0
		var before: int = int(b.stats.get("ev:caught", 0))
		b.enqueue("fish")
		b.advance(b.t + 600.0, true)
		if int(b.stats.get("ev:caught", 0)) == before:
			empty += 1
	ok(empty == 0 and int(b.stats.get("bait_used", 0)) == 20 and "P02" in b.side_done, "20 baited casts: 20 catches, 20 bait used (%d empty)" % empty)
	# bandage heals, and is kept at full health
	var h = fresh(at(2026, 6, 21, 9))
	h.add("bandage", 2)
	ok(h.consume("bandage") != "" and h.count("bandage") == 2, "full health: the bandage stays in the bag")
	h.bars.hp = 40.0
	ok(h.consume("bandage") == "" and is_equal_approx(h.bars.hp, 65.0) and h.count("bandage") == 1, "bandage: +25 health")
	ok("H01" in h.side_done, "H01 First Aid")
	# cooked meals count
	h.add("fish_stew", 1)
	h.bars.food = 10.0
	h.consume("fish_stew")
	ok(is_equal_approx(h.bars.food, 45.0) and int(h.stats.get("cooked_eaten", 0)) == 1, "fish stew: +35 food, a cooked meal")
	# the frond hat in a heatwave
	var a = fresh(at(2026, 6, 21, 9))
	var c = fresh(at(2026, 6, 21, 9))
	a.weather = "heatwave"
	c.weather = "heatwave"
	c.add("frond_hat", 1)
	a.advance(a.t + 3600.0, true)
	c.advance(c.t + 3600.0, true)
	ok(c.bars.water > a.bars.water + 2.0, "a frond hat saves water in a heatwave (%.1f vs %.1f)" % [c.bars.water, a.bars.water])

func test_review_misc() -> void:
	# food that was lying on the sand still spoils once it is back in the bag
	var e = fresh(at(2026, 6, 21, 9))
	for i in e.capacity():
		e.slots.append({"id": "junk%d" % i, "n": 1})
	e.add("fish_small", 2)
	ok(int(e.ground.get("fish_small", 0)) == 2, "bag full: the fish lie on the sand")
	e.slots.pop_back()
	e._settle_ground()
	var back := {}
	for s in e.slots:
		if s.id == "fish_small":
			back = s
	ok(not back.is_empty() and float(back.get("spoil", 0.0)) > e.t, "picked back up: it has a spoil time")
	# a bottle thrown back: no note in the bag, sometimes one more ashore the next morning
	var b = fresh(at(2026, 6, 21, 9))
	b.structures["crafting_stump"] = {"built": b.t}
	var sent := 0
	for i in 40:
		b.add("bottle", 1)
		b.add("paper", 1)
		b.add("charcoal", 1)
		b.bars.energy = 80.0
		b.enqueue("craft", "bottle_post")
		b.advance(b.t + 600.0, true)
		sent += 1
	ok(b.count("bottle_note") == 0 and int(b.stats.get("bottles_sent", 0)) == sent, "40 bottles thrown, none kept")
	ok(int(b.shore.get("replies", 0)) == D.BOTTLE_REPLY_MAX and "M02" in b.side_done, "at most %d replies wait for the morning; M02 done" % D.BOTTLE_REPLY_MAX)
	b.shore.last_day = b.day_index()
	b.advance(at(2026, 6, 22, 10), false)
	ok(int(b.shore.pile.get("bottle_note", 0)) == 1 + D.BOTTLE_REPLY_MAX and int(b.shore.get("replies", 0)) == 0, "the replies came in with the morning bottle")
	# mood changes the pace
	var m = fresh(at(2026, 6, 21, 9))
	m.mood = 60.0
	var base: float = m.duration_of("gather", "stones")
	m.mood = 90.0
	ok(is_equal_approx(m.duration_of("gather", "stones"), base * D.MOOD_HIGH_SPEED), "a happy castaway is 5% faster")
	m.mood = 10.0
	ok(is_equal_approx(m.duration_of("gather", "stones"), base * D.MOOD_LOW_SPEED), "a miserable one is 10% slower")
	# clay: dig for it with a shovel (which wears)
	var c = fresh(at(2026, 6, 21, 9))
	ok(c.pastime_block("dig_clay").begins_with("Needs"), "digging clay needs a shovel")
	c.add("shovel", 1)
	c.enqueue("pastime", "dig_clay")
	c.advance(c.t + 120.0, true)
	ok(c.count("clay") == 2 and c.tool_uses("shovel") == D.TOOL_USES.shovel - 1 and int(c.stats.get("odd_jobs", 0)) == 1, "2 clay, one shovel use, an odd job counted")
	# wax: now and then from a shaken palm, never from the first shake
	var w = fresh(at(2026, 6, 21, 9))
	w.enqueue("shake", "A")
	w.advance(w.t + 60.0, true)
	ok(w.count("wax") == 0, "the first shake is just a coconut")
	for i in 400:
		w.bars.energy = 80.0
		w.enqueue("shake", "A")
		w.advance(w.t + 60.0, true)
	var wax: int = w.count("wax") + int(w.ground.get("wax", 0))
	ok(wax >= 8 and wax <= 50, "400 shakes: some wax (%d)" % wax)
	ok("L04" in w.side_done, "L04 Tree Hugger (30 shakes)")
	# days survived
	var d = fresh(at(2026, 6, 21, 9))
	d.advance(at(2026, 6, 28, 9), false)
	ok(int(d.stats.get("days", 0)) == 8 and "Y01" in d.side_done and not "Y02" in d.side_done, "Y01 on day 7, not Y02")

## The story goes on after T12: T13-T20, and old saves that had finished pick it up.
func test_story_chapter_two() -> void:
	var seen := {}
	for q in D.quests():
		seen[q.id] = true
		ok(D.QUEST_HINTS.has(q.id) and D.QUEST_SHORT.has(q.id), "quest %s has a hint and a HUD line" % q.id)
		ok(str(q.journal_en) in D.QUEST_JOURNAL, "quest %s journal line is in QUEST_JOURNAL" % q.id)
		for nx in q.next:
			ok(D.quest(str(nx)).size() > 0, "quest %s leads to a real quest" % q.id)
	ok(seen.size() == 20, "20 story quests")
	# an old save: tutorial finished, a fish trap already built, fish already cooked
	var e = fresh(at(2026, 6, 21, 9))
	e.quest = ""
	for i in 12:
		e.quests_done.append("T%02d" % (i + 1))
	e.stats["ev:crafted:fish_cooked"] = 2
	e.stats["ev:structure_built:rain_catcher"] = 1
	var e2 = Engine_.new()
	e2.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	ok(e2.quest == "T15" and "T13" in e2.quests_done and "T14" in e2.quests_done, "old save: the story resumes, what was already done counts (now %s)" % e2.quest)
	# play the rest
	e2.bars.energy = 100.0
	e2._emit("structure_built", {"id": "fish_trap"})
	ok(e2.quest == "T16" and e2.count("bait") == 3, "T15 pays bait")
	e2._emit("crafted", {"id": "shovel"})
	ok(e2.quest == "T17" and e2.count("seeds") == 2, "T16 pays the first seeds")
	e2.structures["garden_plot"] = {"built": e2.t}
	e2._emit("structure_built", {"id": "garden_plot"})
	ok(e2.quest == "T18" and e2.count("seeds") == 3, "T17")
	e2.enqueue("plant")
	e2.advance(e2.t + 60.0, true)
	ok(e2.quest == "T19", "T18 planted")
	e2.advance(e2.t + (D.GARDEN_GROW_H + 1.0) * 3600.0, false)
	e2.bars.energy = 100.0
	e2.sleep = {}
	e2.enqueue("harvest")
	e2.advance(e2.t + 60.0, true)
	ok(e2.quest == "T20", "T19 harvested (%s)" % e2.quest)
	e2._emit("structure_built", {"id": "sundial"})
	ok(e2.quest == "" and e2.quests_done.size() == 20 and "hour_stones" in e2.decor, "T20: the story is done")
	# a finished save stays finished
	var e3 = Engine_.new()
	e3.from_dict(JSON.parse_string(JSON.stringify(e2.to_dict())))
	ok(e3.quest == "" and e3.quests_done.size() == 20, "a finished story is not restarted")

func test_new_quests_data() -> void:
	var ids := {}
	for q in Quests.LIST:
		ids[q.id] = true
		ok(str(q.es) != "" and str(q.goal).ends_with("."), "quest %s has Spanish and a goal" % q.id)
	ok(ids.size() == Quests.LIST.size() and Quests.LIST.size() == 93, "93 side quests, unique ids (got %d)" % Quests.LIST.size())
	ok(Quests.DAILY.size() == 14, "14 daily quests in the pool")
	for q in Quests.DAILY:
		for pair in q.reward:
			ok(not D.item(str(pair[0])).is_empty(), "daily %s pays a real item" % q.id)
	for p in Pastimes.LIST:
		for row in p.get("loot", []) + p.get("give", []):
			ok(str(row[0]) == "" or not D.item(str(row[0])).is_empty(), "pastime %s gives a real item (%s)" % [p.id, row[0]])
	for id in D.FOOD:
		ok(not D.item(id).is_empty(), "food %s is an item" % id)
	for id in D.SPOIL_H:
		ok(not D.item(id).is_empty(), "spoiling %s is an item" % id)
