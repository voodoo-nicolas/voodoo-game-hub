extends RefCounted

## board[r][c]: 0 empty, 1 P1 man, 2 P1 king, -1 P2 man, -2 P2 king.
## P1 starts at the bottom (rows 5-7) and moves toward row 0; P2 starts at the
## top (rows 0-2) and moves toward row 7. Standard American checkers rules:
## mandatory capture (if any piece can capture, only capture moves are legal),
## multi-jump chains, forced continuation with the same piece, kings on
## reaching the far row (which ends the turn even mid-chain).
var board: Array = []
var current_player: int = 1
var winner: int = 0
var game_over: bool = false
var must_continue_from: Vector2i = Vector2i(-1, -1)
## Moves in a row (both players) with no capture and no man moving -- only
## kings shuffling around. At DRAW_QUIET_MOVES the game is a draw, the
## standard American "40 moves each without progress" rule; without it two
## kings could chase each other forever.
var quiet_moves: int = 0
const DRAW_QUIET_MOVES := 80

func reset() -> void:
	board = []
	for r in range(8):
		var row: Array = []
		for c in range(8):
			row.append(0)
		board.append(row)
	for r in range(3):
		for c in range(8):
			if (r + c) % 2 == 1:
				board[r][c] = -1
	for r in range(5, 8):
		for c in range(8):
			if (r + c) % 2 == 1:
				board[r][c] = 1
	current_player = 1
	winner = 0
	game_over = false
	must_continue_from = Vector2i(-1, -1)
	quiet_moves = 0

func _is_king(v: int) -> bool:
	return absi(v) == 2

func _owner(v: int) -> int:
	if v == 0:
		return 0
	return 1 if v > 0 else -1

func _in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < 8 and c >= 0 and c < 8

