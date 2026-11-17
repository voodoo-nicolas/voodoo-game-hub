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
	# v0.6 polish: particles fade and shrink out instead of popping off
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.6, Color(1, 1, 1, 0.85))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.35))
	p.scale_amount_curve = c
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	# v0.6 polish: bigger bursts (hits, kills, blasts) get a short soft impact flash
	if count >= 10:
		flash(parent, pos, color.lightened(0.5), 0.35 + size * 0.08)

## v0.6 polish: a soft additive glow that pops out and fades (impact flash). Frees itself.
static func flash(parent: Node, pos: Vector2, color: Color, scale_to: float = 0.5, life: float = 0.16) -> void:
	var sp := Sprite2D.new()
	sp.texture = light_texture()
	sp.position = pos
	sp.z_index = 2001
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sp.material = m
	sp.modulate = Color(color.r, color.g, color.b, 0.7)
	sp.scale = Vector2.ONE * scale_to * 0.3
	parent.add_child(sp)
	var tw := sp.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "scale", Vector2.ONE * scale_to, life)
	tw.tween_property(sp, "modulate:a", 0.0, life)
	tw.chain().tween_callback(sp.queue_free)

## Vignette (dark edges) + a red "hurt" flash, as one full-screen canvas shader.
## v0.6 polish: also the colour grade (reads the screen once): a gentle S-curve for contrast, a touch
## more saturation, cool shadows / warm highlights (night-shift mood). One pass; cheap on mobile.
static func vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.5;
uniform float hurt = 0.0;
uniform float grade = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	// grade
	float l = dot(src, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(l), src, 1.12);                       // saturation +12%
	g = mix(g, g * g * (3.0 - 2.0 * g), 0.35);              // soft S-curve
	g += mix(vec3(-0.012, 0.0, 0.028), vec3(0.03, 0.012, -0.02), smoothstep(0.15, 0.75, l));
	g = mix(src, clamp(g, 0.0, 1.0), grade);
	// vignette + hurt flash on top
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.85));
	float edge = smoothstep(0.30, 0.80, d);
	vec3 col = mix(vec3(0.0), vec3(0.65, 0.04, 0.04), clamp(hurt, 0.0, 1.0));
	float a = clamp(edge * (strength + hurt * 0.45) + hurt * 0.10, 0.0, 0.95);
	COLOR = vec4(mix(g, col, a), 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

## v0.6 polish: slow drifting embers rising over the menu key art (screen space, cheap CPU particles).
static func embers(area: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 36
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.x * 0.55, 10)
	p.position = Vector2(area.x * 0.5, area.y + 10)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(8, -6)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.3, 0.0))
	g.add_point(0.15, Color(1.0, 0.6, 0.15, 0.9))
	g.add_point(0.7, Color(1.0, 0.35, 0.05, 0.6))
	g.set_color(g.get_point_count() - 1, Color(0.6, 0.15, 0.0, 0.0))
	p.color_ramp = g
	return p

## v0.6 polish: faint dust motes floating in the air of a room. Child of the camera, so they fill
## whatever is on screen; local coords keep them stable relative to the view.
static func dust_motes(view: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.z_index = 1500
	p.amount = 22
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = view * 0.5
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.gravity = Vector2(1.5, -1.0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.85, 0.0))
	g.add_point(0.5, Color(1, 0.95, 0.85, 0.22))
	g.set_color(g.get_point_count() - 1, Color(1, 0.95, 0.85, 0.0))
	p.color_ramp = g
	return p

## v0.6: big soft patches of grime / wear over a room's floor, so the 32 px tiles stop reading as a
## repeated pattern. One low-res noise texture scaled up (filtered), drawn just above the tiles.
static func grime(room_px: Vector2, seed_v: int, strength: float = 0.32) -> Sprite2D:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.16
	n.fractal_gain = 0.6
	n.fractal_octaves = 3
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.03, strength))
	g.add_point(0.4, Color(0.02, 0.02, 0.03, 0.0))
	g.add_point(0.8, Color(1, 0.95, 0.85, 0.0))
	g.set_color(g.get_point_count() - 1, Color(1, 0.95, 0.85, strength * 0.25))
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.width = maxi(8, int(room_px.x / 8.0))
	t.height = maxi(8, int(room_px.y / 8.0))
	var sp := Sprite2D.new()
	sp.texture = t
	sp.centered = false
	sp.scale = Vector2(8, 8)
	sp.z_index = -9
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sp

