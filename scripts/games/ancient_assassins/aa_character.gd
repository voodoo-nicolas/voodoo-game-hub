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

## Shop dances (2026-11-27): the clip each one stands on while its overlay (_overlay) moves the
## body on top of it. "" (the default) is Quaternius' Dance_Loop ("win").
const DANCES := {
	"samba": {"clip": "win", "speed": 1.35},
	"belly": {"clip": "idle", "speed": 1.0},
	"twirl": {"clip": "idle", "speed": 1.0},
	"strut": {"clip": "strut", "speed": 1.0},
	"pump": {"clip": "idle", "speed": 1.0},
}
## Shop emotes: one-shot overlays on the idle pose, seconds long.
const EMOTES := {"wave": 2.6, "kiss": 2.4, "hips": 2.8, "flex": 2.6, "flip": 2.4, "salute": 2.2}
## Bones the pose layer may turn (parents first); each is keyed in every clip.
const POSE_BONES := ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r",
	"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"]

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
// corset: 1 = boning seams and a lace-up front. sheen: satin rim light on the garment.
// stock_net: 1 = fishnet stockings. seams: a seam up the back of each stocking.
uniform int corset = 0;
uniform float sheen = 0.0;
uniform int stock_net = 0;
uniform bool seams = false;
uniform vec4 decal_col : source_color = vec4(1.0);
// Tattoos (2026-11-27): 0 none, 1 tribal armbands, 2 rose (left thigh), 3 butterfly (lower back),
// 4 sun (belly), 5 ankle vines, 6 tribal sleeve (left arm). Ink only shows on skin.
uniform int tat = 0;
uniform vec4 tat_col : source_color = vec4(0.03, 0.03, 0.05, 0.95);
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
float ringm(float a, float b, float x) {
	return step(a, x) * step(x, b);
}
float tattoo(vec3 r) {
	float ax = abs(r.x);
	float m = 0.0;
	bool arm = ax > 0.17 && r.y > 1.3;
	bool leg = r.y < 0.86;
	bool front = r.z > -0.03;
	if (tat == 1 && arm && ax > 0.2 && ax < 0.36) {
		float th = atan(r.z, r.y - 1.42);
		float zz = abs(fract(th * 2.4) - 0.5) * 0.03;
		float mid = step(abs(ax - 0.268 - zz + 0.0075), 0.0065);
		m = max(ringm(0.215, 0.235, ax), max(ringm(0.30, 0.32, ax), mid));
	} else if (tat == 2 && leg && front && r.x > 0.0) {
		vec2 d = vec2(r.x - 0.12, r.y - 0.66);
		float R = length(d);
		float a = atan(d.y, d.x);
		if (R < 0.062) {
			float petals = 1.0 - smoothstep(0.25, 0.45, abs(sin(R * 120.0 - a * 2.0)));
			m = max(petals, step(0.055, R) * 0.9);
		}
		vec2 l1 = (d - vec2(0.05, -0.065)) / vec2(0.035, 0.014);
		vec2 l2 = (d - vec2(-0.045, -0.07)) / vec2(0.035, 0.014);
		if (length(l1) < 1.0 || length(l2) < 1.0) m = 0.9;
	} else if (tat == 3 && !leg && !arm && r.z < -0.03) {
		vec2 q = vec2(ax, r.y - 1.11);
		float up = length((q - vec2(0.055, 0.032)) / vec2(0.055, 0.034));
		float lo = length((q - vec2(0.04, -0.03)) / vec2(0.036, 0.026));
		float w = min(up, lo);
		if (w < 1.0) m = (w > 0.78) ? 1.0 : 0.4;
		if (ax < 0.006 && abs(q.y) < 0.055) m = 1.0;
		if (ax < 0.035 && q.y > 0.055 && q.y < 0.1 && abs(ax - (q.y - 0.055) * 0.8) < 0.004) m = 1.0;
	} else if (tat == 4 && !leg && !arm && front) {
		vec2 d = vec2(r.x, r.y - 1.07);
		float R = length(d);
		float a = atan(d.y, d.x);
		if (R < 0.016) m = 1.0;
		else if (R > 0.021 && R < 0.026) m = 1.0;
		else if (R > 0.031 && R < 0.052 && abs(sin(a * 8.0)) > 0.7) m = 1.0;
	} else if (tat == 5 && leg && r.y > 0.07 && r.y < 0.24) {
		float th = atan(r.z + 0.03, r.x - sign(r.x) * 0.11);
		float vine = r.y - 0.15 - 0.022 * sin(th * 3.0);
		m = step(abs(vine), 0.007);
		float leaf = length(vec2(fract(th * 2.0) - 0.5, (r.y - 0.17) * 18.0));
		if (leaf < 0.34 && r.y > 0.17) m = 1.0;
	} else if (tat == 6 && arm && r.x > 0.0 && ax > 0.2 && ax < 0.64) {
		float th = atan(r.z, r.y - 1.42);
		float s1 = step(0.8, fract(ax * 16.0 + th * 0.9));
		float s2 = 1.0 - smoothstep(0.1, 0.2, abs(sin(th * 5.0 + ax * 26.0)));
		m = max(s1, s2 * 0.9);
		if (ax < 0.3) m = max(m, 0.6);
	}
	return m;
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
	if (tat > 0) {
		col = mix(col, tat_col.rgb * (0.5 + 0.5 * lum), tattoo(rp) * tat_col.a * (1.0 - cloth));
	}
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
		if (r.y > lace && band_col.a > 0.0) {
			// The lace top: an open floral weave over the skin.
			float holes = step(0.55, fract((r.y + atan(r.z + 0.03, r.x - sign(r.x) * 0.11) * 0.02) / 0.009)) * step(0.5, fract(r.y / 0.014 + 0.25));
			g = vec4(band_col.rgb, 1.0);
			grough = 0.7;
			if (holes > 0.5 && r.y < stock_y - 0.012) g = vec4(0.0);
		} else if (stock_net == 1) {
			float u = atan(r.z + 0.03, r.x - sign(r.x) * 0.11) * 0.06;
			float d1 = abs(fract((r.y + u) / 0.016) - 0.5);
			float d2 = abs(fract((r.y - u) / 0.016) - 0.5);
			if (min(d1, d2) < 0.09) { g = vec4(stock_col.rgb, 1.0); grough = 0.5; }
		} else {
			col = mix(col, stock_col.rgb * (0.55 + 0.45 * lum), stock_col.a);
			rough = 0.32;
		}
		if (seams && abs(ax - 0.11) < 0.0035 && r.z < -0.05 && r.y < lace) g = vec4(stock_col.rgb * 0.6, 1.0);
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
			if (corset == 1 && torso && !edge) {
				// Boning seams (four in front, four behind) and a lace-up front.
				float bx = min(abs(ax - 0.05), abs(ax - 0.1));
				if (bx < 0.0035) g.rgb *= 0.55;
				if (front && ax < 0.022 && r.y < top_y.y - 0.02) {
					float cross = abs(fract(r.y / 0.028) - 0.5) * 0.044;
					if (abs(ax - cross) < 0.0035) g = vec4(trim_col.a > 0.0 ? trim_col.rgb : vec3(0.9), 1.0);
					else g.rgb *= 0.6;
				}
			}
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
	float rim = 0.0;
	if (g.a > 0.0) {
		col = g.rgb * gshade;
		rough = grough;
		cloth = 1.0;
		rim = sheen;
	}
	ALBEDO = mix(col, flash.rgb, flash.a);
	ROUGHNESS = rough;
	RIM = rim;
	RIM_TINT = 0.7;
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
# Knockback (owner, 2026-11-26: a hit must shove her, not leave a statue).
var _knock_t := -1.0
var _knock_s := 0.0
var _knock_side := 1.0
var _knock_ko := false
var _model_base := Transform3D.IDENTITY
# Pose layer (2026-11-27): each amazon stands her own way (stance = degrees per bone, turned in
# MODEL space on top of the clip), and the Shop's emotes / dances move the body the same way.
signal emote_done
var _bones := {}          # bone name -> index
var _base_rot := {}       # index -> local rotation the clip gave it this frame (before the layer)
var _stance := {}         # bone -> Vector3 degrees
var _stance_w := 1.0
var _state := "idle"      # the clip name the game asked for ("idle", "ready", "aim", "win"...)
var _dance := ""
var _ov := ""             # running overlay: an emote id or "d:<dance>"
var _ov_t := 0.0
var _ov_len := 0.0
var _ov_w := 0.0
var _ov_off := false
var _spin := 0.0
var _idle_clip := "idle"
var _hair_tint := Color("2a1a10")

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
	model.scale = ch.get("scale", Vector3.ONE)   # height / build, so they are not clones
	model.position.y = -float(ch.get("drop", 0.0))   # bent knees keep her feet on the ground
	_model_base = model.transform
	skel = model.find_child("Skeleton3D", true, false)
	_stance = ch.get("stance", {})
	_idle_clip = str(ch.get("idle_clip", "idle"))
	_hair_tint = ch.get("hair_col", Color("2a1a10"))
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
	var extra := str(ch.get("hair_extra", ""))
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
	if extra != "":
		_hair_extra(extra, _attach("Head"))
	body_mat.set_shader_parameter("tat", int(ch.get("tattoo", 0)))
	_dress(ch)
	weapon_holder = _attach("hand_r")
	weapon_holder.transform = skel.get_bone_global_rest(skel.find_bone("hand_r")).affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(-0.66, 1.39, 0.0))
	set_skull(skull, ch)
	# Animations.
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.root_node = NodePath("..")
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL   # _process advances it, then the pose layer
	if _anims:
		anim.add_animation_library("", _anims)
	for b in POSE_BONES:
		var bi := skel.find_bone(b)
		if bi >= 0:
			_bones[b] = bi
			_base_rot[bi] = skel.get_bone_pose_rotation(bi)
	play("idle", 0.0)
	# No two assassins breathe in step: a random start and her own pace.
	var clip := _idle_clip if anim.has_animation(_idle_clip) else "idle"
	if anim.has_animation(clip):
		anim.seek(randf() * anim.get_animation(clip).length, true)
	anim.speed_scale = float(ch.get("pace", 1.0)) * randf_range(0.97, 1.03)

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

