extends Node3D

## Ancient Assassins' 3D arena (lives in the game's SubViewport): a lagoon in
## the ruins of an old harbour, two rock islands, columns / a rock in the way,
## sandstone cliffs and far mountains, the two assassins (aa_character.gd).
##
## Look (2026-11-23 visual pass): each map style has its own time of day
## (MOODS: noon lagoon, golden-hour ruins, dusk cliffs; Skull mode = night),
## a procedural sky with clouds drifting with the wind, water with shoreline
## foam round every rock, glints and sparkles, rocks with strata / moss / wet
## waterline, grass with swaying blades, gulls, pollen and leaves riding the
## wind, a sailboat on the horizon, glow + colour grade. Effects: soft dust,
## splash columns with ripple rings, sparks, flashes, shock rings, glowing
## camera-facing trails, victory petals. Camera: an intro flyover (rival ->
## your shoulder), a breathing shoulder cam, kill cam, winner view.
## Reads the engine; never changes it. Kenney's Retro Fantasy Kit (CC0) gives
## the columns and trees. All shaders are short, no screen-space passes
## (Android, Mobile renderer).

const AaCharacter = preload("res://scripts/games/ancient_assassins/aa_character.gd")
const KENNEY := "res://games/ancient_assassins/models/kenney/"
const MAX_STUCK := 14
const MAX_FOAM := 8
const INTRO_LEN := 2.8

## Time of day per map style. sun: [elevation, azimuth] degrees (azimuth 0 =
## behind the near island, looking down the lagoon).
const MOODS := [
	{"name": "noon", "top": Color("1b62c4"), "horizon": Color("a8dcf4"), "ground": Color("2a6a86"),
		"sun": [55.0, 35.0], "sun_col": Color("fff4e0"), "sun_e": 1.35, "fill_e": 0.45, "amb": 0.8,
		"fog": Color("bfe2f4"), "fog_d": 0.0022, "deep": Color("064b70"), "shallow": Color("27c4c0"),
		"rock": Color("9c9a82"), "grass": Color("4f9a30"), "cloud": 0.42, "exposure": 1.0, "sat": 1.12},
	{"name": "golden", "top": Color("2f4f94"), "horizon": Color("ffb877"), "ground": Color("3a4a5a"),
		"sun": [16.0, 110.0], "sun_col": Color("ffc47e"), "sun_e": 1.55, "fill_e": 0.5, "amb": 0.7,
		"fog": Color("f0b88a"), "fog_d": 0.0034, "deep": Color("0d3b5a"), "shallow": Color("2f9ea6"),
		"rock": Color("a8916c"), "grass": Color("6a9a2e"), "cloud": 0.5, "exposure": 1.02, "sat": 1.18},
	{"name": "dusk", "top": Color("221a4a"), "horizon": Color("ff8a7a"), "ground": Color("2a2440"),
		"sun": [7.0, 160.0], "sun_col": Color("ff9a66"), "sun_e": 1.2, "fill_e": 0.6, "amb": 0.6,
		"fog": Color("c87488"), "fog_d": 0.004, "deep": Color("142446"), "shallow": Color("3a6f9a"),
		"rock": Color("94786a"), "grass": Color("4e7e36"), "cloud": 0.55, "exposure": 1.05, "sat": 1.15},
]
const NIGHT := {"name": "night", "top": Color("05020c"), "horizon": Color("3a1458"), "ground": Color("05020a"),
	"sun": [28.0, 25.0], "sun_col": Color("b9a0ff"), "sun_e": 0.55, "fill_e": 0.45, "amb": 0.5,
	"fog": Color("2a0d40"), "fog_d": 0.004, "deep": Color("0b0520"), "shallow": Color("6a1fa8"),
	"rock": Color("5a3a6a"), "grass": Color("1e4a2a"), "cloud": 0.35, "exposure": 1.0, "sat": 1.2}

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 ground_color : source_color;
uniform vec3 sun_color : source_color;
uniform float cloud_cover = 0.45;
uniform vec2 wind = vec2(0.02, 0.0);
uniform float stars = 0.0;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * n2(p); p *= 2.03; a *= 0.5; } return v; }
void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.5));
	col = mix(col, ground_color, smoothstep(0.0, -0.15, h));
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += sun_color * (pow(s, 6.0) * 0.28 + pow(s, 90.0) * 0.8);
	col += sun_color * smoothstep(0.9993, 0.9997, s) * 6.0;
	if (!AT_CUBEMAP_PASS && h > 0.0) {
		vec2 uv = d.xz / (h + 0.12);
		vec2 drift = wind * TIME;
		float c1 = fbm(uv * 0.9 + drift);
		float c2 = fbm(uv * 2.3 - drift * 1.7 + 7.0);
		float c = smoothstep(1.0 - cloud_cover, 1.25 - cloud_cover, c1 * 0.75 + c2 * 0.35);
		float lit = clamp(0.55 + (c1 - c2) * 0.9, 0.0, 1.0);
		vec3 cc = mix(horizon_color * 0.75, sun_color * 1.05 + vec3(0.12), lit);
		cc += sun_color * pow(s, 8.0) * 0.6;
		col = mix(col, cc, c * smoothstep(0.0, 0.18, h) * 0.92);
	}
	if (stars > 0.0 && h > 0.0) {
		vec2 g = floor(d.xz / (h + 0.3) * 90.0);
		float st = step(0.996, h21(g)) * (0.6 + 0.4 * sin(TIME * 3.0 + h21(g + 3.0) * 40.0));
		col += vec3(st) * stars * smoothstep(0.05, 0.3, h);
	}
	COLOR = col;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 deep : source_color;
