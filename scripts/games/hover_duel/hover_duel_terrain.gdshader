shader_type canvas_item;

// Hover Duel terrain: the map picture (one pixel per height cell) drawn with
// - moving ripples and glints on water, a slow pulsing glow on lava,
// - a fine grain inside each cell (4x4 sub-pixels) so grass, sand and rock
//   read as texture instead of flat squares, cracks on rock,
// - big soft cloud shadows drifting over everything,
// - a soft vignette.
// mask: R = liquid, G = lava, B = rock (same size as the map picture).

uniform sampler2D mask : filter_nearest;
uniform float t = 0.0;
uniform vec2 grid = vec2(240.0, 180.0);
uniform float neon = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 m = texture(mask, UV);
	vec2 sub = floor(UV * grid * 4.0);   // 4 sub-pixels per cell, kept chunky
	vec3 col = base.rgb;
	if (m.r > 0.5) {
		float w = sin(sub.x * 0.33 + t * 1.7) + sin(sub.y * 0.41 - t * 1.3) + sin((sub.x + sub.y) * 0.19 + t * 0.8);
		float glint = step(2.35, w);
		if (m.g > 0.5) {
			float pulse = 0.5 + 0.5 * sin(t * 1.8 + vnoise(sub * 0.05) * 6.0);
			col += vec3(0.22, 0.07, 0.0) * pulse + vec3(0.35, 0.25, 0.05) * glint;
		} else {
			col += vec3(0.16, 0.2, 0.24) * glint + vec3(0.02, 0.03, 0.04) * w;
		}
	} else {
		float g = hash(sub);
		col *= 0.92 + 0.12 * g;
		if (m.b > 0.5) {
			// cracks: thin dark lines from a coarse noise
			float c = abs(vnoise(sub * 0.18) - 0.5);
			col *= c < 0.04 ? 0.72 : 1.0;
		}
	}
	// Cloud shadows (not in Voodoo: it is night there).
	vec2 wp = UV * grid / 60.0;
	float cloud = smoothstep(0.55, 0.78, vnoise(wp * 1.3 + vec2(t * 0.03, t * 0.012)));
	col *= 1.0 - 0.18 * cloud * (1.0 - neon);
	// Vignette.
	vec2 q = SCREEN_UV - 0.5;
	col *= 1.0 - 0.45 * dot(q, q);
	COLOR = vec4(col, 1.0);
}
