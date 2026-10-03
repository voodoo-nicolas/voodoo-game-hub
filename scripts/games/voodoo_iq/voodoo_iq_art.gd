extends RefCounted

## Voodoo IQ drawing: ports of the prototype's SVG drawings (docs/voodoo-iq-prototype.html)
## to CanvasItem draw calls -- matrix cells, isometric cube stacks, polyominoes, creatures,
## faces, section icons, the brain map and the bell curve. Every function draws in the
## prototype's own SVG coordinates: begin() maps an SVG viewBox onto a rect (like the
## browser's default "xMidYMid meet"), so the numbers below are the prototype's numbers.
## Paths given as SVG path data go through parse_path().

const T = preload("res://scripts/games/voodoo_iq/voodoo_iq_text.gd")

const INK := Color("#05050A")
const DARK := Color("#1A1A27")

## A Control that draws itself with `paint.call(self, size)`.
class Canvas extends Control:
	var paint: Callable
	func _draw() -> void:
		if paint.is_valid():
			paint.call(self, size)

static func canvas(paint: Callable, min_size: Vector2) -> Canvas:
	var c := Canvas.new()
	c.paint = paint
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = true  # an SVG viewBox crops (the eyes-only face relies on it)
	return c

# ------------------------------------------------------------------ viewBox

## Map the SVG viewBox `vb` into `rect`, centred, aspect kept. Returns the scale.
static func begin(ci: CanvasItem, vb: Rect2, rect: Rect2) -> float:
	var s := minf(rect.size.x / vb.size.x, rect.size.y / vb.size.y)
	var off := rect.position + (rect.size - vb.size * s) / 2.0 - vb.position * s
	ci.draw_set_transform(off, 0.0, Vector2(s, s))
	return s

static func finish(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func mix(a: Color, b: Color, f: float) -> Color:
	return Color(a.r * f + b.r * (1.0 - f), a.g * f + b.g * (1.0 - f), a.b * f + b.b * (1.0 - f))

# ------------------------------------------------------------------ shapes

static func ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out

static func round_rect_pts(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) / 2.0)
	var out := PackedVector2Array()
	var corners := [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
	for cc in corners:
		for k in 7:
			var a: float = cc[2] + (PI / 2) * k / 6.0
			out.append(Vector2(cc[0] + cos(a) * r, cc[1] + sin(a) * r))
	return out

## Fill a simple polygon; skips (rather than errors on) one that can't be triangulated.
static func fill(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	pts = _clean(pts)
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		# self-intersecting (e.g. a mouth whose curves cross): a union splits it into simple parts
		for part in Geometry2D.merge_polygons(pts, pts):
			if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
				ci.draw_colored_polygon(part, color)
		return
	ci.draw_colored_polygon(pts, color)

static func stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, closed: bool = true, round_caps: bool = false) -> void:
	if pts.size() < 2:
		return
	var line := pts.duplicate()
	if closed and line[0] != line[line.size() - 1]:
		line.append(line[0])
	ci.draw_polyline(line, color, width, true)
	if round_caps and not closed:
		ci.draw_circle(line[0], width / 2.0, color)
		ci.draw_circle(line[line.size() - 1], width / 2.0, color)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, round_caps: bool = true) -> void:
	ci.draw_line(a, b, color, width, true)
	if round_caps:
		ci.draw_circle(a, width / 2.0, color)
		ci.draw_circle(b, width / 2.0, color)

## Neon glow (art standard): the same outline drawn wider and fainter underneath.
static func glow(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, closed: bool = true) -> void:
	stroke(ci, pts, Color(color, 0.10), width * 4.5, closed)
	stroke(ci, pts, Color(color, 0.30), width * 2.3, closed)
	stroke(ci, pts, color, width, closed)

static func _clean(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 1e-6:
			out.append(p)
	if out.size() > 1 and out[0].distance_squared_to(out[out.size() - 1]) < 1e-6:
		out.remove_at(out.size() - 1)
	return out

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, width := 0.0) -> void:
	var font := ThemeDB.fallback_font
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER and width <= 0.0:
		width = 400.0
		x -= 200.0
	ci.draw_string(font, Vector2(x, pos.y), s, align, width, size, color)

# ------------------------------------------------------------------ SVG path data

static var _re: RegEx

