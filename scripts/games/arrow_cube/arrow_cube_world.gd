extends Node3D

## Arrow Cube -- the 3D view. Lives in a SubViewport of arrow_cube_game.gd, which owns the HUD.
## Draws the shape, the arrows (flat ribbons a hair above the faces), stops and wrap edges;
## orbits on drag, zooms on pinch / wheel, and turns a tap into (arrow id, head).

const E = preload("res://scripts/games/arrow_cube/arrow_cube_engine.gd")

signal tapped(id: int, head: int)
signal tapped_empty

const LIFT := 0.004
## Per-face darkening (+x, -x, +y, -y, +z, -z): fixed shading so the faces read apart from any angle.
const FACE_SHADE := [0.07, 0.13, 0.0, 0.2, 0.04, 0.1]
const TAP_SLOP := 14.0
const LINE_W := 0.075     # ribbon half-width in cells (was 0.13: owner wanted thinner so the tip reads)
const SLIDE_SPEED := 11.0 # cells per second for the snake move

var engine: E
var skin: String = "classic"
var pivot: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var shape_node: MeshInstance3D
var deco_node: MeshInstance3D       # wrap edges, outlines, stops
var arrow_nodes: Dictionary = {}    # arrow id -> MeshInstance3D
var flash_node: MeshInstance3D
var highlight: Dictionary = {}      # arrow id -> Color
var interactive: bool = true
var slides: Array = []              # snake moves in flight: {node, id, pts, nrm, cum, len, t, end, exits, a, base}

var yaw: float = -0.6
var pitch: float = -0.5
var dist: float = 4.0
var base_dist: float = 4.0
var spin_v: Vector2 = Vector2.ZERO
var _press_pos: Vector2
var _pressed: bool = false
var _dragged: bool = false
var _touches: Dictionary = {}
var _pinch_d: float = 0.0

# ---------- colours ----------

const PAL := {
	"classic": {"bg": Color("e8eef6"), "shape": Color("fbfcfe"), "line": Color("1d2433"), "two_a": Color("2fb95a"),
		"two_b": Color("f0b51e"), "fork": Color("ef7d22"), "stop": Color("e03131"), "wrap": Color("4dabf7"),
		"edge": Color("c5cfdc"), "safe": Color("16c060"), "bad": Color("e03131"), "pick": Color("7048e8")},
	"voodoo": {"bg": Color("0a0d26"), "shape": Color("1b2156"), "line": Color("e9f1ff"), "two_a": Color("8cff5a"),
		"two_b": Color("ffd23f"), "fork": Color("ff5fa2"), "stop": Color("ff4f4f"), "wrap": Color("27e0d0"),
		"edge": Color("3b4590"), "safe": Color("5affc8"), "bad": Color("ff4f4f"), "pick": Color("b36bff")},
}
const NEON := [Color("27e0d0"), Color("ff5fa2"), Color("ffd23f"), Color("8cff5a"), Color("b36bff"), Color("38b6ff"), Color("ff8a3d")]

func col(k: String) -> Color:
	return PAL[skin][k]

# ---------- setup ----------

func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	we.environment = env
	add_child(we)
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 40.0
	pivot.add_child(cam)
	sun = DirectionalLight3D.new()
	sun.light_energy = 0.75
	cam.add_child(sun)
	sun.rotation_degrees = Vector3(-25, -30, 0)  # light from over the viewer's shoulder
	shape_node = MeshInstance3D.new()
	add_child(shape_node)
	deco_node = MeshInstance3D.new()
	add_child(deco_node)
	flash_node = MeshInstance3D.new()
	add_child(flash_node)
	set_skin("classic")

func set_skin(s: String) -> void:
	skin = "voodoo" if s == "voodoo" else "classic"
	env.background_color = col("bg")
	env.ambient_light_energy = 0.95 if skin == "classic" else 0.4
	sun.light_energy = 0.45 if skin == "classic" else 0.75
	if engine:
		rebuild()