## A skirt: one continuous cloth mesh round her hips (rest pose; hips are ~0.40 m wide
## and 0.24 m deep at y 0.94, centre z -0.04). length (m), flare 0..1, soft pleats in
## colour a (b = the shade in the folds), an optional hem band (scalloped lace when lace).
func _skirt(hips: Node3D, length: float, flare: float, a: Color, b: Color, hem: Color = Color(0, 0, 0, 0), top_y: float = 1.0, lace: bool = false, pleats: int = 18) -> void:
	_place(hips, _flare_mesh(top_y, length, 0.19, 0.135, 0.205 + flare * 0.07, 0.15 + flare * 0.06, pleats, 0.035 + flare * 0.05, 0.0, TAU, false, a, b), "pelvis", Transform3D.IDENTITY)
	if hem.a > 0.0:
		var rx := 0.205 + flare * 0.07
		var rz := 0.15 + flare * 0.06
		_place(hips, _flare_mesh(top_y - length + 0.004, 0.03 if lace else 0.022, rx + 0.002, rz + 0.002, rx + 0.012, rz + 0.01, pleats, 0.035 + flare * 0.05, 0.0, TAU, lace, hem, hem.darkened(0.15)), "pelvis", Transform3D.IDENTITY)

## A cloth that hangs from a ring: an ellipse rx0 x rz0 at y_top widening to rx1 x rz1 at the
## bottom, with soft pleats (pleats, amp), over the angles a0..a1 (0 = her front, +x = her left);
## scallop = a lace-scalloped bottom edge. Colours: a on the crests, b in the folds.
func _flare_mesh(y_top: float, length: float, rx0: float, rz0: float, rx1: float, rz1: float, pleats: int, amp: float, a0: float, a1: float, scallop: bool, a: Color, b: Color) -> MeshInstance3D:
	var seg := 72
	var rows := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var full := absf(a1 - a0 - TAU) < 0.001
	var pts: Array = []
	for r in rows + 1:
		var t := float(r) / rows
		var row: Array = []
		for k in seg + 1:
			var ang := lerpf(a0, a1, float(k) / seg) if not full else TAU * k / seg
			var wave := sin(ang * pleats)
			var grow := 1.0 + amp * pow(t, 0.8) * wave / maxf(rx0, 0.01)
			var rx := lerpf(rx0, rx1, t) * grow
			var rz := lerpf(rz0, rz1, t) * grow
			var y := y_top - length * t
			if scallop and r == rows:
				y += absf(sin(ang * pleats * 2.0)) * 0.012
			row.append([Vector3(sin(ang) * rx, y, -0.04 + cos(ang) * rz), a.lerp(b, clampf(0.5 - 0.5 * wave, 0.0, 1.0) * t * 0.9 + (0.0 if t > 0.0 else 0.0))])
		pts.append(row)
	for r in rows:
		for k in seg:
			var q := [pts[r][k], pts[r][k + 1], pts[r + 1][k + 1], pts[r + 1][k]]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(q[i][1])
				st.add_vertex(q[i][0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _cloth_mat(Color.WHITE, 0.62)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.rim = 0.12
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi

## Two-sided cloth with a soft sheen at the edges (satin catches the light).
func _cloth_mat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m

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
				"corset": 1, "sheen": 0.35, "top_rough": 0.4, "seams": true,
				"stock_col": Color(0.05, 0.05, 0.06, 0.72), "stock_y": 0.72, "band_col": Color("101012"),
				"shoe_col": Color("101012"), "shoe_y": 0.09})
			_skirt(hips, 0.21, 0.75, Color("18181c"), Color("060608"), Color("f4f2ee"), 1.0, true, 20)
			# A curved white apron over the front of the skirt, lace-edged, with a waistband.
			_place(hips, _flare_mesh(0.995, 0.17, 0.205, 0.15, 0.27, 0.23, 7, 0.012, -0.6, 0.6, true, Color("f6f4f0"), Color("d8d6d2")), "pelvis", Transform3D.IDENTITY)
			_place(hips, _flare_mesh(1.005, 0.022, 0.193, 0.14, 0.195, 0.142, 1, 0.0, 0.0, TAU, false, Color("f6f4f0"), Color("f6f4f0")), "pelvis", Transform3D.IDENTITY)
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
			_paint({"top_col": Color("f2f0ec"), "top_y": Vector2(0.93, 1.5), "sleeve_x": 0.62, "neck_v": 0.2, "top_rough": 0.22, "sheen": 0.6,
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
				"decal": 2, "decal_col": Color("c8ccd4"), "sheen": 0.5, "bot_col": Color("121216"), "bot_y": 0.8, "bot_top": 1.06,
				"boot_col": Color("0a0a0c"), "boot_y": 0.72, "glove_col": Color("0a0a0c"), "glove_x": 0.6})
			_place(chest, _box(Vector3(0.035, 0.042, 0.008), gold), "spine_03", Transform3D(Basis.IDENTITY, Vector3(-0.075, 1.4, 0.115)))
			_place(hips, _flare_mesh(1.045, 0.035, 0.19, 0.135, 0.195, 0.138, 1, 0.0, 0.0, TAU, false, Color("0a0a0c"), Color("0a0a0c")), "pelvis", Transform3D.IDENTITY)
			_place(hips, _box(Vector3(0.05, 0.035, 0.012), silver), "pelvis", Transform3D(Basis.IDENTITY, Vector3(0, 1.027, 0.1)))
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
			_skirt(hips, 0.19, 0.55, Color("f6f4f0"), Color("c8c6c2"), Color("d42a2a"), 1.0, false, 24)
			_place(head, _box(Vector3(0.16, 0.06, 0.1), white), "Head", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.765, 0.03)))
			_place(head, _box(Vector3(0.05, 0.016, 0.004), red), "Head", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.775, 0.083)))
			_place(head, _box(Vector3(0.016, 0.05, 0.004), red), "Head", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.775, 0.083)))
		"angel":
			# White corset with gold trim, white lace stockings, a soft white skirt, a glowing
			# halo and feathered wings.
			_paint({"top_col": Color("f8f6f0"), "top_y": Vector2(0.96, 1.37), "trim_col": Color("e8b84a"), "corset": 1, "sheen": 0.5, "top_rough": 0.35,
				"stock_col": Color(0.97, 0.96, 0.93, 0.55), "stock_y": 0.72, "band_col": Color("f4f2ee"),
				"shoe_col": Color("f4f2ee"), "shoe_y": 0.09})
			_skirt(hips, 0.23, 0.85, Color("fbfaf6"), Color("d6d2c8"), Color("e8b84a"), 1.0, true, 16)
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
			_paint({"top_col": Color("b01418"), "top_y": Vector2(0.96, 1.37), "top_rough": 0.25, "trim_col": Color("101012"),
				"corset": 1, "sheen": 0.6, "stock_net": 1,
				"stock_col": Color(0.05, 0.03, 0.03, 0.7), "stock_y": 0.72, "band_col": Color("101012"),
				"shoe_col": Color("a01016"), "shoe_y": 0.09})
			_skirt(hips, 0.18, 0.6, Color("1a0a0c"), Color("050203"), Color("b01418"), 1.0, true, 20)
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
		"domina":
			# Glossy black: a studded corset with silver trim and lacing, tiny shorts, thigh-high
			# boots, long gloves, a spiked choker, silver cuffs, garter straps, a belt and a riding crop.
			var silver_m := _mat(Color("d6dae2"), 0.2, 0.95)
			var latex := _mat(Color("0a0a0d"), 0.12, 0.2)
			_paint({"top_col": Color("08080b"), "top_y": Vector2(1.0, 1.4), "trim_col": Color("c8ccd4"), "decal": 4,
				"corset": 1, "sheen": 0.8, "top_rough": 0.14, "bot_col": Color("08080b"), "bot_y": 0.82, "bot_top": 1.04,
				"boot_col": Color("060608"), "boot_y": 0.8, "glove_col": Color("060608"), "glove_x": 0.3})
			# Studs down the corset front.
			for k in 5:
				_place(chest, _ball(0.009, silver_m), "spine_03", Transform3D(Basis.IDENTITY, Vector3(0.055, 1.07 + k * 0.058, 0.108 - absf(k - 2) * 0.004)))
			# Garter straps from the belt to the boot tops.
			for sx in [-1.0, 1.0]:
				_rod(hips, "pelvis", Vector3(sx * 0.115, 1.02, 0.1), Vector3(sx * 0.125, 0.83, 0.1), 0.008, 0.008, latex)
				_rod(hips, "pelvis", Vector3(sx * 0.17, 1.02, -0.02), Vector3(sx * 0.2, 0.83, -0.02), 0.008, 0.008, latex)
				_place(hips, _ball(0.013, silver_m), "pelvis", Transform3D(Basis.IDENTITY, Vector3(sx * 0.125, 0.835, 0.1)))
			# A belt with a ring buckle, the crop at the hip.
			_place(hips, _flare_mesh(1.06, 0.035, 0.19, 0.135, 0.195, 0.138, 1, 0.0, 0.0, TAU, false, Color("0a0a0d"), Color("0a0a0d")), "pelvis", Transform3D.IDENTITY)
			_place(hips, _torus(0.016, 0.024, silver_m), "pelvis", Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.04, 0.12)))
			_rod(hips, "pelvis", Vector3(-0.2, 1.03, 0.0), Vector3(-0.36, 0.78, 0.1), 0.007, 0.006, latex)
			_place(hips, _box(Vector3(0.035, 0.05, 0.006), latex), "pelvis", Transform3D(Basis(Vector3.BACK, 0.5), Vector3(-0.375, 0.76, 0.105)))
			# Choker with spikes, a ring at the front.
			_place(chest, _torus(0.055, 0.064, latex), "spine_03", Transform3D.IDENTITY.translated(Vector3(0, 1.52, -0.005)))
			for k in 9:
				var a := PI * 0.15 + PI * 0.7 * k / 8.0
				var sp := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(0.012, 0.022, 0.012)
				sp.mesh = pm
				sp.material_override = silver_m
				_place(chest, sp, "spine_03", Transform3D(Basis(Vector3.UP, a - PI / 2).rotated(Vector3.RIGHT, 0.0), Vector3(sin(a - PI / 2) * -0.07, 1.525, cos(a - PI / 2) * 0.07 - 0.005)))
			_place(chest, _torus(0.009, 0.014, silver_m), "spine_03", Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.495, 0.065)))
			# Silver cuffs on both wrists.
			for side in ["l", "r"]:
				var sxx := 1.0 if side == "l" else -1.0
				var arm := _attach("lowerarm_" + side)
				_place(arm, _cyl(0.038, 0.038, 0.045, silver_m), "lowerarm_" + side, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(sxx * 0.6, 1.415, -0.03)))
			# A peaked cap, tilted, with a silver badge.
			_place(head, _cyl(0.112, 0.1, 0.06, latex), "Head", Transform3D(Basis(Vector3.RIGHT, -0.1).rotated(Vector3.BACK, 0.12), Vector3(0.01, 1.775, 0.0)))
			_place(head, _cyl(0.12, 0.12, 0.008, latex), "Head", Transform3D(Basis(Vector3.RIGHT, -0.1).rotated(Vector3.BACK, 0.12).scaled(Vector3(1.0, 1.0, 1.2)), Vector3(0.01, 1.748, 0.045)))
			_place(head, _ball(0.016, silver_m), "Head", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.4)), Vector3(0.012, 1.775, 0.112)))
		"belly":
			# Teal and gold: a jewelled top with straps, a low hip band, sheer harem trousers gathered
			# at gold ankle cuffs, a coin belt, bangles, a tiara and a face veil. Bare midriff.
			var teal_c := Color("0aa6a8")
			var gold_m := _mat(Color("f0c04a"), 0.25, 0.85)
			var sheer := StandardMaterial3D.new()
			sheer.albedo_color = Color(0.12, 0.78, 0.8, 0.5)
			sheer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sheer.cull_mode = BaseMaterial3D.CULL_DISABLED
			sheer.roughness = 0.3
			sheer.rim_enabled = true
			sheer.rim = 0.4
			_paint({"top_col": teal_c, "top_y": Vector2(1.25, 1.4), "trim_col": Color("f0c04a"), "decal": 4, "sheen": 0.6, "top_rough": 0.3,
				"bot_col": teal_c, "bot_y": 0.9, "bot_top": 0.98})
			# Gold fringe and a jewel on the top.
			for k in 7:
				_place(chest, _ball(0.011, gold_m), "spine_03", Transform3D(Basis.IDENTITY, Vector3(-0.065 + k * 0.0217, 1.255, 0.098)))
			_place(chest, _ball(0.016, _mat(Color("e0206a"), 0.1, 0.4)), "spine_03", Transform3D(Basis.IDENTITY, Vector3(0, 1.33, 0.12)))
			# Harem trousers: a wide thigh and a wide calf per leg, gathered at the ankle.
			for sx in [-1.0, 1.0]:
				var side := "l" if sx > 0.0 else "r"
				var th := _attach("thigh_" + side)
				var cf := _attach("calf_" + side)
				_rod(th, "thigh_" + side, Vector3(sx * 0.098, 0.93, -0.01), Vector3(sx * 0.098, 0.53, -0.015), 0.115, 0.125, sheer)
				_rod(cf, "calf_" + side, Vector3(sx * 0.098, 0.53, -0.015), Vector3(sx * 0.098, 0.12, 0.0), 0.125, 0.075, sheer)
				_place(cf, _cyl(0.064, 0.064, 0.035, gold_m), "calf_" + side, Transform3D(Basis.IDENTITY, Vector3(sx * 0.098, 0.11, 0.0)))
				_place(th, _cyl(0.06, 0.06, 0.03, gold_m), "thigh_" + side, Transform3D(Basis.IDENTITY, Vector3(sx * 0.098, 0.62, -0.012)))
			# The coin belt: a gold band and hanging coins all round the hips.
			_place(hips, _flare_mesh(1.0, 0.03, 0.2, 0.145, 0.205, 0.148, 1, 0.0, 0.0, TAU, false, Color("f0c04a"), Color("f0c04a")), "pelvis", Transform3D.IDENTITY)
			for k in 26:
				var a := TAU * k / 26.0
				var cn := _cyl(0.012, 0.012, 0.004, gold_m)
				_place(hips, cn, "pelvis", Transform3D(Basis(Vector3.RIGHT, PI / 2.0 - 0.0).rotated(Vector3.UP, a), Vector3(sin(a) * 0.212, 0.955 - (k % 2) * 0.03, -0.04 + cos(a) * 0.152)))
			# Bangles and upper-arm bands.
			for side in ["l", "r"]:
				var sxx := 1.0 if side == "l" else -1.0
				var lo := _attach("lowerarm_" + side)
				for k in 3:
					_place(lo, _cyl(0.034, 0.034, 0.008, gold_m), "lowerarm_" + side, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(sxx * (0.58 + k * 0.014), 1.415, -0.03)))
				var up := _attach("upperarm_" + side)
				_place(up, _cyl(0.05, 0.05, 0.03, gold_m), "upperarm_" + side, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(sxx * 0.27, 1.42, -0.01)))
			# Tiara and a face veil under the eyes.
			_place(head, _torus(0.096, 0.104, gold_m), "Head", Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(0, 1.735, 0.01)))
			_place(head, _ball(0.016, _mat(Color("e0206a"), 0.1, 0.4)), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.775, 0.095)))
			var veil := StandardMaterial3D.new()
			veil.albedo_color = Color(0.12, 0.78, 0.8, 0.38)
			veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			veil.cull_mode = BaseMaterial3D.CULL_DISABLED
			_place(head, _box(Vector3(0.14, 0.05, 0.004), veil), "Head", Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 1.628, 0.098)))
			for k in 5:
				_place(head, _ball(0.007, gold_m), "Head", Transform3D(Basis.IDENTITY, Vector3(-0.06 + k * 0.03, 1.646, 0.104)))

