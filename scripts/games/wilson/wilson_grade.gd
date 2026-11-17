extends Control

## Beached: the light on top of the painted beach (owner brief 2026-11-17, visual pass). Three cheap layers over
## the world, under the HUD: a warm band along the horizon at sunrise / sunset, a soft vignette that deepens at
## night, and slow motes (pale dust by day, fireflies at night). Driven by `update_light()` from the sky keyframes.

const WARM_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 col : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform float amount = 0.0;
uniform float horizon = 0.42;
void fragment() {
	float y = (UV.y - horizon) / 0.30;
	float band = exp(-y * y);
	float side = 0.6 + 0.4 * (1.0 - abs(UV.x - 0.5) * 1.2);
	COLOR = vec4(col.rgb * band * side * amount, 1.0);
}
"""
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float amount = 0.2;
uniform vec4 col : source_color = vec4(0.02, 0.03, 0.08, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 1.15);
	float d = length(p);
	COLOR = vec4(col.rgb, smoothstep(0.38, 0.85, d) * amount);
}
"""

var _warm: ColorRect
var _vig: ColorRect
var _motes: CPUParticles2D
var _warm_mat: ShaderMaterial
var _vig_mat: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warm_mat = _rect_mat(WARM_SHADER)
	_vig_mat = _rect_mat(VIGNETTE_SHADER)
	_warm = _fill(_warm_mat)
	_vig = _fill(_vig_mat)
	_motes = CPUParticles2D.new()
	_motes.amount = 18
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.direction = Vector2(1, -0.3)
	_motes.spread = 60.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 4.0
	_motes.initial_velocity_max = 14.0
	_motes.scale_amount_min = 1.5
	_motes.scale_amount_max = 3.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	_motes.color_ramp = fade
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_motes.material = cm
	add_child(_motes)
	resized.connect(_fit)
	_fit()

func _rect_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _fill(m: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = m
	add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r

func _fit() -> void:
	if _motes:
		_motes.position = size / 2.0
		_motes.emission_rect_extents = size / 2.0

## `warm` 0..1 (sun near the horizon), `night` 0..1, `horizon_col` the keyframe's horizon colour,
## `horizon_y` where the sea meets the sky as 0..1 of the screen height, `calm` 0..1 (less drift in a storm).
func update_light(warm: float, night: float, horizon_col: Color, horizon_y: float, wind: float) -> void:
	if _warm_mat == null:
		return
	_warm_mat.set_shader_parameter("amount", warm * 0.6)
	_warm_mat.set_shader_parameter("col", Color(1.0, 0.62, 0.34).lerp(horizon_col, 0.35))
	_warm_mat.set_shader_parameter("horizon", horizon_y)
	_vig_mat.set_shader_parameter("amount", 0.16 + 0.34 * night)
	# fireflies at night (green-gold), dust by day (pale warm)
	_motes.color = Color(0.75, 1.0, 0.45, 0.85).lerp(Color(1.0, 0.96, 0.82, 0.35), 1.0 - night)
	_motes.initial_velocity_max = 10.0 + 22.0 * wind
