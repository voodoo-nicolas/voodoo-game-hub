extends RefCounted

## How the controller looks. Everything is drawn in code (0 bytes of art), in skins taken from the
## owner's mock-ups: "mono" (flat greys), "neon" (blue glass, A green / B red / X blue / Y gold),
## "outline" (thin white lines, the Last Shift look). Every function takes the CanvasItem to draw
## on and `a`, the overall alpha (the player's opacity, raised while a part is touched).

const SKINS := {
	"mono": {
		"name": "Mono", "plate": true, "glow": false, "arrows": false,
		"fill": Color(0.09, 0.09, 0.10, 0.88), "line": Color(0.66, 0.66, 0.70, 0.75),
		"plate_fill": Color(0.07, 0.07, 0.08, 0.55), "plate_line": Color(0.55, 0.55, 0.60, 0.45),
		"knob": Color(0.36, 0.36, 0.38, 0.95), "knob_line": Color(0.80, 0.80, 0.84, 0.9),
		"text": Color(0.94, 0.94, 0.96), "lit": Color(1, 1, 1, 0.30),
		"face": {},
	},
	"neon": {
		"name": "Neon", "plate": true, "glow": true, "arrows": true,
		"fill": Color(0.04, 0.09, 0.19, 0.86), "line": Color("3d8bff"),
		"plate_fill": Color(0.03, 0.07, 0.16, 0.50), "plate_line": Color(0.24, 0.55, 1.0, 0.55),
		"knob": Color(0.28, 0.46, 0.92, 0.80), "knob_line": Color("9cc0ff"),
		"text": Color(0.92, 0.95, 1.0), "lit": Color(0.35, 0.65, 1.0, 0.40),
		"face": {"a": Color("2fd35b"), "b": Color("ff3b5c"), "x": Color("29a3ff"), "y": Color("ffb21f")},
	},
	"outline": {
		"name": "Outline", "plate": false, "glow": false, "arrows": false,
		"fill": Color(1, 1, 1, 0.14), "line": Color(1, 1, 1, 0.60),
		"plate_fill": Color(1, 1, 1, 0.0), "plate_line": Color(1, 1, 1, 0.0),
		"knob": Color(1, 1, 1, 0.34), "knob_line": Color(1, 1, 1, 0.70),
		"text": Color(1, 1, 1, 0.95), "lit": Color(1, 1, 1, 0.45),
		"face": {},
	},
}

static func skin_ids() -> Array:
	return SKINS.keys()

static func skin(id: String) -> Dictionary:
	return SKINS.get(id, SKINS["neon"])

static func _c(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * a)

