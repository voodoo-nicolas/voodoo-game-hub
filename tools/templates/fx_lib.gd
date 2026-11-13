extends RefCounted

## Shared effects helper: slow smoke, glitter, press squash, pop-in.
##
## GENERATED COPY: `python tools/hub.py sync` copies tools/templates/fx_lib.gd to
## scripts/games/<id>/fx_lib.gd for every game whose scripts mention it (the Landing
## styles do: tools/templates/landing_styles.gd), so each pack carries its own copy
## and runs on any app version. Edit the template, never a copy.
##
## "Reduce effects" (owner, 2026-11-13): one app-wide switch, user://fx.json, shown in the
## Options of every game with a styled Landing. Until the player picks, it follows the
## device: on for the web build and for phones with 4 or fewer cores. Reduced = no smoke,
## no glitter, no idle floating; presses and pop-ins stay (they are the feedback).
## Particle budget: BUDGET (40) CPUParticles2D particles on screen at once, in all.

const PREFS_PATH := "user://fx.json"
const BUDGET := 40
const SMOKE_AMOUNT := 12
const GLITTER_AMOUNT := 24

static var _reduce: int = -1  # -1 not read yet, 0 full, 1 reduced
static var _blobs: Dictionary = {}
static var _star: Texture2D = null

## True when effects should be left out (the player's choice, else the device's).
static func reduced() -> bool:
	# The app's own "reduce motion" switch (Settings, newer apps) always wins.
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var s: Node = (loop as SceneTree).root.get_node_or_null("Settings")
		if s != null and "reduce_motion" in s and bool(s.get("reduce_motion")):
			return true
	if _reduce < 0:
		_reduce = 1 if _auto_reduce() else 0
		var parsed: Variant = null
		if FileAccess.file_exists(PREFS_PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PREFS_PATH))
		if parsed is Dictionary and parsed.has("reduce"):
			_reduce = 1 if bool(parsed["reduce"]) else 0
	return _reduce == 1

static func _auto_reduce() -> bool:
	return OS.has_feature("web") or OS.get_processor_count() <= 4

static func set_reduced(on: bool) -> void:
	_reduce = 1 if on else 0
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"reduce": on}))

## Soft round blob (white, fading to nothing at the rim): the smoke puff and glows.
static func blob(size: int = 64) -> Texture2D:
	if _blobs.has(size):
		return _blobs[size]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.45, Color(1, 1, 1, 0.35))
	var t := GradientTexture2D.new()
	t.gradient = grad
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	_blobs[size] = t
	return t

## A four-pointed sparkle (17 px).
static func star() -> Texture2D:
	if _star != null:
		return _star
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	for y in 17:
		for x in 17:
			var dx := absf(x - 8.0)
			var dy := absf(y - 8.0)
			var along := maxf(dx, dy)
			var across := minf(dx, dy)
			var a := maxf(0.0, 1.0 - along / 8.5) * maxf(0.0, 1.0 - across / 2.2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_star = ImageTexture.create_from_image(img)
	return _star

## Slow smoke drifting up out of a rectangle (half-sizes `extents`). Add it behind the
## thing it comes from. Returns null when effects are reduced.
static func smoke(parent: Node, color: Color, extents: Vector2) -> CPUParticles2D:
	if reduced():
		return null
	var p := CPUParticles2D.new()
	p.amount = SMOKE_AMOUNT
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.texture = blob(64)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.gravity = Vector2(7, -5)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 2.2
	p.scale_amount_max = 3.8
	p.angle_max = 360.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.3, Color(color, 0.22))
	ramp.add_point(0.7, Color(color, 0.14))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	return p

## Glitter specks that twinkle and fade over a rectangle. Null when effects are reduced.
static func glitter(parent: Node, color: Color, extents: Vector2) -> CPUParticles2D:
	if reduced():
		return null
	var p := CPUParticles2D.new()
	p.amount = GLITTER_AMOUNT
	p.lifetime = 2.8
	p.lifetime_randomness = 0.6
	p.preprocess = 3.0
	p.texture = star()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 9.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.hue_variation_max = 0.05
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.25, Color(color, 0.95))
	ramp.add_point(0.55, Color(color, 0.5))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	return p

## Makes a Button (or any BaseButton) squash when pressed and spring back when let go.
## Its pivot must be its centre (the caller sets `pivot_offset` when it sizes it).
static func bind_press(b: BaseButton) -> void:
	b.button_down.connect(_squash.bind(b, true))
	b.button_up.connect(_squash.bind(b, false))

