extends "res://scripts/games/video_poker/video_poker_rules_holdem.gd"

## Short Deck (6+) Hold'em: Texas Hold'em with the 2s to 5s taken out (36 cards).
## Flushes beat full houses, three of a kind beats a straight, and A-6-7-8-9 is
## the lowest straight (video_poker_eval_short.gd). There is no starting-hand
## chart: the Hold'em points are made for 52 cards, so the computer players and
## the coach work from their win chance only.

const Short = preload("res://scripts/games/video_poker/video_poker_eval_short.gd")

func title() -> String:
	return "Short Deck Hold'em"

func short_title() -> String:
	return "Short Deck"

## No 2s, 3s, 4s or 5s.
func new_deck() -> Array:
	return range(52).filter(func(c): return c % 13 == 0 or c % 13 >= 5)

func has_starting_hand_chart() -> bool:
	return false

func describe(score: int) -> String:
	return Short.describe(score)

func hand_type(score: int) -> int:
	return Short.type_of(score)

func hand_score(hole: Array, board: Array) -> int:
	return Short.score(hole + board)

func best_cards(hole: Array, board: Array) -> Array:
	return Short.best_five(hole + board)
