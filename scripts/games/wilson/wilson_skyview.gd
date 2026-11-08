extends Node2D

## Beached: the sky, behind everything (its own canvas layer, so the night tint does not dim it twice).
## Gradient sky_top -> horizon from daynight.json keyframes, stars (fade per daynight.json), the sun and
## the moon on their arcs (the moon shows the real phase, lit side flipped in the southern hemisphere),
## drifting clouds. Drawn in screen pixels; `stage_pos` / `stage_scale` place the plate.

const D = preload("res://scripts/games/wilson/wilson_data.gd")
const ART := "res://games/wilson/art/"

var stage_pos := Vector2.ZERO
var stage_scale := 1.0
var sky := {"sky_top": Color("3d9bd6"), "horizon": Color("cdeef2"), "light_tint": Color.WHITE, "intensity": 1.0}
var stars := 0.0
var sun := Vector2(0.5, 1.0)      # x 0..1 across, height 0..1
var moon := Vector2(0.5, -1.0)
var moon_phase := 0.0
var south := true
var cloudiness := 0.35            # 0..1 (weather)
var _stars: Array = []
var _clouds: Array = []
var _cloud_tex: Array = []
var _t := 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		_stars.append([rng.randf(), pow(rng.randf(), 1.4), rng.randf() * TAU, rng.randf_range(1.0, 2.6)])
	for f in ["cloud_1.webp", "cloud_2.webp"]:
		if ResourceLoader.exists(ART + f):
			_cloud_tex.append(load(ART + f))
	for i in 6:
		_clouds.append([rng.randf(), rng.randf_range(0.08, 0.6), rng.randf_range(0.5, 1.1), rng.randf_range(4.0, 11.0), i % 2])

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _horizon_y() -> float:
	return stage_pos.y + D.HORIZON_Y * stage_scale

func _draw() -> void:
	var vr := get_viewport_rect()
	var hy := _horizon_y()
	var top := Color(sky.sky_top)
	var hor := Color(sky.horizon)
	# sky gradient (one quad with vertex colours), solid top above the gradient if the screen is tall
	var pts := PackedVector2Array([Vector2(0, minf(0, hy - 400)), Vector2(vr.size.x, minf(0, hy - 400)),
		Vector2(vr.size.x, hy + 4), Vector2(0, hy + 4)])
	draw_polygon(pts, PackedColorArray([top, top, hor, hor]))
	# below the horizon (only visible past the plate's edges on odd screens): sea colour
	draw_rect(Rect2(0, hy + 2, vr.size.x, vr.size.y - hy), Color("1f7f8e") * Color(sky.light_tint) * lerpf(0.55, 1.0, float(sky.intensity)))
	# stars
	if stars > 0.01:
		for s in _stars:
			var p := Vector2(s[0] * vr.size.x, s[1] * (hy - 10.0))
			var tw := 0.6 + 0.4 * sin(_t * 1.3 + s[2])
			var a: float = stars * tw * (0.4 + 0.6 * (1.0 - s[1]))
			var sz: float = s[3]
			draw_rect(Rect2(p - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(1, 1, 0.95, a))
	var span := Vector2(vr.size.x * 0.06, vr.size.x * 0.94)
	var arc_h := hy - maxf(40.0, hy * 0.12)
	# sun
	if sun.y > -0.1:
		var sp := Vector2(lerpf(span.x, span.y, sun.x), hy + 10.0 - sun.y * arc_h)
		var r := 34.0 * stage_scale
		var warm := Color(1.0, 0.95, 0.7).lerp(Color(1.0, 0.65, 0.35), 1.0 - clampf(sun.y * 2.5, 0.0, 1.0))
		draw_circle(sp, r * 1.9, Color(warm, 0.18))
		draw_circle(sp, r * 1.35, Color(warm, 0.3))
		draw_circle(sp, r, warm)
	# moon
	if moon.y > -0.1:
		var mp := Vector2(lerpf(span.x, span.y, moon.x), hy + 10.0 - moon.y * arc_h * 0.92)
		_draw_moon(mp, 22.0 * stage_scale)
	# clouds
	var tint := Color(sky.light_tint) * lerpf(0.45, 1.0, float(sky.intensity))
	tint.a = lerpf(0.55, 0.95, float(sky.intensity))
	var shown := int(round(lerpf(2.0, 6.0, cloudiness)))
	for i in mini(shown, _clouds.size()):
		var c: Array = _clouds[i]
		if _cloud_tex.is_empty():
			break
		var tex: Texture2D = _cloud_tex[c[4] % _cloud_tex.size()]
		var w: float = tex.get_width() * c[2] * stage_scale
		var x: float = fposmod(c[0] * (vr.size.x + w) + _t * c[3] * stage_scale, vr.size.x + w) - w
		var y: float = c[1] * (hy - 60.0)
		var col := tint
		if cloudiness > 0.6:
			col = col.lerp(Color(0.55, 0.58, 0.62, col.a), (cloudiness - 0.6) * 1.8)
		draw_texture_rect(tex, Rect2(x, y, w, tex.get_height() * c[2] * stage_scale), false, col)

## The lit part of the disc for the real phase (0 new, 0.25 first quarter, 0.5 full, 0.75 last).
func _draw_moon(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(0.32, 0.36, 0.48, 0.5))
	var p := moon_phase
	if p < 0.01 or p > 0.99:
		return
	var right := p < 0.5          # waxing: lit on the right (northern view)
	if south:
		right = not right         # southern hemisphere sees it mirrored
	var side := 1.0 if right else -1.0
	var k := cos(TAU * p)         # terminator x-radius factor
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var a := -PI / 2.0 + PI * float(i) / n
		pts.append(c + Vector2(side * r * cos(a), r * sin(a)))
	for i in range(n, -1, -1):
		var a := -PI / 2.0 + PI * float(i) / n
		var tx := (k if p < 0.5 else k) * r * cos(a)
		pts.append(c + Vector2(side * tx, r * sin(a)))
	draw_colored_polygon(pts, Color(0.98, 0.96, 0.86))
