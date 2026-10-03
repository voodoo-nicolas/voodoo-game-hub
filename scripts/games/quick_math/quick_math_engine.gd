extends RefCounted

## Quick Math logic: a stream of arithmetic questions that get harder as the
## score climbs, answered by picking one of four choices. No Nodes, so it is
## tested headlessly.

const ROUND_SECS := 60.0
const WRONG_PENALTY := 3.0
const MAX_LEVEL := 5

var rng := RandomNumberGenerator.new()
var time_left: float = ROUND_SECS
var score: int = 0
var streak: int = 0
var best_streak: int = 0
var wrong_count: int = 0
var question: String = ""
var answer: int = 0
var choices: Array = []
var correct_index: int = 0

func reset(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	time_left = ROUND_SECS
	score = 0
	streak = 0
	best_streak = 0
	wrong_count = 0
	next_question()

## Every 5 correct answers unlocks the next kind of question.
func level() -> int:
	return mini(score / 5, MAX_LEVEL)

func is_over() -> bool:
	return time_left <= 0.0

func tick(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)

func next_question() -> void:
	var q := make_question(level(), rng)
	question = q.text
	answer = q.answer
	choices = make_choices(answer, rng)
	correct_index = choices.find(answer)

## Returns true when `index` was the right choice. A right answer scores a
## point and moves on; a wrong one breaks the streak and costs time.
func submit(index: int) -> bool:
	var ok: bool = choices[index] == answer
	if ok:
		score += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
		wrong_count += 1
		time_left = maxf(0.0, time_left - WRONG_PENALTY)
	next_question()
	return ok

static func make_question(lvl: int, r: RandomNumberGenerator) -> Dictionary:
	var a: int
	var b: int
	var c: int
	match lvl:
		0:
			a = r.randi_range(2, 9)
			b = r.randi_range(1, 9)
			if r.randf() < 0.5:
				return {"text": "%d + %d" % [a, b], "answer": a + b}
			if b > a:
				var t := a
				a = b
				b = t
			return {"text": "%d − %d" % [a, b], "answer": a - b}
		1:
			a = r.randi_range(10, 60)
			b = r.randi_range(5, 39)
			if r.randf() < 0.5:
				return {"text": "%d + %d" % [a, b], "answer": a + b}
			if b > a:
				var t2 := a
				a = b
				b = t2
			return {"text": "%d − %d" % [a, b], "answer": a - b}
		2:
			a = r.randi_range(2, 9)
			b = r.randi_range(2, 9)
			return {"text": "%d × %d" % [a, b], "answer": a * b}
		3:
			if r.randf() < 0.5:
				a = r.randi_range(30, 99)
				b = r.randi_range(20, 79)
				if r.randf() < 0.5:
					return {"text": "%d + %d" % [a, b], "answer": a + b}
				return {"text": "%d − %d" % [maxi(a, b), mini(a, b)], "answer": absi(a - b)}
			a = r.randi_range(3, 12)
			b = r.randi_range(3, 12)
			return {"text": "%d × %d" % [a, b], "answer": a * b}
		4:
			if r.randf() < 0.5:
				b = r.randi_range(2, 12)
				var q := r.randi_range(2, 12)
				return {"text": "%d ÷ %d" % [b * q, b], "answer": q}
			a = r.randi_range(10, 50)
			b = r.randi_range(10, 40)
			c = r.randi_range(2, 9)
			return {"text": "%d + %d − %d" % [a, b, c], "answer": a + b - c}
		_:
			var kind := r.randi_range(0, 2)
			if kind == 0:
				a = r.randi_range(6, 15)
				b = r.randi_range(4, 9)
				return {"text": "%d × %d" % [a, b], "answer": a * b}
			if kind == 1:
				a = r.randi_range(2, 9)
				b = r.randi_range(2, 9)
				c = r.randi_range(2, 9)
				return {"text": "(%d + %d) × %d" % [a, b, c], "answer": (a + b) * c}
			b = r.randi_range(3, 12)
			var q2 := r.randi_range(4, 15)
			return {"text": "%d ÷ %d" % [b * q2, b], "answer": q2}

## The right answer plus three distinct near misses, shuffled.
static func make_choices(correct: int, r: RandomNumberGenerator) -> Array:
	var offsets := [-10, -5, -3, -2, -1, 1, 2, 3, 5, 10]
	var out: Array = [correct]
	var tries := 0
	while out.size() < 4 and tries < 200:
		tries += 1
		var cand: int = correct + int(offsets[r.randi() % offsets.size()])
		if cand >= 0 and not out.has(cand):
			out.append(cand)
	var n := 11
	while out.size() < 4:  # tiny answers: fall back to the next free numbers
		if not out.has(n):
			out.append(n)
		n += 1
	for i in range(out.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out
