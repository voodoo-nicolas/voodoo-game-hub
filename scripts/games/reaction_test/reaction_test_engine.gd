extends RefCounted

## Actual delay timing and wall-clock reads happen in the UI controller (real
## Time/Timer calls aren't meaningfully unit-testable); this just tracks the
## state machine and best/last results so that logic can be tested headlessly.
enum State { IDLE, WAITING, READY, TOO_EARLY, RESULT }

var state: int = State.IDLE
var best_ms: int = -1
var last_ms: int = 0
var attempts: int = 0

func reset() -> void:
	state = State.IDLE
	best_ms = -1
	last_ms = 0
	attempts = 0

func start_waiting() -> void:
	state = State.WAITING

func mark_ready() -> void:
	state = State.READY

## Call when the player taps. Returns "too_early", "result", or "ignored"
## (tapping while idle or while a previous result/false-start is still showing).
func tap(reaction_ms: int) -> String:
	if state == State.WAITING:
		state = State.TOO_EARLY
		return "too_early"
	elif state == State.READY:
		last_ms = reaction_ms
		attempts += 1
		if best_ms == -1 or reaction_ms < best_ms:
			best_ms = reaction_ms
		state = State.RESULT
		return "result"
	return "ignored"
