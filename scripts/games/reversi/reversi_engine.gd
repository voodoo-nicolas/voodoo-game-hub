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
			if not _flips_for(r, c, player).is_empty():
				moves.append(Vector2i(r, c))
	return moves

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
