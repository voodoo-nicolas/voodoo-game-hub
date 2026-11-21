extends Node3D

## Ancient Assassins' 3D arena (lives in the game's SubViewport): a lagoon in
## the ruins of an old harbour, two rock islands, columns / a rock in the way,
## sandstone cliffs all round, the two assassins (aa_character.gd), the throw
## in flight with its trail, weapons left where they land, splashes and
## sparks, the aim ribbon, and the camera: over the shoulder of whoever the
## phone is playing (turning with the aim), a kill cam beside the victim and a
## front view of the winner. Reads the engine; never changes it.
## Kenney's Retro Fantasy Kit (CC0) gives the columns, stairs and trees.

const AaCharacter = preload("res://scripts/games/ancient_assassins/aa_character.gd")
const KENNEY := "res://games/ancient_assassins/models/kenney/"
const MAX_STUCK := 14

const WATER_SHADER := """
shader_type spatial;
uniform vec4 deep : source_color = vec4(0.05, 0.42, 0.55, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.78, 0.82, 1.0);
uniform float glow = 0.0;
void fragment() {
	vec2 w = UV * 160.0;
	float t = TIME;
	float a = sin(w.x * 0.9 + t * 1.3) + sin(w.y * 1.1 - t * 1.1) + sin((w.x + w.y) * 0.6 + t * 0.7);
	float b = cos(w.x * 1.3 - t * 0.9) + cos(w.y * 0.8 + t * 1.4);
	NORMAL_MAP = normalize(vec3(a * 0.08 + 0.5, b * 0.08 + 0.5, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.35 + 0.25 * sin(a * 0.5)) * (1.0 - fres * 0.3) + fres * vec3(0.5, 0.7, 0.85) * 0.35;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = shallow.rgb * glow * (0.3 + 0.2 * a);
}
"""

var engine
var chars: Array = []          # two AaCharacter
var char_defs: Array = []
var skull := false
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var water_mat: ShaderMaterial
var level: Node3D              # rebuilt each fight
var scenery: Node3D            # cliffs (once)
var cam: Camera3D
var proj: Node3D
var proj_w := -1
var trail: MeshInstance3D
var trail_mesh := ImmediateMesh.new()
var ribbon: MeshInstance3D
var ribbon_mesh := ImmediateMesh.new()
var flag: MeshInstance3D
var stuck_nodes: Array = []
var cam_pos := Vector3(0, 3, -4)
var cam_look := Vector3(0, 1.5, 10)
var rock_cache: Array = []
var _time := 0.0
var view3d_shake := 0.0   # 0..1, set by the game when this phone's assassin is hit

func setup(p_engine, defs: Array, p_skull: bool) -> void:
	engine = p_engine
	skull = p_skull
	_make_env()
	scenery = Node3D.new()
	add_child(scenery)
	_make_scenery()
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 52.0
	cam.near = 0.1
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	trail = _imm(trail_mesh, true)
	ribbon = _imm(ribbon_mesh, false)
	rebuild(defs)

