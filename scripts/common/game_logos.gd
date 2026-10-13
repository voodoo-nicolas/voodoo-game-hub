extends RefCounted

## Per-game LOGOS drawn in code (neon vector on transparent, 100x100 box, origin top-left),
## the same style as game_icons.gd (chess, sudoku, ...). Used through game_art.gd.
## No image assets, so no licence entries. Never draw Unicode die glyphs (draw dice).
##
## Add one: write `_logo_<id>(c)` here, add the id to IDS and a `match` line in `_logo()`.
## Batch 1 (2026-10-13): Intelligence category. See docs/claude/hub-v2.md "Game art".

const GI = preload("res://scripts/common/game_icons.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD

const IDS := [
	"trivia", "quick_math", "memory_grid", "color_clash", "number_series", "digit_recall",
	"voodoo_iq", "sketch_it", "trace_it", "trivia_battle", "color_sort", "hidato",
]

static func has(id: String) -> bool:
	return id in IDS

## Draws logo `id` scaled to fit the Control `c` (square, centred).
static func draw(c: Control, id: String) -> void:
	var s: float = min(c.size.x, c.size.y)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - s) * 0.5, (c.size.y - s) * 0.5)
	c.draw_set_transform_matrix(Transform2D(0.0, Vector2(s / 100.0, s / 100.0), 0.0, origin))
	_logo(c, id)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## A logo placed inside a bigger scene: `base` is the scene's transform, `ctr`/`size` in scene units.
static func logo_at(c: CanvasItem, base: Transform2D, id: String, ctr: Vector2, size: float) -> void:
	var k := size / 100.0
	c.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(k, k), 0.0, ctr - Vector2(size, size) * 0.5))
	_logo(c, id)
	c.draw_set_transform_matrix(base)

static func _logo(c: CanvasItem, id: String) -> void:
	match id:
		"trivia": _logo_trivia(c)
		"quick_math": _logo_quick_math(c)
		"memory_grid": _logo_memory_grid(c)
		"color_clash": _logo_color_clash(c)
		"number_series": _logo_number_series(c)
		"digit_recall": _logo_digit_recall(c)
		"voodoo_iq": _logo_voodoo_iq(c)
		"sketch_it": _logo_sketch_it(c)
		"trace_it": _logo_trace_it(c)
		"trivia_battle": _logo_trivia_battle(c)
		"color_sort": _logo_color_sort(c)
		"hidato": _logo_hidato(c)

## ---------- shared helpers (also used by game_teasers.gd) ----------

