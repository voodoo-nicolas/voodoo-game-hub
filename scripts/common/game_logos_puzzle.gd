extends RefCounted

## Puzzle & Board category logos drawn in code (batch 3, 2026-10-13). Chess, Sudoku,
## Tic-tac-toe, Connect 4, Checkers and Reversi keep their game_icons.gd logos; the other 23
## are here. Same 100x100 box and rules as game_logos.gd. Also holds shared board helpers
## (hexagon, mj_tile, pegs) used by game_teasers_puzzle.gd.
## Add one: `_logo_<id>(c)`, id in IDS, line in `_logo()`. Used through game_art.gd.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const BROWN := Color("c8803a")
const CREAM := Color(0.95, 0.93, 0.85)

const IDS := [
	"minesweeper", "sea_battle", "dots_boxes", "mancala", "backgammon", "morris",
	"peg_solitaire", "lights_out", "box_pusher", "fifteen_puzzle", "g2048", "kakuro",
	"nonogram", "code_breaker", "hanoi", "calcudoku", "pipe_flow", "five_in_row",
	"mahjong", "flood_it", "same_game", "binary_grid", "hex",
]

static func has(id: String) -> bool:
	return id in IDS

static func draw(c: Control, id: String) -> void:
	var s: float = min(c.size.x, c.size.y)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - s) * 0.5, (c.size.y - s) * 0.5)
	c.draw_set_transform_matrix(Transform2D(0.0, Vector2(s / 100.0, s / 100.0), 0.0, origin))
	_logo(c, id)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func logo_at(c: CanvasItem, base: Transform2D, id: String, ctr: Vector2, size: float) -> void:
	var k := size / 100.0
	c.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(k, k), 0.0, ctr - Vector2(size, size) * 0.5))
	_logo(c, id)
	c.draw_set_transform_matrix(base)

## The six older game_icons.gd logos, placed inside a scene.
static func old_logo_at(c: CanvasItem, base: Transform2D, id: String, ctr: Vector2, size: float) -> void:
	var k := size / 100.0
	c.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(k, k), 0.0, ctr - Vector2(size, size) * 0.5))
	match id:
		"chess": GI._icon_chess(c)
		"sudoku": GI._icon_sudoku(c)
		"tictactoe": GI._icon_tictactoe(c)
		"connect4": GI._icon_connect4(c)
		"checkers": GI._icon_checkers(c)
		"reversi": GI._icon_reversi(c)
	c.draw_set_transform_matrix(base)

static func _logo(c: CanvasItem, id: String) -> void:
	match id:
		"minesweeper": _logo_minesweeper(c)
		"sea_battle": _logo_sea_battle(c)
		"dots_boxes": _logo_dots_boxes(c)
		"mancala": _logo_mancala(c)
		"backgammon": _logo_backgammon(c)
		"morris": _logo_morris(c)
		"peg_solitaire": _logo_peg_solitaire(c)
		"lights_out": _logo_lights_out(c)
		"box_pusher": _logo_box_pusher(c)
		"fifteen_puzzle": _logo_fifteen_puzzle(c)
		"g2048": _logo_g2048(c)
		"kakuro": _logo_kakuro(c)
		"nonogram": _logo_nonogram(c)
		"code_breaker": _logo_code_breaker(c)
		"hanoi": _logo_hanoi(c)
		"calcudoku": _logo_calcudoku(c)
		"pipe_flow": _logo_pipe_flow(c)
		"five_in_row": _logo_five_in_row(c)
		"mahjong": _logo_mahjong(c)
		"flood_it": _logo_flood_it(c)
		"same_game": _logo_same_game(c)
		"binary_grid": _logo_binary_grid(c)
		"hex": _logo_hex(c)

## ---------- shared helpers ----------

