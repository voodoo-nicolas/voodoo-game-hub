extends RefCounted

## Poker's presentation effects (2026-11-17 visual pass), shared by the game
## picker, the per-game menus, Career, Stats and the table:
## - room(): the layered background = the look's table picture (slow drift),
##   a warm light that wanders over it, a vignette and a few floating dust
##   motes. Follows the look (Classic gold / Skull neon) each time it shows.
## - pop_in(): a node fades and grows in (staggered lists).
## - press(): a button squashes a little while held.
## Everything obeys the app-wide "Reduce effects" switch (user://fx.json, the
## same rule as the shared effects template): reduced = no drift, no light, no
## dust, no pop-ins; presses stay (they are feedback). Budget: 18 particles.

const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")

const PREFS_PATH := "user://fx.json"
const DUST := 18

static var _reduce: int = -1

const VIGNETTE := """shader_type canvas_item;
uniform float strength = 0.82;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.46);
	p.x *= 0.8;
	float d = length(p);
	float v = smoothstep(0.22, 0.78, d);
	// darker toward the bottom, where the buttons sit
	v = max(v, smoothstep(0.55, 1.0, UV.y) * 0.55);
	COLOR = vec4(0.0, 0.0, 0.0, v * strength);
}
"""

const EDGE_GLOW := """shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float power = 0.0;
void fragment() {
	vec2 p = abs(UV - vec2(0.5)) * 2.0;
	float e = max(p.x, p.y);
	float g = smoothstep(0.6, 1.0, e);
	COLOR = vec4(tint.rgb * g * power * 0.55, 1.0);
}
"""

const LIGHT := """shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.45, 1.0);
uniform float speed = 1.0;
uniform float power = 0.16;
void fragment() {
	float t = TIME * 0.11 * speed;
	vec2 c = vec2(0.5 + 0.28 * sin(t), 0.32 + 0.1 * sin(t * 1.7 + 1.3));
	vec2 p = UV - c;
	p.x *= 1.4;
	float spot = exp(-dot(p, p) * 7.0);
	// a slow second glow on the felt
	vec2 q = UV - vec2(0.5 - 0.2 * sin(t * 0.7), 0.62);
	spot += 0.5 * exp(-dot(q, q) * 10.0) * (0.6 + 0.4 * sin(t * 2.3));
	COLOR = vec4(tint.rgb * spot * power, 1.0);
}
"""

## True when effects should be left out (the player's choice, else the device's).
static func reduced() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var s: Node = (loop as SceneTree).root.get_node_or_null("Settings")
		if s != null and "reduce_motion" in s and bool(s.get("reduce_motion")):
			return true
	if _reduce < 0:
		_reduce = 1 if (OS.has_feature("web") or OS.get_processor_count() <= 4) else 0
		if FileAccess.file_exists(PREFS_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_PATH))
			if parsed is Dictionary and parsed.has("reduce"):
				_reduce = 1 if bool(parsed["reduce"]) else 0
	return _reduce == 1

## Forget the cached choice (Options changed it).
static func refresh_pref() -> void:
	_reduce = -1

## The layered room background, full rect, ignoring the mouse. `dim` darkens
## the picture (menus 0.55, the table 0.35 so the felt reads).
static func room(dim: float = 0.55) -> Control:
	var r := Room.new()
	r.dim = dim
	return r

## Fade + grow `n` in after `delay` seconds (nothing when reduced).
static func pop_in(n: Control, delay: float = 0.0) -> void:
	if n == null or reduced():
		return
	n.modulate.a = 0.0
	var go := func() -> void:
		if not is_instance_valid(n):
			return
		n.pivot_offset = n.size / 2.0
		n.scale = Vector2(0.94, 0.94)
		var tw := n.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "modulate:a", 1.0, 0.28).set_delay(delay).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "scale", Vector2.ONE, 0.36).set_delay(delay)
	if n.is_inside_tree():
		go.call_deferred()
	else:
		n.ready.connect(func() -> void: go.call_deferred(), CONNECT_ONE_SHOT)

## A button that squashes while held and springs back.
static func press(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(0.95, 0.95), 0.06))
	b.button_up.connect(func() -> void:
		b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(b, "scale", Vector2.ONE, 0.22))

