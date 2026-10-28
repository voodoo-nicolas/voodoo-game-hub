extends SceneTree

## Headless rules check of the poker engine (Poker, id video_poker): hand
## values, legal bets (No limit / Pot limit / Limit), side pots, Draw and Stud
## rules, the JSON save round trip, and a seeded run of ~1000 random hands
## that checks chips never appear or vanish. The run's fingerprint (GOLDEN)
## pins the engine's behaviour: it must stay the same through refactors and
## change only on purpose (then paste the new value from the output).
## Pure logic: touches no saves.
## godot --headless --path . --script res://tools/test_poker_rules.gd

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")
const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")

const RulesHoldem = preload("res://scripts/games/video_poker/video_poker_rules_holdem.gd")

const GOLDEN := "f4a8f5635166e88f6678cbc3d45dc598"

## Stands in for Short Deck's deck (no 2s to 5s; scoring stays standard): proves
## the engine never assumes 52 cards.
class Deck36 extends RulesHoldem:
	func new_deck() -> Array:
		return range(52).filter(func(c): return c % 13 == 0 or c % 13 >= 5)

const CONFIGS := [["holdem", "nl"], ["holdem", "pl"], ["holdem", "fl"], ["omaha", "pl"], ["omaha", "nl"],
	["omaha", "fl"], ["draw", "nl"], ["draw", "pl"], ["draw", "fl"], ["stud", "fl"]]

var fails := 0
var stats := {"hands": 0, "showdowns": 0, "side_pots": 0, "all_ins": 0, "draws": 0, "clone_steps": 0}

func _init() -> void:
	_eval()
	_omaha()
	_betting()
	_side_pots()
	_draw_rules()
	_stud()
	_short_deck()
	_traits()
	_screen_questions()
	var a := _sim(20261027)
	var b := _sim(20261027)
	ok(a == b, "the seeded run repeats exactly (no global randomness in the engine)")
	ok(int(stats.side_pots) > 0 and int(stats.showdowns) > 0 and int(stats.all_ins) > 0 and int(stats.draws) > 0,
		"the seeded run reaches showdowns, all-ins, side pots and draws: %s" % str(stats))
	var fingerprint := a.md5_text()
	print("golden fingerprint: ", fingerprint)
	if GOLDEN != "":
		ok(fingerprint == GOLDEN, "the seeded run matches GOLDEN (the engine's play changed)")
	print("poker rules: ", "OK" if fails == 0 else "%d FAILED" % fails, "  ", stats)
	quit(1 if fails else 0)

## What the screens ask the rules instead of naming a variant.
func _screen_questions() -> void:
	for v in Table.VARIANTS:
		var r = Table.rules_for(v)
		ok(r.title() != "" and r.short_title() != "", v + ": has a title")
	ok(Table.rules_for("stud").forced_limit() == "fl" and Table.rules_for("holdem").forced_limit() == "", "only Stud forces Limit")
	ok(Table.rules_for("stud").has_up_cards() and not Table.rules_for("draw").has_up_cards(), "only Stud has face-up cards")
	ok(not Table.rules_for("stud").has_dealer_button() and Table.rules_for("omaha").has_dealer_button(), "Stud has no dealer button")
	ok(Table.rules_for("holdem").round_note(null) == "", "Hold'em has no round note")

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

## "As Kd 9h" -> cards. Suits s h d c are 0..3 (spades first), ranks A23456789TJQK.
func h(text: String) -> Array:
	var out: Array = []
	for tok in text.split(" ", false):
		out.append("shdc".find(tok[1]) * 13 + "A23456789TJQK".find(tok[0]))
	return out

func sc(text: String) -> int:
	return Eval.score(h(text))

