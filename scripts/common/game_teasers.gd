extends RefCounted

## Per-game TEASER pictures drawn in code: a 16:9 mini scene (160x90 box, origin top-left)
## that shows what the game looks like. Shown in the Game Browser detail; used through
## game_art.gd. No image assets. Replace a game's teaser with real art any time via the
## manifest "tile_art"/"hero_art" (hub_art.gd) -- real art wins.
##
## Add one: write `_teaser_<id>(c, base)` here, add the id to IDS and a `match` line in `_scene()`.
## `base` is the scene transform; call GameLogos.logo_at(c, base, id, ctr, size) to place a logo.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const W := 160.0
const H := 90.0

const IDS := [
	"trivia", "quick_math", "memory_grid", "color_clash", "number_series", "digit_recall",
	"voodoo_iq", "sketch_it", "trace_it", "trivia_battle", "color_sort", "hidato",
]

static func has(id: String) -> bool:
	return id in IDS

## Draws teaser `id` filling the Control `c` (16:9; letterboxed if the box is another shape).
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
		"trivia": _teaser_trivia(c, base)
		"quick_math": _teaser_quick_math(c, base)
		"memory_grid": _teaser_memory_grid(c, base)
		"color_clash": _teaser_color_clash(c, base)
		"number_series": _teaser_number_series(c, base)
		"digit_recall": _teaser_digit_recall(c, base)
		"voodoo_iq": _teaser_voodoo_iq(c, base)
		"sketch_it": _teaser_sketch_it(c, base)
		"trace_it": _teaser_trace_it(c, base)
		"trivia_battle": _teaser_trivia_battle(c, base)
		"color_sort": _teaser_color_sort(c, base)
		"hidato": _teaser_hidato(c, base)

## Near-black with a soft glow of `col` and a faint grid. Overdraws the box on purpose
## (the picture is clipped to its rounded frame).
static func backdrop(c: CanvasItem, col: Color) -> void:
	c.draw_rect(Rect2(-20, -20, W + 40, H + 40), Color(0.015, 0.025, 0.06))
	for k in range(5):
		c.draw_circle(Vector2(W * 0.5, H * 0.5), 100.0 - k * 17.0, Color(col, 0.035 + k * 0.012))
	var line := Color(col, 0.07)
	var x := 0.0
	while x <= W:
		c.draw_line(Vector2(x, 0), Vector2(x, H), line, 1.0)
		x += 16.0
	var y := 0.0
	while y <= H:
		c.draw_line(Vector2(0, y), Vector2(W, y), line, 1.0)
		y += 15.0

## ---------- the 12 Intelligence teasers ----------

static func _teaser_trivia(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, BLUE)
	L.panel(c, Rect2(12, 8, 136, 34), BLUE, 9)
	GI._sphere(c, Vector2(30, 25), 11.0, BLUE)
	L.txt(c, "?", Vector2(30, 25), 16, Color(1, 1, 1, 0.95))
	c.draw_line(Vector2(48, 20), Vector2(132, 20), Color(1, 1, 1, 0.55), 3.0, true)
	c.draw_line(Vector2(48, 31), Vector2(108, 31), Color(1, 1, 1, 0.3), 3.0, true)
	for i in range(4):
		var r := Rect2(12 + (i % 2) * 70, 50 + floori(i / 2.0) * 20, 66, 16)
		var good: bool = i == 1
		var col: Color = LIME if good else BLUE
		L.cell(c, r, col, good, 8.0)
		c.draw_line(r.position + Vector2(10, 8), r.position + Vector2(10 + 28 + (i * 7) % 14, 8), Color(1, 1, 1, 0.5), 2.5, true)

static func _teaser_quick_math(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, LIME)
	L.meter(c, Rect2(14, 8, 132, 7), LIME, 0.65)
	L.txt(c, "7 + 5 = ?", Vector2(80, 36), 30, Color(1, 1, 1, 0.96))
	var nums := ["11", "12", "13"]
	for i in range(3):
		var hot: bool = i == 1
		var r := Rect2(12 + i * 46, 58, 40, 24)
		L.cell(c, r, LIME if hot else CYAN, hot, 8.0)
		L.txt(c, nums[i], r.get_center(), 16, Color(1, 1, 1, 0.95))

