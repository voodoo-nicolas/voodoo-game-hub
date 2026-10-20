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

## Soft ring that says what the creature is to you: green prey, red hunter, white equal.
static func draw_halo(ci: CanvasItem, c: Vector2, r: float, kind: String, t: float) -> void:
	var col: Color = HALO.get(kind, Color.WHITE)
	var pulse := 0.5 + 0.5 * sin(t * (6.0 if kind == "hunter" else 2.5))
	ci.draw_circle(c, r * 1.7, Color(col, 0.05 + 0.05 * pulse))
	ci.draw_arc(c, r * 1.35, 0.0, TAU, 32, Color(col, 0.28 + 0.2 * pulse), maxf(r * 0.05, 1.6), true)

# ---------- other creatures ----------

## One creature of species `sp` (evolution_data.gd). `voodoo`: neon wireframe skin.
static func draw_creature(ci: CanvasItem, c: Vector2, r: float, sp: Dictionary, heading: float, t: float, sd: float, voodoo: bool) -> void:
	if r < 1.5:
		return
	var col: Color = sp.col
	ci.draw_set_transform(c, heading, Vector2.ONE)
	if voodoo:
		_creature_voodoo(ci, r, col, sp.shape, t, sd)
		_reset(ci)
		return
	match sp.shape:
		"beads":
			_beads(ci, r, col, t, sd)
		"rod":
			_rod(ci, r, col, t, sd)
		"chain":
			_chain(ci, r, col, t, sd)
		"bumpy":
			_bumpy(ci, r, col, t, sd)
		"spiky":
			_spiky(ci, r, col, t, sd, sp.role)
		"corona":
			_corona(ci, r, col, t, sd)
		"worm":
			_worm(ci, r, col, t, sd)
		"phage":
			_phage(ci, r, col, t, sd)
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
	ci.draw_polyline(cl, col.lightened(0.35), maxf(pts[0].length() * 0.06, 1.4), true)

