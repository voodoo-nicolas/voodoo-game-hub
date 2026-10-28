extends RefCounted

## Rebuilds a recorded hand (video_poker_history.gd's format) as a list of
## tables, one per step, that the table view can draw: frame 0 is the deal with
## the forced bets in, frame k follows the k-th action, the last frame is the
## showdown (or the pot pushed to the winner). Pure: no Nodes, no saves.
##
## What a record cannot say is guessed the plain way: a Stud card is face up
## from the third on until the seventh; a Draw hand shows the old cards until
## that seat's draw; the Stud ante and bring-in sit in the pot, not on the felt.

const Table = preload("res://scripts/games/video_poker/video_poker_table.gd")

## [{"t": Table, "caption": String, "street": int, "event": int}], event = the
## index of the action just shown (-1 for the deal).
static func frames(rec: Dictionary) -> Array:
	var out: Array = []
	var seats_rec: Array = rec.get("seats", [])
	var n := seats_rec.size()
	if n == 0:
		return out
	var rules = Table.rules_for(str(rec.get("variant", "holdem")))
	var ev: Array = rec.get("ev", [])
	var board_all: Array = rec.get("board", [])
	var ends := {}
	for e in rec.get("end", []):
		ends[int(e[0])] = e[1]
	var stack0: Array = []
	var put: Array = []        # chips each seat has put in so far
	var round_bet: Array = []  # chips in front of each seat this round
	var folded: Array = []
	var acts: Array = []
	var amts: Array = []
	var drew: Array = []       # draw: has this seat drawn yet
	var stud: bool = rules.has_up_cards()
	for i in n:
		stack0.append(int(seats_rec[i].stack))
		put.append(int(seats_rec[i].get("post", 0)))
		round_bet.append(0 if stud else int(seats_rec[i].get("post", 0)))
		folded.append(false)
		acts.append("")
		amts.append(0)
		drew.append(false)
	var street := 0
	out.append(_frame(rec, rules, stack0, put, round_bet, folded, acts, amts, drew, street, ev, 0, board_all, ends, ""))
	for k in ev.size():
		var e: Array = ev[k]
		var seat := int(e[0])
		var code := str(e[1])
		var amount := int(e[2])
		var ev_street := int(e[3])
		if ev_street != street:
			street = ev_street
			for i in n:
				round_bet[i] = 0
				if not folded[i]:
					acts[i] = ""
					amts[i] = 0
		var added := int(e[5])
		put[seat] = int(put[seat]) + added
		round_bet[seat] = int(round_bet[seat]) + added
		var someone_bet := false
		for i in n:
			if i != seat and int(round_bet[i]) > 0 and street > 0:
				someone_bet = true
		match code:
			"fold":
				folded[seat] = true
				acts[seat] = "Fold"
			"check":
				acts[seat] = "Check"
			"call":
				acts[seat] = "All in" if int(e[4]) == 1 else "Call"
				amts[seat] = amount
			"raise":
				acts[seat] = "All in" if int(e[4]) == 1 else ("Raise" if someone_bet or street == 0 else "Bet")
				amts[seat] = amount
			"draw":
				acts[seat] = "Draw" if amount > 0 else "Stand pat"
				amts[seat] = amount
				drew[seat] = true
		var cap := _caption(str(seats_rec[seat].name), code, amount, int(e[4]) == 1)
		var next_street := int(ev[k + 1][3]) if k + 1 < ev.size() else street
		var swept: bool = next_street != street  # the round is over: its bets went into the pot
		var shown_bets: Array = round_bet
		var shown_acts: Array = acts
		if swept:
			shown_bets = []
			shown_acts = []
			for i in n:
				shown_bets.append(0)
				shown_acts.append("Fold" if folded[i] else "")
		out.append(_frame(rec, rules, stack0, put, shown_bets, folded, shown_acts, amts, drew, next_street, ev, k + 1, board_all, ends, cap))
		out[out.size() - 1].event = k
		out[out.size() - 1].street = street
	# the end of the hand
	var last := _frame(rec, rules, stack0, put, round_bet, folded, acts, amts, drew, street, ev, ev.size() + 1, board_all, ends, "")
	out.append(last)
	return out

