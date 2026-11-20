extends Node2D

## Beached: the island in plate pixels (2087x768; the game scales and places this node). Back to front
## (KICKOFF M0): [sky: wilson_skyview.gd, its own canvas layer] -> sea + island plate (shader: moving
## foam lines + sparkles on the painted sea only, the island untouched) -> object sprites, props,
## campfire and Johnny (y-sorted) -> foreground waves. The CanvasModulate tint lives on this layer.

const D = preload("res://scripts/games/wilson/wilson_data.gd")
const Fire = preload("res://scripts/games/wilson/wilson_fire.gd")
const Castaway = preload("res://scripts/games/wilson/wilson_castaway.gd")
const Props = preload("res://scripts/games/wilson/wilson_props.gd")
const ART := "res://games/wilson/art/"

const SEA_SHADER := """
shader_type canvas_item;
uniform float amp = 0.4;
uniform float horizon = 0.4219;
uniform float night = 0.0;
uniform sampler2D sea_tex : source_color, filter_linear, repeat_enable;
uniform float use_tex = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float below = step(horizon + 0.002, UV.y);
	float sea = smoothstep(0.03, 0.12, c.b - c.r) * below * c.a;
	float depth = clamp((UV.y - horizon) / (1.0 - horizon), 0.0, 1.0);
	// gentle sideways ripple of the painted water (only where both pixels are sea)
	vec2 uv2 = UV + vec2(sin(UV.y * 900.0 * (1.2 - depth) + TIME * 1.6) * 0.0012 * (0.4 + amp) * (0.3 + depth), 0.0);
	vec4 c2 = texture(TEXTURE, uv2);
	float sea2 = smoothstep(0.03, 0.12, c2.b - c2.r);
	vec3 col = mix(c.rgb, c2.rgb, sea * sea2);
	// the owner's sea layer (art/sea/sea_tile.webp) scrolls over the painted sea; the island is untouched
	vec2 pp = vec2(UV.x * 2087.0, UV.y * 768.0);
	vec2 tuv = vec2(pp.x / 880.0 + TIME * (0.006 + amp * 0.012) + sin(TIME * 0.4 + pp.y * 0.012) * 0.004 * (0.4 + amp),
		(pp.y - 324.0) / 1000.0 + sin(TIME * 0.5 + pp.x * 0.005) * 0.004 * (0.4 + amp));
	col = mix(col, texture(sea_tex, tuv).rgb, sea * 0.88 * use_tex);
	// scrolling sine foam lines, closer together far away
	float freq = mix(260.0, 70.0, depth);
	float wob = sin(UV.x * (14.0 + depth * 10.0) + TIME * (0.5 + depth) * (0.6 + amp)) * (0.6 + amp * 1.6);
	float band = sin(UV.y * freq + wob + TIME * 0.35);
	float foam = smoothstep(0.93 - amp * 0.06, 1.0, band);
	foam *= 0.5 + 0.5 * sin(UV.x * 40.0 - TIME * (0.8 + depth * 1.4));
	col += vec3(foam) * 0.32 * (0.5 + amp) * sea * mix(1.0, 0.0, use_tex);   // no scrolling foam lines on the painted sea (owner: "the sea mist is weird")
	// sun sparkles by day, plankton glints by night
	vec2 cell = floor(vec2(UV.x * 300.0, UV.y * 160.0));
	float h = hash(cell);
	float tw = pow(max(0.0, sin(TIME * (1.5 + h * 3.0) + h * 40.0)), 24.0);
	float spark = step(0.997, h) * tw * sea * 0.6;     // rarer, dimmer (owner, 2026-11-09: the sea mist looked weird)
	vec3 sc = mix(vec3(1.0, 1.0, 0.92), vec3(0.4, 1.0, 0.95), night);
	col += sc * spark * mix(0.9, 1.3, night);
	COLOR = vec4(col, c.a);
}
"""

