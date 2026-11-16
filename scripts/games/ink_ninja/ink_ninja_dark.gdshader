shader_type canvas_item;

// Ink Ninja light and dark (owner 2026-11-16): a dim wash over the whole field with a bright,
// warm hole round every light (lit lanterns, the hero's torch at night). Drawn as a ColorRect
// between the field and the HUD. `dim` 0 = off, ~0.2 = a dusky day, ~0.9 = a night road.

uniform vec4 shade : source_color = vec4(0.06, 0.05, 0.13, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform float dim = 0.0;
uniform float aspect = 1.7778;
uniform int count = 0;
uniform vec4 lights[12];   // xy = screen uv, z = radius (screen heights), w = warmth 0..1

void fragment() {
	float lit = 0.0;
	float glow = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= count) {
			break;
		}
		float d = length((UV - lights[i].xy) * vec2(aspect, 1.0)) / max(lights[i].z, 0.001);
		lit = max(lit, 1.0 - smoothstep(0.1, 1.0, d));
		glow = max(glow, (1.0 - smoothstep(0.0, 1.0, d)) * lights[i].w);
	}
	float a_dark = dim * (1.0 - lit);
	float a_warm = glow * 0.24;
	float a = a_dark + a_warm * (1.0 - a_dark);
	vec3 col = (shade.rgb * a_dark + warm.rgb * a_warm * (1.0 - a_dark)) / max(a, 0.001);
	COLOR = vec4(col, a);
}