static func _caption(name: String, code: String, amount: int, allin: bool) -> String:
	var who := name if name != "" else "You"
	var amt := _chips(amount)
	var text := ""
	match code:
		"fold": text = "%s folds."
		"check": text = "%s checks."
		"call": text = "%s calls %s." if not allin else "%s is all in for %s!"
		"raise": text = "%s raises to %s." if not allin else "%s is all in for %s!"
		"draw": text = "%s draws %d." if amount > 0 else "%s stands pat."
	if text == "":
		return ""
	var translated := str(TranslationServer.translate(text))
	var you := str(TranslationServer.translate("You")) if name == "" else name
	if code == "draw":
		return translated % [you, amount] if amount > 0 else translated % you
	if code in ["fold", "check"]:
		return translated % you
	return translated % [you, amt]

## `at` is how many actions are applied; ev.size() + 1 asks for the showdown.
static func _frame(rec: Dictionary, rules, stack0: Array, put: Array, round_bet: Array, folded: Array, acts: Array,
		amts: Array, drew: Array, street: int, ev: Array, at: int, board_all: Array, ends: Dictionary, caption: String) -> Dictionary:
	var seats_rec: Array = rec.seats
	var n := seats_rec.size()
	var done: bool = at > ev.size()
	var t = Table.new()
	t.variant = str(rec.get("variant", "holdem"))
	t.limit = str(rec.get("limit", "nl"))
	t.sb = int(rec.get("sb", 10))
	t.bb = int(rec.get("bb", 20))
	t.button = int(rec.get("btn", 0))
	t.hand_no = int(rec.get("n", 0))
	t.street = street
	t.phase = "done" if done else "bet"
	var net: Array = rec.get("net", [])
	var stud: bool = rules.has_up_cards()
	var total_bets := 0
	for i in n:
		var sr: Dictionary = seats_rec[i]
		var s := Table.new_seat(str(sr.name), 0, int(sr.kind))
		s.out = bool(sr.get("out", false))
		s.folded = bool(folded[i])
		s.total = int(put[i])
		s.bet = 0 if done else int(round_bet[i])
		total_bets += int(s.bet)
		s.act = "" if done else str(acts[i])
		s.amt = int(amts[i])
		var final_stack: int = stack0[i] + (int(net[i]) if i < net.size() else 0)
		s.stack = final_stack if done else stack0[i] - int(put[i])
		s.allin = not done and int(s.stack) <= 0 and not s.out
		s.hole = _hole(sr, ends.get(i, []), rules, stud, street, drew[i], done)
		var ups: Array = []
		for c in s.hole.size():
			ups.append(stud and c >= 2 and c <= 5)
		s.up = ups
		t.seats.append(s)
	var sum_put := 0
	for i in n:
		sum_put += int(put[i])
	t.pot = 0 if done else sum_put - total_bets
	t.board = _board(rules, board_all, street, done, at, ev)
	if not done and at < ev.size():
		t.to_act = int(ev[at][0])
	else:
		t.to_act = -1
	if done:
		var results: Array = []
		for r in rec.get("res", []):
			var seat := int(r[0])
			var score := int(r[2])
			var hole: Array = t.seats[seat].hole
			var shown := int(r[3]) == 1
			results.append({"seat": seat, "won": int(r[1]), "score": score,
				"desc": rules.describe(score) if score >= 0 and shown else "",
				"best": rules.best_cards(hole, t.board) if shown and int(r[1]) > 0 and score >= 0 else [],
				"shown": shown})
		t.results = results
	return {"t": t, "caption": caption, "street": street, "event": -1}

## The cards a seat has by this point.
static func _hole(sr: Dictionary, end_hole: Array, rules, stud: bool, street: int, has_drawn: bool, done: bool) -> Array:
	var start: Array = (sr.hole as Array).duplicate()
	if end_hole.is_empty():
		return start
	if done or (has_drawn and not stud):
		return (end_hole as Array).duplicate()
	if stud:
		return end_hole.slice(0, mini(end_hole.size(), 3 + street))
	return start

static func _board(rules, board_all: Array, street: int, done: bool, at: int, ev: Array) -> Array:
	if board_all.is_empty() or rules.board_size() == 0:
		return []
	if done:
		return board_all.duplicate()
	var shown := 0
	match street:
		0: shown = 0
		1: shown = 3
		2: shown = 4
		_: shown = 5
	return board_all.slice(0, mini(shown, board_all.size()))

static func _chips(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