func shuffled(rng: RandomNumberGenerator) -> Array:
	var d: Array = range(52)
	for i in range(51, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = d[i]
		d[i] = d[j]
		d[j] = t
	return d

func mk(variant: String, limit: String, stacks: Array, sb: int = 10, bb: int = 20) -> RefCounted:
	var t = Table.new()
	t.variant = variant
	t.limit = limit
	t.sb = sb
	t.bb = bb
	for i in stacks.size():
		t.seats.append(Table.new_seat("P%d" % i, stacks[i], 1 if i == 0 else 0))
	return t

# ---------- hand values ----------

func _eval() -> void:
	var cats := [8, 8, 7, 6, 5, 4, 3, 2, 1, 0]
	for i in Eval.EXAMPLES.size():
		ok(Eval.category(Eval.score(Eval.EXAMPLES[i])) == cats[i], "EXAMPLES[%d] has category %d" % [i, cats[i]])
	ok(Eval.is_royal(sc("As Ks Qs Js Ts")), "royal flush")
	ok(not Eval.is_royal(sc("Ks Qs Js Ts 9s")), "a king-high straight flush is not royal")
	# Strictly weaker to stronger, across every category and its kickers.
	var chain := ["2c 3d 4h 5s 7d", "2c 3d 4h 5s 8d", "As Kd Qh Jc 9d",
		"2c 2d 3h 4s 5d", "2c 2d 3h 4s 6d", "3c 3d 2h 4s 5d", "As Ad 2h 3c 4d",
		"3c 3d 2h 2s 4d", "3c 3d 2h 2s 5d", "4c 4d 2h 2s 3d", "As Ad Kh Kc Qd",
		"2c 2d 2h 3s 4d", "3c 3d 3h 2s 4d",
		"Ac 2d 3h 4s 5d", "2c 3d 4h 5s 6d", "Tc Jd Qh Ks Ad",
		"2c 4c 6c 8c Tc", "2c 4c 6c 8c Qc", "3c 4c 6c 8c Qc",
		"2c 2d 2h 3s 3d", "2c 2d 2h 4s 4d", "3c 3d 3h 2s 2d",
		"2c 2d 2h 2s 3d", "2c 2d 2h 2s 4d", "3c 3d 3h 3s 2d",
		"Ac 2c 3c 4c 5c", "6c 7c 8c 9c Tc", "9c Tc Jc Qc Kc", "Ac Kc Qc Jc Tc"]
	for i in range(1, chain.size()):
		ok(sc(chain[i]) > sc(chain[i - 1]), "%s beats %s" % [chain[i], chain[i - 1]])
	ok(sc("As Kd Qh Jc 9d") == sc("Ac Kh Qd Js 9h"), "same ranks, other suits: a split")
	ok(sc("Ac 2d 3h 4s 5d") < sc("2c 3d 4h 5s 6d"), "the wheel is the lowest straight")
	# Seven cards: the best five play.
	ok(sc("As Ad Ah Ks Kd Kh 2c") == sc("As Ad Ah Ks Kd"), "two trips: full house, aces over kings")
	ok(sc("As Ad Kh Kd Qh Qd 2c") == sc("As Ad Kh Kd Qc"), "three pairs: the best kicker is the third pair")
	ok(sc("9c 9d 9h 9s Ac Kd Kh") == sc("9c 9d 9h 9s Ac"), "quads with a pair beside: the ace kicks")
	ok(Eval.category(sc("2h 4h 6h 8h Th 9c 7d")) == Eval.FLUSH, "a flush beats the straight inside the same seven")
	ok(Eval.category(sc("5h 6h 7h 8h 9h Ah Ad")) == Eval.STRAIGHT_FLUSH and (sc("5h 6h 7h 8h 9h Ah Ad") >> 16) & 15 == 9,
		"a straight flush hidden in seven cards")
	ok((sc("Ah 2h 3h 4h 5h Kd Kc") >> 16) & 15 == 5 and Eval.category(sc("Ah 2h 3h 4h 5h Kd Kc")) == Eval.STRAIGHT_FLUSH,
		"steel wheel is a five-high straight flush")
	ok((sc("Ac 2d 3h 4s 5d 6c") >> 16) & 15 == 6, "A-2-3-4-5-6 is a six-high straight")
	ok((sc("5c 5d 6h 7s 8d 9c") >> 16) & 15 == 9, "a straight with a pair inside")
	ok(sc("Ah Kh Qh 2h 3h 9h") == sc("Ah Kh Qh 9h 3h"), "six of a suit: the top five play")
	ok(Eval.describe(sc("As Ad Kh Kd Qc")) != "", "describe() says something")
	# The fast five-card path agrees with the general one.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := 0
	for n in 30000:
		var d := shuffled(rng)
		if Eval.score5(d[0], d[1], d[2], d[3], d[4]) != Eval.score(d.slice(0, 5)):
			bad += 1
			if bad <= 3:
				print("  score5 differs for ", d.slice(0, 5))
	ok(bad == 0, "score5 == score on 30000 random hands (%d differ)" % bad)
	bad = 0
	for n in 400:
		var d2 := shuffled(rng)
		for size in [5, 6, 7]:
			var cards: Array = d2.slice(0, size)
			if Eval.score(Eval.best_five(cards)) != Eval.score(cards):
				bad += 1
	ok(bad == 0, "best_five holds the same value as the whole hand (%d differ)" % bad)
	ok(Eval.combos(7, 5).size() == 21 and Eval.combos(52, 2).size() == 1326, "combos() counts")

func _omaha() -> void:
	var board := h("2h 5h 9h Jh Kh")
	var hole := h("Ah 3c 4d 8s")
	ok(Eval.category(Eval.score_omaha(hole, board)) != Eval.FLUSH, "Omaha: one heart in hand makes no flush")
	ok(Eval.category(Eval.score(hole + board)) == Eval.FLUSH, "...where Hold'em rules would")
	var royal_board := h("As Ks Qs Js Ts")
	var junk := h("2c 3d 4h 5c")
	ok(Eval.category(Eval.score_omaha(junk, royal_board)) == Eval.HIGH_CARD, "Omaha: a royal on the board is not yours")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bad := 0
	for n in 200:
		var d := shuffled(rng)
		var hl: Array = d.slice(0, 4)
		var bd: Array = d.slice(4, 9)
		if Eval.score(Eval.best_five(bd, hl)) != Eval.score_omaha(hl, bd):
			bad += 1
	ok(bad == 0, "Omaha best_five == score_omaha (%d differ)" % bad)

# ---------- betting ----------

func _betting() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# Three-handed No limit: the button acts first preflop.
	var t = mk("holdem", "nl", [1000, 1000, 1000])
	ok(t.start_hand(rng), "3 seats can start a hand")
	ok(t.button == 0 and t.to_act == 0 and t.seats[1].bet == 10 and t.seats[2].bet == 20, "blinds and first to act")
	var l: Dictionary = t.legal()
	ok(l.to_call == 20 and not l.can_check and l.can_raise and l.min_to == 40 and l.max_to == 1000, "NL opening range: %s" % str(l))
	ok(t.act("raise", 100), "NL raise to 100")
	l = t.legal()  # seat 1, 10 in
	ok(l.to_call == 90 and l.min_to == 180, "NL min re-raise is the last raise again (180): %s" % str(l))
	# Pot limit: the pot after calling, then raise by that.
	t = mk("holdem", "pl", [1000, 1000, 1000])
	t.start_hand(rng)
	l = t.legal()
	ok(l.min_to == 40 and l.max_to == 70, "PL opening max is 70 (call 20 into a 30 pot): %s" % str(l))
	# Limit: fixed raise, capped at a bet and three raises.
	t = mk("holdem", "fl", [1000, 1000, 1000])
	t.start_hand(rng)
	l = t.legal()
	ok(l.min_to == 40 and l.max_to == 40, "FL raise is fixed: %s" % str(l))
	t.act("raise")
	t.act("raise")
	t.act("raise")
	l = t.legal()
	ok(not l.can_raise and l.to_call == 40, "FL: capped after the big blind and three raises: %s" % str(l))
	# Short stacks.
	t = mk("holdem", "nl", [15, 1000, 1000])
	t.start_hand(rng)
	l = t.legal()
	ok(l.to_call == 15 and not l.can_raise, "short stack can only call all in: %s" % str(l))
	t.act("allin")
	ok(t.seats[0].allin and t.seats[0].total == 15 and t.seats[0].stack == 0, "all in for 15")
	# A fold with nothing to call is a check.
	t = mk("holdem", "nl", [1000, 1000])
	t.start_hand(rng)
	ok(t.button == 0 and t.to_act == 0 and t.seats[0].bet == 10 and t.seats[1].bet == 20, "heads-up: the button posts the small blind and acts first")
	t.act("call")
	ok(t.to_act == 1 and t.legal().can_check, "heads-up: the big blind has the option")
	t.act("fold")
	ok(not t.seats[1].folded and t.last_event.action == "check", "folding with nothing to call is a check")
	ok(t.street == 1 and t.board.size() == 3 and t.to_act == 1, "flop: the non-button acts first heads-up")
	# Everyone folds: the pot goes to the last seat, and every chip is paid.
	t = mk("holdem", "nl", [1000, 1000])
	t.start_hand(rng)
	t.act("fold")
	ok(t.phase == "done" and t.seats[0].stack == 990 and t.seats[1].stack == 1010 and t.results[0].seat == 1, "SB folds, BB takes 30")
	# Both all in preflop: the board runs out and every chip is paid.
	t = mk("holdem", "nl", [200, 500])
	t.start_hand(rng)
	t.act("allin")
	t.act("call")
	ok(t.phase == "done" and t.board.size() == 5 and t.chips_total() == 700, "all in preflop runs the board out")

# ---------- side pots ----------

## Seats are [total put in, folded, "hole cards"]; returns each seat's stack after the showdown.
func _pots(rows: Array, board: String = "2c 7d 9h Js 3c") -> Array:
	var t = mk("holdem", "nl", rows.map(func(r): return 0))
	for i in rows.size():
		t.seats[i].total = rows[i][0]
		t.seats[i].folded = rows[i][1]
		t.seats[i].hole = h(rows[i][2])
	t.board = h(board)
	t.phase = "bet"
	t.button = 0
	t._showdown()
	var out: Array = []
	for s in t.seats:
		out.append(int(s.stack))
	return out

func _side_pots() -> void:
	# A (best) all in for 100, B for 300, C for 500; D folded 50.
	var r := _pots([[100, false, "Ah Ad"], [300, false, "Kh Kd"], [500, false, "Qh Qd"], [50, true, "Ts 8s"]])
	ok(r == [350, 400, 200, 0], "3 all-ins and a fold: %s" % str(r))
	# A tie for the main pot: the odd chip goes to the first winner after the button.
	r = _pots([[100, false, "Ah Kd"], [100, false, "Ac Ks"], [51, true, "Ts 8s"]])
	ok(r == [125, 126, 0], "a split with an odd chip: %s" % str(r))
	# A folded seat that put in more than a short all-in.
	r = _pots([[100, false, "Ah Ad"], [200, false, "Kh Kd"], [200, true, "Qh Qd"]])
	ok(r == [300, 200, 0], "folded chips go to the pots they reach: %s" % str(r))
	# The best hand among the deepest stacks only wins what it covered.
	r = _pots([[300, false, "Qh Qd"], [100, false, "Ah Ad"], [300, false, "Kh Kd"]])
	ok(r == [0, 300, 400], "a short all-in wins only its share: %s" % str(r))

# ---------- Five Card Draw and Stud ----------

func _draw_rules() -> void:
	ok(Table.can_discard(h("Ks 2d 3d 4d 5d"), [0, 1, 2]), "draw 3 is always allowed")
	ok(not Table.can_discard(h("Ks 2d 3d 4d 5d"), [1, 2, 3, 4]), "draw 4 keeping a King is not")
	ok(Table.can_discard(h("As 2d 3d 4d 5d"), [1, 2, 3, 4]), "draw 4 keeping an Ace is allowed")
	ok(not Table.can_discard(h("As 2d 3d 4d 5d"), [0, 1, 2, 3, 4]), "draw 5 is not")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t = mk("draw", "nl", [1000, 1000])
	t.start_hand(rng)
	ok(t.seats[0].hole.size() == 5, "five cards each")
	t.act("call")
	t.act("check")
	ok(t.phase == "draw" and t.to_act == 1, "after the first round: the draw, non-button first")
	t.seats[1].hole = h("Ks 2d 3d 4d 5d")
	ok(not t.draw([1, 2, 3, 4]) and t.phase == "draw" and t.to_act == 1, "an illegal draw changes nothing")
	ok(t.draw([1, 2, 3]) and t.seats[1].drew == 3 and t.to_act == 0, "legal draw, then the other seat")
	ok(t.draw([]) and t.seats[0].drew == 0, "stand pat")
	ok(t.phase == "bet" and t.street == 1 and t.current_bet == 0 and t.to_act == 1, "second betting round opens")
	ok(t.chips_total() == 2000, "no chips lost in the draw")

func _stud() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var t = mk("stud", "fl", [1000, 1000, 1000, 1000])
	ok(t.start_hand(rng), "stud starts")
	var low := -1
	var low_key := 999
	for i in 4:
		var s: Dictionary = t.seats[i]
		ok(s.hole.size() == 3 and s.up == [false, false, true], "stud seat %d: two down, one up" % i)
		var c: int = s.hole[2]
		var key: int = Eval.value(c) * 4 + [3, 2, 1, 0][c / 13]
		if key < low_key:
			low_key = key
			low = i
	ok(t.bring_in == low and t.seats[low].bet == t.stud_bring_in(), "the lowest upcard brings it in")
	ok(t.pot == 4 * t.stud_ante() and t.chips_total() == 4000, "antes are in the pot, no chip lost")
	ok(t.to_act == (low + 1) % 4, "action starts after the bring-in")

## What the computer players and the coach ask each variant's rules.
func _traits() -> void:
	var work := {"holdem": 1.0, "stud": 1.0, "draw": 2.5, "omaha": 10.0, "short": 1.0, "pineapple": 2.0, "crazy": 2.0, "omahahilo": 14.0}
	var board := {"holdem": 5, "omaha": 5, "draw": 0, "stud": 0, "short": 5, "pineapple": 5, "crazy": 5, "omahahilo": 5}
	for v in Table.VARIANTS:
		var r = Table.rules_for(v)
		ok(r.work_cost() == work[v], "%s: work cost" % v)
		ok(r.board_size() == board[v], "%s: board size" % v)
		ok(r.has_blinds() == (v != "stud"), "%s: blinds" % v)
		ok(r.has_draw() == (v == "draw"), "%s: draw phase" % v)
		ok(r.has_starting_hand_chart() == (v == "holdem"), "%s: starting-hand chart" % v)
		ok(r.new_deck().size() == (36 if v == "short" else 52), "%s: deck size" % v)
	ok(Table.rules_for("nonsense") == Table.rules_for("holdem"), "an unknown variant plays as Hold'em")

## Hold'em with a 36-card deck: hands play out, chips are conserved and only
## cards of that deck are ever dealt.
func _short_deck() -> void:
	var rng := RandomNumberGenerator.new()
	var arng := RandomNumberGenerator.new()
	rng.seed = 9
	arng.seed = 10
	for n in [2, 3, 6]:
		var t = mk("holdem", "nl", [])
		t._rules = Deck36.new()
		for i in n:
			t.seats.append(Table.new_seat("P%d" % i, 0, 0))
		ok(t.deck_cards().size() == 36, "a 36-card deck")
		for hand in 60:
			var tag := "short deck/%d/%d" % [n, hand]
			if t.players_left() < 2:
				for s in t.seats:
					s.stack = 1000
			var before: int = t.chips_total()
			ok(t.start_hand(rng), tag + ": starts")
			var active := 0
			for s in t.seats:
				active += 0 if s.out else 1
			ok(t.deck.size() == 36 - active * 2, tag + ": the deal took %d cards from 36" % (active * 2))
			var guard := 0
			while t.phase != "done" and guard < 300:
				guard += 1
				_do(t, _step(t, arng, tag), tag)
			ok(t.phase == "done" and t.chips_total() == before, tag + ": ends, chips conserved")
			var dealt: Array = t.board.duplicate()
			for s in t.seats:
				dealt.append_array(s.hole)
			for c in dealt:
				ok(c % 13 == 0 or c % 13 >= 5, tag + ": card %d is not in a short deck" % c)
			_check_end(t, tag)

# ---------- seeded random hands ----------

func _sim(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()    # the deals
	var arng := RandomNumberGenerator.new()   # this test's own choices
	rng.seed = seed_value
	arng.seed = seed_value + 1
	var log := PackedStringArray()
	for cfg in CONFIGS:
		for n in [2, 3, 6]:
			var t = Table.new()
			t.variant = cfg[0]
			t.limit = cfg[1]
			t.sb = 10
			t.bb = 20
			for i in n:
				t.seats.append(Table.new_seat("P%d" % i, 0, 0))
			for hand in 40:
				var tag := "%s/%s/%d/%d" % [cfg[0], cfg[1], n, hand]
				if t.players_left() < 2:
					for s in t.seats:
						s.stack = [60, 150, 400, 1000, 2500][arng.randi_range(0, 4)]
				var before: int = t.chips_total()
				if not t.start_hand(rng):
					ok(false, tag + ": the hand did not start")
					continue
				stats.hands += 1
				var acts := PackedStringArray()
				var guard := 0
				while t.phase != "done" and guard < 300:
					guard += 1
					var c = t.clone()
					var step := _step(t, arng, tag)
					acts.append(step.text)
					_do(t, step, tag)
					_do(c, step, tag)
					stats.clone_steps += 1
					ok(JSON.stringify(c.to_dict()) == JSON.stringify(t.to_dict()), tag + ": a clone made mid-hand plays on identically")
					ok(t.chips_total() == before, tag + ": chips conserved mid-hand")
				ok(t.phase == "done", tag + ": the hand ends")
				ok(t.chips_total() == before, tag + ": chips conserved at the end")
				_check_end(t, tag)
				var stacks := PackedStringArray()
				for s in t.seats:
					stacks.append(str(int(s.stack)))
				var res := PackedStringArray()
				for r in t.results:
					res.append("%d:%d:%d" % [r.seat, r.won, r.score])
				log.append("%s|%s|%s|%s" % [tag, ",".join(stacks), ",".join(res), ",".join(acts)])
	return "\n".join(log)

## What the next seat does: a random but legal move.
func _step(t, arng: RandomNumberGenerator, tag: String) -> Dictionary:
	if t.phase == "draw":
		var idx: Array = [0, 1, 2, 3, 4]
		for i in range(4, 0, -1):
			var j := arng.randi_range(0, i)
			var x: int = idx[i]
			idx[i] = idx[j]
			idx[j] = x
		var k := arng.randi_range(0, 3)
		var pick: Array = idx.slice(0, k)
		pick.sort()
		return {"kind": "draw", "idx": pick, "amount": 0, "text": "d%d>%s" % [t.to_act, str(pick)]}
	var l: Dictionary = t.legal()
	_check_legal(t, l, tag)
	var r := arng.randf()
	var kind := "call"
	var amount := 0
	if r < 0.12:
		kind = "fold"
	elif r < 0.65:
		kind = "call"
	elif r < 0.92 and l.can_raise:
		kind = "raise"
		amount = arng.randi_range(int(l.min_to), int(l.max_to))
	elif r >= 0.92:
		kind = "allin"
	return {"kind": kind, "idx": [], "amount": amount, "text": "%d%s%d" % [t.to_act, kind[0], amount]}

func _do(t, step: Dictionary, tag: String) -> void:
	if step.kind == "draw":
		stats.draws += 1
		ok(t.draw(step.idx), tag + ": a random legal draw was refused")
	else:
		if step.kind == "allin":
			stats.all_ins += 1
		ok(t.act(step.kind, step.amount), tag + ": a legal %s was refused" % step.kind)

func _check_legal(t, l: Dictionary, tag: String) -> void:
	var s: Dictionary = t.seats[t.to_act]
	ok(l.to_call >= 0 and l.to_call <= int(s.stack), tag + ": to_call within the stack")
	ok(l.can_check == (l.to_call == 0), tag + ": check exactly when nothing is owed")
	if l.can_raise:
		ok(l.min_to > t.current_bet and l.min_to <= l.max_to and l.max_to <= l.all_in_to, tag + ": raise range sane %s" % str(l))
		if t.limit == "fl":
			ok(l.min_to == l.max_to, tag + ": Limit raises are one size")

func _check_end(t, tag: String) -> void:
	var total_in := 0
	var won := 0
	var live_totals: Array = []
	for i in t.seats.size():
		var s: Dictionary = t.seats[i]
		total_in += int(s.total)
		won += int(s.won)
		ok(int(s.stack) >= 0, tag + ": no negative stack")
		if t.in_hand(i) and int(s.total) > 0 and not live_totals.has(int(s.total)):
			live_totals.append(int(s.total))
	ok(won == total_in, tag + ": every chip put in is paid out (%d in, %d out)" % [total_in, won])
	var seen := {}
	var all_cards: Array = t.board.duplicate()
	for s in t.seats:
		all_cards.append_array(s.hole)
	for c in all_cards:
		ok(not seen.has(c) and t.deck_cards().has(c), tag + ": card %d dealt twice or not from this deck" % c)
		seen[c] = true
	var shown := false
	var best := -1
	var best_seat := -1
	for r in t.results:
		ok(int(r.won) == int(t.seats[r.seat].won), tag + ": results match the seats")
		ok(not t.seats[r.seat].folded, tag + ": a folded seat cannot win")
		if r.shown:
			shown = true
			if int(r.score) > best:
				best = int(r.score)
				best_seat = int(r.seat)
	if shown:
		stats.showdowns += 1
		ok(int(t.seats[best_seat].won) > 0, tag + ": the best hand wins something")
		if live_totals.size() >= 2:
			stats.side_pots += 1