## Text centred on `ctr` (digits, ?, ! and Latin letters only: no emoji, no words that need translating).
static func txt(c: CanvasItem, s: String, ctr: Vector2, size: int, col: Color) -> void:
	var f: Font = ThemeDB.fallback_font
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(f, ctr + Vector2(-w * 0.5, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## A dark rounded tile with a glowing border; `lit` fills it with the colour.
static func cell(c: CanvasItem, rect: Rect2, col: Color, lit: bool, radius: float = 5.0) -> void:
	if lit:
		GI._slab(c, rect, col.darkened(0.45), col, radius, 0.8)
	else:
		GI._slab(c, rect, col.darkened(0.85), Color(col, 0.4), radius, 0.0)

## A pill / panel with a thin glowing border.
static func panel(c: CanvasItem, rect: Rect2, col: Color, radius: float = 8.0) -> void:
	GI._slab(c, rect, Color(0.04, 0.06, 0.12, 0.92), col, radius, 0.5)

## A tube-like bar: dark track plus a bright fill from the left (0..1).
static func meter(c: CanvasItem, rect: Rect2, col: Color, frac: float) -> void:
	GI._slab(c, rect, Color(0.03, 0.05, 0.1), Color(col, 0.45), rect.size.y * 0.5, 0.0)
	if frac > 0.0:
		GI._slab(c, Rect2(rect.position, Vector2(maxf(rect.size.y, rect.size.x * frac), rect.size.y)), col.darkened(0.2), col, rect.size.y * 0.5, 0.5)

## ---------- the 12 Intelligence logos ----------

static func _logo_trivia(c: CanvasItem) -> void:
	GI._halo(c, Vector2(50, 50), 40.0, BLUE)
	var tail := PackedVector2Array([Vector2(34, 66), Vector2(28, 88), Vector2(54, 74)])
	c.draw_colored_polygon(tail, BLUE.darkened(0.45))
	GI._glow_poly(c, tail, BLUE, 1.6)
	GI._sphere(c, Vector2(50, 44), 31.0, BLUE)
	txt(c, "?", Vector2(50, 44), 46, Color(1, 1, 1, 0.96))

static func _logo_quick_math(c: CanvasItem) -> void:
	GI._slab(c, Rect2(12, 14, 76, 72), Color(0.03, 0.09, 0.05), LIME, 12, 0.6)
	GI._glow_line(c, Vector2(50, 24), Vector2(50, 52), LIME, 3.6)
	GI._glow_line(c, Vector2(36, 38), Vector2(64, 38), LIME, 3.6)
	txt(c, "=?", Vector2(50, 68), 24, Color(1, 1, 1, 0.92))

static func _logo_memory_grid(c: CanvasItem) -> void:
	var lit := [0, 4, 7]
	for r in range(3):
		for k in range(3):
			cell(c, Rect2(11 + k * 28, 11 + r * 28, 22, 22), CYAN, (r * 3 + k) in lit)

static func _logo_color_clash(c: CanvasItem) -> void:
	GI._sphere(c, Vector2(36, 36), 19.0, PINK)
	GI._sphere(c, Vector2(64, 36), 19.0, BLUE)
	GI._sphere(c, Vector2(36, 64), 19.0, LIME)
	GI._sphere(c, Vector2(64, 64), 19.0, GOLD)

static func _logo_number_series(c: CanvasItem) -> void:
	var xs := [5, 36, 67]
	var labels := ["2", "4", "?"]
	for i in range(3):
		var hot: bool = i == 2
		var col: Color = GOLD if hot else CYAN
		cell(c, Rect2(xs[i], 32, 28, 36), col, hot, 7.0)
		txt(c, labels[i], Vector2(xs[i] + 14, 50), 24, Color(1, 1, 1, 0.95))

static func _logo_digit_recall(c: CanvasItem) -> void:
	var xs := [8, 37, 66]
	var labels := ["7", "3", "9"]
	for i in range(3):
		cell(c, Rect2(xs[i], 22, 26, 34), GOLD, true, 7.0)
		txt(c, labels[i], Vector2(xs[i] + 13, 39), 24, Color(1, 1, 1, 0.95))
	for i in range(5):
		var on: bool = i < 3
		c.draw_circle(Vector2(26 + i * 12, 76), 3.6, Color(GOLD, 1.0 if on else 0.3))

static func _logo_voodoo_iq(c: CanvasItem) -> void:
	var col := PINK
	GI._halo(c, Vector2(50, 50), 42.0, col)
	for sx in [-1.0, 1.0]:
		var ctr := Vector2(50.0 + sx * 13.0, 46.0)
		c.draw_colored_polygon(GI._pts(ctr, 25.0, 29.0), col.darkened(0.55))
		var o := GI._pts(ctr, 25.0, 29.0)
		o.append(o[0])
		c.draw_polyline(o, col, 2.4, true)
		# folds
		GI._glow_arc(c, ctr + Vector2(-sx * 3.0, -10.0), 9.0, PI * 0.8, PI * 2.1, col.lightened(0.2), 1.5)
		GI._glow_arc(c, ctr + Vector2(sx * 2.0, 10.0), 9.0, -PI * 0.1, PI * 1.1, col.lightened(0.2), 1.5)
	GI._slab(c, Rect2(44, 74, 12, 14), col.darkened(0.55), col, 4, 0.0)
	var bolt := PackedVector2Array([Vector2(55, 26), Vector2(42, 51), Vector2(50, 51), Vector2(45, 72), Vector2(61, 44), Vector2(52, 44)])
	c.draw_colored_polygon(bolt, GOLD.lightened(0.3))
	GI._glow_poly(c, bolt, GOLD, 1.6)

static func _logo_sketch_it(c: CanvasItem) -> void:
	# scribble under the pencil
	var wave := PackedVector2Array()
	for i in range(13):
		var t := i / 12.0
		wave.append(Vector2(10.0 + t * 44.0, 84.0 - sin(t * TAU * 1.5) * 5.0 - t * 4.0))
	GI._glow_poly_open(c, wave, CYAN, 2.2)
	# pencil
	var body := PackedVector2Array([Vector2(70, 14), Vector2(86, 30), Vector2(46, 70), Vector2(30, 54)])
	c.draw_colored_polygon(body, GOLD.darkened(0.35))
	c.draw_colored_polygon(PackedVector2Array([Vector2(70, 14), Vector2(78, 22), Vector2(38, 62), Vector2(30, 54)]), GOLD)
	GI._glow_poly(c, body, GOLD, 1.8)
	var tip := PackedVector2Array([Vector2(46, 70), Vector2(30, 54), Vector2(24, 78)])
	c.draw_colored_polygon(tip, Color(0.95, 0.8, 0.6))
	GI._glow_poly(c, tip, Color(0.95, 0.8, 0.6), 1.4)
	c.draw_colored_polygon(PackedVector2Array([Vector2(28, 66), Vector2(24, 78), Vector2(36, 74)]), PINK)
	GI._slab(c, Rect2(63, 11, 20, 12), PINK.darkened(0.2), PINK, 3, 0.0)

static func _logo_trace_it(c: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var t := i / 24.0
		pts.append(Vector2(14.0 + t * 72.0, 52.0 - sin(t * TAU * 0.95) * 26.0))
	for i in range(14, 25):
		c.draw_circle(pts[i], 2.6, Color(CYAN, 0.5))
	GI._glow_poly_open(c, pts.slice(0, 15), LIME, 3.0)
	GI._sphere(c, pts[0], 6.0, LIME)
	GI._sphere(c, pts[14], 8.0, GOLD)

static func _logo_trivia_battle(c: CanvasItem) -> void:
	var left := PackedVector2Array([Vector2(16, 52), Vector2(14, 66), Vector2(30, 52)])
	c.draw_colored_polygon(left, CYAN.darkened(0.45))
	GI._slab(c, Rect2(8, 16, 50, 38), CYAN.darkened(0.6), CYAN, 10, 0.6)
	txt(c, "?", Vector2(33, 35), 28, Color(1, 1, 1, 0.95))
	var right := PackedVector2Array([Vector2(84, 84), Vector2(86, 98), Vector2(70, 84)])
	c.draw_colored_polygon(right, PINK.darkened(0.45))
	GI._slab(c, Rect2(42, 46, 50, 38), PINK.darkened(0.6), PINK, 10, 0.6)
	txt(c, "!", Vector2(67, 65), 28, Color(1, 1, 1, 0.95))

static func _logo_color_sort(c: CanvasItem) -> void:
	var tubes := [
		[CYAN, LIME, CYAN],
		[PINK, PINK, PINK],
		[LIME],
	]
	for i in range(3):
		var x := 12.0 + i * 27.0
		var segs: Array = tubes[i]
		for j in range(segs.size()):
			var col: Color = segs[j]
			GI._slab(c, Rect2(x + 3, 78.0 - (j + 1) * 17.0, 16, 15), col.darkened(0.2), col, 3, 0.4)
		GI._slab(c, Rect2(x, 14, 22, 70), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.75), 10, 0.0)

static func _logo_hidato(c: CanvasItem) -> void:
	var path := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	for r in range(3):
		for k in range(3):
			cell(c, Rect2(11 + k * 28, 11 + r * 28, 22, 22), GOLD, Vector2i(k, r) in path)
	var line := PackedVector2Array()
	for p in path:
		line.append(Vector2(22 + p.x * 28, 22 + p.y * 28))
	GI._glow_poly_open(c, line, GOLD.lightened(0.2), 1.6)
	for i in range(path.size()):
		var p: Vector2i = path[i]
		txt(c, str(i + 1), Vector2(22 + p.x * 28, 22 + p.y * 28), 15, Color(1, 1, 1, 0.97))
