extends RefCounted

## Five in a Row (gomoku, freestyle): two players take turns placing stones
## on the points of a 15 x 15 grid; the first to get five or more in a line
## -- across, down or diagonally -- wins. Black moves first. Pure logic,
## plus a pattern-scoring computer player.

const SIZE := 15
const EMPTY := 0
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

var board: Array = []
var turn: int = 1        # 1 black, 2 white
var winner: int = 0      # 0 none, 1/2, 3 draw
var last: int = -1
var line: Array = []     # the winning stones

func reset() -> void:
	board = []
	board.resize(SIZE * SIZE)
	board.fill(EMPTY)
	turn = 1
	winner = 0
	last = -1
	line = []

func at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return -1
	return board[y * SIZE + x]

func play(i: int) -> bool:
	if winner != 0 or i < 0 or i >= board.size() or board[i] != EMPTY:
		return false
	board[i] = turn
	last = i
	var run := _run_through(i, turn)
	if run.size() >= 5:
		winner = turn
		line = run
	elif not board.has(EMPTY):
		winner = 3
	turn = 3 - turn
	return true

## The longest line of `p` through point i (as indices), or just [i].
func _run_through(i: int, p: int) -> Array:
	var best: Array = [i]
	var x := i % SIZE
	var y := i / SIZE
	for d in DIRS:
		var run: Array = [i]
		for s in [1, -1]:
			var k := 1
			while at(x + d.x * k * s, y + d.y * k * s) == p:
				run.append((y + d.y * k * s) * SIZE + x + d.x * k * s)
				k += 1
		if run.size() > best.size():
			best = run
	return best

# ---------- computer player ----------

## How good it would be for `p` to play at i: one score per direction from
## the length of the line it makes and how many of its ends stay open.
func _value(i: int, p: int) -> float:
	var x := i % SIZE
	var y := i / SIZE
	var total := 0.0
	for d in DIRS:
		var count := 1
		var open := 0
		for s in [1, -1]:
			var k := 1
			while at(x + d.x * k * s, y + d.y * k * s) == p:
				count += 1
				k += 1
			if at(x + d.x * k * s, y + d.y * k * s) == EMPTY:
				open += 1
		total += _pattern(count, open)
	return total

static func _pattern(count: int, open: int) -> float:
	if count >= 5:
		return 1000000.0
	if open == 0:
		return 0.0
	match count:
		4:
			return 50000.0 if open == 2 else 4000.0
		3:
			return 3000.0 if open == 2 else 300.0
		2:
			return 200.0 if open == 2 else 30.0
	return 10.0 if open == 2 else 2.0

## Empty points next to a stone (or the centre on an empty board).
func candidates() -> Array:
	var out: Array = []
	for i in board.size():
		if board[i] != EMPTY:
			continue
		var x := i % SIZE
		var y := i / SIZE
		var near := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var v := at(x + dx, y + dy)
				if v == 1 or v == 2:
					near = true
		if near:
			out.append(i)
	if out.is_empty():
		out.append((SIZE / 2) * SIZE + SIZE / 2)
	return out

## Level 0 easy (often second-best, misses some blocks), 1 normal, 2 hard.
func cpu_move(level: int, rng: RandomNumberGenerator) -> int:
	var me := turn
	var foe := 3 - turn
	var attack: float = [0.7, 1.0, 1.15][level]
	var defend: float = [0.6, 0.95, 1.0][level]
	var scored: Array = []
	for i in candidates():
		var s: float = _value(i, me) * attack + _value(i, foe) * defend
		s += rng.randf() * [400.0, 20.0, 1.0][level]
		scored.append([s, i])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	if level == 0 and scored.size() > 2 and scored[0][0] < 900000.0 and rng.randf() < 0.35:
		return scored[rng.randi_range(1, mini(3, scored.size() - 1))][1]
	return scored[0][1]
