extends RefCounted

## Evolution: all creature drawing, in code (no image assets). Every function
## draws into any CanvasItem `ci` in local space: +x is "forward", so the body
## is rotated by `heading` with draw_set_transform and the transform is reset
## at the end.

const HALO := {
	"prey": Color("7dff3a"), "hunter": Color("ff4f9a"), "equal": Color("d8e4ff"),
	"toxic": Color("d7ff2a"), "rare": Color("ffd23f"),
}

static func _reset(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A wobbling closed outline around the origin (local space).
static func _blob(r: float, sides: int, t: float, sd: float, amp: float = 0.035) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var ang := TAU * float(i) / float(sides)
		var k := 1.0 + amp * sin(ang * 3.0 + t * 2.2 + sd) + amp * 0.7 * sin(ang * 5.0 - t * 3.1 + sd * 1.7)
		pts.append(Vector2.RIGHT.rotated(ang) * r * k)
	return pts

static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c

# ---------- cheap drawing (2026-10-29) ----------
# In Godot 4.7 every draw_circle / draw_arc / draw_polyline / draw_colored_polygon call costs 60-110 µs (each
# one makes its own GPU buffer), while a texture rect costs 0.5 µs and a draw_multiline ~12 µs. Evolution made
# well over 1,000 such calls a frame (5-15 fps on a weak GPU), so circles are drawn as a white disc texture and
# arcs / polylines as one multiline. Same signatures as the CanvasItem calls, with the canvas item first.
# Antialiased multiline segments overlap at their joints, which shows as bright dots on see-through colours, so
# only solid colours are antialiased.

static var _disc_tex: Array = []    # white discs, 16 / 64 / 256 px (the closest size keeps the edge sharp)

static func _disc_texture(px: float) -> Texture2D:
	if _disc_tex.is_empty():
		for s in [16, 64, 256]:
			var g := Gradient.new()
			g.set_offset(0, 0.0)
			g.set_color(0, Color.WHITE)
			g.set_offset(1, 1.0)
			g.set_color(1, Color(1, 1, 1, 0))
			g.add_point(1.0 - 2.0 / float(s), Color.WHITE)     # solid to one texel from the rim
			var tex := GradientTexture2D.new()
			tex.gradient = g
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(1.0, 0.5)
			tex.width = s
			tex.height = s
			_disc_tex.append(tex)
	if px <= 16.0:
		return _disc_tex[0]
	return _disc_tex[1] if px <= 64.0 else _disc_tex[2]

## A filled circle (like draw_circle).
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r <= 0.0:
		return
	ci.draw_texture_rect(_disc_texture(r * 2.0), Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), false, col)

## An arc outline (like draw_arc: `n` points from angle a0 to a1).
static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, aa: bool = false) -> void:
	if n < 2:
		return
	var segs := PackedVector2Array()
	segs.resize((n - 1) * 2)
	var prev := c + Vector2(cos(a0), sin(a0)) * r
	for i in range(1, n):
		var a := lerpf(a0, a1, float(i) / float(n - 1))
		var p := c + Vector2(cos(a), sin(a)) * r
		segs[(i - 1) * 2] = prev
		segs[(i - 1) * 2 + 1] = p
		prev = p
	ci.draw_multiline(segs, col, w, aa and col.a >= 0.99)

## A line through the points (like draw_polyline).
static func strip(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = -1.0, aa: bool = false) -> void:
	var n := pts.size()
	if n < 2:
		return
	var segs := PackedVector2Array()
	segs.resize((n - 1) * 2)
	for i in range(1, n):
		segs[(i - 1) * 2] = pts[i - 1]
		segs[(i - 1) * 2 + 1] = pts[i]
	ci.draw_multiline(segs, col, w, aa and col.a >= 0.99)

## A soft glow, nothing more: red for something that can eat you, sickly green for poison, gold for a rare one.
## Everything else gets no marking.
static func draw_halo(ci: CanvasItem, c: Vector2, r: float, kind: String, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	match kind:
		"hunter":
			disc(ci, c, r * 2.1, Color(1.0, 0.1, 0.18, 0.05 + 0.02 * pulse))
			disc(ci, c, r * 1.6, Color(1.0, 0.1, 0.18, 0.08 + 0.03 * pulse))
			disc(ci, c, r * 1.25, Color(1.0, 0.15, 0.2, 0.12 + 0.04 * pulse))
		"toxic":
			disc(ci, c, r * 1.6, Color(0.8, 1.0, 0.1, 0.07 + 0.03 * pulse))
		"rare":
			# Rare: a bright golden glow, ripples spreading through the water and sparkles circling it.
			disc(ci, c, r * 2.6, Color(1.0, 0.85, 0.2, 0.05 + 0.03 * pulse))
			disc(ci, c, r * 1.8, Color(1.0, 0.85, 0.2, 0.12 + 0.07 * pulse))
			draw_ripples(ci, c, r, t, 1.0)
			for i in 5:
				var a := t * 1.6 + TAU * float(i) / 5.0
				var p := c + Vector2.RIGHT.rotated(a) * r * (1.45 + 0.12 * sin(t * 5.0 + float(i)))
				var tw := 0.5 + 0.5 * sin(t * 7.0 + float(i) * 2.3)
				disc(ci, p, maxf(r * 0.09, 1.5) * (0.6 + 0.6 * tw), Color(1.0, 0.97, 0.7, 0.55 + 0.45 * tw))

## Rings spreading out from a rare creature, like ripples in the water. `alpha` fades them (the game also
## draws faint ones a little beyond your sight, so you notice something special is near).
static func draw_ripples(ci: CanvasItem, c: Vector2, r: float, t: float, alpha: float) -> void:
	for q in 3:
		var f := fposmod(t * 0.45 + float(q) / 3.0, 1.0)
		var rr := r * (1.3 + 3.2 * f)
		arc(ci, c, rr, 0.0, TAU, 40, Color(1.0, 0.88, 0.4, 0.45 * (1.0 - f) * alpha), maxf(r * 0.06, 2.0), true)

# ---------- other creatures ----------

## Shapes drawn by `_animal` (everything from size 3 on, and the rare creatures).
const ANIMAL_SHAPES := ["fish", "jelly", "squid", "ray", "snake", "octopus", "turtle", "star", "seahorse", "mermaid", "poseidon"]

## One creature of species `sp` (evolution_data.gd). `voodoo`: neon wireframe skin. `lvl`: its own size, which
## decides what the toxic and rare ones (sized relative to you) look like: from size 3 on they are animals,
## never giant bacteria. `detail`: draw cell parts (nucleus, vacuoles ...), only while you are size 1-2.
static func draw_creature(ci: CanvasItem, c: Vector2, r: float, sp: Dictionary, heading: float, t: float, sd: float, voodoo: bool, lvl: int = 1, detail: bool = true) -> void:
	if r < 1.5:
		return
	var col: Color = sp.col
	var shape: String = sp.shape
	var plan: Dictionary = sp.get("fish", {})
	if sp.has("adv") and lvl >= 3:
		shape = sp.adv.shape
		plan = sp.adv.get("fish", {})
	ci.draw_set_transform(c, heading, Vector2.ONE)
	if ANIMAL_SHAPES.has(shape):
		_animal(ci, r, col, shape, plan, t, sd, lvl, voodoo)
		_reset(ci)
		return
	if voodoo:
		_creature_voodoo(ci, r, col, shape, t, sd)
		_reset(ci)
		return
	var feats: Array = sp.get("feats", [])
	_feats_back(ci, r, col, t, sd, feats)
	match shape:
		"blob":
			_amoeba(ci, r, col, t, sd, detail)
		"spiral":
			_spiral(ci, r, col, t, sd)
		"beads":
			_beads(ci, r, col, t, sd, detail)
		"rod":
			_rod(ci, r, col, t, sd, detail)
		"chain":
			_chain(ci, r, col, t, sd)
		"bumpy":
			_bumpy(ci, r, col, t, sd)
		"spiky":
			_spiky(ci, r, col, t, sd, sp.role)
		"corona":
			_corona(ci, r, col, t, sd, detail)
		"worm":
			_worm(ci, r, col, t, sd)
		"tailed":
			_tailed(ci, r, col, t, sd, detail)
		"eyed":
			_eyed(ci, r, col, t, sd, detail)
		"phage":
			_phage(ci, r, col, t, sd)
	_feats_front(ci, r, col, t, sd, feats)
	_reset(ci)

static func _shade(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col.darkened(0.55))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.84)
	ci.draw_colored_polygon(inner, col.darkened(0.12))
	var core := PackedVector2Array()
	for p in pts:
		core.append(p * 0.5 + Vector2(-0.06, -0.08) * pts[0].length())
	ci.draw_colored_polygon(core, col.lightened(0.3))
	var cl := _closed(pts)
	strip(ci, cl, col.lightened(0.35), maxf(pts[0].length() * 0.06, 1.4), true)

static func _beads(ci: CanvasItem, r: float, col: Color, t: float, sd: float, detail: bool = true) -> void:
	var pts := _blob(r, 24, t, sd)
	_shade(ci, pts, col)
	for j in (5 if detail else 0):
		var a := sd + float(j) * 1.3
		disc(ci, Vector2.RIGHT.rotated(a) * r * (0.25 + 0.4 * fmod(float(j) * 0.37, 1.0)), r * 0.09, col.darkened(0.5))
	for i in range(0, 24, 3):
		var d := pts[i].normalized()
		ci.draw_line(pts[i], pts[i] + d.rotated(sin(t * 7.0 + i) * 0.3) * r * 0.2, Color(col, 0.7), maxf(r * 0.03, 1.0), true)

static func _rod(ci: CanvasItem, r: float, col: Color, t: float, sd: float, detail: bool = true) -> void:
	var half := r * 1.35
	var th := r * 0.55
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * float(i) / 9.0
		pts.append(Vector2(half - th, 0) + Vector2(cos(a), sin(a)) * th)
	for i in 10:
		var a2 := PI / 2.0 + PI * float(i) / 9.0
		pts.append(Vector2(-half + th, 0) + Vector2(cos(a2), sin(a2)) * th)
	_shade(ci, pts, col)
	for j in (4 if detail else 0):
		disc(ci, Vector2(lerpf(-half * 0.6, half * 0.6, float(j) / 3.0), sin(sd + float(j) * 2.0) * th * 0.3), th * 0.18, col.darkened(0.5))