func _imm(m: ImmediateMesh, alpha: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

# ---------- environment ----------

func _make_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_density = 0.0026
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 155, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	# A soft fill from the other side, so faces turned away from the sun aren't black.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -25, 0)
	fill.light_energy = 0.45
	fill.light_color = Color("dfe8ff")
	add_child(fill)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	water.mesh = pm
	water_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water_mat.shader = sh
	water.material_override = water_mat
	water.position = Vector3(0, 0, 20)
	add_child(water)
	_apply_sky()

func _apply_sky() -> void:
	if skull:
		sky_mat.sky_top_color = Color("07030f")
		sky_mat.sky_horizon_color = Color("3a1458")
		sky_mat.ground_horizon_color = Color("3a1458")
		sky_mat.ground_bottom_color = Color("05020a")
		sky_mat.sun_angle_max = 8.0
		env.fog_light_color = Color("2a0d40")
		env.ambient_light_energy = 0.5
		sun.light_color = Color("b9a0ff")
		sun.light_energy = 0.55
		water_mat.set_shader_parameter("deep", Color("0b0520"))
		water_mat.set_shader_parameter("shallow", Color("6a1fa8"))
		water_mat.set_shader_parameter("glow", 0.35)
	else:
		sky_mat.sky_top_color = Color("2f78d0")
		sky_mat.sky_horizon_color = Color("b4dcf2")
		sky_mat.ground_horizon_color = Color("b4dcf2")
		sky_mat.ground_bottom_color = Color("3a6a80")
		sky_mat.sun_angle_max = 30.0
		env.fog_light_color = Color("c4e2f2")
		env.ambient_light_energy = 0.85
		sun.light_color = Color("fff2dc")
		sun.light_energy = 1.25
		water_mat.set_shader_parameter("deep", Color("0b6f8e"))
		water_mat.set_shader_parameter("shallow", Color("38c6cc"))
		water_mat.set_shader_parameter("glow", 0.0)

func set_skull(on: bool) -> void:
	skull = on
	_apply_sky()
	for i in chars.size():
		chars[i].set_skull(on, char_defs[i])
	rebuild_level()

## A lumpy, flat-shaded rock (cached shapes, scaled per use).
func _rock_mesh(k: int) -> ArrayMesh:
	while rock_cache.size() <= k:
		var noise := FastNoiseLite.new()
		noise.seed = 31 + rock_cache.size() * 17
		noise.frequency = 1.6
		var sm := SphereMesh.new()
		sm.radial_segments = 14
		sm.rings = 9
		var arrays := sm.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts.size():
			var p := verts[v]
			var n := noise.get_noise_3d(p.x, p.y, p.z)
			p *= 1.0 + n * 0.45
			if p.y < -0.2:
				p.y = -0.2 - (p.y + 0.2) * 0.2
			verts[v] = p
		arrays[Mesh.ARRAY_VERTEX] = verts
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var st := SurfaceTool.new()
		st.create_from(am, 0)
		st.deindex()
		st.generate_normals(false)
		rock_cache.append(st.commit())
	return rock_cache[k]

func _rock_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	if skull:
		m.albedo_color = col.darkened(0.75)
		m.emission_enabled = true
		m.emission = Color("ff2bd6") * 0.08
	return m

func _make_scenery() -> void:
	for c in scenery.get_children():
		c.queue_free()
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	# A ring of sandstone cliffs round the lagoon, open behind the camera.
	for k in 26:
		var a := lerpf(-1.25, 1.25, k / 25.0) * PI * 0.62
		var dist := r.randf_range(55.0, 95.0)
		var p := Vector3(sin(a) * dist, 0, 14.0 + cos(a) * dist)
		var rock := MeshInstance3D.new()
		rock.mesh = _rock_mesh(k % 4)
		var h := r.randf_range(10.0, 32.0)
		var w := r.randf_range(9.0, 18.0)
		rock.scale = Vector3(w, h, w * r.randf_range(0.7, 1.2))
		rock.position = p + Vector3(0, h * 0.18, 0)
		rock.rotation.y = r.randf() * TAU
		rock.material_override = _rock_mat(Color("c79a68").lerp(Color("9c6f4a"), r.randf()))
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scenery.add_child(rock)
		if r.randf() < 0.45:
			_kenney(scenery, "tree-large", p + Vector3(r.randf_range(-2, 2), h * 0.7, r.randf_range(-2, 2)), r.randf_range(3.0, 5.0), r.randf() * TAU)

func _kenney(parent: Node3D, name: String, pos: Vector3, s: float, rot: float) -> Node3D:
	var path := KENNEY + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * s
	n.rotation.y = rot
	parent.add_child(n)
	if skull:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("140a22")
			m.emission_enabled = true
			m.emission = Color("29e6ff") * 0.25
			mi.material_override = m
	return n

# ---------- the level ----------

func rebuild(defs: Array) -> void:
	char_defs = defs
	for c in chars:
		c.queue_free()
	chars = []
	for i in 2:
		var a = AaCharacter.new()
		add_child(a)
		a.build(defs[i], skull)
		chars.append(a)
	rebuild_level()

func rebuild_level() -> void:
	if level:
		level.queue_free()
	level = Node3D.new()
	add_child(level)
	stuck_nodes = []
	var r := RandomNumberGenerator.new()
	r.seed = engine.seed_ + 5
	for k in engine.islands.size():
		var isl: Dictionary = engine.islands[k]
		var c := Vector3(isl.x, 0, isl.z)
		var top: float = isl.top
		var base := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = isl.r
		cm.bottom_radius = isl.r * 1.35
		cm.height = top + 4.0
		cm.radial_segments = 20
		base.mesh = cm
		base.position = c + Vector3(0, (top - 4.0) / 2.0, 0)
		base.material_override = _rock_mat(Color("b48c62"))
		level.add_child(base)
		# Rough rocks round the foot, grass on top, sand edge.
		for j in 6:
			var a := TAU * j / 6.0 + r.randf()
			var rk := MeshInstance3D.new()
			rk.mesh = _rock_mesh(j % 4)
			var s := r.randf_range(0.8, 1.6)
			rk.scale = Vector3(s * 1.4, s * (top + 0.6) * 0.6, s * 1.4)
			rk.position = c + Vector3(cos(a), 0, sin(a)) * isl.r * 1.05
			rk.material_override = _rock_mat(Color("a57c55"))
			level.add_child(rk)
		var grass := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = isl.r * 0.97
		gm.bottom_radius = isl.r * 0.99
		gm.height = 0.1
		gm.radial_segments = 20
		grass.mesh = gm
		grass.position = c + Vector3(0, top + 0.02, 0)
		var g := StandardMaterial3D.new()
		g.albedo_color = Color("5f9e3a") if not skull else Color("12301a")
		g.roughness = 1.0
		if skull:
			g.emission_enabled = true
			g.emission = Color("7dff3a") * 0.12
		grass.material_override = g
		level.add_child(grass)
		# Decor behind each fighter: a column, a shrub, a tree.
		var fw: Vector3 = engine.forward(k)
		var side := fw.cross(Vector3.UP)
		if k == 0:   # the near island: decor to her left, away from the camera (over her right shoulder)
			_kenney(level, "column-damaged", c + Vector3(0, top, 0) + fw * 0.9 - side * 2.5, 1.0, r.randf() * TAU)
			_kenney(level, "tree-shrub", c + Vector3(0, top, 0) - fw * 0.6 - side * 2.4, 1.3, r.randf() * TAU)
		else:
			_kenney(level, "column-damaged", c + Vector3(0, top, 0) - fw * 2.1 + side * 1.6, 1.0, r.randf() * TAU)
			_kenney(level, "tree-shrub", c + Vector3(0, top, 0) - fw * 1.8 - side * 1.7, 1.3, r.randf() * TAU)
		if k == 1:
			_kenney(level, "tree-large", c + Vector3(0, top, 0) - fw * 2.4 - side * 0.6, 2.2, r.randf() * TAU)
	for b in engine.blocks:
		if b.kind == "column":
			var col := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = b.r * 0.85
			cc.bottom_radius = b.r
			cc.height = b.top + 2.0
			cc.radial_segments = 12
			col.mesh = cc
			col.position = Vector3(b.x, (b.top - 2.0) / 2.0, b.z)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("e2d2b4") if not skull else Color("140a22")
			m.roughness = 0.8
			if skull:
				m.emission_enabled = true
				m.emission = Color("29e6ff") * 0.5
			col.material_override = m
			level.add_child(col)
			var cap := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(b.r * 2.6, 0.28, b.r * 2.6)
			cap.mesh = bm
			cap.position = Vector3(b.x, b.top + 0.14, b.z)
			cap.material_override = m
			level.add_child(cap)
			var foot := MeshInstance3D.new()
			foot.mesh = _rock_mesh(2)
			foot.scale = Vector3(1.4, 0.9, 1.4)
			foot.position = Vector3(b.x, 0.1, b.z)
			foot.material_override = _rock_mat(Color("a57c55"))
			level.add_child(foot)
		else:
			var rk := MeshInstance3D.new()
			rk.mesh = _rock_mesh(1)
			rk.scale = Vector3(b.r, b.top * 0.85, b.r)
			rk.position = Vector3(b.x, 0, b.z)
			rk.material_override = _rock_mat(Color("c09060"))
			level.add_child(rk)
	# A pennant on the near island: it streams the way the wind blows.
	flag = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.55, 0.28)
	flag.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("d42a2a") if not skull else Color("ff2bd6")
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	if skull:
		fm.emission_enabled = true
		fm.emission = Color("ff2bd6") * 0.6
	flag.material_override = fm
	level.add_child(flag)
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.03
	pc.bottom_radius = 0.04
	pc.height = 2.4
	pole.mesh = pc
	var fw0: Vector3 = engine.forward(0)
	var pole_at: Vector3 = engine.feet(0) + fw0 * 2.4 - fw0.cross(Vector3.UP) * 2.6
	pole.position = pole_at + Vector3(0, 1.2, 0)
	pole.material_override = _rock_mat(Color("3a2a1a"))
	level.add_child(pole)
	flag.set_meta("pole", pole_at + Vector3(0, 2.25, 0))
	for i in 2:
		chars[i].position = engine.feet(i)
		_face(i, engine.forward(i))

