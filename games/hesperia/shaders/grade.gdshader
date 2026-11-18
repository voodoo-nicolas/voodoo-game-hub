shader_type canvas_item;
// Screen-space colour grade for the game world (Hesperia visual pass, 2026-11).
// Saturation/contrast/tint per area kind, drifting cloud shadows (outdoor), torch light around the
// hero (dungeons/interiors), vignette and a red hurt pulse. One full-screen pass at 384x216: cheap on Android.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 tint = vec3(1.0);
uniform float saturation = 1.08;
uniform float contrast = 1.05;
uniform float vignette = 0.3;
uniform float clouds = 0.0;
uniform vec2 cam = vec2(0.0);
uniform vec2 light_pos = vec2(0.5);
uniform float light_radius = 0.0;
uniform float darkness = 0.0;
uniform vec3 light_col = vec3(1.0, 0.75, 0.45);
uniform float hurt = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	if (clouds > 0.0) {
		vec2 p = (px + cam) / 110.0 + vec2(TIME * 0.035, TIME * 0.014);
		float n = vnoise(p) * 0.65 + vnoise(p * 2.1) * 0.35;
		c *= 1.0 - clouds * smoothstep(0.5, 0.78, n);
	}
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	if (light_radius > 0.0) {
		float r = length((SCREEN_UV - light_pos) * vec2(aspect, 1.0));
		float lit = 1.0 - smoothstep(light_radius * 0.35, light_radius, r);
		c *= mix(1.0 - darkness, 1.0, lit);
		c += light_col * 0.06 * lit * darkness;
	}
	vec2 v = (SCREEN_UV - 0.5) * vec2(1.0, 1.2);
	float vig = smoothstep(0.82, 0.3, length(v));
	c *= mix(1.0 - vignette, 1.0, vig);
	c = mix(c, vec3(0.75, 0.04, 0.05), hurt * (0.15 + 0.6 * (1.0 - vig)));
	COLOR = vec4(c, 1.0);
}
