extends RefCounted

const EMPTY := 0
const RED := 1
const YELLOW := 2
const COLS := 7
const ROWS := 6

## board[row][col], row 0 = top. 0=empty, 1=red, 2=yellow.
var board: Array = []
var turn: int = RED

func _init() -> void:
	reset()

func reset() -> void:
	board = []
	for r in range(ROWS):
		board.append([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	turn = RED

## Drops the current player's piece into the given column (0-6).
## Returns the landing row, or -1 if the column is full or the game is over.
func drop(col: int) -> int:
	if is_over():
		return -1
	for r in range(ROWS - 1, -1, -1):
		if board[r][col] == EMPTY:
			board[r][col] = turn
			turn = YELLOW if turn == RED else RED
			return r
	return -1

func winner() -> int:
	for r in range(ROWS):
		for c in range(COLS):
			var v: int = board[r][c]
			if v == EMPTY:
				continue
			for dir in [[0, 1], [1, 0], [1, 1], [1, -1]]:
				var count := 1
				var dr: int = dir[0]
				var dc: int = dir[1]
				var nr: int = r + dr
				var nc: int = c + dc
				while nr >= 0 and nr < ROWS and nc >= 0 and nc < COLS and board[nr][nc] == v:
					count += 1
					nr += dr
					nc += dc
				if count >= 4:
					return v
	return EMPTY

func is_full() -> bool:
	for c in range(COLS):
		if board[0][c] == EMPTY:
			return false
	return true

func is_over() -> bool:
	return winner() != EMPTY or is_full()

# ---------- computer opponent ----------

const _CPU_DEPTH := [1, 3, 4]
const _CPU_SLIP := [0.35, 0.08, 0.0]
const _ORDER := [3, 2, 4, 1, 5, 0, 6]
const _WIN := 100000

## The column the computer drops in for whoever's turn it is.
## level 0 = easy, 1 = medium, 2 = hard.
func cpu_move(level: int, rng: RandomNumberGenerator) -> int:
	var cells := PackedInt32Array()
	cells.resize(ROWS * COLS)
	var heights := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])  # discs per column
	for c in COLS:
		for r in range(ROWS - 1, -1, -1):
			var v: int = board[r][c]
			cells[r * COLS + c] = v
			if v != EMPTY:
				heights[c] = ROWS - r
	var free: Array = []
	for c in COLS:
		if heights[c] < ROWS:
			free.append(c)
	if free.is_empty():
		return -1
	level = clampi(level, 0, 2)
	var me := turn
	var foe := YELLOW if me == RED else RED
	# Always take a win, and (above easy) always block one.
	for side in ([me, foe] if level > 0 else [me]):
		for c in free:
			var r: int = ROWS - 1 - heights[c]
			cells[r * COLS + c] = side
			var wins := _wins_at(cells, r, c, side)
			cells[r * COLS + c] = EMPTY
			if wins:
				return c
	if rng.randf() < _CPU_SLIP[level]:
		return free[rng.randi() % free.size()]
	var best_score := -_WIN * 10
	var best: Array = []
	for c in _ORDER:
		if heights[c] >= ROWS:
			continue
		var r: int = ROWS - 1 - heights[c]
		cells[r * COLS + c] = me
		heights[c] += 1
		var s: int
		if _wins_at(cells, r, c, me):
			s = _WIN
		else:
			s = -_negamax(cells, heights, foe, me, _CPU_DEPTH[level] - 1, -_WIN * 10, _WIN * 10)
		heights[c] -= 1
		cells[r * COLS + c] = EMPTY
		if s > best_score:
			best_score = s
			best = [c]
		elif s == best_score:
			best.append(c)
	return best[rng.randi() % best.size()]

func _negamax(cells: PackedInt32Array, heights: PackedInt32Array, side: int, other: int, depth: int, alpha: int, beta: int) -> int:
	if depth <= 0:
		return _evaluate(cells, side) - _evaluate(cells, other)
	var any := false
	for c in _ORDER:
		if heights[c] >= ROWS:
			continue
		any = true
		var r: int = ROWS - 1 - heights[c]
		cells[r * COLS + c] = side
		heights[c] += 1
		var s: int
		if _wins_at(cells, r, c, side):
			s = _WIN + depth
		else:
			s = -_negamax(cells, heights, other, side, depth - 1, -beta, -alpha)
		heights[c] -= 1
		cells[r * COLS + c] = EMPTY
		if s > alpha:
			alpha = s
		if alpha >= beta:
			break
	return alpha if any else 0

func _wins_at(cells: PackedInt32Array, r: int, c: int, side: int) -> bool:
	for d in [[0, 1], [1, 0], [1, 1], [1, -1]]:
		var n := 1
		for sgn in [1, -1]:
			var rr: int = r + d[0] * sgn
			var cc: int = c + d[1] * sgn
			while rr >= 0 and rr < ROWS and cc >= 0 and cc < COLS and cells[rr * COLS + cc] == side:
				n += 1
				rr += d[0] * sgn
				cc += d[1] * sgn
		if n >= 4:
			return true
	return false

## Open windows of four: the more of `side`'s discs (and none of the other's), the better.
func _evaluate(cells: PackedInt32Array, side: int) -> int:
	var score := 0
	for r in ROWS:
		score += 3 if cells[r * COLS + 3] == side else 0
		for c in COLS:
			for d in [[0, 1], [1, 0], [1, 1], [-1, 1]]:
				var er: int = r + d[0] * 3
				var ec: int = c + d[1] * 3
				if er < 0 or er >= ROWS or ec >= COLS:
					continue
				var mine := 0
				var blocked := false
				for k in 4:
					var v: int = cells[(r + d[0] * k) * COLS + c + d[1] * k]
					if v == side:
						mine += 1
					elif v != EMPTY:
						blocked = true
						break
				if not blocked:
					score += [0, 1, 4, 20, 0][mine]
	return score
