extends RefCounted

## Number Series logic: what number comes next? Twelve questions that get
## harder, four choices each. The rule behind every sequence is kept so the
## game can explain a miss. Pure logic, tested headlessly.

const QUESTIONS := 12
const TIME_LIMIT := 25.0
const POINTS := 10
const MAX_BONUS := 5

## Rule descriptions (English templates; the game translates them, then
## fills in `rule_args`).
const RULE_ADD := "Add %d each time."
const RULE_SUB := "Subtract %d each time."
const RULE_MUL := "Multiply by %d each time."
const RULE_SQUARES := "These are square numbers (1, 4, 9, 16...)."
const RULE_SQUARES_PLUS := "Square numbers (1, 4, 9, 16...) plus %d."
const RULE_CUBES := "These are cube numbers (1, 8, 27, 64...)."
const RULE_GROWING := "The gap grows by %d each step."
const RULE_FIB := "Each number is the sum of the two before it."
const RULE_ALT := "The steps alternate: add %d, then add %d."
const RULE_PRIMES := "These are the prime numbers."
const RULE_DOUBLE_PLUS := "Double the number, then add %d."
const RULE_TRIPLE_MINUS := "Multiply by 3, then subtract %d."
const RULE_INTERLEAVED := "Two sequences are woven together: one adds %d, the other adds %d."

var rng := RandomNumberGenerator.new()
var index: int = 0            # 0-based number of the current question
var score: int = 0
var correct_count: int = 0
var streak: int = 0
var best_streak: int = 0
var shown: Array = []         # the visible terms
var answer: int = 0
var choices: Array = []
var correct_index: int = 0
var rule_text: String = ""
var rule_args: Array = []

func reset(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	index = 0
	score = 0
	correct_count = 0
	streak = 0
	best_streak = 0
	_make_question()

func is_done() -> bool:
	return index >= QUESTIONS

## 0 = easy, 1 = medium, 2 = hard.
func tier() -> int:
	return mini(index / 4, 2)

## `elapsed` is how long the player took, in seconds. Returns the points
## earned (0 for a wrong answer); a right answer earns a speed bonus.
## A timed-out question is submitted as choice -1.
func submit(choice: int, elapsed: float) -> int:
	var earned := 0
	if choice == correct_index:
		earned = POINTS + clampi(MAX_BONUS - int(elapsed / 2.0), 0, MAX_BONUS)
		score += earned
		correct_count += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
	return earned

## Moves to the next question (call after submit).
func advance() -> void:
	index += 1
	if not is_done():
		_make_question()

func _make_question() -> void:
	var kinds: Array = _kinds_for(tier())
	var kind: String = kinds[rng.randi() % kinds.size()]
	var terms: Array = _build(kind)
	# The last term is the answer; everything before it is shown.
	answer = terms[terms.size() - 1]
	shown = terms.slice(0, terms.size() - 1)
	choices = _choices_for(answer, terms)
	correct_index = choices.find(answer)

func _kinds_for(t: int) -> Array:
	match t:
		0:
			return ["add", "sub", "mul"]
		1:
			return ["squares", "growing", "fib", "alt", "add"]
		_:
			return ["squares_plus", "cubes", "primes", "double_plus", "triple_minus", "interleaved", "growing"]

## Builds shown terms + the answer as one list; sets rule_text / rule_args.
func _build(kind: String) -> Array:
	var out: Array = []
	match kind:
		"add":
			var step := rng.randi_range(2, 9)
			var a := rng.randi_range(1, 30)
			for i in 6:
				out.append(a + step * i)
			rule_text = RULE_ADD
			rule_args = [step]
		"sub":
			var step2 := rng.randi_range(2, 9)
			var a2 := rng.randi_range(40, 90)
			for i in 6:
				out.append(a2 - step2 * i)
			rule_text = RULE_SUB
			rule_args = [step2]
		"mul":
			var ratio := rng.randi_range(2, 3)
			var term := rng.randi_range(1, 4)
			for i in 6 if ratio == 2 else 5:
				out.append(term)
				term *= ratio
			rule_text = RULE_MUL
			rule_args = [ratio]
		"squares":
			var start := rng.randi_range(1, 6)
			for i in 6:
				out.append((start + i) * (start + i))
			rule_text = RULE_SQUARES
			rule_args = []
		"squares_plus":
			var plus := rng.randi_range(1, 9)
			var start2 := rng.randi_range(1, 5)
			for i in 6:
				out.append((start2 + i) * (start2 + i) + plus)
			rule_text = RULE_SQUARES_PLUS
			rule_args = [plus]
		"cubes":
			var start3 := rng.randi_range(1, 3)
			for i in 6:
				out.append((start3 + i) * (start3 + i) * (start3 + i))
			rule_text = RULE_CUBES
			rule_args = []
		"growing":
			var gap_step := rng.randi_range(1, 3)
			var gap := rng.randi_range(1, 4)
			var v := rng.randi_range(1, 15)
			for i in 6:
				out.append(v)
				v += gap
				gap += gap_step
			rule_text = RULE_GROWING
			rule_args = [gap_step]
		"fib":
			out = [rng.randi_range(1, 4), rng.randi_range(1, 5)]
			for i in 4:
				out.append(out[out.size() - 1] + out[out.size() - 2])
			rule_text = RULE_FIB
			rule_args = []
		"alt":
			var s1 := rng.randi_range(2, 8)
			var s2 := rng.randi_range(1, 7)
			if s2 == s1:
				s2 += 1
			var w := rng.randi_range(1, 20)
			for i in 6:
				out.append(w)
				w += s1 if i % 2 == 0 else s2
			rule_text = RULE_ALT
			rule_args = [s1, s2]
		"primes":
			var primes := [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41]
			var p := rng.randi_range(0, 5)
			out = primes.slice(p, p + 6)
			rule_text = RULE_PRIMES
			rule_args = []
		"double_plus":
			var add := rng.randi_range(1, 3)
			var d := rng.randi_range(1, 3)
			for i in 6:
				out.append(d)
				d = d * 2 + add
			rule_text = RULE_DOUBLE_PLUS
			rule_args = [add]
		"triple_minus":
			var sub := rng.randi_range(1, 3)
			var t := rng.randi_range(2, 4)
			for i in 5:
				out.append(t)
				t = t * 3 - sub
			rule_text = RULE_TRIPLE_MINUS
			rule_args = [sub]
		_:  # "interleaved": even positions follow one sequence, odd the other
			var sa := rng.randi_range(2, 5)
			var sb := rng.randi_range(3, 9)
			var va := rng.randi_range(1, 10)
			var vb := rng.randi_range(20, 50)
			for i in 7:
				if i % 2 == 0:
					out.append(va)
					va += sa
				else:
					out.append(vb)
					vb += sb
			rule_text = RULE_INTERLEAVED
			rule_args = [sa, sb]
	return out

## The answer plus three distinct wrong numbers, shuffled. The wrong ones
## include the tempting mistakes: repeating the last gap, or the last term.
func _choices_for(correct: int, terms: Array) -> Array:
	var last_shown: int = terms[terms.size() - 2]
	var prev_shown: int = terms[terms.size() - 3]
	var gap: int = last_shown - prev_shown
	var pool: Array = [last_shown + gap, last_shown, correct + 1, correct - 1,
			correct + 2, correct - 2, correct + 10, correct - 10, correct + 3, correct - 3, correct + 5]
	var out: Array = [correct]
	for c in pool:
		if out.size() >= 4:
			break
		if c != correct and not out.has(c):
			out.append(c)
	var n := correct + 20
	while out.size() < 4:
		if not out.has(n):
			out.append(n)
		n += 1
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
