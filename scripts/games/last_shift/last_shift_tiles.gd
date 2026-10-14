extends RefCounted

## Themed tile sets for Last Shift, drawn in code (no image files yet). One TileSet per room
## theme. Look: ink-outlined walls that show their FRONT FACE where a floor is south of them
## (baseboard, panel seams, decorations) and a flat dark TOP everywhere else, floors with
## speckle / cracks / stains and a soft shadow under the wall face. Light from the top-left.
##
## Atlas (32 px tiles):
##   row 0, x 0..3   floor variants            row 0, x 4..7  same, with the wall's shadow on top
##   rows 1..3       walls: x = open-neighbour mask (N=1 E=2 S=4 W=8), row = 1 + decor variant
##   row 4           wall with the employer's logo (x = mask)
##   row 5           hedge (map char 'H', outdoors): x = open-neighbour mask

const TILE := 32
const INK := Color("0e0e12")
const SOURCE_ID := 0

## Theme palettes. ambient = overall room light, light = color of the ceiling lights.
const THEMES := {
	"plant": {
		"floor": Color("4d5057"), "floor2": Color("565961"), "grid": Color("43464c"), "stain": Color("5a3a28"),
		"face": Color("5c6670"), "face_dark": Color("424a54"), "top": Color("2a2d33"), "trim": Color("e09a1a"),
		"decor": "pipes", "ambient": Color(0.44, 0.46, 0.52), "light": Color(0.95, 0.96, 1.0),
	},
	"locker": {
		"floor": Color("5a6259"), "floor2": Color("636b61"), "grid": Color("4c544c"), "stain": Color("4a4a40"),
		"face": Color("6f7d70"), "face_dark": Color("55625a"), "top": Color("2c322e"), "trim": Color("3a4038"),
		"decor": "tiles", "ambient": Color(0.52, 0.55, 0.53), "light": Color(1.0, 0.97, 0.88),
	},
	"security": {
		"floor": Color("3f4552"), "floor2": Color("474e5c"), "grid": Color("363b46"), "stain": Color("2c303a"),
		"face": Color("4c5668"), "face_dark": Color("39414f"), "top": Color("23262e"), "trim": Color("e09a1a"),
		"decor": "panels", "ambient": Color(0.46, 0.5, 0.58), "light": Color(0.92, 0.95, 1.0),
	},
	"office": {
		"floor": Color("66607a"), "floor2": Color("6d6783"), "grid": Color("5b556e"), "stain": Color("4e4560"),
		"face": Color("8a8798"), "face_dark": Color("6e6b7c"), "top": Color("2d2b36"), "trim": Color("6a3fd6"),
		"decor": "posters", "ambient": Color(0.55, 0.53, 0.6), "light": Color(1.0, 0.98, 0.92),
	},
	"lobby": {
		"floor": Color("797982"), "floor2": Color("83838d"), "grid": Color("767680"), "stain": Color("7a7a84"),
		"face": Color("6e6a80"), "face_dark": Color("55516a"), "top": Color("2b2a36"), "trim": Color("6a3fd6"),
		"decor": "posters", "ambient": Color(0.56, 0.55, 0.62), "light": Color(1.0, 0.96, 0.88),
	},
	# Outdoors: asphalt, and the building's front (concrete, dark glass windows) along the top.
	# The lot's other edges are hedges ('H' in the map).
	"lot": {
		"floor": Color("45474c"), "floor2": Color("4a4c51"), "grid": Color("45474c"), "stain": Color("36383c"),
		"face": Color("a39e94"), "face_dark": Color("7d796f"), "top": Color("34363b"), "trim": Color("5c5850"),
		"decor": "facade", "ambient": Color(1.0, 1.0, 1.0), "light": Color(1.0, 1.0, 1.0),
	},
}

static var _cache := {}

static func theme_of(name: String) -> Dictionary:
	return THEMES.get(name, THEMES.plant)

static func floor_coord(variant: int, shadow: bool) -> Vector2i:
	return Vector2i(variant + (4 if shadow else 0), 0)

static func wall_coord(mask: int, variant: int, logo: bool) -> Vector2i:
	return Vector2i(mask, 4 if logo else 1 + variant)

static func hedge_coord(mask: int) -> Vector2i:
	return Vector2i(mask, 5)

