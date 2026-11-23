extends SceneTree

## Headless check of the Chinchón engine: meld rules, best melding, closing, scoring, and whole
## matches played by two computers.  godot --headless --path . --script res://tools/test_chinchon.gd

const E = preload("res://scripts/games/chinchon/chinchon_engine.gd")
const C = preload("res://scripts/games/chinchon/chinchon_cards.gd")
var fails := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)

func k(s: int, n: int) -> int:
	return C.make(s, n)

func _init() -> void:
	ok(E.is_meld([k(0, 4), k(0, 5), k(0, 6)]), "run 4-5-6")
	ok(E.is_meld([k(1, 6), k(1, 7), k(1, 10)]), "7 is followed by 10")
	ok(E.is_meld([k(2, 10), k(2, 11), k(2, 12)]), "10-11-12")
	ok(not E.is_meld([k(2, 11), k(2, 12), k(2, 1)]), "no wrap-around")
	ok(not E.is_meld([k(0, 4), k(1, 5), k(0, 6)]), "mixed suits")
	ok(E.is_meld([k(0, 7), k(1, 7), k(2, 7)]) and E.is_meld([k(0, 7), k(1, 7), k(2, 7), k(3, 7)]), "sets of 3 and 4")
	ok(not E.is_meld([k(0, 7), k(1, 7)]), "two is not a meld")
	var h := [k(0, 1), k(0, 2), k(0, 3), k(1, 5), k(2, 5), k(3, 5), k(1, 12)]
	var bm := E.best_melds(h)
	ok(bm.points == 10 and bm.melds.size() == 2 and bm.dead == [k(1, 12)], "two melds, dead = a 12 (10 points)")
	ok(E.deadwood([k(0, 1), k(1, 3), k(2, 5), k(3, 7), k(0, 10), k(1, 11), k(2, 12)]) == 1 + 3 + 5 + 7 + 30, "no melds")
	ok(E.is_chinchon([k(0, 2), k(0, 3), k(0, 4), k(0, 5), k(0, 6), k(0, 7), k(0, 10)]), "chinchon")
	ok(not E.is_chinchon([k(0, 1), k(0, 2), k(0, 3), k(0, 4), k(0, 5), k(0, 6), k(1, 7)]), "six + one is not")
	# closing and scoring
	var e := E.new()
	e.new_game()
	e.turn = 0
	e.hands[0] = [k(0, 1), k(0, 2), k(0, 3), k(1, 5), k(2, 5), k(3, 5), k(1, 2), k(3, 3)]
	e.hands[1] = [k(0, 4), k(1, 6), k(2, 7), k(3, 10), k(0, 11), k(1, 1), k(2, 2)]
	e.phase = "discard"
	ok(e.can_close(0, k(3, 3)) == false or true, "can_close runs")
	ok(e.can_close(0, k(3, 3)) and e.close(0, k(3, 3)) and e.result.dead[0] == 2, "close with 2 dead points")
	ok(e.score[0] == 2 and e.score[1] == E.deadwood(e.hands[1]), "scores added")
	# clean close
	e.new_round()
	e.turn = 0
	e.hands[0] = [k(0, 1), k(0, 2), k(0, 3), k(0, 5), k(1, 5), k(2, 5), k(3, 5), k(1, 7)]
	e.hands[1] = [k(0, 4), k(1, 6), k(2, 7), k(3, 10), k(0, 11), k(1, 1), k(2, 2)]
	e.score = [20, 20]
	e.phase = "discard"
	ok(e.close(0, k(1, 7)) and e.result.clean and e.score[0] == 20 - 10 + 0, "clean close = -10")
	# throw back rule
	e.new_round()
	e.turn = 0
	var top: int = e.discard.back()
	ok(e.draw_discard(0) == top and not e.can_discard(0, top), "cannot throw back the discard just taken")
	# full matches
	for g in 15:
		e = E.new()
		e.new_game()
		var guard := 0
		while e.winner == -1 and guard < 20000:
			guard += 1
			if e.round_over:
				e.new_round()
			var p: int = e.turn
			var got := -1
			if e.cpu_take_discard(p):
				got = e.draw_discard(p)
			else:
				got = e.draw_stock(p)
			ok(got != -1, "draw works")
			if got == -1:
				break
			var f: Dictionary = e.cpu_finish(p, g % 2)
			if f.close:
				ok(e.close(p, f.card), "close legal")
			else:
				ok(e.throw(p, f.card), "throw legal")
			var tot: int = e.hands[0].size() + e.hands[1].size() + e.stock.size() + e.discard.size()
			ok(tot == 40, "all 40 cards accounted for")
		ok(e.winner != -1, "match %d finished" % g)
	print("chinchon: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
