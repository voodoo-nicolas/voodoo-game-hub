extends RefCounted

## Trivia logic: ten multiple-choice questions from one topic (or all of
## them), scored with a speed bonus. The questions live in
## trivia_questions.json, each with an English and a Spanish text, the
## correct answer always listed first (the engine shuffles). Pure logic,
## tested headlessly.

const BANK_PATH := "res://scripts/games/trivia/trivia_questions.json"
const QUESTIONS := 10
const TIME_LIMIT := 20.0
const POINTS := 10
const MAX_BONUS := 5
const MIXED := "mixed"

## Topic ids match the bank; the names are English, translated by the game.
const TOPICS := [
	{"id": "science", "name": "Science", "icon": "🔬"},
	{"id": "nature", "name": "Nature & Animals", "icon": "🦁"},
	{"id": "history", "name": "History", "icon": "📜"},
	{"id": "geography", "name": "Geography", "icon": "🌍"},
	{"id": "arts", "name": "Arts & Culture", "icon": "🎭"},
	{"id": "sports", "name": "Sports & Games", "icon": "⚽"},
	{"id": "mixed", "name": "Mixed", "icon": "🎲"},
]

var rng := RandomNumberGenerator.new()
var bank: Dictionary = {}     # topic id -> Array of {"en": [...], "es": [...]}
var spanish: bool = false
var questions: Array = []     # this game's questions: {text, choices, correct}
var index: int = 0
var score: int = 0
var correct_count: int = 0
var streak: int = 0
var best_streak: int = 0

## Reads the question bank. Returns false if it can't be read.
func load_bank(path: String = BANK_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("topics"):
		return false
	bank = {}
	for t in parsed.topics:
		bank[t.id] = t.questions
	return not bank.is_empty()

func question_count(topic: String) -> int:
	if topic == MIXED:
		var n := 0
		for k in bank:
			n += bank[k].size()
		return n
	return bank.get(topic, []).size()

func start(topic: String, use_spanish: bool = false, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	spanish = use_spanish
	var pool: Array = []
	if topic == MIXED:
		for k in bank:
			pool.append_array(bank[k])
	else:
		pool = bank.get(topic, []).duplicate()
	_shuffle(pool)
	questions = []
	for entry in pool.slice(0, mini(QUESTIONS, pool.size())):
		questions.append(_make(entry))
	index = 0
	score = 0
	correct_count = 0
	streak = 0
	best_streak = 0

func _make(entry: Dictionary) -> Dictionary:
	var parts: Array = entry["es"] if spanish and entry.has("es") else entry["en"]
	var correct: String = parts[1]
	var choices: Array = parts.slice(1, 5)
	_shuffle(choices)
	return {"text": parts[0], "choices": choices, "correct": choices.find(correct)}

func current() -> Dictionary:
	return questions[index]

func total() -> int:
	return questions.size()

func is_done() -> bool:
	return index >= questions.size()

## `elapsed` is the seconds the player took. Returns the points earned
## (0 when wrong). A timed-out question is submitted as choice -1.
func submit(choice: int, elapsed: float) -> int:
	var earned := 0
	if choice == current().correct:
		earned = POINTS + clampi(MAX_BONUS - int(elapsed / 3.0), 0, MAX_BONUS)
		score += earned
		correct_count += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
	return earned

func advance() -> void:
	index += 1

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