const WAVE_SHADER := """
shader_type canvas_item;
uniform float amp = 0.4;
uniform vec4 sea_col : source_color = vec4(0.16, 0.55, 0.62, 1.0);
void fragment() {
	float x = UV.x * 1.327;      // the rect is 33 % wider since the wide plate: same wave length
	float y = UV.y;
	float c1 = 0.35 + sin(x * 9.0 + TIME * 0.9) * 0.08 * (0.5 + amp) + sin(x * 23.0 - TIME * 1.7) * 0.03;
	float c2 = 0.68 + sin(x * 7.0 - TIME * 0.7 + 1.3) * 0.07 * (0.5 + amp) + sin(x * 19.0 + TIME * 1.3) * 0.03;
	float a = 0.0;
	vec3 col = sea_col.rgb;
	float l1 = smoothstep(0.035, 0.0, abs(y - c1));
	float l2 = smoothstep(0.03, 0.0, abs(y - c2));
	a = max(a, smoothstep(c1, c1 + 0.25, y) * 0.35);
	a = max(a, smoothstep(c2, c2 + 0.25, y) * 0.45);
	col = mix(col, vec3(0.92, 0.98, 1.0), max(l1, l2));
	a = max(a, max(l1, l2) * 0.3);
	COLOR = vec4(col, a * (0.6 + amp * 0.4));
}
"""

const SURF_SHADER := """
shader_type canvas_item;
uniform sampler2D surf_tex : source_color, filter_linear, repeat_enable;
uniform float amp = 0.4;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 uv = vec2(UV.x * 1.1 + TIME * (0.012 + amp * 0.02), 0.52 + UV.y * 0.3 + sin(TIME * 0.7 + UV.x * 6.0) * 0.01 * amp);
	vec4 t = texture(surf_tex, uv);
	float fade = smoothstep(0.0, 0.4, UV.y);
	float on = smoothstep(0.55, 0.95, amp);
	COLOR = vec4(t.rgb * tint.rgb, fade * on * 0.92);
}
"""

const SWAY_SHADER := """
shader_type canvas_item;
uniform float wind = 0.3;
uniform float phase = 0.0;
void vertex() {
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 1.1 + phase) * (2.0 + wind * 7.0) * top;
}
"""