static func _beads(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var pts := _blob(r, 24, t, sd)
	_shade(ci, pts, col)
	for j in 5:
		var a := sd + float(j) * 1.3
		ci.draw_circle(Vector2.RIGHT.rotated(a) * r * (0.25 + 0.4 * fmod(float(j) * 0.37, 1.0)), r * 0.09, col.darkened(0.5))
	for i in range(0, 24, 3):
		var d := pts[i].normalized()
		ci.draw_line(pts[i], pts[i] + d.rotated(sin(t * 7.0 + i) * 0.3) * r * 0.2, Color(col, 0.7), maxf(r * 0.03, 1.0), true)

static func _rod(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
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
	for j in 4:
		ci.draw_circle(Vector2(lerpf(-half * 0.6, half * 0.6, float(j) / 3.0), sin(sd + float(j) * 2.0) * th * 0.3), th * 0.18, col.darkened(0.5))

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
		ci.draw_circle(p, br * 0.72, col.darkened(0.05))
		ci.draw_circle(p + Vector2(-br * 0.2, -br * 0.25), br * 0.3, col.lightened(0.45))
		ci.draw_polyline(_closed(pts), col.lightened(0.3), maxf(br * 0.12, 1.2), true)

static func _bumpy(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var pts := _blob(r, 28, t, sd, 0.015)
	ci.draw_colored_polygon(pts, col.darkened(0.45))
	ci.draw_polyline(_closed(pts), col.lightened(0.3), maxf(r * 0.08, 1.4), true)
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
			ci.draw_polyline(_closed(hex), col.darkened(0.5), maxf(r * 0.025, 1.0), true)
	ci.draw_circle(Vector2.ZERO, r * 0.13, col.lightened(0.4))

static func _spiky(ci: CanvasItem, r: float, col: Color, t: float, sd: float, role: String) -> void:
	var n := 12
	var body := r * 0.78
	for i in n:
		var a := TAU * float(i) / float(n) + sd + sin(t * 1.5 + float(i)) * 0.04
		var d := Vector2.RIGHT.rotated(a)
		var ln := r * (1.0 + 0.06 * sin(t * 4.0 + float(i) * 2.0))
		ci.draw_line(d * body * 0.9, d * ln, col.darkened(0.15), maxf(r * 0.07, 1.4), true)
		ci.draw_circle(d * ln, maxf(r * 0.11, 1.6), col.lightened(0.25))
	var pts := _blob(body, 24, t, sd, 0.03)
	_shade(ci, pts, col)
	if role == "toxic":
		# a sickly skull-like mark: two dark eyes
		for sgn in [-1.0, 1.0]:
			ci.draw_circle(Vector2(body * 0.18, sgn * body * 0.28), body * 0.15, Color(0.04, 0.05, 0.0))
		ci.draw_line(Vector2(-body * 0.3, -body * 0.25), Vector2(-body * 0.3, body * 0.25), Color(0.04, 0.05, 0.0), maxf(r * 0.05, 1.2))
	elif role == "rare":
		ci.draw_circle(Vector2.ZERO, body * 0.5, Color(1, 1, 0.8, 0.35 + 0.25 * sin(t * 6.0)))

static func _corona(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var body := r * 0.8
	var pts := _blob(body, 28, t, sd, 0.02)
	ci.draw_colored_polygon(pts, col.darkened(0.5))
	ci.draw_colored_polygon(_scaled(pts, 0.86), col.darkened(0.1))
	for j in 14:
		var a := TAU * float(j) / 14.0 + sd
		var d := Vector2.RIGHT.rotated(a)
		ci.draw_line(d * body * 0.92, d * r * 0.98, Color("63c5ff"), maxf(r * 0.06, 1.4), true)
		ci.draw_circle(d * r, maxf(r * 0.1, 1.6), Color("63c5ff"))
	for j in 6:
		var a2 := sd + float(j) * 1.05
		ci.draw_circle(Vector2.RIGHT.rotated(a2) * body * (0.2 + 0.45 * fmod(float(j) * 0.41, 1.0)), body * 0.1, col.lightened(0.45))
	ci.draw_polyline(_closed(pts), col.lightened(0.3), maxf(r * 0.05, 1.4), true)

static func _worm(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var pts := PackedVector2Array()
	for j in 22:
		var f := float(j) / 21.0
		pts.append(Vector2(lerpf(r * 1.7, -r * 1.7, f), sin(f * 7.0 - t * 5.0 + sd) * r * 0.55))
	ci.draw_polyline(pts, col.darkened(0.5), maxf(r * 0.7, 3.0), true)
	ci.draw_polyline(pts, col, maxf(r * 0.5, 2.2), true)
	ci.draw_polyline(pts, col.lightened(0.4), maxf(r * 0.14, 1.2), true)
	ci.draw_circle(pts[0], maxf(r * 0.34, 2.0), col.lightened(0.1))

static func _phage(ci: CanvasItem, r: float, col: Color, t: float, sd: float) -> void:
	var head := PackedVector2Array()
	for k in 6:
		head.append(Vector2(r * 0.55, 0) + Vector2.RIGHT.rotated(TAU * float(k) / 6.0 + PI / 6.0) * r * 0.62)
	ci.draw_colored_polygon(head, col.darkened(0.2))
	ci.draw_polyline(_closed(head), col.lightened(0.4), maxf(r * 0.06, 1.4), true)
	ci.draw_line(Vector2(r * 0.55, -r * 0.5), Vector2(r * 0.55, r * 0.5), col.lightened(0.2), maxf(r * 0.035, 1.0))
	ci.draw_line(Vector2(0, 0), Vector2(-r * 0.8, 0), col.lightened(0.2), maxf(r * 0.16, 2.0), true)
	for j in 6:
		var f := float(j) / 5.0 - 0.5
		var base := Vector2(-r * 0.8, 0)
		var foot := Vector2(-r * 1.35, f * r * 1.6 + sin(t * 4.0 + float(j) + sd) * r * 0.1)
		ci.draw_polyline(PackedVector2Array([base, base + Vector2(-r * 0.2, f * r * 0.5), foot]), col.darkened(0.1), maxf(r * 0.05, 1.2), true)

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
		ci.draw_polyline(line, Color(col, 0.3), maxf(r * 0.5, 3.0), true)
		ci.draw_polyline(line, col, maxf(r * 0.1, 1.6), true)
		return
	ci.draw_circle(Vector2.ZERO, r * 1.5, Color(col, 0.06))
	ci.draw_colored_polygon(pts, Color(col, 0.14))
	ci.draw_polyline(_closed(pts), Color(col, 0.3), maxf(r * 0.14, 4.0), true)
	ci.draw_polyline(_closed(pts), col, maxf(r * 0.045, 1.8), true)
	if shape == "spiky" or shape == "corona":
		for j in 10:
			var d := Vector2.RIGHT.rotated(TAU * float(j) / 10.0 + sd)
			ci.draw_line(d * r, d * r * 1.25, col, maxf(r * 0.04, 1.4), true)
	if r > 9.0:
		for sgn in [-1.0, 1.0]:
			var ep := Vector2(r * 0.12, sgn * r * 0.3)
			ci.draw_circle(ep, r * 0.18, Color(0.02, 0.0, 0.05, 0.95))
			ci.draw_arc(ep, r * 0.18, 0.0, TAU, 16, col, maxf(r * 0.04, 1.2), true)

# ---------- the player ----------

## Tail length by movement rank, in radii.
const TAIL_LEN := [0.0, 0.7, 1.1, 1.5, 1.8, 2.1]

## The player's creature. `st`: move_rank, sight_rank, eye_open (0..1), owned {}, specials {},
## ailments {}, speed (0..1 share of top speed), voodoo, dash (bool), lurch (0..1 after a jolt).
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
	ci.draw_set_transform(c, heading, Vector2.ONE)
	var sides := 36 if r > 24.0 else 22
	var pts := _blob(r, sides, t, 0.0)
	for i in sides:
		var ang := TAU * float(i) / float(sides)
		var k := 1.0 + 0.10 * spd * cos(ang) - 0.04 * spd * (1.0 - absf(cos(ang))) + 0.12 * lurch * cos(ang)
		pts[i] *= k
	if st.get("ailments", {}).has("glow"):
		ci.draw_circle(Vector2.ZERO, r * 2.6, Color(1, 1, 0.6, 0.10 + 0.05 * sin(t * 5.0)))
	if st.get("dash", false):
		for j in 4:
			ci.draw_circle(Vector2(-r * (1.2 + 0.5 * float(j)), 0), r * (0.7 - 0.12 * float(j)), Color(col, 0.2 - 0.04 * float(j)))
	_tail(ci, r, col, t, move_rank, owned, spd, st.get("tail_grow", 1.0))
	if voodoo:
		_player_voodoo(ci, r, col, pts, sight_rank, t)
		_reset(ci)
		return
	# cilia: tiny hairs all round (dense with the cilia coat)
	var hairs := 30 if owned.has("cilia") else 14
	var hair_len := 0.26 if owned.has("cilia") else 0.14
	for j in hairs:
		var a := TAU * float(j) / float(hairs)
		var d := Vector2.RIGHT.rotated(a)
		var wav := sin(t * 6.0 + float(j) * 1.7) * 0.35
		ci.draw_line(d * r * 0.98, d.rotated(wav) * r * (1.0 + hair_len), Color(col, 0.75), maxf(r * 0.03, 1.0), true)
	if owned.has("spikes"):
		for j in 10:
			var a2 := TAU * (float(j) + 0.5) / 10.0
			var d2 := Vector2.RIGHT.rotated(a2)
			ci.draw_colored_polygon(PackedVector2Array([d2 * r * 0.96 + d2.orthogonal() * r * 0.07, d2 * r * 1.28, d2 * r * 0.96 - d2.orthogonal() * r * 0.07]), col.lightened(0.3))
	if owned.has("tentacles"):
		_tentacles(ci, r, col, t, owned.has("stinger"))
	ci.draw_circle(Vector2.ZERO, r * 1.9, Color(col, 0.05))
	ci.draw_circle(Vector2.ZERO, r * 1.45, Color(col, 0.09))
	ci.draw_colored_polygon(pts, col.darkened(0.7))
	ci.draw_colored_polygon(_scaled(pts, 0.84), Color(col, 0.42))
	ci.draw_colored_polygon(_scaled(pts, 0.5), Color(col.lightened(0.35), 0.22))
	# cell parts: nucleus, vacuoles, a bean-shaped mitochondrion
	var nuc := Vector2(-r * 0.12, r * 0.04)
	ci.draw_circle(nuc, r * 0.28, Color(col.darkened(0.45), 0.9))
	ci.draw_arc(nuc, r * 0.28, 0.0, TAU, 24, Color(col.lightened(0.3), 0.8), maxf(r * 0.03, 1.2), true)
	ci.draw_circle(nuc + Vector2(r * 0.04, -r * 0.05), r * 0.08, Color(1, 1, 1, 0.45))
	for j in 3:
		var va := 1.1 + float(j) * 2.1 + t * 0.12
		ci.draw_circle(Vector2.RIGHT.rotated(va) * r * 0.58, r * (0.07 + 0.015 * float(j)), Color(col.lightened(0.5), 0.5))
		ci.draw_arc(Vector2.RIGHT.rotated(va) * r * 0.58, r * (0.07 + 0.015 * float(j)), 0.0, TAU, 12, Color(col.lightened(0.6), 0.8), maxf(r * 0.02, 1.0), true)
	var bean := PackedVector2Array()
	for k in 10:
		var ba := TAU * float(k) / 10.0
		bean.append(Vector2(-r * 0.45, -r * 0.42) + Vector2(cos(ba) * r * 0.16, sin(ba) * r * 0.07).rotated(0.6))
	ci.draw_colored_polygon(bean, Color(col.lightened(0.45), 0.6))
	var cl := _closed(pts)
	var rim := maxf(r * (0.16 if owned.has("membrane") else 0.1), 2.5)
	ci.draw_polyline(cl, Color(col, 0.35), rim, true)
	ci.draw_polyline(cl, col.lightened(0.25), maxf(r * 0.05, 1.8), true)
	if st.get("specials", {}).has("armor"):
		for j in 5:
			var aa := PI * 0.5 + float(j) * 0.5 - 1.0
			ci.draw_arc(Vector2.ZERO, r * 1.07, aa - 0.2, aa + 0.2, 8, Color(0.85, 0.9, 1.0, 0.9), maxf(r * 0.09, 2.0), true)
	_eyes(ci, r, col, sight_rank, eye_open, owned)
	_reset(ci)

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
			ci.draw_circle(line[line.size() - 1], maxf(r * 0.07, 1.8), Color("ff6a4a"))

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
			line.append(Vector2(-r * 0.9 - ln * f, off * r * f + sin(t * (8.0 + 6.0 * spd) - f * 5.0 + off * 3.0) * r * 0.24 * f))
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
		ci.draw_circle(p, er * 1.25, Color(col.lightened(0.15), 0.9))    # the lump
		var w := er * open
		var lid := PackedVector2Array()
		for k in 14:
			var a := TAU * float(k) / 14.0
			lid.append(p + Vector2(cos(a) * er * 0.55, sin(a) * maxf(w, 0.3)))
		ci.draw_colored_polygon(lid, Color(1, 1, 1, 0.95))
		ci.draw_circle(p + Vector2(er * 0.12, 0), maxf(w * 0.55, 0.0), Color(0.03, 0.03, 0.08))
		if w > er * 0.5:
			ci.draw_circle(p + Vector2(er * 0.0, -w * 0.25), er * 0.12, Color.WHITE)

static func _player_voodoo(ci: CanvasItem, r: float, col: Color, pts: PackedVector2Array, sight_rank: int, t: float) -> void:
	ci.draw_circle(Vector2.ZERO, r * 1.6, Color(col, 0.06))
	ci.draw_colored_polygon(pts, Color(col, 0.14))
	var closed := _closed(pts)
	ci.draw_polyline(closed, Color(col, 0.30), maxf(r * 0.14, 4.0), true)
	ci.draw_polyline(closed, col, maxf(r * 0.045, 2.0), true)
	if sight_rank < 2 or r < 10.0:
		return
	for sgn in [-1.0, 1.0]:
		var ep := Vector2(r * 0.12, sgn * r * 0.3)
		ci.draw_circle(ep, r * 0.2, Color(0.02, 0.0, 0.05, 0.95))
		ci.draw_arc(ep, r * 0.2, 0.0, TAU, 20, col, maxf(r * 0.04, 1.4), true)
		ci.draw_circle(ep + Vector2(r * 0.03, 0), r * 0.06, Color(col.lightened(0.5), 0.6 + 0.4 * sin(t * 4.0)))
