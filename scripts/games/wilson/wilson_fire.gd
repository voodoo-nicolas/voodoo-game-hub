extends Node2D

## Beached: the campfire (GDD §9). Three flame layers (outer / mid / core, placeholder shapes) with sine
## scale and skew at different speeds and random offsets; sparks + smoke particles (smoke leans with the
## wind). Flame size = fuel level; rain -> embers; no fuel -> dead coals. Position = the base of the fire,
## in plate pixels. The light (#ffb35a, +-8 % noise flicker) is `glow_energy()` / `glow_radius()`: the
## game draws it as an additive glow on a layer above the night tint (a PointLight2D under the
## CanvasModulate did not light the island on the mobile renderer).

const LIGHT_COLOR := Color("ffb35a")
## Owner's fire parts (fire3.jpg, cut by tools/wilson_art.py). Pit width on screen, plate pixels.
const ART := "res://games/wilson/art/fire/"
const PIT_W := 92.0
const FLICKER := 0.08

var level := 1.0          # 0..1 fuel
var state := "lit"        # lit / embers / dead
var night := 0.0          # 0 day .. 1 night: how strong the light is
var wind := 0.0           # -1..1
var _t := 0.0
var _seed := randf() * 100.0
var _noise := FastNoiseLite.new()
var _sparks: CPUParticles2D
var _smoke: CPUParticles2D
var _ring: Node2D
var _tex := {}

func _ready() -> void:
	for n in ["pit_unlit", "pit_embers", "flame_large", "flame_mid", "flame_core", "smoke"]:
		if ResourceLoader.exists(ART + n + ".webp"):
			_tex[n] = load(ART + n + ".webp")
	_noise.frequency = 2.5
	_noise.seed = randi()
	_ring = Node2D.new()
	_ring.draw.connect(_draw_ring)
	_ring.show_behind_parent = true
	add_child(_ring)
	_sparks = CPUParticles2D.new()
	_sparks.amount = 14
	_sparks.lifetime = 1.3
	_sparks.position = Vector2(0, -18)
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(10, 2)
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 25.0
	_sparks.initial_velocity_min = 30.0
	_sparks.initial_velocity_max = 70.0
	_sparks.gravity = Vector2(0, -20)
	_sparks.scale_amount_min = 1.5
	_sparks.scale_amount_max = 3.0
	var sg := Gradient.new()
	sg.set_color(0, Color(1.0, 0.85, 0.4, 1))
	sg.set_color(1, Color(1.0, 0.35, 0.1, 0))
	_sparks.color_ramp = sg
	add_child(_sparks)
	_smoke = CPUParticles2D.new()
	_smoke.amount = 10
	_smoke.lifetime = 3.2
	_smoke.position = Vector2(0, -30)
	_smoke.direction = Vector2(0, -1)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 14.0
	_smoke.initial_velocity_max = 24.0
	_smoke.gravity = Vector2(0, -6)
	_smoke.scale_amount_min = 6.0
	_smoke.scale_amount_max = 10.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	_smoke.scale_amount_curve = curve
	var mg := Gradient.new()
	mg.set_color(0, Color(0.55, 0.55, 0.55, 0.35))
	mg.set_color(1, Color(0.7, 0.7, 0.7, 0))
	_smoke.color_ramp = mg
	_smoke.show_behind_parent = true
	if _tex.has("smoke"):
		_smoke.texture = _tex.smoke
		_smoke.scale_amount_min = 0.12
		_smoke.scale_amount_max = 0.2
	add_child(_smoke)

func _process(dt: float) -> void:
	_t += dt
	var lit := state == "lit"
	_sparks.emitting = lit and level > 0.05
	_smoke.emitting = state != "dead" or level > 0.0
	_smoke.gravity = Vector2(wind * 18.0, -6)
	_smoke.amount = 10 if state != "embers" else 6
	queue_redraw()

## 0..1 light strength right now (flickers +-8 %).
func glow_energy() -> float:
	var flick := 1.0 + _noise.get_noise_1d(_t * 10.0) * FLICKER * 1.6
	var base := 0.0
	if state == "lit":
		base = lerpf(0.15, 1.0, night) * lerpf(0.45, 1.0, level)
	elif state == "embers":
		base = lerpf(0.05, 0.3, night)
	return clampf(base * flick, 0.0, 1.2)

## Light radius in plate pixels.
func glow_radius() -> float:
	return lerpf(170.0, 300.0, level) * (1.0 + _noise.get_noise_1d(_t * 7.0 + 30.0) * FLICKER)

