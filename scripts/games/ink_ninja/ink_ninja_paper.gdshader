shader_type canvas_item;

// Ink Ninja: rice-paper grain, fibres and a soft vignette over the play field.
// Drawn as a ColorRect on top of the field (mouse ignored). Greys only.
// grain_col: the speckle colour (dark on paper, pale on night); edge_col: the vignette.

uniform vec4 grain_col : source_color = vec4(0.25, 0.22, 0.18, 1.0);
uniform vec4 edge_col : source_color = vec4(0.1, 0.09, 0.08, 1.0);
uniform float grain = 0.10;
uniform float edge = 0.45;
uniform vec2 px_size = vec2(1280.0, 720.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * px_size;
	// fine speckle + long horizontal fibres + big soft blotches (uneven wash)
	float speck = step(0.93, hash(floor(p / 2.0)));
	float fibre = smoothstep(0.78, 0.95, noise(vec2(p.x / 60.0, p.y / 3.0)));
	float wash = noise(p / 260.0);
	float g = grain * (speck * 0.8 + fibre * 0.6 + wash * 0.7);
	vec2 c = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(c * vec2(1.0, 1.25))) * edge;
	vec3 col = mix(grain_col.rgb, edge_col.rgb, v / max(v + g, 0.001));
	COLOR = vec4(col, clamp(g + v, 0.0, 0.85));
}