# ---------- Shop hairstyles (2026-11-27): the base hair plus pieces made of simple shapes ----------

func _hair_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = _hair_tint
	m.roughness = 0.5
	m.metallic_specular = 0.5
	return m

## A tail of balls and tapered rods through points (model rest space) under the Head bone.
func _tail(head: Node3D, pts: Array, rad: Array, m: Material) -> void:
	for k in pts.size() - 1:
		_rod(head, "Head", pts[k], pts[k + 1], rad[k], rad[k + 1], m)
	for k in pts.size():
		_place(head, _ball(rad[k], m), "Head", Transform3D(Basis.IDENTITY, pts[k]))

func _hair_extra(kind: String, head: Node3D) -> void:
	var hm := _hair_mat()
	var tie := _mat(Color("e8b84a"), 0.3, 0.8)
	match kind:
		"ponytail":
			_tail(head, [Vector3(0, 1.765, -0.07), Vector3(0, 1.735, -0.15), Vector3(0, 1.66, -0.2), Vector3(0, 1.55, -0.2), Vector3(0, 1.43, -0.16)], [0.04, 0.052, 0.05, 0.038, 0.012], hm)
			_place(head, _ball(0.036, tie), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.755, -0.095)))
		"pigtails":
			for sx in [-1.0, 1.0]:
				_tail(head, [Vector3(sx * 0.1, 1.745, -0.03), Vector3(sx * 0.14, 1.7, -0.04), Vector3(sx * 0.16, 1.6, -0.03), Vector3(sx * 0.16, 1.5, -0.02), Vector3(sx * 0.15, 1.42, -0.01)], [0.036, 0.046, 0.042, 0.03, 0.01], hm)
				_place(head, _ball(0.03, tie), "Head", Transform3D(Basis.IDENTITY, Vector3(sx * 0.115, 1.735, -0.035)))
		"braids":
			for sx in [-1.0, 1.0]:
				for k in 11:
					var t := k / 10.0
					var c := Vector3(sx * (0.12 - 0.01 * t) + (0.011 if k % 2 == 0 else -0.011), 1.62 - 0.34 * t, 0.045 + 0.02 * t)
					var b := _ball(0.026 - 0.011 * t, hm)
					_place(head, b, "Head", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.45, 1.0)), c))
				_place(head, _ball(0.016, tie), "Head", Transform3D(Basis.IDENTITY, Vector3(sx * 0.11, 1.28, 0.065)))
		"afro":
			_place(head, _ball(0.17, hm), "Head", Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.95, 1.0)), Vector3(0, 1.775, -0.02)))
			for k in 22:
				var y := 1.0 - 2.0 * (k + 0.5) / 22.0
				var r := sqrt(1.0 - y * y)
				var a := k * 2.39996
				var dir := Vector3(cos(a) * r, y * 0.95, sin(a) * r)
				if dir.y < -0.35 or dir.z > 0.55:
					continue
				_place(head, _ball(0.055, hm), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.775, -0.02) + dir * 0.15))
		"topknot":
			_place(head, _ball(0.07, hm), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.85, -0.02)))
			_place(head, _cyl(0.04, 0.05, 0.05, hm), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.8, -0.015)))
			_place(head, _torus(0.045, 0.054, tie), "Head", Transform3D(Basis.IDENTITY, Vector3(0, 1.815, -0.015)))
		"mohawk":
			for k in 11:
				var t := k / 10.0
				var h := 0.07 + 0.06 * sin(t * PI)
				var z := lerpf(0.09, -0.13, t)
				var y := 1.8 - 0.05 * absf(t - 0.35) + h * 0.45 - 0.02
				_place(head, _box(Vector3(0.026, h, 0.05), hm), "Head", Transform3D(Basis(Vector3.RIGHT, -0.5 * (t - 0.4)), Vector3(0, y, z)))

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