## Pointy-top hexagon with a glowing outline.
static func hexagon(c: CanvasItem, ctr: Vector2, r: float, fill: Color, border: Color) -> void:
	var p := PackedVector2Array()
	for i in range(6):
		var a := deg_to_rad(-90.0 + 60.0 * i)
		p.append(ctr + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(p, fill)
	GI._glow_poly(c, p, border, 1.2)

## A mahjong tile with a drawn face: kind 0 three dots, 1 two bamboo, 2 big dot, 3 four dots.
static func mj_tile(c: CanvasItem, rect: Rect2, kind: int, edge: Color = LIME) -> void:
	var o := Vector2(rect.size.x, rect.size.y) * 0.1
	GI._slab(c, Rect2(rect.position + o, rect.size), edge.darkened(0.55), edge.darkened(0.3), rect.size.x * 0.18, 0.0)
	GI._slab(c, rect, CREAM, edge, rect.size.x * 0.18, 0.4)
	var ctr := rect.get_center()
	var u := rect.size.x * 0.22
	match kind:
		0:
			var cols := [CYAN, PINK, LIME]
			for i in range(3):
				var col: Color = cols[i]
				c.draw_circle(ctr + Vector2((i - 1) * u * 1.1, (i - 1) * u * 1.1), u * 0.62, col)
		1:
			for sx in [-1.0, 1.0]:
				var x: float = ctr.x + sx * u * 0.9
				c.draw_line(Vector2(x, ctr.y - u * 1.6), Vector2(x, ctr.y + u * 1.6), LIME.darkened(0.2), u * 0.7, true)
				c.draw_line(Vector2(x - u * 0.4, ctr.y), Vector2(x + u * 0.4, ctr.y), Color(0, 0.3, 0.1), 1.0)
		2:
			c.draw_circle(ctr, u * 1.5, PINK)
			c.draw_circle(ctr, u * 0.8, CREAM)
			c.draw_circle(ctr, u * 0.4, PINK)
		3:
			for i in range(4):
				var col: Color = BLUE if i % 3 == 0 else CYAN
				c.draw_circle(ctr + Vector2((i % 2 - 0.5) * u * 1.9, (floori(i / 2.0) - 0.5) * u * 1.9), u * 0.6, col)

## A small numbered tile (15-puzzle, 2048).
static func num_tile(c: CanvasItem, rect: Rect2, n: String, col: Color, size: int) -> void:
	L.cell(c, rect, col, true, rect.size.x * 0.18)
	L.txt(c, n, rect.get_center(), size, Color(1, 1, 1, 0.97))

## ---------- the 23 Puzzle & Board logos ----------

static func _logo_minesweeper(c: CanvasItem) -> void:
	L.cell(c, Rect2(8, 8, 84, 84), BLUE, false, 12.0)
	c.draw_circle(Vector2(44, 58), 28.0, Color(PINK, 0.1))
	for i in range(8):
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		GI._glow_line(c, Vector2(44, 58) + d * 18.0, Vector2(44, 58) + d * 29.0, Color(1, 1, 1, 0.8), 2.2)
	GI._sphere(c, Vector2(44, 58), 19.0, Color(0.34, 0.36, 0.5))
	GI._glow_line(c, Vector2(74, 38), Vector2(74, 12), Color(1, 1, 1, 0.9), 1.6)
	var flag := PackedVector2Array([Vector2(74, 12), Vector2(90, 19), Vector2(74, 26)])
	c.draw_colored_polygon(flag, PINK)
	GI._glow_poly(c, flag, PINK, 1.2)

static func _logo_sea_battle(c: CanvasItem) -> void:
	L.cell(c, Rect2(8, 8, 84, 84), CYAN, false, 10.0)
	for i in range(1, 5):
		var p := 8.0 + i * 16.8
		c.draw_line(Vector2(p, 12), Vector2(p, 88), Color(CYAN, 0.28), 1.0)
		c.draw_line(Vector2(12, p), Vector2(88, p), Color(CYAN, 0.28), 1.0)
	var ship := PackedVector2Array([Vector2(14, 66), Vector2(24, 58), Vector2(62, 58), Vector2(72, 66), Vector2(62, 74), Vector2(24, 74)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.5))
	GI._glow_poly(c, ship, CYAN, 1.8)
	GI._slab(c, Rect2(34, 51, 18, 8), CYAN.darkened(0.35), CYAN, 2, 0.0)
	GI._draw_x(c, Vector2(74, 32), 8.0, PINK)
	c.draw_arc(Vector2(30, 28), 7.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0, true)

static func _logo_dots_boxes(c: CanvasItem) -> void:
	c.draw_rect(Rect2(20, 20, 30, 30), Color(CYAN, 0.28))
	var segs := [
		[Vector2(20, 20), Vector2(50, 20)], [Vector2(50, 20), Vector2(80, 20)], [Vector2(20, 20), Vector2(20, 50)],
		[Vector2(50, 20), Vector2(50, 50)], [Vector2(20, 50), Vector2(50, 50)], [Vector2(80, 20), Vector2(80, 50)],
		[Vector2(50, 50), Vector2(50, 80)], [Vector2(20, 80), Vector2(50, 80)],
	]
	for s in segs:
		GI._glow_line(c, s[0], s[1], CYAN if s[0].y < 55 and s[0].x < 55 else PINK, 2.6)
	for r in range(3):
		for k in range(3):
			GI._sphere(c, Vector2(20 + k * 30, 20 + r * 30), 5.0, Color(0.95, 0.97, 1.0))

static func _logo_mancala(c: CanvasItem) -> void:
	GI._slab(c, Rect2(4, 24, 92, 52), BROWN.darkened(0.65), BROWN, 16, 0.5)
	for sx in [-1.0, 1.0]:
		GI._ellipse(c, Vector2(50 + sx * 38, 50), 8.0, 20.0, Color(0.02, 0.03, 0.05))
	var seeds := [[3, GOLD], [2, PINK], [4, CYAN], [1, LIME], [3, PINK], [2, GOLD]]
	for r in range(2):
		for k in range(3):
			var ctr := Vector2(36 + k * 15.0, 38 + r * 24.0)
			c.draw_circle(ctr, 7.0, Color(0.02, 0.03, 0.05))
			var sd: Array = seeds[r * 3 + k]
			for j in range(int(sd[0])):
				var a := TAU * j / 4.0 + 0.5
				GI._sphere(c, ctr + Vector2(cos(a), sin(a)) * 2.6, 2.4, sd[1])
	GI._sphere(c, Vector2(12, 50), 3.0, GOLD)
	GI._sphere(c, Vector2(88, 46), 3.0, CYAN)

static func _logo_backgammon(c: CanvasItem) -> void:
	GI._slab(c, Rect2(6, 8, 88, 84), Color(0.04, 0.06, 0.12), BROWN, 8, 0.5)
	for i in range(6):
		var x := 13.0 + i * 13.0
		var col: Color = CYAN if i % 2 == 0 else PINK
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 90), Vector2(x + 13, 90), Vector2(x + 6.5, 54)]), col.darkened(0.5))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, 10), Vector2(x + 13, 10), Vector2(x + 6.5, 46)]), (PINK if i % 2 == 0 else CYAN).darkened(0.5))
	for j in range(3):
		GI._sphere(c, Vector2(19.5, 82 - j * 9.0), 4.8, CYAN)
	for j in range(2):
		GI._sphere(c, Vector2(71.5, 18 + j * 9.0), 4.8, PINK)

