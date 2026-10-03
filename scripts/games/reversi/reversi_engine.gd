extends RefCounted

const EMPTY := 0
const BLACK := 1
const WHITE := -1

const DIRECTIONS := [
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
	Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
]

var board: Array = []
var current_player: int = BLACK
var game_over: bool = false

func reset() -> void:
	board = []
	for r in range(8):
		var row: Array = []
		for c in range(8):
			row.append(EMPTY)
		board.append(row)
	board[3][3] = WHITE
	board[3][4] = BLACK
	board[4][3] = BLACK
	board[4][4] = WHITE
	current_player = BLACK
	game_over = false

func _in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < 8 and c >= 0 and c < 8

## Every opponent piece that would flip if `player` placed at (r,c), across
## all 8 directions. Empty if the square is occupied or the placement is illegal.
func _flips_for(r: int, c: int, player: int) -> Array:
	if board[r][c] != EMPTY:
		return []
	var all_flips: Array = []
	for d in DIRECTIONS:
		var line: Array = []
		var rr: int = r + d.x
		var cc: int = c + d.y
		while _in_bounds(rr, cc) and board[rr][cc] == -player:
			line.append(Vector2i(rr, cc))
			rr += d.x
			cc += d.y
		if _in_bounds(rr, cc) and board[rr][cc] == player and not line.is_empty():
			all_flips.append_array(line)
	return all_flips

func legal_moves(player: int) -> Array:
	var moves: Array = []
	for r in range(8):
		for c in range(8):
			if _can_place(r, c, player):
				moves.append(Vector2i(r, c))
	return moves

## _flips_for(...) is non-empty, without building the list (the AI asks a lot).
func _can_place(r: int, c: int, player: int) -> bool:
	if board[r][c] != EMPTY:
		return false
	for d in DIRECTIONS:
		var rr: int = r + d.x
		var cc: int = c + d.y
		var seen := false
		while rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and board[rr][cc] == -player:
			seen = true
			rr += d.x
			cc += d.y
		if seen and rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and board[rr][cc] == player:
			return true
	return false

func _mobility(player: int) -> int:
	var n := 0
	for r in range(8):
		for c in range(8):
			if _can_place(r, c, player):
				n += 1
	return n

## Places for current_player at (r,c). Returns {valid, flips, passed}.
## `passed` is true if the OTHER player had no legal reply and had to pass
## (turn comes right back to whoever just moved); sets game_over if neither
## player has a move after that.
func place(r: int, c: int) -> Dictionary:
	var flips: Array = _flips_for(r, c, current_player)
	if flips.is_empty():
		return {"valid": false}

	board[r][c] = current_player
	for p in flips:
		board[p.x][p.y] = current_player

	current_player = -current_player
	var passed := false
	if legal_moves(current_player).is_empty():
		passed = true
		current_player = -current_player
		if legal_moves(current_player).is_empty():
			game_over = true

	return {"valid": true, "flips": flips, "passed": passed}

func score() -> Dictionary:
	var black := 0
	var white := 0
	for r in range(8):
		for c in range(8):
			if board[r][c] == BLACK:
				black += 1
			elif board[r][c] == WHITE:
				white += 1
	return {"black": black, "white": white}

func winner() -> int:
	var s: Dictionary = score()
	if s.black > s.white:
		return BLACK
	if s.white > s.black:
		return WHITE
	return EMPTY

# ---------- computer opponent ----------

const _CPU_DEPTH := [1, 1, 2]
const _CPU_SLIP := [0.5, 0.12, 0.0]
## Classic square values: corners great, the squares next to them bad.
const _WEIGHTS := [
	[100, -20, 10, 5, 5, 10, -20, 100],
	[-20, -50, -2, -2, -2, -2, -50, -20],
	[10, -2, 1, 1, 1, 1, -2, 10],
	[5, -2, 1, 0, 0, 1, -2, 5],
	[5, -2, 1, 0, 0, 1, -2, 5],
	[10, -2, 1, 1, 1, 1, -2, 10],
	[-20, -50, -2, -2, -2, -2, -50, -20],
	[100, -20, 10, 5, 5, 10, -20, 100],
]

func clone():
	var e = get_script().new()
	e.board = []
	for row in board:
		e.board.append(row.duplicate())
	e.current_player = current_player
	e.game_over = game_over
	return e

## The square the computer plays for the player to move (level 0..2).
func cpu_move(level: int, rng: RandomNumberGenerator) -> Vector2i:
	var moves := legal_moves(current_player)
	if moves.is_empty():
		return Vector2i(-1, -1)
	level = clampi(level, 0, 2)
	if rng.randf() < _CPU_SLIP[level]:
		return moves[rng.randi() % moves.size()]
	var me := current_player
	var best_score := -1000000
	var best: Array = []
	for m in moves:
		var e = clone()
		e.place(m.x, m.y)
		var s: int = e._search(me, _CPU_DEPTH[level] - 1, -1000000, 1000000)
		if s > best_score:
			best_score = s
			best = [m]
		elif s == best_score:
			best.append(m)
	return best[rng.randi() % best.size()]

## Minimax from `me`'s point of view (turns can repeat after a pass).
func _search(me: int, depth: int, alpha: int, beta: int) -> int:
	if game_over:
		var s := score()
		var diff: int = (s.black - s.white) * (1 if me == BLACK else -1)
		return 0 if diff == 0 else (10000 + diff if diff > 0 else -10000 + diff)
	if depth <= 0:
		return _evaluate(me)
	var moves := legal_moves(current_player)
	var maximize := current_player == me
	var best := -1000000 if maximize else 1000000
	for m in moves:
		var e = clone()
		e.place(m.x, m.y)
		var v: int = e._search(me, depth - 1, alpha, beta)
		if maximize:
			best = maxi(best, v)
			alpha = maxi(alpha, v)
		else:
			best = mini(best, v)
			beta = mini(beta, v)
		if beta <= alpha:
			break
	return best

func _evaluate(me: int) -> int:
	var s := 0
	for r in range(8):
		for c in range(8):
			var v: int = board[r][c]
			if v != EMPTY:
				s += _WEIGHTS[r][c] * (1 if v == me else -1)
	s += 3 * (_mobility(me) - _mobility(-me))
	return s
