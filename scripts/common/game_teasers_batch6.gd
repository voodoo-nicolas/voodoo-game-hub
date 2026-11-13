extends RefCounted

## Batch 6 TEASERS (2026-11-13, hub fixes): 160x90 mini scenes for Rectangles, Bug Chain
## and Last Shift -- the Game Browser preview for games with no picture. Same rules as
## game_teasers.gd; the logos' helpers come from game_logos_batch6.gd (B).

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")
const T = preload("res://scripts/common/game_teasers.gd")
const B = preload("res://scripts/common/game_logos_batch6.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const MAGENTA := GI.MAGENTA
const RED := B.RED
const W := 160.0
const H := 90.0

const IDS := B.IDS

static func has(id: String) -> bool:
	return id in IDS

static func draw(c: Control, id: String) -> void:
	var s: float = minf(c.size.x / W, c.size.y / H)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - W * s) * 0.5, (c.size.y - H * s) * 0.5)
	var base := Transform2D(0.0, Vector2(s, s), 0.0, origin)
	c.draw_set_transform_matrix(base)
	match id:
		"rectangles": _teaser_rectangles(c, base)
		"bug_chain": _teaser_bug_chain(c, base)
		"last_shift": _teaser_last_shift(c, base)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## Logo `id` drawn into a size x size box centred on ctr (through `base`).
static func _logo_at(c: CanvasItem, base: Transform2D, id: String, ctr: Vector2, size: float) -> void:
	var k := size / 100.0
	c.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(k, k), 0.0, ctr - Vector2(size, size) * 0.5))
	B.logo(c, id)
	c.draw_set_transform_matrix(base)

## A half-solved 8x5 board: rectangles drawn, a finger dragging the next one.
static func _teaser_rectangles(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var o := Vector2(22, 8)
	var cell := 14.5
	for i in range(9):
		c.draw_line(o + Vector2(i * cell, 0), o + Vector2(i * cell, 5 * cell), Color(1, 1, 1, 0.12), 1.0)
	for j in range(6):
		c.draw_line(o + Vector2(0, j * cell), o + Vector2(8 * cell, j * cell), Color(1, 1, 1, 0.12), 1.0)
	var done := [[0, 0, 2, 3, PINK], [2, 0, 4, 1, CYAN], [0, 3, 3, 2, LIME], [6, 0, 2, 2, GOLD], [3, 3, 1, 2, MAGENTA]]
	for r in done:
		var rect := Rect2(o + Vector2(r[0], r[1]) * cell, Vector2(r[2], r[3]) * cell).grow(-1.5)
		c.draw_rect(rect, Color(r[4], 0.18))
		GI._glow_poly(c, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), r[4], 1.4)
	# numbers still waiting
	for n in [[Vector2(1, 1), "6"], [Vector2(4, 0), "4"], [Vector2(1, 4), "6"], [Vector2(7, 1), "4"], [Vector2(3, 4), "2"], [Vector2(5, 2), "6"], [Vector2(7, 4), "4"]]:
		L.txt(c, n[1], o + (n[0] + Vector2(0.5, 0.5)) * cell, 10, Color(1, 1, 1, 0.92))
	# the drag in progress
	var drag := Rect2(o + Vector2(4, 1) * cell, Vector2(3, 2) * cell).grow(-1.5)
	c.draw_rect(drag, Color(BLUE, 0.12))
	GI._glow_poly(c, PackedVector2Array([drag.position, Vector2(drag.end.x, drag.position.y), drag.end, Vector2(drag.position.x, drag.end.y)]), BLUE, 1.0)
	c.draw_circle(drag.end, 4.0, Color(1, 1, 1, 0.85))
	c.draw_circle(drag.end, 7.0, Color(1, 1, 1, 0.2))