## A little 3D stage for the amazon: its own world, transparent, warm lights, (optionally) a
## gold plinth under her feet. Returns the SubViewport; the camera is its child "Cam".
## The Shop's preview, Options and the Landing all use it.
static func make_stage(parent: Control, h: float, plinth: bool = true) -> SubViewport:
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.custom_minimum_size = Vector2(0, h)
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vc.add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 0.95)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()   # a warm rim from behind
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 1.6
	rim.light_color = Color("ffb877")
	vp.add_child(rim)
	if plinth:
		var disc := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		tm.rings = 40
		disc.mesh = tm
		disc.scale = Vector3(1, 0.15, 1)
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color("e8b84a")
		dm.metallic = 0.8
		dm.roughness = 0.3
		dm.emission_enabled = true
		dm.emission = Color("ffb84a") * 0.4
		disc.material_override = dm
		vp.add_child(disc)
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 40
	vp.add_child(cam)
	frame_cam(vp, 1.0)
	return vp

## Camera for the stage: zoom 1 = the whole amazon, 2+ = closer (looks higher up her body).
static func frame_cam(vp: SubViewport, zoom: float) -> void:
	var cam: Camera3D = vp.get_node("Cam")
	var z := clampf(zoom, 0.55, 3.2)
	var look := Vector3(0, lerpf(0.95, 1.5, clampf((z - 1.0) / 1.6, 0.0, 1.0)) , 0)
	cam.position = Vector3(0, look.y + 0.12, 3.1 / z)
	cam.look_at(look)

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
## ended keeps its last pose); `force` restarts it (a second hit). "idle" uses her own idle
## clip; "win" plays her Shop dance when she has one.
func play(name: String, blend: float = 0.2, force: bool = false) -> void:
	if anim == null:
		return
	_state = name
	var clip := name
	if name == "win" and _dance != "" and DANCES.has(_dance):
		clip = str(DANCES[_dance].clip)
		if _ov != "d:" + _dance:
			_start_ov("d:" + _dance, 0.0)
		anim.speed_scale = float(DANCES[_dance].speed)
	else:
		if _ov.begins_with("d:"):
			_ov_off = true
		if name == "idle" and anim.has_animation(_idle_clip):
			clip = _idle_clip
	if not anim.has_animation(clip):
		return
	if clip == current and not force:
		return
	if force:
		anim.stop()
	current = clip
	anim.play(clip, blend)

