extends RefCounted

## What differs between poker variants. The table (video_poker_table.gd) owns
## the shared engine (seats, betting, side pots, showdown); one of these per
## variant answers the questions that change: how many cards, how the hand is
## dealt and each street, which five cards count. This base is the community
## card game (Texas Hold'em); the other variants extend it.
##
## Stateless: the table keeps one shared instance per variant, and every method
## that acts takes the table as `t`, using its engine helpers (_post, _deal,
## _settle, _next_seat). To add a variant: extend this, then list it in the
## table's rules_for().

const Eval = preload("res://scripts/games/video_poker/video_poker_eval.gd")

## The cards in the deck, as ints (see video_poker_eval.gd). Short Deck would
## leave out the 2s to 5s: the table never assumes 52.
func new_deck() -> Array:
	return range(52)

## What a hand score says in words ("Two Pair, Kings and Sevens").
func describe(score: int) -> String:
	return Eval.describe(score)

## Cards each seat is dealt to start.
func hole_count() -> int:
	return 2

## The last betting round (rounds are numbered from 0).
func last_street() -> int:
	return 3

## Limit games bet the big size on this round.
func big_street(street: int) -> bool:
	return street >= 2

## Posts the forced bets, deals the hole cards and finds the first seat to act.
func start(t) -> void:
	var playing: int = t.live().size()
	var sb_seat: int = t.button if playing == 2 else t._next_seat(t.button, true)
	var bb_seat: int = t._next_seat(sb_seat, true)
	t._post(sb_seat, t.sb, "Small blind")
	t._post(bb_seat, t.bb, "Big blind")
	t.current_bet = maxi(int(t.seats[sb_seat].bet), int(t.seats[bb_seat].bet))
	t.last_raise = t.bb
	t.raises = 1  # in Limit the big blind is the round's first bet
	for k in t.hole_count():
		var i: int = t.button
		for n in playing:
			i = t._next_seat(i, true)
			t.seats[i].hole.append(t._deal())
	t._settle(bb_seat)

## Deals what a new betting round (t.street, already counted up) brings.
func deal_street(t) -> void:
	t.deck.pop_back()  # burn
	if t.street == 1:
		for k in 3:
			t.board.append(t._deal())
	else:
		t.board.append(t._deal())

## Finds who acts first on a new betting round.
func open_round(t) -> void:
	t._settle(t.button)

## True when the draw phase comes after betting round `street`.
func draw_phase_after(_street: int) -> bool:
	return false

## One int, bigger wins (see video_poker_eval.gd).
func hand_score(hole: Array, board: Array) -> int:
	return Eval.score(hole + board)

## The five cards that make that hand.
func best_cards(hole: Array, board: Array) -> Array:
	return Eval.best_five(hole + board)