var engine
var plate: Sprite2D
var sorted: Node2D           # y-sorted objects
var castaway                 # Castaway node
var fire                     # Fire node (only once built)
var waves: ColorRect
var surf: ColorRect
const GLOW_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 col : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float amount = 1.0;
uniform float reach = 10.0;      // halo width in texture pixels
// A halo traced from the object's own silhouette (alpha): strongest at its edge, fading outward, nothing inside.
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = texture(TEXTURE, UV).a;
	float g = 0.0;
	for (int r = 1; r <= 5; r++) {
		float f = float(r) / 5.0;
		float w = exp(-f * f * 2.2);
		for (int i = 0; i < 16; i++) {
			float ang = float(i) * 0.3927;
			g = max(g, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * reach * f * px).a * w);
		}
	}
	COLOR = vec4(col.rgb, col.a * amount * g * (1.0 - a));
}
"""
var focus_rect := Rect2()
var focus_id := ""
var mark_ids: Array = []
var _glow_pool: Array = []     # slots: {vp, holder, spr, mat, id, built}
var _glow_shader: Shader
var mark_rects: Array = []   # quest objectives: pulsing rings
var _focus_node: Node2D
var _surf_mat: ShaderMaterial
var _foam: Array = []        # [Sprite2D, base_scale, phase]
var _sea_mat: ShaderMaterial
var _wave_mat: ShaderMaterial
var _heaps := {}             # stones / shells: spot id -> Node2D of icon sprites (the wide plate has no painted ones)
var _palm_grass := {}        # id -> its grass tuft (hidden with a felled palm)
var _palms := {}             # id -> Sprite2D (C and D: cut out so they can fall)
var _stumps := {}            # id -> Props
var _debris := {}            # id -> Sprite2D
var _props := {}             # structure id -> Props
var _piles := {}             # spot id -> Props
var _shore: Node2D

func setup(e) -> void:
	engine = e
	plate = Sprite2D.new()
	plate.centered = false
	plate.texture = _tex("plate.webp")
	_sea_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SEA_SHADER
	_sea_mat.shader = sh
	plate.material = _sea_mat
	var sea_tex := _tex("sea/sea_tile.webp")
	if sea_tex:
		_sea_mat.set_shader_parameter("sea_tex", sea_tex)
		_sea_mat.set_shader_parameter("use_tex", 1.0)
	add_child(plate)
	# foam arcs from the owner's sea foam sheet, pulsing at the shoreline (KICKOFF: +-4 % scale / alpha)
	for f in [["foam_3", Vector2(1760, 500), 0.0, false, 0.45], ["foam_3", Vector2(170, 505), 0.0, true, 0.45],
			["foam_1", Vector2(700, 598), 90.0, false, 0.5], ["foam_2", Vector2(1330, 598), -90.0, false, 0.5]]:
		var ft := _tex("sea/%s.webp" % f[0])
		if ft == null:
			continue
		var fs := Sprite2D.new()
		fs.texture = ft
		fs.position = f[1]
		fs.rotation_degrees = f[2]
		fs.flip_h = f[3]
		fs.scale = Vector2.ONE * f[4]
		fs.modulate = Color(1, 1, 1, 0.55)
		add_child(fs)
		_foam.append([fs, f[4], randf() * TAU])
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	_focus_node = Node2D.new()
	_focus_node.z_index = 30
	add_child(_focus_node)
	_focus_node.draw.connect(_draw_marks)
	_glow_shader = Shader.new()
	_glow_shader.code = GLOW_SHADER
	var sway := Shader.new()
	sway.code = SWAY_SHADER
	# palm art (palm_C / palm_D were cut out of the old plate): the sprite's top-left relative to its trunk base.
	# The wide plate has no painted palms, so all six (A and B hold the hammock) are sprites; E and F are new.
	var palm_art := {"A": "D", "B": "C", "C": "C", "D": "D", "E": "E", "F": "F"}
	var palm_off := {"C": Vector2(-102, -190), "D": Vector2(-26, -208), "E": Vector2(-45, -322), "F": Vector2(-73, -203)}
	for id in D.PALMS:
		var s := Sprite2D.new()
		s.texture = _tex("palm_%s.webp" % palm_art[id])
		s.centered = false
		var base: Vector2 = D.PALMS[id].pos
		s.position = base
		s.offset = palm_off[palm_art[id]]
		var m := ShaderMaterial.new()
		m.shader = sway
		m.set_shader_parameter("phase", 0.4 + 0.9 * float(id.unicode_at(0) - 65))
		s.material = m
		sorted.add_child(s)
		_palms[id] = s
		_add_shadow(s, 90.0)
		if palm_art[id] in ["C", "D"] and _tex("palm_grass.webp"):      # the cut-out trunks end flat: a grass tuft over the foot
			var gs := Sprite2D.new()
			gs.texture = _tex("palm_grass.webp")
			# gs.position = base + Vector2(0, 2)
			# the cut-out trunks end ~10 px under their base in a thin point: the tuft sat above it and the palm
			# looked like it stood on a stilt (owner, 2026-11-20); cover the trunk end instead
			gs.position = base + Vector2(0, 13)
			gs.scale = Vector2.ONE * (70.0 / float(gs.texture.get_width()))
			gs.offset = Vector2(0, -gs.texture.get_height() * 0.62)
			sorted.add_child(gs)
			_palm_grass[id] = gs
		var st := Props.new()
		st.kind = "stump"
		st.position = base
		st.visible = false
		sorted.add_child(st)
		_stumps[id] = st
	var clump := Sprite2D.new()      # the bamboo clump: scenery on the gather spot (a sand mound in the picture)
	clump.texture = _tex("camp/bamboo_clump.webp")
	if clump.texture:
		clump.position = D.SPOTS.bamboo.pos + Vector2(0, 14)
		clump.scale = Vector2.ONE * (D.CAMP_ART.bamboo_clump[1] / float(clump.texture.get_width()))
		clump.offset = Vector2(0, -clump.texture.get_height() / 2.0)
		sorted.add_child(clump)
	for id in D.DEBRIS:
		var d: Dictionary = D.DEBRIS[id]
		var s := Sprite2D.new()
		s.texture = _tex("debris_%s.webp" % id)
		s.scale = Vector2.ONE * float(d.scale)
		s.position = d.pos
		s.offset = Vector2(0, -s.texture.get_height() * 0.42) if s.texture else Vector2.ZERO
		sorted.add_child(s)
		_debris[id] = s
		if s.texture:
			_add_shadow(s, float(s.texture.get_width()) * s.scale.x * 0.85)
	for id in ["sticks", "fronds", "dry_fronds", "seaweed"]:
		var p := Props.new()
		p.kind = {"sticks": "pile_sticks", "fronds": "pile_fronds", "dry_fronds": "pile_dry", "seaweed": "pile_seaweed"}[id]
		p.position = D.SPOTS[id].pos
		sorted.add_child(p)
		_piles[id] = p
	for id in ["stones", "shells"]:
		var ic := _tex("icons/stone.webp") if id == "stones" else _tex("icons/shell.webp")
		if ic == null:
			continue
		var heap := Node2D.new()
		heap.position = D.SPOTS[id].pos
		var w := 26.0 if id == "stones" else 20.0
		for off in [Vector2(-22, 4), Vector2(0, 9), Vector2(22, 3), Vector2(-9, -5), Vector2(12, -4), Vector2(-32, -3)]:
			var sp := Sprite2D.new()
			sp.texture = ic
			sp.scale = Vector2.ONE * (w / float(ic.get_width()))
			sp.position = off
			sp.offset = Vector2(0, -ic.get_height() / 2.0)
			heap.add_child(sp)
		sorted.add_child(heap)
		_heaps[id] = heap
	_shore = Props.new()
	_shore.kind = "shore"
	_shore.position = D.SHORE.pos
	sorted.add_child(_shore)
	castaway = Castaway.new()
	castaway.look = engine.look
	castaway.position = D.START_POS
	sorted.add_child(castaway)
	waves = ColorRect.new()
	waves.position = Vector2(-400, 640)
	waves.size = Vector2(D.W + 800, 140)
	waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_mat = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = WAVE_SHADER
	_wave_mat.shader = ws
	waves.material = _wave_mat
	add_child(waves)
	var surf_tex := _tex("sea/front_waves.webp")
	if surf_tex:
		surf = ColorRect.new()
		surf.position = Vector2(-400, 600)
		surf.size = Vector2(D.W + 800, 168)
		surf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_surf_mat = ShaderMaterial.new()
		var ss := Shader.new()
		ss.code = SURF_SHADER
		_surf_mat.shader = ss
		_surf_mat.set_shader_parameter("surf_tex", surf_tex)
		surf.material = _surf_mat
		add_child(surf)
	sync()

static var _shadow_tex: Texture2D

## A soft contact shadow on the sand under `n` (its origin is its base), `w` plate pixels wide. It follows the
## node (hides with it) and draws behind it.
func _add_shadow(n: Node2D, w: float) -> void:
	if _shadow_tex == null:
		var g := GradientTexture2D.new()
		g.width = 64
		g.height = 64
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.set_color(0, Color(0, 0, 0, 0.55))
		gr.set_color(1, Color(0, 0, 0, 0))
		gr.add_point(0.55, Color(0, 0, 0, 0.3))
		g.gradient = gr
		_shadow_tex = g
	var sh := Sprite2D.new()
	sh.texture = _shadow_tex
	sh.show_behind_parent = true
	sh.modulate = Color(0.12, 0.08, 0.04, 0.7)
	var k := w / 64.0
	sh.scale = Vector2(k, k * 0.3) / n.scale
	sh.position = Vector2(0, 2) / n.scale
	n.add_child(sh)

## A one-shot puff at plate position `p`: "dust" (gather / salvage), "spark" (made / built), "chips" (crate).
func burst(p: Vector2, kind: String) -> void:
	var c := CPUParticles2D.new()
	c.position = p
	c.one_shot = true
	c.emitting = true
	c.explosiveness = 0.95
	c.direction = Vector2(0, -1)
	c.spread = 75.0
	c.gravity = Vector2(0, 260)
	c.lifetime = 0.7
	match kind:
		"spark":
			c.amount = 16
			c.initial_velocity_min = 50.0
			c.initial_velocity_max = 120.0
			c.gravity = Vector2(0, 60)
			c.scale_amount_min = 2.0
			c.scale_amount_max = 4.0
			c.color = Color(1.0, 0.86, 0.4)
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			c.material = cm
			c.lifetime = 0.9
		"chips":
			c.amount = 14
			c.initial_velocity_min = 70.0
			c.initial_velocity_max = 170.0
			c.scale_amount_min = 2.5
			c.scale_amount_max = 5.0
			c.color = Color(0.58, 0.4, 0.22)
		_:
			c.amount = 12
			c.initial_velocity_min = 25.0
			c.initial_velocity_max = 70.0
			c.gravity = Vector2(0, 40)
			c.scale_amount_min = 3.0
			c.scale_amount_max = 7.0
			c.color = Color(0.9, 0.78, 0.55, 0.8)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	c.color_ramp = ramp
	_focus_node.add_child(c)
	get_tree().create_timer(1.6).timeout.connect(c.queue_free)

func _tex(file: String) -> Texture2D:
	var p := ART + file
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## Matches what is on screen to the engine: debris, palms, structures, piles, the fire.
func sync() -> void:
	for id in _debris:
		_debris[id].visible = engine.debris.get(id, false)
	for id in _palms:
		var felled: bool = float(engine.palms[id].felled) > 0.0
		_palms[id].visible = not felled
		if _palm_grass.has(id):
			_palm_grass[id].visible = not felled
		_stumps[id].visible = felled
	for id in D.CAMP:
		var built: bool = engine.structures.has(id)
		if built and not _props.has(id):
			if id == "campfire":
				fire = Fire.new()
				fire.position = D.CAMP[id].pos
				sorted.add_child(fire)
				_props[id] = fire
			else:
				var p := Props.new()
				p.kind = id
				p.position = D.CAMP[id].pos
				if D.CAMP_ART.has(id):
					var art: Array = D.CAMP_ART[id]
					p.tex = _tex("%s/%s.webp" % [art[3] if art.size() > 3 else "camp", art[0]])
					p.tex_w = art[1]
					p.tex_lift = art[2]
				sorted.add_child(p)
				_props[id] = p
		elif not built and _props.has(id):
			_props[id].queue_free()
			_props.erase(id)
			if id == "campfire":
				fire = null
	if _props.has("crafting_stump"):
		var st = _props.crafting_stump
		if int(st.data.get("tallies", -1)) != engine.tallies.size():
			st.data = {"tallies": engine.tallies.size()}
			st.refresh()
	# the garden plot shows sprouts while something grows in it
	if _props.has("garden_plot"):
		var gp = _props.garden_plot
		var gs: String = engine.garden_state()
		if str(gp.data.get("g", "")) != gs:
			gp.data = {"g": gs}
			var sprouts := _tex("camp/garden_sprouts.webp") if gs in ["growing", "ready"] else null
			gp.tex = sprouts if sprouts else _tex("camp/garden_plot.webp")
			gp.refresh()
	# the garden plot shows sprouts while something grows in it
	if _props.has("garden_plot"):
		var gp = _props.garden_plot
		var gs: String = engine.garden_state()
		if str(gp.data.get("g", "")) != gs:
			gp.data = {"g": gs}
			var sprouts := _tex("camp/garden_sprouts.webp") if gs in ["growing", "ready"] else null
			gp.tex = sprouts if sprouts else _tex("camp/garden_plot.webp")
			gp.refresh()
	for id in _piles:
		var s: Dictionary = D.SPOTS[id]
		var amt := clampf(float(engine.spots.get(id, 0.0)) / float(s.max), 0.0, 1.0)
		var p = _piles[id]
		p.visible = amt >= 1.0 / float(s.max)
		if absf(p.amount - amt) > 0.08:
			p.amount = amt
			p.refresh()
	for id in _heaps:      # fewer icons as the stock runs down
		var hp := clampf(float(engine.spots.get(id, 0.0)) / float(D.SPOTS[id].max), 0.0, 1.0)
		var shown := int(ceil(hp * 6.0)) if float(engine.spots.get(id, 0.0)) >= 1.0 else 0
		for i in _heaps[id].get_child_count():
			_heaps[id].get_child(i).visible = i < shown
	_shore.visible = not engine.shore.pile.is_empty()
	# the hammock sprite hides while the castaway lies in it (his "hammock" pose includes one)
	if _props.has("hammock"):
		_props.hammock.visible = not in_hammock()
	if castaway and castaway.look != engine.shown_look():
		castaway.set_look(engine.shown_look())

## Sleeping or napping in the hammock right now.
func in_hammock() -> bool:
	if engine.sleep.is_empty():
		return false
	var bed := str(engine.sleep.get("bed", ""))
	return bed == "hammock" or (bed == "shade" and engine.structures.has("hammock"))

## Every frame: sea motion from the weather, fire state, night glints.
func tick(night: float, sea_amp: float, wind: float) -> void:
	if _focus_node:
		_update_glows()
		if not mark_rects.is_empty():
			_focus_node.queue_redraw()
	_sea_mat.set_shader_parameter("amp", sea_amp)
	_sea_mat.set_shader_parameter("night", night)
	_wave_mat.set_shader_parameter("amp", sea_amp)
	if _surf_mat:
		_surf_mat.set_shader_parameter("amp", sea_amp)
	var tt := Time.get_ticks_msec() / 1000.0
	for f in _foam:
		var k: float = sin(tt * 0.9 + float(f[2]))
		f[0].scale = Vector2.ONE * float(f[1]) * (1.0 + 0.04 * k)
		f[0].modulate.a = 0.0      # hidden: the pale foam arcs read as ghostly tentacles (owner, 2026-11-09: "the sea mist is weird")
	for id in _palms:
		_palms[id].material.set_shader_parameter("wind", wind)
	if fire:
		fire.state = engine.fire_state()
		fire.level = engine.fire_level()
		fire.night = night
		fire.wind = wind

func set_wave_color(c: Color) -> void:
	_wave_mat.set_shader_parameter("sea_col", c)
	if _surf_mat:
		_surf_mat.set_shader_parameter("tint", Color(0.55 + c.r * 2.0, 0.55 + c.g * 0.8, 0.55 + c.b * 0.8))

# ================================================================ tapping

## What is at plate position `p`: {"type": ..., "id": ...}; type "" = open ground.
func hit(p: Vector2) -> Dictionary:
	if castaway and Rect2(castaway.position + Vector2(-26, -100), Vector2(52, 104)).has_point(p):
		return {"type": "johnny"}
	for id in _props:
		var pos: Vector2 = D.CAMP[id].pos
		var r := Rect2(pos + Vector2(-50, -60), Vector2(100, 70))
		if id == "hammock":
			r = Rect2(pos + Vector2(-70, -40), Vector2(140, 50))
		if r.has_point(p):
			return {"type": "structure", "id": id}
	if _shore.visible and Rect2(D.SHORE.pos + Vector2(-40, -36), Vector2(80, 50)).has_point(p):
		return {"type": "shore"}
	for id in _debris:
		var s: Sprite2D = _debris[id]
		if s.visible and s.texture:
			var sz := s.texture.get_size() * s.scale
			if Rect2(s.position + s.offset * s.scale - sz / 2.0, sz).grow(6).has_point(p):
				return {"type": "debris", "id": id}
	for id in D.SPOTS:
		if p.distance_to(D.SPOTS[id].pos) < 34.0:
			return {"type": "spot", "id": id}
	for id in D.PALMS:
		var pm: Dictionary = D.PALMS[id]
		var top: Vector2 = pm.top
		var base: Vector2 = pm.pos
		if Rect2(Vector2(minf(top.x, base.x) - 30, top.y - 40), Vector2(absf(top.x - base.x) + 60, base.y - top.y + 50)).has_point(p):
			return {"type": "palm", "id": id}
	if Rect2(D.CAVE.pos + Vector2(-80, -110), Vector2(170, 150)).has_point(p):
		return {"type": "cave"}
	if p.y > 575.0 and p.y < 700.0 and p.x > 380.0 and p.x < 1650.0:
		return {"type": "shallows"}
	return {"type": ""}

## Everything the castaway can use: [{"probe": plate point that hit() maps to it, "id": text, "rect": its box}].
func interactables() -> Array:
	var out: Array = []
	for id in _debris:
		var s: Sprite2D = _debris[id]
		if s.visible and s.texture:
			var sz := s.texture.get_size() * s.scale
			var c := s.position + s.offset * s.scale
			out.append({"probe": c, "id": "debris:" + str(id), "rect": Rect2(c - sz / 2.0, sz)})
	for id in D.SPOTS:
		var sp: Vector2 = D.SPOTS[id].pos
		out.append({"probe": sp, "id": "spot:" + str(id), "rect": Rect2(sp + Vector2(-34, -26), Vector2(68, 44))})
	for id in D.PALMS:
		var pm: Dictionary = D.PALMS[id]
		var top: Vector2 = pm.top
		var base: Vector2 = pm.pos
		out.append({"probe": Vector2(base.x, base.y - 20.0), "id": "palm:" + str(id),
			"rect": Rect2(Vector2(minf(top.x, base.x) - 26, top.y - 30), Vector2(absf(top.x - base.x) + 52, base.y - top.y + 40))})
	for id in _props:
		var pr = _props[id]
		var pos: Vector2 = D.CAMP[id].pos
		var r := Rect2(pos + Vector2(-50, -60), Vector2(100, 70))
		if pr is Node2D and "tex" in pr and pr.tex:
			var sz: Vector2 = pr.tex.get_size() * (float(pr.tex_w) / float(pr.tex.get_width()))
			r = Rect2(pos + Vector2(-sz.x / 2.0, -sz.y - float(pr.tex_lift)), sz)
		out.append({"probe": pos + Vector2(0, -10), "id": "structure:" + str(id), "rect": r})
	if _shore and _shore.visible:
		out.append({"probe": D.SHORE.pos, "id": "shore", "rect": Rect2(D.SHORE.pos + Vector2(-40, -36), Vector2(80, 50))})
	out.append({"probe": D.CAVE.pos + Vector2(0, -20), "id": "cave", "rect": Rect2(D.CAVE.pos + Vector2(-80, -110), Vector2(170, 150))})
	return out

## Quest objectives: a golden halo hugging their silhouette (owner, 2026-11-09: "not a circle, not a box";
## 2026-11-17: "just outside its silhouette"). `ids` = the interactable ids, parallel to `rects`.
func set_marks(rects: Array, ids: Array = []) -> void:
	mark_rects = rects
	mark_ids = ids
	if _focus_node:
		_focus_node.queue_redraw()

## Only the small bobbing arrow is drawn; the halo itself is a shader (GLOW_SHADER).
func _draw_marks() -> void:
	var tt := Time.get_ticks_msec() * 0.004
	for r in mark_rects:
		var c: Vector2 = r.get_center()
		var ay: float = r.position.y - 26.0 - 5.0 * sin(tt * 1.6)
		_focus_node.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 12, ay - 18), Vector2(c.x + 12, ay - 18), Vector2(c.x, ay)]), Color(1.0, 0.82, 0.25, 0.95))

## What a button press would hit right now (close and directly in front): a soft warm halo (empty = none).
## Everything else that is selectable stays dark unless it is the current objective.
func set_focus(r: Rect2, id: String = "") -> void:
	focus_rect = r
	focus_id = id

const GLOW_PAD := 30.0       # plate pixels around the object for the halo
const GLOW_RES := 0.5        # the mask is rendered at half size: the halo is soft anyway

## The node drawing the thing behind an interactable id, or null (the cave, the shallows, Johnny, the fire:
## those get the arrow only).
func _glow_source(id: String) -> Node2D:
	var kind := id.get_slice(":", 0)
	var key := id.get_slice(":", 1) if ":" in id else ""
	match kind:
		"debris":
			return _debris.get(key)
		"palm":
			return _palms.get(key)
		"structure":
			var pr = _props.get(key)
			return pr if pr is Props else null
		"spot":
			if _heaps.has(key):
				return _heaps[key]
			return _piles.get(key)
		"shore":
			return _shore
	return null

## Plate-space box of the sprites under `n` (children are not scaled or rotated in this scene).
func _sprite_box(n: Node2D, base: Vector2, acc: Array) -> void:
	var at := base + n.position
	if n is Sprite2D and n.texture and n.visible:
		var sz: Vector2 = n.texture.get_size() * n.scale
		var o: Vector2 = n.offset * n.scale
		acc.append(Rect2(at + o - (sz / 2.0 if n.centered else Vector2.ZERO), sz))
	for ch in n.get_children():
		if ch is Node2D:
			_sprite_box(ch, at, acc)

func _glow_box(src: Node2D, rect: Rect2) -> Rect2:
	var boxes: Array = []
	_sprite_box(src, Vector2.ZERO, boxes)
	var out := rect
	for b in boxes:
		out = out.merge(b)
	if src is Props and src.tex:
		var sz: Vector2 = src.tex.get_size() * (float(src.tex_w) / float(src.tex.get_width()))
		out = out.merge(Rect2(src.position + Vector2(-sz.x / 2.0, -sz.y - float(src.tex_lift)), sz))
	return out.grow(GLOW_PAD)

func _clone_for_glow(src: Node2D) -> Node2D:
	if src is Props:
		var p := Props.new()
		p.kind = src.kind
		p.amount = src.amount
		p.data = src.data.duplicate()
		p.tex = src.tex
		p.tex_w = src.tex_w
		p.tex_lift = src.tex_lift
		return p
	return src.duplicate()

func _glow_slot(i: int) -> Dictionary:
	while _glow_pool.size() <= i:
		var vp := SubViewport.new()
		vp.world_2d = World2D.new()
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.size = Vector2i(8, 8)
		var holder := Node2D.new()
		holder.scale = Vector2.ONE * GLOW_RES
		vp.add_child(holder)
		_focus_node.add_child(vp)
		var spr := Sprite2D.new()
		spr.centered = false
		spr.scale = Vector2.ONE / GLOW_RES
		var m := ShaderMaterial.new()
		m.shader = _glow_shader
		m.set_shader_parameter("reach", 10.0)
		spr.material = m
		spr.texture = vp.get_texture()
		spr.visible = false
		_focus_node.add_child(spr)
		_glow_pool.append({"vp": vp, "holder": holder, "spr": spr, "mat": m, "id": "", "built": 0})
	return _glow_pool[i]

func _update_glows() -> void:
	var list: Array = []     # [id, rect, colour, strength]
	var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	for i in mark_rects.size():
		var mid := str(mark_ids[i]) if i < mark_ids.size() else ""
		list.append([mid, mark_rects[i], Color(1.0, 0.78, 0.18), 1.1 + 0.6 * k])
	if focus_rect.size != Vector2.ZERO and focus_id != "" and not (focus_id in mark_ids):
		list.append([focus_id, focus_rect, Color(1.0, 0.95, 0.8), 0.7 + 0.3 * k])
	var now := Time.get_ticks_msec()
	for i in maxi(list.size(), _glow_pool.size()):
		var slot: Dictionary = _glow_slot(i) if i < list.size() else _glow_pool[i]
		var spr: Sprite2D = slot.spr
		var src: Node2D = _glow_source(str(list[i][0])) if i < list.size() else null
		if src == null or not src.visible:
			spr.visible = false
			slot.id = ""
			continue
		var id := str(list[i][0])
		# (re)draw the mask when the target changes, and a few times a second (piles shrink, doors open)
		if slot.id != id or now - int(slot.built) > 400:
			slot.id = id
			slot.built = now
			var box := _glow_box(src, list[i][1])
			var holder: Node2D = slot.holder
			for ch in holder.get_children():
				ch.queue_free()
			var cl := _clone_for_glow(src)
			cl.position = src.position - box.position
			holder.add_child(cl)
			var vp: SubViewport = slot.vp
			vp.size = Vector2i(maxi(int(ceil(box.size.x * GLOW_RES)), 8), maxi(int(ceil(box.size.y * GLOW_RES)), 8))
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			spr.position = box.position
		var m: ShaderMaterial = slot.mat
		m.set_shader_parameter("col", list[i][2])
		m.set_shader_parameter("amount", list[i][3])
		spr.visible = true

## Nearest walkable point to `p` (snapped to a depth lane).
static func walk_point(p: Vector2) -> Vector2:
	var best: Dictionary = D.LANES[0]
	for lane in D.LANES:
		if absf(p.y - float(lane.y)) < absf(p.y - float(best.y)):
			best = lane
	return Vector2(clampf(p.x, float(best.x0), float(best.x1)), float(best.y))
