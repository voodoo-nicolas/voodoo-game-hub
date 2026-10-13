extends RefCounted

## Puzzle & Board category TEASERS (batch 3, 2026-10-13): 160x90 mini scenes for all 29
## games (the six with older logos included). Same rules as game_teasers.gd; helpers from
## game_logos.gd (L), game_logos_puzzle.gd (P) and game_teasers.gd (T).
## Add one: `_teaser_<id>(c, base)`, id in IDS, line in `_scene()`.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")
const P = preload("res://scripts/common/game_logos_puzzle.gd")
const T = preload("res://scripts/common/game_teasers.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const BROWN := P.BROWN
const W := 160.0
const H := 90.0

const IDS := [
	"chess", "sudoku", "tictactoe", "connect4", "checkers", "reversi",
	"minesweeper", "sea_battle", "dots_boxes", "mancala", "backgammon", "morris",
	"peg_solitaire", "lights_out", "box_pusher", "fifteen_puzzle", "g2048", "kakuro",
	"nonogram", "code_breaker", "hanoi", "calcudoku", "pipe_flow", "five_in_row",
	"mahjong", "flood_it", "same_game", "binary_grid", "hex",
]

static func has(id: String) -> bool:
	return id in IDS

static func draw(c: Control, id: String) -> void:
	var s: float = minf(c.size.x / W, c.size.y / H)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - W * s) * 0.5, (c.size.y - H * s) * 0.5)
	var base := Transform2D(0.0, Vector2(s, s), 0.0, origin)
	c.draw_set_transform_matrix(base)
	_scene(c, base, id)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _scene(c: CanvasItem, base: Transform2D, id: String) -> void:
	match id:
		"chess": _teaser_chess(c, base)
		"sudoku": _teaser_sudoku(c, base)
		"tictactoe": _teaser_tictactoe(c, base)
		"connect4": _teaser_connect4(c, base)
		"checkers": _teaser_checkers(c, base)
		"reversi": _teaser_reversi(c, base)
		"minesweeper": _teaser_minesweeper(c, base)
		"sea_battle": _teaser_sea_battle(c, base)
		"dots_boxes": _teaser_dots_boxes(c, base)
		"mancala": _teaser_mancala(c, base)
		"backgammon": _teaser_backgammon(c, base)
		"morris": _teaser_morris(c, base)
		"peg_solitaire": _teaser_peg_solitaire(c, base)
		"lights_out": _teaser_lights_out(c, base)
		"box_pusher": _teaser_box_pusher(c, base)
		"fifteen_puzzle": _teaser_fifteen_puzzle(c, base)
		"g2048": _teaser_g2048(c, base)
		"kakuro": _teaser_kakuro(c, base)
		"nonogram": _teaser_nonogram(c, base)
		"code_breaker": _teaser_code_breaker(c, base)
		"hanoi": _teaser_hanoi(c, base)
		"calcudoku": _teaser_calcudoku(c, base)
		"pipe_flow": _teaser_pipe_flow(c, base)
		"five_in_row": _teaser_five_in_row(c, base)
		"mahjong": _teaser_mahjong(c, base)
		"flood_it": _teaser_flood_it(c, base)
		"same_game": _teaser_same_game(c, base)
		"binary_grid": _teaser_binary_grid(c, base)
		"hex": _teaser_hex(c, base)

## An n x n checkered board; dark squares tinted `col`.
static func _board(c: CanvasItem, x0: float, y0: float, n: int, cs: float, col: Color, tint: float = 0.38) -> void:
	for r in range(n):
		for k in range(n):
			var rc := Rect2(x0 + k * cs, y0 + r * cs, cs, cs)
			c.draw_rect(rc, Color(col, tint) if (r + k) % 2 == 1 else Color(1, 1, 1, 0.05))
	GI._glow_poly(c, PackedVector2Array([Vector2(x0, y0), Vector2(x0 + n * cs, y0), Vector2(x0 + n * cs, y0 + n * cs), Vector2(x0, y0 + n * cs)]), col, 1.2)

## ---------- the 29 Puzzle & Board teasers ----------

