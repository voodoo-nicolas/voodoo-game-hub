extends Node3D

## One assassin in 3D: Quaternius' CC0 female base (games/ancient_assassins/models,
## media/CREDITS.json) dressed per character in code: the base's grey bikini
## recoloured into her colours by a shader (skin tone tinted the same way),
## skinned hair, a pleated war skirt, gold belt, bracers, headband or circlet,
## an optional cape, and the weapon in her right hand. Clips come from
## models/aa_anims.res (tools/aa_build_anims.gd): idle, aim_in, aim, throw,
## hit, hit_head, death, win, ready.
##
##     var a = AaCharacter.new()
##     add_child(a)
##     a.build(CHARS[i], skull_mode)
##     a.play("idle")

const DIR := "res://games/ancient_assassins/models/"
const BODY := DIR + "Superhero_Female_FullBody.gltf"
const ANIMS := DIR + "aa_anims.res"
const HAIR := {
	"long": DIR + "Hair_Long.gltf", "buns": DIR + "Hair_Buns.gltf",
	"parted": DIR + "Hair_SimpleParted.gltf", "short": DIR + "Hair_BuzzedFemale.gltf",
}

const BODY_SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 outfit : source_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform vec4 skin : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// Shop outfits (2026-11-25). rp = this vertex in the T-pose rest pose (CUSTOM0, set by
// _rest_mesh()), so patterns and painted garments never swim while she moves.
// Rest landmarks (metres): feet 0, knee 0.53, crotch 0.86, waist 1.0, chest 1.29,
// shoulders / arms along x at 1.42 (shoulder 0.15, elbow 0.39, wrist 0.64), neck 1.48.
// Bikini pattern: 0 solid, 1 three bands across, 2 stripes, 3 smileys, 4 polka dots, 5 stars & stripes.
uniform int pattern = 0;
uniform vec4 pa : source_color = vec4(1.0);
uniform vec4 pb : source_color = vec4(1.0);
uniform vec4 pc : source_color = vec4(1.0);
// Painted garments (alpha 0 = none): a top (torso band top_y + sleeves to |x| < sleeve_x,
// V neckline neck_v deep), trim on its edges, shorts down to bot_y, stockings up to stock_y
// (alpha = how sheer) with a lace band, boots up to boot_y, gloves past glove_x, shoes.
// decal: 1 buttons, 2 zip, 3 red cross, 4 shoulder straps, 5 ties under the bust.
uniform vec4 top_col : source_color = vec4(0.0);
uniform vec2 top_y = vec2(1.0, 1.4);
uniform float sleeve_x = 0.0;
uniform float neck_v = 0.0;
uniform float top_rough = 0.6;
uniform vec4 trim_col : source_color = vec4(0.0);
uniform vec4 bot_col : source_color = vec4(0.0);
uniform float bot_y = 0.8;
uniform float bot_top = 1.0;
uniform vec4 stock_col : source_color = vec4(0.0);
uniform float stock_y = 0.0;
uniform vec4 band_col : source_color = vec4(0.0);
uniform vec4 boot_col : source_color = vec4(0.0);
uniform float boot_y = 0.0;
uniform vec4 glove_col : source_color = vec4(0.0);
uniform float glove_x = 9.0;
uniform vec4 shoe_col : source_color = vec4(0.0);
uniform float shoe_y = 0.0;
uniform int decal = 0;
uniform vec4 decal_col : source_color = vec4(1.0);
varying vec3 rp;
void vertex() {
	rp = CUSTOM0.xyz;
}
vec3 pat(vec3 base) {
	if (pattern == 1) {
		return rp.x < -0.04 ? pa.rgb : (rp.x > 0.04 ? pc.rgb : pb.rgb);
	} else if (pattern == 2) {
		float b = mod(floor(rp.y / 0.018), 3.0);
		return b < 0.5 ? pa.rgb : (b < 1.5 ? pb.rgb : pc.rgb);
	} else if (pattern == 3 || pattern == 4) {
		vec2 q = vec2(rp.x, rp.y) / 0.055;
		vec2 cell = fract(q) - 0.5;
		float d = length(cell);
		if (d > 0.36) return pa.rgb;
		if (pattern == 4) return pb.rgb;
		// A smiley: two eyes and a smile on the dot.
		vec2 e = vec2(abs(cell.x) - 0.12, cell.y - 0.1);
		if (length(e) < 0.055) return pc.rgb;
		float m = length(cell + vec2(0.0, 0.02));
		if (cell.y < -0.04 && m > 0.17 && m < 0.23) return pc.rgb;
		return pb.rgb;
	} else if (pattern == 5) {
		if (rp.y > 1.12) {
			vec2 cell = fract(vec2(rp.x, rp.y) / 0.035) - 0.5;
			return length(cell) < 0.18 ? vec3(1.0) : pa.rgb;
		}
		return mod(floor(rp.y / 0.016), 2.0) < 0.5 ? pb.rgb : vec3(1.0);
	}
	return base;
}
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.0001);
	float cloth = smoothstep(0.24, 0.12, sat);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float shade = clamp(lum / 0.5, 0.45, 1.25);
	vec3 fabric = pattern == 0 ? outfit.rgb * shade : pat(outfit.rgb) * mix(1.0, shade, 0.6);
	vec3 col = mix(c * skin.rgb, fabric, cloth);
	float rough = mix(texture(rough_tex, UV).g * 0.85, 0.35, cloth);
	// Painted garments, in the rest pose.
	vec3 r = rp;
	float ax = abs(r.x);
	bool arm = ax > 0.17 && r.y > 1.3;
	bool leg = r.y < 0.86;
	bool torso = !arm && !leg;
	bool front = r.z > -0.03;
	float gshade = mix(1.0, clamp(lum / 0.55, 0.6, 1.2), 0.5);
	vec4 g = vec4(0.0);
	float grough = 0.6;
	if (shoe_col.a > 0.0 && r.y < shoe_y) { g = vec4(shoe_col.rgb, 1.0); grough = 0.2; }
	if (boot_col.a > 0.0 && leg && r.y < boot_y) { g = vec4(boot_col.rgb, 1.0); grough = 0.12; }
	if (stock_col.a > 0.0 && leg && r.y < stock_y && g.a == 0.0) {
		float lace = stock_y - 0.05 + 0.008 * sin(atan(r.z + 0.03, r.x - sign(r.x) * 0.11) * 14.0);
		if (r.y > lace && band_col.a > 0.0) { g = vec4(band_col.rgb, 1.0); grough = 0.7; }
		else { col = mix(col, stock_col.rgb * (0.55 + 0.45 * lum), stock_col.a); rough = 0.4; }
	}
	if (bot_col.a > 0.0 && ((torso && r.y < bot_top) || (leg && r.y > bot_y))) { g = vec4(bot_col.rgb, 1.0); grough = 0.45; }
	bool covered = false;
	if (top_col.a > 0.0) {
		covered = (torso && r.y > top_y.x && r.y < top_y.y) || (arm && ax < sleeve_x);
		float v0 = top_y.y - neck_v;
		if (neck_v > 0.0 && front && torso && r.y > v0 && ax < (r.y - v0) * 0.6 + 0.004) covered = false;
		if (covered) {
			g = vec4(top_col.rgb, 1.0);
			grough = top_rough;
			bool edge = (torso && (r.y - top_y.x < 0.014 || (top_y.y - r.y < 0.014 && neck_v == 0.0))) || (arm && sleeve_x - ax < 0.018);
			if (neck_v > 0.0 && front && torso && r.y > v0 - 0.01 && ax < (r.y - v0) * 0.6 + 0.02) edge = true;
			if (trim_col.a > 0.0 && edge) g = vec4(trim_col.rgb, 1.0);
		}
	}
	if (decal == 4 && torso && top_col.a > 0.0 && r.y > top_y.y - 0.01 && r.y < 1.47 && abs(ax - 0.1) < 0.012) g = vec4(trim_col.rgb, 1.0);
	if (covered && front) {
		if (decal == 1 && ax < 0.011 && fract(r.y / 0.05) < 0.28) g = vec4(decal_col.rgb, 1.0);
		if (decal == 2 && ax < 0.005) { g = vec4(decal_col.rgb, 1.0); grough = 0.2; }
		if (decal == 3) {
			vec2 d = vec2(r.x - 0.075, r.y - 1.36);
			if ((abs(d.x) < 0.026 && abs(d.y) < 0.009) || (abs(d.x) < 0.009 && abs(d.y) < 0.026)) g = vec4(decal_col.rgb, 1.0);
		}
	}
	if (glove_col.a > 0.0 && arm && ax > glove_x) { g = vec4(glove_col.rgb, 1.0); grough = 0.3; }
	if (g.a > 0.0) {
		col = g.rgb * gshade;
		rough = grough;
		cloth = 1.0;
	}
	ALBEDO = mix(col, flash.rgb, flash.a);
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = fabric * cloth * glow + flash.rgb * flash.a * 0.6;
}
"""

const HAIR_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.2, 0.12, 0.08, 1.0);
uniform float glow = 0.0;
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	ALBEDO = tint.rgb * (0.35 + lum * 1.3);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.55;
	SPECULAR = 0.6;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = tint.rgb * glow;
}
"""