func _draw_ring() -> void:
	if _tex.has("pit_unlit"):
		return  # the pit sprite is drawn in _draw (it changes with the state)
	# stones around the fire (drawn once)
	for i in 9:
		var a := PI + PI * float(i) / 8.0
		var p := Vector2(cos(a) * 30.0, sin(a) * 9.0 + 4.0)
		_ring.draw_rect(Rect2(p - Vector2(7, 5), Vector2(14, 10)), Color("7d7a72"))
		_ring.draw_rect(Rect2(p - Vector2(7, 5), Vector2(14, 3)), Color("a19d93"))
	for i in 5:
		var a := float(i) * 0.6 - 1.2
		_ring.draw_set_transform(Vector2(0, -2), a, Vector2.ONE)
		_ring.draw_rect(Rect2(-20, -3, 40, 6), Color("5a3a22"))
	_ring.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw() -> void:
	if _tex.has("pit_unlit"):
		_draw_sprites()
		return
	if state == "dead":
		draw_rect(Rect2(-16, -4, 32, 6), Color(0.15, 0.12, 0.1))
		return
	if state == "embers":
		var glow := 0.6 + 0.4 * sin(_t * 3.0 + _seed)
		draw_rect(Rect2(-16, -5, 32, 7), Color(0.9, 0.3, 0.1, glow))
		return
	var s := lerpf(0.45, 1.0, level)
	_flame(Color(1.0, 0.45, 0.1, 0.85), 26.0 * s, 62.0 * s, 1.7, 0.0)
	_flame(Color(1.0, 0.7, 0.2, 0.9), 18.0 * s, 46.0 * s, 2.6, 1.3)
	_flame(Color(1.0, 0.95, 0.65, 0.95), 9.0 * s, 26.0 * s, 3.7, 2.1)

## One teardrop flame: sine scale (height) and skew (sideways lean) at its own speed.
func _flame(col: Color, w: float, h: float, speed: float, off: float) -> void:
	var k := _t * speed + off + _seed
	var hh := h * (1.0 + 0.12 * sin(k) + 0.06 * sin(k * 2.3))
	var skew := 0.18 * sin(k * 0.8) + wind * 0.25
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var a := PI * float(i) / steps
		pts.append(Vector2(-cos(a) * w * 0.5, sin(a) * w * 0.3 - w * 0.3))
	pts.append(Vector2(skew * hh, -hh))
	draw_colored_polygon(pts, col)

## Sprite version: the stone pit (cold or glowing), then three flames from the owner's art with
## their own sine scale and skew (outer = large, mid, core).
func _draw_sprites() -> void:
	var pit: Texture2D = _tex.pit_unlit if state == "dead" else _tex.get("pit_embers", _tex.pit_unlit)
	var k := PIT_W / float(pit.get_width())
	var psz := pit.get_size() * k
	draw_texture_rect(pit, Rect2(Vector2(-psz.x / 2.0, -psz.y * 0.75), psz), false)
	if state == "embers":
		var glow := 0.55 + 0.45 * sin(_t * 3.0 + _seed)
		draw_texture_rect(pit, Rect2(Vector2(-psz.x / 2.0, -psz.y * 0.75), psz), false, Color(1.0, 0.5, 0.3, glow * 0.4))
	if state != "lit":
		return
	var s := lerpf(0.5, 1.0, level)
	_flame_tex("flame_large", 52.0 * s, 1.7, 0.0, Color(1, 1, 1, 0.92))
	_flame_tex("flame_mid", 38.0 * s, 2.6, 1.3, Color(1, 1, 1, 0.95))
	_flame_tex("flame_core", 22.0 * s, 3.7, 2.1, Color(1, 1, 1, 0.95))

func _flame_tex(n: String, w: float, speed: float, off: float, col: Color) -> void:
	var tex: Texture2D = _tex.get(n)
	if tex == null:
		return
	var k := _t * speed + off + _seed
	var sy := 1.0 + 0.12 * sin(k) + 0.06 * sin(k * 2.3)
	var sx := 1.0 - 0.06 * sin(k * 1.3)
	var skew := 0.16 * sin(k * 0.8) + wind * 0.22
	var h := w * tex.get_height() / float(tex.get_width())
	# x' = x + skew * (-y): the tip leans, the base stays put
	var m := Transform2D(Vector2(sx, 0), Vector2(-skew * sy, sy), Vector2(0, -6))
	draw_set_transform_matrix(m)
	draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -h), Vector2(w, h)), false, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)
