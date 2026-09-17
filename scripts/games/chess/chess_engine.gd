extends RefCounted

## Signed-int board: 0 empty, positive = White, negative = Black, magnitude =
## piece type. Row 0 is Black's back rank, row 7 is White's -- White moves
## "up" (decreasing row) toward row 0, mirroring Checkers' P1-at-the-bottom
## convention (White = player 1 = positive).
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const WHITE := 1
const BLACK := -1

const KNIGHT_OFFSETS := [
	Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, -2), Vector2i(-1, 2),
	Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1),
]
const KING_OFFSETS := [
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
	Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
]
const BISHOP_DIRS := [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
const ROOK_DIRS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

var board: Array = []  # 8x8 ints
var current_player: int = WHITE
var castling_rights: Dictionary = {}  # "K","Q","k","q" -> bool
var en_passant_target: Vector2i = Vector2i(-1, -1)
var halfmove_clock: int = 0
var move_history: Array = []
var game_over: bool = false
var winner: int = 0  # 0 = none/draw, else WHITE or BLACK
var result_reason: String = ""  # "checkmate" | "stalemate" | "draw_50move" | "draw_insufficient_material"

func reset() -> void:
	board = []
	for r in range(8):
		var row: Array = []
		for c in range(8):
			row.append(0)
		board.append(row)

	var back_rank := [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
	for c in range(8):
		board[0][c] = -back_rank[c]
		board[1][c] = -PAWN
		board[6][c] = PAWN
		board[7][c] = back_rank[c]

	current_player = WHITE
	castling_rights = {"K": true, "Q": true, "k": true, "q": true}
	en_passant_target = Vector2i(-1, -1)
	halfmove_clock = 0
	move_history = []
	game_over = false
	winner = 0
	result_reason = ""

func _in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < 8 and c >= 0 and c < 8

func _owner(v: int) -> int:
	if v == 0:
		return 0
	return WHITE if v > 0 else BLACK

## Public alias of _owner() for UI code -- e.g. deciding if a tapped square
## holds a piece belonging to the side to move.
func owner_of(v: int) -> int:
	return _owner(v)

## Public alias of _find_king() for UI code -- e.g. highlighting a king that's
## in check.
func find_king(player: int) -> Vector2i:
	return _find_king(player)

func _piece_type(v: int) -> int:
	return absi(v)

# ---------- pseudo-legal move generation ----------
# Each move is {to, is_capture, is_en_passant, is_castle, is_double_step, promotes}.
# None of this filters for king safety -- legal_moves_for() does that.

func _pseudo_legal_moves_for(r: int, c: int) -> Array:
	var v: int = board[r][c]
	if v == 0:
		return []
	var owner: int = _owner(v)
	var ptype: int = _piece_type(v)
	var moves: Array = []

	match ptype:
		PAWN:
			moves = _pawn_moves(r, c, owner)
		KNIGHT:
			for off in KNIGHT_OFFSETS:
				_try_add_step(moves, r, c, off, owner)
		BISHOP:
			_add_sliding_moves(moves, r, c, owner, BISHOP_DIRS)
		ROOK:
			_add_sliding_moves(moves, r, c, owner, ROOK_DIRS)
		QUEEN:
			_add_sliding_moves(moves, r, c, owner, BISHOP_DIRS)
			_add_sliding_moves(moves, r, c, owner, ROOK_DIRS)
		KING:
			for off in KING_OFFSETS:
				_try_add_step(moves, r, c, off, owner)
			_add_castle_moves(moves, r, c, owner)

	return moves

func _blank_move(to: Vector2i) -> Dictionary:
	return {"to": to, "is_capture": false, "is_en_passant": false, "is_castle": false, "is_double_step": false, "promotes": false}

func _try_add_step(moves: Array, r: int, c: int, off: Vector2i, owner: int) -> void:
	var nr: int = r + off.x
	var nc: int = c + off.y
	if not _in_bounds(nr, nc):
		return
	var target: int = board[nr][nc]
	if _owner(target) == owner:
		return
	var m := _blank_move(Vector2i(nr, nc))
	m.is_capture = target != 0
	moves.append(m)

func _add_sliding_moves(moves: Array, r: int, c: int, owner: int, dirs: Array) -> void:
	for d in dirs:
		var nr: int = r + d.x
		var nc: int = c + d.y
		while _in_bounds(nr, nc):
			var target: int = board[nr][nc]
			if _owner(target) == owner:
				break
			var m := _blank_move(Vector2i(nr, nc))
			m.is_capture = target != 0
			moves.append(m)
			if target != 0:
				break
			nr += d.x
			nc += d.y

func _pawn_moves(r: int, c: int, owner: int) -> Array:
	var moves: Array = []
	var dir: int = -1 if owner == WHITE else 1
	var start_row: int = 6 if owner == WHITE else 1
	var promo_row: int = 0 if owner == WHITE else 7

	var one_r: int = r + dir
	if _in_bounds(one_r, c) and board[one_r][c] == 0:
		var m := _blank_move(Vector2i(one_r, c))
		m.promotes = one_r == promo_row
		moves.append(m)
		var two_r: int = r + dir * 2
		if r == start_row and board[two_r][c] == 0:
			var m2 := _blank_move(Vector2i(two_r, c))
			m2.is_double_step = true
			moves.append(m2)

	for dc in [-1, 1]:
		var nc: int = c + dc
		var nr: int = r + dir
		if not _in_bounds(nr, nc):
			continue
		var target: int = board[nr][nc]
		if target != 0 and _owner(target) != owner:
			var m := _blank_move(Vector2i(nr, nc))
			m.is_capture = true
			m.promotes = nr == promo_row
			moves.append(m)
		elif target == 0 and Vector2i(nr, nc) == en_passant_target:
			var m3 := _blank_move(Vector2i(nr, nc))
			m3.is_capture = true
			m3.is_en_passant = true
			moves.append(m3)

	return moves

func _add_castle_moves(moves: Array, r: int, c: int, owner: int) -> void:
	var back_row: int = 7 if owner == WHITE else 0
	if r != back_row or c != 4:
		return

	var king_flag: String = "K" if owner == WHITE else "k"
	var queen_flag: String = "Q" if owner == WHITE else "q"
	var enemy: int = -owner

	if castling_rights.get(king_flag, false):
		if board[back_row][5] == 0 and board[back_row][6] == 0:
			if not _is_square_attacked(back_row, 4, enemy) and not _is_square_attacked(back_row, 5, enemy) and not _is_square_attacked(back_row, 6, enemy):
				var m := _blank_move(Vector2i(back_row, 6))
				m.is_castle = true
				moves.append(m)

	if castling_rights.get(queen_flag, false):
		if board[back_row][1] == 0 and board[back_row][2] == 0 and board[back_row][3] == 0:
			if not _is_square_attacked(back_row, 4, enemy) and not _is_square_attacked(back_row, 3, enemy) and not _is_square_attacked(back_row, 2, enemy):
				var m := _blank_move(Vector2i(back_row, 2))
				m.is_castle = true
				moves.append(m)

# ---------- attack detection ----------

## Is (r,c) attacked by any of by_player's pieces, on the current board?
## The single shared primitive for check detection and castling legality.
func _is_square_attacked(r: int, c: int, by_player: int) -> bool:
	var pawn_dir: int = -1 if by_player == WHITE else 1
	var pr: int = r - pawn_dir
	for dc in [-1, 1]:
		var pc: int = c + dc
		if _in_bounds(pr, pc) and board[pr][pc] == PAWN * by_player:
			return true

	for off in KNIGHT_OFFSETS:
		var nr: int = r + off.x
		var nc: int = c + off.y
		if _in_bounds(nr, nc) and board[nr][nc] == KNIGHT * by_player:
			return true

	for off in KING_OFFSETS:
		var nr2: int = r + off.x
		var nc2: int = c + off.y
		if _in_bounds(nr2, nc2) and board[nr2][nc2] == KING * by_player:
			return true

	for d in BISHOP_DIRS:
		var nr3: int = r + d.x
		var nc3: int = c + d.y
		while _in_bounds(nr3, nc3):
			var v: int = board[nr3][nc3]
			if v != 0:
				if _owner(v) == by_player and (_piece_type(v) == BISHOP or _piece_type(v) == QUEEN):
					return true
				break
			nr3 += d.x
			nc3 += d.y

	for d in ROOK_DIRS:
		var nr4: int = r + d.x
		var nc4: int = c + d.y
		while _in_bounds(nr4, nc4):
			var v: int = board[nr4][nc4]
			if v != 0:
				if _owner(v) == by_player and (_piece_type(v) == ROOK or _piece_type(v) == QUEEN):
					return true
				break
			nr4 += d.x
			nc4 += d.y

	return false

func _find_king(player: int) -> Vector2i:
	for r in range(8):
		for c in range(8):
			if board[r][c] == KING * player:
				return Vector2i(r, c)
	return Vector2i(-1, -1)

func is_in_check(player: int) -> bool:
	var king_pos: Vector2i = _find_king(player)
	if king_pos.x < 0:
		return false
	return _is_square_attacked(king_pos.x, king_pos.y, -player)

# ---------- make / unmake ----------
# Shared by legal_moves_for()'s king-safety filter and (Phase 3) the AI's
# search tree, so legality-checking and AI search can never disagree.

func _make_move_raw(from: Vector2i, move: Dictionary, promotion_piece: int = QUEEN) -> Dictionary:
	var piece: int = board[from.x][from.y]
	var owner: int = _owner(piece)
	var to: Vector2i = move.to

	var captured_piece: int = 0
	var captured_square := Vector2i(-1, -1)
	if move.is_en_passant:
		captured_square = Vector2i(from.x, to.y)
		captured_piece = board[captured_square.x][captured_square.y]
		board[captured_square.x][captured_square.y] = 0
	elif move.is_capture:
		captured_square = to
		captured_piece = board[to.x][to.y]

	var castle_rook_from := Vector2i(-1, -1)
	var castle_rook_to := Vector2i(-1, -1)
	if move.is_castle:
		var back_row: int = from.x
		if to.y == 6:
			castle_rook_from = Vector2i(back_row, 7)
			castle_rook_to = Vector2i(back_row, 5)
		else:
			castle_rook_from = Vector2i(back_row, 0)
			castle_rook_to = Vector2i(back_row, 3)
		board[castle_rook_to.x][castle_rook_to.y] = board[castle_rook_from.x][castle_rook_from.y]
		board[castle_rook_from.x][castle_rook_from.y] = 0

	var record := {
		"from": from, "to": to, "piece": piece,
		"captured_piece": captured_piece, "captured_square": captured_square,
		"is_castle": move.is_castle, "castle_rook_from": castle_rook_from, "castle_rook_to": castle_rook_to,
		"is_en_passant": move.is_en_passant,
		"promoted": move.promotes,
		"prev_castling_rights": castling_rights.duplicate(),
		"prev_en_passant_target": en_passant_target,
		"prev_halfmove_clock": halfmove_clock,
	}

	board[from.x][from.y] = 0
	board[to.x][to.y] = (promotion_piece * owner) if move.promotes else piece

	_update_castling_rights_after_move(from, piece, captured_piece, captured_square)

	if move.is_double_step:
		en_passant_target = Vector2i((from.x + to.x) / 2, from.y)
	else:
		en_passant_target = Vector2i(-1, -1)

	if _piece_type(piece) == PAWN or move.is_capture:
		halfmove_clock = 0
	else:
		halfmove_clock += 1

	return record

func _unmake_move_raw(record: Dictionary) -> void:
	var from: Vector2i = record.from
	var to: Vector2i = record.to

	if record.is_castle:
		board[record.castle_rook_from.x][record.castle_rook_from.y] = board[record.castle_rook_to.x][record.castle_rook_to.y]
		board[record.castle_rook_to.x][record.castle_rook_to.y] = 0

	board[from.x][from.y] = record.piece
	board[to.x][to.y] = 0
	if record.captured_piece != 0:
		board[record.captured_square.x][record.captured_square.y] = record.captured_piece

	castling_rights = record.prev_castling_rights.duplicate()
	en_passant_target = record.prev_en_passant_target
	halfmove_clock = record.prev_halfmove_clock

func _update_castling_rights_after_move(from: Vector2i, piece: int, captured_piece: int, captured_square: Vector2i) -> void:
	var ptype: int = _piece_type(piece)
	if ptype == KING:
		if piece > 0:
			castling_rights["K"] = false
			castling_rights["Q"] = false
		else:
			castling_rights["k"] = false
			castling_rights["q"] = false
	elif ptype == ROOK:
		_revoke_rook_right(from, piece > 0)
	if captured_piece != 0 and _piece_type(captured_piece) == ROOK:
		_revoke_rook_right(captured_square, captured_piece > 0)

func _revoke_rook_right(square: Vector2i, is_white: bool) -> void:
	var back_row: int = 7 if is_white else 0
	if square.x != back_row:
		return
	if square.y == 0:
		castling_rights[("Q" if is_white else "q")] = false
	elif square.y == 7:
		castling_rights[("K" if is_white else "k")] = false

# ---------- public legality API ----------

func legal_moves_for(r: int, c: int) -> Array:
	var piece: int = board[r][c]
	if piece == 0 or _owner(piece) != current_player:
		return []
	var owner: int = current_player
	var legal: Array = []
	for move in _pseudo_legal_moves_for(r, c):
		var record: Dictionary = _make_move_raw(Vector2i(r, c), move, QUEEN)
		if not is_in_check(owner):
			legal.append(move)
		_unmake_move_raw(record)
	return legal

## {from: Vector2i, move: Dictionary} for every legal move `player` has.
func get_all_legal_moves(player: int) -> Array:
	var out: Array = []
	for r in range(8):
		for c in range(8):
			if _owner(board[r][c]) == player:
				for m in legal_moves_for(r, c):
					out.append({"from": Vector2i(r, c), "move": m})
	return out

func is_promotion_move(from: Vector2i, to: Vector2i) -> bool:
	for m in legal_moves_for(from.x, from.y):
		if m.to == to:
			return m.promotes
	return false

## Returns {valid} or {valid, is_capture, is_en_passant, is_castle, promotes,
## game_over, result_reason, winner}.
func move(from: Vector2i, to: Vector2i, promotion_piece: int = QUEEN) -> Dictionary:
	if game_over:
		return {"valid": false}

	var chosen = null
	for m in legal_moves_for(from.x, from.y):
		if m.to == to:
			chosen = m
			break
	if chosen == null:
		return {"valid": false}

	var record: Dictionary = _make_move_raw(from, chosen, promotion_piece)
	record["promotion_piece"] = promotion_piece if chosen.promotes else 0
	move_history.append(record)

	current_player = -current_player
	_update_game_over_status()

	return {
		"valid": true,
		"is_capture": chosen.is_capture,
		"is_en_passant": chosen.is_en_passant,
		"is_castle": chosen.is_castle,
		"promotes": chosen.promotes,
		"game_over": game_over,
		"result_reason": result_reason,
		"winner": winner,
	}

# ---------- game-over detection ----------

func _update_game_over_status() -> void:
	if get_all_legal_moves(current_player).is_empty():
		game_over = true
		if is_in_check(current_player):
			result_reason = "checkmate"
			winner = -current_player
		else:
			result_reason = "stalemate"
			winner = 0
		return

	if halfmove_clock >= 100:
		game_over = true
		result_reason = "draw_50move"
		winner = 0
		return

	if _is_insufficient_material():
		game_over = true
		result_reason = "draw_insufficient_material"
		winner = 0
		return

	game_over = false
	result_reason = ""
	winner = 0

## Per-side test: could this side, in principle, ever force checkmate with
## its current material alone (ignoring the opponent's material entirely)?
## If neither side can, the game is an automatic draw. Any pawn/rook/queen is
## always sufficient; among minors, a bishop pair on opposite-colored squares
## or a bishop+knight pair can force mate, but 2+ knights alone or 2+ bishops
## on the same color cannot (this matches the common convention used by
## chess engines/software, e.g. python-chess's is_insufficient_material()).
func _is_insufficient_material() -> bool:
	return not _side_has_mating_material(WHITE) and not _side_has_mating_material(BLACK)

func _side_has_mating_material(player: int) -> bool:
	var bishops_light := 0
	var bishops_dark := 0
	var knights := 0
	for r in range(8):
		for c in range(8):
			var v: int = board[r][c]
			if _owner(v) != player:
				continue
			var ptype: int = _piece_type(v)
			if ptype == PAWN or ptype == ROOK or ptype == QUEEN:
				return true
			if ptype == BISHOP:
				if (r + c) % 2 == 0:
					bishops_dark += 1
				else:
					bishops_light += 1
			elif ptype == KNIGHT:
				knights += 1

	if bishops_light > 0 and bishops_dark > 0:
		return true
	if (bishops_light + bishops_dark) > 0 and knights > 0:
		return true
	return false