## A garden path: the beetle chain winding toward the pit, the launcher firing.
static func _teaser_bug_chain(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var pts := PackedVector2Array()
	for i in range(60):
		var t := float(i) / 59.0
		pts.append(Vector2(8 + t * 130.0, 22 + sin(t * PI * 2.2) * 12.0 + t * 18.0))
	c.draw_polyline(pts, Color(0.55, 0.4, 0.2, 0.55), 12.0)
	c.draw_polyline(pts, Color(0.75, 0.55, 0.3, 0.35), 8.0)
	# the pit at the end
	c.draw_circle(pts[59], 9.0, Color(0, 0, 0, 0.9))
	c.draw_arc(pts[59], 9.0, 0.0, TAU, 24, Color(RED, 0.8), 1.6, true)
	var cols := [CYAN, CYAN, PINK, GOLD, GOLD, LIME, PINK, PINK, PINK, CYAN, GOLD, LIME]
	for i in range(cols.size()):
		var k := mini(4 + i * 4, 58)
		var d := pts[k + 1] - pts[k]
		B.beetle(c, pts[k], 4.2, cols[i], d.angle())
	# a pop burst where three pinks just met
	var pop := pts[30]
	for i in range(8):
		var a := TAU * i / 8.0
		GI._glow_line(c, pop + Vector2(cos(a), sin(a)) * 6.0, pop + Vector2(cos(a), sin(a)) * 11.0, PINK, 1.0)
	# launcher on the rail
	GI._glow_line(c, Vector2(20, 84), Vector2(140, 84), BLUE, 1.4)
	var gun := PackedVector2Array([Vector2(70, 84), Vector2(84, 84), Vector2(80, 74), Vector2(74, 74)])
	c.draw_colored_polygon(gun, BLUE.darkened(0.5))
	GI._glow_poly(c, gun, BLUE, 1.6)
	B.beetle(c, Vector2(77, 64), 3.8, GOLD, -PI / 2.0)

## A dark shop aisle at 3 a.m.: shelves, the torch beam, a shape at the end, the clock.
static func _teaser_last_shift(c: CanvasItem, base: Transform2D) -> void:
	c.draw_rect(Rect2(-20, -20, W + 40, H + 40), Color(0.02, 0.015, 0.03))
	# aisle in perspective
	var vp := Vector2(96, 40)
	for side in [-1.0, 1.0]:
		var x0: float = 96.0 + side * 70.0
		GI._glow_line(c, Vector2(x0, 0), vp + Vector2(side * 12.0, -14.0), Color(0.3, 0.32, 0.4, 0.6), 1.0)
		GI._glow_line(c, Vector2(x0, 90), vp + Vector2(side * 12.0, 14.0), Color(0.3, 0.32, 0.4, 0.6), 1.0)
		for k in range(4):
			var t := 0.2 + k * 0.2
			var y := lerpf(18.0, 0.0, t) + k * 0.0
			c.draw_line(Vector2(lerpf(x0, vp.x + side * 12.0, t), lerpf(0.0, 26.0, t) + 12.0 * (1.0 - t)),
				Vector2(lerpf(x0, vp.x + side * 12.0, t), lerpf(90.0, 54.0, t) - 12.0 * (1.0 - t)), Color(0.35, 0.37, 0.45, 0.35), 1.0)
	# torch beam from the bottom left
	c.draw_colored_polygon(PackedVector2Array([Vector2(30, 92), Vector2(84, 30), Vector2(112, 52)]), Color(1.0, 0.95, 0.7, 0.14))
	# the figure at the end of the aisle
	c.draw_circle(vp + Vector2(0, -6), 3.4, Color(0, 0, 0))
	c.draw_colored_polygon(PackedVector2Array([vp + Vector2(-4, -3), vp + Vector2(4, -3), vp + Vector2(5, 12), vp + Vector2(-5, 12)]), Color(0, 0, 0))
	c.draw_circle(vp + Vector2(-1.2, -6.5), 0.8, RED)
	c.draw_circle(vp + Vector2(1.2, -6.5), 0.8, RED)
	_logo_at(c, base, "last_shift", Vector2(26, 26), 44.0)