const CAPE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(0.7, 0.1, 0.1, 1.0);
uniform float wind = 0.0;
uniform float glow = 0.0;
void vertex() {
	float down = clamp(-VERTEX.y / 0.9 + 0.5, 0.0, 1.0);
	VERTEX.z -= down * (0.12 + 0.06 * sin(TIME * 4.0 + VERTEX.y * 6.0));
	VERTEX.x += down * wind * 0.25;
}
void fragment() {
	ALBEDO = color.rgb;
	ROUGHNESS = 0.8;
	EMISSION = color.rgb * glow;
}
"""

static var _body_shader: Shader
static var _hair_shader: Shader
static var _cape_shader: Shader
static var _anims: AnimationLibrary
static var _body_rest: ArrayMesh   # the body with its rest positions in CUSTOM0 (built once)

## The body mesh with each vertex's rest position copied into CUSTOM0, for the shader.
static func _rest_mesh(src: Mesh) -> Mesh:
	if _body_rest:
		return _body_rest
	if not (src is ArrayMesh) or src.get_surface_count() != 1:
		return src
	var arrays: Array = (src as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c0 := PackedFloat32Array()
	c0.resize(verts.size() * 4)
	for k in verts.size():
		c0[k * 4] = verts[k].x
		c0[k * 4 + 1] = verts[k].y
		c0[k * 4 + 2] = verts[k].z
	arrays[Mesh.ARRAY_CUSTOM0] = c0
	arrays[Mesh.ARRAY_CUSTOM1] = null   # the glTF import fills it; nothing here reads it
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if arrays[Mesh.ARRAY_BONES] != null and (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() == verts.size() * 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	m.surface_set_material(0, src.surface_get_material(0))
	_body_rest = m
	return m

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var body_mat: ShaderMaterial
var weapon_holder: Node3D
var cape_mat: ShaderMaterial
var current := ""
var _flash_t := 0.0

func build(ch: Dictionary, skull: bool = false) -> void:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY_SHADER
		_hair_shader = Shader.new()
		_hair_shader.code = HAIR_SHADER
		_cape_shader = Shader.new()
		_cape_shader.code = CAPE_SHADER
		_anims = load(ANIMS)
	model = (load(BODY) as PackedScene).instantiate()
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	# Body: the recolouring shader.
	body_mat = ShaderMaterial.new()
	body_mat.shader = _body_shader
	body_mat.set_shader_parameter("albedo_tex", load(DIR + "T_Superhero_Female_Light_BaseColor.png"))
	body_mat.set_shader_parameter("normal_tex", load(DIR + "T_Superhero_Female_Normal.png"))
	body_mat.set_shader_parameter("rough_tex", load(DIR + "T_Superhero_Female_Roughness.png"))
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if m.name == "Superhero_Female":
			m.mesh = _rest_mesh(m.mesh)
			m.material_override = body_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Hair, skinned to the same skeleton.
	var hair_path: String = HAIR.get(str(ch.get("hair3d", "long")), HAIR.long)
	var hair_scene: Node3D = (load(hair_path) as PackedScene).instantiate()
	var hair_mat := ShaderMaterial.new()
	hair_mat.shader = _hair_shader
	var hair_tex := "T_Hair_2" if hair_path.contains("Long") or hair_path.contains("Buns") else "T_Hair_1"
	hair_mat.set_shader_parameter("albedo_tex", load(DIR + hair_tex + "_BaseColor.png"))
	hair_mat.set_shader_parameter("normal_tex", load(DIR + hair_tex + "_Normal.png"))
	hair_mat.set_shader_parameter("tint", ch.get("hair_col", Color("2a1a10")))
	for hm in hair_scene.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = hm
		var keep_skin := mi.skin
		mi.owner = null
		mi.get_parent().remove_child(mi)
		skel.add_child(mi)
		mi.skin = keep_skin
		mi.skeleton = NodePath("..")
		mi.material_override = hair_mat
	hair_scene.free()
	_dress(ch)
	weapon_holder = _attach("hand_r")
	weapon_holder.transform = skel.get_bone_global_rest(skel.find_bone("hand_r")).affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(-0.66, 1.39, 0.0))
	set_skull(skull, ch)
	# Animations.
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.root_node = NodePath("..")
	if _anims:
		anim.add_animation_library("", _anims)
	play("idle", 0.0)
	# No two assassins breathe in step: a random start and a slightly different pace.
	if anim.has_animation("idle"):
		anim.seek(randf() * anim.get_animation("idle").length, true)
	anim.speed_scale = randf_range(0.93, 1.07)

## A node that follows `bone` (sits exactly on it).
func _attach(bone: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var holder := Node3D.new()
	ba.add_child(holder)
	return holder

func _mat(col: Color, rough: float = 0.5, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

func _dress(ch: Dictionary) -> void:
	var c1: Color = ch.c1
	var c2: Color = ch.c2
	var gold := _mat(Color("e8b84a"), 0.3, 0.8)
	var bikini: Dictionary = ch.get("bikini", {})
	if not bikini.is_empty():
		body_mat.set_shader_parameter("pattern", int(bikini.get("pattern", 0)))
		var cols: Array = bikini.get("cols", [c1, c1, c1])
		body_mat.set_shader_parameter("pa", cols[0])
		body_mat.set_shader_parameter("pb", cols[1])
		body_mat.set_shader_parameter("pc", cols[2])
		return   # just the bikini (and her hair): no skirt, belt, bracers or headband
	var costume := str(ch.get("costume", ""))
	if costume != "":
		_costume(costume)
		return
	# Pleated war skirt (pteruges) and a gold belt, on the hips.
	var hips := _attach("pelvis")
	var n := 12
	for k in n:
		var a := TAU * k / n
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.085, 0.29, 0.012)
		strip.mesh = bm
		strip.material_override = _mat(c1 if k % 2 == 0 else c1.darkened(0.25), 0.7)
		var out := Vector3(sin(a) * 0.175, 0, cos(a) * 0.135)
		var b := Basis(Vector3.UP, a).rotated(Vector3(cos(a), 0, -sin(a)), 0.22)
		var centre := Vector3(0, 0.81, -0.03) + out
		_place(hips, strip, "pelvis", Transform3D(b, centre))
	var belt := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.175
	tm.rings = 24
	belt.mesh = tm
	belt.material_override = gold
	_place(hips, belt, "pelvis", Transform3D(Basis.IDENTITY.scaled(Vector3(1.05, 1.0, 0.85)), Vector3(0, 0.96, -0.03)))
	# Bracers on both forearms.
	for side in ["l", "r"]:
		var sx := 1.0 if side == "l" else -1.0
		var br := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.042
		cm.bottom_radius = 0.036
		cm.height = 0.13
		br.mesh = cm
		br.material_override = _mat(c2, 0.4, 0.3)
		var arm := _attach("lowerarm_" + side)
		_place(arm, br, "lowerarm_" + side, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(sx * 0.53, 1.415, -0.05)))
	# Headband (or a gold circlet) and a necklace.
	var head := _attach("Head")
	var band := MeshInstance3D.new()
	var hb := TorusMesh.new()
	hb.inner_radius = 0.099
	hb.outer_radius = 0.109
	hb.rings = 24
	band.mesh = hb
	band.material_override = gold if bool(ch.get("circlet", false)) else _mat(c2, 0.5)
	_place(head, band, "Head", Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 1.70, 0.005)))
	var neck := _attach("spine_03")
	var lace := MeshInstance3D.new()
	var nm := TorusMesh.new()
	nm.inner_radius = 0.075
	nm.outer_radius = 0.083
	lace.mesh = nm
	lace.material_override = gold
	_place(neck, lace, "spine_03", Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 1.47, 0.02)))
	# Cape.
	if bool(ch.get("cape", false)):
		var back := _attach("spine_03")
		var cape := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.42, 0.95)
		qm.subdivide_depth = 8
		cape.mesh = qm
		cape_mat = ShaderMaterial.new()
		cape_mat.shader = _cape_shader
		cape_mat.set_shader_parameter("color", c1.darkened(0.15))
		cape.material_override = cape_mat
		_place(back, cape, "spine_03", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.0, -0.14)))

# ---------- Shop costumes (2026-11-25, after the owner's reference pictures) ----------
## Each costume = garments painted on the body by the shader (tops, sleeves, shorts,
## stockings, boots, gloves, shoes) + pieces made of simple shapes (skirts, apron, hats,
## wings, horns, tail).

func _box(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	return mi

func _torus(r_in: float, r_out: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r_in
	tm.outer_radius = r_out
	tm.rings = 24
	mi.mesh = tm
	mi.material_override = m
	return mi

func _cyl(top: float, bottom: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = m
	return mi

func _ball(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	return mi

## A cylinder from a to b (model rest space) under holder.
func _rod(holder: Node3D, bone: String, a: Vector3, b: Vector3, r0: float, r1: float, m: Material) -> void:
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var bs := Basis(side, up, side.cross(up)).orthonormalized()
	_place(holder, _cyl(r1, r0, a.distance_to(b), m), bone, Transform3D(bs, (a + b) * 0.5))

## Paints garments on the body (shader uniforms; see BODY_SHADER).
func _paint(p: Dictionary) -> void:
	for k in p:
		body_mat.set_shader_parameter(k, p[k])

## A flared skirt of pleats: length, flare, colours a / b, an optional hem colour.
func _skirt(hips: Node3D, length: float, flare: float, a: Color, b: Color, hem: Color = Color(0, 0, 0, 0), top_y: float = 0.97, n: int = 22) -> void:
	flare *= 0.6   # a soft flare: wide pleats read as a lampshade
	for k in n:
		var ang := TAU * k / n
		var out := Vector3(sin(ang) * 0.165, 0, cos(ang) * 0.13)
		var bs := Basis(Vector3.UP, ang).rotated(Vector3(cos(ang), 0, -sin(ang)), flare)
		var centre := Vector3(0, top_y - length * 0.5, -0.03) + out
		_place(hips, _box(Vector3(0.07, length, 0.01), _mat(a if k % 2 == 0 else b, 0.75)), "pelvis", Transform3D(bs, centre))
		if hem.a > 0.0:
			var down := bs * Vector3(0, -length * 0.5 - 0.012, 0.002)
			_place(hips, _box(Vector3(0.08, 0.026, 0.012), _mat(hem, 0.8)), "pelvis", Transform3D(bs, centre + down))

func _costume(id: String) -> void:
	var hips := _attach("pelvis")
	var head := _attach("Head")
	var chest := _attach("spine_03")
	var white := _mat(Color("f4f2ee"), 0.6)
	var black := _mat(Color("16161a"), 0.5)
	var gold := _mat(Color("e8b84a"), 0.3, 0.8)
	var silver := _mat(Color("c8ccd4"), 0.25, 0.9)
	match id:
		"maid":
			# Black corset with white lace edge and straps, white buttons, a flared black skirt
			# with a white lace hem, white apron with a bow, sheer black stockings with lace tops,
			# a frilled headpiece and a choker with a bow.
			_paint({"top_col": Color("141418"), "top_y": Vector2(0.96, 1.37), "trim_col": Color("f4f2ee"), "decal": 4,
				"stock_col": Color(0.05, 0.05, 0.06, 0.72), "stock_y": 0.72, "band_col": Color("101012"),
				"shoe_col": Color("101012"), "shoe_y": 0.09})
			_skirt(hips, 0.2, 0.55, Color("16161a"), Color("202026"), Color("f4f2ee"))
			_place(hips, _box(Vector3(0.21, 0.2, 0.008), white), "pelvis", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.865, 0.175)))
			for k in 8:
				_place(hips, _ball(0.016, white), "pelvis", Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.7, 0.5)), Vector3(-0.095 + k * 0.027, 0.765, 0.205)))
			for sx in [-1.0, 1.0]:
				_place(hips, _box(Vector3(0.06, 0.03, 0.012), black), "pelvis", Transform3D(Basis(Vector3.BACK, sx * 0.4), Vector3(sx * 0.035, 0.955, 0.16)))
			_place(head, _box(Vector3(0.17, 0.04, 0.025), white), "Head", Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.755, 0.03)))
			for k in 6:
				_place(head, _ball(0.018, white), "Head", Transform3D(Basis.IDENTITY, Vector3(-0.07 + k * 0.028, 1.78, 0.03)))
			_place(head, _box(Vector3(0.19, 0.012, 0.03), black), "Head", Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.745, 0.035)))
			_place(chest, _torus(0.058, 0.066, black), "spine_03", Transform3D(Basis.IDENTITY, Vector3(0, 1.525, -0.01)))
			for sx in [-1.0, 1.0]:
				_place(chest, _box(Vector3(0.035, 0.022, 0.01), black), "spine_03", Transform3D(Basis(Vector3.BACK, sx * 0.5), Vector3(sx * 0.018, 1.51, 0.06)))
		"secretary":
			# White satin blouse with long sleeves, a deep open V and buttons; a black pencil
			# skirt above the knee, black heels, glasses and pearls.
			_paint({"top_col": Color("f2f0ec"), "top_y": Vector2(0.93, 1.5), "sleeve_x": 0.62, "neck_v": 0.2, "top_rough": 0.3,
				"decal": 1, "decal_col": Color("d8d4cc"), "shoe_col": Color("0e0e10"), "shoe_y": 0.1,
				"bot_col": Color("16161a"), "bot_y": 0.6, "bot_top": 1.0})
			# The skirt is painted on her hips and thighs; this fills the gap between her legs.
			_place(hips, _cyl(0.13, 0.12, 0.3, _mat(Color("16161a"), 0.5)), "pelvis", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.75)), Vector3(0, 0.75, -0.03)))
			var frame := _mat(Color("1a1a1a"), 0.3, 0.4)
			for sx in [-1.0, 1.0]:
				_place(head, _torus(0.022, 0.027, frame), "Head", Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(sx * 0.034, 1.665, 0.105)))
			_place(head, _box(Vector3(0.02, 0.004, 0.004), frame), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.667, 0.108)))
			for k in 18:
				var a := TAU * k / 18.0
				_place(chest, _ball(0.009, _mat(Color("f4efe4"), 0.15, 0.3)), "spine_03", Transform3D(Basis.IDENTITY, Vector3(sin(a) * 0.075, 1.465 - (1.0 + cos(a)) * 0.02, cos(a) * 0.065 + 0.0)))
		"cop":
			# Black long-sleeve crop top with a zip and a gold badge, black shorts, glossy
			# thigh-high boots, gloves, a belt with handcuffs, police cap and sunglasses.
			_paint({"top_col": Color("121216"), "top_y": Vector2(1.18, 1.5), "sleeve_x": 0.62, "top_rough": 0.45,
				"decal": 2, "decal_col": Color("c8ccd4"), "bot_col": Color("121216"), "bot_y": 0.8, "bot_top": 1.06,
				"boot_col": Color("0a0a0c"), "boot_y": 0.72, "glove_col": Color("0a0a0c"), "glove_x": 0.6})
			_place(chest, _box(Vector3(0.035, 0.042, 0.008), gold), "spine_03", Transform3D(Basis.IDENTITY, Vector3(-0.075, 1.4, 0.115)))
			_place(hips, _torus(0.16, 0.18, black), "pelvis", Transform3D(Basis.IDENTITY.scaled(Vector3(1.05, 1.0, 0.85)), Vector3(0, 1.02, -0.03)))
			_place(hips, _box(Vector3(0.05, 0.035, 0.012), silver), "pelvis", Transform3D(Basis.IDENTITY, Vector3(0, 1.02, 0.125)))
			for k in 2:
				_place(hips, _torus(0.02, 0.027, silver), "pelvis", Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0.18, 0.925 - k * 0.045, 0.05)))
			_place(head, _cyl(0.118, 0.1, 0.075, black), "Head", Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 1.785, 0.0)))
			_place(head, _cyl(0.122, 0.122, 0.008, _mat(Color("08080a"), 0.2)), "Head", Transform3D(Basis(Vector3.RIGHT, -0.15).scaled(Vector3(1.0, 1.0, 1.25)), Vector3(0, 1.752, 0.04)))
			_place(head, _box(Vector3(0.04, 0.035, 0.01), gold), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.795, 0.114)))
			var lens := _mat(Color("0c0c0e"), 0.05, 0.6)
			for sx in [-1.0, 1.0]:
				_place(head, _ball(0.024, lens), "Head", Transform3D(Basis.IDENTITY.scaled(Vector3(1.2, 0.8, 0.3)), Vector3(sx * 0.034, 1.665, 0.106)))
		"nurse":
			# White tie-front crop top with short sleeves, red trim and a red cross, a white
			# pleated mini skirt with a red hem, white heels, the cap with a red cross.
			var red := _mat(Color("d42a2a"), 0.5)
			_paint({"top_col": Color("f6f4f0"), "top_y": Vector2(1.22, 1.48), "sleeve_x": 0.3, "neck_v": 0.12,
				"trim_col": Color("d42a2a"), "decal": 3, "decal_col": Color("d42a2a"), "shoe_col": Color("f4f2ee"), "shoe_y": 0.1})
			for sx in [-1.0, 1.0]:
				_place(chest, _box(Vector3(0.05, 0.06, 0.012), white), "spine_03", Transform3D(Basis(Vector3.BACK, sx * 0.6), Vector3(sx * 0.03, 1.19, 0.12)))
			_place(chest, _ball(0.02, white), "spine_03", Transform3D(Basis.IDENTITY, Vector3(0, 1.215, 0.125)))
			_skirt(hips, 0.19, 0.5, Color("f6f4f0"), Color("e8e6e2"), Color("d42a2a"))
			_place(head, _box(Vector3(0.16, 0.06, 0.1), white), "Head", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.765, 0.03)))
			_place(head, _box(Vector3(0.05, 0.016, 0.004), red), "Head", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.775, 0.083)))
			_place(head, _box(Vector3(0.016, 0.05, 0.004), red), "Head", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.775, 0.083)))
		"angel":
			# White corset with gold trim, white lace stockings, a soft white skirt, a glowing
			# halo and feathered wings.
			_paint({"top_col": Color("f8f6f0"), "top_y": Vector2(0.96, 1.37), "trim_col": Color("e8b84a"),
				"stock_col": Color(0.97, 0.96, 0.93, 0.55), "stock_y": 0.72, "band_col": Color("f4f2ee"),
				"shoe_col": Color("f4f2ee"), "shoe_y": 0.09})
			_skirt(hips, 0.22, 0.5, Color("f8f6f0"), Color("ece8de"), Color("e8b84a"))
			var halo := _mat(Color("ffd76a"), 0.2, 0.6)
			halo.emission_enabled = true
			halo.emission = Color("ffc84a")
			halo.emission_energy_multiplier = 1.4
			_place(head, _torus(0.09, 0.105, halo), "Head", Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 1.86, -0.02)))
			for sx in [-1.0, 1.0]:
				_feather_wing(chest, sx)
		"devil":
			# Red corset with black trim, sheer black stockings, a black skirt, curved horns,
			# a tail with a spade tip and webbed demon wings.
			var red := _mat(Color("c01818"), 0.3, 0.2)
			_paint({"top_col": Color("b01418"), "top_y": Vector2(0.96, 1.37), "top_rough": 0.35, "trim_col": Color("101012"),
				"stock_col": Color(0.05, 0.03, 0.03, 0.7), "stock_y": 0.72, "band_col": Color("101012"),
				"shoe_col": Color("a01016"), "shoe_y": 0.09})
			_skirt(hips, 0.18, 0.45, Color("16161a"), Color("2a0c10"), Color("b01418"))
			for sx in [-1.0, 1.0]:
				var pts := [Vector3(sx * 0.055, 1.79, 0.04), Vector3(sx * 0.075, 1.84, 0.03), Vector3(sx * 0.08, 1.885, 0.0), Vector3(sx * 0.07, 1.915, -0.03)]
				var rad := [0.022, 0.016, 0.01, 0.004, 0.0]
				for k in pts.size() - 1:
					_rod(head, "Head", pts[k], pts[k + 1], rad[k], rad[k + 1], red)
			var tail := [Vector3(0, 0.9, -0.16), Vector3(0, 0.8, -0.24), Vector3(0.03, 0.68, -0.3), Vector3(0.09, 0.58, -0.3), Vector3(0.15, 0.53, -0.24), Vector3(0.2, 0.55, -0.17)]
			for k in tail.size() - 1:
				_rod(hips, "pelvis", tail[k], tail[k + 1], 0.013, 0.011, red)
			var tip := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.08, 0.08, 0.012)
			tip.mesh = pm
			tip.material_override = red
			_place(hips, tip, "pelvis", Transform3D(Basis(Vector3.BACK, -0.9), Vector3(0.23, 0.58, -0.14)))
			for sx in [-1.0, 1.0]:
				_demon_wing(chest, sx)

## The wing's frame: (u outward, v up) in metres on her back -> model rest space.
func _wing_pt(sx: float, u: float, v: float) -> Vector3:
	return Vector3(sx * (0.07 + u), 1.36 + v, -0.15 - u * 0.35)

## A feathered angel wing: three rows of feathers along a curved arm, longest at the tip.
func _feather_wing(chest: Node3D, sx: float) -> void:
	var mats := [_mat(Color("fbfaf6"), 0.85), _mat(Color("eef1f4"), 0.85), _mat(Color("e2e8ee"), 0.85)]
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 6
	var n := 12
	for row in 3:
		for k in n:
			var t := float(k) / (n - 1)
			# The arm: out and up in a curve, highest near the tip (like a raised wing).
			var u := t * 0.42
			var v := sin(t * PI * 0.6) * 0.34
			var base := _wing_pt(sx, u, v - row * 0.06)
			# Short coverts on top, then longer flight feathers, longest towards the tip.
			var length: float = [0.1, 0.2, 0.26][row] * (0.75 + 0.6 * t) + (0.1 * t * t if row == 2 else 0.0)
			# Feathers hang down and fan out a little towards the tip.
			var ang := -PI / 2.0 + sx * t * 0.55
			var dir := Vector3(cos(ang), sin(ang), -0.12).normalized()
			var side := dir.cross(Vector3(0, 0, 1)).normalized()
			var bs := Basis(side, dir, side.cross(dir)).orthonormalized().scaled(Vector3(0.07, length, 0.01))
			var f := MeshInstance3D.new()
			f.mesh = sm
			f.material_override = mats[row]
			_place(chest, f, "spine_03", Transform3D(bs, base + dir * length * 0.45 + Vector3(0, 0, -0.004 * row)))

## A demon wing: bones (arm, then four fingers) with dark red skin webbed between them,
## the edge scalloped between the finger tips.
func _demon_wing(chest: Node3D, sx: float) -> void:
	var bone_m := _mat(Color("3a0c0e"), 0.45)
	var root := Vector2(0.0, 0.0)
	var elbow := Vector2(0.24, 0.2)
	var wrist := Vector2(0.44, 0.34)
	var tips := [Vector2(0.72, 0.12), Vector2(0.62, -0.16), Vector2(0.42, -0.36), Vector2(0.2, -0.42)]
	var body := Vector2(0.02, -0.26)
	_rod(chest, "spine_03", _wing_pt(sx, root.x, root.y), _wing_pt(sx, elbow.x, elbow.y), 0.016, 0.013, bone_m)
	_rod(chest, "spine_03", _wing_pt(sx, elbow.x, elbow.y), _wing_pt(sx, wrist.x, wrist.y), 0.013, 0.011, bone_m)
	for t in tips:
		_rod(chest, "spine_03", _wing_pt(sx, wrist.x, wrist.y), _wing_pt(sx, t.x, t.y), 0.008, 0.003, bone_m)
	# A claw on the wrist.
	_rod(chest, "spine_03", _wing_pt(sx, wrist.x, wrist.y), _wing_pt(sx, wrist.x + 0.05, wrist.y + 0.07), 0.009, 0.0, bone_m)
	# The membrane: a fan from the wrist round the edge (elbow, root, body, scallops, tips).
	var ring: Array = [elbow, root, body]
	var prev: Vector2 = body
	var back := tips.duplicate()
	back.reverse()
	for t in back:
		var mid: Vector2 = (prev + t) * 0.5
		ring.append(mid.lerp(wrist, 0.22))
		ring.append(t)
		prev = t
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w3 := _wing_pt(sx, wrist.x, wrist.y)
	for k in ring.size() - 1:
		var a: Vector2 = ring[k]
		var b: Vector2 = ring[k + 1]
		for p in [w3, _wing_pt(sx, a.x, a.y), _wing_pt(sx, b.x, b.y)]:
			st.add_vertex(p)
	st.generate_normals()
	var mem := MeshInstance3D.new()
	mem.mesh = st.commit()
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color("8a1014")
	mm.roughness = 0.55
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mm.rim_enabled = true
	mm.rim = 0.4
	mem.material_override = mm
	_place(chest, mem, "spine_03", Transform3D.IDENTITY)

## Puts `node` under `holder` (which follows `bone`) so it sits at `rest_xf`
## (model space, metres) in the T-pose.
func _place(holder: Node3D, node: Node3D, bone: String, rest_xf: Transform3D) -> void:
	holder.add_child(node)
	node.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse() * rest_xf

func set_skull(on: bool, ch: Dictionary) -> void:
	var c1: Color = ch.c1
	if on:
		body_mat.set_shader_parameter("outfit", c1.lightened(0.15))
		body_mat.set_shader_parameter("skin", Color(0.55, 0.45, 0.7))
		body_mat.set_shader_parameter("glow", 0.9)
	else:
		body_mat.set_shader_parameter("outfit", c1)
		body_mat.set_shader_parameter("skin", ch.get("skin3d", Color(1, 1, 1)))
		body_mat.set_shader_parameter("glow", 0.0)
	if cape_mat:
		cape_mat.set_shader_parameter("glow", 0.6 if on else 0.0)

## The weapon in her right hand (-1 = empty hand).
func set_weapon(w: int, mesh_maker: Callable) -> void:
	for c in weapon_holder.get_children():
		c.queue_free()
	if w < 0:
		return
	var m: Node3D = mesh_maker.call(w)
	weapon_holder.add_child(m)
	# In the T-pose the palm faces down: hold it across the palm, pointing forward.
	m.transform = Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)) if w == 0 else Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, -0.03, 0.05))

## Plays a clip unless it's already the current one (a one-shot clip that has
## ended keeps its last pose); `force` restarts it (a second hit).
func play(name: String, blend: float = 0.2, force: bool = false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if name == current and not force:
		return
	if force:
		anim.stop()
	current = name
	anim.play(name, blend)

func queue_after(name: String) -> void:
	if anim:
		anim.queue(name)
		current = name

func set_wind(w: float) -> void:
	if cape_mat:
		cape_mat.set_shader_parameter("wind", w)

## A white flash on a hit.
func flash() -> void:
	_flash_t = 0.25

func _process(delta: float) -> void:
	if _flash_t > 0.0 and body_mat:
		_flash_t = maxf(0.0, _flash_t - delta)
		body_mat.set_shader_parameter("flash", Color(1, 1, 1, _flash_t * 2.4))
