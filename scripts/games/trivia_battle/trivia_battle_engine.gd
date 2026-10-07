extends RefCounted

## Trivia Battle: 2-4 players share one phone and race to answer the same
## question. Everyone has four answers on their own panel; the first right tap
## scores 1 point, a wrong tap locks you out of that question. Pure logic, no
## Nodes. The questions are data (trivia_battle_questions.json, with their own
## Spanish): [question, right answer, wrong, wrong, wrong].

const BANK_PATH := "res://scripts/games/trivia_battle/trivia_battle_questions.json"
const QUESTIONS := 10
const TIME_LIMIT := 15.0
const MIXED := "mixed"
const TOPICS := ["science", "nature", "history", "geography", "arts", "sports"]

var bank := {}               # topic id -> Array of {"en": [...], "es": [...]}
var spanish: bool = false
var players: int = 2
var scores: Array = []
var questions: Array = []    # {"text", "answer"}
var index: int = 0
var phase: String = "done"   # ready, live, done
var winner: int = -1
var locked: Array = []
var options: Array = []      # per player: 4 answers, shuffled separately
var correct: Array = []
var solved: Array = []

func load_bank() -> bool:
	if not bank.is_empty():
		return true
	var f := FileAccess.open(BANK_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if not (d is Dictionary) or not d.has("topics"):
		return false
	for t in d.topics:
		bank[str(t.id)] = t.questions
	return not bank.is_empty()

func question_count(topic: String) -> int:
	if topic == MIXED:
		var n := 0
		for k in bank:
			n += bank[k].size()
		return n
	return bank.get(topic, []).size()

func new_game(p: int, topic: String, use_spanish: bool) -> void:
	spanish = use_spanish
	players = clampi(p, 2, 4)
	var pool: Array = []
	if topic == MIXED:
		for k in bank:
			pool.append_array(bank[k])
	else:
		pool = bank.get(topic, []).duplicate()
	pool.shuffle()
	questions = []
	for e in pool.slice(0, mini(QUESTIONS, pool.size())):
		var parts: Array = e["es"] if spanish and e.has("es") else e["en"]
		questions.append({"text": str(parts[0]), "choices": parts.slice(1, 5)})
	index = 0
	scores = []
	solved = []
	for i in players:
		scores.append(0)
		solved.append(0)
	phase = "done"
	winner = -1

func is_over() -> bool:
	return index >= questions.size()

func total() -> int:
	return questions.size()

func question() -> Dictionary:
	return questions[index]

func new_round() -> void:
	winner = -1
	phase = "ready"
	locked = []
	options = []
	correct = []
	var q: Dictionary = question()
	var right: String = str(q.choices[0])
	for p in players:
		locked.append(false)
		var opts: Array = q.choices.duplicate()
		opts.shuffle()
		options.append(opts)
		correct.append(opts.find(right))

func begin() -> void:
	phase = "live"

func all_locked() -> bool:
	return not locked.has(false)

## "win", "wrong" or "ignored".
func tap_option(p: int, i: int) -> String:
	if phase != "live" or locked[p] or winner >= 0:
		return "ignored"
	if i == correct[p]:
		winner = p
		scores[p] += 1
		solved[p] += 1
		phase = "done"
		return "win"
	locked[p] = true
	if all_locked():
		phase = "done"
	return "wrong"

func time_out() -> void:
	phase = "done"

func answer_text() -> String:
	return str(question().choices[0])

func next_round() -> void:
	index += 1

func match_winner() -> int:
	var best := 0
	var tie := false
	for i in range(1, players):
		if scores[i] > scores[best]:
			best = i
			tie = false
		elif scores[i] == scores[best]:
			tie = true
	return -1 if tie else best
