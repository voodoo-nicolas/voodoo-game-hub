extends SceneTree

## Headless check of the Pig engine: rules, computer play, saves.
## godot --headless --path . --script res://tools/test_pig.gd

const E = preload("res://scripts/games/pig/pig_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	# Rules, one die.
	e.new_game("pig", 100, 2, [false, false], 1)
	if e.roll_with([4]) != "ok" or e.turn_total != 4: fails += 1; print("FAIL: pig add")
	if e.roll_with([6]) != "ok" or e.turn_total != 10: fails += 1; print("FAIL: pig add 2")
	e.hold()
	if e.scores[0] != 10 or e.turn != 1 or e.turn_total != 0: fails += 1; print("FAIL: hold")
	e.roll_with([5])
	if e.roll_with([1]) != "bust" or e.scores[1] != 0 or e.turn != 0 or e.turn_total != 0: fails += 1; print("FAIL: bust")
	# Big Pig.
	e.new_game("big", 100, 2, [false, false], 1)
	e.roll_with([3, 4])
	if e.turn_total != 7: fails += 1; print("FAIL: big sum")
	e.hold()
	e.roll_with([2, 2])
	e.hold()
	if e.roll_with([1, 3]) != "bust" or e.scores[0] != 7: fails += 1; print("FAIL: big single one")
	e.roll_with([5, 5])
	e.hold()
	if e.roll_with([1, 1]) != "snake" or e.scores[0] != 0 and e.turn != 0: fails += 1; print("FAIL: snake eyes ", e.scores)
	# Computer vs computer always finishes, at every level and variant.
	for variant in ["pig", "big"]:
		for goal in [50, 100]:
			for lvl in 3:
				for g in 8:
					e.new_game(variant, goal, 2 + g % 3, [true, true, true, true], lvl)
					var guard := 0
					while not e.over and guard < 4000:
						guard += 1
						if e.turn_total > 0 and e.cpu_should_hold():
							e.hold()
						else:
							e.roll()
					if not e.over or e.winner < 0 or e.scores[e.winner] < goal:
						fails += 1; print("FAIL: game did not finish ", variant, goal, lvl)
	# Hard beats Easy in Pig more often than not.
	var hard_wins := 0
	var games := 400
	for g in games:
		e.new_game("pig", 100, 2, [true, true], 1)
		var levels := [2, 0]
		var guard2 := 0
		while not e.over and guard2 < 4000:
			guard2 += 1
			e.level = levels[e.turn]
			if e.turn_total > 0 and e.cpu_should_hold():
				e.hold()
			else:
				e.roll()
		if e.winner == 0:
			hard_wins += 1
	print("hard beat easy ", hard_wins, "/", games)
	if hard_wins < games * 0.55: fails += 1; print("FAIL: hard is not stronger")
	e.new_game("big", 50, 3, [false, true, true], 2)
	e.roll_with([2, 3])
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.turn_total != e.turn_total or e2.is_cpu != e.is_cpu or e2.variant != "big":
		fails += 1; print("FAIL: save round trip")
	print("pig: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