static func _teaser_chess(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	_board(c, 40, 5, 8, 10, CYAN)
	for sq in [Vector2i(3, 4), Vector2i(2, 4), Vector2i(1, 4)]:
		c.draw_rect(Rect2(40 + sq.x * 10, 5 + sq.y * 10, 10, 10), Color(LIME, 0.3))
	for sq in [Vector2i(4, 6), Vector2i(2, 2), Vector2i(6, 3), Vector2i(1, 1), Vector2i(5, 5)]:
		P.old_logo_at(c, base, "chess", Vector2(45 + sq.x * 10, 10 + sq.y * 10), 13.0)
	GI._sphere(c, Vector2(25, 22), 5.0, LIME)

static func _teaser_sudoku(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var cs := 9.0
	var x0 := 39.5
	var y0 := 4.5
	for i in range(10):
		var heavy: bool = i % 3 == 0
		var col := Color(CYAN, 1.0 if heavy else 0.3)
		c.draw_line(Vector2(x0 + i * cs, y0), Vector2(x0 + i * cs, y0 + 9 * cs), col, 1.6 if heavy else 0.7, true)
		c.draw_line(Vector2(x0, y0 + i * cs), Vector2(x0 + 9 * cs, y0 + i * cs), col, 1.6 if heavy else 0.7, true)
	var cols := [LIME, GOLD, PINK]
	for r in range(9):
		for k in range(9):
			if (r * 5 + k * 3) % 4 == 0:
				var d := (r * 3 + floori(r / 3.0) + k) % 9 + 1
				L.txt(c, str(d), Vector2(x0 + (k + 0.5) * cs, y0 + (r + 0.5) * cs), 7, cols[(r + k) % 3])

static func _teaser_tictactoe(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	for p in [68.0, 92.0]:
		GI._glow_line(c, Vector2(p, 10), Vector2(p, 80), BLUE, 2.2)
	for p in [33.0, 57.0]:
		GI._glow_line(c, Vector2(44, p), Vector2(116, p), BLUE, 2.2)
	for i in range(3):
		GI._draw_x(c, Vector2(56 + i * 24, 21 + i * 24), 7.0, MAGENTA)
	GI._draw_o(c, Vector2(80, 21), 7.5, CYAN)
	GI._draw_o(c, Vector2(56, 69), 7.5, CYAN)
	GI._glow_line(c, Vector2(48, 13), Vector2(112, 77), GOLD, 2.0)

static func _teaser_connect4(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	GI._slab(c, Rect2(26, 2, 108, 86), Color(0.05, 0.12, 0.38), BLUE, 10, 0.5)
	var red := Color("ff3a4f")
	var yel := Color("ffd02b")
	var rows := [".......", "..R....", "..YR...", ".RYYR..", ".YRRY..", "RYYRRY."]
	for r in range(6):
		for k in range(7):
			var ctr := Vector2(40.0 + k * 13.3, 12.0 + r * 13.0)
			c.draw_circle(ctr, 5.6, Color(0.01, 0.02, 0.08))
			var ch: String = rows[r][k]
			if ch == "R":
				GI._sphere(c, ctr, 5.3, red)
			elif ch == "Y":
				GI._sphere(c, ctr, 5.3, yel)
	GI._sphere(c, Vector2(120, 5), 4.5, red)

static func _teaser_checkers(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, PINK)
	_board(c, 40, 5, 8, 10, PINK, 0.3)
	for r in range(8):
		for k in range(8):
			if (r + k) % 2 == 1 and (r < 3 or r > 4):
				var top: Color = Color("ff3a4f") if r < 3 else Color(0.32, 0.36, 0.5)
				var glow: Color = PINK if r < 3 else CYAN
				if r == 2 and k == 3:
					continue
				GI._disc(c, Vector2(45 + k * 10, 9 + r * 10), 3.8, 3.8, 1.8, top, glow)
	GI._disc(c, Vector2(55, 39), 3.8, 3.8, 1.8, Color(0.32, 0.36, 0.5), CYAN)
	GI._glow_line(c, Vector2(75, 59), Vector2(55, 39), LIME, 1.2)

static func _teaser_reversi(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	c.draw_rect(Rect2(40, 5, 80, 80), Color(0.03, 0.17, 0.12))
	for i in range(9):
		c.draw_line(Vector2(40 + i * 10, 5), Vector2(40 + i * 10, 85), Color(CYAN, 0.35), 1.0)
		c.draw_line(Vector2(40, 5 + i * 10), Vector2(120, 5 + i * 10), Color(CYAN, 0.35), 1.0)
	var rows := ["........", "........", "..bw....", "..wbbw..", "...wbb..", "....w...", "........", "........"]
	for r in range(8):
		for k in range(8):
			var ch: String = rows[r][k]
			if ch != ".":
				GI._sphere(c, Vector2(45 + k * 10, 10 + r * 10), 4.2, Color(0.95, 0.96, 1.0) if ch == "w" else Color(0.2, 0.16, 0.45))
	GI._glow_arc(c, Vector2(82, 40), 14.0, -2.5, -0.6, LIME, 1.4)

static func _teaser_minesweeper(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	var cols := [CYAN, LIME, GOLD]
	for r in range(7):
		for k in range(8):
			var rc := Rect2(12 + k * 11.2, 6 + r * 11.2, 10, 10)
			if (r * 7 + k * 3) % 5 != 0 and r < 6:
				L.cell(c, rc, BLUE, false, 2.0)
				var n := (r * 2 + k * 5) % 4
				if n > 0:
					L.txt(c, str(n), rc.get_center(), 8, cols[n - 1])
			else:
				GI._slab(c, rc, BLUE.darkened(0.3), BLUE, 2, 0.3)
	P.logo_at(c, base, "minesweeper", Vector2(130, 45), 44.0)

static func _teaser_sea_battle(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	c.draw_circle(Vector2(30, 45), 24.0, Color(CYAN, 0.1))
	for r in [8.0, 16.0, 24.0]:
		c.draw_arc(Vector2(30, 45), r, 0.0, TAU, 28, Color(LIME, 0.4), 1.0, true)
	GI._glow_line(c, Vector2(30, 45), Vector2(30, 45) + Vector2(cos(-0.9), sin(-0.9)) * 24.0, LIME, 1.6)
	c.draw_circle(Vector2(38, 36), 2.4, PINK)
	L.panel(c, Rect2(62, 6, 88, 78), CYAN, 6)
	for i in range(1, 6):
		c.draw_line(Vector2(62 + i * 14.7, 8), Vector2(62 + i * 14.7, 82), Color(CYAN, 0.3), 1.0)
		c.draw_line(Vector2(64, 6 + i * 13), Vector2(148, 6 + i * 13), Color(CYAN, 0.3), 1.0)
	var ship := PackedVector2Array([Vector2(68, 56), Vector2(74, 50), Vector2(118, 50), Vector2(124, 56), Vector2(118, 62), Vector2(74, 62)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.5))
	GI._glow_poly(c, ship, CYAN, 1.6)
	GI._draw_x(c, Vector2(133, 30), 5.0, PINK)
	GI._draw_x(c, Vector2(104, 56), 5.0, PINK)
	for p in [Vector2(80, 22), Vector2(120, 72), Vector2(90, 36)]:
		c.draw_arc(p, 4.0, 0.0, TAU, 14, Color(1, 1, 1, 0.8), 1.6, true)

static func _teaser_dots_boxes(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var xs := 28.0
	var ys := 12.0
	var dx := 26.0
	var dy := 22.0
	for bx in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
		c.draw_rect(Rect2(xs + bx.x * dx, ys + bx.y * dy, dx, dy), Color(CYAN, 0.3))
	c.draw_rect(Rect2(xs + 2 * dx, ys + 1 * dy, dx, dy), Color(PINK, 0.3))
	c.draw_rect(Rect2(xs + 3 * dx, ys + 2 * dy, dx, dy), Color(PINK, 0.3))
	for r in range(4):
		for k in range(4):
			if (r + k * 2) % 3 != 0 or r < 2:
				GI._glow_line(c, Vector2(xs + k * dx, ys + r * dy), Vector2(xs + (k + 1) * dx, ys + r * dy), CYAN if k < 2 else PINK, 1.8)
	for r in range(3):
		for k in range(5):
			if (r * 2 + k) % 3 != 1:
				GI._glow_line(c, Vector2(xs + k * dx, ys + r * dy), Vector2(xs + k * dx, ys + (r + 1) * dy), CYAN if k < 3 else PINK, 1.8)
	for r in range(4):
		for k in range(5):
			GI._sphere(c, Vector2(xs + k * dx, ys + r * dy), 3.4, Color(0.95, 0.97, 1.0))

static func _teaser_mancala(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BROWN)
	GI._slab(c, Rect2(6, 14, 148, 62), BROWN.darkened(0.65), BROWN, 20, 0.5)
	for sx in [-1.0, 1.0]:
		GI._ellipse(c, Vector2(80 + sx * 66, 45), 9.0, 24.0, Color(0.02, 0.03, 0.05))
	var cols := [GOLD, PINK, CYAN, LIME]
	for r in range(2):
		for k in range(6):
			var ctr := Vector2(36 + k * 17.6, 32 + r * 26.0)
			c.draw_circle(ctr, 7.6, Color(0.02, 0.03, 0.05))
			for j in range((r * 3 + k * 2) % 4 + 1):
				var a := TAU * j / 4.0 + 0.6
				GI._sphere(c, ctr + Vector2(cos(a), sin(a)) * 2.8, 2.5, cols[(j + k) % 4])
	for j in range(5):
		GI._sphere(c, Vector2(14 + (j % 2) * 4.0, 36 + j * 4.5), 2.5, cols[j % 4])
	for j in range(4):
		GI._sphere(c, Vector2(146 - (j % 2) * 4.0, 38 + j * 4.5), 2.5, cols[(j + 1) % 4])
	GI._glow_arc(c, Vector2(80, 45), 40.0, -2.5, -0.7, GOLD, 1.2)

static func _teaser_backgammon(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, BROWN)
	GI._slab(c, Rect2(6, 6, 104, 78), Color(0.04, 0.06, 0.12), BROWN, 8, 0.5)
	for i in range(12):
		var x := 10.0 + i * 8.0 + (4.0 if i >= 6 else 0.0)
		var col: Color = CYAN if i % 2 == 0 else PINK
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 83), Vector2(x + 8, 83), Vector2(x + 4, 52)]), col.darkened(0.5))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 7), Vector2(x + 8, 7), Vector2(x + 4, 38)]), (PINK if i % 2 == 0 else CYAN).darkened(0.5))
	c.draw_line(Vector2(60, 7), Vector2(60, 83), Color(BROWN, 0.9), 3.0)
	for j in range(4):
		GI._sphere(c, Vector2(14, 78 - j * 7.0), 3.6, CYAN)
	for j in range(3):
		GI._sphere(c, Vector2(78, 78 - j * 7.0), 3.6, PINK)
	for j in range(3):
		GI._sphere(c, Vector2(46, 12 + j * 7.0), 3.6, PINK)
	for j in range(2):
		GI._sphere(c, Vector2(102, 12 + j * 7.0), 3.6, CYAN)
	for d in [[Vector2(122, 45), 3], [Vector2(142, 45), 5]]:
		c.draw_set_transform_matrix(base * Transform2D(0.0, Vector2.ONE, 0.0, d[0]))
		GI.draw_die(c, 15.0, d[1], GOLD)
	c.draw_set_transform_matrix(base)

