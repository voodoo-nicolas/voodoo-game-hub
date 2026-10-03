extends RefCounted

## Digit Recall logic (a digit-span test): a string of digits is shown for a
## moment, then the player types it back. It gets one digit longer each time
## it is recalled. Pure logic, tested headlessly.

const START_LENGTH := 3
const MAX_LENGTH := 20
const START_LIVES := 3

var rng := RandomNumberGenerator.new()
var length: int = START_LENGTH   # digits in the current number
var lives: int = START_LIVES
var digits: Array = []           # the number to remember
var entry: Array = []            # what the player has typed so far
var best_length: int = 0         # longest number recalled correctly (the score)

func reset(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	length = START_LENGTH
	lives = START_LIVES
	best_length = 0
	start_round()

## How long the number stays on screen, in seconds.
func show_secs() -> float:
	return 1.0 + 0.6 * length

## A new random number of the current length; never the same digit twice in
## a row, which would be easy to miscount.
func start_round() -> void:
	digits = []
	entry = []
	var prev := -1
	for i in length:
		var d := rng.randi_range(0, 9)
		while d == prev:
			d = rng.randi_range(0, 9)
		digits.append(d)
		prev = d

## One keypad digit. Returns "typing" while more are needed, then "clear"
## (right: the number gets one digit longer), "miss" (wrong, a life lost) or
## "over" (wrong with no lives left). Extra presses once full are "ignored".
func press(digit: int) -> String:
	if entry.size() >= length:
		return "ignored"
	entry.append(digit)
	if entry.size() < length:
		return "typing"
	if entry == digits:
		best_length = maxi(best_length, length)
		length = mini(length + 1, MAX_LENGTH)
		return "clear"
	lives -= 1
	return "over" if lives <= 0 else "miss"

func backspace() -> void:
	if entry.size() > 0 and entry.size() < length:
		entry.pop_back()
