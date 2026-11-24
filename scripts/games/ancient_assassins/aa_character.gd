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
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.0001);
	float cloth = smoothstep(0.24, 0.12, sat);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 fabric = outfit.rgb * clamp(lum / 0.5, 0.45, 1.25);
	vec3 col = mix(c * skin.rgb, fabric, cloth);
	ALBEDO = mix(col, flash.rgb, flash.a);
	ROUGHNESS = mix(texture(rough_tex, UV).g * 0.85, 0.35, cloth);
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