static func build(theme_name: String) -> TileSet:
	if _cache.has(theme_name):
		return _cache[theme_name]
	var th := theme_of(theme_name)
	var seed_base: int = theme_name.hash()
	var img := Image.create(TILE * 16, TILE * 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# floors
	for v in 4:
		_floor(img, Vector2i(v * TILE, 0), th, v, false, seed_base + v)
		_floor(img, Vector2i((v + 4) * TILE, 0), th, v, true, seed_base + v)
	# walls
	for mask in 16:
		for variant in 3:
			_wall(img, Vector2i(mask * TILE, (1 + variant) * TILE), th, mask, variant, false, seed_base + mask)
		_wall(img, Vector2i(mask * TILE, 4 * TILE), th, mask, 0, true, seed_base + mask)
		_hedge(img, Vector2i(mask * TILE, 5 * TILE), mask, seed_base + mask * 31)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, SOURCE_ID)
	var half := TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for x in 8:
		source.create_tile(Vector2i(x, 0))
	for y in range(1, 6):
		for x in 16:
			source.create_tile(Vector2i(x, y))
			var td: TileData = source.get_tile_data(Vector2i(x, y), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	_cache[theme_name] = tile_set
	return tile_set

# ---------------------------------------------------------------- image helpers

static func _r(img: Image, o: Vector2i, x: int, y: int, w: int, h: int, col: Color) -> void:
	img.fill_rect(Rect2i(o.x + x, o.y + y, w, h), col)

static func _speckle(img: Image, o: Vector2i, rng: RandomNumberGenerator, base: Color, count: int) -> void:
	for i in count:
		var x := rng.randi_range(1, TILE - 3)
		var y := rng.randi_range(1, TILE - 3)
		var c := base.lightened(0.10) if rng.randf() < 0.5 else base.darkened(0.12)
		_r(img, o, x, y, rng.randi_range(1, 2), 1, c)

# ---------------------------------------------------------------- floors

static func _floor(img: Image, o: Vector2i, th: Dictionary, v: int, shadow: bool, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 13
	var base: Color = th.floor if v % 2 == 0 else th.floor2
	_r(img, o, 0, 0, TILE, TILE, base)
	# tile seams (right and bottom edge)
	_r(img, o, TILE - 1, 0, 1, TILE, th.grid)
	_r(img, o, 0, TILE - 1, TILE, 1, th.grid)
	_speckle(img, o, rng, base, 16)
	if v == 2:
		# a crack
		var x := rng.randi_range(6, 14)
		var y := 4
		for i in 12:
			_r(img, o, x, y, 2, 2, base.darkened(0.35))
			x += rng.randi_range(-1, 2)
			y += 2
	elif v == 3:
		# a stain / puddle
		_r(img, o, 8, 10, 14, 9, base.lerp(th.stain, 0.35))
		_r(img, o, 11, 8, 8, 13, base.lerp(th.stain, 0.35))
	if shadow:
		for y in 11:
			var a := (11.0 - y) / 11.0 * 0.5
			for x in TILE:
				var px := img.get_pixel(o.x + x, o.y + y)
				img.set_pixel(o.x + x, o.y + y, px.darkened(a))

# ---------------------------------------------------------------- walls

static func _wall(img: Image, o: Vector2i, th: Dictionary, mask: int, variant: int, logo: bool, seed_v: int) -> void:
	var n_open := mask & 1 != 0
	var e_open := mask & 2 != 0
	var s_open := mask & 4 != 0
	var w_open := mask & 8 != 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 104729 + 7
	if s_open:
		_face(img, o, th, variant, logo, rng)
	else:
		# flat dark top of a wall seen from above
		_r(img, o, 0, 0, TILE, TILE, th.top)
		_r(img, o, 2, 2, TILE - 4, TILE - 4, th.top.lightened(0.06))
		_speckle(img, o, rng, th.top, 8)
	# ink lines on every side that touches open floor
	if n_open:
		_r(img, o, 0, 0, TILE, 2, INK)
	if e_open:
		_r(img, o, TILE - 2, 0, 2, TILE, INK)
	if w_open:
		_r(img, o, 0, 0, 2, TILE, INK)
	if s_open:
		_r(img, o, 0, TILE - 2, TILE, 2, INK)

## The visible front of a wall: baseboard trim, panel seams, and decoration by theme.
static func _face(img: Image, o: Vector2i, th: Dictionary, variant: int, logo: bool, rng: RandomNumberGenerator) -> void:
	var face: Color = th.face
	_r(img, o, 0, 0, TILE, TILE, face)
	_r(img, o, 0, 0, TILE, 3, face.lightened(0.18))          # lit top edge
	_r(img, o, 0, TILE - 12, TILE, 12, face.darkened(0.12))   # lower half a little darker
	# panel seams
	_r(img, o, 0, 0, 1, TILE, th.face_dark)
	_r(img, o, TILE - 1, 0, 1, TILE, th.face_dark)
	# baseboard / trim stripe
	_r(img, o, 0, TILE - 7, TILE, 5, th.trim.darkened(0.1))
	_r(img, o, 0, TILE - 7, TILE, 1, th.trim.lightened(0.25))
	if th.decor == "pipes":
		# hazard stripes on the baseboard
		for i in 4:
			_r(img, o, 2 + i * 8, TILE - 6, 4, 3, INK)
	_speckle(img, o, rng, face, 10)
	# rust streaks (plant) / grime
	if th.decor == "pipes" and variant != 1:
		var x := rng.randi_range(4, 24)
		_r(img, o, x, 3, 2, rng.randi_range(8, 14), Color("7a4a2a"))
	match variant:
		1:
			_decor(img, o, th, rng, 0)
		2:
			_decor(img, o, th, rng, 1)
	if logo:
		# the employer's logo: white chevron on Ascend purple, plate with ink border
		_r(img, o, 6, 4, 20, 19, INK)
		_r(img, o, 7, 5, 18, 17, Color("6a3fd6"))
		for i in 8:
			_r(img, o, 15 - i, 8 + i * 2, 2, 2, Color("e8e8f0"))
			_r(img, o, 15 + i, 8 + i * 2, 2, 2, Color("e8e8f0"))
		_r(img, o, 11, 18, 10, 2, Color("e8e8f0"))

static func _decor(img: Image, o: Vector2i, th: Dictionary, rng: RandomNumberGenerator, which: int) -> void:
	match th.decor:
		"pipes":
			# a thick metal pipe across the wall, with collar rings (and a red valve wheel)
			_r(img, o, 0, 9, TILE, 8, INK)
			_r(img, o, 0, 10, TILE, 6, Color("8b949e"))
			_r(img, o, 0, 10, TILE, 2, Color("c5ccd3"))
			_r(img, o, 0, 14, TILE, 2, Color("5c6670"))
			_r(img, o, 6, 8, 3, 10, Color("5c6670"))
			_r(img, o, 22, 8, 3, 10, Color("5c6670"))
			if which == 1:
				_r(img, o, 13, 2, 6, 6, INK)
				_r(img, o, 14, 3, 4, 4, Color("b3161c"))
				_r(img, o, 15, 7, 2, 3, Color("5c6670"))
		"posters":
			# a framed poster
			var col := Color("6a3fd6") if which == 0 else Color("e09a1a")
			_r(img, o, 8, 4, 16, 20, INK)
			_r(img, o, 9, 5, 14, 18, Color("e8e8f0"))
			_r(img, o, 11, 7, 10, 7, col)
			_r(img, o, 11, 16, 10, 2, Color("6b6e75"))
			_r(img, o, 11, 19, 7, 2, Color("6b6e75"))
		"panels":
			# a control panel with little lights
			_r(img, o, 6, 5, 20, 14, INK)
			_r(img, o, 7, 6, 18, 12, Color("2c303a"))
			for i in 3:
				_r(img, o, 9 + i * 6, 9, 3, 3, Color("e09a1a") if (i + which) % 2 == 0 else Color("4fbf5a"))
			_r(img, o, 9, 14, 14, 2, Color("6b6e75"))
		"tiles":
			# ceramic tile grid
			for ty in 3:
				for tx in 4:
					_r(img, o, tx * 8, 3 + ty * 7, 7, 1, th.face_dark)
					_r(img, o, tx * 8 + 7, 3 + ty * 7, 1, 7, th.face_dark)
			if which == 1:
				_r(img, o, 12, 6, 8, 10, INK)
				_r(img, o, 13, 7, 6, 8, Color("c9ccd3"))   # a mirror
		"facade":
			# the office building's windows: dark glass with a warm streak of reflected sky
			_r(img, o, 3, 4, 26, 18, INK)
			_r(img, o, 4, 5, 24, 16, Color("2a3442"))
			for i in 9:
				_r(img, o, 6 + i * 2, 18 - i * 1, 2, 2, Color("2a3442").lerp(Color(0.95, 0.72, 0.5), 0.5))
			_r(img, o, 15, 5, 2, 16, INK)                       # mullion
			if which == 1:
				for y in range(6, 20, 3):
					_r(img, o, 4, y, 24, 1, Color("4a5466"))     # blinds
			_r(img, o, 3, 22, 26, 2, th.face.lightened(0.2))    # sill

# ---------------------------------------------------------------- hedges (outdoors)

## A trimmed hedge seen from above: leafy top, a darker leafy front where it faces floor to the
## south, ink lines where it meets the ground.
static func _hedge(img: Image, o: Vector2i, mask: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7727 + 3
	var base := Color("2f5a2a")
	_r(img, o, 0, 0, TILE, TILE, base)
	for i in 26:
		var x := rng.randi_range(0, TILE - 5)
		var y := rng.randi_range(0, TILE - 5)
		var c: Color = [Color("3f7a35"), Color("4f8f40"), Color("244a20"), Color("386e30")][rng.randi_range(0, 3)]
		_r(img, o, x, y, rng.randi_range(3, 5), rng.randi_range(2, 4), c)
	for i in 6:
		_r(img, o, rng.randi_range(1, TILE - 3), rng.randi_range(1, TILE - 3), 2, 1, Color("6aa84f"))
	if mask & 4 != 0:
		# front face: darker leaves with vertical texture, a strip of soil at the foot
		_r(img, o, 0, TILE - 11, TILE, 11, Color("234620"))
		for i in 10:
			var x := rng.randi_range(0, TILE - 2)
			_r(img, o, x, TILE - 10 + rng.randi_range(0, 3), 2, rng.randi_range(3, 6), Color("2f5a2a"))
		_r(img, o, 0, TILE - 4, TILE, 2, Color("3a2e22"))
	if mask & 1 != 0:
		_r(img, o, 0, 0, TILE, 2, INK)
	if mask & 2 != 0:
		_r(img, o, TILE - 2, 0, 2, TILE, INK)
	if mask & 8 != 0:
		_r(img, o, 0, 0, 2, TILE, INK)
	if mask & 4 != 0:
		_r(img, o, 0, TILE - 2, TILE, 2, INK)
