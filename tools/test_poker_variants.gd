extends SceneTree

## Headless check of Poker's newer variants: Short Deck, Pineapple, Crazy
## Pineapple and Omaha Hi-Lo (video_poker_rules_<variant>.gd, _eval_short.gd,
## _eval_low.gd and the table's discard phase and split pots): hand rankings
## with known cards, a Hi-Lo pot split worked out by hand (odd chip, scoop, side
## pot), the discard phase in the right place, every seat down to two cards at
## showdown, and ~500 seeded random hands per variant for conserved chips.
## godot --headless --path . --script res://tools/test_poker_variants.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")
const Short = preload("res://scripts/games/video_poker/video_poker_eval_short.gd")
const Low = preload("res://scripts/games/video_poker/video_poker_eval_low.gd")
const AI = preload("res://scripts/games/video_poker/video_poker_ai.gd")

var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	_short()
	_low()
	_pineapple_scores()
	_hilo_split()
	_discard_phase()
	for v in ["short", "pineapple", "crazy", "omahahilo"]:
		_random_hands(v)
		_computer_play(v)
	print("poker variants: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)

## "As Kd 9h" -> cards (suits s h d c = 0..3, ranks A23456789TJQK).
func h(text: String) -> Array:
	var out: Array = []
	for tok in text.split(" ", false):
		out.append("shdc".find(tok[1]) * 13 + "A23456789TJQK".find(tok[0]))
	return out

# ---------- Short Deck ----------

func _short() -> void:
	var s := func(t: String): return Short.score(h(t))
	ok(s.call("Ah Kh Qh Jh Th") > s.call("9s 9d 9h Ks Kd"), "a flush beats a full house")
	ok(s.call("Ah Kh Qh 9h 7h") > s.call("9s 9d 9h Ks Kd"), "a flush beats a full house (any)")
	ok(s.call("9s 9d 9h Ks Qd") > s.call("6s 7d 8h 9c Td"), "three of a kind beats a straight")
	ok(s.call("6s 7d 8h 9c Td") > s.call("As Ad Kh Kc Qd"), "a straight beats two pair")
	ok(s.call("As 6d 7h 8c 9d") > s.call("As Ad Kh Kc Qd"), "A-6-7-8-9 is a straight")
	ok(s.call("6s 7d 8h 9c Td") > s.call("As 6d 7h 8c 9d"), "the wheel is the lowest straight")
	ok(s.call("As Kd Qh Jc Td") > s.call("6s 7d 8h 9c Td"), "broadway is the highest")
	ok(Short.describe(s.call("As 6d 7h 8c 9d")) == "Straight, Nine high", "the wheel reads nine high: " + Short.describe(s.call("As 6d 7h 8c 9d")))
	ok(Short.type_of(s.call("9s 9d 9h Ks Qd")) == Eval.TRIPS and Short.type_of(s.call("6s 7d 8h 9c Td")) == Eval.STRAIGHT, "types stay the usual ones")
	ok(Short.type_of(s.call("Ah Kh Qh 9h 7h")) == Eval.FLUSH and Short.type_of(s.call("9s 9d 9h Ks Kd")) == Eval.FULL_HOUSE, "flush and full house types")
	ok(Short.describe(s.call("Ah Kh Qh 9h 7h")).begins_with("Flush"), "describes a flush")
	var sf: int = s.call("6h 7h 8h 9h Ah")
	ok(Short.type_of(sf) == Eval.STRAIGHT_FLUSH and sf > s.call("Ah Ad Ac As Kd"), "the ace-low straight flush beats quads")
	ok(s.call("Ah Ad Ac As Kd") > s.call("Ah Kh Qh 9h 7h"), "quads beat a flush")
	var best := Short.best_five(h("9s 9d 9h Ks Qd 6c 7c"))
	ok(best.size() == 5 and Short.score(best) == s.call("9s 9d 9h Ks Qd"), "best five of seven (trips over the straight draw)")
	ok(Table.rules_for("short").hand_score(h("As Kd"), h("Qh Jc Td 6s 7s")) == s.call("As Kd Qh Jc Td"), "the rules score hole plus board")
	ok(Table.rules_for("short").new_deck().size() == 36, "36 cards")

# ---------- lows ----------

func _low() -> void:
	var f := func(t: String): return Low.five_score(h(t))
	ok(f.call("As 2d 3h 4c 5d") > f.call("As 2d 3h 4c 6d"), "the wheel is the best low")
	ok(f.call("As 2d 3h 4c 6d") > f.call("As 2d 3h 5c 6d"), "6-4-3-2-A beats 6-5-3-2-A")
	ok(f.call("7s 5d 4h 2c Ad") > f.call("8s 5d 4h 2c Ad"), "a seven low beats an eight low")
	ok(f.call("As 2d 3h 4c 9d") == -1, "a nine does not qualify")
	ok(f.call("As 2d 2h 4c 5d") == -1, "a pair is no low")
	ok(f.call("Ks 2d 3h 4c 5d") == -1, "a king does not qualify")
	ok(Low.describe(f.call("8s 6d 4h 2c Ad")) == "8-6-4-2-A", "reads 8-6-4-2-A: " + Low.describe(f.call("8s 6d 4h 2c Ad")))
	ok(Low.describe(f.call("As 2d 3h 4c 5d")) == "5-4-3-2-A", "reads the wheel")
	# exactly two from the hand and three from the board
	var b := Low.best(h("As 2d 9h Kc"), h("3h 4c 5d 9s Kd"))
	ok(int(b.score) == f.call("As 2d 3h 4c 5d"), "two hole cards and three board cards make the wheel")
	b = Low.best(h("As 9d Th Kc"), h("2h 3c 4d 5s 6d"))
	ok(int(b.score) == -1, "one low hole card is not enough")
	b = Low.best(h("As 2d 3h Kc"), h("4c 5d 6s Kd Qs"))
	ok(int(b.score) == f.call("As 2d 4c 5d 6s"), "a qualifying low is found (6-5-4-2-A)")
	b = Low.best(h("As 2d 3h Kc"), h("9c Kd Qs"))
	ok(int(b.score) == -1, "no three low board cards: no low")
	ok(Low.best(h("As 2d 3h Kc"), h("4c 5d")).score == -1, "fewer than three board cards: no low")

# ---------- Pineapple scores ----------

func _pineapple_scores() -> void:
	var r = Table.rules_for("pineapple")
	var board := h("Ks Kd 7c 2h 3d")
	# three hole cards count as the best two of them
	var with3: int = r.hand_score(h("Kh 2c 9d"), board)
	ok(with3 == Eval.score(h("Kh 2c Ks Kd 7c 2h 3d")), "keeps the two that make the best hand")
	ok(r.hand_score(h("Kh 2c"), board) == Eval.score(h("Kh 2c Ks Kd 7c 2h 3d")), "two cards score as in Hold'em")
	ok(r.auto_discard(h("Kh 2c 9d"), board) == [2], "the spare card is the one that helps least")
	ok(r.can_discard(h("Kh 2c 9d"), [1]) and not r.can_discard(h("Kh 2c 9d"), []) and not r.can_discard(h("Kh 2c 9d"), [0, 1]), "exactly one card")
	ok(not r.can_discard(h("Kh 2c"), [0]), "nothing to throw away from two cards")
	ok(r.draw_phase_after(0) and not r.draw_phase_after(1), "Pineapple: before the flop")
	var c = Table.rules_for("crazy")
	ok(c.draw_phase_after(1) and not c.draw_phase_after(0), "Crazy Pineapple: after the flop betting")
	ok(not r.draw_replaces() and Table.rules_for("draw").draw_replaces(), "a dropped card is not replaced")

# ---------- Hi-Lo pots ----------

func _hilo_table(holes: Array, totals: Array, board: String) -> RefCounted:
	var t = Table.new()
	t.variant = "omahahilo"
	t.limit = "pl"
	t.sb = 10
	t.bb = 20
	for i in holes.size():
		var s := Table.new_seat("P%d" % i, 1000, 0)
		s.hole = h(holes[i])
		s.total = totals[i]
		s.stack = 1000 - totals[i]
		t.seats.append(s)
	t.board = h(board)
	t.button = 0
	t.phase = "bet"
	return t

func _hilo_split() -> void:
	# seat 0 has the best high (trip kings), seat 1 the best low (8-5-3-2-A), seat 2 a worse low
	var t = _hilo_table(["Kd Kh 9c 9s", "Ah 3c Td Ts", "4h 6c Qs Qh"], [100, 100, 100], "2d 5h 8s Kc Jd")
	t._showdown()
	ok(t.phase == "done" and t.chips_total() == 3000, "chips conserved")
	ok(int(t.seats[0].won) == 150 and int(t.seats[1].won) == 150 and int(t.seats[2].won) == 0, "the pot is split: high 150, low 150 (%d %d %d)" % [t.seats[0].won, t.seats[1].won, t.seats[2].won])
	var r1: Dictionary = t.results[0] if int(t.results[0].seat) == 1 else t.results[1]
	ok(int(r1.low_won) == 150 and str(r1.low_desc) == "8-5-3-2-A", "the low winner's result says so (%s)" % str(r1.low_desc))
	# an odd pot: the high gets the odd chip
	t = _hilo_table(["Kd Kh 9c 9s", "Ah 3c Td Ts", "4h 6c Qs Qh"], [101, 101, 101], "2d 5h 8s Kc Jd")
	t._showdown()
	ok(int(t.seats[0].won) == 152 and int(t.seats[1].won) == 151, "the odd chip goes to the high (%d %d)" % [t.seats[0].won, t.seats[1].won])
	# a scoop: one hand has both the best high and the best low
	t = _hilo_table(["Ac 3c Kd Kh", "Ah 2c 9s 9d", "4h 6c Qs Qh"], [100, 100, 100], "2d 5h 8s Kc Jd")
	t._showdown()
	ok(int(t.seats[0].won) == 300, "a scoop takes the whole pot (%d)" % int(t.seats[0].won))
	# no qualifying low: the high takes everything
	t = _hilo_table(["Kd Kh 9c 9s", "Ah 3c Td Ts", "4h 6c Qs Qd"], [100, 100, 100], "Jd 9h Tc Kc Qh")
	t._showdown()
	var total := 0
	for s in t.seats:
		total += int(s.won)
	ok(total == 300, "all chips paid")
	var lows := 0
	for r in t.results:
		lows += 1 if int(r.low) >= 0 else 0
	ok(lows == 0 and int(t.seats[0].won) + int(t.seats[1].won) + int(t.seats[2].won) == 300, "no low on this board")
	# a tie for low splits the low half
	t = _hilo_table(["Kd Kh 9c 9s", "Ah 3c Td Ts", "As 3d Qs Qh"], [100, 100, 100], "2d 5h 8s Kc Jd")
	t._showdown()
	ok(int(t.seats[0].won) == 150 and int(t.seats[1].won) == 75 and int(t.seats[2].won) == 75, "tied lows share the low half (%d %d %d)" % [t.seats[0].won, t.seats[1].won, t.seats[2].won])
	# a side pot: the short stack has the best low but can only win what it covered
	t = _hilo_table(["Kd Kh 9c 9s", "Ah 3c Td Ts", "4h 6c Qs Qh"], [100, 40, 100], "2d 5h 8s Kc Jd")
	t._showdown()
	# main pot 120 (40 each): high 60 to seat 0, low 60 to seat 1; side pot 120 (60 each from seats 0 and 2): no low for seat 1 there; seat 2 has a low: low 60, high 60
	ok(int(t.seats[1].won) == 60, "the short stack wins half of the main pot only (%d)" % int(t.seats[1].won))
	ok(int(t.seats[0].won) + int(t.seats[1].won) + int(t.seats[2].won) == 240, "all chips paid out")
	ok(int(t.seats[2].won) == 60 and int(t.seats[0].won) == 120, "the side pot is split between its two (%d %d)" % [t.seats[0].won, t.seats[2].won])

# ---------- the discard phase ----------

func _step(t, arng: RandomNumberGenerator) -> bool:
	if t.phase == "draw":
		var rules = t.rules()
		var hole: Array = t.seats[t.to_act].hole
		var drop: Array = rules.auto_discard(hole, t.board)
		return t.draw(drop)
	var l: Dictionary = t.legal()
	var r := arng.randf()
	if r < 0.12 and not l.can_check:
		return t.act("fold")
	if r < 0.7:
		return t.act("call" if int(l.to_call) > 0 else "check")
	if l.can_raise:
		return t.act("raise", arng.randi_range(int(l.min_to), int(l.max_to)))
	return t.act("call")

func _table(variant: String, n: int, stack: int) -> RefCounted:
	var t = Table.new()
	t.variant = variant
	t.limit = "pl" if variant == "omahahilo" else "nl"
	t.sb = 10
	t.bb = 20
	for i in n:
		t.seats.append(Table.new_seat("P%d" % i, stack, 0))
	return t

func _discard_phase() -> void:
	for v in ["pineapple", "crazy"]:
		var t = _table(v, 3, 1000)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		var arng := RandomNumberGenerator.new()
		arng.seed = 5
		var with_phase := 0
		for hand in 30:
			if t.players_left() < 2:
				for s in t.seats:
					s.stack = 1000
			ok(t.start_hand(rng), v + ": starts")
			for s in t.seats:
				if not s.out:
					ok(s.hole.size() == 3, v + ": three hole cards")
			var seen_draw := false
			var board_at_draw := -1
			var guard := 0
			while t.phase != "done" and guard < 100:
				guard += 1
				if t.phase == "draw":
					seen_draw = true
					board_at_draw = t.board.size()
				ok(_step(t, arng), v + ": a move was accepted")
			if seen_draw:
				with_phase += 1
				ok(board_at_draw == (0 if v == "pineapple" else 3), "%s: discard with %d board cards (%d)" % [v, 0 if v == "pineapple" else 3, board_at_draw])
				for s in t.seats:
					if not s.folded and not s.out:
						ok(s.hole.size() == 2, "%s: a hand that reaches the end holds two cards (%d)" % [v, s.hole.size()])
		ok(with_phase >= 5, "%s: the discard phase came up in %d of 30 hands" % [v, with_phase])

# ---------- seeded random hands ----------

func _random_hands(variant: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var arng := RandomNumberGenerator.new()
	arng.seed = 78
	var showdowns := 0
	var splits := 0
	for n in [2, 3, 5, 6]:
		var t = _table(variant, n, 1000)
		for hand in 40:
			if t.players_left() < 2:
				for s in t.seats:
					s.stack = [60, 200, 1000][arng.randi_range(0, 2)]
			var before: int = t.chips_total()
			var tag := "%s/%d/%d" % [variant, n, hand]
			ok(t.start_hand(rng), tag + ": starts")
			var guard := 0
			while t.phase != "done" and guard < 300:
				guard += 1
				if not _step(t, arng):
					ok(false, tag + ": a move was refused in phase " + t.phase)
					break
			ok(t.phase == "done" and t.chips_total() == before, tag + ": ends with the chips conserved")
			var won := 0
			for s in t.seats:
				won += int(s.won)
			if not t.results.is_empty() and bool(t.results[0].shown):
				showdowns += 1
				for r in t.results:
					if variant in ["pineapple", "crazy"]:
						ok(t.seats[int(r.seat)].hole.size() == 2, tag + ": two cards at the showdown")
					if int(r.low) >= 0 and int(r.low_won) > 0:
						splits += 1
					ok(int(r.low_won) <= int(r.won), tag + ": the low share is part of the win")
			if variant == "short":
				for s in t.seats:
					for c in s.hole:
						ok(c % 13 == 0 or c % 13 >= 5, tag + ": a short deck card")
	ok(showdowns > 20, variant + ": reached showdowns (%d)" % showdowns)
	if variant == "omahahilo":
		ok(splits > 0, "some pots were won in part by a low (%d)" % splits)

## The computer players and the coach play every new variant with legal moves.
func _computer_play(variant: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var t = _table(variant, 3, 1500)
	t.seats[0].kind = 1
	var coached := 0
	for hand in 12:
		if t.players_left() < 2:
			for s in t.seats:
				s.stack = 1500
		ok(t.start_hand(rng), variant + ": starts")
		var guard := 0
		while t.phase != "done" and guard < 150:
			guard += 1
			if int(t.seats[t.to_act].kind) == 1:
				var adv: Dictionary = AI.advise(t.to_dict(), rng.randi())
				ok(str(adv.hand) != "" or t.seats[t.to_act].hole.is_empty(), variant + ": the coach describes the hand")
				if str(adv.advice) != "":
					coached += 1
			var move: Dictionary = AI.decide(t.to_dict(), 0, rng.randi())
			var done: bool = false
			if str(move.action) == "draw":
				done = t.draw(move.get("discards", []))
			else:
				done = t.act(str(move.action), int(move.get("amount", 0)))
				if not done:
					done = t.act("check") or t.act("fold")
			ok(done, "%s: the computer's move (%s) was accepted" % [variant, str(move)])
			if not done:
				break
		ok(t.phase == "done", variant + ": the computer-played hand ends")
	ok(coached > 0, variant + ": the coach gave advice")
