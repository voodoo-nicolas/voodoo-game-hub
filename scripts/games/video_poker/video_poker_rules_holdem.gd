extends "res://scripts/games/video_poker/video_poker_rules.gd"

## Texas Hold'em: two hole cards, five on the board, the best five of the
## seven play. Everything is the base's default, plus the starting-hand chart.

func has_starting_hand_chart() -> bool:
	return true
