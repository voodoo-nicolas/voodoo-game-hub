extends RefCounted

const WORDS := [
	{"word": "PYTHON", "category": "Programming language"},
	{"word": "GUITAR", "category": "Musical instrument"},
	{"word": "ELEPHANT", "category": "Animal"},
	{"word": "COMPUTER", "category": "Electronic device"},
	{"word": "ROCKET", "category": "Mode of transport"},
	{"word": "MOUNTAIN", "category": "Geographic feature"},
	{"word": "DOLPHIN", "category": "Sea creature"},
	{"word": "BICYCLE", "category": "Mode of transport"},
	{"word": "ORANGE", "category": "Fruit"},
	{"word": "GALAXY", "category": "Space object"},
	{"word": "PUZZLE", "category": "Type of game"},
	{"word": "JACKET", "category": "Clothing item"},
	{"word": "PENCIL", "category": "School supply"},
	{"word": "WINDOW", "category": "Part of a house"},
	{"word": "CANDLE", "category": "Household item"},
	{"word": "TURTLE", "category": "Reptile"},
	{"word": "VOLCANO", "category": "Geographic feature"},
	{"word": "WHISTLE", "category": "Sports equipment"},
	{"word": "ROTTWEILER", "category": "Type of dog"},
	{"word": "POODLE", "category": "Type of dog"},
	{"word": "CHEETAH", "category": "Animal"},
	{"word": "TRUMPET", "category": "Musical instrument"},
	{"word": "BASKETBALL", "category": "Sport"},
	{"word": "STRAWBERRY", "category": "Fruit"},
]
const MAX_WRONG := 6

var word: String = ""
var category: String = ""
var guessed: Dictionary = {}  # letter (String) -> true
var wrong_count: int = 0

func reset() -> void:
	var entry: Dictionary = WORDS[randi() % WORDS.size()]
	word = entry.word
	category = entry.category
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