## SVG path data -> [{pts: PackedVector2Array, closed: bool}]. Supports M L H V C S Q T A Z
## (absolute and relative); curves are flattened into `seg` points each.
static func parse_path(d: String, seg: int = 12) -> Array:
	if _re == null:
		_re = RegEx.new()
		_re.compile("[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
	var toks: Array = []
	for m in _re.search_all(d):
		toks.append(m.get_string())
	var subs: Array = []
	var cur := PackedVector2Array()
	var p := Vector2.ZERO
	var start := Vector2.ZERO
	var ctrl := Vector2.ZERO
	var prev := ""
	var cmd := ""
	var i := 0
	while i < toks.size():
		var tk: String = toks[i]
		if tk.length() == 1 and "MmLlHhVvCcSsQqTtAaZz".contains(tk):
			cmd = tk
			i += 1
			if cmd == "Z" or cmd == "z":
				if cur.size() > 1:
					subs.append({"pts": cur, "closed": true})
				cur = PackedVector2Array()
				p = start
				prev = "Z"
				continue
		if cmd == "" or i >= toks.size():
			break
		if cur.is_empty():
			cur.append(p)
		var rel := cmd == cmd.to_lower()
		var o := p if rel else Vector2.ZERO
		match cmd.to_upper():
			"M":
				var q := Vector2(float(toks[i]), float(toks[i + 1])) + o
				i += 2
				if cur.size() > 1:
					subs.append({"pts": cur, "closed": false})
				cur = PackedVector2Array([q])
				p = q
				start = q
				cmd = "l" if rel else "L"
			"L":
				p = Vector2(float(toks[i]), float(toks[i + 1])) + o
				i += 2
				cur.append(p)
			"H":
				p = Vector2(float(toks[i]) + (p.x if rel else 0.0), p.y)
				i += 1
				cur.append(p)
			"V":
				p = Vector2(p.x, float(toks[i]) + (p.y if rel else 0.0))
				i += 1
				cur.append(p)
			"C", "S":
				var c1: Vector2
				if cmd.to_upper() == "C":
					c1 = Vector2(float(toks[i]), float(toks[i + 1])) + o
					i += 2
				else:
					c1 = p * 2.0 - ctrl if prev == "C" or prev == "S" else p
				var c2 := Vector2(float(toks[i]), float(toks[i + 1])) + o
				var e := Vector2(float(toks[i + 2]), float(toks[i + 3])) + o
				i += 4
				for k in range(1, seg + 1):
					var t := float(k) / seg
					var u := 1.0 - t
					cur.append(p * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + e * t * t * t)
				ctrl = c2
				p = e
			"Q", "T":
				var c: Vector2
				if cmd.to_upper() == "Q":
					c = Vector2(float(toks[i]), float(toks[i + 1])) + o
					i += 2
				else:
					c = p * 2.0 - ctrl if prev == "Q" or prev == "T" else p
				var e := Vector2(float(toks[i]), float(toks[i + 1])) + o
				i += 2
				for k in range(1, seg + 1):
					var t := float(k) / seg
					var u := 1.0 - t
					cur.append(p * u * u + c * 2.0 * u * t + e * t * t)
				ctrl = c
				p = e
			"A":
				var e := Vector2(float(toks[i + 5]), float(toks[i + 6])) + o
				cur.append_array(_arc(p, float(toks[i]), float(toks[i + 1]), float(toks[i + 2]), toks[i + 3] != "0", toks[i + 4] != "0", e, seg * 2))
				i += 7
				p = e
			_:
				i += 1
		prev = cmd.to_upper()
	if cur.size() > 1:
		subs.append({"pts": cur, "closed": false})
	return subs

static func _arc(p0: Vector2, rx: float, ry: float, phi_deg: float, large: bool, sweep: bool, p1: Vector2, n: int) -> PackedVector2Array:
	rx = absf(rx)
	ry = absf(ry)
	if rx == 0.0 or ry == 0.0 or p0 == p1:
		return PackedVector2Array([p1])
	var phi := deg_to_rad(phi_deg)
	var cp := cos(phi)
	var sp := sin(phi)
	var dx2 := (p0.x - p1.x) / 2.0
	var dy2 := (p0.y - p1.y) / 2.0
	var x1p := cp * dx2 + sp * dy2
	var y1p := -sp * dx2 + cp * dy2
	var lam := x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
	if lam > 1.0:
		rx *= sqrt(lam)
		ry *= sqrt(lam)
	var num := rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
	var den := rx * rx * y1p * y1p + ry * ry * x1p * x1p
	var coef := sqrt(maxf(0.0, num / den)) * (-1.0 if large == sweep else 1.0)
	var cxp := coef * rx * y1p / ry
	var cyp := -coef * ry * x1p / rx
	var cx := cp * cxp - sp * cyp + (p0.x + p1.x) / 2.0
	var cy := sp * cxp + cp * cyp + (p0.y + p1.y) / 2.0
	var u := Vector2((x1p - cxp) / rx, (y1p - cyp) / ry)
	var v := Vector2((-x1p - cxp) / rx, (-y1p - cyp) / ry)
	var th1 := atan2(u.y, u.x)
	var dth := atan2(u.x * v.y - u.y * v.x, u.dot(v))
	if not sweep and dth > 0:
		dth -= TAU
	elif sweep and dth < 0:
		dth += TAU
	var out := PackedVector2Array()
	for k in range(1, n + 1):
		var t := th1 + dth * k / n
		out.append(Vector2(cx + rx * cos(t) * cp - ry * sin(t) * sp, cy + rx * cos(t) * sp + ry * sin(t) * cp))
	return out

## Fill and/or stroke SVG path data (pass a transparent color to skip either).
static func path(ci: CanvasItem, d: String, fill_color: Color, stroke_color: Color, width: float, round_caps: bool = false) -> void:
	for sub in parse_path(d):
		if sub.closed and fill_color.a > 0.0:
			fill(ci, sub.pts, fill_color)
		if stroke_color.a > 0.0 and width > 0.0:
			stroke(ci, sub.pts, stroke_color, width, sub.closed, round_caps)

# ------------------------------------------------------------------ section icons (24x24)

static func icon(ci: CanvasItem, sec: String, rect: Rect2, color: Color = Color(0, 0, 0, 0)) -> void:
	var d: String = str(T.data().get("SEC_ICON", {}).get(sec, ""))
	if d == "":
		return
	begin(ci, Rect2(0, 0, 24, 24), rect)
	path(ci, d, Color(0, 0, 0, 0), color if color.a > 0 else T.sec_color(sec), 2.0, true)
	finish(ci)

# ------------------------------------------------------------------ LOG: matrix cells (viewBox 0 0 100 100)

static func _mx_shape_pts(kind: String, cx: float, cy: float, r: float) -> PackedVector2Array:
	match kind:
		"circle":
			return ellipse_pts(Vector2(cx, cy), r, r, 36)
		"square":
			return PackedVector2Array([Vector2(cx - r * .86, cy - r * .86), Vector2(cx + r * .86, cy - r * .86), Vector2(cx + r * .86, cy + r * .86), Vector2(cx - r * .86, cy + r * .86)])
		"triangle":
			return PackedVector2Array([Vector2(cx, cy - r * 1.05), Vector2(cx + r * 1.05, cy + r * .8), Vector2(cx - r * 1.05, cy + r * .8)])
		"diamond":
			return PackedVector2Array([Vector2(cx, cy - r * 1.1), Vector2(cx + r * .85, cy), Vector2(cx, cy + r * 1.1), Vector2(cx - r * .85, cy)])
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(Vector2(cx + r * cos(PI / 3 * i), cy + r * sin(PI / 3 * i)))
	return hex

static func matrix_cell(ci: CanvasItem, cell: Dictionary, rect: Rect2, fg: Color = Color.WHITE) -> void:
	begin(ci, Rect2(0, 0, 100, 100), rect)
	var n := int(cell.count) + 1
	var slots := [[50, 50]] if n == 1 else ([[28, 50], [72, 50]] if n == 2 else [[50, 27], [27, 72], [73, 72]])
	var rr: float = [10.5, 15.0, 19.5][int(cell.size)]
	var shapes: Array = T.data().get("MX_SHAPES", [])
	for s in slots:
		var pts := _mx_shape_pts(str(shapes[int(cell.shape)]), s[0], s[1], rr)
		match int(cell.fill):
			0:
				stroke(ci, pts, fg, 3.2)
			1:
				fill(ci, pts, fg)
				stroke(ci, pts, fg, 2.0)
			_:
				_hatch(ci, pts, fg)
				stroke(ci, pts, fg, 3.0)
	finish(ci)

## The prototype's 45-degree stripe pattern (3 wide, every 7) clipped to the shape.
static func _hatch(ci: CanvasItem, pts: PackedVector2Array, fg: Color) -> void:
	var rot := Transform2D(PI / 4, Vector2.ZERO)
	for k in range(-30, 30):
		var x := 1.5 + 7.0 * k
		var seg := PackedVector2Array([rot * Vector2(x, -200), rot * Vector2(x, 200)])
		for piece in Geometry2D.intersect_polyline_with_polygon(seg, pts):
			if piece.size() >= 2:
				ci.draw_line(piece[0], piece[1], fg, 3.0, true)

# ------------------------------------------------------------------ SPA: top view of a cube stack

static func _tv_col(i: int) -> Color:
	return Color(str(T.data().get("TV_COL", [])[i]))

static func _tv_side(i: int, k: int) -> Color:
	return Color(str(T.data().get("TV_SIDE", [])[i][k]))

static func _tv_symbol(ci: CanvasItem, k: int, cx: float, cy: float, r: float, col: Color) -> void:
	match k:
		0:
			ci.draw_circle(Vector2(cx, cy), r * .9, col)
		1:
			fill(ci, PackedVector2Array([Vector2(cx, cy - r), Vector2(cx + r, cy + r * .8), Vector2(cx - r, cy + r * .8)]), col)
		2:
			ci.draw_rect(Rect2(cx - r * .8, cy - r * .8, r * 1.6, r * 1.6), col)
		_:
			ci.draw_line(Vector2(cx - r, cy), Vector2(cx + r, cy), col, r * .55)
			ci.draw_line(Vector2(cx, cy - r), Vector2(cx, cy + r), col, r * .55)

static func _tv_proj(n: int, s: float) -> Callable:
	var cw := s * 0.866
	var ch := s * 0.5
	var ox := n * cw + 10
	var oy := 10 + 4 * s
	return func(x: float, y: float, z: float) -> Vector2: return Vector2(ox + (x - y) * cw, oy + (x + y) * ch - z * s)

## Isometric view of the stack, with the thick white front edge (x = n).
static func tv_iso(ci: CanvasItem, stack: Array, rect: Rect2) -> void:
	var n := stack.size()
	var s := 34.0 if n <= 3 else (28.0 if n == 4 else 23.0)
	var P := _tv_proj(n, s)
	var min_y := INF
	for i in n:
		for j in n:
			min_y = minf(min_y, P.call(i, j, stack[i][j].size()).y)
	var x0: float = P.call(0, n, 0).x - 8
	var x1: float = P.call(n, 0, 0).x + 8
	var y0 := min_y - 8
	var y1: float = P.call(n, n, 0).y + 10
	begin(ci, Rect2(round(x0), round(y0), round(x1 - x0), round(y1 - y0)), rect)
	for i in n:
		for j in n:
			var tile := PackedVector2Array([P.call(i, j, 0), P.call(i + 1, j, 0), P.call(i + 1, j + 1, 0), P.call(i, j + 1, 0)])
			fill(ci, tile, Color("#2A2A3E"))
			stroke(ci, tile, Color("#55557A"), 1.6)
	line(ci, P.call(n, 0, 0), P.call(n, n, 0), Color.WHITE, 6.0)
	var cubes: Array = []
	for i in n:
		for j in n:
			var col_stack: Array = stack[i][j]
			for z in col_stack.size():
				cubes.append([i, j, z, int(col_stack[z]), z == col_stack.size() - 1])
	cubes.sort_custom(func(a, b): return (a[0] + a[1] < b[0] + b[1]) or (a[0] + a[1] == b[0] + b[1] and a[2] < b[2]))
	for c in cubes:
		var i: int = c[0]
		var j: int = c[1]
		var z: int = c[2]
		var col: int = c[3]
		var faces := [
			[PackedVector2Array([P.call(i, j + 1, z), P.call(i + 1, j + 1, z), P.call(i + 1, j + 1, z + 1), P.call(i, j + 1, z + 1)]), _tv_side(col, 0)],
			[PackedVector2Array([P.call(i + 1, j, z), P.call(i + 1, j + 1, z), P.call(i + 1, j + 1, z + 1), P.call(i + 1, j, z + 1)]), _tv_side(col, 1)],
			[PackedVector2Array([P.call(i, j, z + 1), P.call(i + 1, j, z + 1), P.call(i + 1, j + 1, z + 1), P.call(i, j + 1, z + 1)]), _tv_col(col)],
		]
		for f in faces:
			fill(ci, f[0], f[1])
			stroke(ci, f[0], INK, 1.6)
		if c[4]:
			var ctr: Vector2 = P.call(i + .5, j + .5, z + 1)
			_tv_symbol(ci, col, ctr.x, ctr.y, s * .2, INK)
	finish(ci)

## One answer option: the top colors as a grid, front edge at the bottom.
static func tv_grid(ci: CanvasItem, grid: Array, rect: Rect2) -> void:
	begin(ci, Rect2(-2, -2, 104, 112), rect)
	var n := grid.size()
	var c := 100.0 / n
	for i in n:
		for j in n:
			var v := int(grid[i][j])
			var r := Rect2(j * c, i * c, c, c)
			ci.draw_rect(r, Color("#1A1A27") if v < 0 else _tv_col(v))
			ci.draw_rect(r, INK, false, 1.5)
			if v >= 0:
				_tv_symbol(ci, v, j * c + c / 2, i * c + c / 2, c * .2, INK)
	line(ci, Vector2(0, 104), Vector2(100, 104), Color.WHITE, 5.0)
	finish(ci)

# ------------------------------------------------------------------ SPA: polyominoes

static func poly(ci: CanvasItem, cells: Array, rect: Rect2, color: Color) -> void:
	var w := 0
	var h := 0
	for c in cells:
		w = maxi(w, int(c[0]) + 1)
		h = maxi(h, int(c[1]) + 1)
	var m := maxi(w, h)
	begin(ci, Rect2(-0.2, -0.2, m + .4, m + .4), rect)
	var ox := (m - w) / 2.0
	var oy := (m - h) / 2.0
	for c in cells:
		var r := Rect2(float(c[0]) + ox, float(c[1]) + oy, 1, 1)
		ci.draw_rect(r, color)
		ci.draw_rect(r, INK, false, .09)
	finish(ci)

# ------------------------------------------------------------------ NAT: creatures (viewBox 0 0 120 120)

static func creature(ci: CanvasItem, x: Array, rect: Rect2) -> void:
	begin(ci, Rect2(0, 0, 120, 120), rect)
	fill(ci, round_rect_pts(0, 0, 120, 120, 10), Color("#E9E9F2"))  # prototype .creature card
	var b := int(x[0])
	var col := Color(str(T.data().get("NAT_COL", [])[int(x[1])]))
	var body := ellipse_pts(Vector2(60, 58), 34, 30) if b == 0 else (round_rect_pts(38, 22, 44, 66, 20) if b == 1 else round_rect_pts(26, 32, 68, 52, 6))
	var bottom := 82.0 if b == 2 else 86.0
	var nl: int = [2, 4, 6][int(x[3])]
	for i in nl:
		var lx := 60 + (i - (nl - 1) / 2.0) * (22.0 if nl == 2 else (14.0 if nl == 4 else 10.0))
		line(ci, Vector2(lx, bottom - 4), Vector2(lx + (-4.0 if i < nl / 2.0 else 4.0), 108), INK, 4.0)
	if int(x[6]):
		path(ci, "M80 70 q22 4 18 -14 q-2 -8 -9 -4" if b == 1 else "M92 62 q20 6 16 -12 q-2 -8 -9 -4", Color(0, 0, 0, 0), INK, 4.0, true)
	var top_y := 30.0 if b == 0 else (24.0 if b == 1 else 34.0)
	if int(x[5]):
		for s in [-1, 1]:
			line(ci, Vector2(60 + s * 8, top_y + 2), Vector2(60 + s * 18, top_y - 16), INK, 3.5)
			ci.draw_circle(Vector2(60 + s * 18, top_y - 18), 4.5, INK)
	fill(ci, body, col)
	if int(x[2]) == 1:
		for pt in [[44, 74], [74, 76], [58, 84], [38, 52], [84, 50]]:
			for piece in Geometry2D.intersect_polygons(ellipse_pts(Vector2(pt[0], pt[1]), 4.5, 4.5, 16), body):
				fill(ci, piece, INK)
	elif int(x[2]) == 2:
		for k in 6:
			var seg := PackedVector2Array([Vector2(14 + k * 18, 10), Vector2(k * 18 - 10, 110)])
			for piece in Geometry2D.intersect_polyline_with_polygon(seg, body):
				ci.draw_line(piece[0], piece[1], INK, 4.5, true)
	stroke(ci, body, INK, 3.5)
	var ne: int = [1, 2, 3][int(x[4])]
	var ey := 44.0 if b == 1 else 52.0
	for i in ne:
		var ex := 60 + (i - (ne - 1) / 2.0) * 15
		ci.draw_circle(Vector2(ex, ey), 7.5, Color.WHITE)
		stroke(ci, ellipse_pts(Vector2(ex, ey), 7.5, 7.5, 24), INK, 2.5)
		ci.draw_circle(Vector2(ex + 1, ey + 1), 3.2, INK)
	finish(ci)

# ------------------------------------------------------------------ INT: faces (viewBox 0 0 200 230; eyes only: 20 52 160 62)

static func face(ci: CanvasItem, p: Dictionary, id: Dictionary, rect: Rect2, eyes_only: bool) -> void:
	ci.draw_rect(rect, Color("#2C2C40"))  # prototype .facewrap
	begin(ci, Rect2(20, 52, 160, 62) if eyes_only else Rect2(0, 0, 200, 230), rect)
	var ink := Color("#14100C")
	var skin := Color(str(T.data().get("SKIN", [])[int(id.skin)]))
	var hair := Color(str(T.data().get("HAIR", [])[int(id.hair)]))
	var fw := 72.0 + float(id.w) * 6.0
	var style := int(id.style)
	var hair_d := ""
	if style == 0:
		hair_d = "M%s 120 Q%s 18 100 16 Q%s 18 %s 120 Z" % [100 - fw - 6, 100 - fw - 10, 100 + fw + 10, 100 + fw + 6]
	elif style == 1:
		hair_d = "M%s 90 Q100 -4 %s 90 Q%s 40 100 40 Q%s 40 %s 90 Z" % [100 - fw - 4, 100 + fw + 4, 100 + fw - 10, 100 - fw + 10, 100 - fw - 4]
	else:
		hair_d = "M%s 74 Q100 8 %s 74 L%s 64 Q100 36 %s 64 Z" % [100 - fw, 100 + fw, 100 + fw - 8, 100 - fw + 8]
	path(ci, hair_d, hair, ink, 3.0)
	var head := ellipse_pts(Vector2(100, 118), fw, 98, 64)
	fill(ci, head, skin)
	stroke(ci, head, ink, 3.5)
	if style == 2:
		path(ci, "M%s 70 Q100 30 %s 70 Q100 52 %s 70 Z" % [100 - fw + 4, 100 + fw - 4, 100 - fw + 4], hair, ink, 3.0)
	var g := func(k: String) -> float: return float(p.get(k, 0.0))
	var eye_y := 92.0
	var ex := 30.0 + float(id.sp) * 3.0
	for s in [-1, 1]:
		var cx: float = 100 + s * ex
		var open := clampf(9 + g.call("ul") * 7 - g.call("lt") * 4 - g.call("cr") * 3, 2.5, 18)
		var eye := ellipse_pts(Vector2(cx, eye_y), 15, open, 32)
		fill(ci, eye, Color.WHITE)
		stroke(ci, eye, ink, 3.0)
		ci.draw_circle(Vector2(cx, eye_y + 1), minf(6.5, open), ink)
		if g.call("cr") > .3:
			path(ci, "M%s %s q14 %s 28 0" % [cx - 14, eye_y + open + 6, -4 - g.call("cr") * 4], Color(0, 0, 0, 0), ink, 2.2)
		var base := eye_y - 22
		var inner: float = base - g.call("bi") * 12 + g.call("bl") * 10
		var outer: float = base - g.call("bo") * 10 - g.call("bi") * 2 + g.call("bl") * 2
		var ix: float = cx - s * 14
		var ox: float = cx + s * 16
		path(ci, "M%s %s Q%s %s %s %s" % [ix, inner, cx, minf(inner, outer) - 6 + g.call("bl") * 4, ox, outer], Color(0, 0, 0, 0), ink, 6.0, true)
	if g.call("bl") > .5:
		line(ci, Vector2(96, 78), Vector2(96, 86), ink, 2.0, false)
		line(ci, Vector2(104, 78), Vector2(104, 86), ink, 2.0, false)
	if not eyes_only:
		path(ci, "M100 100 L94 %s Q100 %s 108 %s" % [140 - g.call("nw") * 3, 146 - g.call("nw") * 2, 140 - g.call("nw") * 3], Color(0, 0, 0, 0), ink, 3.0)
		if g.call("nw") > .35:
			for seg in [[86, 112, 94, 116], [114, 112, 106, 116], [88, 120, 95, 123], [112, 120, 105, 123]]:
				line(ci, Vector2(seg[0], seg[1]), Vector2(seg[2], seg[3]), ink, 2.2, false)
		var my: float = 172 - g.call("ur") * 6
		var mw: float = 30 + g.call("ls") * 10 + g.call("cr") * 4 - g.call("lp") * 6
		var cy: float = my - g.call("lc") * 14
		var mopen := clampf(g.call("mo") * 20 + g.call("ur") * 6, 0, 26)
		var curve: float = my + g.call("lc") * 10
		if mopen > 3:
			path(ci, "M%s %s Q100 %s %s %s Q100 %s %s %s Z" % [100 - mw, cy, curve - 4 - g.call("ur") * 6, 100 + mw, cy, curve + mopen * 1.3, 100 - mw, cy], Color("#3A0E0E"), ink, 3.5)
		else:
			path(ci, "M%s %s Q100 %s %s %s" % [100 - mw, cy, curve, 100 + mw, cy], Color(0, 0, 0, 0), ink, 4 + g.call("lp") * 2.5, true)
	finish(ci)

# ------------------------------------------------------------------ brain map (viewBox 40 20 560 440)

const BRAIN_VB := Rect2(40, 20, 560, 440)

static var _brain_cache: Dictionary = {}

## Region polygons clipped to the brain outline (as the prototype's clip-path does).
static func _brain_shapes() -> Dictionary:
	if not _brain_cache.is_empty():
		return _brain_cache
	var B: Dictionary = T.data().get("BRAIN", {})
	var outline: PackedVector2Array = _clean(parse_path(str(B.outline))[0].pts)
	var regions: Array = []
	for r in B.get("regions", []):
		var pieces: Array = []
		for sub in parse_path(str(r[1])):
			for piece in Geometry2D.intersect_polygons(_clean(sub.pts), outline):
				pieces.append(piece)
		regions.append([str(r[0]), pieces])
	_brain_cache = {
		"outline": outline,
		"cerebellum": _clean(parse_path(str(B.cerebellum))[0].pts),
		"stem": _clean(parse_path(str(B.stem))[0].pts),
		"regions": regions,
	}
	return _brain_cache

static func _brain_alpha(sec: String, selected: String) -> float:
	if selected == "":
		return 0.62
	return 0.95 if selected == sec else (0.7 if selected == "ALL" else 0.28)

static func brain(ci: CanvasItem, rect: Rect2, selected: String) -> void:
	var B: Dictionary = T.data().get("BRAIN", {})
	var shp := _brain_shapes()
	var secs: Array = T.secs()
	begin(ci, BRAIN_VB, rect)
	fill(ci, shp.stem, Color("#2A2A3E"))
	stroke(ci, shp.stem, Color("#8A8AB0"), 3.0)
	fill(ci, shp.outline, DARK)
	for r in shp.regions:
		for piece in r[1]:
			fill(ci, piece, mix(T.sec_color(r[0]), DARK, _brain_alpha(r[0], selected)))
	# procedural folds for texture
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 46:
		var x := rng.randi_range(80, 560)
		var y := rng.randi_range(50, 340)
		var a := rng.randf() * PI
		var l := rng.randi_range(26, 60)
		var x2 := x + cos(a) * l
		var y2 := y + sin(a) * l
		var d := "M%s %s Q%s %s %s %s" % [x, y, (x + x2) / 2 + rng.randi_range(-18, 18), (y + y2) / 2 + rng.randi_range(-18, 18), x2, y2]
		for piece in Geometry2D.intersect_polyline_with_polygon(parse_path(d)[0].pts, shp.outline):
			stroke(ci, piece, Color(INK, .32), 3.0, false)
	for d in B.get("sulci", []):
		for piece in Geometry2D.intersect_polyline_with_polygon(parse_path(str(d))[0].pts, shp.outline):
			stroke(ci, piece, INK, 6.0, false, true)
	fill(ci, shp.cerebellum, mix(T.sec_color("KIN"), DARK, _brain_alpha("KIN", selected)))
	stroke(ci, shp.cerebellum, INK, 2.0)
	for i in 6:
		path(ci, "M%s %s Q490 %s %s %s" % [446 + i * 2, 330 + i * 9, 322 + i * 9, 536 - i * 3, 338 + i * 7], Color(0, 0, 0, 0), Color(INK, .4), 2.5)
	glow(ci, shp.outline, Color.WHITE, 4.0)
	# existential: a network, not a place
	var nodes: Array = B.get("exi", [])
	var exi := T.sec_color("EXI")
	var on := selected == "EXI"
	for i in nodes.size():
		var j := (i + 1) % nodes.size()
		ci.draw_dashed_line(Vector2(nodes[i][0], nodes[i][1]), Vector2(nodes[j][0], nodes[j][1]), Color(exi, 1.0 if on else .55), 4.0 if on else 2.5, 7.0, true)
	for nd in nodes:
		ci.draw_circle(Vector2(nd[0], nd[1]), 11.0 if on else 8.0, exi)
		stroke(ci, ellipse_pts(Vector2(nd[0], nd[1]), 11.0 if on else 8.0, 11.0 if on else 8.0, 20), INK, 3.0)
	# number badges so regions are identifiable without color
	for sec in secs:
		var at: Array = B.labelAt[sec]
		var c := Vector2(at[0], at[1])
		ci.draw_circle(c, 17, INK)
		stroke(ci, ellipse_pts(c, 17, 17, 28), T.sec_color(sec), 3.0)
		text(ci, c + Vector2(0, 6), str(secs.find(sec) + 1), 17, Color.WHITE)
	finish(ci)

## The section under `pos` (local to the brain canvas of size `size`), or "".
static func brain_hit(pos: Vector2, size: Vector2) -> String:
	var vb := BRAIN_VB
	var s := minf(size.x / vb.size.x, size.y / vb.size.y)
	var off := (size - vb.size * s) / 2.0 - vb.position * s
	var q := (pos - off) / s
	var B: Dictionary = T.data().get("BRAIN", {})
	for sec in T.secs():
		var at: Array = B.labelAt[sec]
		if q.distance_to(Vector2(at[0], at[1])) <= 22:
			return sec
	for nd in B.get("exi", []):
		if q.distance_to(Vector2(nd[0], nd[1])) <= 16:
			return "EXI"
	var shp := _brain_shapes()
	if Geometry2D.is_point_in_polygon(q, shp.cerebellum):
		return "KIN"
	var regions: Array = shp.regions
	for k in range(regions.size() - 1, -1, -1):
		for piece in regions[k][1]:
			if Geometry2D.is_point_in_polygon(q, piece):
				return regions[k][0]
	return ""

# ------------------------------------------------------------------ bell curve (viewBox 0 0 640 230)

static func bell(ci: CanvasItem, rect: Rect2, theta: float, se: float, accent: Color, fg: Color, fg2: Color) -> void:
	begin(ci, Rect2(0, 0, 640, 230), rect)
	var x0 := 30.0
	var x1 := 610.0
	var base := 170.0
	var X := func(v: float) -> float: return x0 + (v - 55.0) / 90.0 * (x1 - x0)
	var pdf := func(z: float) -> float: return exp(-z * z / 2.0)
	var curve := PackedVector2Array()
	for v in range(55, 146):
		curve.append(Vector2(X.call(v), base - pdf.call((v - 100) / 15.0) * 140))
	var lo := clampf(T.iq(theta - 1.96 * se), 55, 145)
	var hi := clampf(T.iq(theta + 1.96 * se), 55, 145)
	ci.draw_rect(Rect2(X.call(lo), 18, maxf(2, X.call(hi) - X.call(lo)), base - 18), Color(accent, .18))
	var area := curve.duplicate()
	area.append(Vector2(X.call(145), base))
	area.append(Vector2(X.call(55), base))
	fill(ci, area, Color(fg, .06))
	glow(ci, curve, fg, 3.0, false)
	ci.draw_line(Vector2(x0, base), Vector2(x1, base), fg2, 2.0)
	for v in [55, 70, 85, 100, 115, 130, 145]:
		ci.draw_line(Vector2(X.call(v), base), Vector2(X.call(v), base + 8), fg2, 2.0)
		text(ci, Vector2(X.call(v), base + 28), str(v), 18, fg)
	for z in [[55, 70, "z_sigbelow"], [70, 85, "z_below"], [85, 115, "z_avg"], [115, 130, "z_above"], [130, 145, "z_sigabove"]]:
		text(ci, Vector2((X.call(z[0]) + X.call(z[1])) / 2, base + 52), T.t(z[2]), 13, fg2)
	var px: float = X.call(clampf(T.iq(theta), 55, 145))
	var py: float = base - pdf.call(clampf(theta, -3, 3)) * 140
	ci.draw_line(Vector2(px, py), Vector2(px, base), accent, 3.0)
	ci.draw_circle(Vector2(px, py), 13, Color("#07070C"))
	ci.draw_circle(Vector2(px, py), 10, accent)
	finish(ci)
