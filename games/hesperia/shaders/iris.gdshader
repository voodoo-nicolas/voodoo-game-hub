shader_type canvas_item;
// Scene transition: the fade ColorRect's alpha (0..1) drives a chunky pixel iris closing on `center`.
// main.gd keeps tweening fade.color:a exactly as before; this only changes how that alpha is drawn.
uniform vec2 center = vec2(0.5);
uniform vec3 ink = vec3(0.03, 0.02, 0.05);

void fragment() {
	float p = COLOR.a;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 cells = vec2(96.0 * aspect / 1.7778, 54.0);
	vec2 uv = (floor(SCREEN_UV * cells) + 0.5) / cells;
	vec2 d = (uv - center) * vec2(aspect, 1.0);
	float r = (1.0 - p) * 2.2;
	float a = (abs(d.x) + abs(d.y)) * 0.85 + length(d) * 0.3 > r ? 1.0 : 0.0;
	if (p >= 0.995) a = 1.0;
	if (p <= 0.005) a = 0.0;
	COLOR = vec4(ink, a);
}
