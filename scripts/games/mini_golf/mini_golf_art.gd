extends RefCounted

## Mini Golf art: every texture is generated in code at first use (no image
## files, nothing to licence) and cached. Tiles are seamless; draw them with
## texture_repeat enabled on the canvas item.

static var _cache := {}

static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img: Image
	match id:
		"grass":
			img = _grass()
		"rough":
			img = _speckle(64, Color("2d6a2b"), 0.07, 11, Color("245a22"), 0.10)
		"sand":
			img = _speckle(64, Color("e3c98d"), 0.06, 12, Color("c9a868"), 0.18)
		"brick":
			img = _brick()
		"stone":
			img = _stone()
		"wood":
			img = _wood()
		"water":
			img = _water()
		"sail":
			img = _sail()
		"roof":
			img = _roof()
		"soft":
			img = _disc(64, true)
		_:
			img = _disc(64, false)
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
	return t

## A filled circle (or soft shadow) of radius r, tinted.
static func disc(c: CanvasItem, p: Vector2, r: float, col: Color, soft: bool = false) -> void:
	c.draw_texture_rect(tex("soft" if soft else "disc"), Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

# ---------- generators ----------

static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

static func _jit(c: Color, d: float) -> Color:
	return Color(clampf(c.r + d, 0, 1), clampf(c.g + d, 0, 1), clampf(c.b + d, 0, 1), c.a)

## Mown fairway: 100 px tile, light and dark 50 px bands, blade streaks.
static func _grass() -> Image:
	var n := 100
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := _rng(7)
	var light := Color("5fae45")
	var dark := Color("52a03c")
	for y in n:
		for x in n:
			img.set_pixel(x, y, _jit(light if y < n / 2 else dark, r.randf_range(-0.035, 0.035)))
	for i in 260:
		var x := r.randi() % n
		var y := r.randi() % n
		var d := r.randf_range(-0.09, 0.06)
		for j in 3:
			var yy := (y + j) % n
			img.set_pixel(x, yy, _jit(img.get_pixel(x, yy), d))
	return img

## Noise tile with a few darker clumps.
static func _speckle(n: int, base: Color, amp: float, s: int, clump: Color, clump_k: float) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := _rng(s)
	var fn := FastNoiseLite.new()
	fn.seed = s
	fn.frequency = 0.09
	var low := fn.get_seamless_image(n, n)
	for y in n:
		for x in n:
			var c := base.lerp(clump, low.get_pixel(x, y).r * clump_k * 3.0)
			img.set_pixel(x, y, _jit(c, r.randf_range(-amp, amp)))
	return img

## Red brick in running bond: 64 px tile, bricks 32 x 16.
static func _brick() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var r := _rng(21)
	var shades: Array = []
	for i in 16:
		shades.append(_jit(Color("9c4a32"), r.randf_range(-0.08, 0.06)))
	var mortar := Color("cfc6b4")
	for y in 64:
		var row := y / 16
		var off := (row % 2) * 16
		for x in 64:
			var bx := (x + off) % 32
			var by := y % 16
			var c: Color
			if bx < 2 or by < 2:
				c = _jit(mortar, r.randf_range(-0.05, 0.03))
			else:
				c = shades[(row * 2 + ((x + off) % 64) / 32) % 16]
				if by > 13 or bx > 29:
					c = _jit(c, -0.08)
				elif by < 4:
					c = _jit(c, 0.05)
				c = _jit(c, r.randf_range(-0.04, 0.04))
			img.set_pixel(x, y, c)
	return img

## Grey cobbles from cellular noise.
static func _stone() -> Image:
	var n := 96
	var edge := FastNoiseLite.new()
	edge.seed = 5
	edge.noise_type = FastNoiseLite.TYPE_CELLULAR
	edge.frequency = 0.07
	edge.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var cell := edge.duplicate() as FastNoiseLite
	cell.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var ei := edge.get_seamless_image(n, n)
	var ci := cell.get_seamless_image(n, n)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := _rng(6)
	for y in n:
		for x in n:
			var e := ei.get_pixel(x, y).r
			var v := ci.get_pixel(x, y).r
			var c: Color
			if e < 0.10:
				c = Color("4a4640")
			else:
				c = Color("8d8a82").lerp(Color("b4ae9f"), v)
				if e < 0.18:
					c = _jit(c, -0.10)
				elif e > 0.45:
					c = _jit(c, 0.05)
			img.set_pixel(x, y, _jit(c, r.randf_range(-0.035, 0.035)))
	return img

## Horizontal planks with grain.
static func _wood() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var r := _rng(9)
	for y in 64:
		var plank := y / 16
		var base := _jit(Color("9a6b3c"), [0.0, -0.05, 0.03, -0.02][plank])
		for x in 64:
			var c := base
			if y % 16 == 0:
				c = Color("4a3018")
			else:
				var g := sin((x + plank * 17) * 0.35 + sin(y * 0.9 + plank) * 1.5)
				c = _jit(c, g * 0.035 + r.randf_range(-0.03, 0.03))
				if x == (plank * 23 + 7) % 64 and y % 16 > 3 and y % 16 < 12:
					c = _jit(c, -0.2)   # a nail
			img.set_pixel(x, y, c)
	return img

## Pond water: seamless noise, deep to shallow blue with light caustics.
static func _water() -> Image:
	var n := 128
	var fn := FastNoiseLite.new()
	fn.seed = 3
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fn.frequency = 0.035
	fn.fractal_octaves = 3
	var ni := fn.get_seamless_image(n, n)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var deep := Color("1d5f9e")
	var shallow := Color("3d93c9")
	for y in n:
		for x in n:
			var v := ni.get_pixel(x, y).r
			var c := deep.lerp(shallow, v)
			var band := absf(v - 0.55)
			if band < 0.025:
				c = c.lerp(Color("cdeeff"), 0.6 * (1.0 - band / 0.025))
			img.set_pixel(x, y, c)
	return img

## One windmill sail seen from above: a long wooden stock, then a lattice
## frame with cream cloth. 128 x 32, the hub at x = 0.
static func _sail() -> Image:
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color("6b4423")
	var cloth := Color("efe4c8")
	for x in 128:
		for y in 32:
			var c := Color(0, 0, 0, 0)
			if y >= 14 and y <= 17:
				c = wood
			elif x >= 26 and x <= 125 and y >= 3 and y <= 28:
				var frame := x <= 27 or x >= 124 or y <= 4 or y >= 27
				var lattice := (x - 26) % 14 < 2 or y == 9 or y == 22
				if frame:
					c = wood
				elif lattice:
					c = wood.lightened(0.15)
				else:
					c = cloth.darkened(0.08 * float(x % 14) / 14.0)
			img.set_pixel(x, y, c)
	return img

## The windmill's cap from above: a cone of wooden shingles.
static func _roof() -> Image:
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ctr := Vector2(n, n) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5) - ctr
			var dist := d.length()
			var c := Color(0, 0, 0, 0)
			if dist < 46.0:
				var ring := int(dist / 7.0)
				var seg := int((d.angle() + PI) / TAU * (8 + ring * 4) + ring * 0.5)
				c = Color("7a3b22").lerp(Color("a85a33"), dist / 46.0)
				if seg % 2 == 0:
					c = _jit(c, -0.05)
				if fmod(dist, 7.0) < 1.2:
					c = _jit(c, -0.15)
				if dist > 43.0:
					c = Color("3a2010")
				c.a = clampf(46.0 - dist, 0.0, 1.0)
				# Light from the top left.
				c = _jit(c, -d.normalized().dot(Vector2(0.7, 0.7)) * 0.08 * dist / 46.0)
			if dist < 6.0:
				c = Color("c8c2b0") if dist < 4.5 else Color("4a4640")
			img.set_pixel(x, y, c)
	return img

static func _disc(n: int, soft: bool) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ctr := n / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - ctr, y + 0.5 - ctr).length()
			var a: float
			if soft:
				a = clampf(1.0 - d / ctr, 0.0, 1.0)
				a *= a
			else:
				a = clampf(ctr - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img
