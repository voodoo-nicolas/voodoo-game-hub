extends RefCounted

const NUM_PADS := 4

var sequence: Array = []
var player_progress: int = 0
var level: int = 0
var game_over: bool = false

func reset() -> void:
	sequence = []
	player_progress = 0
	level = 0
	game_over = false

func next_round() -> void:
	level += 1
	sequence.append(randi() % NUM_PADS)
	player_progress = 0

## Returns "correct" (keep going), "round_complete" (matched the whole sequence so far),
## or "wrong" (game over).
func tap(pad: int) -> String:
	if game_over or sequence.is_empty():
		return "wrong"
	if sequence[player_progress] != pad:
		game_over = true
		return "wrong"
	player_progress += 1
	if player_progress == sequence.size():
		return "round_complete"
	return "correct"
