extends SceneTree

## Headless check of the Bunco engine.
## godot --headless --path . --script res://tools/test_bunco.gd

const E = preload("res://scripts/games/bunco/bunco_engine.gd")

func _init() -> void:
	var fails := 0
	var e = E.new()
	e.new_game(2, [false, true])
	# Round 1: ones count.
	if e.roll_with([1, 3, 4]) != "hits" or e.last_points != 1 or e.turn != 0: fails += 1; print("FAIL: one hit keeps the turn")
	if e.roll_with([2, 3, 4]) != "miss" or e.turn != 1: fails += 1; print("FAIL: miss passes the turn")
	if e.roll_with([1, 1, 5]) != "hits" or e.last_points != 2: fails += 1; print("FAIL: two hits")
	if e.roll_with([4, 4, 4]) != "triple" or e.last_points != 5: fails += 1; print("FAIL: triple")
	if e.round_points[1] != 7 or e.total_points[1] != 7: fails += 1; print("FAIL: points")
	if e.roll_with([1, 1, 1]) != "bunco" or e.round_winner != 1 or e.wins[1] != 1 or e.round_no != 2: fails += 1; print("FAIL: bunco")
	if e.round_points != [0, 0] or e.turn != 0: fails += 1; print("FAIL: new round reset ", e.round_points, e.turn)
	# Round 2: a triple of 1s is only a triple now.
	if e.roll_with([1, 1, 1]) != "triple": fails += 1; print("FAIL: triple of other number")
	# Reaching 21 wins a round.
	e.new_game(2, [])
	var guard := 0
	while e.round_no == 1 and guard < 500:
		guard += 1
		e.roll_with([1, 1, 2])   # 2 points a roll, never misses
	if e.round_no != 2 or e.wins[0] != 1: fails += 1; print("FAIL: 21 wins round")
	# A full game of random play ends after six rounds.
	for g in 30:
		e.new_game(2 + g % 3, [true, true, true, true])
		var guard2 := 0
		while not e.over and guard2 < 20000:
			guard2 += 1
			e.roll()
		if not e.over: fails += 1; print("FAIL: game didn't end")
		var total_wins := 0
		for w in e.wins: total_wins += w
		if total_wins != E.ROUNDS: fails += 1; print("FAIL: round wins ", total_wins)
	e.new_game(3, [false, true, true])
	e.roll_with([1, 2, 3])
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.round_points != e.round_points or e2.is_cpu != e.is_cpu: fails += 1; print("FAIL: save round trip")
	print("bunco: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
