extends SceneTree

## Headless check of the Truco engine: card order, envido maths, round rules, and whole games
## played out by two computers.  godot --headless --path . --script res://tools/test_truco.gd

const E = preload("res://scripts/games/truco/truco_engine.gd")
const C = preload("res://scripts/games/truco/truco_cards.gd")
var fails := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	ok(E.power(C.make(2, 1)) > E.power(C.make(3, 1)), "1 espadas beats 1 bastos")
	ok(E.power(C.make(3, 1)) > E.power(C.make(2, 7)), "1 bastos beats 7 espadas")
	ok(E.power(C.make(2, 7)) > E.power(C.make(0, 7)), "7 espadas beats 7 oros")
	ok(E.power(C.make(0, 7)) > E.power(C.make(1, 3)), "7 oros beats a 3")
	ok(E.power(C.make(1, 3)) == E.power(C.make(2, 3)), "3s tie")
	ok(E.power(C.make(1, 1)) > E.power(C.make(1, 12)), "1 copas beats 12")
	ok(E.power(C.make(1, 7)) > E.power(C.make(1, 6)), "7 copas beats 6")
	ok(E.power(C.make(1, 6)) > E.power(C.make(1, 4)), "6 beats 4")
	ok(E.envido_points([C.make(0, 7), C.make(0, 6), C.make(1, 12)]) == 33, "7+6 oros = 33")
	ok(E.envido_points([C.make(0, 12), C.make(0, 11), C.make(1, 5)]) == 20, "two figures same suit = 20")
	ok(E.envido_points([C.make(0, 12), C.make(1, 11), C.make(2, 5)]) == 5, "no pair = best card")
	# round rules
	var e := E.new()
	e.new_game(0)
	e.hands = [[C.make(2, 1), C.make(0, 4), C.make(1, 5)], [C.make(0, 7), C.make(1, 4), C.make(2, 6)]]
	e.dealt = [e.hands[0].duplicate(), e.hands[1].duplicate()]
	ok(e.play(0, C.make(2, 1)) and e.turn == 1, "mano plays first")
	ok(not e.play(0, C.make(0, 4)), "cannot play twice in a row")
	ok(e.play(1, C.make(0, 7)) and e.tricks == [0] and e.turn == 0, "1 espadas takes trick 1, leads next")
	e.play(0, C.make(0, 4)); e.play(1, C.make(1, 4))   # parda (4 vs 4)
	ok(e.round_winner == 0 and e.score[0] == 1, "won trick 1 + tied trick 2 -> round to first winner")
	# truco chain and refusal
	e.new_game(0)
	ok(e.call_truco(0) and not e.play(0, e.hands[0][0]), "no playing while a call is pending")
	ok(e.call_truco(1) and e.pending.level == 2 and e.level == 1, "raising accepts and calls retruco")
	ok(e.answer_truco(0, true) and e.level == 2 and e.truco_owner == 0, "accepted retruco")
	ok(not e.can_call_truco(1), "the one who called last cannot raise again")
	ok(e.can_call_truco(0), "the acceptor may raise")
	e.call_truco(0); ok(e.answer_truco(1, false) and e.score[0] == 3 and e.round_winner == 0, "refusing vale cuatro gives the retruco stake (3)")
	# envido
	e.new_game(0)
	e.dealt = [[C.make(0, 7), C.make(0, 6), C.make(1, 12)], [C.make(1, 5), C.make(2, 4), C.make(3, 1)]]
	ok(e.call_envido(0, "envido") and e.call_envido(1, "real") and not e.call_envido(0, "envido"), "envido then real, no envido after real")
	ok(e.answer_envido(0, true) and e.score[0] == 5 and e.score[1] == 0, "accepted envido+real = 5 to the better hand")
	e.new_game(0)
	e.call_envido(0, "envido"); e.answer_envido(1, false)
	ok(e.score[0] == 1, "refused envido = 1")
	e.new_game(1)
	e.dealt = [[C.make(0, 7), C.make(0, 6), C.make(1, 12)], [C.make(1, 7), C.make(1, 6), C.make(3, 1)]]
	e.call_envido(1, "envido"); e.answer_envido(0, true)
	ok(e.score[1] == 2, "tie goes to mano")
	# full games
	for g in 200:
		e = E.new()
		e.new_game()
		var guard := 0
		while e.winner == -1 and guard < 5000:
			guard += 1
			if e.round_winner != -1:
				e.new_round()
			var p: int = e.turn if e.pending.is_empty() else 1 - int(e.pending.by)
			var a: Dictionary = e.cpu_action(p, g % 3)
			match a["do"]:
				"play": ok(e.play(p, a["card"]), "cpu play legal")
				"envido": ok(e.call_envido(p, a["kind"]), "cpu envido legal")
				"truco": ok(e.call_truco(p), "cpu truco legal")
				"yes", "no":
					if e.pending.kind == "envido":
						e.answer_envido(p, a["do"] == "yes")
					else:
						e.answer_truco(p, a["do"] == "yes")
		ok(e.winner != -1, "game %d finished" % g)
		ok(e.score[e.winner] >= 15 and e.score[1 - e.winner] <= 15, "final score sane")
	print("truco: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
