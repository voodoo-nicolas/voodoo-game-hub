extends Node3D

## Mini Golf 3D world: one hole at a time, floating over a sea of clouds.
## Every hole is built in code from a small piece kit (floor_rect, ramp, bumper,
## windmill, spinner, slider, loop, booster, sand, pond); all art is generated
## here too (toon shading + ink outlines). Lives in a SubViewport of
## mini_golf_3d_game.gd, which owns the HUD, the Landing kit and saving.
## Hub physics is Godot Physics: the game runs it at 240 ticks while playing
## (set and restored by the game), which keeps the ball on the loop's curve.

signal changed            # strokes / power / rest state moved
signal holed(strokes: int)
signal message(text: String)


const BALL_R := 0.08
const MAX_POWER := 11.0         # m/s at full pull
const FULL_PULL_PX := 300.0
const AIM_PX_PER_RAD := 260.0
const STOP_SPEED := 0.1
const CUP_R := 0.14
const W := 3.0                  # standard fairway width
const TH := 0.3                 # floor thickness
const WH := 0.28                # wall height
const WT := 0.18                # wall thickness
const CANDY := [Color("#ff6fa8"), Color("#ffb347"), Color("#9b7bff"), Color("#4fc3f7"), Color("#ff7a5c"), Color("#c06cff")]

var hole_i := 0
var tee := Vector3.ZERO
var tee_yaw := PI
var cup := Vector3.ZERO
var min_y := 0.0
var course: Node3D
var movers: Array = []
var sands: Array = []           # [[Rect2 on x/z, floor y]]
var ponds: Array = []
var boosts: Array = []          # [[Rect2, y, dir, speed]]
var water_mats: Array = []
var wall_col := Color.WHITE

var ball: RigidBody3D
var cam: Camera3D
var aim_yaw := PI
var strokes := 0
var still_time := 0.0
var last_rest := Vector3.ZERO
var before_putt := {}           # for the ↩ Mulligan help
var dragging := false
var drag_start := Vector2.ZERO
var drag_yaw0 := 0.0
var power := 0.0
var sunk := false
var time := 0.0
var aim_arrow: MeshInstance3D
var mats := {}
var sink_tw: Tween
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial

func _ready() -> void:
	_build_world()
	_build_ball()
	cam = Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.current = true

# =====================================================================
# Art: toon materials with an ink outline pass
# =====================================================================
func _outline() -> StandardMaterial3D:
	if mats.has("_outline"):
		return mats["_outline"]
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = Color("#2a1e3a")
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = 0.025
	mats["_outline"] = o
	return o

func _toon(col: Color, outline := true, tex: Texture2D = null) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [col.to_html(), outline, tex]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.35
	if tex:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	if outline:
		m.next_pass = _outline()
	mats[key] = m
	return m

func _stripe_tex(a: Color, b: Color, bands: int) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var c := a if int(x * bands / 64.0) % 2 == 0 else b
			if (x * 37 + y * 91) % 23 == 0:
				c = c.lightened(0.15)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _grass() -> StandardMaterial3D:
	if not mats.has("grass"):
		mats["grass"] = _toon(Color.WHITE, true, _stripe_tex(Color("#5fd35f"), Color("#4cbf55"), 4))
	return mats["grass"]

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else course).add_child(mi)
	return mi