## The dance she does when she wins ("" = the classic one).
func set_dance(id: String) -> void:
	_dance = id

## Dance now (the Shop preview and the Landing); stop_overlay() ends it.
func start_dance(id: String) -> void:
	_dance = id
	_ov = ""
	play("win", 0.3, true)

func play_emote(id: String) -> void:
	if not EMOTES.has(id) or _ov.begins_with("d:"):
		return
	_start_ov(id, float(EMOTES[id]))

func stop_overlay() -> void:
	_ov_off = true
	if _state == "win":
		play("idle", 0.4)

func is_emoting() -> bool:
	return _ov != "" and not _ov_off and not _ov.begins_with("d:")

func _start_ov(id: String, length: float) -> void:
	_ov = id
	_ov_t = 0.0
	_ov_len = length
	_ov_off = false
	_ov_w = 0.0
	if id.begins_with("d:"):
		_spin = 0.0

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

## Knocked back by a hit: she's shoved a step back, rocks back and wobbles
## sideways, then steps in again (a KO keeps the shove; the death clip falls).
## strength ~1 for a body hit, ~1.5 for the head.
func knock(strength: float, ko: bool = false) -> void:
	_knock_t = 0.0
	_knock_s = strength
	_knock_side = -1.0 if randf() < 0.5 else 1.0
	_knock_ko = ko

