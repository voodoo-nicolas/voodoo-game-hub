extends SceneTree

## Headless check of the Ship, Captain, Crew engine.
## godot --headless --path . --script res://tools/test_ship_captain_crew.gd

const E = preload("res://scripts/games/ship_captain_crew/ship_captain_crew_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	e.new_game(2, [false, true], 1)
	# A 4 and a 5 come before the 6: nothing locks.
	e.roll_with([4, 5, 3, 3, 1])
	if e.has("ship") or e.has("captain") or e.has_crew():
		fails += 1
		print("FAIL: order")
	# A 6 then 5 then 4 can all come in one roll, in any dice order.
	e.new_game(2, [false, true], 1)
	e.roll_with([4, 5, 6, 2, 3])
	if not (e.has("ship") and e.has("captain") and e.has_crew()):
		fails += 1
		print("FAIL: one-roll crew")
	if e.cargo() != 5 or e.cargo_indices().size() != 2:
		fails += 1
		print("FAIL: cargo ", e.cargo())
	# Held cargo dice are kept when rolling again.
	var first: int = e.cargo_indices()[0]
	e.toggle_hold(first)
	var kept: int = e.dice[first]
	e.roll_with([1, 1])
	if e.dice[first] != kept:
		fails += 1
		print("FAIL: hold")
	if e.rolls_left != 1:
		fails += 1
		print("FAIL: rolls_left")
	# Ship first, crew later across rolls.
	e.new_game(2, [false, true], 1)
	e.roll_with([6, 1, 1, 1, 1])
	if not e.has("ship") or e.has("captain"):
		fails += 1
		print("FAIL: ship only")
	e.roll_with([5, 4, 2, 2])
	if not e.has_crew() or e.cargo() != 4:
		fails += 1
		print("FAIL: crew in roll 2 ", e.cargo())
	if not e.can_stop():
		fails += 1
		print("FAIL: can_stop")
	e.end_turn()
	if e.scores[0] != 4 or e.turn != 1:
		fails += 1
		print("FAIL: end turn")
	# No crew scores 0.
	e.roll_with([1, 2, 3, 3, 2])
	e.roll_with([1, 1, 1, 1, 1])
	e.roll_with([1, 1, 1, 1, 1])
	if e.rolls_left != 0 or e.cargo() != 0:
		fails += 1
		print("FAIL: no crew")
	e.end_turn()
	if e.scores[1] != 0 or e.round_no != 2:
		fails += 1
		print("FAIL: round advance")
	# Full computer games finish after 5 rounds.
	for lvl in 3:
		var total := 0
		for g in 40:
			e.new_game(2, [true, true], lvl)
			var guard := 0
			while not e.over and guard < 5000:
				guard += 1
				var act: String = e.cpu_decide()
				if act == "roll" and e.rolls_left > 0:
					e.roll()
				else:
					e.end_turn()
			if not e.over:
				fails += 1
				print("FAIL: game never ended")
			total += e.scores[0] + e.scores[1]
		print("level ", lvl, " average total per game ", total / 40.0)
	e.new_game(3, [false, true, true], 2)
	e.roll_with([6, 5, 4, 3, 2])
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.dice != e.dice or e2.role != e.role or e2.rolls_left != e.rolls_left:
		fails += 1
		print("FAIL: save round trip")
	print("ship_captain_crew: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