static func _logo_morris(c: CanvasItem) -> void:
	for h in [38.0, 24.0, 12.0]:
		var p := PackedVector2Array([Vector2(50 - h, 50 - h), Vector2(50 + h, 50 - h), Vector2(50 + h, 50 + h), Vector2(50 - h, 50 + h)])
		GI._glow_poly(c, p, BLUE, 1.6)
	for s in [[Vector2(50, 12), Vector2(50, 38)], [Vector2(50, 62), Vector2(50, 88)], [Vector2(12, 50), Vector2(38, 50)], [Vector2(62, 50), Vector2(88, 50)]]:
		GI._glow_line(c, s[0], s[1], BLUE, 1.6)
	for p in [Vector2(12, 12), Vector2(50, 26), Vector2(74, 74), Vector2(50, 38)]:
		GI._sphere(c, p, 6.0, CYAN)
	for p in [Vector2(88, 12), Vector2(26, 50), Vector2(50, 88), Vector2(62, 50)]:
		GI._sphere(c, p, 6.0, PINK)

static func _logo_peg_solitaire(c: CanvasItem) -> void:
	for r in range(5):
		for k in range(5):
			if (r == 0 or r == 4) and (k == 0 or k == 4):
				continue
			var ctr := Vector2(18 + k * 16.0, 18 + r * 16.0)
			c.draw_circle(ctr, 6.5, Color(0.02, 0.03, 0.06))
			c.draw_arc(ctr, 6.5, 0.0, TAU, 14, Color(GOLD, 0.45), 1.2, true)
			if not (r == 2 and k == 2):
				GI._sphere(c, ctr, 5.4, GOLD)

static func _logo_lights_out(c: CanvasItem) -> void:
	var on := [1, 3, 4, 5, 7]
	for r in range(3):
		for k in range(3):
			var lit: bool = (r * 3 + k) in on
			var rc := Rect2(11 + k * 28, 11 + r * 28, 22, 22)
			L.cell(c, rc, GOLD, lit, 6.0)
			if lit:
				c.draw_circle(rc.get_center(), 11.0, Color(GOLD, 0.2))
				c.draw_circle(rc.get_center(), 5.0, Color(1, 0.97, 0.8, 0.95))

