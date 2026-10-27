extends "res://scripts/games/video_poker/video_poker_rules.gd"

## Omaha: four hole cards, exactly two of them plus three from the board.

func hole_count() -> int:
	return 4

## Rating a hand tries 60 two-plus-three combinations.
func work_cost() -> float:
	return 10.0

func hand_score(hole: Array, board: Array) -> int:
	if board.size() < 3:
		# Only two of the four can ever play: the best pair of them.
		var best := -1
		for a in hole.size():
			for b in range(a + 1, hole.size()):
				best = maxi(best, Eval.score([hole[a], hole[b]]))
		return best
	return Eval.score_omaha(hole, board)

func best_cards(hole: Array, board: Array) -> Array:
	return Eval.best_five(board, hole) if board.size() >= 3 else []
