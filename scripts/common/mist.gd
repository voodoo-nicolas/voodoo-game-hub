extends ColorRect

## Slowly drifting violet / electric-blue / magenta mist over near-black --
## the backdrop of the hub and Options in the dark theme, matching the
## smoke in the VOODOO banner art. Pure shader (no textures), full rect,
## ignores the mouse. Add it as the first child so everything sits on top.

const SHADER := """
shader_type canvas_item;

uniform vec3 base_color = vec3(0.025, 0.008, 0.05);
uniform vec3 violet = vec3(0.55, 0.16, 0.95);
uniform vec3 blue = vec3(0.12, 0.38, 1.0);
uniform vec3 magenta = vec3(0.95, 0.22, 0.62);
uniform float strength = 0.95;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(1.0, 2.0);  // portrait: keep the wisps round-ish
	float t = TIME * 0.035;
	// domain warping makes it curl like smoke instead of drifting clouds
	vec2 q = vec2(fbm(uv * 1.6 + vec2(0.0, t)), fbm(uv * 1.6 + vec2(5.2, -t)));
	float smoke = fbm(uv * 2.2 + 2.5 * q + vec2(t * 0.6, t * 1.3));
	float wisps = smoothstep(0.32, 0.9, smoke);
	vec3 tint = mix(violet, blue, smoothstep(0.2, 0.8, q.x));
	tint = mix(tint, magenta, smoothstep(0.55, 0.9, q.y) * 0.6);
	// a little brighter toward the top, where the banner's smoke is
	float glow = mix(0.75, 1.15, 1.0 - UV.y);
	vec3 col = base_color + tint * wisps * strength * glow;
	// vignette keeps the edges dark and the middle readable
	float vig = smoothstep(1.15, 0.35, length((UV - 0.5) * vec2(1.3, 1.0)));
	COLOR = vec4(col * mix(0.55, 1.0, vig), 1.0);
}
"""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	material = mat
