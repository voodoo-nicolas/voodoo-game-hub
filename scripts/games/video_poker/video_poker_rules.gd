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

## The variant's name in full and short (English keys the screens translate).
func title() -> String:
	return "Texas Hold'em"

func short_title() -> String:
	return "Hold'em"

## The cards in the deck, as ints (see video_poker_eval.gd). Short Deck would
## leave out the 2s to 5s: the table never assumes 52.
func new_deck() -> Array:
	return range(52)

## What a hand score says in words ("Two Pair, Kings and Sevens").
func describe(score: int) -> String:
	return Eval.describe(score)

## Community cards dealt in all (0 when there is no board).
func board_size() -> int:
	return 5

## True when blinds start the hand (so there is a "before the flop" with a
## big blind to raise over); false when antes and a bring-in do.
func has_blinds() -> bool:
	return true

## True when there is a draw phase.
func has_draw() -> bool:
	return false

## The usual category of a score (Eval.PAIR .. Eval.STRAIGHT_FLUSH): for the
## names and statistics, even where the scores order the hands differently.
func hand_type(score: int) -> int:
	return Eval.category(score)

# ---------- split pots (Hi-Lo) ----------

## True when half of every pot goes to the best qualifying low hand.
func is_split() -> bool:
	return false

## A seat's low hand: bigger is better, -1 when it has none.
func low_score(_hole: Array, _board: Array) -> int:
	return -1

## The five cards of that low.
func low_best(_hole: Array, _board: Array) -> Array:
	return []

## A low in words ("8-6-4-2-A").
func describe_low(_score: int) -> String:
	return ""

# ---------- discards (the phase between betting rounds) ----------

## "" no discard phase, "swap" cards are thrown away and replaced (Draw), "drop"
## they are thrown away and not replaced (Pineapple).
func discard_kind() -> String:
	return ""

## Are the discarded cards replaced (Draw), or just thrown away (Pineapple)?
func draw_replaces() -> bool:
	return discard_kind() != "drop"

## The English word for the action ("Swap", "Discard"), for buttons and labels.
func discard_word() -> String:
	return "Swap"

## What to tell the player in the discard phase.
func discard_prompt() -> String:
	return ""

## Is throwing away the cards at `indices` of `hand` allowed?
func can_discard(_hand: Array, _indices: Array) -> bool:
	return false

## The cards to throw away when nobody is asked (everyone is all in).
func auto_discard(_hole: Array, _board: Array) -> Array:
	return []

## True when Chen's starting-hand points rate the two hole cards (the
## computer's ranges and the coach's tiers; Hold'em only).
func has_starting_hand_chart() -> bool:
	return false

## How costly it is for the computer to rate one hand here, relative to
## Hold'em: the higher, the fewer deals it simulates per decision.
func work_cost() -> float:
	return 1.0

## The only betting structure this variant is played with ("fl" = Limit), or
## "" when the player picks No limit / Pot limit / Limit.
func forced_limit() -> String:
	return ""

## True when a dealer button is drawn (games with a fixed first bet, like Stud, have none).
func has_dealer_button() -> bool:
	return true

## True when some of a seat's cards are dealt face up (the table draws the
## viewer's hidden and showing cards apart).
func has_up_cards() -> bool:
	return false

## What to say about the round in progress next to the pot (an English key the
## view translates), or "".
func round_note(_t) -> String:
	return ""

## Cards a hand holds once it has made its discard (Pineapple: two).
func hole_after_discard() -> int:
	return hole_count()

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