## New level (or loaded save): fit the camera, draw everything.
func show_level(e: E) -> void:
	engine = e
	highlight.clear()
	pivot.position = engine.shape_center()
	base_dist = engine.shape_radius() / tan(deg_to_rad(cam.fov * 0.5)) * 1.42  # owner 2026-11-25: start zoomed out a little more
	dist = base_dist
	yaw = -0.6
	pitch = -0.5
	pivot.scale = Vector3.ONE
	_apply_cam()
	rebuild()

func _apply_cam() -> void:
	pitch = clampf(pitch, -1.45, 1.45)
	pivot.rotation = Vector3(pitch, yaw, 0)
	cam.position = Vector3(0, 0, dist)

func reset_view() -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "yaw", -0.6, 0.35)
	tw.tween_property(self, "pitch", -0.5, 0.35)
	tw.tween_property(self, "dist", base_dist, 0.35)

func _process(delta: float) -> void:
	_step_slides(delta)
	if not _pressed and spin_v.length() > 0.01:
		yaw -= spin_v.x * delta
		pitch -= spin_v.y * delta
		spin_v = spin_v.lerp(Vector2.ZERO, minf(1.0, delta * 4.0))
	_apply_cam()

# ---------- building meshes ----------

func rebuild() -> void:
	_cancel_slides()
	_build_shape()
	_build_deco()
	for id in arrow_nodes:
		arrow_nodes[id].queue_free()
	arrow_nodes.clear()
	for a in engine.arrows:
		_add_arrow_node(a)

func refresh_arrow(id: int) -> void:
	_cancel_slides(id)
	var a := engine.arrow_by_id(id)
	if arrow_nodes.has(id):
		if a.is_empty():
			arrow_nodes[id].queue_free()
			arrow_nodes.erase(id)
		else:
			arrow_nodes[id].mesh = _arrow_mesh(a)
	elif not a.is_empty():
		_add_arrow_node(a)

func sync_arrows() -> void:
	var live := {}
	for a in engine.arrows:
		live[int(a.id)] = true
		if not _sliding(int(a.id)):  # a snake move redraws it when it lands
			refresh_arrow(int(a.id))
	for id in arrow_nodes.keys():
		if not live.has(id):
			arrow_nodes[id].queue_free()
			arrow_nodes.erase(id)
	_build_deco()

