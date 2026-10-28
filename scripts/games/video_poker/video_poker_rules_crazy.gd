extends "res://scripts/games/video_poker/video_poker_rules_pineapple.gd"

## Crazy Pineapple: three hole cards like Pineapple, but the discard comes after
## the FLOP betting, so you choose which card to drop knowing the flop.

func title() -> String:
	return "Crazy Pineapple"

func short_title() -> String:
	return "Crazy Pineapple"

func _discard_street() -> int:
	return 1