## The edges of `host` glow gold for a moment (the player won a pot); `power`
## 0..1 scales it. With effects reduced: a shorter, fainter glow (still feedback).
static func win_glow(host: Control, power: float = 0.6) -> void:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = EDGE_GLOW
	m.shader = sh
	m.set_shader_parameter("tint", Look.c("winner"))
	m.set_shader_parameter("power", 0.0)
	r.material = m
	host.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := power * (0.4 if reduced() else 1.0)
	var tw := r.create_tween()
	tw.tween_method(func(x: float) -> void: m.set_shader_parameter("power", x), 0.0, top, 0.18)
	tw.tween_method(func(x: float) -> void: m.set_shader_parameter("power", x), top, 0.0, 0.9 if not reduced() else 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(r.queue_free)

## A label (or any control) pops once: grows a little and settles.
static func bump(n: Control) -> void:
	if n == null:
		return
	n.pivot_offset = n.size / 2.0
	var tw := n.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector2(1.08, 1.08), 0.1)
	tw.tween_property(n, "scale", Vector2.ONE, 0.3)

## A soft round dot (white, fading out) for the dust.
static func dot() -> Texture2D:
	return Room.dot_tex()

## The background node: rebuilt from the current look whenever it shows.
class Room extends Control:
	var dim := 0.55
	var base: ColorRect
	var pic: TextureRect
	var light: ColorRect
	var dust: CPUParticles2D
	var drift: Tween
	static var _dot: Texture2D = null

	static func dot_tex() -> Texture2D:
		if _dot == null:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(0.5, 0.0)
			t.width = 16
			t.height = 16
			_dot = t
		return _dot

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		clip_contents = true

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		base = ColorRect.new()
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(base)
		base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic = TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		light = ColorRect.new()
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lm := ShaderMaterial.new()
		var ls := Shader.new()
		ls.code = LIGHT
		lm.shader = ls
		light.material = lm
		add_child(light)
		light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var vig := ColorRect.new()
		vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vm := ShaderMaterial.new()
		var vs := Shader.new()
		vs.code = VIGNETTE
		vm.shader = vs
		vig.material = vm
		add_child(vig)
		vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dust = CPUParticles2D.new()
		dust.amount = DUST
		dust.lifetime = 10.0
		dust.preprocess = 10.0
		dust.texture = dot_tex()
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.direction = Vector2(0.3, -1)
		dust.spread = 40.0
		dust.gravity = Vector2(0, -4)
		dust.initial_velocity_min = 4.0
		dust.initial_velocity_max = 12.0
		dust.scale_amount_min = 0.25
		dust.scale_amount_max = 0.8
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.add_point(0.3, Color(1, 1, 1, 1))
		fade.add_point(0.75, Color(1, 1, 1, 1))
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
		dust.color_ramp = fade
		add_child(dust)
		resized.connect(_fit)
		visibility_changed.connect(_apply)
		_fit()
		_apply()

	func _fit() -> void:
		if dust:
			dust.position = size / 2.0
			dust.emission_rect_extents = size / 2.0
		if pic:
			pic.pivot_offset = size / 2.0

	## Colours and picture from the current look; motion on or off.
	func _apply() -> void:
		if base == null or not is_visible_in_tree():
			return
		var classic := Look.is_classic()
		base.color = Look.c("room")
		var tex := Look.tex("landing")
		pic.texture = tex
		pic.visible = tex != null
		pic.modulate = Color(1, 1, 1, 1).darkened(dim)
		var warm := Color(1.0, 0.78, 0.42) if classic else Color(0.62, 0.36, 1.0)
		var calm: bool = _calm()
		(light.material as ShaderMaterial).set_shader_parameter("tint", warm)
		(light.material as ShaderMaterial).set_shader_parameter("speed", 0.0 if calm else 1.0)
		light.visible = not calm
		dust.color = Color(Look.c("gold") if classic else Look.c("glow_a"), 0.35)
		dust.emitting = not calm
		dust.visible = not calm
		if drift:
			drift.kill()
		pic.scale = Vector2.ONE
		if not calm and tex != null:
			drift = create_tween().set_loops()
			drift.tween_property(pic, "scale", Vector2(1.07, 1.07), 18.0).set_trans(Tween.TRANS_SINE)
			drift.tween_property(pic, "scale", Vector2.ONE, 18.0).set_trans(Tween.TRANS_SINE)

	func _calm() -> bool:
		return load("res://scripts/games/video_poker/video_poker_fx.gd").reduced()
