extends RefCounted
## Color Sort look pass (2026-11-25): small textures made once in code, drawn with
## draw_texture_rect (cheap on phones; no per-frame circles/arcs, no shaders, no threads).
## glow(): soft round light, tint it for halos, shadows and light pools.
## vignette(): darkens the edges so the vials read first.
## fog(): seamless cloudy noise for the Voodoo skin's drifting mist.

static var _glow: Texture2D
static var _vig: Texture2D
static var _fog: Texture2D

static func glow() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow

static func vignette() -> Texture2D:
	if _vig == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.7)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.45)
		t.fill_to = Vector2(1.05, 1.0)
		t.width = 128
		t.height = 256
		_vig = t
	return _vig

static func fog() -> Texture2D:
	if _fog == null:
		var n := FastNoiseLite.new()
		n.seed = 7
		n.frequency = 0.02
		n.fractal_octaves = 3
		var img: Image = n.get_seamless_image(128, 128)
		img.convert(Image.FORMAT_LA8)
		# brightness -> alpha so it tints cleanly
		for y in 128:
			for x in 128:
				var v: float = img.get_pixel(x, y).r
				img.set_pixel(x, y, Color(1, 1, 1, clampf((v - 0.35) * 1.6, 0.0, 1.0)))
		_fog = ImageTexture.create_from_image(img)
	return _fog

## A soft light centred at c (radius rad), tinted col.
static func light(ci: CanvasItem, c: Vector2, rad: Vector2, col: Color) -> void:
	ci.draw_texture_rect(glow(), Rect2(c - rad, rad * 2.0), false, col)

## Fog drifting sideways across rect r (tiles the seamless texture).
static func drift(ci: CanvasItem, r: Rect2, t: float, speed: float, scale: float, col: Color) -> void:
	var tex := fog()
	var tile: float = 128.0 * scale
	var off: float = fposmod(t * speed, tile)
	var x: float = r.position.x - off
	while x < r.end.x:
		var y: float = r.position.y
		while y < r.end.y:
			ci.draw_texture_rect(tex, Rect2(x, y, tile, tile), false, col)
			y += tile
		x += tile