static func _teaser_memory_grid(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, CYAN)
	var lit := [1, 6, 7, 10, 12]
	for r in range(4):
		for k in range(4):
			L.cell(c, Rect2(40 + k * 21, 5 + r * 21, 17, 17), CYAN, (r * 4 + k) in lit, 4.0)
	GI._glow_line(c, Vector2(14, 70), Vector2(14, 40), GOLD, 2.4)   # level bars either side
	GI._glow_line(c, Vector2(146, 70), Vector2(146, 28), GOLD, 2.4)

static func _teaser_color_clash(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, PINK)
	L.meter(c, Rect2(14, 8, 132, 7), PINK, 0.55)
	GI._sphere(c, Vector2(80, 36), 19.0, LIME)
	c.draw_arc(Vector2(80, 36), 28.0, 0.0, TAU, 32, PINK, 2.5, true)
	var cols := [PINK, BLUE, LIME, GOLD]
	for i in range(4):
		var col: Color = cols[i]
		var r := Rect2(12 + i * 36, 64, 32, 18)
		GI._slab(c, r, col.darkened(0.4), col.lightened(0.6) if i == 2 else col, 9, 0.7 if i == 2 else 0.2)

static func _teaser_number_series(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, CYAN)
	var labels := ["2", "4", "8", "16", "?"]
	for i in range(5):
		var hot: bool = i == 4
		var r := Rect2(8 + i * 30, 30, 24, 32)
		L.cell(c, r, GOLD if hot else CYAN, hot, 7.0)
		L.txt(c, labels[i], r.get_center(), 17, Color(1, 1, 1, 0.96))
		if i < 4:
			L.txt(c, "x2", Vector2(8 + i * 30 + 27, 22), 9, Color(CYAN, 0.85))
			GI._glow_arc(c, Vector2(8 + i * 30 + 27, 36), 11.0, PI * 1.15, PI * 1.85, CYAN, 1.0)
	for i in range(5):
		c.draw_circle(Vector2(60 + i * 10, 76), 2.6, Color(GOLD, 1.0 if i < 2 else 0.3))

static func _teaser_digit_recall(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, GOLD)
	var d := ["4", "7", "2", "9"]
	for i in range(4):
		var a := 1.0 if i < 3 else 0.28
		L.txt(c, d[i], Vector2(32 + i * 32, 34), 30, Color(1, 1, 1, a))
		c.draw_line(Vector2(20 + i * 32, 54), Vector2(44 + i * 32, 54), Color(GOLD, a), 2.5, true)
	L.meter(c, Rect2(24, 68, 112, 8), GOLD, 0.45)

static func _teaser_voodoo_iq(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, PINK)
	var orbit := GI._pts(Vector2(80, 45), 66.0, 34.0)
	orbit.append(orbit[0])
	c.draw_polyline(orbit, Color(PINK, 0.3), 1.4, true)
	L.logo_at(c, base, "voodoo_iq", Vector2(80, 46), 72.0)
	# puzzle shapes on the orbit
	GI._glow_poly(c, PackedVector2Array([Vector2(24, 30), Vector2(16, 44), Vector2(32, 44)]), CYAN, 2.0)
	GI._slab(c, Rect2(126, 14, 16, 16), CYAN.darkened(0.6), CYAN, 3, 0.4)
	c.draw_circle(Vector2(30, 68), 7.0, Color(LIME, 0.25))
	c.draw_arc(Vector2(30, 68), 7.0, 0.0, TAU, 20, LIME, 2.0, true)
	L.txt(c, "?", Vector2(134, 66), 22, Color(GOLD, 0.95))