func _face(i: int, dir: Vector3) -> void:
	chars[i].rotation.y = atan2(dir.x, dir.z)

# ---------- weapons ----------

## A weapon model pointing along -Z (look_at friendly), centred on its grip.
func weapon_mesh(w: int) -> Node3D:
	var n := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a5a2a")
	wood.roughness = 0.8
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("d9c08a") if w == 0 else Color("cfd6e0")
	metal.metallic = 0.85
	metal.roughness = 0.3
	if skull:
		metal.emission_enabled = true
		metal.emission = Color("29e6ff") * 0.8
	match w:
		0:
			var shaft := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.016
			c.bottom_radius = 0.016
			c.height = 1.5
			c.radial_segments = 6
			shaft.mesh = c
			shaft.rotation.x = PI / 2.0
			shaft.material_override = wood
			n.add_child(shaft)
			var tip := MeshInstance3D.new()
			var t := CylinderMesh.new()
			t.top_radius = 0.0
			t.bottom_radius = 0.035
			t.height = 0.2
			t.radial_segments = 6
			tip.mesh = t
			tip.rotation.x = -PI / 2.0
			tip.position = Vector3(0, 0, -0.84)
			tip.material_override = metal
			n.add_child(tip)
			var band := MeshInstance3D.new()
			var b := CylinderMesh.new()
			b.top_radius = 0.022
			b.bottom_radius = 0.022
			b.height = 0.12
			band.mesh = b
			band.rotation.x = PI / 2.0
			band.position = Vector3(0, 0, 0.1)
			var red := StandardMaterial3D.new()
			red.albedo_color = Color("c0302a")
			band.material_override = red
			n.add_child(band)
		1:
			var handle := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.022
			c.height = 0.5
			handle.mesh = c
			handle.material_override = wood
			n.add_child(handle)
			var head := MeshInstance3D.new()
			var p := PrismMesh.new()
			p.size = Vector3(0.22, 0.2, 0.03)
			head.mesh = p
			head.rotation.z = -PI / 2.0
			head.position = Vector3(0.1, 0.18, 0)
			head.material_override = metal
			n.add_child(head)
		_:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.1
			tm.outer_radius = 0.14
			tm.rings = 24
			tm.ring_segments = 6
			ring.mesh = tm
			ring.material_override = metal
			n.add_child(ring)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n