static func _logo_box_pusher(c: CanvasItem) -> void:
	GI._ellipse(c, Vector2(76, 78), 11.0, 5.0, Color(LIME, 0.18))
	c.draw_arc(Vector2(76, 78), 10.0, 0.0, TAU, 20, LIME, 2.2, true)
	GI._slab(c, Rect2(14, 16, 50, 50), BROWN.darkened(0.55), BROWN, 5, 0.5)
	GI._slab(c, Rect2(20, 22, 38, 38), BROWN.darkened(0.3), Color(BROWN, 0.6), 3, 0.0)
	GI._glow_line(c, Vector2(22, 24), Vector2(56, 58), GOLD, 1.6)
	GI._glow_line(c, Vector2(56, 24), Vector2(22, 58), GOLD, 1.6)
	GI._sphere(c, Vector2(80, 30), 8.0, CYAN)
	GI._slab(c, Rect2(74, 40, 12, 14), CYAN.darkened(0.4), CYAN, 3, 0.0)
	GI._glow_line(c, Vector2(70, 34), Vector2(66, 34), Color.WHITE, 1.4)

static func _logo_fifteen_puzzle(c: CanvasItem) -> void:
	var nums := ["1", "2", "3", "4", "8", "5", "7", "6", ""]
	for i in range(9):
		var rc := Rect2(8 + (i % 3) * 29, 8 + floori(i / 3.0) * 29, 26, 26)
		if nums[i] == "":
			L.cell(c, rc, BLUE, false, 5.0)
		else:
			num_tile(c, rc, nums[i], BLUE if i % 2 == 0 else CYAN, 16)

static func _logo_g2048(c: CanvasItem) -> void:
	var vals := [["2", BLUE], ["4", CYAN], ["8", LIME], ["16", GOLD]]
	for i in range(4):
		var rc := Rect2(10 + (i % 2) * 42, 10 + floori(i / 2.0) * 42, 38, 38)
		num_tile(c, rc, vals[i][0], vals[i][1], 20)

static func _logo_kakuro(c: CanvasItem) -> void:
	var clue_top := {Vector2i(1, 0): "4", Vector2i(2, 0): "6"}
	var clue_left := {Vector2i(0, 1): "7", Vector2i(0, 2): "3"}
	var digits := {Vector2i(1, 1): "3", Vector2i(2, 1): "4", Vector2i(1, 2): "1", Vector2i(2, 2): "2"}
	for r in range(3):
		for k in range(3):
			var rc := Rect2(8 + k * 29, 8 + r * 29, 26, 26)
			var p := Vector2i(k, r)
			if digits.has(p):
				L.cell(c, rc, CYAN, true, 4.0)
				L.txt(c, digits[p], rc.get_center(), 17, Color.WHITE)
			else:
				GI._slab(c, rc, Color(0.02, 0.04, 0.08), Color(GOLD, 0.7), 4, 0.0)
				if p != Vector2i(0, 0):
					c.draw_line(rc.position + Vector2(2, 2), rc.end - Vector2(2, 2), Color(GOLD, 0.8), 1.2, true)
				if clue_top.has(p):
					L.txt(c, clue_top[p], rc.position + Vector2(19, 8), 9, GOLD)
				if clue_left.has(p):
					L.txt(c, clue_left[p], rc.position + Vector2(7, 19), 9, GOLD)

static func _logo_nonogram(c: CanvasItem) -> void:
	var pic := [".x.x.", "xxxxx", "xxxxx", ".xxx.", "..x.."]
	for r in range(5):
		for k in range(5):
			var rc := Rect2(34 + k * 12, 34 + r * 12, 11, 11)
			var on: bool = pic[r][k] == "x"
			L.cell(c, rc, PINK, on, 2.0)
	var left := ["1 1", "5", "5", "3", "1"]
	for r in range(5):
		L.txt(c, left[r], Vector2(18, 40 + r * 12), 8, Color(1, 1, 1, 0.8))
	var top := ["2", "4", "5", "4", "2"]
	for k in range(5):
		L.txt(c, top[k], Vector2(40 + k * 12, 22), 8, Color(1, 1, 1, 0.8))

