extends RefCounted

## The chess pieces, drawn in code (no font glyphs: phones fill in ♟ from the
## emoji font, so one side looked different). Staunton-style silhouettes in a
## 1 x 1 box (y down, base at 0.93), filled with a left-to-right gradient so
## they look turned, a clean outer outline, and a few detail lines.
## A piece set (chess_styles.gd) only changes the colours.
##
##     ChessPieces.draw(canvas, ChessEngine.KNIGHT, true, Rect2(...), style)
##     style = {"light": Color, "dark": Color, "line": Color, "detail": Color,
##              "glow": Color (optional: neon halo, the Voodoo look)}

const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

## Shapes per piece type, built once: [{"pts": PackedVector2Array}].
static var _shapes: Dictionary = {}
## Detail lines per piece type: [[Vector2, Vector2], ...].
static var _details: Dictionary = {}

static func draw(c: CanvasItem, ptype: int, white: bool, r: Rect2, style: Dictionary) -> void:
	if _shapes.is_empty():
		_build()
	var shapes: Array = _shapes.get(ptype, [])
	var w: float = maxf(1.5, r.size.x * 0.035)
	var line: Color = style.get("line", Color.BLACK)
	if style.has("glow"):
		var g: Color = style.glow
		for spec in [[4.0, 0.10], [2.4, 0.22]]:
			for s in shapes:
				var pts := _place(s.pts, r)
				c.draw_polyline(_closed(pts), Color(g, spec[1]), w * spec[0], true)
		line = g
	# Outline first, drawn wide; the fills on top leave only the outer edge.
	for s in shapes:
		var pts := _place(s.pts, r)
		c.draw_polyline(_closed(pts), line, w * 2.0, true)
		for p in pts:
			c.draw_circle(p, w, line)
	var light: Color = style.get("light", Color.WHITE)
	var dark: Color = style.get("dark", Color.GRAY)
	for s in shapes:
		var pts := _place(s.pts, r)
		var cols := PackedColorArray()
		for i in s.pts.size():
			var t: float = clampf((s.pts[i].x - 0.22) / 0.56, 0.0, 1.0)
			cols.append(light.lerp(dark, t))
		c.draw_polygon(pts, cols)
	var detail: Color = style.get("detail", Color(line, 0.6))
	for d in _details.get(ptype, []):
		c.draw_line(r.position + d[0] * r.size, r.position + d[1] * r.size, detail, maxf(1.0, w * 0.8), true)
	if ptype == KNIGHT:
		c.draw_circle(r.position + Vector2(0.43, 0.30) * r.size, r.size.x * 0.03, detail)