uniform vec4 shallow : source_color;
uniform vec4 sky_tint : source_color;
uniform sampler2D wave_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 foam_c[8];   // x, z, radius, 1 = used
uniform vec2 wind = vec2(0.0);
uniform float glow = 0.0;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wp.xz;
	vec3 na = texture(wave_a, uv * 0.045 + vec2(TIME * 0.012, TIME * 0.008) + wind * TIME * 0.01).rgb;
	vec3 nb = texture(wave_b, uv * 0.11 - vec2(TIME * 0.02, -TIME * 0.015)).rgb;
	NORMAL_MAP = normalize(mix(na, nb, 0.45));
	NORMAL_MAP_DEPTH = 0.9;
	float near = 99.0;
	for (int i = 0; i < 8; i++) {
		if (foam_c[i].w > 0.5) { near = min(near, length(uv - foam_c[i].xy) - foam_c[i].z); }
	}
	float sh = 1.0 - smoothstep(0.0, 5.0, near);
	vec3 col = mix(deep.rgb, shallow.rgb, sh * 0.85 + 0.12);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_tint.rgb, fres * 0.65);
	float jag = (na.r + nb.g) - 1.0;
	float rim = 1.0 - smoothstep(0.0, 0.55, near + jag * 0.35);
	float wave = smoothstep(0.75, 1.0, sin((near - TIME * 0.45) * 5.5) * 0.5 + 0.5) * (1.0 - smoothstep(0.3, 2.2, near));
	float foam = clamp(rim + wave * 0.55, 0.0, 1.0);
	vec2 cell = uv * 9.0;
	float spark = step(0.993, h21(floor(cell) + floor(TIME * 2.0))) * smoothstep(0.12, 0.0, length(fract(cell) - 0.5)) * 1.6;
	ALBEDO = mix(col, vec3(0.95, 0.98, 1.0), foam * 0.85);
	ROUGHNESS = mix(0.03, 0.6, foam);
	SPECULAR = 0.65;
	EMISSION = vec3(spark) * 0.8 + shallow.rgb * glow * (0.25 + sh * 0.5) + vec3(foam) * glow * 0.6;
}
"""

const ROCK_SHADER := """
shader_type spatial;
uniform vec4 base : source_color;
uniform vec4 moss : source_color = vec4(0.33, 0.48, 0.2, 1.0);
uniform float moss_amt = 1.0;
uniform float glow = 0.0;
uniform vec4 glow_col : source_color = vec4(1.0, 0.17, 0.84, 1.0);
varying vec3 wp;
varying vec3 wn;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec3 b = abs(wn); b /= (b.x + b.y + b.z);
	float n = n2(wp.zy * 1.7) * b.x + n2(wp.xz * 1.7) * b.y + n2(wp.xy * 1.7) * b.z;
	float fine = n2(wp.xz * 9.0 + wp.y * 3.0);
	float strata = sin(wp.y * 4.2 + n * 3.0) * 0.5 + 0.5;
	vec3 col = base.rgb * (0.72 + 0.28 * strata) * (0.85 + 0.3 * n) * (0.92 + 0.16 * fine);
	float top = smoothstep(0.55, 0.85, wn.y) * smoothstep(0.35, 0.6, n) * moss_amt;
	col = mix(col, moss.rgb * (0.8 + 0.4 * fine), top);
	float wet = 1.0 - smoothstep(0.0, 0.7, wp.y);
	col *= 1.0 - 0.45 * wet;
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.35, wet);
	EMISSION = glow_col.rgb * glow * (0.15 + 0.35 * strata);
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base : source_color;
uniform vec2 wind = vec2(0.0);
uniform float glow = 0.0;
varying float tip;
varying vec3 wp;
void vertex() {
	tip = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 2.3 + w.x * 1.7 + w.z * 1.3) * 0.06 + sin(TIME * 5.1 + w.z * 4.0) * 0.015;
	VERTEX.x += (sway + wind.x * 0.12) * tip;
	VERTEX.z += (sway * 0.6 + wind.y * 0.12) * tip;
	wp = w;
}
void fragment() {
	vec3 col = base.rgb * mix(0.75, 1.25, tip) * (0.92 + 0.16 * sin(wp.x * 3.1 + wp.z * 2.3));
	ALBEDO = col;
	ROUGHNESS = 0.8;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);   // lit like the ground: no dark backs
	BACKLIGHT = vec3(0.25, 0.35, 0.1) * tip;
	EMISSION = base.rgb * glow * tip;
}
"""

const GROUND_SHADER := """
shader_type spatial;
uniform vec4 base : source_color;
uniform vec4 sand : source_color = vec4(0.86, 0.76, 0.55, 1.0);
uniform vec3 centre = vec3(0.0);
uniform float radius = 3.0;
uniform float glow = 0.0;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = n2(wp.xz * 1.3) * 0.6 + n2(wp.xz * 5.0) * 0.3 + n2(wp.xz * 19.0) * 0.1;
	vec3 g = base.rgb * (0.7 + 0.55 * n);
	g = mix(g, g * vec3(1.15, 1.05, 0.6), smoothstep(0.6, 0.8, n2(wp.xz * 0.7 + 4.0)) * 0.6);
	float r = length(wp.xz - centre.xz) / radius;
	float edge = smoothstep(0.82 + n * 0.08, 0.97, r);
	ALBEDO = mix(g, sand.rgb * (0.85 + 0.3 * n), edge);
	ROUGHNESS = 0.95;
	EMISSION = base.rgb * glow * (0.4 + n);
}
"""

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float core = smoothstep(0.55, 1.0, across);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), core) * 1.4;
	ALPHA = COLOR.a * (pow(across, 1.4) * 0.75 + core * 0.4);
}
"""

var engine
var chars: Array = []          # two AaCharacter
var char_defs: Array = []
var skull := false
var mood: Dictionary = MOODS[0]
var env: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var sky_mat: ShaderMaterial
var water_mat: ShaderMaterial
var rock_mat_cache: Dictionary = {}
var level: Node3D              # rebuilt each fight
var scenery: Node3D            # cliffs, mountains, boat, gulls
var cam: Camera3D
var chase_p := Vector3.ZERO     # the throw's head (then where it landed)
var chase_dir := Vector3.ZERO   # its flat heading
var proj: Node3D
var proj_w := -1
var trail: MeshInstance3D
var trail_mesh := ImmediateMesh.new()
var ribbon: MeshInstance3D
var ribbon_mesh := ImmediateMesh.new()
var flag: MeshInstance3D
var stuck_nodes: Array = []
var gulls: Array = []          # [node, centre, radius, height, speed, phase, wings]
var boat: Node3D
var pollen: CPUParticles3D
var leaves: CPUParticles3D
var petals: CPUParticles3D
var grass_mats: Array = []
var cam_pos := Vector3(0, 3, -4)
var cam_look := Vector3(0, 1.5, 10)
var rock_cache: Array = []
var soft_tex: Texture2D
var _time := 0.0
var view3d_shake := 0.0        # 0..1, set by the game when this phone's assassin is hit
var intro_t := -1.0            # >= 0 while the intro flyover runs (0..INTRO_LEN)
var intro_view := 0

func setup(p_engine, defs: Array, p_skull: bool) -> void:
	engine = p_engine
	skull = p_skull
	soft_tex = _make_soft_tex()
	_make_env()
	scenery = Node3D.new()
	add_child(scenery)
	_make_scenery()
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 52.0
	cam.near = 0.1
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	trail = _imm(trail_mesh, true)
	ribbon = _imm(ribbon_mesh, false)
	_make_ambient()
	rebuild(defs)

