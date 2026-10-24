extends Control

## The chess board, drawn in one Control: frame, squares (marble veins on the
## stone boards), a-h / 1-8 coordinates, the last move, the picked piece and
## where it can go, a king in check, a 💡 hint, lesson stars, and the pieces
## (chess_pieces.gd), which slide when they move. The board is the largest
## square that fits the Control. Taps come out as square_pressed(row, col) in
## board terms (row 0 = rank 8), already turned round when `flipped`.

signal square_pressed(r: int, c: int)

const ChessPieces = preload("res://scripts/games/chess/chess_pieces.gd")

var board: Array = []           # 8x8 ints, the engine's
var flipped := false            # Black at the bottom
var selected := Vector2i(-1, -1)
var dests: Dictionary = {}      # Vector2i -> true if it captures
var last_move: Array = []       # [from, to]
var check_sq := Vector2i(-1, -1)
var hint: Array = []            # [from, to]
var stars: Array = []           # Vector2i squares still to collect
var coords := true
var voodoo := false
var board_style: Dictionary = {}
var piece_style: Dictionary = {}  # {"white": {...}, "black": {...}}

var _anim_from := Vector2i(-1, -1)
var _anim_to := Vector2i(-1, -1)
var anim_t: float = 1.0:
	set(v):
		anim_t = v
		queue_redraw()
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

## The piece now on `to` slides there from `from`.
func animate(from: Vector2i, to: Vector2i) -> void:
	_anim_from = from
	_anim_to = to
	if _tween:
		_tween.kill()
	anim_t = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "anim_t", 1.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## Size of the whole board (frame included) and of one square, and the
## board's top-left corner.
func _metrics() -> Dictionary:
	var total: float = floorf(minf(size.x, size.y))
	var frame: float = floorf(total * 0.025)
	var cell: float = (total - frame * 2.0) / 8.0
	var origin := Vector2(floorf((size.x - total) / 2.0), floorf((size.y - total) / 2.0))
	return {"total": total, "frame": frame, "cell": cell, "origin": origin, "inner": origin + Vector2(frame, frame)}

## Board square -> its rectangle on screen.
func square_rect(sq: Vector2i) -> Rect2:
	var m := _metrics()
	var vr: int = 7 - sq.x if flipped else sq.x
	var vc: int = 7 - sq.y if flipped else sq.y
	return Rect2(m.inner + Vector2(vc, vr) * m.cell, Vector2(m.cell, m.cell))

func _gui_input(event: InputEvent) -> void:
	# Phones send each tap twice (touch + emulated mouse): the mouse one only.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var m := _metrics()
		var p: Vector2 = (event.position - m.inner) / m.cell
		if p.x < 0 or p.y < 0 or p.x >= 8 or p.y >= 8:
			return
		var vr := int(p.y)
		var vc := int(p.x)
		accept_event()
		square_pressed.emit(7 - vr if flipped else vr, 7 - vc if flipped else vc)