func _box_mesh(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

func _cyl(r_top: float, r_bot: float, h: float, segs := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	return c

func _sphere(r: float, hemi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2
	s.is_hemisphere = hemi
	s.radial_segments = 20
	s.rings = 10
	return s

func _build_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.008
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	set_skin("classic")

## Classic: a sunny pastel sky. Voodoo: the same course by moonlight.
func set_skin(skin: String) -> void:
	var night := skin == "voodoo"
	sky_mat.sky_top_color = Color("#120a2e") if night else Color("#6fb6ff")
	sky_mat.sky_horizon_color = Color("#5a2a7a") if night else Color("#ffd9f0")
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color("#2a1840") if night else Color("#ffffff")
	env.ambient_light_energy = 0.55 if night else 0.9
	env.fog_light_color = Color("#3a2060") if night else Color("#ffe6f5")
	sun.light_color = Color("#a9b8ff") if night else Color("#fff4dc")
	sun.light_energy = 0.6 if night else 1.0

func _cloud_sea(center: Vector3) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	_mesh(pm, _toon(Color("#ffffff"), false), Vector3(center.x, min_y - 4.0, center.z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + hole_i
	var cm := _toon(Color("#fdf7ff"), true)
	for i in 26:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(9, 30)
		var p := center + Vector3(cos(ang) * dist, rng.randf_range(-3.5, 2.5) + min_y, sin(ang) * dist)
		for k in rng.randi_range(3, 5):
			_mesh(_sphere(rng.randf_range(0.6, 1.4)), cm, p + Vector3(k * 0.9 - 1.5, rng.randf_range(-0.2, 0.4), rng.randf_range(-0.4, 0.4)))

# =====================================================================
# Piece kit
# =====================================================================
func _static(c: Vector3, s: Vector3, rx: float, mat: Material, friction: float, bounce: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = c
	body.rotation.x = rx
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = bounce
	body.physics_material_override = pm
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = s
	col.shape = sh
	body.add_child(col)
	_mesh(_box_mesh(s), mat, Vector3.ZERO, body)
	course.add_child(body)
	return body

func _wall(c: Vector3, s: Vector3) -> void:
	_static(c, s, 0.0, _toon(wall_col), 0.2, 0.3)

## Flat floor between x0..x1, z0..z1 at top height y. `walls` lists the
## closed sides: n (-z), s (+z), e (+x), w (-x).
func floor_rect(x0: float, x1: float, z0: float, z1: float, y: float, walls: String) -> void:
	var xa := minf(x0, x1)
	var xb := maxf(x0, x1)
	var za := minf(z0, z1)
	var zb := maxf(z0, z1)
	var w := xb - xa
	var l := zb - za
	var c := Vector3((xa + xb) * 0.5, y, (za + zb) * 0.5)
	_static(c - Vector3(0, TH * 0.5, 0), Vector3(w, TH, l), 0.0, _grass(), 0.25, 0.0)
	_mesh(_cyl(0.0, 1.0, 1.0, 8), _toon(Color("#a8744a")), c - Vector3(0, TH + 0.6, 0)).scale = Vector3(w * 0.55, 1.2, l * 0.55)
	var hy := y + WH * 0.5
	if "n" in walls: _wall(Vector3(c.x, hy, za - WT * 0.5), Vector3(w + WT * 2, WH, WT))
	if "s" in walls: _wall(Vector3(c.x, hy, zb + WT * 0.5), Vector3(w + WT * 2, WH, WT))
	if "e" in walls: _wall(Vector3(xb + WT * 0.5, hy, c.z), Vector3(WT, WH, l))
	if "w" in walls: _wall(Vector3(xa - WT * 0.5, hy, c.z), Vector3(WT, WH, l))
	min_y = minf(min_y, y)

## Ramp running north (-z) from z0 (height y0) to z1 (height y1), walled on e/w.
func ramp(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var run := absf(z1 - z0)
	var rise := y1 - y0
	var a := atan2(rise, run)
	var L := sqrt(run * run + rise * rise)
	var w := absf(x1 - x0)
	var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var n := Vector3(0, cos(a), sin(a))
	_static(mid - n * TH * 0.5, Vector3(w, TH, L + 0.04), a, _grass(), 0.25, 0.0)
	for sx in [-1, 1]:
		_static(mid + n * WH * 0.5 + Vector3(sx * (w + WT) * 0.5, 0, 0), Vector3(WT, WH, L), a, _toon(wall_col), 0.2, 0.3)
	min_y = minf(min_y, minf(y0, y1))

## Mushroom bumper: springy stalk, spotted cap.
func bumper(x: float, z: float, y: float, r := 0.28) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(x, y, z)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.95
	pm.friction = 0.1
	body.physics_material_override = pm
	var col := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = 0.5
	col.shape = sh
	col.position.y = 0.25
	body.add_child(col)
	_mesh(_cyl(r * 0.8, r, 0.45), _toon(Color("#fff3d6")), Vector3(0, 0.22, 0), body)
	var cap := _mesh(_sphere(r * 1.8, true), _toon(Color("#ff4f6d")), Vector3(0, 0.42, 0), body)
	cap.scale = Vector3(1, 0.8, 1)
	for k in 5:
		var ang := k * TAU / 5.0
		_mesh(_sphere(r * 0.28), _toon(Color.WHITE, false), Vector3(cos(ang) * r * 1.1, 0.42 + r * 0.95, sin(ang) * r * 1.1), body)
	course.add_child(body)

## Windmill across the lane at z: thread the tunnel in its base while the
## sails sweep down in front of it.
func windmill(cx: float, z: float, y: float) -> void:
	var tun := 0.34
	var depth := 1.2
	var h := 1.3
	var wood := _toon(Color("#f6e2b3"))
	var bw := W * 0.5 - tun
	for sx in [-1, 1]:
		_static(Vector3(cx + sx * (tun + bw * 0.5), y + h * 0.5, z), Vector3(bw, h, depth), 0.0, wood, 0.2, 0.5)
	_static(Vector3(cx, y + 0.32 + (h - 0.32) * 0.5, z), Vector3(tun * 2, h - 0.32, depth), 0.0, wood, 0.2, 0.5)
	_mesh(_cyl(0.75, 1.05, 2.0, 8), _toon(Color("#ffffff")), Vector3(cx, y + h + 1.0, z))
	_mesh(_cyl(0.0, 0.95, 1.1, 8), _toon(Color("#ff6f61")), Vector3(cx, y + h + 2.55, z))
	_mesh(_box_mesh(Vector3(0.3, 0.45, 0.05)), _toon(Color("#6fb6ff")), Vector3(cx, y + h + 1.2, z + 0.92))
	var hub := AnimatableBody3D.new()
	hub.position = Vector3(cx, y + 2.05, z + depth * 0.5 + 0.2)
	hub.sync_to_physics = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.5
	hub.physics_material_override = pm
	_mesh(_sphere(0.16), _toon(Color("#ffcf3f")), Vector3.ZERO, hub)
	for k in 4:
		var ang := k * PI * 0.5
		var s := Vector3(0.34, 1.9, 0.06)
		var off := Vector3(0, 1.05, 0).rotated(Vector3.BACK, ang)
		var sail := _mesh(_box_mesh(s), _toon(CANDY[k]), off, hub)
		sail.rotation.z = ang
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(s.x, s.y, 0.3)
		col.shape = sh
		col.position = off
		col.rotation.z = ang
		hub.add_child(col)
	course.add_child(hub)
	movers.append({"body": hub, "kind": "spin_z", "speed": 1.1})

## Candy-striped bar spinning flat over the fairway.
func spinner(x: float, z: float, y: float, length: float, speed: float) -> void:
	var b := AnimatableBody3D.new()
	b.position = Vector3(x, y, z)
	b.sync_to_physics = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.8
	b.physics_material_override = pm
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(length, 0.25, 0.18)
	col.shape = sh
	col.position.y = 0.13
	b.add_child(col)
	var seg := length / 6.0
	for k in 6:
		_mesh(_box_mesh(Vector3(seg, 0.25, 0.18)), _toon(Color("#ff5d8f") if k % 2 == 0 else Color.WHITE), Vector3(-length * 0.5 + seg * (k + 0.5), 0.13, 0), b)
	course.add_child(b)
	_mesh(_cyl(0.12, 0.12, 0.4), _toon(Color("#ffcf3f")), Vector3(x, y + 0.2, z))
	movers.append({"body": b, "kind": "spin_y", "speed": speed})

## Googly-eyed block sliding left/right across the lane.
func slider(x: float, z: float, y: float, width: float, travel: float, speed: float, phase: float, col_c: Color) -> void:
	var b := AnimatableBody3D.new()
	b.position = Vector3(x, y + 0.2, z)
	b.sync_to_physics = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.6
	b.physics_material_override = pm
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width, 0.4, 0.4)
	col.shape = sh
	b.add_child(col)
	_mesh(_box_mesh(sh.size), _toon(col_c), Vector3.ZERO, b)
	for sx in [-1, 1]:
		_mesh(_sphere(0.09), _toon(Color.WHITE, false), Vector3(sx * 0.16, 0.06, 0.2), b)
		_mesh(_sphere(0.045), _toon(Color.BLACK, false), Vector3(sx * 0.16, 0.06, 0.27), b)
	course.add_child(b)
	movers.append({"body": b, "kind": "slide_x", "base": b.position, "travel": travel, "speed": speed, "phase": phase})

## Sand bunker: slows the ball right down (no collision, just drag).
func sand(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var r := Rect2(minf(x0, x1), minf(z0, z1), absf(x1 - x0), absf(z1 - z0))
	sands.append([r, y])
	if not mats.has("sand"):
		mats["sand"] = _toon(Color.WHITE, false, _stripe_tex(Color("#ffe3a3"), Color("#f7d48a"), 9))
	_mesh(_box_mesh(Vector3(r.size.x, 0.012, r.size.y)), mats["sand"], Vector3(r.get_center().x, y + 0.006, r.get_center().y))

## Pond: roll in and it is a splash (+1, back to the last rest spot).
func pond(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var r := Rect2(minf(x0, x1), minf(z0, z1), absf(x1 - x0), absf(z1 - z0))
	ponds.append([r, y])
	var m: StandardMaterial3D = _toon(Color.WHITE, false, _stripe_tex(Color("#3fb7ff"), Color("#7fd3ff"), 6)).duplicate()
	water_mats.append(m)
	_mesh(_box_mesh(Vector3(r.size.x, 0.014, r.size.y)), m, Vector3(r.get_center().x, y + 0.007, r.get_center().y))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0 * 100 + z0 * 7)
	for k in int(r.get_area() * 0.8) + 1:
		var pad := _mesh(_cyl(0.13, 0.13, 0.01, 10), _toon(Color("#4caf50"), false), Vector3(rng.randf_range(r.position.x + 0.15, r.end.x - 0.15), y + 0.018, rng.randf_range(r.position.y + 0.15, r.end.y - 0.15)))
		pad.scale = Vector3(1, 1, 0.8)

## Boost pad: glowing chevrons that fling the ball forward.
func booster(x0: float, x1: float, z0: float, z1: float, y: float, yaw: float, speed: float) -> void:
	var r := Rect2(minf(x0, x1), minf(z0, z1), absf(x1 - x0), absf(z1 - z0))
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	boosts.append([r, y, dir, speed])
	var cx := r.get_center()
	_mesh(_box_mesh(Vector3(r.size.x, 0.012, r.size.y)), _toon(Color("#7b3fe4"), false), Vector3(cx.x, y + 0.006, cx.y))
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#7fffd4")
	var n := maxi(1, int(r.size.y / 0.45))
	for k in n:
		var pz := lerpf(r.end.y, r.position.y, (k + 0.5) / n)
		for sx in [-1, 1]:
			var bar := _mesh(_box_mesh(Vector3(r.size.x * 0.4, 0.014, 0.08)), glow, Vector3(cx.x + sx * r.size.x * 0.17, y + 0.012, pz))
			bar.rotation.y = sx * 0.6
			movers.append({"body": bar, "kind": "pulse", "phase": k * 0.7})

## Vertical loop-de-loop: enters heading north at (x, z) on floor height y and
## exits north again, `shift` m east (a slight corkscrew so the track clears
## its own entry). One smooth mesh: flat boxes leave seams the ball bounces
## off on a concave curve. A boost pad at its mouth launches the ball along the
## helix (sideways speed matched to the corkscrew) so it rides round.
func loop(x: float, z: float, y: float, r: float, shift: float, tw := 0.9) -> void:
	var steps := 72
	var rail_h := 0.24
	var cy := y + r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for k in steps + 1:
		var th := float(k) / steps * TAU
		var n := Vector3(0, cos(th), sin(th))          # points to the loop centre
		var c := Vector3(x + shift * th / TAU, cy - r * cos(th), z - r * sin(th))
		var lft := c - Vector3(tw * 0.5, 0, 0)
		var rgt := c + Vector3(tw * 0.5, 0, 0)
		pts.append([lft, rgt, lft + n * rail_h, rgt + n * rail_h, n])
	for k in steps:
		var A: Array = pts[k]
		var B: Array = pts[k + 1]
		var col := Color("#ffcf3f") if (k / 3) % 2 == 0 else Color("#ff8fc8")
		_quad(st, A[0], A[1], B[1], B[0], A[4], col)
		_quad(st, A[0], B[0], B[2], A[2], Vector3.RIGHT, wall_col)
		_quad(st, A[1], A[3], B[3], B[1], Vector3.LEFT, wall_col)
	var mesh := st.commit()
	booster(x - 0.5, x + 0.5, z + 1.0, z, y, atan2(shift / (TAU * r), -1.0), 7.8)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.15
	pm.bounce = 0.0
	body.physics_material_override = pm
	var col_shape := CollisionShape3D.new()
	var tri := mesh.create_trimesh_shape()
	tri.backface_collision = true
	col_shape.shape = tri
	body.add_child(col_shape)
	_mesh(mesh, m, Vector3.ZERO, body)
	course.add_child(body)
	var star := _mesh(_sphere(0.18), _toon(Color("#fff27a")), Vector3(x + shift * 0.5, y + r * 2 + 0.6, z))
	movers.append({"body": star, "kind": "bob", "base": star.position})

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(n)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)

func lolly_tree(x: float, z: float, y: float, c: Color) -> void:
	_mesh(_cyl(0.05, 0.06, 1.6), _toon(Color("#fff3d6")), Vector3(x, y + 0.8, z))
	_mesh(_sphere(0.55), _toon(c), Vector3(x, y + 1.9, z))

func flower(x: float, z: float, y: float, c: Color) -> void:
	_mesh(_cyl(0.02, 0.02, 0.3, 6), _toon(Color("#3fa34d"), false), Vector3(x, y + 0.15, z))
	for k in 5:
		var a := k * TAU / 5.0
		_mesh(_sphere(0.06), _toon(c, false), Vector3(x + cos(a) * 0.08, y + 0.32, z + sin(a) * 0.08))
	_mesh(_sphere(0.05), _toon(Color("#ffd93f"), false), Vector3(x, y + 0.33, z))

func set_cup(x: float, z: float, y: float) -> void:
	cup = Vector3(x, y, z)
	_mesh(_cyl(CUP_R, CUP_R, 0.004), _toon(Color("#141018"), false), cup + Vector3(0, 0.003, 0))
	_mesh(_cyl(CUP_R + 0.04, CUP_R + 0.04, 0.002), _toon(Color.WHITE, false), cup + Vector3(0, 0.001, 0))
	_mesh(_cyl(0.015, 0.015, 1.1), _toon(Color.WHITE, false), cup + Vector3(0, 0.55, 0))
	var pm := PrismMesh.new()
	pm.size = Vector3(0.36, 0.24, 0.02)
	var flag := _mesh(pm, _toon(Color("#ff4f6d")), cup + Vector3(0.12, 0.98, 0))
	flag.rotation.z = -PI * 0.5
	movers.append({"body": flag, "kind": "wave", "base_rot": flag.rotation})

func set_tee(x: float, z: float, y: float, yaw: float) -> void:
	tee = Vector3(x, y, z)
	tee_yaw = yaw
	_mesh(_cyl(0.3, 0.3, 0.01), _toon(Color("#ffffff"), false), tee + Vector3(0, 0.006, 0))

# =====================================================================
# The nine holes (names and pars in mini_golf_3d_engine.gd)
# =====================================================================
func _build_hole(i: int) -> void:
	match i:
		0: # Up the Hill: a ramp onto a raised green, mushroom guard
			set_tee(0, -2.0, 0, PI)
			floor_rect(-1.5, 1.5, 0.5, -6, 0, "swe")
			ramp(-1.5, 1.5, -6, -10, 0, 1)
			floor_rect(-1.5, 1.5, -10, -14, 1, "nwe")
			bumper(-0.9, -12.6, 1)
			set_cup(0.6, -13.0, 1)
			lolly_tree(-2.6, -3, 0, Color("#ff9ad5"))
			lolly_tree(2.7, -12, 1, Color("#9b7bff"))
			flower(2.2, -1, 0, Color("#ff6fa8"))
		1: # Windmill Lane: time the sails, thread the tunnel
			set_tee(0, -2.0, 0, PI)
			floor_rect(-1.5, 1.5, 0.5, -16, 0, "nswe")
			windmill(0, -8, 0)
			bumper(-0.8, -12.5, 0)
			bumper(0.8, -12.5, 0)
			set_cup(0, -14.6, 0)
			for k in 4:
				flower(-2.2, -2 - k * 3.5, 0, CANDY[k])
				flower(2.2, -3.5 - k * 3.5, 0, CANDY[k + 1])
		2: # Dogleg Dash: up the lane, turn right through a mushroom slalom
			set_tee(0, -2.0, 0, PI)
			floor_rect(-1.5, 1.5, 0.5, -7, 0, "swe")
			floor_rect(-1.5, 1.5, -7, -10, 0, "nw")
			floor_rect(1.5, 13.5, -7, -10, 0, "nse")
			bumper(4.8, -9.1, 0)
			bumper(7.6, -7.9, 0)
			bumper(10.4, -9.1, 0)
			set_cup(12.4, -8.5, 0)
			lolly_tree(-2.7, -9, 0, Color("#ffb347"))
			lolly_tree(7, -11.6, 0, Color("#4fc3f7"))
			lolly_tree(3, -5.5, 0, Color("#ff6fa8"))
		3: # Double Decker: over the hump, down the far side, past the spinner
			set_tee(0, -2.0, 0, PI)
			floor_rect(-1.5, 1.5, 0.5, -5, 0, "swe")
			ramp(-1.5, 1.5, -5, -9, 0, 1.2)
			floor_rect(-1.5, 1.5, -9, -11, 1.2, "we")
			ramp(-1.5, 1.5, -11, -14, 1.2, 0)
			floor_rect(-1.5, 1.5, -14, -21, 0, "nwe")
			spinner(0, -17.5, 0, 2.2, 1.3)
			set_cup(0, -20, 0)
			lolly_tree(2.8, -10, 0, Color("#c06cff"))
			lolly_tree(-2.8, -18, 0, Color("#ffb347"))
		4: # Slide Gates: two googly-eyed blocks guard the lane
			set_tee(0, -2.0, 0, PI)
			floor_rect(-1.5, 1.5, 0.5, -18, 0, "nswe")
			slider(0, -6, 0, 1.0, 1.0, 1.3, 0.0, Color("#4fc3f7"))
			slider(0, -11, 0, 1.0, 1.0, 1.6, PI, Color("#ffb347"))
			bumper(0, -14, 0, 0.24)
			set_cup(0.7, -16.6, 0)
			for k in 5:
				flower(-2.2, -1 - k * 4, 0, CANDY[k])
				flower(2.2, -3 - k * 4, 0, CANDY[(k + 2) % 6])
		5: # Cloud Volcano: two climbs to a crater ringed by mushrooms
			set_tee(0, -2.0, 0, PI)
			floor_rect(-1.5, 1.5, 0.5, -5, 0, "swe")
			ramp(-1.5, 1.5, -5, -9, 0, 0.8)
			floor_rect(-1.5, 1.5, -9, -12, 0.8, "we")
			ramp(-1.5, 1.5, -12, -15, 0.8, 1.5)
			floor_rect(-1.5, 1.5, -15, -21, 1.5, "nwe")
			for k in 7:
				var a := PI * 0.5 + 0.55 + k * (TAU - 1.1) / 6.0
				bumper(cos(a) * 0.95, -18.5 + sin(a) * 0.95, 1.5, 0.2)
			set_cup(0, -18.5, 1.5)
			lolly_tree(-2.8, -7, 0, Color("#ff7a5c"))
			lolly_tree(2.8, -19, 1.5, Color("#ff9ad5"))
		6: # Loop the Loop: down the chute, round the loop, out the side
			set_tee(-0.3, -2.0, 0, PI)
			floor_rect(-0.8, 0.2, 0.5, -9, 0, "swe")
			loop(-0.3, -9, 0, 0.55, 1.2)
			floor_rect(0.4, 1.4, -9, -16, 0, "nwe")
			sand(0.4, 1.4, -12.5, -13.5, 0)
			set_cup(0.9, -15.2, 0)
			lolly_tree(-1.8, -4, 0, Color("#4fc3f7"))
			lolly_tree(2.4, -14, 0, Color("#ff6fa8"))
			for k in 4: flower(-1.4, -1 - k * 2, 0, CANDY[k + 2])
		7: # Sandy Shores: cross the pond on the plank bridge, dodge the bunkers
			set_tee(0, -2.0, 0, PI)
			floor_rect(-2, 2, 0.5, -17, 0, "nswe")
			pond(-2, -0.45, -6, -8.5, 0)
			pond(0.45, 2, -6, -8.5, 0)
			_mesh(_box_mesh(Vector3(0.9, 0.02, 2.5)), _toon(Color("#c98a4e")), Vector3(0, 0.01, -7.25))
			sand(-2, -0.5, -11.5, -14, 0)
			sand(0.6, 2, -10.5, -12.5, 0)
			sand(-0.9, 0.9, -16, -17, 0)
			bumper(0.9, -14.8, 0, 0.22)
			set_cup(0, -15.2, 0)
			lolly_tree(-3, -7, 0, Color("#ffb347"))
			lolly_tree(3, -13, 0, Color("#9b7bff"))
		8: # Grand Finale: loop, climb, then an island green in a lily pond
			set_tee(-0.3, -2.0, 0, PI)
			floor_rect(-0.8, 0.2, 0.5, -8, 0, "swe")
			loop(-0.3, -8, 0, 0.55, 1.2)
			floor_rect(0.4, 1.4, -8, -10, 0, "we")
			ramp(0.4, 1.4, -10, -13, 0, 0.7)
			floor_rect(-1.1, 2.9, -13, -21, 0.7, "nwe")
			pond(-1.1, 0.6, -15, -16, 0.7)
			pond(1.2, 2.9, -15, -16, 0.7)
			_mesh(_box_mesh(Vector3(0.6, 0.02, 1.0)), _toon(Color("#c98a4e")), Vector3(0.9, 0.71, -15.5))
			pond(-1.1, -0.1, -16, -19.5, 0.7)
			pond(1.9, 2.9, -16, -19.5, 0.7)
			sand(-0.1, 1.9, -19.5, -20.5, 0.7)
			spinner(0.9, -17.5, 0.7, 1.3, -1.1)
			set_cup(0.9, -18.6, 0.7)
			lolly_tree(-1.6, -5, 0, Color("#c06cff"))
			lolly_tree(3.6, -18, 0.7, Color("#ffb347"))

func load_hole(i: int) -> void:
	hole_i = i
	if course:
		course.queue_free()
	course = Node3D.new()
	add_child(course)
	movers.clear()
	sands.clear()
	ponds.clear()
	boosts.clear()
	water_mats.clear()
	min_y = 0.0
	wall_col = CANDY[i % CANDY.size()]
	_build_hole(i)
	_cloud_sea(Vector3(tee.x, 0, tee.z - 8))
	sunk = false
	strokes = 0
	before_putt = {}
	aim_yaw = tee_yaw
	_reset_ball(tee)
	_snap_camera()
	changed.emit()

## Resume: put the ball back where it lay.
func place(p: Vector3, s: int, yaw: float) -> void:
	strokes = s
	aim_yaw = yaw
	_reset_ball(p)
	_snap_camera()
	changed.emit()

func _snap_camera() -> void:
	cam.global_position = ball.global_position - Vector3(sin(aim_yaw), 0, cos(aim_yaw)) * 2.3 + Vector3(0, 1.3, 0)

# =====================================================================
# Ball
# =====================================================================
func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.mass = 0.046
	ball.linear_damp = 0.32
	ball.angular_damp = 0.4
	ball.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	pm.bounce = 0.4
	pm.rough = true
	ball.physics_material_override = pm
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = BALL_R
	col.shape = sh
	ball.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere(BALL_R)
	mi.material_override = _toon(Color("#fffaf0"), false)
	ball.add_child(mi)
	add_child(ball)
	aim_arrow = MeshInstance3D.new()
	aim_arrow.mesh = _box_mesh(Vector3(0.05, 0.01, 1.0))
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1, 0.9, 0.2, 0.9)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_arrow.material_override = am
	add_child(aim_arrow)

func _reset_ball(p: Vector3) -> void:
	if sink_tw and sink_tw.is_valid():
		sink_tw.kill()
	ball.freeze = true
	ball.global_position = p + Vector3(0, BALL_R + 0.01, 0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	last_rest = p
	ball.freeze = false
	still_time = 1.0

func at_rest() -> bool:
	return still_time > 0.25 and not sunk

func _physics_process(delta: float) -> void:
	time += delta
	for m in movers:
		var b: Node3D = m.body
		match m.kind:
			"spin_z": b.rotation.z += m.speed * delta
			"spin_y": b.rotation.y += m.speed * delta
			"slide_x": b.position = m.base + Vector3(sin(time * m.speed + m.phase) * m.travel, 0, 0)
			"wave": b.rotation = m.base_rot + Vector3(0, sin(time * 3.0) * 0.25, 0)
			"bob": b.position = m.base + Vector3(0, sin(time * 2.0) * 0.15, 0)
			"pulse": b.visible = fmod(time * 4.0 - m.phase, 3.0) < 1.6
	for wm in water_mats:
		(wm as StandardMaterial3D).uv1_offset = Vector3(time * 0.05, 0, time * 0.03)
	if sunk:
		return
	var was_rest := at_rest()
	var v := ball.linear_velocity.length()
	if v < STOP_SPEED:
		still_time += delta
		if still_time > 0.25 and v > 0.0:
			ball.linear_velocity = Vector3.ZERO
			ball.angular_velocity = Vector3.ZERO
			last_rest = ball.global_position - Vector3(0, BALL_R + 0.01, 0)
	else:
		still_time = 0.0
	if was_rest != at_rest():
		changed.emit()
	var bp := ball.global_position
	var bxz := Vector2(bp.x, bp.z)
	var in_sand := false
	for sd in sands:
		if (sd[0] as Rect2).has_point(bxz) and absf(bp.y - BALL_R - sd[1]) < 0.06:
			in_sand = true
	ball.linear_damp = 3.2 if in_sand else 0.32
	for bo in boosts:
		if (bo[0] as Rect2).has_point(bxz) and absf(bp.y - BALL_R - bo[1]) < 0.06:
			var dir: Vector3 = bo[2]
			if ball.linear_velocity.dot(dir) < bo[3]:
				ball.linear_velocity = dir * bo[3]
				ball.angular_velocity = Vector3.UP.cross(dir) * bo[3] / BALL_R
	for pd in ponds:
		if (pd[0] as Rect2).has_point(bxz) and absf(bp.y - BALL_R - pd[1]) < 0.08:
			_splash(bp, "Splash! Into the pond. +1")
			return
	var d: Vector3 = bp - cup
	if Vector2(d.x, d.z).length() < CUP_R and absf(d.y - BALL_R) < 0.12 and v < 1.6:
		_sink()
		return
	if bp.y < min_y - 1.5:
		_splash(Vector3.INF, "Splash into the clouds! +1")

func _splash(at: Vector3, txt: String) -> void:
	if at != Vector3.INF:
		_confetti(at, [Color("#ffffff"), Color("#bfe9ff"), Color("#7fd3ff"), Color("#3fb7ff"), Color("#ffffff")])
	strokes += 1
	_reset_ball(last_rest)
	message.emit(txt)
	changed.emit()

func _sink() -> void:
	sunk = true
	ball.freeze = true
	sink_tw = create_tween()
	sink_tw.tween_property(ball, "global_position", cup - Vector3(0, 0.1, 0), 0.25)
	_confetti(cup, [])
	holed.emit(strokes)
	changed.emit()

func _confetti(at: Vector3, cols: Array) -> void:
	var p := CPUParticles3D.new()
	p.position = at + Vector3(0, 0.2, 0)
	p.one_shot = true
	p.amount = 90
	p.lifetime = 1.8
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 50
	p.initial_velocity_min = 3
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -6, 0)
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.04)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray(cols if cols.size() == 5 else [CANDY[0], CANDY[1], CANDY[2], CANDY[3], CANDY[4]])
	p.color_initial_ramp = g
	course.add_child(p)
	p.emitting = true

func _process(delta: float) -> void:
	var fwd := Vector3(sin(aim_yaw), 0, cos(aim_yaw))
	var target := ball.global_position - fwd * 2.3 + Vector3(0, 1.3, 0)
	cam.global_position = cam.global_position.lerp(target, clampf(delta * 4.0, 0, 1))
	cam.look_at(ball.global_position + fwd * 1.5 + Vector3(0, 0.1, 0), Vector3.UP)
	var show := at_rest()
	aim_arrow.visible = show
	if show:
		var l := 0.4 + power * 1.6
		aim_arrow.scale = Vector3(1, 1, l)
		aim_arrow.global_position = ball.global_position + fwd * (BALL_R + l * 0.5) + Vector3(0, -BALL_R + 0.02, 0)
		aim_arrow.rotation = Vector3(0, aim_yaw, 0)

## Pull-back putting, fed from the game's field (local coordinates; only
## the drag distance matters). Phones send taps twice: mouse events only.
func handle_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and at_rest():
			dragging = true
			drag_start = e.position
			drag_yaw0 = aim_yaw
			power = 0.0
		elif not e.pressed and dragging:
			dragging = false
			if power > 0.03:
				putt(aim_yaw, power)
			power = 0.0
			changed.emit()
	elif e is InputEventMouseMotion and dragging:
		var dv: Vector2 = e.position - drag_start
		power = clampf(dv.y / FULL_PULL_PX, 0.0, 1.0)
		aim_yaw = drag_yaw0 - dv.x / AIM_PX_PER_RAD
		changed.emit()

func cancel_drag() -> void:
	dragging = false
	power = 0.0

func turn(amount: float) -> void:
	if not dragging:
		aim_yaw -= amount

func putt(yaw: float, p: float) -> void:
	before_putt = {"pos": last_rest, "strokes": strokes}
	aim_yaw = yaw
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	ball.linear_velocity = fwd * p * MAX_POWER
	ball.angular_velocity = Vector3.UP.cross(fwd) * p * MAX_POWER / BALL_R  # start rolling, not skidding
	still_time = 0.0
	strokes += 1
	changed.emit()

## ↩ help: the last putt never happened.
func mulligan() -> bool:
	if before_putt.is_empty() or not at_rest():
		return false
	strokes = int(before_putt.strokes)
	_reset_ball(before_putt.pos)
	before_putt = {}
	changed.emit()
	return true
