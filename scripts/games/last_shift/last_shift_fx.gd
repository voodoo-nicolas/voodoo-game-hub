extends RefCounted

## Visual effects helpers: particle bursts, a soft light texture, and the vignette shader.

## Soft round light texture (white in the middle, fading to nothing) for PointLight2D.
static var _light_tex: GradientTexture2D = null

static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 256
		_light_tex.height = 256
	return _light_tex

## A one-shot burst of little squares (sparks, dust). Frees itself when done.
static func burst(parent: Node, pos: Vector2, color: Color, count: int = 8, speed: float = 90.0,
		life: float = 0.4, size: float = 2.5) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 2000
	p.one_shot = true
	p.emitting = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2.ZERO
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = color
	p.finished.connect(p.queue_free)
	parent.add_child(p)

## Vignette (dark edges) + a red "hurt" flash, as one full-screen canvas shader.
static func vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.5;
uniform float hurt = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.85));
	float edge = smoothstep(0.30, 0.80, d);
	vec3 col = mix(vec3(0.0), vec3(0.65, 0.04, 0.04), clamp(hurt, 0.0, 1.0));
	float a = edge * (strength + hurt * 0.45) + hurt * 0.10;
	COLOR = vec4(col, clamp(a, 0.0, 0.95));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