static func _place(pts: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(r.position + p * r.size)
	return out

static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if pts.size() > 0:
		out.append(pts[0])
	return out

## A round-sided body from a half-profile [[half width, y], ...] top to bottom.
static func _lathe(profile: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in profile:
		pts.append(Vector2(0.5 + p[0], p[1]))
	for i in range(profile.size() - 1, -1, -1):
		pts.append(Vector2(0.5 - profile[i][0], profile[i][1]))
	return pts

static func _ellipse(cx: float, cy: float, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts

static func _poly(list: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in list:
		pts.append(Vector2(p[0], p[1]))
	return pts

static func _build() -> void:
	var base := _lathe([[0.27, 0.79], [0.29, 0.83], [0.34, 0.86], [0.35, 0.93]])
	var base_line := [Vector2(0.17, 0.86), Vector2(0.83, 0.86)]
	# Pawn: a ball on a flared stem.
	_shapes[PAWN] = [
		{"pts": _lathe([[0.06, 0.38], [0.15, 0.43], [0.15, 0.47], [0.08, 0.49], [0.10, 0.60], [0.16, 0.71], [0.25, 0.78], [0.29, 0.80]])},
		{"pts": _ellipse(0.5, 0.29, 0.12, 0.12)},
		{"pts": base},
	]
	_details[PAWN] = [base_line, [Vector2(0.36, 0.45), Vector2(0.64, 0.45)]]
	# Rook: a tower with three merlons.
	_shapes[ROOK] = [
		{"pts": _poly([[0.25, 0.12], [0.35, 0.12], [0.35, 0.19], [0.45, 0.19], [0.45, 0.12], [0.55, 0.12],
			[0.55, 0.19], [0.65, 0.19], [0.65, 0.12], [0.75, 0.12], [0.75, 0.30], [0.25, 0.30]])},
		{"pts": _lathe([[0.22, 0.29], [0.17, 0.35], [0.17, 0.66], [0.21, 0.72], [0.28, 0.78], [0.29, 0.81]])},
		{"pts": base},
	]
	_details[ROOK] = [base_line, [Vector2(0.27, 0.30), Vector2(0.73, 0.30)], [Vector2(0.33, 0.35), Vector2(0.67, 0.35)]]
	# Bishop: a mitre with a slit and a small ball on top.
	_shapes[BISHOP] = [
		{"pts": _lathe([[0.08, 0.45], [0.17, 0.47], [0.17, 0.51], [0.09, 0.53], [0.10, 0.62], [0.16, 0.72], [0.25, 0.78], [0.29, 0.81]])},
		{"pts": _poly([[0.5, 0.13], [0.58, 0.20], [0.63, 0.29], [0.63, 0.37], [0.58, 0.44], [0.42, 0.44], [0.37, 0.37], [0.37, 0.29], [0.42, 0.20]])},
		{"pts": _ellipse(0.5, 0.11, 0.045, 0.045, 12)},
		{"pts": base},
	]
	_details[BISHOP] = [base_line, [Vector2(0.55, 0.23), Vector2(0.47, 0.34)], [Vector2(0.36, 0.49), Vector2(0.64, 0.49)]]
	# Queen: a crown of five points with balls, on a tall body.
	var body := _lathe([[0.13, 0.35], [0.11, 0.40], [0.18, 0.43], [0.18, 0.47], [0.10, 0.49], [0.11, 0.60], [0.16, 0.71], [0.26, 0.78], [0.30, 0.81]])
	var crown := _poly([[0.35, 0.38], [0.22, 0.19], [0.34, 0.28], [0.37, 0.14], [0.44, 0.27], [0.5, 0.12],
		[0.56, 0.27], [0.63, 0.14], [0.66, 0.28], [0.78, 0.19], [0.65, 0.38]])
	_shapes[QUEEN] = [{"pts": body}, {"pts": crown}, {"pts": base}]
	for p in [[0.22, 0.18], [0.37, 0.13], [0.5, 0.11], [0.63, 0.13], [0.78, 0.18]]:
		_shapes[QUEEN].append({"pts": _ellipse(p[0], p[1], 0.04, 0.04, 12)})
	_details[QUEEN] = [base_line, [Vector2(0.33, 0.45), Vector2(0.67, 0.45)], [Vector2(0.36, 0.36), Vector2(0.64, 0.36)]]
	# King: a cross over a flared cap, on the same body.
	_shapes[KING] = [
		{"pts": body},
		{"pts": _poly([[0.33, 0.22], [0.67, 0.22], [0.63, 0.38], [0.37, 0.38]])},
		{"pts": _ellipse(0.5, 0.23, 0.17, 0.05, 18)},
		{"pts": _poly([[0.46, 0.03], [0.54, 0.03], [0.54, 0.08], [0.59, 0.08], [0.59, 0.14], [0.54, 0.14],
			[0.54, 0.20], [0.46, 0.20], [0.46, 0.14], [0.41, 0.14], [0.41, 0.08], [0.46, 0.08]])},
		{"pts": base},
	]
	_details[KING] = [base_line, [Vector2(0.33, 0.45), Vector2(0.67, 0.45)], [Vector2(0.36, 0.37), Vector2(0.64, 0.37)]]
	# Knight: a horse's head looking left, on a pedestal.
	_shapes[KNIGHT] = [
		{"pts": _poly([[0.70, 0.80], [0.73, 0.60], [0.73, 0.45], [0.69, 0.31], [0.61, 0.20], [0.54, 0.15],
			[0.51, 0.07], [0.46, 0.14], [0.39, 0.17], [0.29, 0.28], [0.19, 0.42], [0.16, 0.49], [0.20, 0.55],
			[0.28, 0.56], [0.36, 0.51], [0.43, 0.51], [0.36, 0.64], [0.31, 0.80]])},
		{"pts": base},
	]
	_details[KNIGHT] = [base_line, [Vector2(0.63, 0.23), Vector2(0.70, 0.42)], [Vector2(0.20, 0.49), Vector2(0.23, 0.50)]]