## v0.6: a directional blood spray (thrown AWAY from the hit), heavier drops fall a little.
static func spray(parent: Node, pos: Vector2, dir: Vector2, count: int = 18) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 2000
	p.one_shot = true
	p.emitting = true
	p.amount = count
	p.lifetime = 0.45
	p.explosiveness = 0.95
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = 32.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 260)
	p.damping_min = 60.0
	p.damping_max = 140.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 4.2
	var g := Gradient.new()
	g.set_color(0, Color("c41820"))
	g.add_point(0.5, Color("8a0e12"))
	g.set_color(g.get_point_count() - 1, Color(0.35, 0.02, 0.03, 0.0))
	p.color_ramp = g
	p.finished.connect(p.queue_free)
	parent.add_child(p)

## v0.6: the bloody screen when Nash is hurt. Procedural (no image file): a ragged rounded-square
## frame of blood soaked in from the edges, fine spray speckles inside it, a few brush streaks in
## the corners. `amount` 0..1 = how far it reaches in and how opaque it is (driven by health).
static func blood_screen_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float amount = 0.0;
uniform float aspect = 1.777;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.15; }
// round droplets: one random drop per grid cell, kept with probability `dens`
float drops(vec2 p, float dens) {
	vec2 i = floor(p); vec2 f = fract(p);
	if (h(i) > dens) return 0.0;
	vec2 c = vec2(h(i + 3.1), h(i + 7.7)) * 0.6 + 0.2;
	float rad = 0.12 + 0.3 * h(i + 1.3);
	return 1.0 - smoothstep(rad - 0.06, rad, length(f - c));
}
void fragment() {
	vec2 uv = UV;
	vec2 q = (uv - 0.5) * 2.0;
	// rounded-square distance from the centre (0 centre, 1 edge)
	float r = pow(pow(abs(q.x), 4.0) + pow(abs(q.y), 4.0), 0.25);
	vec2 sp = uv * vec2(aspect, 1.0);
	float big = fbm(sp * 3.0);
	float reach = mix(1.05, 0.55, amount);           // how far the blood soaks in
	float rr = r + (big - 0.5) * 0.45;
	float solid = smoothstep(reach - 0.02, reach + 0.12, rr);
	// spray speckles in a band inside the solid edge
	float band = smoothstep(reach - 0.45, reach, rr) * (1.0 - solid);
	float sp1 = drops(sp * 38.0, band * 0.75);
	float sp2 = drops(sp * 95.0 + 7.0, band * 0.6);
	// diagonal brush streaks near the corners
	vec2 d = vec2(uv.x + uv.y, (uv.x - uv.y) * 9.0);
	float streak = smoothstep(0.62, 0.8, vn(d * vec2(2.5, 1.0))) * smoothstep(reach - 0.2, reach + 0.1, r);
	float a = max(max(solid, streak * 0.85), max(sp1, sp2) * 0.9);
	float tone = fbm(sp * 9.0);
	vec3 dark = vec3(0.22, 0.0, 0.01);
	vec3 wet = vec3(0.72, 0.05, 0.07);
	vec3 col = mix(dark, wet, smoothstep(0.25, 0.8, tone));
	col = mix(col, vec3(0.85, 0.3, 0.32), (1.0 - solid) * 0.35);   // lighter, pinker spray
	COLOR = vec4(col, a * clamp(amount * 1.5, 0.0, 0.92));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

## v0.6: slow drifting fog / fumes over a whole room (one scrolling noise texture; cheap).
static func fog_layer(room_px: Vector2, tint: Color, seed_v: int) -> Sprite2D:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 0.012
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.noise = n
	t.seamless = true
	t.width = 256
	t.height = 256
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(0.8, 0.85, 0.9, 0.12);
uniform vec2 scale = vec2(4.0, 3.0);
void fragment() {
	vec2 uv = UV * scale;
	float a = texture(TEXTURE, uv + vec2(TIME * 0.012, TIME * 0.004)).r;
	float b = texture(TEXTURE, uv * 0.7 + vec2(-TIME * 0.008, TIME * 0.006)).r;
	float f = smoothstep(0.35, 0.8, a * 0.6 + b * 0.5);
	COLOR = vec4(tint.rgb, tint.a * f);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("scale", room_px / 256.0)
	var sp := Sprite2D.new()
	sp.texture = t
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(Vector2.ZERO, Vector2(256, 256))
	sp.centered = false
	sp.scale = room_px / 256.0
	sp.material = m
	sp.z_index = 1400
	return sp

## v0.6: a vent / leak puffing steam or smoke (rising soft puffs). `col` alpha = density.
static func smoke_vent(pos: Vector2, col: Color, rising: float = 30.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 1300
	p.texture = light_texture()
	p.amount = 14
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.direction = Vector2(0.2, -1)
	p.spread = 20.0
	p.initial_velocity_min = rising * 0.6
	p.initial_velocity_max = rising
	p.gravity = Vector2(4, -3)
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.angular_velocity_min = -20.0
	p.angular_velocity_max = 20.0
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.24
	var c := Curve.new()
	c.add_point(Vector2(0, 0.35))
	c.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.15, col)
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	return p
