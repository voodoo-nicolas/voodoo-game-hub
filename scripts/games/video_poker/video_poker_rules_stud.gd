extends "res://scripts/games/video_poker/video_poker_rules.gd"

## Seven Card Stud: antes and a bring-in instead of blinds, seven cards each
## (two down, four up, one down), the best five of them play.

func hole_count() -> int:
	return 7

func board_size() -> int:
	return 0

func has_blinds() -> bool:
	return false

func last_street() -> int:
	return 4

## Antes go straight in the pot; the lowest card showing opens ("brings it in"),
## suits breaking ties.
func start(t) -> void:
	for i in t.live():
		t._post(i, t.stud_ante(), "Ante")
		t.seats[i].bet = 0  # antes go straight in the pot
	t.pot = 0
	for s in t.seats:
		t.pot += int(s.total)
	for i in t.live():
		for k in 3:
			t.seats[i].hole.append(t._deal())
			t.seats[i].up.append(k == 2)
	var low := -1
	var low_key := 999
	for i in t.live():
		var c: int = t.seats[i].hole[2]
		var key: int = Eval.value(c) * 4 + [3, 2, 1, 0][c / 13]  # clubs lowest, spades highest
		if key < low_key:
			low_key = key
			low = i
	t.bring_in = low
	t._post(low, t.stud_bring_in(), "Bring-in")
	t.seats[low].acted = true
	t.current_bet = int(t.seats[low].bet)
	t.last_raise = t.bb
	t._settle(low)

func deal_street(t) -> void:
	for i in t.live():
		t.seats[i].hole.append(t._deal())
		t.seats[i].up.append(t.street < 4)

## The best hand showing acts first from fourth street on.
func open_round(t) -> void:
	# Start the search just before the best hand showing.
	t._settle((_best_showing(t) - 1 + t.seats.size()) % t.seats.size())

func _best_showing(t) -> int:
	var best := -1
	var best_s := -1
	var i: int = t.bring_in if t.bring_in >= 0 else t.button
	for k in t.seats.size():
		i = (i + 1) % t.seats.size()
		if not t.in_hand(i):
			continue
		var s := Eval.score(t.upcards(i))
		if s > best_s:
			best_s = s
			best = i
	return best

func hand_score(hole: Array, _board: Array) -> int:
	return Eval.score(hole)

func best_cards(hole: Array, _board: Array) -> Array:
	return Eval.best_five(hole)
