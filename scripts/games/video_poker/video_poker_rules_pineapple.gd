extends "res://scripts/games/video_poker/video_poker_rules.gd"

## Pineapple: Texas Hold'em where everyone is dealt THREE hole cards and throws
## one away (no new card) before the flop. A hand with three hole cards counts as
## the best of the three ways to keep two, so the computer players' win chance
## (they rate hands they have not yet trimmed) is right.

func title() -> String:
	return "Pineapple"

func short_title() -> String:
	return "Pineapple"

func hole_count() -> int:
	return 3

## Rating a hand tries each card as the one dropped.
func work_cost() -> float:
	return 2.0

## The discard comes after the first round of betting, before the flop.
func draw_phase_after(street: int) -> bool:
	return street == _discard_street()

func _discard_street() -> int:
	return 0

func hole_after_discard() -> int:
	return 2

func discard_kind() -> String:
	return "drop"

func discard_word() -> String:
	return "Discard"

func discard_prompt() -> String:
	return "Tap the card to throw away, then discard it."

func can_discard(hand: Array, indices: Array) -> bool:
	return hand.size() == 3 and indices.size() == 1 and int(indices[0]) >= 0 and int(indices[0]) < 3

## The card whose loss hurts the hand least.
func auto_discard(hole: Array, board: Array) -> Array:
	if hole.size() < 3:
		return []
	var best := -1
	var drop := 0
	for k in hole.size():
		var keep: Array = hole.duplicate()
		keep.remove_at(k)
		var s := Eval.score(keep + board)
		if s > best:
			best = s
			drop = k
	return [drop]

func hand_score(hole: Array, board: Array) -> int:
	if hole.size() <= 2:
		return Eval.score(hole + board)
	var best := -1
	for k in hole.size():
		var keep: Array = hole.duplicate()
		keep.remove_at(k)
		best = maxi(best, Eval.score(keep + board))
	return best

func best_cards(hole: Array, board: Array) -> Array:
	if hole.size() <= 2:
		return Eval.best_five(hole + board)
	var best := -1
	var out: Array = []
	for k in hole.size():
		var keep: Array = hole.duplicate()
		keep.remove_at(k)
		var s := Eval.score(keep + board)
		if s > best:
			best = s
			out = Eval.best_five(keep + board)
	return out
