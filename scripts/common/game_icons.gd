extends RefCounted

## Hub tile icons drawn in code: neon-vector glow with a little depth (bevelled
## slabs, shaded spheres, stacked discs), per reference/art/ART_STYLE.md. No
## image assets. A game with an entry here gets this icon on its hub tile; any
## other game keeps the emoji from manifest.json (which older apps also use).
##
## Add one: write a `_icon_<id>(c)` function that draws in a 100x100 box
## (origin top-left) on CanvasItem `c`, then add the id to IDS.
##
## Used by the hub as `ctl.draw.connect(GameIcons.draw.bind(ctl, id))`.

const IDS := ["chess", "sudoku", "tictactoe", "connect4", "checkers", "reversi", "three_man"]

const CYAN := Color("29e6ff")
const BLUE := Color("3a8cff")
const MAGENTA := Color("ff2bd6")
const PINK := Color("ff4f9a")
const LIME := Color("7dff3a")
const GOLD := Color("ffae2b")
const PURPLE := Color("9b4dff")

static func has(id: String) -> bool:
	return id in IDS

## Draws icon `id` scaled to fit the Control `c` (square, centered).
static func draw(c: Control, id: String) -> void:
	var s: float = min(c.size.x, c.size.y)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - s) * 0.5, (c.size.y - s) * 0.5)
	var base := Transform2D(0.0, Vector2(s / 100.0, s / 100.0), 0.0, origin)
	c.draw_set_transform_matrix(base)
	match id:
		"chess": _icon_chess(c)
		"sudoku": _icon_sudoku(c)
		"tictactoe": _icon_tictactoe(c)
		"connect4": _icon_connect4(c)
		"checkers": _icon_checkers(c)
		"reversi": _icon_reversi(c)
		"three_man":
			c.draw_set_transform_matrix(base * Transform2D(deg_to_rad(-13.0), Vector2(35, 58)))
			draw_die(c, 44.0, 1, GOLD)
			c.draw_set_transform_matrix(base * Transform2D(deg_to_rad(12.0), Vector2(66, 42)))
			draw_die(c, 44.0, 2, GOLD)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## ---------- icons ----------

static func _icon_chess(c: CanvasItem) -> void:
	var col := CYAN
	# Soft glow behind the whole piece.
	_halo(c, Vector2(50, 56), 34.0, col)
	# Base, stem, collar, head -- darker body with a lit left edge.
	_slab(c, Rect2(24, 80, 52, 10), col.darkened(0.55), col, 4, 0.4)
	var body := PackedVector2Array([Vector2(41, 46), Vector2(59, 46), Vector2(68, 80), Vector2(32, 80)])
	c.draw_colored_polygon(body, col.darkened(0.5))
	c.draw_colored_polygon(PackedVector2Array([Vector2(41, 46), Vector2(48, 46), Vector2(47, 80), Vector2(32, 80)]), col.darkened(0.15))
	_glow_poly(c, body, col, 2.0)
	_slab(c, Rect2(31, 40, 38, 9), col.darkened(0.4), col, 4, 0.4)
	_sphere(c, Vector2(50, 27), 14.0, col)

static func _icon_sudoku(c: CanvasItem) -> void:
	# Slab with a visible thickness, 3x3 boxes of 3x3 cells.
	_slab(c, Rect2(14, 18, 76, 76), CYAN.darkened(0.8), CYAN.darkened(0.6), 8, 0.0)
	_slab(c, Rect2(10, 10, 76, 76), Color(0.03, 0.07, 0.13), CYAN, 8, 0.5)
	for i in range(1, 9):
		var p: float = 10.0 + i * 76.0 / 9.0
		var heavy: bool = i % 3 == 0
		var col := Color(CYAN, 1.0 if heavy else 0.28)
		var w := 2.2 if heavy else 0.9
		c.draw_line(Vector2(p, 14), Vector2(p, 82), col, w, true)
		c.draw_line(Vector2(14, p), Vector2(82, p), col, w, true)
	var font := ThemeDB.fallback_font
	var cell := 76.0 / 9.0
	var digits := [[0, 0, "5", LIME], [4, 1, "3", GOLD], [1, 4, "8", PINK], [5, 4, "2", LIME], [2, 7, "7", GOLD], [7, 8, "9", PINK], [8, 3, "4", CYAN]]
	for d in digits:
		var x: float = 10.0 + d[0] * cell
		var y: float = 10.0 + d[1] * cell
		c.draw_string(font, Vector2(x, y + cell * 0.82), d[2], HORIZONTAL_ALIGNMENT_CENTER, cell, 10, d[3])

