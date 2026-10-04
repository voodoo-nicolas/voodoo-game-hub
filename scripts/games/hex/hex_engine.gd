extends RefCounted

## Hex: a rhombus of hexagons. Red (player 1, moves first) joins the top
## edge to the bottom edge; Blue (player 2) joins left to right. Players
## take turns claiming one empty hexagon. Someone always wins -- a board
## can't fill up without a connection. Pure logic plus a computer player.
## Cell (x, y) is index y * size + x; neighbours are the six hexagons around it.

const NB := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]

var size: int = 9
var board: Array = []
var turn: int = 1
var winner: int = 0
var last: int = -1
var path: Array = []   # the winning chain

func reset(n: int = 9) -> void:
	size = n
	board = []
	board.resize(n * n)
	board.fill(0)
	turn = 1
	winner = 0
	last = -1
	path = []

func play(i: int) -> bool:
	if winner != 0 or i < 0 or i >= board.size() or board[i] != 0:
		return false
	board[i] = turn
	last = i
	var chain := _connection(turn)
	if not chain.is_empty():
		winner = turn
		path = chain
	turn = 3 - turn
	return true

func neighbours(i: int) -> Array:
	var x := i % size
	var y := i / size
	var out: Array = []
	for d in NB:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= 0 and ny >= 0 and nx < size and ny < size:
			out.append(ny * size + nx)
	return out

func _starts(p: int) -> Array:
	var out: Array = []
	for k in size:
		out.append(k if p == 1 else k * size)  # red: top row; blue: left column
	return out

func _is_goal(p: int, i: int) -> bool:
	return (i / size == size - 1) if p == 1 else (i % size == size - 1)

## A chain of p's stones joining p's two edges, or [].
func _connection(p: int) -> Array:
	var prev := {}
	var todo: Array = []
	for s in _starts(p):
		if board[s] == p:
			prev[s] = -1
			todo.append(s)
	while not todo.is_empty():
		var i: int = todo.pop_front()
		if _is_goal(p, i):
			var chain: Array = []
			var k := i
			while k != -1:
				chain.append(k)
				k = prev[k]
			return chain
		for j in neighbours(i):
			if board[j] == p and not prev.has(j):
				prev[j] = i
				todo.append(j)
	return []

## Fewest empty cells p still needs to connect (own stones cost 0).
func distance(p: int) -> int:
	var inf := 1 << 20
	var dist := {}
	var todo: Array = []  # simple 0-1 BFS with a deque
	for s in _starts(p):
		var v: int = board[s]
		if v == 3 - p:
			continue
		var c := 0 if v == p else 1
		if not dist.has(s) or c < dist[s]:
			dist[s] = c
			if c == 0:
				todo.push_front(s)
			else:
				todo.push_back(s)
	var best := inf
	while not todo.is_empty():
		var i: int = todo.pop_front()
		var d: int = dist[i]
		if _is_goal(p, i):
			best = mini(best, d)
		for j in neighbours(i):
			var v: int = board[j]
			if v == 3 - p:
				continue
			var nd := d + (0 if v == p else 1)
			if not dist.has(j) or nd < dist[j]:
				dist[j] = nd
				if v == p:
					todo.push_front(j)
				else:
					todo.push_back(j)
	return best

## Level 0 easy (a path-length guess), 1 normal and 2 hard (random
## playouts: fill the rest of the board at random many times and play the
## cell that ended up in our winning games most often).
func cpu_move(level: int, rng: RandomNumberGenerator) -> int:
	var me := turn
	var foe := 3 - turn
	var empties: Array = []
	for i in board.size():
		if board[i] == 0:
			empties.append(i)
	if empties.size() == board.size():
		return (size / 2) * size + size / 2
	if level == 0:
		return _greedy(empties, me, foe, rng)
	# Win now, or block a win next move.
	for p in [me, foe]:
		for i in empties:
			board[i] = p
			var done := not _connection(p).is_empty()
			board[i] = 0
			if done:
				return i
	var playouts: int = [0, 250, 900][level]
	var wins := {}
	var seen := {}
	for i in empties:
		wins[i] = 0
		seen[i] = 0
	var order := empties.duplicate()
	for k in playouts:
		# Shuffle the empty cells; alternate colours starting with ours.
		for a in range(order.size() - 1, 0, -1):
			var b := rng.randi_range(0, a)
			var t = order[a]
			order[a] = order[b]
			order[b] = t
		for idx in order.size():
			board[order[idx]] = me if idx % 2 == 0 else foe
		var won := not _connection(me).is_empty()
		for idx in order.size():
			if idx % 2 == 0:
				seen[order[idx]] += 1
				if won:
					wins[order[idx]] += 1
		for i in order:
			board[i] = 0
	var best: int = empties[0]
	var best_rate := -1.0
	for i in empties:
		var rate: float = (wins[i] + 0.5) / (seen[i] + 1.0) + rng.randf() * 0.001
		if rate > best_rate:
			best_rate = rate
			best = i
	return best

func _greedy(cands: Array, me: int, foe: int, rng: RandomNumberGenerator) -> int:
	var scored: Array = []
	for i in cands:
		board[i] = me
		var mine := distance(me)
		board[i] = foe
		var theirs := distance(foe)
		board[i] = 0
		var cx := absf(i % size - (size - 1) / 2.0) + absf(i / size - (size - 1) / 2.0)
		var s: float = -mine * 10.0 + theirs * 6.0 - cx * 0.3
		if mine == 0:
			s += 10000.0
		s += rng.randf() * 12.0
		scored.append([s, i])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return scored[0][1]