static func _ring(ci: CanvasItem, p: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_arc(p, r, 0.0, TAU, maxi(24, int(r * 0.6)), col, w, true)

## A soft neon halo: a few wide, faint rings outside the line.
static func _glow(ci: CanvasItem, p: Vector2, r: float, col: Color, a: float) -> void:
	for i in 3:
		_ring(ci, p, r + 2.0 + i * 3.0, Color(col.r, col.g, col.b, 0.16 * a / (i + 1)), 5.0)

static func _text(ci: CanvasItem, p: Vector2, s: String, px: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc := font.get_ascent(px)
	var at := p + Vector2(-w * 0.5, asc * 0.5 - 2.0)
	ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color(0, 0, 0, col.a * 0.45))
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

static func _tri(ci: CanvasItem, c: Vector2, dir: Vector2, size: float, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	ci.draw_colored_polygon(PackedVector2Array([c + dir * size, c - dir * size * 0.6 + side * size * 0.8, c - dir * size * 0.6 - side * size * 0.8]), col)

## The round plate behind the face buttons.
static func plate(ci: CanvasItem, p: Vector2, r: float, sk: Dictionary, a: float) -> void:
	if not sk["plate"]:
		return
	ci.draw_circle(p, r, _c(sk["plate_fill"], a))
	_ring(ci, p, r, _c(sk["plate_line"], a), 2.0)

## Analog stick. `off` = how far the knob is pushed (pixels), `held` = a finger is on it.
static func stick(ci: CanvasItem, p: Vector2, r: float, knob_r: float, off: Vector2, held: bool, sk: Dictionary, a: float) -> void:
	var line: Color = sk["line"]
	ci.draw_circle(p, r, _c(sk["fill"], a * 0.75))
	if sk["glow"]:
		_glow(ci, p, r, line, a)
	_ring(ci, p, r, _c(line, a), 3.0)
	_ring(ci, p, r * 0.74, _c(line, a * 0.35), 2.0)
	if sk["arrows"]:
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			_tri(ci, p + d * r * 0.86, d, r * 0.07, _c(sk["knob_line"], a * 0.8))
	var kp := p + off
	ci.draw_circle(kp, knob_r, _c(sk["knob"], a * (1.0 if held else 0.8)))
	ci.draw_circle(kp + Vector2(-knob_r * 0.22, -knob_r * 0.26), knob_r * 0.55, Color(1, 1, 1, 0.10 * a))
	_ring(ci, kp, knob_r, _c(sk["knob_line"], a), 3.0)

## Four arrow pads in a round plate. `lit` = Vector2 of the pressed direction(s).
static func dpad(ci: CanvasItem, p: Vector2, r: float, lit: Vector2, sk: Dictionary, a: float) -> void:
	var line: Color = sk["line"]
	ci.draw_circle(p, r, _c(sk["plate_fill"] if sk["plate"] else sk["fill"], a))
	_ring(ci, p, r, _c(sk["plate_line"] if sk["plate"] else line, a), 2.5)
	var pad := Vector2(r * 0.62, r * 0.56)
	var dist := r * 0.52
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var c: Vector2 = p + d * dist
		var sz := Vector2(pad.x, pad.y) if d.y != 0.0 else Vector2(pad.y, pad.x)
		var on: bool = (d.x != 0.0 and lit.x == d.x) or (d.y != 0.0 and lit.y == d.y)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(r * 0.14))
		sb.bg_color = _c(sk["lit"], a * 1.6) if on else _c(sk["fill"], a)
		sb.border_color = _c(line, a)
		sb.set_border_width_all(2)
		ci.draw_style_box(sb, Rect2(c - sz * 0.5, sz))
		_tri(ci, c, d, r * 0.13, _c(sk["text"], a * (1.0 if on else 0.8)))

## A round button. `color` tints the ring and letter (neon face colours); `down` lights it.
## `sub` = a word under the letter (shrunk to fit); `ring` = an amber ring around it (e.g. sneaking).
static func button(ci: CanvasItem, p: Vector2, r: float, id: String, label: String, down: bool, enabled: bool, sk: Dictionary, a: float, sub: String = "", ring: bool = false) -> void:
	var col: Color = sk["face"].get(id, sk["line"])
	var al := a * (1.0 if enabled else 0.4)
	ci.draw_circle(p, r, _c(sk["fill"], al))
	if down:
		ci.draw_circle(p, r, _c(col if sk["glow"] else sk["lit"], al * 0.45))
	if sk["glow"]:
		_glow(ci, p, r, col, al)
	_ring(ci, p, r, _c(col, al), 3.0)
	ci.draw_circle(p + Vector2(-r * 0.2, -r * 0.28), r * 0.5, Color(1, 1, 1, 0.07 * al))
	var tc: Color = col if sk["glow"] else sk["text"]
	if sub == "":
		_text(ci, p, label, int(r * 0.9), _c(tc, al))
	else:
		_text(ci, p + Vector2(0, -r * 0.2), label, int(r * 0.72), _c(tc, al))
		var px := int(r * 0.34)
		var font := ThemeDB.fallback_font
		while px > 9 and font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > r * 1.65:
			px -= 1
		_text(ci, p + Vector2(0, r * 0.46), sub, px, _c(sk["text"], al * 0.95))
	if ring:
		_ring(ci, p, r + 6.0, Color(1.0, 0.78, 0.3, 0.9 * a), 3.0)

## A small rounded system button with an icon.
static func pill(ci: CanvasItem, rect: Rect2, icon: String, down: bool, sk: Dictionary, a: float) -> void:
	var line: Color = sk["line"]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(rect.size.y * 0.3))
	sb.bg_color = _c(sk["lit"], a * 1.4) if down else _c(sk["fill"], a)
	sb.border_color = _c(line, a)
	sb.set_border_width_all(3)
	if sk["glow"]:
		sb.shadow_color = Color(line.r, line.g, line.b, 0.25 * a)
		sb.shadow_size = 8
	ci.draw_style_box(sb, rect)
	var c := rect.get_center()
	var col := _c(sk["text"], a)
	var h := rect.size.y
	match icon:
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.19, -h * 0.24), Vector2(h * 0.12, h * 0.48)), col)
			ci.draw_rect(Rect2(c + Vector2(h * 0.07, -h * 0.24), Vector2(h * 0.12, h * 0.48)), col)
		"info":
			ci.draw_circle(c, h * 0.29, col)
			_text(ci, c, "i", int(h * 0.42), Color(0.05, 0.08, 0.16, a))
		"menu":
			for i in 3:
				ci.draw_rect(Rect2(c + Vector2(-h * 0.24, -h * 0.22 + i * h * 0.19), Vector2(h * 0.48, h * 0.08)), col)

## Map mode: a dashed hit area and the action names, drawn over a part whatever its opacity.
static func map_label(ci: CanvasItem, p: Vector2, lines: Array, col: Color, px: int = 15) -> void:
	var gap := px * 1.2
	var y := -float(lines.size() - 1) * gap * 0.5
	for s in lines:
		_text(ci, p + Vector2(0, y), str(s), px, col)
		y += gap

static func map_ring(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var n := maxi(16, int(r * 0.45))
	for i in n:
		if i % 2 == 0:
			ci.draw_arc(p, r, TAU * i / n, TAU * (i + 1) / n, 4, col, 2.0, true)
