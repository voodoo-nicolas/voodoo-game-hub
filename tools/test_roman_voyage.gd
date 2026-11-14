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
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
