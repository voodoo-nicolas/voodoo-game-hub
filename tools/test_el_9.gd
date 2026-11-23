extends SceneTree

## Headless check of the El 9 engine: opening, ladder rules, and full games played by computers.
## godot --headless --path . --script res://tools/test_el_9.gd

const E = preload("res://scripts/games/el_9/el_9_engine.gd")
const C = preload("res://scripts/games/el_9/el_9_cards.gd")
var fails := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	ok(C.number(C.make(0, 9)) == 9 and C.make(0, 9) == E.OPEN, "9 of oros id")
	ok(C.new_deck().size() == 48, "48 cards")
	for n in [2, 3, 4]:
		for g in 100:
			var e := E.new()
			e.new_game(n)
			ok(e.hi[0] == 9 and e.lo[0] == 9, "9 of oros opens")
			var total := 0
			for h in e.hands:
				total += h.size()
			var guard := 0
			while e.winner == -1 and guard < 2000:
				guard += 1
				var c := e.cpu_pick(e.turn)
				if c == -1:
					ok(e.pass_turn(e.turn), "pass legal")
				else:
					ok(e.play(e.turn, c), "play legal")
			ok(e.winner != -1, "game ends (%d seats)" % n)
	# rules
	var e2 := E.new()
	e2.new_game(3)
	ok(not e2.can_play(C.make(1, 8)), "cannot start another suit with an 8")
	ok(not e2.can_play(C.make(1, 9)) or e2.hi[0] == 9, "9 of copas playable once the 9 of oros is out")
	ok(e2.can_play(C.make(0, 10)) and e2.can_play(C.make(0, 8)), "ladder grows both ways")
	ok(not e2.can_play(C.make(0, 11)), "no gaps")
	print("el_9: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