func _apply_knock(delta: float) -> void:
	if _knock_t < 0.0 or model == null:
		return
	_knock_t += delta
	var t := _knock_t
	var s := _knock_s
	# She faces +Z: back is -Z. Shove out fast, ease back in.
	var back := 0.55 * s * (1.0 - exp(-t * 16.0)) * (1.0 if _knock_ko else exp(-t * 2.2))
	var lean := -0.42 * s * exp(-t * 4.5) * cos(t * 9.0)
	var wob := 0.16 * s * _knock_side * exp(-t * 4.0) * sin(t * 13.0)
	var dip := -0.08 * s * exp(-t * 6.0) * sin(minf(t * 12.0, PI))
	var b := Basis(Vector3.RIGHT, lean) * Basis(Vector3.BACK, wob)
	model.transform = Transform3D(b, Vector3(0, dip, -back)) * _model_base
	if t > 2.0 and not _knock_ko:
		_knock_t = -1.0
		model.transform = _model_base

func _process(delta: float) -> void:
	_apply_knock(delta)
	if anim:
		_pose_step(delta)
	if _flash_t > 0.0 and body_mat:
		_flash_t = maxf(0.0, _flash_t - delta)
		body_mat.set_shader_parameter("flash", Color(1, 1, 1, _flash_t * 2.4))

