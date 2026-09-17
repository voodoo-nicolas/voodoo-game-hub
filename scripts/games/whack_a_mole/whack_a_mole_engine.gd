extends RefCounted

const HOLE_COUNT := 9
const ROUND_SECONDS := 30.0

var active_hole: int = -1
var score: int = 0
var misses: int = 0
var time_remaining: float = 0.0
var running: bool = false

func reset() -> void:
	active_hole = -1
	score = 0
	misses = 0
	time_remaining = ROUND_SECONDS
	running = true

func pop_random_hole() -> int:
	active_hole = randi() % HOLE_COUNT
	return active_hole

func hide_mole() -> void:
	if active_hole >= 0:
		misses += 1
	active_hole = -1

## Returns true if this was a genuine hit (a mole was actually up at this hole).
func whack(hole: int) -> bool:
	if not running or hole != active_hole:
		return false
	score += 1
	active_hole = -1
	return true

## Returns true exactly once, the tick where the round just ended.
func tick(delta: float) -> bool:
	if not running:
		return false
	time_remaining = max(0.0, time_remaining - delta)
	if time_remaining <= 0.0:
		running = false
		return true
	return false