## A soft round spot (64 px), for every particle.
func _make_soft_tex() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)

func _imm(m: ImmediateMesh, glow_trail: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if glow_trail:
		var sm := ShaderMaterial.new()
		sm.shader = _shader(TRAIL_SHADER)
		mi.material_override = sm
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

static var _shaders: Dictionary = {}
func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]

# ---------- environment ----------

func _make_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = _shader(SKY_SHADER)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.light_color = Color("dfe8ff")
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # the sky shader's LIGHT0 is the sun
	add_child(fill)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	water.mesh = pm
	water_mat = ShaderMaterial.new()
	water_mat.shader = _shader(WATER_SHADER)
	# Wave normal maps, made here and now (NoiseTexture2D builds on a thread; the web build has none).
	for k in 2:
		var fn := FastNoiseLite.new()
		fn.seed = 7 + k * 13
		fn.frequency = 0.03 if k == 0 else 0.06
		fn.fractal_octaves = 3
		var img := fn.get_seamless_image(128, 128, false, false, 0.1, true)
		img.convert(Image.FORMAT_RGBA8)
		img.bump_map_to_normal_map(6.0 if k == 0 else 3.0)
		img.generate_mipmaps()
		water_mat.set_shader_parameter("wave_a" if k == 0 else "wave_b", ImageTexture.create_from_image(img))
	water.material_override = water_mat
	water.position = Vector3(0, 0, 25)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

## Lighting, sky, water and colour grade for this fight's mood.
func _apply_mood() -> void:
	mood = NIGHT if skull else MOODS[clampi(int(engine.style), 0, MOODS.size() - 1)]
	var m := mood
	sky_mat.set_shader_parameter("top_color", m.top)
	sky_mat.set_shader_parameter("horizon_color", m.horizon)
	sky_mat.set_shader_parameter("ground_color", m.ground)
	sky_mat.set_shader_parameter("sun_color", m.sun_col)
	sky_mat.set_shader_parameter("cloud_cover", m.cloud)
	sky_mat.set_shader_parameter("stars", 1.0 if skull else 0.0)
	# Sun direction: elevation / azimuth, measured round the lagoon's axis.
	var el := deg_to_rad(m.sun[0])
	var az := deg_to_rad(m.sun[1])
	var to_sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = m.sun_col
	sun.light_energy = m.sun_e
	var to_fill := Vector3(-to_sun.x, 0.5, -to_sun.z).normalized()
	fill.look_at_from_position(Vector3.ZERO, -to_fill, Vector3.UP)
	fill.light_energy = m.fill_e
	fill.light_color = (m.horizon as Color).lerp(Color.WHITE, 0.5)
	env.ambient_light_energy = m.amb
	env.fog_light_color = m.fog
	env.fog_density = m.fog_d
	env.tonemap_exposure = m.exposure
	env.adjustment_saturation = m.sat
	water_mat.set_shader_parameter("deep", m.deep)
	water_mat.set_shader_parameter("shallow", m.shallow)
	water_mat.set_shader_parameter("sky_tint", (m.horizon as Color).lerp(m.top, 0.35))
	water_mat.set_shader_parameter("glow", 0.45 if skull else 0.0)
	var foam: Array = []
	for isl in engine.islands:
		foam.append(Vector4(isl.x, isl.z, isl.r * 1.12, 1.0))
	for b in engine.blocks:
		foam.append(Vector4(b.x, b.z, b.r * (1.25 if b.kind == "column" else 0.9), 1.0))
	while foam.size() < MAX_FOAM:
		foam.append(Vector4(0, 0, 0, 0))
	water_mat.set_shader_parameter("foam_c", PackedVector4Array(foam.slice(0, MAX_FOAM)))
	rock_mat_cache.clear()

func set_skull(on: bool) -> void:
	skull = on
	for i in chars.size():
		chars[i].set_skull(on, char_defs[i])
	_make_scenery()
	rebuild_level()

## A lumpy, flat-shaded rock (cached shapes, scaled per use).
func _rock_mesh(k: int) -> ArrayMesh:
	while rock_cache.size() <= k:
		var noise := FastNoiseLite.new()
		noise.seed = 31 + rock_cache.size() * 17
		noise.frequency = 1.6
		var sm := SphereMesh.new()
		sm.radial_segments = 16
		sm.rings = 10
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

## Rock material: strata, moss on top, darker and wet at the waterline.
func _rock_mat(tint: float = 0.0, moss: float = 1.0) -> ShaderMaterial:
	var key := "%s_%s_%s" % [tint, moss, skull]
	if rock_mat_cache.has(key):
		return rock_mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = _shader(ROCK_SHADER)
	var base: Color = (mood.rock as Color).darkened(tint) if tint >= 0.0 else (mood.rock as Color).lightened(-tint)
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("moss", (mood.grass as Color).darkened(0.15))
	m.set_shader_parameter("moss_amt", moss)
	m.set_shader_parameter("glow", 0.16 if skull else 0.0)
	rock_mat_cache[key] = m
	return m

func _make_scenery() -> void:
	for c in scenery.get_children():
		c.queue_free()
	gulls = []
	boat = null
	if engine:
		_apply_mood()
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	# Near ring: sandstone cliffs round the lagoon, open behind the camera.
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
		rock.material_override = _rock_mat(r.randf_range(-0.08, 0.2), 0.8)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scenery.add_child(rock)
		# Amazonia: jungle on every cliff (was one tree on 45% of them).
		for t in 2 + r.randi() % 3:
			_kenney(scenery, "tree-large" if t % 2 == 0 else "tree-shrub", p + Vector3(r.randf_range(-w * 0.4, w * 0.4), h * 0.62, r.randf_range(-w * 0.4, w * 0.4)), r.randf_range(3.0, 5.5), r.randf() * TAU)
	# Far ring: blue mountains in the haze (depth).
	for k in 12:
		var a := lerpf(-1.1, 1.1, k / 11.0) * PI * 0.6
		var dist := r.randf_range(170.0, 240.0)
		var mt := MeshInstance3D.new()
		mt.mesh = _rock_mesh(k % 4)
		var h := r.randf_range(40.0, 80.0)
		mt.scale = Vector3(r.randf_range(40.0, 70.0), h, r.randf_range(30.0, 50.0))
		mt.position = Vector3(sin(a) * dist, -h * 0.1, 14.0 + cos(a) * dist)
		mt.material_override = _rock_mat(0.35, 0.3)
		mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scenery.add_child(mt)
	# A broken stone shrine in the trees on a far cliff, a dugout canoe, birds.
	_kenney(scenery, "column-damaged", Vector3(-26, 9.5, 74), 3.0, 0.7)
	for t in 5:
		_kenney(scenery, "tree-large", Vector3(-34 + t * 4.0, 9.0, 76 + (t % 2) * 3.0), 4.0, t * 1.3)
	boat = _make_boat()
	boat.position = Vector3(38, 0, 120)
	scenery.add_child(boat)
	for k in 5:
		var g := _make_gull()
		scenery.add_child(g[0])
		gulls.append([g[0], Vector3(r.randf_range(-15, 15), 0, r.randf_range(20, 45)), r.randf_range(10.0, 24.0),
			r.randf_range(10.0, 18.0), r.randf_range(0.18, 0.32) * (1.0 if k % 2 == 0 else -1.0), r.randf() * TAU, g[1]])

