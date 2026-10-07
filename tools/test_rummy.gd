extends SceneTree

## Headless check of the Rummy engine: meld rules, laying off, and full hands
## played out by two computers with every card accounted for.
## godot --headless --path . --script res://tools/test_rummy.gd

const E = preload("res://scripts/games/rummy/rummy_engine.gd")

func _c(rank: int, suit: int) -> int:
	return suit * 13 + rank - 1

func _count(e) -> int:
	var n: int = e.hands[0].size() + e.hands[1].size() + e.stock.size() + e.discard.size()
	for m in e.melds:
		n += m.cards.size()
	return n

## Player 0 plays like a simple bot so whole hands can be simulated.
func _bot_turn(e) -> void:
	if e.draw_stock(0) < 0:
		if e.draw_discard(0) < 0:
			e.phase = "over"
			return
	for g in E.best_melds(e.hands[0]):
		e.meld(0, g)
		if e.phase == "over":
			return
	for c in e.hands[0].duplicate():
		for i in e.melds.size():
			if c in e.hands[0] and e.can_lay_off(c, e.melds[i]):
				e.lay_off(0, c, i)
				if e.phase == "over":
					return
	for c in e.hands[0]:
		if c != e.drew_discard:
			e.do_discard(0, c)
			return
	e.do_discard(0, e.hands[0][0])

func _init() -> void:
	var fails := 0
	# Classification.
	var info := {}
	if E.classify([_c(7, 0), _c(7, 1), _c(7, 2)]) != "set": fails += 1; print("FAIL: set")
	if E.classify([_c(7, 0), _c(7, 1), _c(7, 2), _c(7, 3)]) != "set": fails += 1; print("FAIL: set of four")
	if E.classify([_c(7, 0), _c(7, 1), _c(7, 1)]) != "": fails += 1; print("FAIL: duplicate suit set")
	if E.classify([_c(4, 2), _c(5, 2), _c(6, 2)], info) != "run" or info.lo != 4 or info.hi != 6: fails += 1; print("FAIL: run")
	if E.classify([_c(1, 2), _c(2, 2), _c(3, 2)], info) != "run" or info.lo != 1: fails += 1; print("FAIL: low ace run")
	if E.classify([_c(12, 3), _c(13, 3), _c(1, 3)], info) != "run" or info.hi != 14: fails += 1; print("FAIL: high ace run")
	if E.classify([_c(13, 3), _c(1, 3), _c(2, 3)]) != "": fails += 1; print("FAIL: wrapping run")
	if E.classify([_c(4, 2), _c(5, 2), _c(7, 2)]) != "": fails += 1; print("FAIL: gap")
	if E.classify([_c(4, 2), _c(5, 1), _c(6, 2)]) != "": fails += 1; print("FAIL: mixed suits")
	if E.classify([_c(4, 2), _c(5, 2)]) != "": fails += 1; print("FAIL: too short")
	# Melding and laying off.
	var e = E.new()
	e.new_match()
	e.turn = 0
	e.phase = "play"
	e.hands[0] = [_c(4, 2), _c(5, 2), _c(6, 2), _c(7, 2), _c(7, 0), _c(9, 3)]
	e.hands[1] = [_c(2, 0), _c(3, 0)]
	if not e.meld(0, [_c(4, 2), _c(5, 2), _c(6, 2)]) or e.melds.size() != 1: fails += 1; print("FAIL: meld")
	if not e.can_lay_off(_c(7, 2), e.melds[0]) or e.can_lay_off(_c(9, 2), e.melds[0]) or e.can_lay_off(_c(7, 0), e.melds[0]): fails += 1; print("FAIL: can_lay_off")
	if not e.lay_off(0, _c(7, 2), 0) or e.melds[0].hi != 7 or e.melds[0].cards.size() != 4: fails += 1; print("FAIL: lay_off")
	if e.lay_off(0, _c(7, 0), 0): fails += 1; print("FAIL: bad lay_off accepted")
	e.drew_discard = -1
	if not e.do_discard(0, _c(9, 3)) or e.turn != 1 or e.phase != "draw": fails += 1; print("FAIL: discard")
	# Going out by melding everything wins and scores the other hand.
	e.new_match()
	e.turn = 0
	e.phase = "play"
	e.hands[0] = [_c(4, 2), _c(5, 2), _c(6, 2)]
	e.hands[1] = [_c(13, 0), _c(2, 0)]
	e.meld(0, [_c(4, 2), _c(5, 2), _c(6, 2)])
	if e.phase != "over" or e.winner != 0 or e.scores[0] != 12: fails += 1; print("FAIL: go out ", e.phase, e.winner, e.scores)
	# Best meld finder.
	var groups: Array = E.best_melds([_c(3, 0), _c(3, 1), _c(3, 2), _c(4, 0), _c(5, 0), _c(9, 3)])
	var covered := 0
	for g in groups: covered += g.size()
	if covered < 3: fails += 1; print("FAIL: best_melds ", groups)
	# Full simulated hands.
	var finished := 0
	var draws := 0
	for g in 150:
		e.new_match()
		var guard := 0
		while e.phase != "over" and guard < 600:
			guard += 1
			if _count(e) != 52:
				fails += 1
				print("FAIL: card count ", _count(e))
				break
			if e.turn == 0:
				_bot_turn(e)
			else:
				e.cpu_turn()
		if e.phase != "over":
			fails += 1
			print("FAIL: hand never ended")
		else:
			finished += 1
			if e.winner < 0:
				draws += 1
	print("hands finished ", finished, " draws ", draws)
	var d: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var e2 = E.new()
	if not e2.from_dict(d) or e2.hands != e.hands or e2.melds != e.melds or e2.scores != e.scores:
		fails += 1
		print("FAIL: save round trip")
	print("rummy: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
