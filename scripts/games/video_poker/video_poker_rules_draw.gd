extends "res://scripts/games/video_poker/video_poker_rules.gd"

## Five Card Draw: five hole cards, one betting round, a draw, one more round.
## (The draw itself is Table.draw(); this says when it happens.)

func hole_count() -> int:
	return 5

func board_size() -> int:
	return 0

func has_draw() -> bool:
	return true

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
