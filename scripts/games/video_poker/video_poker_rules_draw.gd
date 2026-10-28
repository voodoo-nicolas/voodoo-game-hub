extends "res://scripts/games/video_poker/video_poker_rules.gd"

## Five Card Draw: five hole cards, one betting round, a draw, one more round.
## (The draw itself is Table.draw(); this says when it happens.)

const MAX_DRAW := 3

func title() -> String:
	return "Five Card Draw"

func short_title() -> String:
	return "5-Card Draw"

func hole_count() -> int:
	return 5

func board_size() -> int:
	return 0

func has_draw() -> bool:
	return true

func discard_kind() -> String:
	return "swap"

func discard_prompt() -> String:
	return "Tap the cards to swap, then draw."

## Up to 3 cards, or 4 when the card kept is an Ace.
func can_discard(hand: Array, indices: Array) -> bool:
	if indices.size() <= MAX_DRAW:
		return true
	if indices.size() == MAX_DRAW + 1:
		for k in hand.size():
			if not indices.has(k):
				return Eval.value(hand[k]) == 14
	return false

func round_note(t) -> String:
	if t.phase == "draw":
		return "The draw"
	return "Before the draw" if t.street == 0 else "After the draw"

## The computer also simulates everyone's draw.
func work_cost() -> float:
	return 2.5

func last_street() -> int:
	return 1

func big_street(street: int) -> bool:
	return street >= 1

## There is no board.
func deal_street(_t) -> void:
	pass

func draw_phase_after(street: int) -> bool:
	return street == 0

func hand_score(hole: Array, _board: Array) -> int:
	return Eval.score(hole)

func best_cards(hole: Array, _board: Array) -> Array:
	return Eval.best_five(hole)
