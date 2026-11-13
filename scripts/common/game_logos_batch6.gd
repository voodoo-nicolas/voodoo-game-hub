extends RefCounted

## Batch 6 logos drawn in code (2026-11-13, hub fixes): the three games that had no
## picture at all -- Rectangles, Bug Chain, Last Shift. Same 100x100 box and rules as
## game_logos.gd (neon on transparent, no emoji, single Latin capitals / digits).
## Add one: `_logo_<id>(c)`, id in IDS, line in `_logo()`.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const RED := Color(1.0, 0.25, 0.3)

const IDS := ["rectangles", "bug_chain", "last_shift"]

static func has(id: String) -> bool:
	return id in IDS

static func draw(c: Control, id: String) -> void:
	var s: float = min(c.size.x, c.size.y)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - s) * 0.5, (c.size.y - s) * 0.5)
	c.draw_set_transform_matrix(Transform2D(0.0, Vector2(s / 100.0, s / 100.0), 0.0, origin))
	logo(c, id)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func logo(c: CanvasItem, id: String) -> void:
	match id:
		"rectangles": _logo_rectangles(c)
		"bug_chain": _logo_bug_chain(c)
		"last_shift": _logo_last_shift(c)

## A 5x5 grid split into glowing rectangles, each with its size in one cell.
static func _logo_rectangles(c: CanvasItem) -> void:
	var o := Vector2(12, 12)
	var cell := 15.2
	for i in range(6):
		c.draw_line(o + Vector2(i * cell, 0), o + Vector2(i * cell, 5 * cell), Color(1, 1, 1, 0.12), 1.0)
		c.draw_line(o + Vector2(0, i * cell), o + Vector2(5 * cell, i * cell), Color(1, 1, 1, 0.12), 1.0)
	# [x, y, w, h, colour, the number's cell]
	var rects := [
		[0, 0, 3, 2, CYAN, Vector2(1, 0)], [3, 0, 2, 3, PINK, Vector2(4, 1)],
		[0, 2, 1, 3, LIME, Vector2(0, 3)], [1, 2, 2, 2, GOLD, Vector2(2, 3)],
		[1, 4, 4, 1, MAGENTA, Vector2(3, 4)], [3, 3, 2, 1, BLUE, Vector2(4, 3)],
	]
	for r in rects:
		var rect := Rect2(o + Vector2(r[0], r[1]) * cell, Vector2(r[2], r[3]) * cell).grow(-2.0)
		c.draw_rect(rect, Color(r[4], 0.16))
		GI._glow_poly(c, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), r[4], 1.8)
		L.txt(c, str(int(r[2]) * int(r[3])), o + (r[5] + Vector2(0.5, 0.5)) * cell, 11, Color(1, 1, 1, 0.95))

## A beetle: oval shell split down the middle, head, six legs.
static func beetle(c: CanvasItem, p: Vector2, r: float, col: Color, ang: float = 0.0) -> void:
	var fwd := Vector2(cos(ang), sin(ang))
	var side := Vector2(-fwd.y, fwd.x)
	for k in [-1.0, 0.0, 1.0]:
		var base: Vector2 = p + fwd * k * r * 0.5
		c.draw_line(base + side * r * 0.8, base + side * r * 1.35 + fwd * k * r * 0.3, Color(col.darkened(0.4), 0.9), 1.2)
		c.draw_line(base - side * r * 0.8, base - side * r * 1.35 + fwd * k * r * 0.3, Color(col.darkened(0.4), 0.9), 1.2)
	c.draw_circle(p, r * 1.15, Color(col, 0.2))
	c.draw_circle(p, r, col)
	c.draw_circle(p + fwd * r * 1.05, r * 0.45, col.darkened(0.55))
	c.draw_line(p - fwd * r * 0.9, p + fwd * r * 0.7, col.darkened(0.5), 1.2)
	c.draw_circle(p - side * r * 0.35 - fwd * r * 0.2, r * 0.18, Color(1, 1, 1, 0.55))

static func _logo_bug_chain(c: CanvasItem) -> void:
	var cols := [LIME, PINK, PINK, CYAN, GOLD, GOLD, GOLD, LIME]
	var path := PackedVector2Array()
	for i in range(40):
		var t := float(i) / 39.0
		path.append(Vector2(10 + t * 80.0, 34 + sin(t * PI * 1.6) * 16.0))
	c.draw_polyline(path, Color(GOLD, 0.18), 7.0)
	for i in range(cols.size()):
		var t := 0.06 + i * 0.12
		var p := Vector2(10 + t * 80.0, 34 + sin(t * PI * 1.6) * 16.0)
		var d := Vector2(80.0, cos(t * PI * 1.6) * 16.0 * PI * 1.6)
		beetle(c, p, 5.2, cols[i], d.angle())
	# the launcher on its rail, firing a beetle up
	GI._glow_line(c, Vector2(14, 88), Vector2(86, 88), BLUE, 1.6)
	var gun := PackedVector2Array([Vector2(42, 88), Vector2(58, 88), Vector2(54, 76), Vector2(46, 76)])
	c.draw_colored_polygon(gun, BLUE.darkened(0.5))
	GI._glow_poly(c, gun, BLUE, 1.8)
	beetle(c, Vector2(50, 66), 4.6, CYAN, -PI / 2.0)
	GI._glow_line(c, Vector2(50, 58), Vector2(50, 50), Color(1, 1, 1, 0.5), 1.0)

## Night shift horror: a wall clock stuck at 3:00 in the dark, a torch beam across it.
static func _logo_last_shift(c: CanvasItem) -> void:
	var beam := PackedVector2Array([Vector2(4, 96), Vector2(98, 20), Vector2(98, 62)])
	c.draw_colored_polygon(beam, Color(1.0, 0.95, 0.7, 0.13))
	var ctr := Vector2(50, 44)
	c.draw_circle(ctr, 33.0, Color(RED, 0.12))
	c.draw_circle(ctr, 29.0, Color(0.06, 0.05, 0.07))
	c.draw_arc(ctr, 29.0, 0.0, TAU, 40, RED, 2.6, true)
	for i in range(12):
		var a := TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		c.draw_line(ctr + d * (23.0 if i % 3 == 0 else 25.0), ctr + d * 27.0, Color(1, 1, 1, 0.75), 1.6 if i % 3 == 0 else 1.0)
	GI._glow_line(c, ctr, ctr + Vector2(0, -19), Color(1, 1, 1, 0.95), 2.4)  # 12
	GI._glow_line(c, ctr, ctr + Vector2(14, 0), Color(1, 1, 1, 0.95), 3.0)   # 3
	c.draw_circle(ctr, 2.6, RED)
	# drips under the clock
	for x in [38.0, 52.0, 63.0]:
		var h: float = 8.0 + fmod(x * 7.0, 9.0)
		GI._glow_line(c, Vector2(x, 76), Vector2(x, 76 + h), RED, 1.6)
		c.draw_circle(Vector2(x, 77 + h), 1.8, RED)
	L.txt(c, "3:00", Vector2(50, 92), 11, Color(RED, 0.9))