func _add_arrow_node(a: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _arrow_mesh(a)
	mi.material_override = _flat_mat()
	add_child(mi)
	arrow_nodes[int(a.id)] = mi

func _flat_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_shape() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in engine.voxels:
		for nd in 6:
			if engine.voxels.has(v + E.DIRS[nd]):
				continue
			var q := _face_quad(Vector3(v), nd)
			st.set_normal(Vector3(E.DIRS[nd]))
			var fc: Color = col("shape").darkened(FACE_SHADE[nd])
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(fc)
				st.add_vertex(q[i])
	var m := _flat_mat()
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	shape_node.mesh = st.commit()
	shape_node.material_override = m

## The 4 corners of block v's face nd, wound to face out.
func _face_quad(v: Vector3, nd: int) -> Array:
	var nv := Vector3(E.DIRS[nd])
	var c := v + Vector3(0.5, 0.5, 0.5) + nv * 0.5
	var ax := E.axis(nd)
	var u := Vector3.ZERO
	var w := Vector3.ZERO
	u[(ax + 1) % 3] = 0.5
	w[(ax + 2) % 3] = 0.5
	if u.cross(w).dot(nv) < 0:
		var t := u
		u = w
		w = t
	return [c - u - w, c + u - w, c + u + w, c - u + w]

func _build_deco() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t := 0.035  # edge band width (block units)
	for e in engine.convex_edges():
		var wrap: bool = engine.wraps.has(e)
		var v := Vector3(E.edge_block(e))
		var f: Array = E.edge_faces(e)
		var na := Vector3(E.DIRS[f[0]])
		var nb := Vector3(E.DIRS[f[1]])
		var along := na.cross(nb).abs()
		var mid := v + Vector3(0.5, 0.5, 0.5) + na * 0.5 + nb * 0.5
		var c: Color = col("wrap") if wrap else col("edge")
		var bw := t * (2.2 if wrap else 0.6)
		# a band on each of the two faces, hugging the edge
		_quad(st, mid - along * 0.5 + na * 0.002, mid + along * 0.5 + na * 0.002, -nb * bw, c)
		_quad(st, mid - along * 0.5 + nb * 0.002, mid + along * 0.5 + nb * 0.002, -na * bw, c)
	var s := 1.0 / engine.n
	var gc: Color = col("edge")
	gc.a = 0.45
	var gw := minf(0.006, s * 0.02)
	for v in engine.voxels:  # faint cell grid so paths read cell by cell
		for nd in 6:
			if engine.voxels.has(v + E.DIRS[nd]):
				continue
			var nv := Vector3(E.DIRS[nd])
			var ax := E.axis(nd)
			var c0 := Vector3(v) + Vector3(0.5, 0.5, 0.5) + nv * 0.5 + nv * 0.001
			for g in range(1, engine.n):
				var o := -0.5 + g * s
				for pair in [[(ax + 1) % 3, (ax + 2) % 3], [(ax + 2) % 3, (ax + 1) % 3]]:
					var a := Vector3.ZERO
					var b := Vector3.ZERO
					var sd := Vector3.ZERO
					a[pair[0]] = o
					b[pair[0]] = o
					a[pair[1]] = -0.5
					b[pair[1]] = 0.5
					sd[pair[0]] = gw
					_quad(st, c0 + a, c0 + b, sd, gc, true)
	for k in engine.stops:
		var nv := Vector3(E.DIRS[E.key_normal(k)])
		var ctr: Vector3 = engine.cell_center(k, LIFT * 0.6)
		var ax := E.axis(E.key_normal(k))
		var u := Vector3.ZERO
		var w := Vector3.ZERO
		u[(ax + 1) % 3] = 1.0
		w[(ax + 2) % 3] = 1.0
		_ring(st, ctr, u, w, s * 0.30, s * 0.40, col("stop"))
		_quad(st, ctr - u * s * 0.15, ctr + u * s * 0.15, w * s * 0.15, col("stop"), true)
		var _n := nv
	var m := _flat_mat()
	deco_node.mesh = st.commit()
	deco_node.material_override = m

## A quad from a to b, `side` wide (one way, or both ways when centred).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, side: Vector3, c: Color, centred: bool = false) -> void:
	var o := -side if centred else Vector3.ZERO
	var p := [a + o, b + o, b + side, a + side]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.add_vertex(p[i])

func _ring(st: SurfaceTool, ctr: Vector3, u: Vector3, w: Vector3, r0: float, r1: float, c: Color) -> void:
	var segs := 20
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := u * cos(a0) + w * sin(a0)
		var d1 := u * cos(a1) + w * sin(a1)
		var p := [ctr + d0 * r0, ctr + d0 * r1, ctr + d1 * r1, ctr + d1 * r0]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_color(c)
			st.add_vertex(p[j])

## Ribbon + heads for one arrow. Two-way: each half takes its end's colour.
func _arrow_mesh(a: Dictionary, over = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cl: Array = a.cells
	var w := _line_w()
	var base: Color = _arrow_color(a)
	if highlight.has(int(a.id)):
		base = highlight[int(a.id)]
	if over != null:
		base = over
	for i in cl.size():
		var k := int(cl[i])
		var prev := -1
		if i > 0 and engine.dir_between(int(cl[i - 1]), k) >= 0:
			prev = int(cl[i - 1])
		elif i > 0:
			for j in i:  # a fork branch starts beside the junction
				if engine.dir_between(int(cl[j]), k) >= 0:
					prev = int(cl[j])
					break
		var c := base
		if a.kind == E.KIND_TWO and highlight.get(int(a.id)) == null and over == null:
			c = col("two_a") if i < cl.size() / 2.0 else col("two_b")
		_joint(st, k, w, c)
		if prev >= 0:
			_segment(st, prev, k, w, c)
	for hi in a.heads.size():
		var h: Dictionary = a.heads[hi]
		var c2 := base
		if a.kind == E.KIND_TWO and highlight.get(int(a.id)) == null and over == null:
			c2 = col("two_a") if hi == 0 else col("two_b")
		_head(st, int(h.at), int(h.dir), c2)
	return st.commit()

## Line half-width / head size in world units: scale with the cell, but capped so big-cell
## levels (level 1) don't get chunky arrows.
func _line_w() -> float:
	return minf(LINE_W / engine.n, 0.024)

func _head_s() -> float:
	return minf(1.0 / engine.n, 0.36)

## A round disc on the face (bends and tail ends look like a smooth line).
func _dot(st: SurfaceTool, ctr: Vector3, nrm: Vector3, r: float, c: Color) -> void:
	var ax := 0 if absf(nrm.x) > 0.5 else (1 if absf(nrm.y) > 0.5 else 2)
	var u := Vector3.ZERO
	var v := Vector3.ZERO
	u[(ax + 1) % 3] = r
	v[(ax + 2) % 3] = r
	var segs := 10
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		for p in [ctr, ctr + u * cos(a0) + v * sin(a0), ctr + u * cos(a1) + v * sin(a1)]:
			st.set_color(c)
			st.add_vertex(p)

func _arrow_color(a: Dictionary) -> Color:
	if a.kind == E.KIND_FORK:
		return col("fork")
	if skin == "voodoo":
		return NEON[int(a.color) % NEON.size()]
	return col("line")

func _segment(st: SurfaceTool, a: int, b: int, w: float, c: Color) -> void:
	if E.key_normal(a) == E.key_normal(b):
		_strip(st, engine.cell_center(a, LIFT), engine.cell_center(b, LIFT), Vector3(E.DIRS[E.key_normal(a)]), w, c)
	else:
		var m: Vector3 = engine.corner_point(a, b)
		var na := Vector3(E.DIRS[E.key_normal(a)])
		var nb := Vector3(E.DIRS[E.key_normal(b)])
		_strip(st, engine.cell_center(a, LIFT), m + na * LIFT, na, w, c)
		_strip(st, m + nb * LIFT, engine.cell_center(b, LIFT), nb, w, c)

func _strip(st: SurfaceTool, p: Vector3, q: Vector3, nrm: Vector3, w: float, c: Color) -> void:
	var side := (q - p).normalized().cross(nrm) * w
	var v := [p - side, q - side, q + side, p + side]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.add_vertex(v[i])

## A round dot at a cell centre so bends and the tail end look smooth.
func _joint(st: SurfaceTool, k: int, w: float, c: Color) -> void:
	_dot(st, engine.cell_center(k, LIFT), Vector3(E.DIRS[E.key_normal(k)]), w, c)

func _head(st: SurfaceTool, k: int, d: int, c: Color) -> void:
	_head_at(st, engine.cell_center(k, LIFT * 1.5), Vector3(E.DIRS[d]), Vector3(E.DIRS[E.key_normal(k)]), c)

func _head_at(st: SurfaceTool, ctr: Vector3, f: Vector3, nrm: Vector3, c: Color, alpha: float = 1.0) -> void:
	var s := _head_s()
	var side := f.cross(nrm)
	var tip := ctr + f * s * 0.46
	var back := ctr - f * s * 0.04
	c.a *= alpha
	for p in [tip, back + side * s * 0.27, back - side * s * 0.27]:
		st.set_color(c)
		st.add_vertex(p)

# ---------- effects ----------

func set_highlight(ids: Array, c: Color) -> void:
	for id in ids:
		highlight[int(id)] = c
		refresh_arrow(int(id))

func clear_highlight() -> void:
	var ids := highlight.keys()
	highlight.clear()
	for id in ids:
		refresh_arrow(int(id))

## The arrow lifts off and flies out the way its head points, fading.
func fly_away(id: int, dir: int) -> void:
	if not arrow_nodes.has(id):
		return
	var mi: MeshInstance3D = arrow_nodes[id]
	arrow_nodes.erase(id)
	var d := Vector3(E.DIRS[dir])
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "position", mi.position + d * 2.4, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)

## Snake move: the arrow slides head-first along its own bends and then `path` (the tip grows
## forward, the tail shrinks behind it). exits: it then runs off the cliff edge and fades;
## otherwise it ends parked and the arrow is redrawn from the engine. `a` = the arrow BEFORE
## the move (a copy), hi = the moving head. Forks keep fly_away (several heads move at once).
func slither(a: Dictionary, hi: int, path: Array, dir: int, exits: bool) -> void:
	var id := int(a.id)
	var body: Array = a.cells.duplicate()
	if a.kind == E.KIND_TWO and hi == 0:
		body.reverse()  # the moving end goes last (same as engine._park)
	var seq: Array = body + path
	var pts: Array = []
	var nrm: Array = []
	for i in seq.size():
		var k := int(seq[i])
		var nk := Vector3(E.DIRS[E.key_normal(k)])
		if i > 0 and E.key_normal(int(seq[i - 1])) != E.key_normal(k):
			var m: Vector3 = engine.corner_point(int(seq[i - 1]), k)
			var np := Vector3(E.DIRS[E.key_normal(int(seq[i - 1]))])
			pts.append(m + np * LIFT); nrm.append(np)
			pts.append(m + nk * LIFT); nrm.append(nk)
		pts.append(engine.cell_center(k, LIFT)); nrm.append(nk)
	var cum: Array = [0.0]
	for i in range(1, pts.size()):
		cum.append(float(cum[i - 1]) + pts[i - 1].distance_to(pts[i]))
	var blen := 0.0  # body length = up to the last body cell's point
	for i in pts.size():
		if pts[i].is_equal_approx(engine.cell_center(int(body[body.size() - 1]), LIFT)):
			blen = cum[i]
			break
	var end: float = cum[cum.size() - 1] - blen
	if exits:
		var last: Vector3 = pts[pts.size() - 1]
		var f := Vector3(E.DIRS[dir])
		var far := 3.0
		pts.append(last + f * far); nrm.append(nrm[nrm.size() - 1])
		cum.append(float(cum[cum.size() - 1]) + far)
		end += blen + 1.2
	var base := _arrow_color(a)
	var node: MeshInstance3D
	if arrow_nodes.has(id):
		_cancel_slides(id)
		node = arrow_nodes[id]
		if exits:
			arrow_nodes.erase(id)
	else:
		node = MeshInstance3D.new()
		node.material_override = _flat_mat()
		add_child(node)
	node.position = Vector3.ZERO
	slides.append({"node": node, "id": id, "pts": pts, "nrm": nrm, "cum": cum, "len": blen, "t": 0.0,
		"end": maxf(end, 0.001), "exits": exits, "kind": a.kind, "hi": hi, "base": base, "speed": SLIDE_SPEED / engine.n})

func _sliding(id: int) -> bool:
	for sl in slides:
		if int(sl.id) == id:
			return true
	return false

func _cancel_slides(id: int = -1) -> void:
	for sl in slides.duplicate():
		if id >= 0 and int(sl.id) != id:
			continue
		slides.erase(sl)
		if sl.exits and is_instance_valid(sl.node):
			sl.node.queue_free()

func _step_slides(delta: float) -> void:
	if slides.is_empty() or engine == null:
		return
	for sl in slides.duplicate():
		var spd: float = sl.speed * (1.0 + float(sl.t) / maxf(0.05, float(sl.len)) * 0.6)  # eases faster
		sl.t = minf(float(sl.end), float(sl.t) + spd * delta)
		if not is_instance_valid(sl.node):
			slides.erase(sl)
			continue
		var alpha := 1.0
		if sl.exits:  # fades as the tail runs off the shape
			alpha = clampf((float(sl.end) - float(sl.t)) / 1.2, 0.0, 1.0)
		sl.node.mesh = _slide_mesh(sl, alpha)
		if float(sl.t) >= float(sl.end):
			slides.erase(sl)
			if sl.exits:
				sl.node.queue_free()
			else:
				refresh_arrow(int(sl.id))

## Point + normal + tangent at distance d along a slide's polyline.
func _slide_at(sl: Dictionary, d: float) -> Array:
	var cum: Array = sl.cum
	var pts: Array = sl.pts
	for i in range(1, cum.size()):
		if d <= float(cum[i]) or i == cum.size() - 1:
			var seg: float = float(cum[i]) - float(cum[i - 1])
			var u := 0.0 if seg <= 1e-6 else clampf((d - float(cum[i - 1])) / seg, 0.0, 1.0)
			var f: Vector3 = (pts[i] - pts[i - 1]).normalized() if seg > 1e-6 else Vector3.ZERO
			return [pts[i - 1].lerp(pts[i], u), sl.nrm[i - 1], f, i]
	return [pts[0], sl.nrm[0], Vector3.ZERO, 1]

func _slide_mesh(sl: Dictionary, alpha: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := _line_w()
	var d0: float = sl.t
	var d1: float = float(sl.t) + float(sl.len)
	var a0 := _slide_at(sl, d0)
	var a1 := _slide_at(sl, d1)
	var chain: Array = [[a0[0], a0[1], d0]]
	for i in range(int(a0[3]), int(a1[3])):
		chain.append([sl.pts[i], sl.nrm[i], float(sl.cum[i])])
	chain.append([a1[0], a1[1], d1])
	var span := maxf(1e-4, d1 - d0)
	for i in range(1, chain.size()):
		var p: Vector3 = chain[i - 1][0]
		var q: Vector3 = chain[i][0]
		if p.distance_to(q) < 1e-5:
			continue
		var c := _slide_col(sl, (float(chain[i - 1][2]) + float(chain[i][2])) * 0.5 - d0, span)
		c.a *= alpha
		_strip(st, p, q, chain[i - 1][1], w, c)
		if i == 1:  # round tail end
			_dot(st, p, chain[0][1], w, c)
		if i < chain.size() - 1:  # round joint so bends stay smooth
			_dot(st, q, chain[i][1], w, c)
	var f: Vector3 = a1[2]
	if f != Vector3.ZERO:
		_head_at(st, a1[0] + Vector3(a1[1]) * LIFT * 0.5, f, a1[1], _slide_col(sl, span, span), alpha)
	return st.commit()

func _slide_col(sl: Dictionary, along: float, span: float) -> Color:
	if sl.kind == E.KIND_TWO:  # front half = the moving head's colour (head 0 = two_a)
		var front := col("two_a") if int(sl.hi) == 0 else col("two_b")
		var back := col("two_b") if int(sl.hi) == 0 else col("two_a")
		return front if along / span >= 0.5 else back
	return sl.base

## Bump: the arrow jerks forward and back, the way it wanted to go flashes red.
func bump(id: int, dir: int, path: Array) -> void:
	if arrow_nodes.has(id):
		var mi: MeshInstance3D = arrow_nodes[id]
		var d := Vector3(E.DIRS[dir]) * (0.25 / engine.n)
		var tw := mi.create_tween()
		tw.tween_property(mi, "position", d, 0.06)
		tw.tween_property(mi, "position", Vector3.ZERO, 0.12)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := _line_w() * 0.8
	var head := int(engine.arrow_by_id(id).get("heads", [{"at": -1}])[0].at) if not engine.arrow_by_id(id).is_empty() else -1
	var prev := head
	for k in path:
		_joint(st, int(k), w, col("bad"))
		if prev >= 0 and engine.dir_between(prev, int(k)) >= 0:
			_segment(st, prev, int(k), w, col("bad"))
		prev = int(k)
	flash_node.mesh = st.commit()
	var m := _flat_mat()
	flash_node.material_override = m
	var tw2 := create_tween()
	tw2.tween_property(m, "albedo_color:a", 0.0, 0.8).set_delay(0.25)

func celebrate() -> void:
	var tw := create_tween()
	tw.tween_property(self, "yaw", yaw - TAU, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

# ---------- input ----------

func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and DisplayServer.is_touchscreen_available():
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_d = 0.0
		return
	if event is InputEventScreenDrag and DisplayServer.is_touchscreen_available():
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var ps: Array = _touches.values()
			var dd: float = ps[0].distance_to(ps[1])
			if _pinch_d > 0.0:
				dist = clampf(dist * _pinch_d / dd, base_dist * 0.45, base_dist * 1.6)
			_pinch_d = dd
			_dragged = true
		return
	if event is InputEventMagnifyGesture:
		dist = clampf(dist / event.factor, base_dist * 0.45, base_dist * 1.6)
		return
	# Taps: mouse events only (phones send touch as mouse too -- CLAUDE.md gotcha).
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			dist = maxf(base_dist * 0.45, dist * 0.92)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			dist = minf(base_dist * 1.6, dist * 1.08)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragged = false
				_press_pos = event.position
				spin_v = Vector2.ZERO
			else:
				_pressed = false
				if not _dragged and _touches.size() < 2:
					_tap(event.position)
	elif event is InputEventMouseMotion and _pressed:
		if _touches.size() >= 2:
			return
		if not _dragged and event.position.distance_to(_press_pos) > TAP_SLOP:
			_dragged = true
		if _dragged:
			var k := 0.0085
			yaw -= event.relative.x * k
			pitch -= event.relative.y * k
			spin_v = spin_v.lerp(event.velocity * k, 0.5)

func _tap(pos: Vector2) -> void:
	if not interactive or engine == null:
		return
	var hit := pick(pos)
	if hit.is_empty():
		tapped_empty.emit()
		return
	tapped.emit(int(hit.id), int(hit.head))

## Arrow under a screen point: {id, head} or {}.
func pick(pos: Vector2) -> Dictionary:
	var o := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var best_t := INF
	var best_p := Vector3.ZERO
	var best_nd := -1
	for v in engine.voxels:
		for nd in 6:
			if engine.voxels.has(v + E.DIRS[nd]):
				continue
			var nv := Vector3(E.DIRS[nd])
			if nv.dot(dir) >= 0.0:
				continue
			var ax := E.axis(nd)
			var plane := float(v[ax]) + (1.0 if E.DIRS[nd][ax] > 0 else 0.0)
			if absf(dir[ax]) < 1e-6:
				continue
			var t := (plane - o[ax]) / dir[ax]
			if t <= 0.0 or t >= best_t:
				continue
			var p := o + dir * t
			var inside := true
			for a in 3:
				if a != ax and (p[a] < v[a] - 1e-4 or p[a] > v[a] + 1.0 + 1e-4):
					inside = false
			if inside:
				best_t = t
				best_p = p
				best_nd = nd
	if best_nd < 0:
		return {}
	var n := float(engine.n)
	var nv2 := Vector3(E.DIRS[best_nd])
	var q := best_p * n - nv2 * 0.5
	var cell := E.key(Vector3i(floori(q.x), floori(q.y), floori(q.z)), best_nd)
	var id := int(engine.occ.get(cell, -1))
	if id < 0:
		# lines are thin: take the nearest arrow cell within about one cell
		var best_d := 1.15 / n
		for a in engine.arrows:
			for c in a.cells:
				var dd := best_p.distance_to(engine.cell_center(int(c)))
				if dd < best_d:
					best_d = dd
					id = int(a.id)
					cell = int(c)
	if id < 0:
		return {}
	var a2 := engine.arrow_by_id(id)
	var head := 0
	if a2.kind == E.KIND_TWO:
		head = 0 if a2.cells.find(cell) < a2.cells.size() / 2.0 else 1
	return {"id": id, "head": head}