static func _teaser_sketch_it(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, CYAN)
	L.panel(c, Rect2(10, 8, 96, 74), CYAN, 8)
	# a doodled house and sun
	GI._glow_poly(c, PackedVector2Array([Vector2(34, 66), Vector2(34, 44), Vector2(70, 44), Vector2(70, 66)]), LIME, 1.8)
	GI._glow_poly_open(c, PackedVector2Array([Vector2(30, 46), Vector2(52, 26), Vector2(74, 46)]), PINK, 1.8)
	GI._glow_poly(c, PackedVector2Array([Vector2(46, 66), Vector2(46, 54), Vector2(58, 54), Vector2(58, 66)]), GOLD, 1.5)
	c.draw_arc(Vector2(90, 22), 6.0, 0.0, TAU, 20, GOLD, 2.0, true)
	var swatch := [PINK, LIME, GOLD]
	for i in range(3):
		GI._sphere(c, Vector2(136, 13 + i * 12), 5.0, swatch[i])
	L.logo_at(c, base, "sketch_it", Vector2(128, 66), 46.0)

static func _teaser_trace_it(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, LIME)
	var pts := PackedVector2Array()
	for i in range(6):
		var a := -PI * 0.5 + i * TAU * 2.0 / 5.0
		pts.append(Vector2(80, 47) + Vector2(cos(a), sin(a)) * 37.0)
	for s in range(5):
		var a: Vector2 = pts[s]
		var b: Vector2 = pts[s + 1]
		var n := int(a.distance_to(b) / 6.0)
		for k in range(n):
			c.draw_circle(a.lerp(b, float(k) / n), 1.3, Color(CYAN, 0.45))
	GI._glow_poly_open(c, pts.slice(0, 4), LIME, 2.6)
	GI._sphere(c, pts[0], 4.0, LIME)
	GI._sphere(c, pts[3], 6.0, GOLD)

static func _teaser_trivia_battle(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, MAGENTA)
	L.logo_at(c, base, "trivia", Vector2(80, 22), 36.0)
	GI._sphere(c, Vector2(32, 36), 12.0, CYAN)
	GI._sphere(c, Vector2(128, 36), 12.0, PINK)
	L.txt(c, "VS", Vector2(80, 58), 20, GOLD)
	L.meter(c, Rect2(8, 62, 52, 9), CYAN, 0.7)
	L.meter(c, Rect2(100, 62, 52, 9), PINK, 0.4)
	L.txt(c, "3", Vector2(34, 80), 12, CYAN)
	L.txt(c, "2", Vector2(126, 80), 12, PINK)

static func _teaser_color_sort(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, CYAN)
	var tubes := [
		[CYAN, CYAN, CYAN, CYAN],
		[PINK, PINK, LIME, PINK],
		[LIME, LIME, GOLD, GOLD],
		[GOLD, PINK, LIME, CYAN],
		[],
	]
	for i in range(5):
		var x := 13.0 + i * 28.0
		var segs: Array = tubes[i]
		for j in range(segs.size()):
			var col: Color = segs[j]
			GI._slab(c, Rect2(x + 2, 80.0 - (j + 1) * 14.0, 14, 13), col.darkened(0.2), col, 2, 0.3)
		GI._slab(c, Rect2(x, 20, 18, 62), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.75), 8, 0.0)
	GI._glow_line(c, Vector2(15, 12), Vector2(25, 12), GOLD, 1.6)
	GI._glow_line(c, Vector2(20, 7), Vector2(20, 17), GOLD, 1.6)

static func _teaser_hidato(c: CanvasItem, base: Transform2D) -> void:
	backdrop(c, GOLD)
	var path := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)]
	for r in range(4):
		for k in range(5):
			L.cell(c, Rect2(29 + k * 21, 5 + r * 21, 18, 18), GOLD, Vector2i(k, r) in path, 4.0)
	var line := PackedVector2Array()
	for i in range(5):
		var p: Vector2i = path[i]
		line.append(Vector2(38 + p.x * 21, 14 + p.y * 21))
	GI._glow_poly_open(c, line, GOLD.lightened(0.2), 1.4)
	for i in range(path.size()):
		var p: Vector2i = path[i]
		L.txt(c, str(i + 1), Vector2(38 + p.x * 21, 14 + p.y * 21), 11, Color(1, 1, 1, 0.97))
