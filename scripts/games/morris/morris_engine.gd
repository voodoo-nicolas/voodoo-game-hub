extends RefCounted

## Nine Men's Morris. Each side places 9 pieces, then moves them along the
## lines to a neighbouring empty point (or anywhere, once down to 3 pieces).
## Three in a row ("a mill") removes an opponent piece that isn't in a mill
## (unless all of them are). Fewer than 3 pieces, or no move, loses.
## Pure logic; includes a small alpha-beta computer player.

const EMPTY := 0
const COORDS := [Vector2i(0, 0), Vector2i(3, 0), Vector2i(6, 0), Vector2i(1, 1), Vector2i(3, 1), Vector2i(5, 1),
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(1, 5), Vector2i(3, 5), Vector2i(5, 5), Vector2i(0, 6), Vector2i(3, 6), Vector2i(6, 6)]
const ADJ := [[1, 9], [0, 2, 4], [1, 14], [4, 10], [1, 3, 5, 7], [4, 13], [7, 11], [4, 6, 8], [7, 12],
	[0, 10, 21], [3, 9, 11, 18], [6, 10, 15], [8, 13, 17], [5, 12, 14, 20], [2, 13, 23], [11, 16],
	[15, 17, 19], [12, 16], [10, 19], [16, 18, 20, 22], [13, 19], [9, 22], [19, 21, 23], [14, 22]]
const MILLS := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11], [12, 13, 14], [15, 16, 17], [18, 19, 20],
	[21, 22, 23], [0, 9, 21], [3, 10, 18], [6, 11, 15], [1, 4, 7], [16, 19, 22], [8, 12, 17],
	[5, 13, 20], [2, 14, 23]]
const DRAW_AFTER := 60   # moves without a mill once all pieces are placed

var board: Array = []
var to_place: Array = [9, 9]   # index = player - 1
var turn: int = 1              # 1 or 2
var winner: int = 0            # 0 none, 1/2, 3 draw
var quiet_moves: int = 0

func reset() -> void:
	board.clear()
	board.resize(24)
	board.fill(EMPTY)
	to_place = [9, 9]
	turn = 1
	winner = 0
	quiet_moves = 0

func count(p: int) -> int:
	return board.count(p)

func placing(p: int) -> bool:
	return to_place[p - 1] > 0

func flying(p: int) -> bool:
	return not placing(p) and count(p) == 3

func in_mill(pos: int, grid: Array = board) -> bool:
	var p: int = grid[pos]
	if p == EMPTY:
		return false
	for m in MILLS:
		if pos in m and grid[m[0]] == p and grid[m[1]] == p and grid[m[2]] == p:
			return true
	return false

## Pieces of `victim` that may be removed.
func removable(victim: int) -> Array:
	var all: Array = []
	var free: Array = []
	for i in 24:
		if board[i] == victim:
			all.append(i)
			if not in_mill(i):
				free.append(i)
	return free if not free.is_empty() else all

## Legal (from, to) pairs for `p`; from = -1 while placing.
func moves_for(p: int) -> Array:
	var out: Array = []
	if placing(p):
		for i in 24:
			if board[i] == EMPTY:
				out.append([-1, i])
		return out
	var fly := flying(p)
	for i in 24:
		if board[i] != p:
			continue
		var targets: Array = range(24) if fly else ADJ[i]
		for t in targets:
			if board[t] == EMPTY:
				out.append([i, t])
	return out

## Applies a move; returns true if it formed a mill (caller must then remove).
func apply_move(from: int, to: int) -> bool:
	if from == -1:
		to_place[turn - 1] -= 1
	else:
		board[from] = EMPTY
	board[to] = turn
	var mill := in_mill(to)
	if mill:
		quiet_moves = 0
	elif not placing(1) and not placing(2):
		quiet_moves += 1
	return mill

func remove_piece(pos: int) -> void:
	board[pos] = EMPTY

func end_turn() -> void:
	turn = 3 - turn
	_check_end()

func _check_end() -> void:
	for p in [1, 2]:
		if not placing(p) and count(p) < 3:
			winner = 3 - p
			return
	if moves_for(turn).is_empty():
		winner = 3 - turn
		return
	if quiet_moves >= DRAW_AFTER:
		winner = 3

# ---------- computer player ----------
# The search makes and unmakes moves in place (no copying) and orders mills
# first, so depth 2-3 stays fast enough on a phone.

## Full turns for the side to move: [from, to, remove (-1 if none)].
func full_moves() -> Array:
	var out: Array = []
	var quiet: Array = []
	var p := turn
	for m in moves_for(p):
		var from: int = m[0]
		var to: int = m[1]
		if from >= 0:
			board[from] = EMPTY
		board[to] = p
		if in_mill(to):
			for r in removable(3 - p):
				out.append([from, to, r])
		else:
			quiet.append([from, to, -1])
		board[to] = EMPTY
		if from >= 0:
			board[from] = p
	out.append_array(quiet)
	return out

func _make(m: Array) -> Array:
	var undo := [m, quiet_moves]
	if m[0] == -1:
		to_place[turn - 1] -= 1
	else:
		board[m[0]] = EMPTY
	board[m[1]] = turn
	if m[2] >= 0:
		board[m[2]] = EMPTY
		quiet_moves = 0
	elif not placing(1) and not placing(2):
		quiet_moves += 1
	turn = 3 - turn
	return undo

func _unmake(undo: Array) -> void:
	var m: Array = undo[0]
	turn = 3 - turn
	if m[2] >= 0:
		board[m[2]] = 3 - turn
	board[m[1]] = EMPTY
	if m[0] == -1:
		to_place[turn - 1] += 1
	else:
		board[m[0]] = turn
	quiet_moves = undo[1]

func best_move(depth: int) -> Array:
	var moves := full_moves()
	var best: Array = moves[randi() % moves.size()]
	var best_score := -INF
	var alpha := -INF
	for m in moves:
		var u := _make(m)
		var s := -_negamax(depth - 1, -INF, -alpha)
		_unmake(u)
		# small random tie-break so games differ
		s += randf() * 0.01
		if s > best_score:
			best_score = s
			best = m
		alpha = max(alpha, s)
	return best

func _negamax(depth: int, alpha: float, beta: float) -> float:
	var p := turn
	if not placing(p) and count(p) < 3:
		return -1000.0 - depth
	if depth == 0:
		return _evaluate(p)
	var moves := full_moves()
	if moves.is_empty():
		return -1000.0 - depth
	for m in moves:
		var u := _make(m)
		var s := -_negamax(depth - 1, -beta, -alpha)
		_unmake(u)
		if s > alpha:
			alpha = s
		if alpha >= beta:
			break
	return alpha

func _evaluate(p: int) -> float:
	var o := 3 - p
	var score: float = 10.0 * ((count(p) + to_place[p - 1]) - (count(o) + to_place[o - 1]))
	for m in MILLS:
		var mine := 0
		var theirs := 0
		for i in m:
			if board[i] == p: mine += 1
			elif board[i] == o: theirs += 1
		if mine == 2 and theirs == 0: score += 2.0
		if theirs == 2 and mine == 0: score -= 2.0
	# mobility: empty neighbours of each side's pieces
	for i in 24:
		var v: int = board[i]
		if v == EMPTY:
			continue
		var free := 0
		for nb in ADJ[i]:
			if board[nb] == EMPTY:
				free += 1
		score += 0.3 * free if v == p else -0.3 * free
	return score