static func _chain(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var n := 5
	var br := r * 0.42
	for i in n:
		var f := float(i) / float(n - 1)
		var p := Vector2(lerpf(r * 1.2, -r * 1.2, f), sin(t * 3.0 + f * 4.0 + sd) * r * 0.22)
		var pts := _blob(br, 14, t, sd + float(i))
		for k in pts.size():
			pts[k] += p
		ci.draw_colored_polygon(pts, col.darkened(0.45))
		disc(ci, p, br * 0.72, col.darkened(0.05))
		disc(ci, p + Vector2(-br * 0.2, -br * 0.25), br * 0.3, col.lightened(0.45))
		strip(ci, _closed(pts), col.lightened(0.3), maxf(br * 0.12, 1.2), true)

static func _bumpy(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var pts := _blob(r, 28, t, sd, 0.015)
	ci.draw_colored_polygon(pts, col.darkened(0.45))
	strip(ci, _closed(pts), col.lightened(0.3), maxf(r * 0.08, 1.4), true)
	# Rosette bumps: rings of little hexagonal plates.
	for ring in 3:
		var rad := r * (0.28 + 0.27 * float(ring))
		var cnt := 5 + ring * 4
		for j in cnt:
			var a := TAU * float(j) / float(cnt) + float(ring) * 0.4 + sd
			var p := Vector2.RIGHT.rotated(a) * rad
			var br := r * 0.15
			var hex := PackedVector2Array()
			for k in 6:
				hex.append(p + Vector2.RIGHT.rotated(TAU * float(k) / 6.0) * br)
			ci.draw_colored_polygon(hex, col.lightened(0.1))
			strip(ci, _closed(hex), col.darkened(0.5), maxf(r * 0.025, 1.0), true)
	disc(ci, Vector2.ZERO, r * 0.13, col.lightened(0.4))

static func _spiky(ci: CanvasItem, r: float, col: Color, t: float, sd: float, role: String) -> void:
	var n := 12
	var body := r * 0.78
	for i in n:
		var a := TAU * float(i) / float(n) + sd + sin(t * 1.5 + float(i)) * 0.04
		var d := Vector2.RIGHT.rotated(a)
		var ln := r * (1.0 + 0.06 * sin(t * 4.0 + float(i) * 2.0))
		ci.draw_line(d * body * 0.9, d * ln, col.darkened(0.15), maxf(r * 0.07, 1.4), true)
		disc(ci, d * ln, maxf(r * 0.11, 1.6), col.lightened(0.25))
	var pts := _blob(body, 24, t, sd, 0.03)
	_shade(ci, pts, col)
	if role == "toxic":
		# a sickly skull-like mark: two dark eyes
		for sgn in [-1.0, 1.0]:
			disc(ci, Vector2(body * 0.18, sgn * body * 0.28), body * 0.15, Color(0.04, 0.05, 0.0))
		ci.draw_line(Vector2(-body * 0.3, -body * 0.25), Vector2(-body * 0.3, body * 0.25), Color(0.04, 0.05, 0.0), maxf(r * 0.05, 1.2))
	elif role == "rare":
		disc(ci, Vector2.ZERO, body * 0.5, Color(1, 1, 0.8, 0.35 + 0.25 * sin(t * 6.0)))

static func _corona(ci: CanvasItem, r: float, col: Color, t: float, sd: float, detail: bool = true) -> void:
	var body := r * 0.8
	var pts := _blob(body, 28, t, sd, 0.02)
	ci.draw_colored_polygon(pts, col.darkened(0.5))
	ci.draw_colored_polygon(_scaled(pts, 0.86), col.darkened(0.1))
	for j in 14:
		var a := TAU * float(j) / 14.0 + sd
		var d := Vector2.RIGHT.rotated(a)
		ci.draw_line(d * body * 0.92, d * r * 0.98, Color("63c5ff"), maxf(r * 0.06, 1.4), true)
		disc(ci, d * r, maxf(r * 0.1, 1.6), Color("63c5ff"))
	for j in (6 if detail else 0):
		var a2 := sd + float(j) * 1.05
		disc(ci, Vector2.RIGHT.rotated(a2) * body * (0.2 + 0.45 * fmod(float(j) * 0.41, 1.0)), body * 0.1, col.lightened(0.45))
	strip(ci, _closed(pts), col.lightened(0.3), maxf(r * 0.05, 1.4), true)

static func _worm(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var pts := PackedVector2Array()
	for j in 22:
		var f := float(j) / 21.0
		pts.append(Vector2(lerpf(r * 1.7, -r * 1.7, f), sin(f * 7.0 - t * 5.0 + sd) * r * 0.55))
	strip(ci, pts, col.darkened(0.5), maxf(r * 0.7, 3.0), true)
	strip(ci, pts, col, maxf(r * 0.5, 2.2), true)
	strip(ci, pts, col.lightened(0.4), maxf(r * 0.14, 1.2), true)
	disc(ci, pts[0], maxf(r * 0.34, 2.0), col.lightened(0.1))

static func _phage(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var head := PackedVector2Array()
	for k in 6:
		head.append(Vector2(r * 0.55, 0) + Vector2.RIGHT.rotated(TAU * float(k) / 6.0 + PI / 6.0) * r * 0.62)
	ci.draw_colored_polygon(head, col.darkened(0.2))
	strip(ci, _closed(head), col.lightened(0.4), maxf(r * 0.06, 1.4), true)
	ci.draw_line(Vector2(r * 0.55, -r * 0.5), Vector2(r * 0.55, r * 0.5), col.lightened(0.2), maxf(r * 0.035, 1.0))
	ci.draw_line(Vector2(0, 0), Vector2(-r * 0.8, 0), col.lightened(0.2), maxf(r * 0.16, 2.0), true)
	for j in 6:
		var f := float(j) / 5.0 - 0.5
		var base := Vector2(-r * 0.8, 0)
		var foot := Vector2(-r * 1.35, f * r * 1.6 + sin(t * 4.0 + float(j) + sd) * r * 0.1)
		strip(ci, PackedVector2Array([base, base + Vector2(-r * 0.2, f * r * 0.5), foot]), col.darkened(0.1), maxf(r * 0.05, 1.2), true)

## A single-celled blob (amoeba): irregular, with a nucleus and a few vacuoles.
static func _amoeba(ci: CanvasItem, r: float, col: Color, t: float, sd: float, detail: bool = true) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var ang := TAU * float(i) / 28.0
		var k := 1.0 + 0.10 * sin(ang * 3.0 + t * 1.6 + sd) + 0.07 * sin(ang * 2.0 - t * 1.1 + sd * 1.3)
		pts.append(Vector2.RIGHT.rotated(ang) * r * 0.9 * k)
	_shade(ci, pts, col)
	if not detail:
		return
	disc(ci, Vector2(-r * 0.1, r * 0.05), r * 0.26, col.darkened(0.5))
	arc(ci, Vector2(-r * 0.1, r * 0.05), r * 0.26, 0.0, TAU, 18, col.lightened(0.4), maxf(r * 0.04, 1.0), true)
	for j in 3:
		var a := sd + float(j) * 2.1
		disc(ci, Vector2.RIGHT.rotated(a) * r * 0.55, r * 0.09, Color(col.lightened(0.5), 0.6))

## A coiled bacterium (spirillum).
static func _spiral(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var pts := PackedVector2Array()
	for j in 26:
		var f := float(j) / 25.0
		pts.append(Vector2(lerpf(r * 1.4, -r * 1.4, f), sin(f * TAU * 2.4 + t * 5.0 + sd) * r * 0.42))
	strip(ci, pts, col.darkened(0.5), maxf(r * 0.5, 3.0), true)
	strip(ci, pts, col, maxf(r * 0.34, 2.0), true)
	strip(ci, pts, col.lightened(0.45), maxf(r * 0.1, 1.0), true)

## Extra body parts drawn behind the body: tail, fins, arms.
static func _feats_back(ci: CanvasItem, r: float, col: Color, t: float, sd: float, feats: Array) -> void:
	if feats.has("tail"):
		var line := PackedVector2Array()
		for j in 14:
			var f := float(j) / 13.0
			line.append(Vector2(-r * 0.8 - r * 1.7 * f, sin(t * 8.0 - f * 5.0 + sd) * r * 0.3 * f))
		_tapered(ci, line, r * 0.3, Color(col, 0.5))
		_tapered(ci, line, r * 0.18, col.lightened(0.2))
	if feats.has("fins"):
		for sgn in [-1.0, 1.0]:
			var w := sin(t * 5.0 + sd + sgn) * r * 0.1
			ci.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.1, sgn * r * 0.7), Vector2(-r * 0.7, sgn * (r * 1.3 + w)), Vector2(-r * 0.9, sgn * r * 0.6)]), Color(col.lightened(0.15), 0.8))
	if feats.has("arms"):
		for k in 5:
			var base_a: float = [1.9, 2.5, 3.14159, 3.78, 4.38][k]
			var dir := Vector2.RIGHT.rotated(base_a)
			var side := dir.orthogonal()
			var line2 := PackedVector2Array()
			for j in 10:
				var f2 := float(j) / 9.0
				line2.append(dir * r * (0.75 + 1.1 * f2) + side * sin(t * 4.0 + float(k) * 1.6 - f2 * 4.0 + sd) * r * 0.26 * f2)
			_tapered(ci, line2, r * 0.2, Color(col, 0.6))
			_tapered(ci, line2, r * 0.11, col.lightened(0.2))

## Extra body parts drawn over the body: cilia, eye.
static func _feats_front(ci: CanvasItem, r: float, col: Color, t: float, sd: float, feats: Array) -> void:
	if feats.has("cilia"):
		for j in 20:
			var a := TAU * float(j) / 20.0
			var d := Vector2.RIGHT.rotated(a)
			ci.draw_line(d * r * 0.88, d.rotated(sin(t * 7.0 + float(j) * 1.9) * 0.35) * r * 1.12, Color(col, 0.8), maxf(r * 0.03, 1.0), true)
	if feats.has("eye"):
		var e := Vector2(r * 0.45, 0)
		disc(ci, e, r * 0.2, Color(1, 1, 1, 0.97))
		disc(ci, e + Vector2(r * 0.04, 0), r * 0.1, Color(0.03, 0.03, 0.08))

## A little cell with a long waving tail: eat it to grow your own.
static func _tailed(ci: CanvasItem, r: float, col: Color, t: float, sd: float, detail: bool = true) -> void:
	var line := PackedVector2Array()
	for j in 14:
		var f := float(j) / 13.0
		line.append(Vector2(-r * 0.7 - r * 2.0 * f, sin(t * 9.0 - f * 5.0 + sd) * r * 0.32 * f))
	_tapered(ci, line, r * 0.34, Color(col, 0.45))
	_tapered(ci, line, r * 0.2, col.lightened(0.2))
	var pts := _blob(r * 0.8, 22, t, sd)
	_shade(ci, pts, col)
	if detail:
		disc(ci, Vector2(-r * 0.1, 0), r * 0.22, col.darkened(0.5))
		disc(ci, Vector2(r * 0.2, -r * 0.3), r * 0.1, col.lightened(0.5))

## A little cell with a big eye on the front: eat it to grow your own.
static func _eyed(ci: CanvasItem, r: float, col: Color, t: float, sd: float, detail: bool = true) -> void:
	var pts := _blob(r * 0.85, 22, t, sd)
	_shade(ci, pts, col)
	var e := Vector2(r * 0.4, 0)
	disc(ci, e, r * 0.38, Color(1, 1, 1, 0.97))
	disc(ci, e + Vector2(r * 0.07 + sin(t * 1.3 + sd) * r * 0.05, 0), r * 0.2, Color(0.03, 0.03, 0.08))
	disc(ci, e + Vector2(r * 0.02, -r * 0.1), r * 0.06, Color.WHITE)
	if detail:
		disc(ci, Vector2(-r * 0.35, r * 0.2), r * 0.16, col.darkened(0.5))

static func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out

## Voodoo skin: any creature as a glowing neon outline with two eye sockets.
static func _creature_voodoo(ci: CanvasItem, r: float, col: Color, shape: String, t: float, sd: float) -> void:
	var pts := _blob(r, 24, t, sd)
	if shape == "worm":
		var line := PackedVector2Array()
		for j in 16:
			var f := float(j) / 15.0
			line.append(Vector2(lerpf(r * 1.7, -r * 1.7, f), sin(f * 7.0 - t * 5.0 + sd) * r * 0.55))
		strip(ci, line, Color(col, 0.3), maxf(r * 0.5, 3.0), true)
		strip(ci, line, col, maxf(r * 0.1, 1.6), true)
		return
	disc(ci, Vector2.ZERO, r * 1.5, Color(col, 0.06))
	ci.draw_colored_polygon(pts, Color(col, 0.14))
	strip(ci, _closed(pts), Color(col, 0.3), maxf(r * 0.14, 4.0), true)
	strip(ci, _closed(pts), col, maxf(r * 0.045, 1.8), true)
	if shape == "spiky" or shape == "corona":
		for j in 10:
			var d := Vector2.RIGHT.rotated(TAU * float(j) / 10.0 + sd)
			ci.draw_line(d * r, d * r * 1.25, col, maxf(r * 0.04, 1.4), true)
	if r > 9.0:
		for sgn in [-1.0, 1.0]:
			var ep := Vector2(r * 0.12, sgn * r * 0.3)
			disc(ci, ep, r * 0.18, Color(0.02, 0.0, 0.05, 0.95))
			arc(ci, ep, r * 0.18, 0.0, TAU, 16, col, maxf(r * 0.04, 1.2), true)

# ---------- animals: fish, jellyfish, squid, rays, snakes, octopus, turtle; the rare starfish, seahorse, merfolk ----------
# Everything from size 3 on. Drawn from above, +x forward. `plan` = the species' `fish` body plan
# (evolution_data.gd); `lvl` = its own size, which adds parts the bigger it is: pelvic fins (5+), glowing
# dots (6+), barbels and tail streamers (7+).

static func _animal(ci: CanvasItem, r: float, col: Color, shape: String, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	match shape:
		"jelly":
			_jelly(ci, r, col, plan, t, sd, lvl, voodoo)
		"squid":
			_squid(ci, r, col, plan, t, sd, lvl, voodoo)
		"ray":
			_ray(ci, r, col, plan, t, sd, lvl, voodoo)
		"snake":
			_snake(ci, r, col, plan, t, sd, lvl, voodoo)
		"octopus":
			_octopus(ci, r, col, plan, t, sd, lvl, voodoo)
		"turtle":
			_turtle(ci, r, col, plan, t, sd, lvl, voodoo)
		"star":
			_star(ci, r, col, plan, t, sd, lvl, voodoo)
		"seahorse":
			_seahorse(ci, r, col, plan, t, sd, lvl, voodoo)
		"mermaid":
			_merfolk(ci, r, col, t, sd, voodoo, false)
		"poseidon":
			_merfolk(ci, r, col, t, sd, voodoo, true)
		_:
			_fish(ci, r, col, plan, t, sd, lvl, voodoo)

## A body part (fin, tail): shaded in the normal skin, a glowing outline in the Voodoo skin.
static func _part(ci: CanvasItem, pts: PackedVector2Array, col: Color, voodoo: bool, w: float, a: float = 0.85) -> void:
	if voodoo:
		ci.draw_colored_polygon(pts, Color(col, 0.10))
		strip(ci, _closed(pts), Color(col, 0.9), maxf(w, 1.4), true)
	else:
		ci.draw_colored_polygon(pts, Color(col.darkened(0.2), a))
		strip(ci, _closed(pts), col.lightened(0.3), maxf(w * 0.8, 1.0), true)

## The main body: shaded, or a neon outline in the Voodoo skin.
static func _torso(ci: CanvasItem, pts: PackedVector2Array, col: Color, voodoo: bool, r: float) -> void:
	if voodoo:
		disc(ci, Vector2.ZERO, r * 1.5, Color(col, 0.05))
		ci.draw_colored_polygon(pts, Color(col, 0.14))
		strip(ci, _closed(pts), Color(col, 0.3), maxf(r * 0.12, 4.0), true)
		strip(ci, _closed(pts), col, maxf(r * 0.045, 1.8), true)
	else:
		_shade(ci, pts, col)

static func _eye_pair(ci: CanvasItem, p: Vector2, er: float, col: Color, voodoo: bool, angry: bool) -> void:
	if voodoo:
		disc(ci, p, er, Color(0.02, 0.0, 0.05, 0.95))
		arc(ci, p, er, 0.0, TAU, 14, col, maxf(er * 0.25, 1.2), true)
		return
	disc(ci, p, er, Color(1.0, 0.93, 0.85, 0.97) if angry else Color(1, 1, 1, 0.97))
	disc(ci, p + Vector2(er * 0.2, 0), er * 0.55, Color(0.03, 0.03, 0.08))
	disc(ci, p + Vector2(er * 0.05, -er * 0.25), er * 0.18, Color.WHITE)

static func _glow_dot(ci: CanvasItem, p: Vector2, rr: float, t: float, k: float) -> void:
	var pulse := 0.55 + 0.45 * sin(t * 3.0 + k * 2.1)
	disc(ci, p, rr * 2.4, Color(0.5, 1.0, 0.9, 0.12 * pulse))
	disc(ci, p, rr, Color(0.7, 1.0, 0.95, 0.5 + 0.5 * pulse))

## Half the height of a fish's body at `u` (0 = nose, 1 = tail root).
static func _fish_h(u: float, hh: float, round_body: bool) -> float:
	if round_body:
		return hh * pow(sin(PI * clampf(u, 0.001, 0.999)), 0.6) * (1.0 - 0.25 * u)
	return hh * sin(PI * pow(clampf(u, 0.0, 1.0), 0.62)) * (1.0 - 0.3 * u)

static func _fish(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var ln: float = r * float(plan.get("len", 1.4)) * 0.85      # (kept near the creature's circle: that is what bites and gets eaten)
	var hh: float = r * float(plan.get("hgt", 0.55))
	var round_body: bool = plan.get("round", false)
	var n := 16
	var pts := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / float(n)
		var h := _fish_h(u, hh, round_body)
		var bend := sin(t * 5.0 - u * 3.5 + sd) * hh * 0.22 * u * u
		var x := ln - 2.0 * ln * u
		pts.append(Vector2(x, -h + bend))
		bot.append(Vector2(x, h + bend))
	for i in range(n - 1, 0, -1):
		pts.append(bot[i])
	var root := Vector2(-ln, sin(t * 5.0 - 3.5 + sd) * hh * 0.22)
	var wag := sin(t * 5.0 - 4.5 + sd) * hh * 0.35
	# tail
	var tail: String = plan.get("tail", "fork")
	var tl: float = r * (0.95 if tail == "fork" else 0.8)
	var ts: float = hh * (1.1 if tail == "fork" else 0.9)
	var tpts := PackedVector2Array()
	match tail:
		"fan":
			tpts = PackedVector2Array([root + Vector2(0, -hh * 0.12), root + Vector2(-tl * 0.8, -ts * 0.9 + wag), root + Vector2(-tl, wag), root + Vector2(-tl * 0.8, ts * 0.9 + wag), root + Vector2(0, hh * 0.12)])
		"fluke":
			ts *= 1.7
			tpts = PackedVector2Array([root + Vector2(0, -hh * 0.15), root + Vector2(-tl * 0.5, -ts + wag), root + Vector2(-tl * 0.9, -ts * 0.7 + wag), root + Vector2(-tl * 0.55, wag * 0.3), root + Vector2(-tl * 0.9, ts * 0.7 + wag), root + Vector2(-tl * 0.5, ts + wag), root + Vector2(0, hh * 0.15)])
		_:
			tpts = PackedVector2Array([root + Vector2(0, -hh * 0.12), root + Vector2(-tl, -ts + wag), root + Vector2(-tl * 0.55, wag * 0.5), root + Vector2(-tl, ts + wag), root + Vector2(0, hh * 0.12)])
	_part(ci, tpts, col, voodoo, r * 0.04, 0.8)
	if lvl >= 7:
		for s in [-1.0, 1.0]:
			var streamer := PackedVector2Array()
			for j in 8:
				var f := float(j) / 7.0
				streamer.append(root + Vector2(-tl * (0.6 + 0.9 * f), s * ts * (0.9 - 0.3 * f) + wag + sin(t * 4.0 + f * 4.0 + s) * r * 0.1 * f))
			strip(ci, streamer, Color(col.lightened(0.2), 0.7), maxf(r * 0.025, 1.0), true)
	# side fins (seen from above) and the long spiny fans of a lionfish
	var u0 := 0.32
	var h0 := _fish_h(u0, hh, round_body)
	var x0 := ln - 2.0 * ln * u0
	if plan.get("pect", false) or plan.get("fans", false):
		var fl: float = r * (1.15 if plan.get("fans", false) else 0.8)
		for s in [-1.0, 1.0]:
			var wv := sin(t * 4.0 + sd + s) * r * 0.08
			var fin := PackedVector2Array([Vector2(x0 + r * 0.1, s * h0 * 0.8), Vector2(x0 - fl * 0.9, s * (h0 + fl * 0.8) + wv), Vector2(x0 - fl * 0.7, s * h0 * 0.9)])
			_part(ci, fin, col.lightened(0.1), voodoo, r * 0.03, 0.75)
			if plan.get("fans", false) and not voodoo:
				for q in 5:
					var qf := float(q) / 4.0
					var tip := Vector2(x0 - fl * (0.2 + 0.7 * qf), s * (h0 + fl * (0.9 - 0.3 * qf)) + wv)
					ci.draw_line(Vector2(x0 - fl * 0.1 * qf, s * h0 * 0.9), tip, Color(col.lightened(0.45), 0.9), maxf(r * 0.03, 1.0), true)
	if lvl >= 5 and not round_body:
		var u1 := 0.62
		var h1 := _fish_h(u1, hh, false)
		var x1 := ln - 2.0 * ln * u1
		for s in [-1.0, 1.0]:
			_part(ci, PackedVector2Array([Vector2(x1 + r * 0.1, s * h1 * 0.8), Vector2(x1 - r * 0.45, s * (h1 + r * 0.38)), Vector2(x1 - r * 0.4, s * h1 * 0.85)]), col, voodoo, r * 0.025, 0.7)
	# spines around the body (pufferfish, anglerfish)
	var spines: int = int(plan.get("spines", 0))
	for k in spines:
		var su := 0.14 + 0.72 * float(k) / float(maxi(spines - 1, 1))
		var sx := ln - 2.0 * ln * su
		var sh := _fish_h(su, hh, round_body)
		for s in [-1.0, 1.0]:
			var tipk := Vector2(sx - r * 0.06, s * (sh + r * 0.3))
			ci.draw_line(Vector2(sx, s * sh * 0.9), tipk, col.lightened(0.35) if not voodoo else col, maxf(r * 0.045, 1.2), true)
			disc(ci, tipk, maxf(r * 0.04, 1.2), Color(1, 1, 1, 0.8))
	# the sword
	if plan.get("sword", false):
		var sw := PackedVector2Array()
		for j in 6:
			sw.append(Vector2(ln * 0.95 + r * 1.2 * float(j) / 5.0, 0.0))
		_tapered(ci, sw, r * 0.13, col.lightened(0.35))
	_torso(ci, pts, col, voodoo, r)
	if voodoo:
		for sgn in [-1.0, 1.0]:
			_eye_pair(ci, Vector2(ln * 0.78, sgn * _fish_h(0.1, hh, round_body) * 0.7), maxf(r * 0.13, 1.6), col, true, false)
		return
	# markings
	var dark := Color(col.darkened(0.6), 0.5)
	if plan.get("stripes", false):
		for k in 4:
			var bu := 0.22 + 0.14 * float(k)
			var bh := _fish_h(bu, hh, round_body) * 0.92
			var bx := ln - 2.0 * ln * bu
			ci.draw_line(Vector2(bx, -bh), Vector2(bx, bh), dark, maxf(r * 0.08, 1.4), true)
	if plan.get("plates", false):
		for a in 7:
			var pu := 0.18 + 0.095 * float(a)
			var ph := _fish_h(pu, hh, round_body)
			var px := ln - 2.0 * ln * pu
			for b in 4:
				var py := ph * (-0.65 + 0.43 * float(b) + (0.2 if a % 2 == 0 else 0.0))
				arc(ci, Vector2(px, py), maxf(r * 0.1, 1.3), PI * 0.5, PI * 1.5, 6, Color(col.lightened(0.4), 0.7), maxf(r * 0.025, 1.0), true)
	if plan.get("spots", false):
		for k in 9:
			var spu := 0.18 + 0.08 * float(k)
			var sy := _fish_h(spu, hh, round_body) * sin(float(k) * 2.3 + sd) * 0.6
			disc(ci, Vector2(ln - 2.0 * ln * spu, sy), r * 0.06, Color(1, 1, 1, 0.75))
	if plan.get("scars", false):
		ci.draw_line(Vector2(ln * 0.1, -hh * 0.5), Vector2(-ln * 0.15, -hh * 0.1), Color(1, 1, 1, 0.45), maxf(r * 0.03, 1.0), true)
		ci.draw_line(Vector2(ln * 0.0, hh * 0.1), Vector2(-ln * 0.3, hh * 0.55), Color(1, 1, 1, 0.45), maxf(r * 0.03, 1.0), true)
	if plan.get("gills", false):
		for k in 3:
			var gx := ln - 2.0 * ln * (0.2 + 0.04 * float(k))
			for s in [-1.0, 1.0]:
				ci.draw_line(Vector2(gx, s * hh * 0.45), Vector2(gx - r * 0.1, s * hh * 0.85), dark, maxf(r * 0.035, 1.0), true)
	# a ridge down the back
	var dorsal: int = int(plan.get("dorsal", 0))
	if dorsal > 0:
		var ridge := PackedVector2Array()
		for j in 8:
			var rf := 0.2 + 0.6 * float(j) / 7.0
			ridge.append(Vector2(ln - 2.0 * ln * rf, sin(t * 5.0 - rf * 3.5 + sd) * hh * 0.22 * rf * rf))
		strip(ci, ridge, Color(col.lightened(0.35), 0.85), maxf(r * 0.07 * float(dorsal), 1.4), true)
	# glowing dots (own flag, or from size 6)
	if plan.get("glow", false) or lvl >= 6:
		for k in 5:
			var gu := 0.2 + 0.14 * float(k)
			var gy := _fish_h(gu, hh, round_body) * 0.55
			_glow_dot(ci, Vector2(ln - 2.0 * ln * gu, gy), maxf(r * 0.035, 1.0), t, float(k))
			_glow_dot(ci, Vector2(ln - 2.0 * ln * gu, -gy), maxf(r * 0.035, 1.0), t, float(k) + 0.5)
	# teeth
	if plan.get("teeth", false):
		for k in 4:
			var tu := 0.01 + 0.03 * float(k)
			for s in [-1.0, 1.0]:
				var tp := Vector2(ln - 2.0 * ln * tu, s * _fish_h(tu, hh, round_body) * 0.9)
				ci.draw_colored_polygon(PackedVector2Array([tp + Vector2(r * 0.02, 0), tp + Vector2(-r * 0.1, -s * r * 0.02), tp + Vector2(r * 0.05, -s * r * 0.13)]), Color(1, 1, 1, 0.95))
	# whiskers
	var barbels: int = int(plan.get("barbels", 0))
	if lvl >= 7 and barbels < 2:
		barbels = 2
	for k in barbels:
		var bs := -1.0 if k % 2 == 0 else 1.0
		var line := PackedVector2Array()
		for j in 8:
			var f := float(j) / 7.0
			line.append(Vector2(ln * 0.88 + r * 0.7 * f, bs * (hh * 0.35 + r * 0.22 * f) + sin(t * 4.0 + float(k) + sd) * r * 0.12 * f))
		_tapered(ci, line, maxf(r * 0.07, 1.2), Color(col.lightened(0.35), 0.85))
	# the lantern of an anglerfish
	if plan.get("lure", false):
		var stalk := PackedVector2Array()
		for j in 9:
			var f := float(j) / 8.0
			stalk.append(Vector2(ln * 0.5 + (ln * 0.5 + r * 0.95) * f, -sin(f * PI) * r * 0.45 + sin(t * 3.0 + sd) * r * 0.1 * f))
		_tapered(ci, stalk, maxf(r * 0.07, 1.4), col.lightened(0.3))
		var bulb: Vector2 = stalk[stalk.size() - 1]
		var lp := 0.6 + 0.4 * sin(t * 4.0 + sd)
		disc(ci, bulb, r * 0.45, Color(0.7, 1.0, 0.9, 0.14 * lp))
		disc(ci, bulb, r * 0.2, Color(0.8, 1.0, 0.95, 0.6 + 0.3 * lp))
		disc(ci, bulb, r * 0.1, Color.WHITE)
	# eyes
	var er := maxf(r * (0.2 if round_body else 0.13), 1.6)
	for sgn in [-1.0, 1.0]:
		_eye_pair(ci, Vector2(ln * 0.78, sgn * _fish_h(0.1, hh, round_body) * 0.72), er, col, false, plan.get("teeth", false))

static func _jelly(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0 + sd)
	var arms: int = int(plan.get("arms", 6))
	var br := r * (0.78 + 0.07 * pulse)
	for k in arms:
		var f0 := (float(k) + 0.5) / float(arms) - 0.5
		var base := Vector2(-br * 0.5, f0 * br * 1.5)
		var line := PackedVector2Array()
		for j in 12:
			var f := float(j) / 11.0
			line.append(base + Vector2(-r * 1.9 * f, sin(t * 3.0 - f * 5.0 + float(k) * 1.3 + sd) * r * 0.26 * f + f0 * r * 0.35 * f))
		if voodoo:
			strip(ci, line, Color(col, 0.8), maxf(r * 0.04, 1.4), true)
		else:
			_tapered(ci, line, maxf(r * 0.1, 1.6), Color(col, 0.55))
			_tapered(ci, line, maxf(r * 0.05, 1.0), col.lightened(0.4))
	# the frilly arms in the middle
	for k in 3:
		var fl := PackedVector2Array()
		for j in 9:
			var f := float(j) / 8.0
			fl.append(Vector2(-br * 0.2 - r * 1.0 * f, (float(k) - 1.0) * br * 0.22 + sin(t * 4.0 - f * 6.0 + float(k) * 2.0 + sd) * r * 0.2 * f))
		_tapered(ci, fl, maxf(r * 0.22, 2.0), Color(col.lightened(0.15), 0.65) if not voodoo else Color(col, 0.35))
	var pts := _blob(br, 28, t, sd, 0.03)
	_torso(ci, pts, col, voodoo, r)
	if not voodoo:
		for k in 8:
			var a := TAU * float(k) / 8.0 + sd * 0.1
			ci.draw_line(Vector2.RIGHT.rotated(a) * br * 0.2, Vector2.RIGHT.rotated(a) * br * 0.9, Color(col.lightened(0.5), 0.45), maxf(r * 0.03, 1.0), true)
	if plan.get("glow", false) or lvl >= 6:
		for k in 8:
			_glow_dot(ci, Vector2.RIGHT.rotated(TAU * float(k) / 8.0) * br * 0.92, maxf(r * 0.035, 1.0), t, float(k))

static func _squid(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var big: bool = plan.get("big", false)
	var arms: int = int(plan.get("arms", 8))
	var longn: int = int(plan.get("long", 2))
	var ml: float = r * (1.5 if big else 1.2)
	var head := Vector2(r * 0.25, 0.0)
	# arms and the two long feeding tentacles reach forward
	for k in arms:
		var f0 := (float(k) + 0.5) / float(arms) - 0.5
		var line := PackedVector2Array()
		for j in 10:
			var f := float(j) / 9.0
			line.append(head + Vector2(r * (0.15 + 1.25 * f), f0 * r * (0.6 + 0.5 * f) + sin(t * 4.0 - f * 5.0 + float(k) * 1.4 + sd) * r * 0.2 * f))
		if voodoo:
			strip(ci, line, Color(col, 0.85), maxf(r * 0.04, 1.4), true)
		else:
			_tapered(ci, line, maxf(r * 0.12, 2.0), Color(col, 0.7))
			if plan.get("suckers", false):
				for j in range(2, 9, 2):
					disc(ci, line[j], maxf(r * 0.035, 1.0), Color(col.lightened(0.55), 0.9))
	for k in longn:
		var sg := -1.0 if k % 2 == 0 else 1.0
		var tl := PackedVector2Array()
		for j in 12:
			var f := float(j) / 11.0
			tl.append(head + Vector2(r * (0.2 + 2.1 * f), sg * r * (0.25 + 0.3 * f) + sin(t * 3.0 - f * 6.0 + float(k) * 2.0 + sd) * r * 0.28 * f))
		if voodoo:
			strip(ci, tl, col, maxf(r * 0.05, 1.6), true)
		else:
			_tapered(ci, tl, maxf(r * 0.1, 1.8), Color(col.lightened(0.15), 0.9))
		disc(ci, tl[tl.size() - 1], maxf(r * 0.1, 1.8), col.lightened(0.3) if not voodoo else col)
	# the mantle, with its fins at the back
	var pts := PackedVector2Array()
	var low := PackedVector2Array()
	for i in 15:
		var u := float(i) / 14.0
		var h := r * (0.62 if big else 0.52) * sin(PI * pow(u, 0.55)) * (1.0 - 0.45 * u)
		var x := head.x - (ml + head.x) * u
		pts.append(Vector2(x, -h))
		low.append(Vector2(x, h))
	for i in range(13, 0, -1):
		pts.append(low[i])
	var flap := sin(t * 4.0 + sd) * r * 0.1
	for s in [-1.0, 1.0]:
		_part(ci, PackedVector2Array([Vector2(-ml * 0.45, s * r * 0.3), Vector2(-ml * 0.95, s * (r * 0.85 + flap)), Vector2(-ml * 1.02, s * r * 0.15)]), col, voodoo, r * 0.03, 0.8)
	_torso(ci, pts, col, voodoo, r)
	if not voodoo:
		ci.draw_line(Vector2(head.x, 0.0), Vector2(-ml * 0.9, 0.0), Color(col.lightened(0.4), 0.5), maxf(r * 0.06, 1.2), true)
	if plan.get("glow", false) or lvl >= 6:
		for k in 5:
			_glow_dot(ci, Vector2(-ml * (0.15 + 0.17 * float(k)), (r * 0.3) * (1.0 if k % 2 == 0 else -1.0)), maxf(r * 0.04, 1.0), t, float(k))
	for sgn in [-1.0, 1.0]:
		_eye_pair(ci, head + Vector2(-r * 0.05, sgn * r * 0.46), maxf(r * 0.2, 2.0), col, voodoo, true)

static func _ray(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var span: float = float(plan.get("span", 1.5)) * r * 0.8
	var flap := 1.0 + sin(t * 3.0 + sd) * 0.12
	# the tail first: a long whip, with a stinger on a stingray
	var tail := PackedVector2Array()
	for j in 14:
		var f := float(j) / 13.0
		tail.append(Vector2(-r * 0.95 - r * 2.3 * f, sin(t * 4.0 - f * 5.0 + sd) * r * 0.22 * f))
	if voodoo:
		strip(ci, tail, col, maxf(r * 0.05, 1.6), true)
	else:
		_tapered(ci, tail, maxf(r * 0.14, 2.0), col.darkened(0.15))
	if plan.get("sting", false):
		var tp: Vector2 = tail[tail.size() - 4]
		ci.draw_colored_polygon(PackedVector2Array([tp + Vector2(r * 0.05, -r * 0.07), tp + Vector2(-r * 0.4, 0), tp + Vector2(r * 0.05, r * 0.07)]), Color("ffd9d0"))
	var pts := PackedVector2Array([Vector2(r * 1.05, 0.0)])
	var lower := PackedVector2Array()
	for s in [-1.0, 1.0]:
		var side := PackedVector2Array([Vector2(r * 0.6, s * span * 0.55), Vector2(r * 0.1, s * span * flap), Vector2(-r * 0.5, s * span * 0.72 * flap), Vector2(-r * 0.95, s * span * 0.16)])
		if s < 0.0:
			for p in side:
				pts.append(p)
		else:
			for i in range(side.size() - 1, -1, -1):
				lower.append(side[i])
	pts.append(Vector2(-r * 1.0, 0.0))
	pts.append_array(lower)
	_torso(ci, pts, col, voodoo, r)
	if plan.get("horns", false):
		for s in [-1.0, 1.0]:
			_part(ci, PackedVector2Array([Vector2(r * 0.95, s * r * 0.12), Vector2(r * 1.5, s * r * 0.3), Vector2(r * 1.0, s * r * 0.34)]), col, voodoo, r * 0.03, 0.9)
	if not voodoo:
		ci.draw_line(Vector2(r * 0.8, 0.0), Vector2(-r * 0.9, 0.0), Color(col.lightened(0.4), 0.5), maxf(r * 0.07, 1.2), true)
		for s in [-1.0, 1.0]:
			ci.draw_line(Vector2(r * 0.4, s * span * 0.2), Vector2(r * 0.0, s * span * 0.6 * flap), Color(col.lightened(0.35), 0.4), maxf(r * 0.03, 1.0), true)
	if plan.get("glow", false) or lvl >= 6:
		for k in 6:
			_glow_dot(ci, Vector2(-r * 0.3 * float(k % 3) + r * 0.3, (r * 0.35 + float(k) * r * 0.07) * (1.0 if k % 2 == 0 else -1.0)), maxf(r * 0.035, 1.0), t, float(k))
	for sgn in [-1.0, 1.0]:
		_eye_pair(ci, Vector2(r * 0.62, sgn * r * 0.2), maxf(r * 0.11, 1.5), col, voodoo, plan.get("sting", false))

static func _snake(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var ln: float = r * float(plan.get("len", 1.7)) * 0.85
	var big: bool = plan.get("big", false)
	var w0: float = r * (0.5 if big else 0.4)
	var n := 28
	var line := PackedVector2Array()
	var wid := PackedFloat32Array()
	for j in n + 1:
		var f := float(j) / float(n)
		line.append(Vector2(ln - f * ln * 2.3, sin(f * 7.5 - t * 5.0 + sd) * r * 0.5 * (0.3 + 0.7 * f)))
		wid.append(w0 * (1.0 - 0.9 * pow(f, 1.4)) + r * 0.02)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for j in n + 1:
		var a: Vector2 = line[maxi(j - 1, 0)]
		var b: Vector2 = line[mini(j + 1, n)]
		var nrm := (b - a).normalized().orthogonal()
		left.append(line[j] + nrm * wid[j])
		right.append(line[j] - nrm * wid[j])
	# fins on the sides (a sea serpent), then the body
	if plan.get("fins", false):
		for s in [-1.0, 1.0]:
			var fj := 7
			var fp: Vector2 = line[fj]
			_part(ci, PackedVector2Array([fp + Vector2(r * 0.2, s * wid[fj]), fp + Vector2(-r * 0.5, s * (wid[fj] + r * 0.55)), fp + Vector2(-r * 0.55, s * wid[fj])]), col, voodoo, r * 0.03, 0.8)
	var pts := PackedVector2Array()
	for j in n + 1:
		pts.append(left[j])
	for j in range(n, -1, -1):
		pts.append(right[j])
	if voodoo:
		ci.draw_colored_polygon(pts, Color(col, 0.14))
		strip(ci, left, col, maxf(r * 0.045, 1.8), true)
		strip(ci, right, col, maxf(r * 0.045, 1.8), true)
	else:
		ci.draw_colored_polygon(pts, col.darkened(0.5))
		var mid := PackedVector2Array()
		for j in n + 1:
			mid.append(line[j])
		strip(ci, mid, col, maxf(w0 * 1.15, 3.0), true)
		strip(ci, mid, col.lightened(0.35), maxf(w0 * 0.3, 1.2), true)
		strip(ci, left, col.lightened(0.25), maxf(r * 0.04, 1.2), true)
		strip(ci, right, col.lightened(0.25), maxf(r * 0.04, 1.2), true)
		if plan.get("bands", false):
			for k in 9:
				var bj := 3 + k * 3
				if bj >= n:
					break
				ci.draw_line(left[bj], right[bj], Color(0.05, 0.05, 0.1, 0.75), maxf(r * 0.12, 1.6), true)
		if plan.get("spots", false):
			for k in 8:
				var sj := 3 + k * 3
				if sj >= n:
					break
				disc(ci, line[sj] + Vector2(0, sin(float(k) * 3.1) * wid[sj] * 0.4), maxf(wid[sj] * 0.3, 1.2), Color(0.12, 0.1, 0.05, 0.7))
		if plan.get("crest", false):
			for k in 10:
				var cj := 2 + k * 2
				if cj >= n:
					break
				for s in [-1.0, 1.0]:
					var cp: Vector2 = line[cj]
					ci.draw_colored_polygon(PackedVector2Array([cp + Vector2(r * 0.07, s * wid[cj] * 0.8), cp + Vector2(-r * 0.2, s * (wid[cj] + r * 0.2)), cp + Vector2(-r * 0.12, s * wid[cj] * 0.8)]), Color(col.lightened(0.3), 0.9))
	if plan.get("glow", false) or lvl >= 6:
		for k in 7:
			var gj := 3 + k * 3
			if gj >= n:
				break
			_glow_dot(ci, line[gj], maxf(r * 0.04, 1.0), t, float(k))
	# the head: wide jaws, eyes and fangs
	var hp: Vector2 = line[0]
	var head := PackedVector2Array()
	for k in 16:
		var a := TAU * float(k) / 16.0
		head.append(hp + Vector2(cos(a) * r * 0.55, sin(a) * r * 0.4))
	_torso(ci, head, col, voodoo, r)
	if plan.get("fangs", false):
		for s in [-1.0, 1.0]:
			var fb := hp + Vector2(r * 0.5, s * r * 0.15)
			ci.draw_colored_polygon(PackedVector2Array([fb + Vector2(-r * 0.05, -s * r * 0.05), fb + Vector2(r * 0.3, 0), fb + Vector2(-r * 0.05, s * r * 0.07)]), Color(1, 1, 1, 0.95))
	if sin(t * 4.0 + sd) > 0.4 and not voodoo:
		var tg := hp + Vector2(r * 0.52, 0)
		ci.draw_line(tg, tg + Vector2(r * 0.4, 0), Color("ff5a6a"), maxf(r * 0.03, 1.0), true)
		ci.draw_line(tg + Vector2(r * 0.4, 0), tg + Vector2(r * 0.55, -r * 0.08), Color("ff5a6a"), maxf(r * 0.03, 1.0), true)
		ci.draw_line(tg + Vector2(r * 0.4, 0), tg + Vector2(r * 0.55, r * 0.08), Color("ff5a6a"), maxf(r * 0.03, 1.0), true)
	for s in [-1.0, 1.0]:
		var ep := hp + Vector2(r * 0.12, s * r * 0.27)
		if voodoo:
			_eye_pair(ci, ep, maxf(r * 0.12, 1.5), col, true, true)
		else:
			disc(ci, ep, maxf(r * 0.13, 1.6), Color("ffd84a"))
			ci.draw_line(ep + Vector2(0, -r * 0.1), ep + Vector2(0, r * 0.1), Color(0.03, 0.03, 0.06), maxf(r * 0.045, 1.2), true)

## An octopus: a round head in front, eight arms curling behind it.
static func _octopus(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	for k in 8:
		var a0 := PI + (float(k) - 3.5) * 0.3
		var curl := 0.9 if k % 2 == 0 else -0.9
		var line := PackedVector2Array()
		for j in 12:
			var f := float(j) / 11.0
			var a := a0 + curl * f * f * (0.8 + 0.4 * sin(t * 2.0 + float(k) + sd))
			line.append(Vector2(-r * 0.15, 0.0) + Vector2.RIGHT.rotated(a) * r * (0.35 + 1.5 * f))
		if voodoo:
			strip(ci, line, Color(col, 0.85), maxf(r * 0.045, 1.4), true)
		else:
			_tapered(ci, line, maxf(r * 0.24, 2.0), col.darkened(0.12))
			if plan.get("suckers", false):
				for j in range(2, 10, 2):
					disc(ci, line[j], maxf(r * 0.035, 1.0), Color(col.lightened(0.55), 0.85))
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		var bulge := 1.0 + 0.18 * maxf(cos(a), 0.0)
		pts.append(Vector2(r * 0.15, 0.0) + Vector2(cos(a) * r * 0.78 * bulge, sin(a) * r * 0.6))
	_torso(ci, pts, col, voodoo, r)
	if plan.get("spots", false) and not voodoo:
		for k in 5:
			disc(ci, Vector2(r * (0.45 - 0.2 * float(k % 3)), r * 0.3 * float(k % 2 * 2 - 1) * (0.5 + 0.2 * float(k))), maxf(r * 0.06, 1.0), Color(col.lightened(0.4), 0.6))
	if plan.get("glow", false) or lvl >= 6:
		for k in 4:
			_glow_dot(ci, Vector2(r * (0.6 - 0.3 * float(k)), r * 0.42 * (1.0 if k % 2 == 0 else -1.0)), maxf(r * 0.035, 1.0), t, float(k))
	for sgn in [-1.0, 1.0]:
		_eye_pair(ci, Vector2(r * 0.55, sgn * r * 0.3), maxf(r * 0.16, 2.0), col, voodoo, true)

## A sea turtle from above: the shell, four paddling flippers and a head.
static func _turtle(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var stroke := sin(t * 2.2 + sd)
	for s in [-1.0, 1.0]:
		var fa := 0.35 * stroke
		_part(ci, PackedVector2Array([Vector2(r * 0.35, s * r * 0.55), Vector2(r * (0.55 + 0.25 * fa), s * r * 1.35), Vector2(r * 0.05, s * r * 0.95)]), col.lightened(0.15), voodoo, r * 0.03, 0.95)
		_part(ci, PackedVector2Array([Vector2(-r * 0.55, s * r * 0.4), Vector2(-r * (0.95 - 0.15 * fa), s * r * 0.75), Vector2(-r * 0.75, s * r * 0.25)]), col.lightened(0.15), voodoo, r * 0.03, 0.95)
	var head := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		head.append(Vector2(r * 0.95, 0.0) + Vector2(cos(a) * r * 0.3, sin(a) * r * 0.22))
	_part(ci, head, col.lightened(0.15), voodoo, r * 0.03, 1.0)
	var shell := PackedVector2Array()
	for i in 22:
		var a := TAU * float(i) / 22.0
		shell.append(Vector2(cos(a) * r * 0.85, sin(a) * r * 0.68))
	_torso(ci, shell, col.darkened(0.1), voodoo, r)
	var line_col := Color(col.lightened(0.45), 0.55) if not voodoo else Color(col, 0.8)
	var plates := [Vector2(r * 0.3, 0.0), Vector2(-r * 0.25, 0.0), Vector2(0.0, r * 0.38), Vector2(0.0, -r * 0.38)]
	for p in plates:
		arc(ci, p, r * 0.22, 0.0, TAU, 6, line_col, maxf(r * 0.035, 1.0), true)
	if plan.get("big", false) or lvl >= 6:
		for k in 4:
			_glow_dot(ci, plates[k], maxf(r * 0.04, 1.0), t, float(k))
	for sgn in [-1.0, 1.0]:
		_eye_pair(ci, Vector2(r * 1.08, sgn * r * 0.11), maxf(r * 0.06, 1.2), col, voodoo, false)

## A starfish (rare): five arms, slowly turning, with little bumps along each arm.
static func _star(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var spin := t * 0.35 + sd
	var pts := PackedVector2Array()
	for i in 10:
		var a := spin + TAU * float(i) / 10.0
		var rr := r * (1.15 if i % 2 == 0 else 0.45) * (1.0 + 0.05 * sin(t * 2.0 + float(i)))
		pts.append(Vector2.RIGHT.rotated(a) * rr)
	_torso(ci, pts, col, voodoo, r)
	var dot := Color(col.lightened(0.6), 0.9) if not voodoo else col
	for k in 5:
		var a := spin + TAU * float(k) / 5.0
		for j in 3:
			disc(ci, Vector2.RIGHT.rotated(a) * r * (0.3 + 0.25 * float(j)), maxf(r * (0.08 - 0.015 * float(j)), 1.0), dot)
	disc(ci, Vector2.ZERO, maxf(r * 0.12, 1.2), col.lightened(0.5) if not voodoo else col)

## A seahorse (rare), seen from the side, nose forward: a curled tail, a crest and a fluttering back fin.
static func _seahorse(ci: CanvasItem, r: float, col: Color, plan: Dictionary, t: float, sd: float, lvl: int, voodoo: bool) -> void:
	var bob := sin(t * 2.0 + sd) * r * 0.06
	# the body: head at the top front, the belly, then the tail curling under
	var line := PackedVector2Array()
	for j in 16:
		var f := float(j) / 15.0
		var p: Vector2
		if f < 0.55:
			var u := f / 0.55
			p = Vector2(r * (0.35 - 0.25 * sin(u * PI)), r * (-0.75 + 1.35 * u))
		else:
			var u := (f - 0.55) / 0.45
			var a := PI * 0.5 + u * PI * 1.6
			var k := r * 0.3 * (1.0 - 0.5 * u)
			p = Vector2(r * 0.22 - cos(a) * k, r * 0.9 - sin(a) * k)
		line.append(p + Vector2(0.0, bob))
	var fin := PackedVector2Array([line[4] + Vector2(-r * 0.12, 0.0), line[5] + Vector2(-r * (0.45 + 0.08 * sin(t * 9.0 + sd)), 0.0), line[7] + Vector2(-r * 0.15, 0.0)])
	_part(ci, fin, col.lightened(0.2), voodoo, r * 0.03, 0.8)
	if voodoo:
		strip(ci, line, col, maxf(r * 0.08, 1.8), true)
	else:
		_tapered(ci, line, maxf(r * 0.62, 3.0), col)
		for j in range(1, 13, 2):
			ci.draw_line(line[j] + Vector2(-r * 0.12, 0.0), line[j] + Vector2(r * 0.12, 0.0), Color(col.darkened(0.3), 0.6), maxf(r * 0.025, 1.0), true)
	var head: Vector2 = line[0]
	# the long snout and the crest (a little crown)
	ci.draw_line(head, head + Vector2(r * 0.6, r * 0.12), col.darkened(0.05) if not voodoo else col, maxf(r * 0.14, 1.6), true)
	for k in 3:
		var b := head + Vector2(-r * 0.12 + r * 0.1 * float(k), -r * 0.12)
		_part(ci, PackedVector2Array([b, b + Vector2(r * 0.03, -r * 0.18), b + Vector2(r * 0.08, 0.0)]), col.lightened(0.3), voodoo, r * 0.02, 1.0)
	_eye_pair(ci, head + Vector2(r * 0.1, -r * 0.02), maxf(r * 0.1, 1.4), col, voodoo, false)

## Skin and hair colours for the merfolk, picked by each one's seed.
const SKIN := [Color("f2c7a5"), Color("d9a06e"), Color("a8704a"), Color("6e4630")]
const HAIR := [Color("2a1a12"), Color("5a3220"), Color("d8b45a"), Color("101018")]

## A mermaid, or (king = true) a little Poseidon with a crown, a white beard and a trident: both rare. Seen from
## the side, swimming head first (+x): a fish tail with a fluke behind, the upper body in front.
static func _merfolk(ci: CanvasItem, r: float, col: Color, t: float, sd: float, voodoo: bool, king: bool) -> void:
	var skin: Color = SKIN[int(absf(sd) * 7.0) % SKIN.size()]
	var hair: Color = Color("e8e8f0") if king else HAIR[int(absf(sd) * 3.0) % HAIR.size()]
	# the tail: waves behind the hips and ends in a fluke
	var tail := PackedVector2Array()
	for j in 14:
		var f := float(j) / 13.0
		tail.append(Vector2(-r * 0.1 - r * 1.25 * f, sin(t * 4.0 - f * 4.5 + sd) * r * 0.28 * f))
	var tip: Vector2 = tail[tail.size() - 1]
	var dir := (tip - tail[tail.size() - 3]).normalized()
	var nrm := dir.orthogonal()
	_part(ci, PackedVector2Array([tip - dir * r * 0.05, tip + dir * r * 0.4 + nrm * r * 0.38, tip + dir * r * 0.15, tip + dir * r * 0.4 - nrm * r * 0.38]), col.lightened(0.15), voodoo, r * 0.03, 0.95)
	if voodoo:
		strip(ci, tail, col, maxf(r * 0.08, 1.8), true)
	else:
		_tapered(ci, tail, maxf(r * 0.5, 3.0), col)
		for j in range(2, 11, 3):
			arc(ci, tail[j], r * 0.12 * (1.0 - float(j) / 14.0), -PI * 0.5, PI * 0.5, 6, Color(col.lightened(0.45), 0.55), maxf(r * 0.025, 1.0), true)
	# hair streams back over the shoulders
	var hp := Vector2(r * 0.72, 0.0)
	var flow := PackedVector2Array()
	for j in 8:
		var f := float(j) / 7.0
		flow.append(hp + Vector2(-r * (0.1 + (0.35 if king else 0.75) * f), -r * 0.12 + sin(t * 3.0 - f * 4.0 + sd) * r * 0.12 * f))
	if voodoo:
		strip(ci, flow, Color(hair, 0.9), maxf(r * 0.06, 1.4), true)
	else:
		_tapered(ci, flow, maxf(r * 0.42, 2.0), hair)
	# the upper body: a torso with a simple top in the tail colour, the arms stroking forward
	var torso := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		torso.append(Vector2(r * 0.22, 0.0) + Vector2(cos(a) * r * 0.36, sin(a) * r * 0.22))
	_part(ci, torso, skin, voodoo, r * 0.03, 1.0)
	if not king and not voodoo:
		ci.draw_line(Vector2(r * 0.32, -r * 0.2), Vector2(r * 0.32, r * 0.2), col.lightened(0.25), maxf(r * 0.16, 1.6), true)
	var stroke := sin(t * 3.0 + sd)
	var arm_col: Color = skin if not voodoo else Color(skin, 0.9)
	var sh := Vector2(r * 0.45, r * 0.12)
	var hand := sh + Vector2(r * (0.3 + 0.12 * stroke), r * (0.25 - 0.1 * stroke))
	ci.draw_line(sh, hand, arm_col, maxf(r * 0.09, 1.3), true)
	ci.draw_line(Vector2(r * 0.45, -r * 0.12), Vector2(r * (0.7 - 0.12 * stroke), -r * (0.3 - 0.1 * stroke)), arm_col, maxf(r * 0.09, 1.3), true)
	var gold := Color("ffd23f")
	if king:
		# the trident, held forward
		var a2 := hand + Vector2(r * 0.85, -r * 0.05)
		ci.draw_line(hand - Vector2(r * 0.4, 0.0), a2, gold, maxf(r * 0.06, 1.3), true)
		ci.draw_line(a2 + Vector2(0.0, -r * 0.12), a2 + Vector2(0.0, r * 0.12), gold, maxf(r * 0.045, 1.1), true)
		for k in 3:
			var off := (float(k) - 1.0) * r * 0.12
			ci.draw_line(a2 + Vector2(0.0, off), a2 + Vector2(r * 0.25, off * 1.2), gold, maxf(r * 0.045, 1.1), true)
			ci.draw_colored_polygon(PackedVector2Array([a2 + Vector2(r * 0.25, off * 1.2 - r * 0.04), a2 + Vector2(r * 0.34, off * 1.2), a2 + Vector2(r * 0.25, off * 1.2 + r * 0.04)]), gold)
	var head := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		head.append(hp + Vector2(cos(a) * r * 0.2, sin(a) * r * 0.2))
	_part(ci, head, skin, voodoo, r * 0.03, 1.0)
	if king:
		# a white beard and the golden crown
		_part(ci, PackedVector2Array([hp + Vector2(r * 0.05, r * 0.08), hp + Vector2(r * 0.22, r * 0.12), hp + Vector2(r * 0.12, r * 0.42), hp + Vector2(-r * 0.05, r * 0.2)]), hair, voodoo, r * 0.02, 1.0)
		for k in 3:
			var b := hp + Vector2(-r * 0.14 + r * 0.12 * float(k), -r * 0.18)
			ci.draw_colored_polygon(PackedVector2Array([b, b + Vector2(r * 0.05, -r * 0.16), b + Vector2(r * 0.1, 0.0)]), gold)
	disc(ci, hp + Vector2(r * 0.09, -r * 0.05), maxf(r * 0.035, 1.0), Color(0.05, 0.05, 0.1) if not voodoo else col)

# ---------- the player ----------

## Tail length by movement rank, in radii.
const TAIL_LEN := [0.0, 0.7, 1.1, 1.5, 1.8, 2.1]

## The player's creature. `st`: move_rank, sight_rank, eye_open (0..1), owned {}, specials {},
## ailments {}, speed (0..1 share of top speed), voodoo, dash (bool), lurch (0..1 after a jolt),
## col2 / col3: the two secondary colours (col2: tail, fins, spikes, tentacles, hairs; col3: spots,
## stripes and small details). Without them both are shades of `col`. `cell` (0..1, default 1): how much of the
## cell parts (nucleus, vacuoles, the bean-shaped mitochondrion, the fringe of tiny hairs) shows: the game fades
## them out between size 2 and size 3 (owner 2026-10-23: from size 3 on you are no longer a cell).
static func draw_player(ci: CanvasItem, c: Vector2, r: float, col: Color, heading: float, t: float, st: Dictionary) -> void:
	if r < 1.5:
		return
	var owned: Dictionary = st.get("owned", {})
	var move_rank: int = st.get("move_rank", 0)
	var sight_rank: int = st.get("sight_rank", 1)
	var eye_open: float = st.get("eye_open", 1.0)
	var spd: float = st.get("speed", 0.0)
	var lurch: float = st.get("lurch", 0.0)
	var voodoo: bool = st.get("voodoo", false)
	var col2: Color = st.get("col2", col.lightened(0.15))
	var col3: Color = st.get("col3", col.lightened(0.45))
	var cell: float = st.get("cell", 1.0)
	ci.draw_set_transform(c, heading, Vector2.ONE)
	var sides := 36 if r > 24.0 else 22
	var pts := _blob(r, sides, t, 0.0)
	for i in sides:
		var ang := TAU * float(i) / float(sides)
		var k := 1.0 + 0.10 * spd * cos(ang) - 0.04 * spd * (1.0 - absf(cos(ang))) + 0.12 * lurch * cos(ang)
		pts[i] *= k
	if st.get("ailments", {}).has("glow"):
		disc(ci, Vector2.ZERO, r * 2.6, Color(1, 1, 0.6, 0.10 + 0.05 * sin(t * 5.0)))
	if st.get("dash", false):
		for j in 4:
			disc(ci, Vector2(-r * (1.2 + 0.5 * float(j)), 0), r * (0.7 - 0.12 * float(j)), Color(col, 0.2 - 0.04 * float(j)))
	_tail(ci, r, col2, t, move_rank, owned, spd, st.get("tail_grow", 1.0))
	if owned.has("fins"):
		_fins(ci, r, col2, t, int(owned.get("fins", 1)))
	if voodoo:
		_player_voodoo(ci, r, col, pts, sight_rank, t)
		_reset(ci)
		return
	# cilia: tiny hairs all round (dense with the cilia coat)
	var hair_a := 1.0 if owned.has("cilia") else cell
	var hairs := (30 if owned.has("cilia") else 14) if hair_a > 0.03 else 0
	var hair_len := 0.26 if owned.has("cilia") else 0.14
	for j in hairs:
		var a := TAU * float(j) / float(hairs)
		var d := Vector2.RIGHT.rotated(a)
		var wav := sin(t * 6.0 + float(j) * 1.7) * 0.35
		ci.draw_line(d * r * 0.98, d.rotated(wav) * r * (1.0 + hair_len), Color(col2, 0.75 * hair_a), maxf(r * 0.03, 1.0), true)
	if owned.has("spikes"):
		for j in 10:
			var a2 := TAU * (float(j) + 0.5) / 10.0
			var d2 := Vector2.RIGHT.rotated(a2)
			ci.draw_colored_polygon(PackedVector2Array([d2 * r * 0.96 + d2.orthogonal() * r * 0.07, d2 * r * 1.28, d2 * r * 0.96 - d2.orthogonal() * r * 0.07]), col2.lightened(0.2))
	if owned.has("tentacles"):
		_tentacles(ci, r, col2, t, owned.has("stinger"))
	disc(ci, Vector2.ZERO, r * 1.9, Color(col, 0.05))
	disc(ci, Vector2.ZERO, r * 1.45, Color(col, 0.09))
	ci.draw_colored_polygon(pts, col.darkened(0.7))
	ci.draw_colored_polygon(_scaled(pts, 0.84), Color(col, 0.42))
	ci.draw_colored_polygon(_scaled(pts, 0.5), Color(col.lightened(0.35), 0.22))
	# markings in the second secondary colour: a stripe across the back and a few spots
	var stripe := PackedVector2Array()
	for k in 12:
		var f := float(k) / 11.0
		stripe.append(Vector2(lerpf(-r * 0.78, r * 0.25, f), -r * (0.62 - 0.1 * sin(f * PI)) + sin(f * 5.0 + t * 1.5) * r * 0.03))
	strip(ci, stripe, Color(col3, 0.75), maxf(r * 0.07, 1.5), true)
	for sp in [Vector2(-0.55, 0.42), Vector2(-0.2, 0.62), Vector2(0.2, 0.5), Vector2(-0.72, 0.05), Vector2(0.38, -0.36)]:
		disc(ci, sp * r, r * 0.075, Color(col3, 0.7))
	# cell parts: nucleus, vacuoles, a bean-shaped mitochondrion (gone from size 3)
	if cell > 0.03:
		var nuc := Vector2(-r * 0.12, r * 0.04)
		disc(ci, nuc, r * 0.28, Color(col.darkened(0.45), 0.9 * cell))
		arc(ci, nuc, r * 0.28, 0.0, TAU, 24, Color(col.lightened(0.3), 0.8 * cell), maxf(r * 0.03, 1.2), true)
		disc(ci, nuc + Vector2(r * 0.04, -r * 0.05), r * 0.08, Color(1, 1, 1, 0.45 * cell))
		for j in 3:
			var va := 1.1 + float(j) * 2.1 + t * 0.12
			disc(ci, Vector2.RIGHT.rotated(va) * r * 0.58, r * (0.07 + 0.015 * float(j)), Color(col3, 0.45 * cell))
			arc(ci, Vector2.RIGHT.rotated(va) * r * 0.58, r * (0.07 + 0.015 * float(j)), 0.0, TAU, 12, Color(col.lightened(0.6), 0.8 * cell), maxf(r * 0.02, 1.0), true)
		var bean := PackedVector2Array()
		for k in 10:
			var ba := TAU * float(k) / 10.0
			bean.append(Vector2(-r * 0.45, -r * 0.42) + Vector2(cos(ba) * r * 0.16, sin(ba) * r * 0.07).rotated(0.6))
		ci.draw_colored_polygon(bean, Color(col3, 0.6 * cell))
	var cl := _closed(pts)
	var rim := maxf(r * (0.16 if owned.has("membrane") else 0.1), 2.5)
	strip(ci, cl, Color(col, 0.35), rim, true)
	strip(ci, cl, col.lightened(0.25), maxf(r * 0.05, 1.8), true)
	if st.get("specials", {}).has("armor"):
		for j in 5:
			var aa := PI * 0.5 + float(j) * 0.5 - 1.0
			arc(ci, Vector2.ZERO, r * 1.07, aa - 0.2, aa + 0.2, 8, Color(0.85, 0.9, 1.0, 0.9), maxf(r * 0.09, 2.0), true)
	_eyes(ci, r, col2, sight_rank, eye_open, owned)
	_reset(ci)

## Fins on both sides, a little behind the middle (bigger with the second point).
static func _fins(ci: CanvasItem, r: float, col: Color, t: float, rank: int) -> void:
	var k := 1.0 if rank <= 1 else 1.3
	for sgn in [-1.0, 1.0]:
		var w := sin(t * 5.0 + sgn) * r * 0.08
		var fin := PackedVector2Array([Vector2(r * 0.15, sgn * r * 0.8), Vector2(-r * 0.55, sgn * (r * (1.0 + 0.35 * k) + w)), Vector2(-r * 0.75, sgn * r * 0.7)])
		ci.draw_colored_polygon(fin, Color(col, 0.85))
		strip(ci, _closed(fin), col.lightened(0.3), maxf(r * 0.03, 1.2), true)

## Four waving tentacles around the front of the body (stinging tips once the stinger is owned).
static func _tentacles(ci: CanvasItem, r: float, col: Color, t: float, sting: bool) -> void:
	for k in 4:
		var base_a: float = [-1.25, -0.5, 0.5, 1.25][k]
		var dir := Vector2.RIGHT.rotated(base_a)
		var side := dir.orthogonal()
		var line := PackedVector2Array()
		for j in 12:
			var f := float(j) / 11.0
			line.append(dir * r * (0.85 + 1.4 * f) + side * sin(t * 4.0 + float(k) * 1.7 - f * 4.0) * r * 0.28 * f)
		_tapered(ci, line, maxf(r * 0.16, 2.4), Color(col, 0.55))
		_tapered(ci, line, maxf(r * 0.09, 1.6), col.lightened(0.2))
		if sting:
			disc(ci, line[line.size() - 1], maxf(r * 0.07, 1.8), Color("ff6a4a"))

static func _tail(ci: CanvasItem, r: float, col: Color, t: float, move_rank: int, owned: Dictionary, spd: float, grow: float = 1.0) -> void:
	if move_rank <= 0:
		return
	var ln: float = r * TAIL_LEN[clampi(move_rank, 0, TAIL_LEN.size() - 1)] * clampf(grow, 0.0, 1.0)
	var tails := [0.0]
	if owned.has("flagella"):
		tails = [-0.45, 0.45]
	for off in tails:
		var line := PackedVector2Array()
		for j in 14:
			var f := float(j) / 13.0
			line.append(Vector2(-r * 0.9 - ln * f, off * r * f + sin(t * (8.0 + 9.0 * spd) - f * 5.0 + off * 3.0) * r * (0.22 + 0.08 * spd) * f))
		_tapered(ci, line, maxf(r * 0.2, 2.6), Color(col, 0.35))
		_tapered(ci, line, maxf(r * 0.12, 1.8), col.lightened(0.15))

## A tail drawn as a tapered ribbon: full width at the body, a point at the tip.
static func _tapered(ci: CanvasItem, line: PackedVector2Array, base_w: float, col: Color) -> void:
	var n := line.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var a: Vector2 = line[maxi(i - 1, 0)]
		var b: Vector2 = line[mini(i + 1, n - 1)]
		var nrm := (b - a).normalized().orthogonal()
		var f := float(i) / float(n - 1)
		var w := base_w * 0.5 * pow(1.0 - f, 0.85) + 0.3
		left.append(line[i] + nrm * w)
		right.append(line[i] - nrm * w)
	right.reverse()
	left.append_array(right)
	ci.draw_colored_polygon(left, col)

## Rank 1 sees nothing (no eye). Rank 2: one eye lump with a slit that opens.
## Rank 3+: two eyes, rank 4 bigger.
static func _eyes(ci: CanvasItem, r: float, col: Color, sight_rank: int, open: float, owned: Dictionary) -> void:
	if sight_rank < 2:
		return
	var er := r * (0.2 if sight_rank >= 4 else 0.17)
	var spots: Array = [Vector2(r * 0.62, 0.0)] if sight_rank == 2 else [Vector2(r * 0.58, -r * 0.3), Vector2(r * 0.58, r * 0.3)]
	for p in spots:
		disc(ci, p, er * 1.25, Color(col.lightened(0.15), 0.9))    # the lump
		var w := er * open
		var lid := PackedVector2Array()
		for k in 14:
			var a := TAU * float(k) / 14.0
			lid.append(p + Vector2(cos(a) * er * 0.55, sin(a) * maxf(w, 0.3)))
		ci.draw_colored_polygon(lid, Color(1, 1, 1, 0.95))
		disc(ci, p + Vector2(er * 0.12, 0), maxf(w * 0.55, 0.0), Color(0.03, 0.03, 0.08))
		if w > er * 0.5:
			disc(ci, p + Vector2(er * 0.0, -w * 0.25), er * 0.12, Color.WHITE)

static func _player_voodoo(ci: CanvasItem, r: float, col: Color, pts: PackedVector2Array, sight_rank: int, t: float) -> void:
	disc(ci, Vector2.ZERO, r * 1.6, Color(col, 0.06))
	ci.draw_colored_polygon(pts, Color(col, 0.14))
	var closed := _closed(pts)
	strip(ci, closed, Color(col, 0.30), maxf(r * 0.14, 4.0), true)
	strip(ci, closed, col, maxf(r * 0.045, 2.0), true)
	if sight_rank < 2 or r < 10.0:
		return
	for sgn in [-1.0, 1.0]:
		var ep := Vector2(r * 0.12, sgn * r * 0.3)
		disc(ci, ep, r * 0.2, Color(0.02, 0.0, 0.05, 0.95))
		arc(ci, ep, r * 0.2, 0.0, TAU, 20, col, maxf(r * 0.04, 1.4), true)
		disc(ci, ep + Vector2(r * 0.03, 0), r * 0.06, Color(col.lightened(0.5), 0.6 + 0.4 * sin(t * 4.0)))
