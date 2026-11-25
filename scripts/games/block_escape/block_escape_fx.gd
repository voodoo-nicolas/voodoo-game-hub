extends RefCounted

## Block Escape look helpers [NEW 2026-11-25]: the animated backdrop shader (one draw call,
## Android-light) and the board's particle system (plain draw_rect squares: cheap).

## Layered backdrop over the picture: drifting gradient tint, two parallax layers of soft
## toy bricks floating upward, a slow diagonal light sweep, vignette, and a red edge pulse
## when the clock runs low (`danger`).
const BG_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(0.55, 0.75, 1.0, 0.25);
uniform vec4 bot_col : source_color = vec4(0.2, 0.35, 0.7, 0.35);
uniform vec4 brick_a : source_color = vec4(1.0, 1.0, 1.0, 0.22);
uniform vec4 brick_b : source_color = vec4(0.6, 0.8, 1.0, 0.22);
uniform vec4 vig_col : source_color = vec4(0.05, 0.1, 0.25, 0.45);
uniform float aspect = 0.5;
uniform float danger = 0.0;
uniform float sweep = 0.10;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 layer(vec2 uv, float scale, float speed, float t, float blur) {
	vec2 p = vec2(uv.x * aspect, uv.y) * scale + vec2(0.0, t * speed);
	vec2 id = floor(p);
	float h = hash(id);
	if (h < 0.55) return vec4(0.0);
	vec2 f = fract(p) - 0.5;
	f += (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.35;
	float a = (hash(id + 1.3) - 0.5) * 0.8 + sin(t * 0.4 + h * 6.28) * 0.15;
	f = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * f;
	float s = 0.10 + 0.12 * hash(id + 9.2);
	float d = rbox(f, vec2(s * 1.4, s), s * 0.35);
	float m = 1.0 - smoothstep(-blur, blur, d);
	vec4 c = mix(brick_a, brick_b, step(0.5, hash(id + 5.5)));
	return vec4(c.rgb, c.a * m);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec2 w = vec2(sin(t * 0.11), cos(t * 0.09)) * 0.08;
	vec4 col = mix(top_col, bot_col, clamp(uv.y + w.x * (uv.x - 0.5), 0.0, 1.0));
	vec4 far = layer(uv, 7.0, -0.25, t, 0.06);
	vec4 near = layer(uv + vec2(0.37, 0.0), 3.2, -0.55, t, 0.025);
	col.rgb = mix(col.rgb, far.rgb, far.a / max(col.a + far.a, 0.001));
	col.a = col.a + far.a * (1.0 - col.a);
	col.rgb = mix(col.rgb, near.rgb, near.a / max(col.a + near.a, 0.001));
	col.a = col.a + near.a * (1.0 - col.a);
	float band = fract((uv.x * aspect + uv.y) * 0.45 - t * 0.035);
	float sw = smoothstep(0.12, 0.0, abs(band - 0.5)) * sweep;
	col.rgb = mix(col.rgb, vec3(1.0), sw / max(col.a + sw, 0.001));
	col.a = col.a + sw * (1.0 - col.a);
	float v = smoothstep(0.45, 1.05, length((uv - 0.5) * vec2(1.0, 1.15)) * 1.35);
	col.rgb = mix(col.rgb, vig_col.rgb, v * vig_col.a / max(col.a + v * vig_col.a, 0.001));
	col.a = col.a + v * vig_col.a * (1.0 - col.a);
	float edge = smoothstep(0.25, 0.0, min(min(uv.x, 1.0 - uv.x) * aspect, min(uv.y, 1.0 - uv.y)));
	float dz = danger * edge * (0.55 + 0.45 * sin(t * 7.0));
	col.rgb = mix(col.rgb, vec3(0.9, 0.08, 0.08), dz / max(col.a + dz, 0.001));
	col.a = col.a + dz * (1.0 - col.a);
	COLOR = col;
}
"""

static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = BG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	r.material = mat
	return r

## Classic = sunny sky tint over the brick picture; Voodoo = deep night with neon bricks.
static func skin_backdrop(r: ColorRect, classic: bool) -> void:
	var m: ShaderMaterial = r.material
	if classic:
		m.set_shader_parameter("top_col", Color(0.75, 0.88, 1.0, 0.08))
		m.set_shader_parameter("bot_col", Color(0.22, 0.42, 0.82, 0.42))
		m.set_shader_parameter("brick_a", Color(1, 1, 1, 0.42))
		m.set_shader_parameter("brick_b", Color(1.0, 0.8, 0.3, 0.32))
		m.set_shader_parameter("vig_col", Color(0.06, 0.12, 0.3, 0.42))
		m.set_shader_parameter("sweep", 0.12)
	else:
		m.set_shader_parameter("top_col", Color(0.05, 0.04, 0.14, 0.6))
		m.set_shader_parameter("bot_col", Color(0.02, 0.08, 0.16, 0.75))
		m.set_shader_parameter("brick_a", Color(0.2, 0.9, 1.0, 0.16))
		m.set_shader_parameter("brick_b", Color(1.0, 0.3, 0.7, 0.14))
		m.set_shader_parameter("vig_col", Color(0, 0, 0, 0.7))
		m.set_shader_parameter("sweep", 0.05)

static func ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var u := x - 1.0
	return 1.0 + (c1 + 1.0) * u * u * u + c1 * u * u

## One particle: {p, v, life, max, col, size, grav, spin}. Squares shrink and fade.
static func burst(list: Array, at: Vector2, dir: Vector2, col: Color, n: int, speed: float, size: float, spread: float = 1.2, grav: float = 0.0) -> void:
	for i in n:
		var a := dir.angle() + randf_range(-spread, spread) if dir != Vector2.ZERO else randf() * TAU
		var sp := speed * randf_range(0.35, 1.0)
		var life := randf_range(0.35, 0.75)
		list.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp, "life": life, "max": life,
			"col": col.lightened(randf_range(0.0, 0.35)), "size": size * randf_range(0.5, 1.0), "grav": grav})

static func step(list: Array, delta: float) -> Array:
	var keep: Array = []
	for q in list:
		q.life -= delta
		if q.life <= 0.0:
			continue
		q.v *= pow(0.12, delta)
		q.v.y += q.grav * delta
		q.p += q.v * delta
		keep.append(q)
	return keep

static func draw(c: CanvasItem, list: Array) -> void:
	for q in list:
		var k: float = q.life / q.max
		var sz: float = q.size * (0.4 + 0.6 * k)
		c.draw_rect(Rect2(q.p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(q.col, minf(1.0, k * 1.6)))