static func _logo_code_breaker(c: CanvasItem) -> void:
	var cols := [PINK, CYAN, LIME, GOLD]
	for k in range(4):
		GI._sphere(c, Vector2(14 + k * 16.0, 28), 6.5, cols[k])
	for i in range(4):
		var p := Vector2(82 + (i % 2) * 8.0, 24 + floori(i / 2.0) * 8.0)
		c.draw_circle(p, 3.0, Color.WHITE if i < 2 else Color(1, 1, 1, 0.25))
	for k in range(4):
		GI._sphere(c, Vector2(14 + k * 16.0, 56), 6.5, cols[(k + 2) % 4])
	for i in range(4):
		var p := Vector2(82 + (i % 2) * 8.0, 52 + floori(i / 2.0) * 8.0)
		c.draw_circle(p, 3.0, GOLD if i == 0 else Color(1, 1, 1, 0.25))
	GI._slab(c, Rect2(6, 72, 64, 20), Color(0.03, 0.05, 0.1), Color(CYAN, 0.5), 8, 0.0)
	for k in range(4):
		L.txt(c, "?", Vector2(14 + k * 16.0, 82), 14, Color(CYAN, 0.9))

static func _logo_hanoi(c: CanvasItem) -> void:
	GI._slab(c, Rect2(6, 84, 88, 8), CYAN.darkened(0.6), CYAN, 3, 0.4)
	for x in [20, 50, 80]:
		GI._glow_line(c, Vector2(x, 28), Vector2(x, 84), Color(CYAN, 0.9), 2.0)
	var cols := [PINK, GOLD, LIME, CYAN]
	var ws := [38.0, 30.0, 22.0, 14.0]
	for i in range(3):
		var col: Color = cols[i]
		GI._slab(c, Rect2(20 - ws[i] * 0.5, 74 - i * 10, ws[i], 9), col.darkened(0.4), col, 3, 0.5)
	GI._slab(c, Rect2(80 - 11, 74, 22, 9), cols[2].darkened(0.4), cols[2], 3, 0.5)
	GI._slab(c, Rect2(50 - 7, 18, 14, 9), cols[3].darkened(0.4), cols[3], 3, 0.5)

static func _logo_calcudoku(c: CanvasItem) -> void:
	var digits := ["1", "2", "3", "2", "3", "1", "3", "1", "2"]
	for i in range(9):
		var rc := Rect2(8 + (i % 3) * 29, 8 + floori(i / 3.0) * 29, 26, 26)
		L.cell(c, rc, BLUE, false, 3.0)
		L.txt(c, digits[i], rc.get_center() + Vector2(2, 3), 15, Color(1, 1, 1, 0.9))
	var cages := [
		[Rect2(7, 7, 58, 28), "5+"], [Rect2(65, 7, 28, 57), "2x"], [Rect2(7, 36, 28, 57), "3-"], [Rect2(36, 36, 28, 28), "1"], [Rect2(36, 65, 57, 28), "6+"],
	]
	for cg in cages:
		var r: Rect2 = cg[0]
		GI._glow_poly(c, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), GOLD, 1.4)
		L.txt(c, cg[1], r.position + Vector2(9, 7), 8, GOLD)

## Wire Up (id pipe_flow): a battery wired to a glowing bulb.
static func _logo_pipe_flow(c: CanvasItem) -> void:
	var wire := PackedVector2Array([Vector2(30, 40), Vector2(30, 20), Vector2(70, 20), Vector2(70, 34)])
	var wire2 := PackedVector2Array([Vector2(30, 66), Vector2(30, 86), Vector2(70, 86), Vector2(70, 66)])
	c.draw_polyline(wire, Color(CYAN, 0.2), 9.0, true)
	c.draw_polyline(wire, CYAN, 3.4, true)
	c.draw_polyline(wire2, Color(GOLD, 0.2), 9.0, true)
	c.draw_polyline(wire2, GOLD, 3.4, true)
	GI._slab(c, Rect2(18, 40, 24, 28), Color(0.03, 0.08, 0.05), LIME, 5, 0.6)
	GI._slab(c, Rect2(24, 35, 12, 6), LIME.darkened(0.2), LIME, 2, 0.0)
	L.txt(c, "+", Vector2(30, 52), 16, Color.WHITE)
	c.draw_circle(Vector2(70, 50), 22.0, Color(GOLD, 0.15))
	GI._sphere(c, Vector2(70, 50), 14.0, GOLD)
	GI._glow_line(c, Vector2(62, 62), Vector2(78, 62), Color(1, 1, 1, 0.6), 1.4)
	for i in range(5):
		var a := deg_to_rad(-90.0 + (i - 2) * 38.0)
		GI._glow_line(c, Vector2(70, 50) + Vector2(cos(a), sin(a)) * 21.0, Vector2(70, 50) + Vector2(cos(a), sin(a)) * 28.0, GOLD, 1.2)

