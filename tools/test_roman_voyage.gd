extends SceneTree

## Headless logic test for Voyage of Aeneas: thousands of voyages per
## difficulty with a random player and a "pious" player; invariants hold,
## every voyage ends, save/load round-trips mid-voyage.
## godot --headless --path . --script res://tools/test_roman_voyage.gd

const E = preload("res://scripts/games/roman_voyage/roman_voyage_engine.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		if fails < 20:
			print("FAIL: ", what)

func _pious(e) -> int:
	# Prefers choices that cost no ships and raise favor; prays when it can.
	var best := -1
	var best_v := -9999.0
	for c in e.choices():
		if not c.ok:
			continue
		var fx: Dictionary = c.choice.fx
		var v := float(fx.get("favor", 0)) * 3 - float(fx.get("wrath", 0)) * 4 + float(fx.get("ships", 0)) * 40 + float(fx.get("crew", 0)) * 0.5 + float(fx.get("food", 0))
		if c.choice.get("storm", false):
			v -= 60
		if c.choice.has("chance"):
			v -= 10
		if v > best_v:
			best_v = v
			best = c.index
	return best

func _init() -> void:
	for d in 3:
		for strat in ["random", "pious"]:
			var won := 0
			var total := 0
			var score_sum := 0
			for t in 2000:
				var e = E.new()
				e.reset(d, 1000 + t)
				var guard := 0
				while not e.over and guard < 100:
					guard += 1
					var cs: Array = e.choices()
					check(cs.size() > 0, "no choices at %s" % e.event().id)
					var ok_list := cs.filter(func(c): return c.ok)
					check(ok_list.size() > 0, "nothing affordable at %s" % e.event().id)
					var i: int = ok_list[randi() % ok_list.size()].index if strat == "random" else _pious(e)
					check(e.pick(i), "pick refused")
					check(e.ships >= 0 and e.crew >= 0 and e.food >= 0, "negative")
					check(e.crew <= e.ships * E.CREW_PER_SHIP, "crew over cap")
					check(e.favor >= 0 and e.favor <= E.MAX_FAVOR and e.wrath >= 0 and e.wrath <= E.MAX_WRATH, "favor/wrath range")
					if t % 97 == 0 and not e.over:
						var e2 = E.new()
						e2.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
						check(e2.event().id == e.event().id and e2.ships == e.ships and e2.rng.state == e.rng.state, "save round-trip")
				check(e.over, "voyage never ended")
				total += 1
				if e.won:
					won += 1
					score_sum += e.score()
					check(e.score() >= 0, "score")
			print("diff %d %s: won %d/%d, avg score %d" % [d, strat, won, total, score_sum / max(1, won)])
	_test_goals()
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)

## Objectives: every daily shows up within a week, rollover resets, a won voyage counts.
func _test_goals() -> void:
	const G = preload("res://scripts/games/roman_voyage/roman_voyage_goals.gd")
	var t0 := 1_800_000_000.0
	var ids := {}
	for d in G.DAILY.size():
		ids[G.daily_for(t0 + d * 86400.0).id] = true
	check(ids.size() == G.DAILY.size(), "dailies cover the cycle")
	check(G.week_index(t0) != G.week_index(t0 + 7 * 86400.0), "week changes")
	var s := G.normalize({}, t0)
	s.daily_done = true
	s.week_count = 2
	check(G.normalize(s, t0 + 86400.0).daily_done == false, "daily rolls over")
	check(int(G.normalize(s, t0 + 8 * 86400.0).week_count) == 0, "weekly rolls over")
	check(G.all_myths().size() == 20, "20 myths, got %d" % G.all_myths().size())
	# Find a won voyage and run it through the goals.
	for seed_v in 50:
		var e = E.new()
		e.reset(0, seed_v)
		var st: Dictionary = G.normalize({}, t0)
		while not e.over:
			var ok: Array = e.choices().filter(func(c): return c.ok)
			e.pick(ok[0].index)
			G.on_choice(st, e, t0, e.last_myth)
		if not e.won:
			continue
		var before_l := int(st.laurels)
		var got: Array = G.on_end(st, e, t0)
		check(st.chronicle.size() > 5, "chronicle filled")
		check(int(st.furthest) == E.STOPS.size() - 1, "furthest = Tiber")
		check(int(st.laurels) == before_l + (G.DAILY_LAURELS if "daily" in got else 0) + (G.WEEKLY_LAURELS if "weekly" in got else 0), "laurels add up")
		check(G.on_end(st, e, t0).filter(func(x): return x == "daily").is_empty(), "daily pays once")
		break