func _make_boat() -> Node3D:
	var b := Node3D.new()
	var hull := MeshInstance3D.new()
	var hm := PrismMesh.new()
	hm.size = Vector3(1.6, 1.0, 6.0)
	hull.mesh = hm
	hull.rotation.z = PI
	hull.position.y = 0.4
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3a22") if not skull else Color("1a0e28")
	hull.material_override = wood
	b.add_child(hull)
	hull.scale = Vector3(0.55, 0.45, 1.0)   # a dugout canoe (Amazonia): low, no mast or sail
	b.rotation.y = 1.2
	return b

## A gull: a body and two wings that flap. Returns [node, [left wing, right wing]].
func _make_gull() -> Array:
	var g := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("eeeeea") if not skull else Color("29e6ff")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # wings seen from below stay white
	if skull:
		mat.emission_enabled = true
		mat.emission = Color("29e6ff") * 0.6
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.12
	bm.height = 0.6
	body.mesh = bm
	body.rotation.x = PI / 2.0
	body.material_override = mat
	g.add_child(body)
	var wings: Array = []
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		g.add_child(pivot)
		var wing := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.28)
		wing.mesh = q
		wing.rotation.x = -PI / 2.0
		wing.position = Vector3(s * 0.45, 0, 0)
		wing.material_override = mat
		pivot.add_child(wing)
		pivot.set_meta("side", s)
		wings.append(pivot)
	return [g, wings]

## Pollen near the camera, leaves over the islands, petals for the winner.
func _make_ambient() -> void:
	pollen = _particles(45, 6.0, Color(1, 0.98, 0.85, 0.5), 0.02, 0.04)
	pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pollen.emission_box_extents = Vector3(7, 2.5, 5)
	pollen.gravity = Vector3(0, 0.02, 0)
	pollen.initial_velocity_min = 0.05
	pollen.initial_velocity_max = 0.25
	pollen.spread = 180.0
	pollen.emitting = true
	add_child(pollen)
	leaves = _particles(22, 7.0, Color("8fb04a"), 0.04, 0.07)
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(14, 2, 18)
	leaves.gravity = Vector3(0, -0.35, 0)
	leaves.angular_velocity_min = -180.0
	leaves.angular_velocity_max = 180.0
	var cg := Gradient.new()
	cg.set_color(0, Color("9cbf4a"))
	cg.set_color(1, Color("e0a040"))
	leaves.color_initial_ramp = cg
	leaves.emitting = true
	add_child(leaves)
	petals = _particles(60, 3.0, Color("ffd36a"), 0.06, 0.1)
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	petals.emission_sphere_radius = 2.2
	petals.gravity = Vector3(0, -0.8, 0)
	petals.angular_velocity_min = -300.0
	petals.angular_velocity_max = 300.0
	var pg := Gradient.new()
	pg.set_color(0, Color("ffd36a"))
	pg.set_color(1, Color("ff6a8a"))
	petals.color_initial_ramp = pg
	petals.emitting = false
	add_child(petals)

func _particles(n: int, life: float, col: Color, smin: float, smax: float) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.amount = n
	ps.lifetime = life
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true   # or every particle is a 1 m blob
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex
	q.material = m
	ps.mesh = q
	ps.color = col
	ps.scale_amount_min = smin
	ps.scale_amount_max = smax
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	ps.color_ramp = fade
	ps.local_coords = false
	return ps

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
	_make_scenery()
	rebuild_level()

