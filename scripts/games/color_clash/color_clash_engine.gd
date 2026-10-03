extends RefCounted

## Color Clash logic (a Stroop test): a color word is shown printed in some
## ink color, and the player says whether the word and the ink match.
## Pure logic, tested headlessly.

const ROUND_SECS := 45.0
const WRONG_PENALTY := 2.0
## English names; the game translates them for display.
const NAMES := ["Red", "Blue", "Green", "Yellow", "Purple", "Orange"]
const COLORS := [
	Color(0.95, 0.25, 0.25),
	Color(0.3, 0.5, 1.0),
	Color(0.3, 0.85, 0.4),
	Color(1.0, 0.9, 0.2),
	Color(0.75, 0.4, 0.95),
	Color(1.0, 0.6, 0.15),
]

var rng := RandomNumberGenerator.new()
var time_left: float = ROUND_SECS
var score: int = 0
var streak: int = 0
var best_streak: int = 0
var word: int = 0   # index into NAMES: the word that is written
var ink: int = 0    # index into COLORS: the color it is printed in

func reset(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	time_left = ROUND_SECS
	score = 0
	streak = 0
	best_streak = 0
	next_word()

func is_over() -> bool:
	return time_left <= 0.0

func tick(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)

func is_match() -> bool:
	return word == ink

## Half the time the ink matches the word; otherwise it is a different color.
func next_word() -> void:
	word = rng.randi_range(0, NAMES.size() - 1)
	if rng.randf() < 0.5:
		ink = word
	else:
		ink = (word + rng.randi_range(1, NAMES.size() - 1)) % NAMES.size()

## `says_match` is the player's answer. Returns whether it was right.
func answer(says_match: bool) -> bool:
	var ok := says_match == is_match()
	if ok:
		score += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
		time_left = maxf(0.0, time_left - WRONG_PENALTY)
	next_word()
	return ok