func _piece_directions(v: int) -> Array:
	if _is_king(v):
		return [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	elif v > 0:
		return [Vector2i(-1, 1), Vector2i(-1, -1)]
	else:
		return [Vector2i(1, 1), Vector2i(1, -1)]

func _captures_for_piece(r: int, c: int) -> Array:
	var v: int = board[r][c]
	if v == 0:
		return []
	var result: Array = []
	for d in _piece_directions(v):
		var mr: int = r + d.x
		var mc: int = c + d.y
		var lr: int = r + d.x * 2
		var lc: int = c + d.y * 2
		if _in_bounds(mr, mc) and _in_bounds(lr, lc):
			var mid: int = board[mr][mc]
			if _owner(mid) == -_owner(v) and board[lr][lc] == 0:
				result.append({"to": Vector2i(lr, lc), "captured": Vector2i(mr, mc)})
	return result

## {Vector2i(r,c): [capture dicts]} for every current-player piece with >=1 capture.
func _all_captures() -> Dictionary:
	var out := {}
	for r in range(8):
		for c in range(8):
			if _owner(board[r][c]) == current_player:
				var caps: Array = _captures_for_piece(r, c)
				if not caps.is_empty():
					out[Vector2i(r, c)] = caps
	return out

func _simple_moves_for_piece(r: int, c: int) -> Array:
	var v: int = board[r][c]
	var result: Array = []
	for d in _piece_directions(v):
		var nr: int = r + d.x
		var nc: int = c + d.y
		if _in_bounds(nr, nc) and board[nr][nc] == 0:
			result.append(Vector2i(nr, nc))
	return result

## {captures: [...], moves: [...]} for the piece at (r,c), respecting mandatory
## capture (if ANY current-player piece can capture, non-capturing pieces and
## simple moves are both illegal) and forced multi-jump continuation.
func legal_moves_for(r: int, c: int) -> Dictionary:
	if _owner(board[r][c]) != current_player:
		return {"captures": [], "moves": []}
	if must_continue_from.x >= 0 and must_continue_from != Vector2i(r, c):
		return {"captures": [], "moves": []}
	var all_caps: Dictionary = _all_captures()
	if not all_caps.is_empty():
		var key := Vector2i(r, c)
		if all_caps.has(key):
			return {"captures": all_caps[key], "moves": []}
		return {"captures": [], "moves": []}
	return {"captures": [], "moves": _simple_moves_for_piece(r, c)}

## Returns {valid, captured (Vector2i or (-1,-1)), promoted, chain_continues}.
func move(from: Vector2i, to: Vector2i) -> Dictionary:
	var legal: Dictionary = legal_moves_for(from.x, from.y)
	var v: int = board[from.x][from.y]
	var is_capture := false
	var captured_pos := Vector2i(-1, -1)

	if not legal.captures.is_empty():
		for cap in legal.captures:
			if cap.to == to:
				is_capture = true
				captured_pos = cap.captured
				break
		if not is_capture:
			return {"valid": false}
	else:
		if not legal.moves.has(to):
			return {"valid": false}

	board[from.x][from.y] = 0
	board[to.x][to.y] = v
	if is_capture:
		board[captured_pos.x][captured_pos.y] = 0

	if is_capture or not _is_king(v):
		quiet_moves = 0
	else:
		quiet_moves += 1

	var promoted := false
	if not _is_king(v):
		if (v > 0 and to.x == 0) or (v < 0 and to.x == 7):
			board[to.x][to.y] = 2 if v > 0 else -2
			promoted = true

	var chain_continues := false
	if is_capture and not promoted:
		if not _captures_for_piece(to.x, to.y).is_empty():
			chain_continues = true
			must_continue_from = to

	if not chain_continues:
		must_continue_from = Vector2i(-1, -1)
		current_player = -current_player
		_check_game_over()
		if not game_over and quiet_moves >= DRAW_QUIET_MOVES:
			game_over = true
			winner = 0  # draw

	return {
		"valid": true,
		"captured": captured_pos,
		"promoted": promoted,
		"chain_continues": chain_continues,
	}

## The player now to move loses if they have no legal moves at all.
func _check_game_over() -> void:
	for r in range(8):
		for c in range(8):
			if _owner(board[r][c]) == current_player:
				var lm: Dictionary = legal_moves_for(r, c)
				if not lm.captures.is_empty() or not lm.moves.is_empty():
					return
	game_over = true
	winner = -current_player

# ---------- computer opponent ----------

## Plies (whole turns) searched per level: easy, medium, hard.
const _CPU_DEPTH := [1, 2, 3]
const _CPU_SLIP := [0.4, 0.1, 0.0]

func clone():
	var e = get_script().new()
	e.board = []
	for row in board:
		e.board.append(row.duplicate())
	e.current_player = current_player
	e.winner = winner
	e.game_over = game_over
	e.must_continue_from = must_continue_from
	e.quiet_moves = quiet_moves
	return e

## Every complete turn for the player to move: each is an Array of
## [from, to] steps (several for a multi-jump).
func all_turns() -> Array:
	var out: Array = []
	for r in range(8):
		for c in range(8):
			if _owner(board[r][c]) != current_player:
				continue
			var lm: Dictionary = legal_moves_for(r, c)
			var targets: Array = []
			for cap in lm.captures:
				targets.append(cap.to)
			targets.append_array(lm.moves)
			for t in targets:
				_extend_turn(self, [[Vector2i(r, c), t]], out)
	return out

## `e` is the position before the last step of `steps`.
static func _extend_turn(e, steps: Array, out: Array) -> void:
	var after = e.clone()
	var last: Array = steps[steps.size() - 1]
	var res: Dictionary = after.move(last[0], last[1])
	if not res.get("valid", false):
		return
	if not res.chain_continues:
		out.append(steps)
		return
	for cap in after.legal_moves_for(last[1].x, last[1].y).captures:
		var next := steps.duplicate()
		next.append([last[1], cap.to])
		_extend_turn(after, next, out)

func apply_turn(steps: Array) -> void:
	for s in steps:
		move(s[0], s[1])

## The computer's whole turn for the player to move.
func cpu_turn(level: int, rng: RandomNumberGenerator) -> Array:
	var turns := all_turns()
	if turns.is_empty():
		return []
	level = clampi(level, 0, 2)
	if rng.randf() < _CPU_SLIP[level]:
		return turns[rng.randi() % turns.size()]
	var me := current_player
	var best_score := -1000000
	var best: Array = []
	for t in turns:
		var e = clone()
		e.apply_turn(t)
		var s: int = -e._negamax(_CPU_DEPTH[level] - 1, -1000000, 1000000)
		if s > best_score:
			best_score = s
			best = [t]
		elif s == best_score:
			best.append(t)
	return best[rng.randi() % best.size()]

func _negamax(depth: int, alpha: int, beta: int) -> int:
	if game_over:
		return 0 if winner == 0 else (100000 + depth if winner == current_player else -100000 - depth)
	if depth <= 0:
		return _evaluate(current_player)
	var turns := all_turns()
	for t in turns:
		var e = clone()
		e.apply_turn(t)
		var s: int = -e._negamax(depth - 1, -beta, -alpha)
		if s > alpha:
			alpha = s
		if alpha >= beta:
			break
	return alpha

## Material (kings worth more), plus a little for advancing men and holding the back row.
func _evaluate(side: int) -> int:
	var score := 0
	for r in range(8):
		for c in range(8):
			var v: int = board[r][c]
			if v == 0:
				continue
			var worth := 160 if _is_king(v) else 100
			if not _is_king(v):
				var advance: int = (7 - r) if v > 0 else r
				worth += advance * 3
				if (v > 0 and r == 7) or (v < 0 and r == 0):
					worth += 6
			if c == 0 or c == 7:
				worth += 4
			score += worth if _owner(v) == side else -worth
	return score