static func _icon_tictactoe(c: CanvasItem) -> void:
	for p in [37.0, 63.0]:
		_glow_line(c, Vector2(p, 12), Vector2(p, 88), PURPLE, 3.0)
		_glow_line(c, Vector2(12, p), Vector2(88, p), PURPLE, 3.0)
	_draw_x(c, Vector2(24, 24), 8.0, MAGENTA)
	_draw_x(c, Vector2(76, 76), 8.0, MAGENTA)
	_draw_o(c, Vector2(50, 50), 8.5, CYAN)
	_draw_o(c, Vector2(24, 76), 8.5, CYAN)
	_draw_o(c, Vector2(76, 24), 8.5, CYAN)

static func _icon_connect4(c: CanvasItem) -> void:
	# Blue board with round holes; shaded discs sit in some of them.
	_slab(c, Rect2(10, 22, 80, 70), BLUE.darkened(0.75), BLUE.darkened(0.5), 9, 0.0)
	_slab(c, Rect2(10, 14, 80, 70), Color(0.05, 0.12, 0.38), BLUE, 9, 0.55)
	var red := Color("ff3a4f")
	var yel := Color("ffd02b")
	var layout := [
		["", "", "", ""],
		["", red, yel, ""],
		[red, yel, red, yel],
	]
	for row in range(3):
		for col in range(4):
			var ctr := Vector2(25.0 + col * 16.7, 31.0 + row * 19.0)
			c.draw_circle(ctr, 7.6, Color(0.01, 0.02, 0.08))
			var disc = layout[row][col]
			if disc is Color:
				_sphere(c, ctr, 7.2, disc)

static func _icon_checkers(c: CanvasItem) -> void:
	_disc(c, Vector2(60, 36), 27.0, 11.0, 9.0, Color(0.32, 0.36, 0.5), CYAN)
	_disc(c, Vector2(40, 60), 27.0, 11.0, 9.0, Color("ff3a4f"), PINK)

static func _icon_reversi(c: CanvasItem) -> void:
	_disc(c, Vector2(62, 34), 26.0, 11.0, 9.0, Color(0.2, 0.16, 0.32), PURPLE)
	_disc(c, Vector2(38, 62), 26.0, 11.0, 9.0, Color(0.95, 0.96, 1.0), CYAN)
	# A "flip" arrow arcing between the two discs.
	_glow_arc(c, Vector2(50, 50), 40.0, deg_to_rad(-80), deg_to_rad(-20), LIME, 2.4)
	var tip := Vector2(50, 50) + Vector2(cos(deg_to_rad(-20)), sin(deg_to_rad(-20))) * 40.0
	_glow_poly_open(c, PackedVector2Array([tip + Vector2(-7, -3), tip, tip + Vector2(-2, 7)]), LIME, 2.4)

## ---------- a neon die, shared by the hub icon and by Three Man's own copy ----------

## Draws a die of side `d` centered on the current transform's origin.
static func draw_die(c: CanvasItem, d: float, value: int, col: Color) -> void:
	var h := d * 0.5
	_slab(c, Rect2(-h + d * 0.05, -h + d * 0.1, d, d), col.darkened(0.65), col.darkened(0.45), d * 0.2, 0.0)
	_slab(c, Rect2(-h, -h, d, d), Color(0.08, 0.06, 0.1), col, d * 0.2, 0.55)
	_slab(c, Rect2(-h + d * 0.07, -h + d * 0.06, d * 0.86, d * 0.38), Color(col, 0.13), Color(col, 0.0), d * 0.14, 0.0)
	var o := d * 0.25
	var spots := {
		1: [Vector2.ZERO],
		2: [Vector2(-o, -o), Vector2(o, o)],
		3: [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)],
		4: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)],
		5: [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)],
		6: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)],
	}
	for p in spots.get(clampi(value, 1, 6), []):
		c.draw_circle(p, d * 0.1 + 2.5, Color(col, 0.28))
		c.draw_circle(p, d * 0.1, col.lightened(0.75))

## ---------- drawing helpers ----------

