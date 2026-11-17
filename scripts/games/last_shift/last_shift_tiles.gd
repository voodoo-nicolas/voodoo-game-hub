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
		"decor": "pipes", "mat": "concrete", "ambient": Color(0.44, 0.46, 0.52), "light": Color(0.95, 0.96, 1.0),
	},
	"locker": {
		"floor": Color("5a6259"), "floor2": Color("636b61"), "grid": Color("4c544c"), "stain": Color("4a4a40"),
		"face": Color("6f7d70"), "face_dark": Color("55625a"), "top": Color("2c322e"), "trim": Color("3a4038"),
		"decor": "tiles", "mat": "ceramic", "ambient": Color(0.52, 0.55, 0.53), "light": Color(1.0, 0.97, 0.88),
	},
	"security": {
		# v0.6: was "3f4552"/"474e5c"; greyer so the colour grade doesn't push it to saturated blue
		"floor": Color("41444b"), "floor2": Color("45484f"), "grid": Color("35373d"), "stain": Color("2c2e33"),
		"face": Color("4c5668"), "face_dark": Color("39414f"), "top": Color("23262e"), "trim": Color("e09a1a"),
		"decor": "panels", "mat": "vinyl", "ambient": Color(0.46, 0.5, 0.58), "light": Color(0.92, 0.95, 1.0),
	},
	"office": {
		# v0.6: was "66607a"/"6d6783" (pastel lilac checkerboard) -> darker, greyer carpet tiles
		"floor": Color("4e4a5c"), "floor2": Color("534f62"), "grid": Color("413e4d"), "stain": Color("3e3548"),
		"face": Color("8a8798"), "face_dark": Color("6e6b7c"), "top": Color("2d2b36"), "trim": Color("6a3fd6"),
		"decor": "posters", "mat": "carpet", "ambient": Color(0.55, 0.53, 0.6), "light": Color(1.0, 0.98, 0.92),
	},
	"lobby": {
		# v0.6: was "797982"/"83838d" (flat grey checkerboard) -> polished stone with veins
		"floor": Color("6c6b72"), "floor2": Color("706f77"), "grid": Color("4f4e57"), "stain": Color("8a8890"),
		"face": Color("6e6a80"), "face_dark": Color("55516a"), "top": Color("2b2a36"), "trim": Color("6a3fd6"),
		"decor": "posters", "mat": "stone", "ambient": Color(0.56, 0.55, 0.62), "light": Color(1.0, 0.96, 0.88),
	},
	# Outdoors: asphalt, and the building's front (concrete, dark glass windows) along the top.
	# The lot's other edges are hedges ('H' in the map).
	"lot": {
		"floor": Color("45474c"), "floor2": Color("4a4c51"), "grid": Color("45474c"), "stain": Color("36383c"),
		"face": Color("a39e94"), "face_dark": Color("7d796f"), "top": Color("34363b"), "trim": Color("5c5850"),
		"decor": "facade", "mat": "asphalt", "ambient": Color(1.0, 1.0, 1.0), "light": Color(1.0, 1.0, 1.0),
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

## v0.6: floors are drawn as a MATERIAL per theme instead of a flat two-tone checkerboard:
## per-pixel grain, a bevelled seam (lit top-left edge, dark bottom-right), material detail
## (aggregate, carpet weave, grout, stone veins, pebbles) and soft-edged stains. Variants 0/1 differ
## only by grain, so the old checker pattern is gone; 2 = crack, 3 = stain (unchanged roles).
static func _floor(img: Image, o: Vector2i, th: Dictionary, v: int, shadow: bool, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 13
	var mat: String = th.get("mat", "concrete")
	var base: Color = (th.floor as Color).lerp(th.floor2, 0.5 if v % 2 == 1 else 0.0)
	var grain: float = {"concrete": 0.055, "ceramic": 0.025, "vinyl": 0.03, "carpet": 0.07,
		"stone": 0.025, "asphalt": 0.08}.get(mat, 0.05)
	for y in TILE:
		for x in TILE:
			var n := rng.randf_range(-1.0, 1.0) * grain
			if mat == "carpet" and (x + y * 2) % 4 == 0:
				n -= 0.05                          # diagonal weave
			img.set_pixel(o.x + x, o.y + y, _shade(base, n))
	match mat:
		"concrete":
			# aggregate specks + a faint trowel swirl
			for i in 22:
				_r(img, o, rng.randi_range(1, TILE - 3), rng.randi_range(1, TILE - 3), rng.randi_range(1, 2), 1,
					_shade(base, rng.randf_range(-0.16, 0.14)))
			_bevel(img, o, base, 0.10, 0.22)
		"ceramic":
			# small 8 px tiles with grout and a glaze highlight
			for t in 4:
				_r(img, o, t * 8, 0, 1, TILE, th.grid)
				_r(img, o, 0, t * 8, TILE, 1, th.grid)
				for u in 4:
					_r(img, o, t * 8 + 1, u * 8 + 1, 3, 1, _shade(base, 0.10))
		"vinyl":
			# speckled institutional vinyl, big panels (seam only)
			for i in 30:
				_r(img, o, rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1), 1, 1,
					[Color("2a2e38"), Color("5b6372"), _shade(base, 0.15)][rng.randi_range(0, 2)])
			_bevel(img, o, base, 0.08, 0.18)
		"carpet":
			# carpet tiles: soft seam, alternating pile direction
			_r(img, o, 0, TILE - 1, TILE, 1, _shade(base, -0.14))
			_r(img, o, TILE - 1, 0, 1, TILE, _shade(base, -0.14))
			if v % 2 == 1:
				for y in range(0, TILE, 3):
					_r(img, o, 0, y, TILE - 1, 1, _shade(base, 0.04))
		"stone":
			# polished stone: thin veins + a diagonal sheen, sharp seam
			var x := rng.randi_range(0, TILE - 1)
			for y in TILE:
				x = clampi(x + rng.randi_range(-1, 1), 0, TILE - 1)
				if rng.randf() < 0.75:
					_r(img, o, x, y, 1, 1, _shade(base, 0.16))
			for i in TILE:
				var sy := TILE - 1 - i
				if sy >= 0 and i < TILE:
					var px := img.get_pixel(o.x + i, o.y + sy)
					img.set_pixel(o.x + i, o.y + sy, _shade(px, 0.06))
			_bevel(img, o, base, 0.14, 0.28)
		"asphalt":
			for i in 40:
				_r(img, o, rng.randi_range(0, TILE - 2), rng.randi_range(0, TILE - 2), 1, 1,
					_shade(base, rng.randf_range(-0.2, 0.22)))
	if v == 2:
		# a crack with a lit lip
		var x := rng.randi_range(6, 14)
		var y := 4
		for i in 12:
			_r(img, o, x, y, 2, 2, base.darkened(0.4))
			_r(img, o, x + 2, y, 1, 2, _shade(base, 0.08))
			x += rng.randi_range(-1, 2)
			y += 2
	elif v == 3:
		# a soft-edged stain (radial falloff instead of two rectangles)
		var c := Vector2(rng.randf_range(12, 20), rng.randf_range(12, 20))
		var rad := rng.randf_range(7.0, 11.0)
		for yy in TILE:
			for xx in TILE:
				var d := Vector2(xx, yy).distance_to(c) / rad
				if d < 1.0:
					var px := img.get_pixel(o.x + xx, o.y + yy)
					img.set_pixel(o.x + xx, o.y + yy, px.lerp(th.stain, 0.4 * (1.0 - d * d)))
	if shadow:
		for y in 13:
			var a := pow((13.0 - y) / 13.0, 1.6) * 0.6
			for x in TILE:
				var px := img.get_pixel(o.x + x, o.y + y)
				img.set_pixel(o.x + x, o.y + y, px.darkened(a))

static func _shade(c: Color, amount: float) -> Color:
	return c.lightened(amount) if amount > 0.0 else c.darkened(-amount)

## Lit top-left edge, dark bottom-right seam: makes each slab read as a slightly raised plate.
static func _bevel(img: Image, o: Vector2i, base: Color, lit: float, dark: float) -> void:
	_r(img, o, 0, 0, TILE, 1, _shade(base, lit))
	_r(img, o, 0, 0, 1, TILE, _shade(base, lit * 0.6))
	_r(img, o, 0, TILE - 1, TILE, 1, _shade(base, -dark))
	_r(img, o, TILE - 1, 0, 1, TILE, _shade(base, -dark))

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
		# top of a wall seen from above. v0.6: textured cap (grain + specks) with a lit rim on the
		# edges that meet open floor, so wall runs read as solid blocks instead of flat dark strips.
		var top: Color = th.top
		for y in TILE:
			for x in TILE:
				img.set_pixel(o.x + x, o.y + y, _shade(top, rng.randf_range(-0.04, 0.04)))
		_speckle(img, o, rng, top, 10)
		if n_open:
			_r(img, o, 0, 2, TILE, 2, top.lightened(0.38))
		if w_open:
			_r(img, o, 2, 0, 2, TILE, top.lightened(0.26))
		if e_open:
			_r(img, o, TILE - 4, 0, 2, TILE, top.darkened(0.25))
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
	# v0.6: smooth vertical light falloff (lit from above) + fine grain, instead of two flat bands
	for y in TILE:
		var k := float(y) / float(TILE - 1)
		var row := _shade(face, 0.16 - 0.40 * k)
		for x in TILE:
			img.set_pixel(o.x + x, o.y + y, _shade(row, rng.randf_range(-0.03, 0.03)))
	_r(img, o, 0, 0, TILE, 2, face.lightened(0.4))          # lit top edge (cap lip)
	_r(img, o, 0, 2, TILE, 2, face.darkened(0.18))           # shadow under the lip
	# panel seams: dark groove with a lit edge beside it
	_r(img, o, 0, 0, 1, TILE, th.face_dark)
	_r(img, o, 1, 4, 1, TILE - 4, face.lightened(0.12))
	_r(img, o, TILE - 1, 0, 1, TILE, th.face_dark)
	# grime creeping up from the floor
	for x in TILE:
		var gh := rng.randi_range(2, 6)
		for y in gh:
			var yy := TILE - 8 - y
			var px := img.get_pixel(o.x + x, o.y + yy)
			img.set_pixel(o.x + x, o.y + yy, px.darkened(0.18 * (1.0 - float(y) / gh)))
	# baseboard / trim stripe with a highlight and a dark kick plate under it
	_r(img, o, 0, TILE - 7, TILE, 5, th.trim.darkened(0.1))
	_r(img, o, 0, TILE - 7, TILE, 1, th.trim.lightened(0.3))
	_r(img, o, 0, TILE - 3, TILE, 1, th.trim.darkened(0.4))
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
