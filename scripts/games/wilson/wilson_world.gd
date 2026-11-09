extends Node2D

## Beached: the island in plate pixels (1376x768; the game scales and places this node). Back to front
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
uniform float horizon = 0.4258;
uniform float night = 0.0;
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
	// scrolling sine foam lines, closer together far away
	float freq = mix(260.0, 70.0, depth);
	float wob = sin(UV.x * (14.0 + depth * 10.0) + TIME * (0.5 + depth) * (0.6 + amp)) * (0.6 + amp * 1.6);
	float band = sin(UV.y * freq + wob + TIME * 0.35);
	float foam = smoothstep(0.93 - amp * 0.06, 1.0, band);
	foam *= 0.5 + 0.5 * sin(UV.x * 40.0 - TIME * (0.8 + depth * 1.4));
	col += vec3(foam) * 0.32 * (0.5 + amp) * sea;
	// sun sparkles by day, plankton glints by night
	vec2 cell = floor(vec2(UV.x * 300.0, UV.y * 160.0));
	float h = hash(cell);
	float tw = pow(max(0.0, sin(TIME * (1.5 + h * 3.0) + h * 40.0)), 24.0);
	float spark = step(0.985, h) * tw * sea;
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
	float x = UV.x;
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
	a = max(a, max(l1, l2) * 0.75);
	COLOR = vec4(col, a * (0.6 + amp * 0.4));
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
var _sea_mat: ShaderMaterial
var _wave_mat: ShaderMaterial
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
	add_child(plate)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	var sway := Shader.new()
	sway.code = SWAY_SHADER
	var palm_origin := {"C": Vector2(1048, 140), "D": Vector2(1196, 232)}
	for id in palm_origin:
		var s := Sprite2D.new()
		s.texture = _tex("palm_%s.webp" % id)
		s.centered = false
		var base: Vector2 = D.PALMS[id].pos
		s.position = base
		s.offset = palm_origin[id] - base
		var m := ShaderMaterial.new()
		m.shader = sway
		m.set_shader_parameter("phase", 1.7 if id == "C" else 0.4)
		s.material = m
		sorted.add_child(s)
		_palms[id] = s
		var st := Props.new()
		st.kind = "stump"
		st.position = base
		st.visible = false
		sorted.add_child(st)
		_stumps[id] = st
	for id in D.DEBRIS:
		var d: Dictionary = D.DEBRIS[id]
		var s := Sprite2D.new()
		s.texture = _tex("debris_%s.webp" % id)
		s.scale = Vector2.ONE * float(d.scale)
		s.position = d.pos
		s.offset = Vector2(0, -s.texture.get_height() * 0.42) if s.texture else Vector2.ZERO
		sorted.add_child(s)
		_debris[id] = s
	for id in ["sticks", "fronds", "dry_fronds", "seaweed"]:
		var p := Props.new()
		p.kind = {"sticks": "pile_sticks", "fronds": "pile_fronds", "dry_fronds": "pile_dry", "seaweed": "pile_seaweed"}[id]
		p.position = D.SPOTS[id].pos
		sorted.add_child(p)
		_piles[id] = p
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
	sync()

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
	for id in _piles:
		var s: Dictionary = D.SPOTS[id]
		var amt := clampf(float(engine.spots.get(id, 0.0)) / float(s.max), 0.0, 1.0)
		var p = _piles[id]
		p.visible = amt >= 1.0 / float(s.max)
		if absf(p.amount - amt) > 0.08:
			p.amount = amt
			p.refresh()
	_shore.visible = not engine.shore.pile.is_empty()
	# the hammock sprite hides while the castaway lies in it (his "hammock" pose includes one)
	if _props.has("hammock"):
		_props.hammock.visible = not in_hammock()
	if castaway and castaway.look != engine.look:
		castaway.set_look(engine.look)

## Sleeping or napping in the hammock right now.
func in_hammock() -> bool:
	if engine.sleep.is_empty():
		return false
	var bed := str(engine.sleep.get("bed", ""))
	return bed == "hammock" or (bed == "shade" and engine.structures.has("hammock"))

## Every frame: sea motion from the weather, fire state, night glints.
func tick(night: float, sea_amp: float, wind: float) -> void:
	_sea_mat.set_shader_parameter("amp", sea_amp)
	_sea_mat.set_shader_parameter("night", night)
	_wave_mat.set_shader_parameter("amp", sea_amp)
	for id in _palms:
		_palms[id].material.set_shader_parameter("wind", wind)
	if fire:
		fire.state = engine.fire_state()
		fire.level = engine.fire_level()
		fire.night = night
		fire.wind = wind

func set_wave_color(c: Color) -> void:
	_wave_mat.set_shader_parameter("sea_col", c)

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
	if p.y > 560.0 and p.y < 700.0 and p.x > 150.0 and p.x < 1250.0:
		return {"type": "shallows"}
	return {"type": ""}

## Nearest walkable point to `p` (snapped to a depth lane).
static func walk_point(p: Vector2) -> Vector2:
	var best: Dictionary = D.LANES[0]
	for lane in D.LANES:
		if absf(p.y - float(lane.y)) < absf(p.y - float(best.y)):
			best = lane
	return Vector2(clampf(p.x, float(best.x0), float(best.x1)), float(best.y))