static func _teaser_morris(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	P.logo_at(c, base, "morris", Vector2(80, 45), 84.0)
	for j in range(4):
		GI._sphere(c, Vector2(16, 20 + j * 12.0), 4.6, CYAN)
	for j in range(3):
		GI._sphere(c, Vector2(144, 20 + j * 12.0), 4.6, PINK)

static func _teaser_peg_solitaire(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	var rows := ["..ooo..", "..ooo..", "ooooooo", "ooo.ooo", "ooooooo", "..ooo..", "..ooo.."]
	for r in range(7):
		for k in range(7):
			var ch: String = rows[r][k]
			if (r < 2 or r > 4) and (k < 2 or k > 4):
				continue
			var ctr := Vector2(80 + (k - 3) * 11.0, 45 + (r - 3) * 11.0)
			c.draw_circle(ctr, 4.8, Color(0.02, 0.03, 0.06))
			c.draw_arc(ctr, 4.8, 0.0, TAU, 12, Color(GOLD, 0.4), 1.0, true)
			if ch == "o":
				GI._sphere(c, ctr, 4.1, GOLD)
	GI._glow_arc(c, Vector2(80, 45), 20.0, -2.4, -0.7, LIME, 1.4)
	L.txt(c, "31", Vector2(26, 14), 14, Color(GOLD, 0.9))

static func _teaser_lights_out(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	var rows := ["..#..", ".###.", "##.##", ".###.", "..#.."]
	for r in range(5):
		for k in range(5):
			var rc := Rect2(39 + k * 17.0, 4 + r * 17.0, 14, 14)
			var lit: bool = rows[r][k] == "#"
			L.cell(c, rc, GOLD, lit, 4.0)
			if lit:
				c.draw_circle(rc.get_center(), 7.0, Color(GOLD, 0.2))
				c.draw_circle(rc.get_center(), 3.2, Color(1, 0.97, 0.8, 0.95))

static func _teaser_box_pusher(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BROWN)
	var rows := ["##########", "#........#", "#..BT....#", "#.P..B.T.#", "#........#", "##########"]
	for r in range(6):
		for k in range(10):
			var ch: String = rows[r][k]
			var rc := Rect2(10 + k * 14.0, 3 + r * 14.0, 13, 13)
			if ch == "#":
				GI._slab(c, rc, BLUE.darkened(0.6), BLUE, 2, 0.0)
				continue
			c.draw_rect(rc, Color(1, 1, 1, 0.04))
			if ch == "T":
				c.draw_arc(rc.get_center(), 4.5, 0.0, TAU, 14, LIME, 1.6, true)
			if ch == "B":
				GI._slab(c, rc.grow(-1), BROWN.darkened(0.55), BROWN, 2, 0.4)
				GI._glow_line(c, rc.position + Vector2(3, 3), rc.end - Vector2(3, 3), GOLD, 1.0)
				GI._glow_line(c, Vector2(rc.end.x - 3, rc.position.y + 3), Vector2(rc.position.x + 3, rc.end.y - 3), GOLD, 1.0)
			if ch == "P":
				GI._sphere(c, rc.get_center() + Vector2(0, -2), 4.5, CYAN)
				GI._slab(c, Rect2(rc.position + Vector2(3, 8), Vector2(7, 4)), CYAN.darkened(0.4), CYAN, 1, 0.0)

static func _teaser_fifteen_puzzle(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	var nums := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "", "11", "13", "14", "15", "12"]
	for i in range(16):
		var rc := Rect2(39 + (i % 4) * 21.0, 4 + floori(i / 4.0) * 21.0, 19, 19)
		if nums[i] == "":
			L.cell(c, rc, BLUE, false, 4.0)
		else:
			P.num_tile(c, rc, nums[i], BLUE if i % 2 == 0 else CYAN, 11)
	GI._glow_line(c, Vector2(118, 66), Vector2(118, 58), LIME, 1.6)

static func _teaser_g2048(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	var vals := [[2, 0, 4, 2], [0, 8, 16, 4], [4, 32, 64, 8], [2, 4, 128, 256]]
	var pal := [BLUE, CYAN, LIME, GOLD, PINK, MAGENTA, CYAN, GOLD]
	for r in range(4):
		for k in range(4):
			var v: int = vals[r][k]
			var rc := Rect2(39 + k * 21.0, 4 + r * 21.0, 19, 19)
			if v == 0:
				L.cell(c, rc, BLUE, false, 4.0)
			else:
				var idx := int(log(v) / log(2.0)) - 1
				P.num_tile(c, rc, str(v), pal[idx % pal.size()], 11 if v < 100 else 8)

static func _teaser_kakuro(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	var rows := ["KKKKK", "KDDDD", "KDDDD", "KDDKK"]
	for r in range(4):
		for k in range(5):
			var rc := Rect2(24 + k * 22.4, 5 + r * 21.0, 20.4, 19)
			if rows[r][k] == "D":
				L.cell(c, rc, CYAN, true, 3.0)
				L.txt(c, str((r * 7 + k * 3) % 9 + 1), rc.get_center(), 12, Color.WHITE)
			else:
				GI._slab(c, rc, Color(0.02, 0.04, 0.08), Color(GOLD, 0.7), 3, 0.0)
				if k > 0 or r > 0:
					c.draw_line(rc.position + Vector2(2, 2), rc.end - Vector2(2, 2), Color(GOLD, 0.8), 1.0, true)
					L.txt(c, str((r + k * 2) % 9 + 4), rc.position + Vector2(15, 6), 7, GOLD)
					L.txt(c, str((r * 3 + k) % 9 + 3), rc.position + Vector2(5, 14), 7, GOLD)

static func _teaser_nonogram(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, PINK)
	var pic := [".xx.xx.", "xxxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x...", "......."]
	var cs := 9.0
	var x0 := 58.0
	var y0 := 24.0
	for r in range(7):
		for k in range(7):
			var on: bool = pic[r][k] == "x"
			L.cell(c, Rect2(x0 + k * cs, y0 + r * cs, cs - 1, cs - 1), PINK, on, 1.5)
	for r in range(7):
		var runs := []
		var n := 0
		for k in range(8):
			if k < 7 and pic[r][k] == "x":
				n += 1
			elif n > 0:
				runs.append(str(n))
				n = 0
		L.txt(c, " ".join(PackedStringArray(runs)) if runs.size() > 0 else "0", Vector2(x0 - 10.0, y0 + (r + 0.5) * cs), 7, Color(1, 1, 1, 0.8))
	for k in range(7):
		var runs := []
		var n := 0
		for r in range(8):
			if r < 7 and pic[r][k] == "x":
				n += 1
			elif n > 0:
				runs.append(str(n))
				n = 0
		for j in range(runs.size()):
			L.txt(c, runs[j], Vector2(x0 + (k + 0.5) * cs, y0 - 6.0 - (runs.size() - 1 - j) * 7.0), 7, Color(1, 1, 1, 0.8))

static func _teaser_code_breaker(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var cols := [PINK, CYAN, LIME, GOLD, BLUE]
	for r in range(4):
		var y := 12.0 + r * 19.0
		GI._slab(c, Rect2(24, y - 9, 112, 18), Color(0.03, 0.05, 0.1), Color(CYAN, 0.35), 8, 0.0)
		for k in range(4):
			if r == 3:
				L.txt(c, "?", Vector2(40 + k * 22.0, y), 14, Color(CYAN, 0.9))
			else:
				GI._sphere(c, Vector2(40 + k * 22.0, y), 6.2, cols[(k * 2 + r * 3) % 5])
		for i in range(4):
			if r < 3:
				var on: bool = i < (r + 1)
				c.draw_circle(Vector2(118 + (i % 2) * 8.0, y - 4 + floori(i / 2.0) * 8.0), 2.8, (Color.WHITE if i == 0 else GOLD) if on else Color(1, 1, 1, 0.22))

static func _teaser_hanoi(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	GI._slab(c, Rect2(8, 78, 144, 8), CYAN.darkened(0.6), CYAN, 3, 0.4)
	for x in [30, 80, 130]:
		GI._glow_line(c, Vector2(x, 22), Vector2(x, 78), Color(CYAN, 0.9), 2.0)
	var cols := [PINK, GOLD, LIME, CYAN, BLUE]
	var ws := [44.0, 36.0, 28.0, 20.0, 12.0]
	var stacks := {30: [0, 1], 80: [2], 130: [3, 4]}
	for x in stacks.keys():
		var lst: Array = stacks[x]
		for j in range(lst.size()):
			var i: int = lst[j]
			var col: Color = cols[i]
			GI._slab(c, Rect2(x - ws[i] * 0.5, 68 - j * 10.0, ws[i], 9), col.darkened(0.4), col, 3, 0.5)
	GI._slab(c, Rect2(80 - 6, 12, 12, 8), cols[4].darkened(0.4), cols[4], 3, 0.5)
	GI._glow_arc(c, Vector2(55, 30), 26.0, -PI * 0.95, -PI * 0.1, LIME, 1.2)

static func _teaser_calcudoku(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	var n := 4
	var cs := 20.0
	var x0 := 40.0
	var y0 := 5.0
	for r in range(n):
		for k in range(n):
			var rc := Rect2(x0 + k * (cs + 0.5), y0 + r * (cs + 0.5), cs, cs)
			L.cell(c, rc, BLUE, false, 3.0)
			if (r + k) % 3 != 0:
				L.txt(c, str((r + k * 2) % 4 + 1), rc.get_center() + Vector2(2, 3), 12, Color(1, 1, 1, 0.9))
	var cages := [[Rect2(x0, y0, 41, 20), "5+"], [Rect2(x0 + 41, y0, 20, 41), "2x"], [Rect2(x0 + 61, y0, 20, 82), "7+"], [Rect2(x0, y0 + 20.5, 20, 61), "6x"], [Rect2(x0 + 20.5, y0 + 41, 41, 41), "3-"]]
	for cg in cages:
		var r: Rect2 = cg[0]
		GI._glow_poly(c, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), GOLD, 1.0)
		L.txt(c, cg[1], r.position + Vector2(8, 6), 7, GOLD)

static func _teaser_pipe_flow(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var a := PackedVector2Array([Vector2(14, 22), Vector2(54, 22), Vector2(54, 62), Vector2(96, 62), Vector2(96, 30), Vector2(140, 30)])
	var b := PackedVector2Array([Vector2(54, 62), Vector2(54, 80), Vector2(120, 80)])
	for pts in [a, b]:
		c.draw_polyline(pts, Color(CYAN, 0.18), 18.0, true)
		c.draw_polyline(pts, BLUE.darkened(0.5), 12.0, true)
	c.draw_polyline(a.slice(0, 4), CYAN, 7.0, true)
	c.draw_polyline(a.slice(0, 4), Color(1, 1, 1, 0.5), 2.2, true)
	c.draw_polyline(b, Color(CYAN, 0.25), 7.0, true)
	GI._sphere(c, Vector2(14, 22), 9.0, LIME)
	GI._slab(c, Rect2(136, 20, 12, 20), GOLD.darkened(0.4), GOLD, 3, 0.5)
	GI._glow_arc(c, Vector2(120, 80), 7.0, 0.0, TAU, GOLD, 1.4)
	L.meter(c, Rect2(40, 84, 80, 4), CYAN, 0.55)

static func _teaser_five_in_row(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	var n := 9
	var cs := 9.0
	var x0 := 40.0
	var y0 := 5.0
	for i in range(n):
		c.draw_line(Vector2(x0 + i * cs, y0), Vector2(x0 + i * cs, y0 + (n - 1) * cs), Color(BLUE, 0.8), 1.0)
		c.draw_line(Vector2(x0, y0 + i * cs), Vector2(x0 + (n - 1) * cs, y0 + i * cs), Color(BLUE, 0.8), 1.0)
	var cyan_pts := [Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4), Vector2i(5, 5), Vector2i(6, 6), Vector2i(2, 5)]
	var pink_pts := [Vector2i(3, 2), Vector2i(4, 3), Vector2i(5, 4), Vector2i(2, 4), Vector2i(6, 5), Vector2i(1, 3)]
	GI._glow_line(c, Vector2(x0 + 2 * cs, y0 + 2 * cs), Vector2(x0 + 6 * cs, y0 + 6 * cs), GOLD, 1.8)
	for p in cyan_pts:
		GI._sphere(c, Vector2(x0 + p.x * cs, y0 + p.y * cs), 4.0, CYAN)
	for p in pink_pts:
		GI._sphere(c, Vector2(x0 + p.x * cs, y0 + p.y * cs), 4.0, PINK)

static func _teaser_mahjong(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var cols := [LIME, CYAN, GOLD, PINK]
	for k in range(5):
		P.mj_tile(c, Rect2(14 + k * 27.0, 46, 24, 33), k % 4, cols[k % 4])
	for k in range(3):
		P.mj_tile(c, Rect2(28 + k * 27.0 + 13, 30, 24, 33), (k + 1) % 4, cols[(k + 1) % 4])
	P.mj_tile(c, Rect2(68, 10, 24, 33), 2, GOLD)

static func _teaser_flood_it(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var pal := [PINK, LIME, GOLD, BLUE, MAGENTA]
	var region := ["CCCC....", "CCCCC...", "CC.CC...", "CC......", "C.......", "........", "........", "........"]
	for r in range(8):
		for k in range(8):
			var rc := Rect2(40 + k * 10.0, 5 + r * 10.0, 9, 9)
			var col: Color = CYAN
			var inside: bool = region[r][k] == "C"
			if not inside:
				col = pal[(r * 3 + k * 5 + r * k) % 5]
			GI._slab(c, rc, col.darkened(0.4), col, 2, 0.5 if inside else 0.0)
	for i in range(5):
		var col: Color = pal[i] if i < 5 else CYAN
		GI._sphere(c, Vector2(18, 16 + i * 14.0), 5.0, col)
	GI._glow_arc(c, Vector2(80, 45), 52.0, PI * 1.05, PI * 1.3, Color.WHITE, 1.2)

static func _teaser_same_game(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, MAGENTA)
	var key := [CYAN, PINK, LIME, GOLD]
	for k in range(10):
		var h := 3 + (k * 5) % 5
		for j in range(h):
			var r := 6 - j
			var idx := (k * 7 + j * 3 + (k * j) % 4) % 4
			var hot: bool = idx == 1 and k in [4, 5] and j in [1, 2]
			var col: Color = key[idx]
			GI._slab(c, Rect2(20 + k * 12.0, 3 + r * 12.0, 11, 11), col.darkened(0.45), Color.WHITE if hot else col, 3, 0.6 if hot else 0.0)
	L.txt(c, "4", Vector2(142, 14), 14, Color(GOLD, 0.9))

static func _teaser_binary_grid(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var rows := ["01.0.1", "1..1.0", ".10.01", "01.1..", "..0.10", "10.01."]
	for r in range(6):
		for k in range(6):
			var rc := Rect2(39 + k * 14.0, 4 + r * 14.0, 13, 13)
			var ch: String = rows[r][k]
			if ch == ".":
				L.cell(c, rc, BLUE, false, 3.0)
			else:
				L.cell(c, rc, CYAN if ch == "0" else PINK, true, 3.0)
				L.txt(c, ch, rc.get_center(), 10, Color.WHITE)

static func _teaser_hex(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var rh := 6.4
	var w := sqrt(3.0) * rh
	var n := 7
	var x0 := 30.0
	var y0 := 18.0
	GI._glow_line(c, Vector2(x0 - 8, y0 - 8), Vector2(x0 + w * n + 4, y0 - 8), CYAN, 2.0)
	GI._glow_line(c, Vector2(x0 + w * 3.5 - 8, y0 + 1.5 * rh * 6 + 10), Vector2(x0 + w * (n + 3.5) + 4, y0 + 1.5 * rh * 6 + 10), CYAN, 2.0)
	var cyan_set := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(3, 5)]
	var pink_set := [Vector2i(0, 1), Vector2i(2, 1), Vector2i(3, 2), Vector2i(1, 3), Vector2i(4, 3), Vector2i(2, 4)]
	for r in range(n):
		for k in range(n):
			var ctr := Vector2(x0 + w * (k + 0.5 * r), y0 + 1.5 * rh * r)
			var p := Vector2i(k, r)
			if p in cyan_set:
				P.hexagon(c, ctr, rh - 0.8, CYAN.darkened(0.35), CYAN)
				GI._sphere(c, ctr, 2.8, CYAN)
			elif p in pink_set:
				P.hexagon(c, ctr, rh - 0.8, PINK.darkened(0.35), PINK)
				GI._sphere(c, ctr, 2.8, PINK)
			else:
				P.hexagon(c, ctr, rh - 0.8, Color(0.02, 0.04, 0.09), Color(BLUE, 0.5))