func show_projectile(w: int) -> void:
	hide_projectile()
	proj = weapon_mesh(w)
	proj_w = w
	proj.scale = Vector3.ONE * 1.6   # reads better far away
	add_child(proj)

func hide_projectile() -> void:
	if proj:
		proj.queue_free()
	proj = null
	trail_mesh.clear_surfaces()

## A weapon left where it landed (not on people).
func leave_stuck(p: Vector3, v: Vector3, w: int, surface: String) -> void:
	if surface == "water":
		return
	var n := weapon_mesh(w)
	add_child(n)
	var dir := v.normalized()
	n.position = p + dir * (0.35 if w == 0 else 0.05)
	if dir.length() > 0.1:
		n.look_at(n.position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	stuck_nodes.append(n)
	if stuck_nodes.size() > MAX_STUCK:
		stuck_nodes.pop_front().queue_free()

# ---------- effects ----------

func burst(p: Vector3, kind: String) -> void:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.explosiveness = 0.95
	ps.emitting = false
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 6
	sm.rings = 3
	ps.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	sm.material = m
	ps.gravity = Vector3(0, -9.8, 0)
	match kind:
		"water":
			ps.amount = 40
			ps.lifetime = 1.0
			ps.direction = Vector3.UP
			ps.spread = 22.0
			ps.initial_velocity_min = 3.0
			ps.initial_velocity_max = 6.5
			ps.color = Color(0.85, 0.95, 1.0)
			ps.scale_amount_min = 1.0
			ps.scale_amount_max = 2.2
		"ground":
			ps.amount = 22
			ps.lifetime = 0.7
			ps.direction = Vector3.UP
			ps.spread = 60.0
			ps.initial_velocity_min = 1.0
			ps.initial_velocity_max = 2.5
			ps.color = Color("c9a26a")
			ps.scale_amount_max = 2.0
		"hit_head":
			ps.amount = 40
			ps.lifetime = 0.6
			ps.spread = 180.0
			ps.initial_velocity_min = 2.0
			ps.initial_velocity_max = 5.0
			ps.color = Color("ffd04a")
		_:  # stone, hit
			ps.amount = 24
			ps.lifetime = 0.5
			ps.spread = 180.0
			ps.initial_velocity_min = 1.5
			ps.initial_velocity_max = 4.0
			ps.color = Color(1, 0.95, 0.8)
	if skull:
		ps.color = Color("29e6ff") if kind != "hit_head" else Color("ff2bd6")
	ps.position = p
	add_child(ps)
	ps.emitting = true
	var tw := ps.create_tween()
	tw.tween_interval(ps.lifetime + 0.3)
	tw.tween_callback(ps.queue_free)

# ---------- per frame ----------

## st: "view" (seat the camera follows), "aiming" (seat aiming or -1),
## "show_ribbon", "eagle" (bool), "kill" (victim or -1), "winner", "zoom" 0..1.
func tick(delta: float, st: Dictionary) -> void:
	_time += delta
	var view: int = st.get("view", 0)
	var aiming: int = st.get("aiming", -1)
	# Who faces where.
	for i in 2:
		var dir: Vector3 = engine.forward(i)
		if aiming == i or (not engine.shot.is_empty() and engine.shot.owner == i):
			dir = engine.direction(i, engine.yaw_of(i), 0.0)
		var target_rot := atan2(dir.x, dir.z)
		chars[i].rotation.y = lerp_angle(chars[i].rotation.y, target_rot, minf(1.0, delta * 10.0))
		chars[i].set_wind(engine.wind / engine.WIND_MAX)
	# The flag.
	if flag and flag.has_meta("pole"):
		var wv: float = engine.wind / engine.WIND_MAX
		var top: Vector3 = flag.get_meta("pole")
		var stream := Vector3(signf(wv) if absf(wv) > 0.05 else 0.2, -(1.0 - absf(wv)) * 0.9, 0.15).normalized()
		flag.position = top + stream * 0.3
		flag.look_at(flag.position + Vector3(0, 0, 1), Vector3.UP)
		flag.rotation.z = -atan2(stream.y, stream.x) + sin(_time * (5.0 + 8.0 * absf(wv))) * 0.08
	# The throw in flight.
	if proj and not engine.shot.is_empty():
		var s: Dictionary = engine.shot
		proj.position = s.p
		var v: Vector3 = s.v
		match proj_w:
			0:
				proj.look_at(proj.position + v, Vector3.UP)
			1:
				proj.look_at(proj.position + Vector3(v.x, 0, v.z), Vector3.UP)
				proj.rotate_object_local(Vector3.RIGHT, -s.age * 16.0)
			_:
				proj.rotation = Vector3(0.1, s.age * 25.0, 0.0)
		_draw_trail(s.trail, s.p)
	_draw_ribbon(st)
	_camera(delta, st, view)

func _draw_trail(pts: Array, head: Vector3) -> void:
	trail_mesh.clear_surfaces()
	var all: Array = pts.duplicate()
	all.append(head)
	if all.size() < 2:
		return
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := all.size()
	for k in n:
		var p: Vector3 = all[k]
		var a := float(k) / (n - 1)
		var c := Color(1, 1, 1, a * 0.8) if not skull else Color(0.16, 0.9, 1.0, a * 0.85)
		var w := 0.02 + a * 0.06
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_add_vertex(p + Vector3(0, w, 0))
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_add_vertex(p - Vector3(0, w, 0))
	trail_mesh.surface_end()

## The aim ribbon: striped, the first stretch of the arc without the wind;
## gold dots all the way with the wind when 🦅 Eagle Eye is on.
func _draw_ribbon(st: Dictionary) -> void:
	ribbon_mesh.clear_surfaces()
	var i: int = st.get("aiming", -1)
	if i < 0 or not st.get("show_ribbon", false):
		return
	var w: int = engine.fighters[i].weapon
	var wpn: Dictionary = engine.WEAPONS[w]
	var v: Vector3 = engine.direction(i, engine.yaw_of(i), engine.angle_of(i)) * float(wpn.speed)
	var p0: Vector3 = engine.hand(i)
	var pts: Array = []
	for k in 26:
		var t := 0.06 + k * 0.03
		pts.append(p0 + v * t + Vector3(0, -0.5 * float(wpn.g) * t * t, 0))
	var side: Vector3 = engine.forward(i).cross(Vector3.UP).normalized()
	ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var col := (Color(1, 1, 1) if k % 2 == 0 else Color("6fd8ff")) if not skull else (Color("29e6ff") if k % 2 == 0 else Color("ff2bd6"))
		var wdt := 0.06 - k * 0.0015
		_quad(a - side * wdt, a + side * wdt, b + side * wdt, b - side * wdt, col)
	if st.get("eagle", false):
		var path: PackedVector3Array = engine.path(i, w)
		for k in range(0, path.size(), 2):
			var c: Vector3 = path[k]
			_quad(c - side * 0.07 + Vector3(0, 0.07, 0), c + side * 0.07 + Vector3(0, 0.07, 0), c + side * 0.07 - Vector3(0, 0.07, 0), c - side * 0.07 - Vector3(0, 0.07, 0), Color("ffc24a"))
	ribbon_mesh.surface_end()

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for p in [a, b, c, a, c, d]:
		ribbon_mesh.surface_set_color(col)
		ribbon_mesh.surface_add_vertex(p)

func _camera(delta: float, st: Dictionary, view: int) -> void:
	var kill: int = st.get("kill", -1)
	var winner: int = st.get("winner", -1)
	var zoom: float = st.get("zoom", 0.0)
	var want_pos: Vector3
	var want_look: Vector3
	var f: Vector3 = engine.feet(view)
	var fw: Vector3 = engine.direction(view, engine.yaw_of(view) * 0.85, 0.0) if st.get("aiming", -1) == view else engine.forward(view)
	var right := fw.cross(Vector3.UP).normalized()
	want_pos = f + Vector3(0, 2.4, 0) + right * 1.0 - fw * 3.7
	want_look = f + Vector3(0, 1.0, 0) + fw * 20.0 + right * 0.3
	if kill >= 0 and zoom > 0.0:
		var vf: Vector3 = engine.feet(kill)
		var toward: Vector3 = engine.forward(kill)
		var side := toward.cross(Vector3.UP).normalized()
		var kp := vf + Vector3(0, 1.5, 0) + side * 2.6 + toward * 1.6
		var kl := vf + Vector3(0, 1.1, 0)
		if not engine.shot.is_empty():
			kl = kl.lerp(engine.shot.p, 0.35)
		want_pos = want_pos.lerp(kp, zoom)
		want_look = want_look.lerp(kl, zoom)
	elif winner >= 0:
		var wf: Vector3 = engine.feet(winner)
		var wfw: Vector3 = engine.forward(winner)
		want_pos = wf + Vector3(0, 1.45, 0) + wfw * 3.4 + wfw.cross(Vector3.UP) * 0.8
		want_look = wf + Vector3(0, 1.05, 0)
	var k := minf(1.0, delta * (3.0 if kill >= 0 or winner >= 0 else 6.0))
	cam_pos = cam_pos.lerp(want_pos, k)
	cam_look = cam_look.lerp(want_look, k)
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * view3d_shake * 0.06
	cam.position = cam_pos + jolt
	if cam_pos.distance_to(cam_look) > 0.01:
		cam.look_at(cam_look + jolt, Vector3.UP)

## Jumps the camera straight to where it's going (new fight, new view).
func snap_camera(view: int) -> void:
	var f: Vector3 = engine.feet(view)
	var fw: Vector3 = engine.forward(view)
	var right := fw.cross(Vector3.UP).normalized()
	cam_pos = f + Vector3(0, 2.4, 0) + right * 1.0 - fw * 3.7
	cam_look = f + Vector3(0, 1.0, 0) + fw * 20.0 + right * 0.3
	cam.position = cam_pos
	cam.look_at(cam_look, Vector3.UP)

## Screen point of a world point (for the HUD's floating numbers); null when behind.
func screen_of(p: Vector3):
	if cam.is_position_behind(p):
		return null
	return cam.unproject_position(p)
