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