func _draw() -> void:
	if board.size() != 8:
		return
	var m := _metrics()
	var light: Color = board_style.get("light", Color("f0d9b5"))
	var dark: Color = board_style.get("dark", Color("b58863"))
	var frame_col: Color = board_style.get("frame", Color("6b4423"))
	var outer := Rect2(m.origin, Vector2(m.total, m.total))
	if voodoo:
		draw_rect(outer, Color(0.02, 0.03, 0.07))
	else:
		draw_rect(outer.grow(2), Color(0, 0, 0, 0.45))
		draw_rect(outer, frame_col)
	for r in range(8):
		for c in range(8):
			var sq := Vector2i(r, c)
			var rect := square_rect(sq)
			var is_dark: bool = (r + c) % 2 == 1
			draw_rect(rect, dark if is_dark else light)
			if board_style.get("veins", false):
				_draw_veins(rect, r * 8 + c, is_dark)
	if voodoo:
		var glow: Color = board_style.get("frame", Color("29e6ff"))
		for i in range(9):
			var x: float = m.inner.x + i * m.cell
			var y: float = m.inner.y + i * m.cell
			draw_line(Vector2(x, m.inner.y), Vector2(x, m.inner.y + m.cell * 8), Color(glow, 0.18), 1.0)
			draw_line(Vector2(m.inner.x, y), Vector2(m.inner.x + m.cell * 8, y), Color(glow, 0.18), 1.0)
		draw_rect(Rect2(m.inner, Vector2(m.cell * 8, m.cell * 8)), Color(glow, 0.8), false, 2.0)
	# Highlights: last move, the picked piece, a king in check, the hint.
	var mark := Color("f6d743") if not voodoo else Color("ffae2b")
	for sq in last_move:
		draw_rect(square_rect(sq), Color(mark, 0.33))
	if selected.x >= 0:
		draw_rect(square_rect(selected), Color(mark, 0.55))
	if check_sq.x >= 0:
		var cr := square_rect(check_sq)
		for k in [[0.62, 0.25], [0.48, 0.45], [0.34, 0.7]]:
			draw_circle(cr.get_center(), cr.size.x * k[0], Color(0.95, 0.12, 0.1, k[1]))
	for sq in hint:
		var hr := square_rect(sq).grow(-2)
		draw_rect(hr, Color("2bff88"), false, maxf(3.0, m.cell * 0.06))
	if coords:
		_draw_coords(m, light, dark)
	for sq in stars:
		_draw_star(square_rect(sq))
	# Pieces (the moving one last, on top).
	for r in range(8):
		for c in range(8):
			var v: int = board[r][c]
			if v == 0 or (anim_t < 1.0 and Vector2i(r, c) == _anim_to):
				continue
			_draw_piece(v, square_rect(Vector2i(r, c)))
	if anim_t < 1.0 and _anim_to.x >= 0 and board[_anim_to.x][_anim_to.y] != 0:
		var a := square_rect(_anim_from)
		var b := square_rect(_anim_to)
		_draw_piece(board[_anim_to.x][_anim_to.y], Rect2(a.position.lerp(b.position, anim_t), b.size))
	# Where the picked piece can go: a dot, or a ring round a capture.
	var dot := Color(0, 0, 0, 0.28) if not voodoo else Color("7dff3a", 0.6)
	for sq in dests:
		var dr := square_rect(sq)
		if dests[sq]:
			draw_arc(dr.get_center(), dr.size.x * 0.44, 0, TAU, 32, dot, maxf(3.0, dr.size.x * 0.08), true)
		else:
			draw_circle(dr.get_center(), dr.size.x * 0.15, dot)

func _draw_piece(v: int, rect: Rect2) -> void:
	var white: bool = v > 0
	var style: Dictionary = piece_style.get("white" if white else "black", {})
	ChessPieces.draw(self, absi(v), white, rect.grow(-rect.size.x * 0.04), style)

func _draw_coords(m: Dictionary, light: Color, dark: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(maxf(10.0, m.cell * 0.2))
	var pad: float = m.cell * 0.06
	for i in range(8):
		# Files along the bottom row, ranks down the left column (as seen).
		var file_sq := Vector2i(0 if flipped else 7, 7 - i if flipped else i)
		var fr := square_rect(file_sq)
		var on_dark: bool = (file_sq.x + file_sq.y) % 2 == 1
		var col: Color = (light if on_dark else dark) if not voodoo else Color("29e6ff", 0.75)
		draw_string(font, Vector2(fr.end.x - pad - font.get_string_size("h", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, fr.end.y - pad),
			"abcdefgh"[file_sq.y], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var rank_sq := Vector2i(7 - i if flipped else i, 7 if flipped else 0)
		var rr := square_rect(rank_sq)
		on_dark = (rank_sq.x + rank_sq.y) % 2 == 1
		col = (light if on_dark else dark) if not voodoo else Color("29e6ff", 0.75)
		draw_string(font, rr.position + Vector2(pad, pad + font.get_ascent(fs)), str(8 - rank_sq.x),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Faint marble veins, the same on every draw (seeded by the square).
func _draw_veins(rect: Rect2, seed_value: int, is_dark: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var col := Color(1, 1, 1, 0.16) if is_dark else Color(0, 0, 0, 0.1)
	for k in range(2):
		var pts := PackedVector2Array()
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		for j in range(4):
			pts.append(p)
			p += Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * rect.size
			p = p.clamp(rect.position, rect.end)
		draw_polyline(pts, col, maxf(1.0, rect.size.x * 0.015), true)

func _draw_star(rect: Rect2) -> void:
	var c := rect.get_center()
	var outer_r := rect.size.x * 0.32
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2.0 + i * PI / 5.0
		var rad := outer_r if i % 2 == 0 else outer_r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, Color("ffcc33"))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color("7a4a00"), maxf(1.5, rect.size.x * 0.03), true)