static func _squash(b: BaseButton, down: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	_kill(b)
	var tw := b.create_tween()
	b.set_meta("fx_tween", tw)
	if down:
		tw.tween_property(b, "scale", Vector2(1.1, 0.86), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(b, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Pops a node in: 0 -> 1 with an overshoot after `delay` seconds (fade only when reduced).
static func pop_in(n: CanvasItem, delay: float) -> void:
	_kill(n)
	n.modulate.a = 0.0
	var tw := n.create_tween()
	n.set_meta("fx_tween", tw)
	tw.tween_interval(delay)
	if reduced():
		tw.tween_property(n, "modulate:a", 1.0, 0.15)
		return
	n.set("scale", Vector2.ZERO)
	tw.tween_property(n, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Slides a Control in from the side (and fades it in) after `delay` seconds; it ends where it is now.
static func slide_in(n: Control, delay: float, dx: float = -36.0) -> void:
	_kill(n)
	var rest := n.position.x
	n.modulate.a = 0.0
	var tw := n.create_tween()
	n.set_meta("fx_tween", tw)
	tw.tween_interval(delay)
	if reduced():
		tw.tween_property(n, "modulate:a", 1.0, 0.15)
		return
	n.position.x = rest + dx
	tw.tween_property(n, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(n, "position:x", rest, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## A seamless soft noise picture (256 px), made once: the fog is drawn from it.
static var _noise: Texture2D = null

static func noise() -> Texture2D:
	if _noise != null:
		return _noise
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.frequency = 0.014
	n.seed = 7
	_noise = ImageTexture.create_from_image(n.get_seamless_image(384, 384))
	return _noise

const MIST_SHADER := """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.6, 0.5, 0.9, 1.0);
uniform float amount = 0.45;
uniform float speed = 0.012;
uniform vec2 tiles = vec2(1.5, 2.6);
void fragment() {
	vec2 uv = UV * tiles;
	float a = texture(TEXTURE, uv + vec2(TIME * speed, TIME * speed * 0.35)).r;
	float b = texture(TEXTURE, uv * 1.9 + vec2(-TIME * speed * 0.7, TIME * speed * 0.5)).r;
	float m = smoothstep(0.30, 1.0, a * 0.6 + b * 0.4);
	COLOR = vec4(tint.rgb, m * amount * tint.a);
}
"""
static var _mist_shader: Shader = null

## Slow drifting fog over a whole screen: add it full-rect (anchors) where the haze should be. Two layers of
## noise slide past each other in a shader (no particles, no threads). Null when effects are reduced.
static func mist(parent: Node, tint: Color, amount: float = 0.45) -> TextureRect:
	if reduced():
		return null
	if _mist_shader == null:
		_mist_shader = Shader.new()
		_mist_shader.code = MIST_SHADER
	var t := TextureRect.new()
	t.texture = noise()
	t.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _mist_shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("amount", amount)
	t.material = mat
	parent.add_child(t)
	return t

## A warm glow (additive) that flickers like a candle flame. Returns the glow; call flicker_start()
## when it shows and flicker_stop() when it hides. `phase` keeps several flames out of step.
static func light(parent: Node, color: Color, diameter: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = blob(128)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	t.material = mat
	t.modulate = Color(color, 0.3)
	t.size = Vector2(diameter, diameter)
	t.pivot_offset = t.size * 0.5
	parent.add_child(t)
	return t

static func flicker_start(t: TextureRect, phase: float) -> void:
	_kill(t)
	if reduced():
		t.modulate.a = 0.28
		return
	var tw := t.create_tween()
	t.set_meta("fx_tween", tw)
	tw.set_loops()
	tw.tween_method(_flicker.bind(t, phase), 0.0, 900.0, 900.0)

static func flicker_stop(t: TextureRect) -> void:
	_kill(t)

static func _flicker(time: float, t: TextureRect, phase: float) -> void:
	if not is_instance_valid(t):
		return
	var a := 0.30 + 0.09 * sin(time * 8.7 + phase) + 0.06 * sin(time * 15.9 + phase * 2.3) + 0.04 * sin(time * 3.1 + phase * 0.7)
	t.modulate.a = clampf(a, 0.08, 0.6)
	var s := 1.0 + 0.04 * sin(time * 6.1 + phase)
	t.scale = Vector2(s, s)

static func _kill(n: Node) -> void:
	if n.has_meta("fx_tween"):
		var old: Variant = n.get_meta("fx_tween")
		if old is Tween and old.is_valid():
			old.kill()
