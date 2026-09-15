extends RefCounted

const WORDS := [
	"PYTHON", "GUITAR", "ELEPHANT", "COMPUTER", "ROCKET", "MOUNTAIN",
	"DOLPHIN", "BICYCLE", "ORANGE", "GALAXY", "PUZZLE", "JACKET",
	"PENCIL", "WINDOW", "CANDLE", "TURTLE", "VOLCANO", "WHISTLE",
]
const MAX_WRONG := 6

var word: String = ""
var guessed: Dictionary = {}  # letter (String) -> true
var wrong_count: int = 0

func reset() -> void:
	word = WORDS[randi() % WORDS.size()]
	guessed = {}
	wrong_count = 0

## Returns "correct", "wrong", or "ignored" (already guessed, or game already over).
func guess(letter: String) -> String:
	letter = letter.to_upper()
	if guessed.has(letter) or is_won() or is_lost():
		return "ignored"
	guessed[letter] = true
	if word.contains(letter):
		return "correct"
	wrong_count += 1
	return "wrong"

func is_won() -> bool:
	for c in word:
		if not guessed.has(c):
			return false
	return true

func is_lost() -> bool:
	return wrong_count >= MAX_WRONG

func display_word() -> String:
	var s := ""
	for c in word:
		s += (c + " ") if guessed.has(c) else "_ "
	return s.strip_edges()
