extends RefCounted

## Fastest Finger: 2-4 players share one phone and race to tap first. Each
## round is a Reaction pad (wait for GO; tapping early locks you out), a Math
## sum (tap the right answer) or an Odd one out (tap the shape that differs).
## First to TARGET points wins. Pure logic, no Nodes: the game decides when
## each phase starts (ready -> wait -> live) and measures reaction times.

const TARGET := 5
const KINDS := ["reaction", "math", "odd"]
const SHAPES := 6          # circle, square, triangle, diamond, star, hexagon

var players: int = 2
var challenge: int = 3     # 0 reaction, 1 math, 2 odd one out, 3 mixed
var scores: Array = []
var round_no: int = 0
var kind: String = "reaction"
var phase: String = "done"   # ready, wait, live, done
var winner: int = -1         # this round's winner, -1 = nobody (yet)
var locked: Array = []       # tapped early / wrong this round
var question: String = ""
var options: Array = []      # per player: Array of option values (math: ints, odd: shape ids)
var correct: Array = []      # per player: index of the right option
var shape_base: int = 0
var shape_odd: int = 1
var last_kind: String = ""

func new_game(p: int, ch: int) -> void:
	players = clampi(p, 2, 4)
	challenge = clampi(ch, 0, 3)
	scores = []
	for i in players:
		scores.append(0)
	round_no = 0
	last_kind = ""
	phase = "done"
	winner = -1

func match_winner() -> int:
	var best := -1
	for i in players:
		if scores[i] >= TARGET and (best < 0 or scores[i] > scores[best]):
			best = i
	return best

func new_round() -> void:
	round_no += 1
	winner = -1
	phase = "ready"
	locked = []
	options = []
	correct = []
	for i in players:
		locked.append(false)
		options.append([])
		correct.append(0)
	if challenge < 3:
		kind = KINDS[challenge]
	else:
		var k: String = KINDS[randi() % 3]
		if k == last_kind:
			k = KINDS[randi() % 3]
		kind = k
	last_kind = kind
	if kind == "math":
		_make_math()
	elif kind == "odd":
		_make_odd()
	else:
		question = ""

func _make_math() -> void:
	var a := 0
	var b := 0
	var ans := 0
	match randi() % 3:
		0:
			a = randi_range(6, 49)
			b = randi_range(4, 40)
			ans = a + b
			question = "%d + %d" % [a, b]
		1:
			a = randi_range(20, 90)
			b = randi_range(4, a - 3)
			ans = a - b
			question = "%d - %d" % [a, b]
		_:
			a = randi_range(3, 12)
			b = randi_range(3, 12)
			ans = a * b
			question = "%d × %d" % [a, b]
	for p in players:
		var opts: Array = [ans]
		var guard := 0
		while opts.size() < 3 and guard < 50:
			guard += 1
			var wrong: int = ans + [-10, -2, -1, 1, 2, 10, 3, -3][randi() % 8]
			if wrong > 0 and not opts.has(wrong):
				opts.append(wrong)
		opts.shuffle()
		options[p] = opts
		correct[p] = opts.find(ans)

func _make_odd() -> void:
	question = ""
	shape_base = randi() % SHAPES
	shape_odd = (shape_base + 1 + randi() % (SHAPES - 1)) % SHAPES
	for p in players:
		var opts: Array = [shape_base, shape_base, shape_base, shape_base]
		var at: int = randi() % 4
		opts[at] = shape_odd
		options[p] = opts
		correct[p] = at

## The game calls these when its timers fire.
func begin_wait() -> void:
	if kind == "reaction":
		phase = "wait"
	else:
		phase = "live"

func go() -> void:
	if phase == "wait":
		phase = "live"

func _lock_check() -> void:
	if winner < 0 and not locked.has(false):
		phase = "done"

## A tap on the Reaction pad. Returns "win", "early", "late" (someone was first) or "ignored".
func tap_pad(p: int) -> String:
	if kind != "reaction" or locked[p] or phase == "ready" or phase == "done":
		return "ignored"
	if phase == "wait":
		locked[p] = true
		_lock_check()
		return "early"
	if winner >= 0:
		return "late"
	winner = p
	scores[p] += 1
	phase = "done"
	return "win"

## A tap on option `idx` of player p's panel (math / odd one out). "win", "wrong" or "ignored".
func tap_option(p: int, idx: int) -> String:
	if kind == "reaction" or phase != "live" or locked[p] or winner >= 0:
		return "ignored"
	if idx == correct[p]:
		winner = p
		scores[p] += 1
		phase = "done"
		return "win"
	locked[p] = true
	_lock_check()
	return "wrong"

func round_over() -> bool:
	return phase == "done"
