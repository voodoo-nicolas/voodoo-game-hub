extends "res://scripts/games/video_poker/video_poker_rules_omaha.gd"

## Omaha Hi-Lo (Omaha 8 or better): Omaha, and every pot is split in two: half to
## the best high hand, half to the best low (five different ranks, none above an
## 8, video_poker_eval_low.gd), both made of exactly two hole cards and three from
## the board. With no qualifying low the best high takes everything. Winning both
## halves is a "scoop". The table splits the pots when is_split() is true.

const Low = preload("res://scripts/games/video_poker/video_poker_eval_low.gd")

func title() -> String:
	return "Omaha Hi-Lo"

func short_title() -> String:
	return "Omaha Hi-Lo"

## A high and a low to rate: the dearest hand to simulate.
func work_cost() -> float:
	return 14.0

func is_split() -> bool:
	return true

func low_score(hole: Array, board: Array) -> int:
	return int(Low.best(hole, board).score)

func low_best(hole: Array, board: Array) -> Array:
	return Low.best(hole, board).cards

func describe_low(score: int) -> String:
	return Low.describe(score)