## Restore the clip's own rotations, advance the clip, then turn the bones by stance + overlay.
func _pose_step(delta: float) -> void:
	for bi in _base_rot:
		skel.set_bone_pose_rotation(bi, _base_rot[bi])
	anim.advance(delta)
	for bi in _base_rot:
		_base_rot[bi] = skel.get_bone_pose_rotation(bi)
	# Her stance shows when she stands (idle / ready / dance), half while aiming, not mid-hit or throw.
	var want := 1.0 if _state in ["idle", "ready", "win"] else (0.35 if _state == "aim" else 0.0)
	_stance_w = move_toward(_stance_w, want, delta * 3.0)
	var d := {}
	if _stance_w > 0.001:
		for b in _stance:
			d[b] = (_stance[b] as Vector3) * _stance_w
	if _ov != "":
		_ov_t += delta
		var dance := _ov.begins_with("d:")
		var w := 1.0
		if dance:
			_ov_w = move_toward(_ov_w, 0.0 if _ov_off else 1.0, delta * 2.5)
			w = _ov_w
			if _ov_off and _ov_w <= 0.0:
				_ov = ""
		else:
			if _ov_off:
				_ov_len = minf(_ov_len, _ov_t + 0.3)
			w = smoothstep(0.0, 0.3, _ov_t) * (1.0 - smoothstep(_ov_len - 0.35, _ov_len, _ov_t))
			if _ov_t >= _ov_len:
				_ov = ""
				emote_done.emit()
		if _ov != "":
			var o := _overlay(_ov.substr(2) if dance else _ov, _ov_t, w, delta)
			for b in o:
				d[b] = (d.get(b, Vector3.ZERO) as Vector3) + (o[b] as Vector3) * w
			if _ov == "d:twirl":
				d["root"] = (d.get("root", Vector3.ZERO) as Vector3) + Vector3(0, rad_to_deg(_spin), 0)
	for b in POSE_BONES:
		if not d.has(b) or not _bones.has(b):
			continue
		var bi: int = _bones[b]
		var par := skel.get_bone_parent(bi)
		var pg := skel.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
		var e: Vector3 = d[b]
		var q := Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
		var nl := (pg.inverse() * q * pg).get_rotation_quaternion() * (_base_rot[bi] as Quaternion)
		skel.set_bone_pose_rotation(bi, nl)