static func _logo_five_in_row(c: CanvasItem) -> void:
	for i in range(6):
		var p := 14.0 + i * 14.4
		c.draw_line(Vector2(p, 14), Vector2(p, 86), Color(BLUE, 0.7), 1.2)
		c.draw_line(Vector2(14, p), Vector2(86, p), Color(BLUE, 0.7), 1.2)
	GI._glow_line(c, Vector2(14, 14), Vector2(72, 72), GOLD, 2.2)
	for i in range(5):
		GI._sphere(c, Vector2(14.0 + i * 14.4, 14.0 + i * 14.4), 6.0, CYAN)
	for p in [Vector2(3, 1), Vector2(1, 3), Vector2(4, 2), Vector2(2, 5)]:
		GI._sphere(c, Vector2(14.0 + p.x * 14.4, 14.0 + p.y * 14.4), 6.0, PINK)

static func _logo_mahjong(c: CanvasItem) -> void:
	mj_tile(c, Rect2(8, 18, 36, 48), 1, LIME)
	mj_tile(c, Rect2(52, 14, 36, 48), 3, CYAN)
	mj_tile(c, Rect2(30, 38, 36, 48), 0, GOLD)

static func _logo_flood_it(c: CanvasItem) -> void:
	var pal := [CYAN, PINK, LIME, GOLD, BLUE]
	var rows := ["CCbd", "CCcb", "Cbad", "dbca"]
	var map := {"a": 1, "b": 2, "c": 3, "d": 4}
	for r in range(4):
		for k in range(4):
			var ch: String = rows[r][k]
			var col: Color = CYAN if ch == "C" else pal[map[ch]]
			var rc := Rect2(9 + k * 21, 9 + r * 21, 19, 19)
			GI._slab(c, rc, col.darkened(0.4), col, 4, 0.5 if ch == "C" else 0.0)
	GI._glow_arc(c, Vector2(50, 50), 44.0, PI * 1.05, PI * 1.45, Color.WHITE, 1.4)

static func _logo_same_game(c: CanvasItem) -> void:
	var rows := ["CPPLC", "CPPCL", "LPCCL", "LLCPC", "CLLPC"]
	var key := {"C": CYAN, "P": PINK, "L": LIME}
	for r in range(5):
		for k in range(5):
			var ch: String = rows[r][k]
			var col: Color = key[ch]
			var rc := Rect2(8 + k * 17, 8 + r * 17, 15, 15)
			var hot: bool = ch == "P" and k in [1, 2] and r < 3
			GI._slab(c, rc, col.darkened(0.45), Color.WHITE if hot else col, 3, 0.6 if hot else 0.0)

static func _logo_binary_grid(c: CanvasItem) -> void:
	var rows := ["01.0", "1..1", ".10.", "01.1"]
	for r in range(4):
		for k in range(4):
			var rc := Rect2(7 + k * 22, 7 + r * 22, 20, 20)
			var ch: String = rows[r][k]
			if ch == ".":
				L.cell(c, rc, BLUE, false, 4.0)
			else:
				L.cell(c, rc, CYAN if ch == "0" else PINK, true, 4.0)
				L.txt(c, ch, rc.get_center(), 15, Color.WHITE)

static func _logo_hex(c: CanvasItem) -> void:
	var rh := 8.6
	var w := sqrt(3.0) * rh
	var stones := {Vector2i(0, 0): CYAN, Vector2i(1, 1): CYAN, Vector2i(2, 1): CYAN, Vector2i(2, 2): CYAN, Vector2i(3, 3): CYAN, Vector2i(2, 0): PINK, Vector2i(1, 2): PINK, Vector2i(3, 1): PINK}
	for r in range(4):
		for k in range(4):
			var ctr := Vector2(14.0 + w * (k + 0.5 * r), 26.0 + 1.5 * rh * r)
			var p := Vector2i(k, r)
			if stones.has(p):
				var col: Color = stones[p]
				hexagon(c, ctr, rh - 1.0, col.darkened(0.35), col)
				GI._sphere(c, ctr, 4.0, col)
			else:
				hexagon(c, ctr, rh - 1.0, Color(0.02, 0.04, 0.09), Color(BLUE, 0.55))
