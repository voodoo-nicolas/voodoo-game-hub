extends RefCounted

## Sketch It: teams take turns; one player draws a secret word and their
## team guesses it out loud before the time runs out. First team to the
## target wins. Pure logic (words, turns, scores), no Nodes.

const WORDS_PATH := "res://scripts/games/sketch_it/sketch_it_words.json"
const LEVELS := ["easy", "hard", "mixed"]

var words: Dictionary = {}   # "easy"/"hard" -> {"en": [...], "es": [...]}
var deck: Array = []
var scores: Array = [0, 0]
var turn: int = 0
var target: int = 5
var level: int = 0
var lang: String = "en"
var word: String = ""

func load_words(path: String = WORDS_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	words = parsed
	return true

func new_game(n_teams: int, p_target: int, p_level: int, p_lang: String, rng: RandomNumberGenerator) -> void:
	scores = []
	scores.resize(n_teams)
	scores.fill(0)
	turn = 0
	target = p_target
	level = p_level
	lang = p_lang
	deck = []
	_refill(rng)

func _refill(rng: RandomNumberGenerator) -> void:
	var pool: Array = []
	for key in (["easy", "hard"] if LEVELS[level] == "mixed" else [LEVELS[level]]):
		var by_lang: Dictionary = words.get(key, {})
		pool.append_array(by_lang.get(lang, by_lang.get("en", [])))
	# Fisher-Yates with our own rng, so tests can seed it.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	deck = pool

func next_word(rng: RandomNumberGenerator) -> String:
	if deck.is_empty():
		_refill(rng)
	word = str(deck.pop_back()) if not deck.is_empty() else "?"
	return word

## The team drawing guessed it: a point, and the next team's turn.
func guessed() -> void:
	scores[turn] += 1
	turn = (turn + 1) % scores.size()

func missed() -> void:
	turn = (turn + 1) % scores.size()

## Index of the team that reached the target, or -1.
func winner() -> int:
	for i in scores.size():
		if scores[i] >= target:
			return i
	return -1