func rebuild_level() -> void:
	if level:
		level.queue_free()
	_apply_mood()
	level = Node3D.new()
	add_child(level)
	stuck_nodes = []
	grass_mats = []
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
		cm.radial_segments = 24
		cm.rings = 3
		base.mesh = cm
		base.position = c + Vector3(0, (top - 4.0) / 2.0, 0)
		base.material_override = _rock_mat(0.05, 0.0)
		level.add_child(base)
		for j in 7:
			var a := TAU * j / 7.0 + r.randf()
			var rk := MeshInstance3D.new()
			rk.mesh = _rock_mesh(j % 4)
			var s := r.randf_range(0.8, 1.6)
			rk.scale = Vector3(s * 1.4, s * (top + 0.6) * 0.6, s * 1.4)
			rk.position = c + Vector3(cos(a), 0, sin(a)) * isl.r * 1.05
			rk.material_override = _rock_mat(r.randf_range(0.0, 0.18), 1.0)
			level.add_child(rk)
		# Grass top with a sandy rim, pebbles, and blades that sway in the wind.
		var ground := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = isl.r * 1.0
		gm.bottom_radius = isl.r * 1.0
		gm.height = 0.12
		gm.radial_segments = 32
		ground.mesh = gm
		ground.position = c + Vector3(0, top + 0.0, 0)
		var gmat := ShaderMaterial.new()
		gmat.shader = _shader(GROUND_SHADER)
		gmat.set_shader_parameter("base", mood.grass)
		gmat.set_shader_parameter("centre", c)
		gmat.set_shader_parameter("radius", isl.r)
		gmat.set_shader_parameter("glow", 0.25 if skull else 0.0)
		ground.material_override = gmat
		level.add_child(ground)
		_grass(c + Vector3(0, top + 0.06, 0), isl.r * 0.88, 2200 if k == 0 else 600, r)
		for j in 6:
			var pb := MeshInstance3D.new()
			pb.mesh = _rock_mesh(j % 4)
			var s := r.randf_range(0.08, 0.2)
			pb.scale = Vector3(s, s * 0.6, s)
			var a := r.randf() * TAU
			pb.position = c + Vector3(cos(a), 0, sin(a)) * r.randf_range(0.6, 0.85) * isl.r + Vector3(0, top + 0.05, 0)
			pb.material_override = _rock_mat(-0.1, 0.0)
			level.add_child(pb)
		var fw: Vector3 = engine.forward(k)
		var side := fw.cross(Vector3.UP)
		if k == 0:   # the near island: decor to her left, away from the camera
			_kenney(level, "column-damaged", c + Vector3(0, top, 0) + fw * 0.9 - side * 2.5, 1.0, r.randf() * TAU)
			_kenney(level, "tree-shrub", c + Vector3(0, top, 0) - fw * 0.6 - side * 2.4, 1.3, r.randf() * TAU)
		else:
			_kenney(level, "column-damaged", c + Vector3(0, top, 0) - fw * 2.1 + side * 1.6, 1.0, r.randf() * TAU)
			_kenney(level, "tree-shrub", c + Vector3(0, top, 0) - fw * 1.8 - side * 1.7, 1.3, r.randf() * TAU)
			_kenney(level, "tree-large", c + Vector3(0, top, 0) - fw * 2.4 - side * 0.6, 2.2, r.randf() * TAU)
	for b in engine.blocks:
		if b.kind == "column":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("ece0c6") if not skull else Color("140a22")
			m.roughness = 0.75
			if skull:
				m.emission_enabled = true
				m.emission = Color("29e6ff") * 0.5
			var col := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = b.r * 0.85
			cc.bottom_radius = b.r
			cc.height = b.top + 2.0
			cc.radial_segments = 16
			col.mesh = cc
			col.position = Vector3(b.x, (b.top - 2.0) / 2.0, b.z)
			col.material_override = m
			level.add_child(col)
			# Fluting: thin darker ribs round the shaft.
			for f in 8:
				var a := TAU * f / 8.0
				var rib := MeshInstance3D.new()
				var bm2 := BoxMesh.new()
				bm2.size = Vector3(0.05, b.top, 0.05)
				rib.mesh = bm2
				rib.position = Vector3(b.x + cos(a) * b.r * 0.93, b.top / 2.0, b.z + sin(a) * b.r * 0.93)
				var rm := m.duplicate()
				rm.albedo_color = m.albedo_color.darkened(0.12)
				rib.material_override = rm
				level.add_child(rib)
			for cap_k in 2:
				var cap := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(b.r * (2.7 - cap_k * 0.4), 0.18, b.r * (2.7 - cap_k * 0.4))
				cap.mesh = bm
				cap.position = Vector3(b.x, b.top + 0.09 - cap_k * 0.18, b.z)
				cap.material_override = m
				level.add_child(cap)
			var foot := MeshInstance3D.new()
			foot.mesh = _rock_mesh(2)
			foot.scale = Vector3(1.4, 0.9, 1.4)
			foot.position = Vector3(b.x, 0.1, b.z)
			foot.material_override = _rock_mat(0.1, 1.0)
			level.add_child(foot)
		else:
			var rk := MeshInstance3D.new()
			rk.mesh = _rock_mesh(1)
			rk.scale = Vector3(b.r, b.top * 0.85, b.r)
			rk.position = Vector3(b.x, 0, b.z)
			rk.material_override = _rock_mat(-0.05, 1.0)
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
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("3a2a1a")
	pole.material_override = pm
	level.add_child(pole)
	flag.set_meta("pole", pole_at + Vector3(0, 2.25, 0))
	for i in 2:
		chars[i].position = engine.feet(i)
		_face(i, engine.forward(i))