## Degrees to add per bone (turned about MODEL axes: x = her left-right line, y up, z forward;
## her left is +x): an arm out to her side is rz = +abd on the left arm, -abd on the right; an arm
## forward is -rx. Gestures lean on the idle pose; w = the fade weight (it drives the spin speed).
func _overlay(id: String, t: float, w: float, delta: float) -> Dictionary:
	var d := {}
	match id:
		"wave":
			d["upperarm_r"] = Vector3(-10, 0, -112)
			d["lowerarm_r"] = Vector3(0, 0, -(38 + 24 * sin(t * 11.0)))
			d["Head"] = Vector3(0, -6, -7)
			d["spine_03"] = Vector3(0, 0, 4)
			d["pelvis"] = Vector3(0, 0, -5)
		"kiss":
			var blow := smoothstep(0.7, 1.0, t) * (1.0 - smoothstep(1.3, 1.7, t))
			d["upperarm_r"] = Vector3(-50 - 10 * blow, 0, -16)
			d["lowerarm_r"] = Vector3(-112 + 70 * blow, 0, 0)
			d["hand_r"] = Vector3(-20 * blow, 0, 0)
			d["Head"] = Vector3(-6 * blow - 4, 0, 9)
			d["spine_02"] = Vector3(-5 * blow, 0, 0)
			d["pelvis"] = Vector3(0, 0, 8)
			d["thigh_l"] = Vector3(0, 0, -4)
		"hips":
			d["upperarm_l"] = Vector3(0, 0, 52)
			d["upperarm_r"] = Vector3(0, 0, -52)
			d["lowerarm_l"] = Vector3(-14, 0, -88)
			d["lowerarm_r"] = Vector3(-14, 0, 88)
			d["pelvis"] = Vector3(0, 7 * sin(t * 2.0), 8 * sin(t * 2.0 + 0.5))
			d["Head"] = Vector3(-3, 10 * sin(t * 1.6), 6 * sin(t * 2.0))
			d["spine_03"] = Vector3(-5, 0, -4 * sin(t * 2.0 + 0.5))
		"flex":
			var pulse := 0.5 + 0.5 * sin(t * 7.0)
			d["upperarm_l"] = Vector3(0, 0, 84)
			d["upperarm_r"] = Vector3(0, 0, -84)
			d["lowerarm_l"] = Vector3(-18, 0, 92 + 14 * pulse)
			d["lowerarm_r"] = Vector3(-18, 0, -92 - 14 * pulse)
			d["spine_03"] = Vector3(-7, 0, 0)
			d["Head"] = Vector3(-5, 0, 0)
			d["thigh_l"] = Vector3(0, 0, 5)
			d["thigh_r"] = Vector3(0, 0, -5)
		"flip":
			var toss := smoothstep(0.8, 1.15, t) * (1.0 - smoothstep(1.3, 1.9, t))
			d["upperarm_r"] = Vector3(-34, 0, -66)
			d["lowerarm_r"] = Vector3(-60, 0, -30)
			d["Head"] = Vector3(-4 * toss, 34 * toss, -20 + 38 * toss)
			d["neck_01"] = Vector3(0, 0, 8 * toss)
			d["spine_03"] = Vector3(0, -8 * toss, 0)
			d["pelvis"] = Vector3(0, 0, 6)
		"salute":
			d["upperarm_r"] = Vector3(-18, 0, -104)
			d["lowerarm_r"] = Vector3(-20, 0, -88)
			d["hand_r"] = Vector3(0, 0, -10)
			d["Head"] = Vector3(-5, 0, 0)
			d["spine_03"] = Vector3(-4, 0, 0)
			d["thigh_l"] = Vector3(0, 0, 3)
			d["thigh_r"] = Vector3(0, 0, -3)
		"samba":
			var k := t * 6.5
			d["pelvis"] = Vector3(0, 10 * sin(k * 0.5), 15 * sin(k))
			d["spine_01"] = Vector3(0, 0, -9 * sin(k))
			d["spine_03"] = Vector3(0, -8 * sin(k * 0.5), -5 * sin(k))
			d["upperarm_l"] = Vector3(-20, 0, 128 + 12 * sin(k))
			d["upperarm_r"] = Vector3(-20, 0, -128 + 12 * sin(k + PI))
			d["lowerarm_l"] = Vector3(0, 0, 22 * sin(k * 2.0))
			d["lowerarm_r"] = Vector3(0, 0, 22 * sin(k * 2.0 + PI))
			d["Head"] = Vector3(0, 0, 6 * sin(k))
		"belly":
			var k := t * 4.2
			d["pelvis"] = Vector3(7 * sin(k * 2.0), 30 * sin(k), 11 * sin(k + 1.57))
			d["spine_01"] = Vector3(0, -16 * sin(k), -6 * sin(k + 1.57))
			d["spine_03"] = Vector3(0, -8 * sin(k), 0)
			d["upperarm_l"] = Vector3(-8, 0, 148 + 12 * sin(k + 0.4))
			d["upperarm_r"] = Vector3(-8, 0, -148 + 12 * sin(k + 0.4 + PI))
			d["lowerarm_l"] = Vector3(0, 0, -22 + 24 * sin(k * 2.0))
			d["lowerarm_r"] = Vector3(0, 0, 22 + 24 * sin(k * 2.0 + PI))
			d["hand_l"] = Vector3(0, 0, 22 * sin(k * 2.0 + 1.0))
			d["hand_r"] = Vector3(0, 0, 22 * sin(k * 2.0 + 1.0 + PI))
			d["thigh_l"] = Vector3(-8 + 9 * sin(k), 0, 0)
			d["thigh_r"] = Vector3(-8 - 9 * sin(k), 0, 0)
			d["calf_l"] = Vector3(10 - 9 * sin(k), 0, 0)
			d["calf_r"] = Vector3(10 + 9 * sin(k), 0, 0)
			d["Head"] = Vector3(0, 0, 8 * sin(k))
		"twirl":
			_spin += delta * w * 6.0
			var bob := 0.5 + 0.5 * sin(t * 11.0)
			d["upperarm_l"] = Vector3(0, 0, 76)
			d["upperarm_r"] = Vector3(0, 0, -118)
			d["lowerarm_r"] = Vector3(0, 0, -16)
			d["thigh_l"] = Vector3(-6 * bob, 0, 4)
			d["thigh_r"] = Vector3(-6 * bob, 0, -4)
			d["calf_l"] = Vector3(10 * bob, 0, 0)
			d["calf_r"] = Vector3(10 * bob, 0, 0)
			d["Head"] = Vector3(-4, 0, 0)
		"strut":
			d["Head"] = Vector3(-4, 0, 0)
			d["spine_03"] = Vector3(-3, 0, 0)
		"pump":
			var k := t * 8.0
			d["upperarm_l"] = Vector3(-22, 0, 150 + 16 * sin(k))
			d["upperarm_r"] = Vector3(-22, 0, -150 + 16 * sin(k + PI))
			d["lowerarm_l"] = Vector3(0, 0, 26 + 22 * sin(k))
			d["lowerarm_r"] = Vector3(0, 0, -26 + 22 * sin(k + PI))
			var down := 0.5 + 0.5 * sin(k * 2.0)
			d["thigh_l"] = Vector3(-16 * down, 0, 5)
			d["thigh_r"] = Vector3(-16 * down, 0, -5)
			d["calf_l"] = Vector3(26 * down, 0, 0)
			d["calf_r"] = Vector3(26 * down, 0, 0)
			d["spine_01"] = Vector3(8 * down, 0, 0)
			d["Head"] = Vector3(-8 + 6 * down, 0, 0)
	return d