static func _pts(ctr: Vector2, rx: float, ry: float, n: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / n
		out.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	return out

static func _ellipse(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color) -> void:
	c.draw_colored_polygon(_pts(ctr, rx, ry), col)

## Rounded rectangle with a border and (optionally) a real soft glow.
static func _slab(c: CanvasItem, rect: Rect2, fill: Color, border: Color, radius: float, glow: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(2 if border.a > 0.0 else 0)
	sb.border_color = border
	if glow > 0.0:
		sb.shadow_color = Color(border, glow * 0.6)
		sb.shadow_size = 6
	c.draw_style_box(sb, rect)

static func _halo(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	for k in range(3):
		c.draw_circle(ctr, r - k * 6.0, Color(col, 0.05 + k * 0.025))

## A ball lit from the top left: stacked circles from dark rim to bright core.
static func _sphere(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	c.draw_circle(ctr, r + 4.0, Color(col, 0.14))
	c.draw_circle(ctr, r + 2.0, Color(col, 0.26))
	var steps := 7
	for i in range(steps):
		var t := float(i) / (steps - 1)
		var rr := r * (1.0 - 0.15 * i)
		var off := Vector2(-0.32, -0.34) * r * t
		c.draw_circle(ctr + off, rr, col.darkened(0.5).lerp(col.lightened(0.55), t))
	c.draw_circle(ctr + Vector2(-0.38, -0.4) * r, r * 0.16, Color(1, 1, 1, 0.9))

## A flat round piece with thickness (checkers / reversi discs).
static func _disc(c: CanvasItem, ctr: Vector2, rx: float, ry: float, thick: float, top: Color, glow: Color) -> void:
	var side := top.darkened(0.55)
	_ellipse(c, ctr + Vector2(0, thick), rx + 4.0, ry + 4.0, Color(glow, 0.16))
	_ellipse(c, ctr + Vector2(0, thick), rx, ry, side)
	c.draw_rect(Rect2(ctr.x - rx, ctr.y, rx * 2.0, thick), side)
	_ellipse(c, ctr, rx, ry, top.darkened(0.2))
	_ellipse(c, ctr + Vector2(-rx * 0.08, -ry * 0.12), rx * 0.82, ry * 0.8, top)
	var ring := _pts(ctr, rx * 0.58, ry * 0.56)
	ring.append(ring[0])
	c.draw_polyline(ring, top.darkened(0.3), 1.3, true)
	var rim := _pts(ctr, rx, ry)
	rim.append(rim[0])
	c.draw_polyline(rim, glow, 2.0, true)
	var bottom := _pts(ctr + Vector2(0, thick), rx, ry)
	bottom = bottom.slice(0, 21)  # front half only
	c.draw_polyline(bottom, Color(glow, 0.8), 2.0, true)
	c.draw_line(Vector2(ctr.x - rx, ctr.y), Vector2(ctr.x - rx, ctr.y + thick), Color(glow, 0.8), 2.0, true)
	c.draw_line(Vector2(ctr.x + rx, ctr.y), Vector2(ctr.x + rx, ctr.y + thick), Color(glow, 0.8), 2.0, true)

## Neon tube: wide faint halo, narrower glow, solid line, white-hot core.
static func _glow_line(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	c.draw_line(a, b, Color(col, 0.10), w * 4.0, true)
	c.draw_line(a, b, Color(col, 0.25), w * 2.2, true)
	c.draw_line(a, b, col, w, true)
	c.draw_line(a, b, Color(1, 1, 1, 0.7), w * 0.35, true)

static func _glow_poly(c: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	_glow_poly_open(c, closed, col, w)

static func _glow_poly_open(c: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	c.draw_polyline(pts, Color(col, 0.12), w * 4.0, true)
	c.draw_polyline(pts, Color(col, 0.28), w * 2.2, true)
	c.draw_polyline(pts, col, w, true)
	c.draw_polyline(pts, Color(1, 1, 1, 0.6), w * 0.35, true)

static func _glow_arc(c: CanvasItem, ctr: Vector2, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	c.draw_arc(ctr, r, a0, a1, 24, Color(col, 0.12), w * 4.0, true)
	c.draw_arc(ctr, r, a0, a1, 24, Color(col, 0.28), w * 2.2, true)
	c.draw_arc(ctr, r, a0, a1, 24, col, w, true)

static func _draw_x(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	_glow_line(c, ctr + Vector2(-r, -r), ctr + Vector2(r, r), col, 3.2)
	_glow_line(c, ctr + Vector2(-r, r), ctr + Vector2(r, -r), col, 3.2)

static func _draw_o(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	c.draw_arc(ctr, r, 0.0, TAU, 32, Color(col, 0.12), 12.0, true)
	c.draw_arc(ctr, r, 0.0, TAU, 32, Color(col, 0.28), 7.0, true)
	c.draw_arc(ctr, r, 0.0, TAU, 32, col, 3.2, true)
	c.draw_arc(ctr, r, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 1.1, true)