## A tuft field: n blades (thin tapered triangles) scattered in a disc, one draw call.
func _grass(centre: Vector3, radius: float, n: int, r: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * radius
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		var h := r.randf_range(0.07, 0.17)
		var w := r.randf_range(0.01, 0.02)
		var rot := r.randf() * TAU
		var side := Vector3(cos(rot), 0, sin(rot)) * w
		var lean := Vector3(r.randf_range(-0.05, 0.05), 0, r.randf_range(-0.05, 0.05))
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p - side)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p + side)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(p + Vector3(0, h, 0) + lean)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = centre
	var m := ShaderMaterial.new()
	m.shader = _shader(GRASS_SHADER)
	m.set_shader_parameter("base", (mood.grass as Color).lightened(0.08))
	m.set_shader_parameter("glow", 0.4 if skull else 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass_mats.append(m)
	level.add_child(mi)

func _face(i: int, dir: Vector3) -> void:
	chars[i].rotation.y = atan2(dir.x, dir.z)

# ---------- weapons ----------

## A weapon model pointing along -Z (look_at friendly), centred on its grip.
func weapon_mesh(w: int) -> Node3D:
	var n := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a5a2a")
	wood.roughness = 0.7
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("e2c78a") if w == 0 else Color("d6dde6")
	metal.metallic = 0.9
	metal.roughness = 0.25
	metal.emission_enabled = true
	metal.emission = Color("29e6ff") * 0.8 if skull else Color(1, 0.9, 0.7) * 0.08
	match w:
		0:
			var shaft := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.016
			c.bottom_radius = 0.018
			c.height = 1.5
			c.radial_segments = 6
			shaft.mesh = c
			shaft.rotation.x = PI / 2.0
			shaft.material_override = wood
			n.add_child(shaft)
			var tip := MeshInstance3D.new()
			var t := CylinderMesh.new()
			t.top_radius = 0.0
			t.bottom_radius = 0.038
			t.height = 0.24
			t.radial_segments = 4
			tip.mesh = t
			tip.rotation.x = -PI / 2.0
			tip.position = Vector3(0, 0, -0.86)
			tip.material_override = metal
			n.add_child(tip)
			for k in 2:
				var band := MeshInstance3D.new()
				var b := CylinderMesh.new()
				b.top_radius = 0.023
				b.bottom_radius = 0.023
				b.height = 0.1 if k == 0 else 0.05
				band.mesh = b
				band.rotation.x = PI / 2.0
				band.position = Vector3(0, 0, 0.1 if k == 0 else 0.62)
				var red := StandardMaterial3D.new()
				red.albedo_color = Color("c0302a") if k == 0 else Color("e8b84a")
				red.metallic = 0.0 if k == 0 else 0.8
				band.material_override = red
				n.add_child(band)
		1:
			var handle := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.024
			c.height = 0.5
			handle.mesh = c
			handle.material_override = wood
			n.add_child(handle)
			for s in [-1.0, 1.0]:
				var head := MeshInstance3D.new()
				var p := PrismMesh.new()
				p.size = Vector3(0.2, 0.17, 0.025)
				head.mesh = p
				head.rotation.z = -PI / 2.0 * s
				head.position = Vector3(0.09 * s, 0.18, 0)
				head.material_override = metal
				head.scale = Vector3.ONE * (1.0 if s > 0 else 0.6)
				n.add_child(head)
		_:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.1
			tm.outer_radius = 0.145
			tm.rings = 24
			tm.ring_segments = 6
			ring.mesh = tm
			ring.material_override = metal
			n.add_child(ring)
			var inner := MeshInstance3D.new()
			var im := TorusMesh.new()
			im.inner_radius = 0.085
			im.outer_radius = 0.1
			im.rings = 24
			im.ring_segments = 4
			inner.mesh = im
			var gold := StandardMaterial3D.new()
			gold.albedo_color = Color("e8b84a")
			gold.metallic = 0.9
			gold.roughness = 0.3
			inner.material_override = gold
			n.add_child(inner)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n

func show_projectile(w: int) -> void:
	chase_dir = Vector3.ZERO
	hide_projectile()
	proj = weapon_mesh(w)
	proj_w = w
	proj.scale = Vector3.ONE * 2.0   # reads better far away
	add_child(proj)
	# A small bright spark rides the weapon's head (keeps it findable against any sky).
	var spark := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2.ONE * 0.22
	spark.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.albedo_texture = soft_tex
	sm.albedo_color = Color(1, 0.95, 0.8) if not skull else Color("29e6ff")
	spark.material_override = sm
	spark.position = Vector3(0, 0, -0.45) if w == 0 else Vector3.ZERO
	proj.add_child(spark)
	if not engine.shot.is_empty():
		_flash(engine.shot.p, Color(1, 0.95, 0.8), 0.5, 0.12)

func hide_projectile() -> void:
	if proj:
		proj.queue_free()
	proj = null
	trail_mesh.clear_surfaces()

## A weapon left where it landed (not on people), with a little quiver.
func leave_stuck(p: Vector3, v: Vector3, w: int, surface: String) -> void:
	if surface == "water":
		return
	var n := weapon_mesh(w)
	add_child(n)
	var dir := v.normalized()
	n.position = p + dir * (0.35 if w == 0 else 0.05)
	if dir.length() > 0.1:
		n.look_at(n.position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	var base_rot := n.rotation
	var tw := n.create_tween()
	for k in 4:
		var amp := 0.06 * (1.0 - k / 4.0)
		tw.tween_property(n, "rotation:x", base_rot.x + amp, 0.05)
		tw.tween_property(n, "rotation:x", base_rot.x - amp, 0.05)
	tw.tween_property(n, "rotation:x", base_rot.x, 0.05)
	stuck_nodes.append(n)
	if stuck_nodes.size() > MAX_STUCK:
		stuck_nodes.pop_front().queue_free()

# ---------- effects ----------

## One-shot soft particles. vel = [min, max], dir/spread, gravity, size range.
func _puff(p: Vector3, n: int, life: float, col: Color, vel: Array, dir: Vector3, spread: float, grav: float, size: Array, additive: bool = false, grow: bool = false) -> void:
	var ps := _particles(n, life, col, size[0], size[1])
	ps.one_shot = true
	ps.explosiveness = 0.92
	ps.direction = dir
	ps.spread = spread
	ps.initial_velocity_min = vel[0]
	ps.initial_velocity_max = vel[1]
	ps.gravity = Vector3(0, grav, 0)
	ps.damping_min = 1.0
	ps.damping_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = fade
	if grow:
		var c := Curve.new()
		c.add_point(Vector2(0, 0.5))
		c.add_point(Vector2(1, 1.6))
		ps.scale_amount_curve = c
	if additive:
		(ps.mesh.material as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ps.position = p
	add_child(ps)
	ps.emitting = true
	var tw := ps.create_tween()
	tw.tween_interval(life + 0.4)
	tw.tween_callback(ps.queue_free)

## A bright, quickly fading flash (additive billboard).
func _flash(p: Vector3, col: Color, size: float, life: float) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * size
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = soft_tex
	m.albedo_color = col
	m.no_depth_test = true
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = p
	add_child(q)
	var tw := q.create_tween()
	tw.set_parallel(true)
	tw.tween_property(q, "scale", Vector3.ONE * 2.2, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(q.queue_free)

## An expanding ring: flat on the water (ripple) or facing the camera (shock).
func _ring(p: Vector3, col: Color, to_size: float, life: float, flat: bool) -> void:
	var r := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 3
	r.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	if not flat:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.position = p
	r.scale = Vector3(0.1, 0.02 if flat else 0.1, 0.1)
	add_child(r)
	if not flat and cam:
		r.look_at(cam.global_position, Vector3.UP)
		r.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "scale", Vector3(to_size, 0.02 if flat else to_size * 0.15, to_size), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)

func burst(p: Vector3, kind: String) -> void:
	var neon := Color("29e6ff")
	match kind:
		"water":
			_puff(p, 34, 1.1, Color(0.9, 0.97, 1.0, 0.9), [3.5, 7.5], Vector3.UP, 14.0, -9.8, [0.12, 0.3])
			_puff(p + Vector3(0, 0.1, 0), 14, 1.4, Color(1, 1, 1, 0.6), [0.6, 1.4], Vector3.UP, 70.0, -0.5, [0.4, 0.8], false, true)
			for k in 3:
				_delay(k * 0.18, _ring.bind(p + Vector3(0, 0.03, 0), Color(1, 1, 1, 0.8 - k * 0.2), 2.0 + k * 1.2, 1.4, true))
		"ground":
			_puff(p, 12, 1.4, Color("c8a878") if not skull else neon, [0.6, 1.8], Vector3.UP, 75.0, -0.3, [0.35, 0.7], false, true)
			_puff(p, 14, 0.7, Color("6a5038"), [1.5, 3.5], Vector3.UP, 45.0, -9.8, [0.04, 0.08])
		"stone":
			_puff(p, 18, 0.45, Color(1, 0.85, 0.5) if not skull else neon, [3.0, 7.0], Vector3.UP, 180.0, -6.0, [0.03, 0.06], true)
			_puff(p, 10, 0.9, Color("bcb0a0"), [1.0, 3.0], Vector3.UP, 90.0, -9.8, [0.05, 0.1])
			_puff(p, 8, 1.2, Color(0.85, 0.8, 0.7, 0.6), [0.4, 1.0], Vector3.UP, 180.0, 0.2, [0.3, 0.6], false, true)
			_flash(p, Color(1, 0.9, 0.6), 0.8, 0.15)
		"hit_head":
			_flash(p, Color(1, 0.85, 0.35) if not skull else Color("ff2bd6"), 1.6, 0.22)
			_ring(p, Color(1, 0.85, 0.4, 0.9) if not skull else Color("ff2bd6"), 2.4, 0.35, false)
			_puff(p, 40, 0.6, Color("ffd04a") if not skull else Color("ff2bd6"), [3.0, 7.0], Vector3.UP, 180.0, -4.0, [0.04, 0.09], true)
		"ko":
			_puff(p, 18, 1.8, Color("c8a878") if not skull else neon, [0.5, 1.5], Vector3.UP, 85.0, -0.2, [0.5, 1.0], false, true)
		_:  # a body hit
			_flash(p, Color(1, 0.97, 0.9) if not skull else neon, 1.1, 0.16)
			_ring(p, Color(1, 1, 1, 0.75) if not skull else neon, 1.6, 0.3, false)
			_puff(p, 24, 0.5, Color(1, 0.95, 0.8) if not skull else neon, [2.0, 5.0], Vector3.UP, 180.0, -4.0, [0.03, 0.07], true)

func _delay(t: float, f: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(t)
	tw.tween_callback(f)

## Gold petals round the winner (on) or stop them (off).
func celebrate(i: int, on: bool) -> void:
	if petals == null:
		return
	if on:
		petals.position = engine.feet(i) + Vector3(0, 3.0, 0)
		petals.emitting = true
	else:
		petals.emitting = false

# ---------- per frame ----------

## st: "view" (seat the camera follows), "aiming" (seat aiming or -1),
## "show_ribbon", "eagle" (bool), "kill" (victim or -1), "winner", "zoom" 0..1.
## "chase" (bool): the camera follows the throw in flight, then holds where it landed.
func tick(delta: float, st: Dictionary) -> void:
	_time += delta
	var view: int = st.get("view", 0)
	var aiming: int = st.get("aiming", -1)
	var wv: float = engine.wind / engine.WIND_MAX
	for i in 2:
		var dir: Vector3 = engine.forward(i)
		if aiming == i or (not engine.shot.is_empty() and engine.shot.owner == i):
			dir = engine.direction(i, engine.yaw_of(i), 0.0)
		var target_rot := atan2(dir.x, dir.z)
		chars[i].rotation.y = lerp_angle(chars[i].rotation.y, target_rot, minf(1.0, delta * 8.0))
		chars[i].set_wind(wv)
	# Wind everywhere: sky clouds, water, grass, leaves, pollen.
	var wind2 := Vector2(wv, 0.15)
	sky_mat.set_shader_parameter("wind", Vector2(0.012 + wv * 0.03, 0.006))
	water_mat.set_shader_parameter("wind", wind2)
	for gm in grass_mats:
		gm.set_shader_parameter("wind", Vector2(wv, 0.0))
	if leaves:
		leaves.gravity = engine.forward(engine.turn) * engine.wind * 0.9 + Vector3(0, -0.35, 0)   # the wind blows along the line
		leaves.position = Vector3(engine.feet(view).x, engine.feet(view).y + 2.0, engine.feet(view).z + 8.0)
	if pollen:
		pollen.gravity = engine.forward(engine.turn) * engine.wind * 0.25 + Vector3(0, 0.02, 0)
		pollen.position = cam.global_position + (cam.global_transform.basis.z * -11.0)
	# Gulls circle and flap; the boat bobs.
	for g in gulls:
		var node: Node3D = g[0]
		var a: float = g[5] + _time * g[4]
		var c: Vector3 = g[1]
		node.position = c + Vector3(cos(a) * g[2], g[3] + sin(_time * 0.7 + g[5]) * 0.6, sin(a) * g[2])
		node.rotation.y = -a + (PI if g[4] > 0 else 0.0)
		var flap := sin(_time * 7.0 + g[5]) * 0.55
		for wing in g[6]:
			wing.rotation.z = flap * float(wing.get_meta("side"))
	if boat:
		boat.position.y = sin(_time * 0.8) * 0.15
		boat.rotation.z = sin(_time * 0.6) * 0.04
		boat.position.x = 38.0 + sin(_time * 0.02) * 6.0
	# The flag.
	if flag and flag.has_meta("pole"):
		var top: Vector3 = flag.get_meta("pole")
		var stream := Vector3(signf(wv) if absf(wv) > 0.05 else 0.2, -(1.0 - absf(wv)) * 0.9, 0.15).normalized()
		flag.position = top + stream * 0.3
		flag.look_at(flag.position + Vector3(0, 0, 1), Vector3.UP)
		flag.rotation.z = -atan2(stream.y, stream.x) + sin(_time * (5.0 + 8.0 * absf(wv))) * 0.08
	# The throw in flight.
	if not engine.shot.is_empty():
		chase_p = engine.shot.p
		var hv := Vector3(engine.shot.v.x, 0, engine.shot.v.z)
		if hv.length() > 0.5:
			chase_dir = hv.normalized()
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

## The glowing trail behind the throw: a ribbon facing the camera, widest and
## brightest at the head.
func _draw_trail(pts: Array, head: Vector3) -> void:
	trail_mesh.clear_surfaces()
	var all: Array = pts.duplicate()
	all.append(head)
	if all.size() < 2:
		return
	var eye: Vector3 = cam.global_position
	var base_col := Color(1.0, 0.92, 0.75) if not skull else Color(0.16, 0.9, 1.0)
	if proj_w == 2 and not skull:
		base_col = Color(1.0, 0.8, 0.35)
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := all.size()
	for k in n:
		var p: Vector3 = all[k]
		var nxt: Vector3 = all[mini(k + 1, n - 1)]
		var prv: Vector3 = all[maxi(k - 1, 0)]
		var along := (nxt - prv).normalized()
		var side := along.cross((eye - p).normalized()).normalized()
		var a := float(k) / (n - 1)
		var w := 0.025 + a * a * 0.09
		var c := Color(base_col, a * 0.95)
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_set_uv(Vector2(0, a))
		trail_mesh.surface_add_vertex(p + side * w)
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_set_uv(Vector2(1, a))
		trail_mesh.surface_add_vertex(p - side * w)
	trail_mesh.surface_end()

## The aim ribbon: striped, the first stretch of the arc without the wind;
## gold dots all the way with the wind when 🦅 Eagle Eye is on.
## Plus the ghost: the previous throw's whole flight, see-through, while she aims again.
func _draw_ribbon(st: Dictionary) -> void:
	ribbon_mesh.clear_surfaces()
	var i: int = st.get("aiming", -1)
	var gi: int = st.get("ghost", -1)
	var ghost: PackedVector3Array = PackedVector3Array()
	if gi >= 0 and gi < engine.last.size() and not (engine.last[gi] as Dictionary).is_empty():
		ghost = engine.last[gi].pts
	var aim_on: bool = i >= 0 and st.get("show_ribbon", false)
	if ghost.size() < 2 and not aim_on:
		return
	ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if ghost.size() >= 2:
		var gside: Vector3 = engine.forward(gi).cross(Vector3.UP).normalized()
		var gcol := Color(1, 1, 1, 0.28) if not skull else Color(0.16, 0.9, 1.0, 0.28)
		for k in ghost.size() - 1:
			_quad(ghost[k] - gside * 0.045, ghost[k] + gside * 0.045, ghost[k + 1] + gside * 0.045, ghost[k + 1] - gside * 0.045, gcol)
	if not aim_on:
		ribbon_mesh.surface_end()
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
	var pulse := 0.75 + 0.25 * sin(_time * 6.0)
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var fade := 1.0 - float(k) / pts.size()
		var col := (Color(1, 1, 1, fade * pulse) if k % 2 == 0 else Color(0.43, 0.85, 1.0, fade * pulse)) if not skull else (Color(0.16, 0.9, 1.0, fade) if k % 2 == 0 else Color(1.0, 0.17, 0.84, fade))
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

func _shoulder(view: int, aim_yaw: bool) -> Array:
	var f: Vector3 = engine.feet(view)
	var fw: Vector3 = engine.direction(view, engine.yaw_of(view) * 0.85, 0.0) if aim_yaw else engine.forward(view)
	var right := fw.cross(Vector3.UP).normalized()
	return [f + Vector3(0, 2.4, 0) + right * 1.0 - fw * 3.7, f + Vector3(0, 1.0, 0) + fw * 20.0 + right * 0.3]

func _camera(delta: float, st: Dictionary, view: int) -> void:
	var kill: int = st.get("kill", -1)
	var winner: int = st.get("winner", -1)
	var zoom: float = st.get("zoom", 0.0)
	var sh := _shoulder(view, st.get("aiming", -1) == view)
	var want_pos: Vector3 = sh[0]
	var want_look: Vector3 = sh[1]
	var k := minf(1.0, delta * 5.0)
	if intro_t >= 0.0:
		# Intro flyover: from in front of the rival, up over the water, down to your shoulder.
		intro_t += delta
		var u := clampf(intro_t / INTRO_LEN, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		var rv: Vector3 = engine.feet(1 - intro_view)
		var rfw: Vector3 = engine.forward(1 - intro_view)
		var a_pos := rv + rfw * 3.6 + Vector3(0, 1.5, 0) + rfw.cross(Vector3.UP) * 0.9
		var a_look := rv + Vector3(0, 1.3, 0)
		var mid: Vector3 = (a_pos + (sh[0] as Vector3)) / 2.0 + Vector3(0, 7.0, 0)
		want_pos = a_pos.lerp(mid, e).lerp(mid.lerp(sh[0], e), e)
		want_look = a_look.lerp(sh[1], smoothstep(0.25, 1.0, u))
		k = 1.0
		if u >= 1.0:
			intro_t = -1.0
	elif kill >= 0 and zoom > 0.0:
		var vf: Vector3 = engine.feet(kill)
		var toward: Vector3 = engine.forward(kill)
		var side := toward.cross(Vector3.UP).normalized()
		var kp := vf + Vector3(0, 1.5, 0) + side * 2.6 + toward * 1.6
		var kl := vf + Vector3(0, 1.1, 0)
		if not engine.shot.is_empty():
			kl = kl.lerp(engine.shot.p, 0.35)
		want_pos = want_pos.lerp(kp, zoom)
		want_look = want_look.lerp(kl, zoom)
		k = minf(1.0, delta * 3.0)
	elif st.get("chase", false) and chase_dir != Vector3.ZERO:
		# Chase cam (2026-11-25): behind and above the throw, looking where it's going;
		# once it lands the camera holds there, so you see whether it hit.
		var side := chase_dir.cross(Vector3.UP).normalized()
		want_pos = chase_p - chase_dir * 4.2 + Vector3(0, 1.6, 0) + side * 0.8
		want_look = chase_p + chase_dir * 6.0 + Vector3(0, -0.4, 0)
		k = minf(1.0, delta * 6.0)
	elif winner >= 0:
		var wf: Vector3 = engine.feet(winner)
		var wfw: Vector3 = engine.forward(winner)
		# A slow arc round the winner.
		var orbit := sin(_time * 0.25) * 0.5
		var dirw := wfw.rotated(Vector3.UP, orbit)
		want_pos = wf + Vector3(0, 1.45, 0) + dirw * 3.4 + dirw.cross(Vector3.UP) * 0.8
		want_look = wf + Vector3(0, 1.05, 0)
		k = minf(1.0, delta * 2.0)
	else:
		# Breathing: the shoulder cam drifts a hand's width, so the view never feels frozen.
		want_pos += Vector3(sin(_time * 0.45) * 0.06, sin(_time * 0.6) * 0.04, 0)
	cam_pos = cam_pos.lerp(want_pos, k)
	cam_look = cam_look.lerp(want_look, k)
	var jolt := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * view3d_shake * 0.07
	cam.position = cam_pos + jolt
	if cam_pos.distance_to(cam_look) > 0.01:
		cam.look_at(cam_look + jolt, Vector3.UP)
	cam.fov = lerpf(52.0, 44.0, zoom) if kill >= 0 else 52.0

## Jumps the camera straight to where it's going (new fight, new view).
func snap_camera(view: int) -> void:
	var sh := _shoulder(view, false)
	cam_pos = sh[0]
	cam_look = sh[1]
	cam.position = cam_pos
	cam.look_at(cam_look, Vector3.UP)

## The intro flyover for a new fight (the game shows the VS card meanwhile).
func start_intro(view: int) -> void:
	intro_view = view
	intro_t = 0.0

func skip_intro() -> void:
	if intro_t >= 0.0:
		intro_t = INTRO_LEN

## Screen point of a world point (for the HUD's floating numbers); null when behind.
func screen_of(p: Vector3):
	if cam.is_position_behind(p):
		return null
	return cam.unproject_position(p)
