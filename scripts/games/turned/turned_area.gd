extends RefCounted

## One map of Turned as plain data plus geometry queries, no Nodes: the two-floor house
## ("house" upstairs, "house_down" ground floor), and Vellmoor's Residential Quarter street with its alley (Day 1). The world draws it
## (turned_area_view.gd) and moves things through it; tools/test_turned.gd checks it headless.
## Units are pixels, 1 m = 32 px (tuning world.pixels_per_meter). y grows downward.
##
## shades: where the sun cannot reach: {"rect": Rect2 | "circle": Vector2 + "r", "style": ...}.
## A whole indoor area is shade. Evaluated at the player's feet.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const NPC_DATA := "res://scripts/games/turned/turned_npcs.json"

var id := ""
var indoor := false
var bounds := Rect2()                  # what the camera and the player stay inside
var solids: Array = []                 # Rect2, things you cannot walk through
var shades: Array = []                 # see above
var deco: Array = []                   # ground drawing: {"t": kind, ...}
var props: Array = []                  # y-sorted things: {"kind", "pos", ...}
var lamps: Array = []                  # Vector2 (a warm light each)
var interacts: Array = []              # {"id", "pos", "r", "verb"}
var triggers: Array = []               # {"id", "rect"}
var npcs: Array = []                   # dictionaries from turned_npcs.json
var spawns := {}                       # name -> Vector2
var light_spots: Array = []            # extra {"pos", "color", "energy", "radius"} (windows)

static func make(area_id: String) -> RefCounted:
	var a: RefCounted = load("res://scripts/games/turned/turned_area.gd").new()
	a.id = area_id
	if area_id == "street":
		a._build_street()
	elif area_id == "house_down":
		a._build_house_down()
	elif area_id == "bar":
		a._build_bar()
	elif area_id == "harbor":
		a._build_harbor()
	elif area_id == "cigar_shop":
		a._build_cigar_shop()
	else:
		a._build_house()
	return a

# ---------------------------------------------------------------- queries

func in_shade(p: Vector2) -> bool:
	if indoor:
		return true
	for s in shades:
		if s.has("rect"):
			if (s["rect"] as Rect2).has_point(p):
				return true
		elif p.distance_to(s["circle"]) <= float(s["r"]):
			return true
	return false

static func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var q := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return c.distance_squared_to(q) < r * r

func is_free(center: Vector2, radius: float) -> bool:
	if not bounds.grow(-radius).has_point(center):
		return false
	for s in solids:
		if _circle_hits_rect(center, radius, s):
			return false
	return true

## Moves a circle by `motion`, sliding along walls (x first, then y).
func move_circle(from: Vector2, motion: Vector2, radius: float) -> Vector2:
	var p := from
	var tx := Vector2(from.x + motion.x, from.y)
	if is_free(tx, radius):
		p = tx
	var ty := Vector2(p.x, from.y + motion.y)
	if is_free(ty, radius):
		p = ty
	return p

## The closest free shaded point to `from` within `max_r` px (null if none). First tries points
## with a little shade around them (so the player is not left on a shade's edge).
func nearest_shade(from: Vector2, max_r: float, radius: float, step: float) -> Variant:
	for margin in [10.0, 0.0]:
		var p: Variant = _ring_search(from, max_r, radius, step, margin)
		if p != null:
			return p
	return null

func _ring_search(from: Vector2, max_r: float, radius: float, step: float, margin: float) -> Variant:
	if _shade_ok(from, radius, margin):
		return from
	var r := step
	while r <= max_r:
		var n := maxi(8, int(TAU * r / step))
		var best: Variant = null
		var best_d := INF
		for i in n:
			var a := TAU * float(i) / float(n)
			var p := from + Vector2(cos(a), sin(a)) * r
			if _shade_ok(p, radius, margin) and p.distance_to(from) < best_d:
				best = p
				best_d = p.distance_to(from)
		if best != null:
			return best
		r += step
	return null

func _shade_ok(p: Vector2, radius: float, margin: float) -> bool:
	if not is_free(p, radius) or not in_shade(p):
		return false
	if margin > 0.0:
		for off in [Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin)]:
			if not in_shade(p + off):
				return false
	return true

func trigger_at(p: Vector2) -> String:
	for t in triggers:
		if (t["rect"] as Rect2).has_point(p):
			return str(t["id"])
	return ""

# ---------------------------------------------------------------- the house
# Two floors, both 560 px wide. "house" is upstairs (bedroom, bathroom, landing, study), "house_down" the
# ground floor (parlour, kitchen, entrance hall with the front door and the locked cellar door). The
# stairs are the same block (x 496..544, y 320..400) on both floors, so you arrive where you left.

## A wall: solid and drawn.
func _wall(r: Rect2) -> void:
	solids.append(r)
	deco.append({"t": "wall", "rect": r})

## A piece of furniture: drawn (kind, see turned_area_view.gd _furniture) and solid.
func _furn(kind: String, r: Rect2) -> void:
	solids.append(r)
	deco.append({"t": "furniture", "kind": kind, "rect": r})

func _build_house() -> void:
	indoor = true
	bounds = Rect2(0, 0, 560, 576)
	solids = []
	deco = [
		{"t": "floor", "rect": Rect2(16, 16, 528, 544), "color": Color("36333f"), "plank": true},   # under the doorways too
		{"t": "floor", "rect": Rect2(16, 16, 320, 288), "color": Color("3b3a4a"), "plank": true},   # bedroom
		{"t": "floor", "rect": Rect2(352, 16, 192, 288), "color": Color("4a5560"), "tile": true},   # bathroom
		{"t": "floor", "rect": Rect2(16, 320, 528, 80), "color": Color("36333f"), "plank": true},   # landing
		{"t": "floor", "rect": Rect2(16, 416, 528, 144), "color": Color("2f2c38"), "plank": true},  # study
		{"t": "rug", "rect": Rect2(130, 120, 130, 90), "color": Color("5a2b3b")},
		{"t": "rug", "rect": Rect2(220, 336, 160, 48), "color": Color("3b4a5e")},
		{"t": "rug", "rect": Rect2(430, 206, 50, 44), "color": Color("3b5a5e")},                   # bath mat
		{"t": "rug", "rect": Rect2(360, 436, 150, 96), "color": Color("3a4a3e")},                  # study
	]
	# outer walls, the bedroom/bathroom wall, the landing's walls with their doorways
	for r in [Rect2(0, 0, 560, 16), Rect2(0, 0, 16, 576), Rect2(0, 560, 560, 16), Rect2(544, 0, 16, 576),
			Rect2(336, 16, 16, 288),
			Rect2(16, 304, 104, 16), Rect2(200, 304, 200, 16), Rect2(472, 304, 72, 16),
			Rect2(16, 400, 184, 16), Rect2(280, 400, 264, 16)]:
		_wall(r)
	deco.append({"t": "window", "rect": Rect2(196, 0, 64, 16)})
	deco.append({"t": "window", "rect": Rect2(486, 0, 48, 16)})
	deco.append({"t": "mirror", "rect": Rect2(420, 16, 48, 6)})
	deco.append({"t": "picture", "rect": Rect2(140, 16, 44, 6)})
	deco.append({"t": "picture", "rect": Rect2(56, 320, 36, 5)})
	deco.append({"t": "picture", "rect": Rect2(240, 320, 52, 5)})
	solids.append(Rect2(496, 320, 48, 80))
	deco.append({"t": "stairs", "rect": Rect2(496, 320, 48, 80), "dir": "down"})
	# bedroom
	solids.append(Rect2(28, 28, 64, 128))
	deco.append({"t": "bed", "rect": Rect2(28, 28, 64, 128)})
	_furn("nightstand", Rect2(96, 24, 30, 28))
	_furn("chair", Rect2(224, 28, 34, 30))        # with the coat
	_furn("dresser", Rect2(150, 252, 110, 40))
	_furn("wardrobe", Rect2(276, 20, 56, 40))
	_furn("candlestand", Rect2(296, 250, 20, 20))
	# bathroom
	_furn("toilet", Rect2(360, 22, 34, 42))
	_furn("sink", Rect2(412, 22, 64, 24))
	_furn("cabinet", Rect2(356, 70, 30, 40))
	_furn("washstand", Rect2(356, 122, 30, 48))
	_furn("bath", Rect2(486, 160, 52, 134))
	_furn("towelrail", Rect2(526, 56, 14, 70))
	_furn("stool", Rect2(364, 250, 30, 40))
	# landing
	_furn("plant", Rect2(26, 338, 30, 30))
	_furn("clock", Rect2(396, 366, 28, 32))
	# study
	_furn("desk", Rect2(40, 430, 100, 42))
	_furn("chair", Rect2(76, 476, 30, 26))
	_furn("bookshelf", Rect2(30, 530, 180, 28))
	_furn("bookshelf", Rect2(330, 530, 190, 28))
	_furn("globe", Rect2(318, 440, 28, 28))
	_furn("armchair", Rect2(440, 446, 44, 44))
	_furn("floorlamp", Rect2(492, 440, 16, 16))
	deco.append_array([
		{"t": "item", "kind": "coat", "pos": Vector2(241, 44)},
		{"t": "item", "kind": "matches", "pos": Vector2(111, 38)},
		{"t": "item", "kind": "calendar", "pos": Vector2(327, 120)},
		{"t": "item", "kind": "towel", "pos": Vector2(533, 72)},
	])
	interacts = [
		{"id": "coat", "pos": Vector2(241, 72), "r": 34.0, "verb": "look"},
		{"id": "matches", "pos": Vector2(111, 64), "r": 30.0, "verb": "take"},
		{"id": "calendar", "pos": Vector2(312, 124), "r": 30.0, "verb": "look"},
		{"id": "wardrobe", "pos": Vector2(304, 74), "r": 30.0, "verb": "look"},
		{"id": "mirror", "pos": Vector2(444, 62), "r": 36.0, "verb": "look"},
		{"id": "toilet", "pos": Vector2(404, 68), "r": 26.0, "verb": "look"},
		{"id": "cabinet", "pos": Vector2(402, 96), "r": 24.0, "verb": "look"},
		{"id": "washstand", "pos": Vector2(402, 148), "r": 26.0, "verb": "look"},
		{"id": "bath", "pos": Vector2(466, 200), "r": 24.0, "verb": "look"},
		{"id": "towel", "pos": Vector2(506, 92), "r": 32.0, "verb": "look"},
		{"id": "portrait", "pos": Vector2(74, 346), "r": 30.0, "verb": "look"},
		{"id": "clock", "pos": Vector2(410, 348), "r": 28.0, "verb": "look"},
		{"id": "stairs_down", "pos": Vector2(476, 360), "r": 30.0, "verb": "down"},
		{"id": "desk", "pos": Vector2(154, 452), "r": 32.0, "verb": "look"},
		{"id": "bookshelf", "pos": Vector2(150, 514), "r": 30.0, "verb": "look"},
		{"id": "globe", "pos": Vector2(332, 484), "r": 28.0, "verb": "look"},
	]
	lamps = []
	# the windows' cold morning light, a candle-warm landing lamp, the study lamp
	light_spots = [
		{"pos": Vector2(228, 90), "color": Color("9db8ff"), "energy": 0.85, "radius": 120.0},
		{"pos": Vector2(300, 360), "color": Color("ffb45a"), "energy": 0.7, "radius": 120.0},
		{"pos": Vector2(444, 100), "color": Color("b8c8ff"), "energy": 0.55, "radius": 90.0},
		{"pos": Vector2(120, 50), "color": Color("ffb45a"), "energy": 0.8, "radius": 80.0},
		{"pos": Vector2(510, 70), "color": Color("9db8ff"), "energy": 0.5, "radius": 80.0},
		{"pos": Vector2(300, 490), "color": Color("ffb45a"), "energy": 0.55, "radius": 130.0},
		{"pos": Vector2(500, 470), "color": Color("ffb45a"), "energy": 0.7, "radius": 90.0},
	]
	spawns = {
		"bed": Vector2(60, 92),
		"bedside": Vector2(110, 100),
		"from_down": Vector2(472, 360),
	}

func _build_house_down() -> void:
	indoor = true
	bounds = Rect2(0, 0, 560, 416)
	solids = []
	deco = [
		{"t": "floor", "rect": Rect2(16, 16, 528, 384), "color": Color("3a3330"), "plank": true},
		{"t": "floor", "rect": Rect2(16, 16, 320, 288), "color": Color("40342f"), "plank": true},   # parlour
		{"t": "floor", "rect": Rect2(352, 16, 192, 288), "color": Color("4a4a52"), "slab": true},   # kitchen
		{"t": "floor", "rect": Rect2(16, 320, 528, 80), "color": Color("36333f"), "plank": true},   # entrance hall
		{"t": "rug", "rect": Rect2(80, 100, 190, 114), "color": Color("4a2f3f")},
		{"t": "rug", "rect": Rect2(110, 336, 280, 48), "color": Color("3b4a5e")},
	]
	for r in [Rect2(0, 0, 560, 16), Rect2(0, 0, 16, 416), Rect2(0, 400, 560, 16), Rect2(544, 0, 16, 416),
			Rect2(336, 16, 16, 288),
			Rect2(16, 304, 104, 16), Rect2(200, 304, 200, 16), Rect2(472, 304, 72, 16)]:
		_wall(r)
	deco.append({"t": "window", "rect": Rect2(30, 0, 64, 16)})
	deco.append({"t": "front_door", "rect": Rect2(0, 336, 16, 48), "flip": true})
	deco.append({"t": "cellar_door", "rect": Rect2(250, 400, 36, 16)})
	deco.append({"t": "picture", "rect": Rect2(330, 320, 54, 5)})
	solids.append(Rect2(496, 320, 48, 80))
	deco.append({"t": "stairs", "rect": Rect2(496, 320, 48, 80), "dir": "up"})
	# parlour
	_furn("fireplace", Rect2(120, 16, 80, 30))
	_furn("sofa", Rect2(112, 138, 96, 40))
	_furn("armchair", Rect2(40, 120, 40, 44))
	_furn("armchair", Rect2(240, 120, 40, 44))
	_furn("piano", Rect2(22, 196, 48, 84))
	_furn("stool", Rect2(78, 224, 22, 22))
	_furn("bookshelf", Rect2(232, 18, 90, 28))
	_furn("table", Rect2(262, 226, 30, 30))
	# kitchen
	_furn("stove", Rect2(360, 22, 60, 40))
	_furn("basin", Rect2(440, 22, 52, 26))
	_furn("shelves", Rect2(524, 66, 16, 120))
	_furn("table", Rect2(388, 126, 80, 52))
	_furn("chair", Rect2(360, 138, 22, 24))
	_furn("chair", Rect2(474, 138, 22, 24))
	_furn("cupboard", Rect2(360, 250, 56, 44))
	# entrance hall
	_furn("coatstand", Rect2(70, 321, 20, 18))
	_furn("console", Rect2(150, 370, 60, 24))
	_furn("clock", Rect2(396, 366, 28, 32))
	deco.append({"t": "item", "kind": "scarf", "pos": Vector2(80, 326)})
	interacts = [
		{"id": "fireplace", "pos": Vector2(160, 66), "r": 30.0, "verb": "look"},
		{"id": "piano", "pos": Vector2(92, 190), "r": 30.0, "verb": "look"},
		{"id": "parlour_books", "pos": Vector2(277, 62), "r": 30.0, "verb": "look"},
		{"id": "stove", "pos": Vector2(390, 78), "r": 28.0, "verb": "look"},
		{"id": "table", "pos": Vector2(428, 200), "r": 32.0, "verb": "look"},
		{"id": "pantry", "pos": Vector2(446, 270), "r": 30.0, "verb": "look"},
		{"id": "shelves", "pos": Vector2(500, 122), "r": 26.0, "verb": "look"},
		{"id": "scarf", "pos": Vector2(80, 350), "r": 34.0, "verb": "take"},
		{"id": "front_door", "pos": Vector2(26, 360), "r": 32.0, "verb": "door"},
		{"id": "clock", "pos": Vector2(410, 348), "r": 28.0, "verb": "look"},
		{"id": "cellar_door", "pos": Vector2(268, 384), "r": 32.0, "verb": "door"},
		{"id": "stairs_up", "pos": Vector2(476, 360), "r": 30.0, "verb": "up"},
	]
	lamps = []
	light_spots = [
		{"pos": Vector2(62, 70), "color": Color("9db8ff"), "energy": 0.6, "radius": 100.0},
		{"pos": Vector2(160, 74), "color": Color("ff9a4a"), "energy": 0.8, "radius": 110.0},
		{"pos": Vector2(390, 62), "color": Color("ff9a4a"), "energy": 0.45, "radius": 80.0},
		{"pos": Vector2(300, 360), "color": Color("ffb45a"), "energy": 0.7, "radius": 120.0},
		{"pos": Vector2(446, 160), "color": Color("b8c8ff"), "energy": 0.4, "radius": 110.0},
	]
	spawns = {
		"from_street": Vector2(44, 360),
		"from_up": Vector2(472, 360),
	}

# ---------------------------------------------------------------- The Crooked Lantern (the bar)
# One room, 640 x 400: the counter along the north wall with the keeper behind it, three tables, a
# fireplace, the street door in the south wall. Placeholder name and layout (docs/turned/DECISIONS.md).

func _build_bar() -> void:
	indoor = true
	bounds = Rect2(0, 0, 640, 416)
	solids = []
	deco = [
		{"t": "floor", "rect": Rect2(16, 16, 608, 384), "color": Color("2f2a2c"), "plank": true},
		{"t": "rug", "rect": Rect2(250, 250, 140, 100), "color": Color("4a2f2f")},
	]
	for r in [Rect2(0, 0, 640, 16), Rect2(0, 0, 16, 416), Rect2(0, 400, 296, 16), Rect2(344, 400, 296, 16), Rect2(624, 0, 16, 416)]:
		_wall(r)
	deco.append({"t": "window", "rect": Rect2(520, 0, 64, 16)})
	deco.append({"t": "window", "rect": Rect2(60, 0, 64, 16)})
	deco.append({"t": "bar_door", "rect": Rect2(296, 400, 48, 16)})
	deco.append({"t": "picture", "rect": Rect2(16, 220, 5, 50)})
	# behind the counter: shelves; the counter; the fireplace
	_furn("shelves", Rect2(190, 18, 260, 24))
	_furn("counter", Rect2(180, 78, 280, 30))
	_furn("fireplace", Rect2(520, 16, 80, 30))
	# tables with chairs
	_furn("table", Rect2(70, 180, 70, 46))
	_furn("chair", Rect2(46, 190, 20, 24))
	_furn("chair", Rect2(144, 190, 20, 24))
	_furn("table", Rect2(460, 190, 70, 46))
	_furn("chair", Rect2(436, 200, 20, 24))
	_furn("chair", Rect2(534, 200, 20, 24))
	_furn("table", Rect2(120, 290, 70, 46))
	_furn("chair", Rect2(96, 300, 20, 24))
	_furn("table", Rect2(450, 300, 70, 46))
	_furn("chair", Rect2(426, 310, 20, 24))
	_furn("chair", Rect2(524, 310, 20, 24))
	interacts = [
		{"id": "bar_exit", "pos": Vector2(320, 380), "r": 34.0, "verb": "door"},
	]
	lamps = []
	light_spots = [
		{"pos": Vector2(320, 150), "color": Color("ffb45a"), "energy": 1.1, "radius": 230.0},
		{"pos": Vector2(320, 40), "color": Color("ffc880"), "energy": 0.8, "radius": 150.0},
		{"pos": Vector2(560, 60), "color": Color("ff8a3a"), "energy": 1.0, "radius": 130.0},
		{"pos": Vector2(120, 250), "color": Color("ffb45a"), "energy": 0.8, "radius": 140.0},
		{"pos": Vector2(490, 290), "color": Color("ffb45a"), "energy": 0.8, "radius": 140.0},
		{"pos": Vector2(320, 340), "color": Color("ffb45a"), "energy": 0.6, "radius": 120.0},
	]
	spawns = {"from_street": Vector2(320, 360)}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NPC_DATA))
	if typeof(parsed) == TYPE_DICTIONARY:
		npcs = (parsed.get("bar_npcs", []) as Array).duplicate(true)

# ---------------------------------------------------------------- Vellmoor Harbor (scene 4)
# One long night street along the quay: warehouses on the north side, gas lamps every 240 px, the water
# to the south, the cigar shop at the east end. Placeholder layout (docs/turned/DECISIONS.md).

func _build_harbor() -> void:
	indoor = false
	bounds = Rect2(0, -200, 1700, 580)
	solids = [
		Rect2(0, -200, 1700, 350),            # the warehouses
		Rect2(0, 368, 1700, 12),              # the quay's edge
		Rect2(-20, -200, 20, 580), Rect2(1700, -200, 20, 580),
	]
	for x in [120, 360, 600, 840, 1080, 1320]:
		solids.append(Rect2(x - 4, 202, 8, 8))
		lamps.append(Vector2(x, 198))
		props.append({"kind": "lamp", "pos": Vector2(x, 208)})
	for c in [Vector2(520, 346), Vector2(1190, 344)]:
		solids.append(Rect2(c.x - 13, c.y - 13, 26, 26))
		props.append({"kind": "crate", "pos": c, "size": Vector2(26, 26)})
	for b in [Vector2(930, 348), Vector2(280, 350), Vector2(1440, 349)]:
		solids.append(Rect2(b.x - 9, b.y - 9, 18, 18))
		props.append({"kind": "barrel", "pos": b, "r": 9.0})
	shades = [
		{"rect": Rect2(1370, 150, 220, 44), "style": "awning", "c1": Color("5a3a2a"), "c2": Color("d4c8a4")},
	]
	deco = [
		{"t": "floor", "rect": Rect2(0, 215, 1700, 115), "color": Color("464a58"), "cobble": true},
		{"t": "floor", "rect": Rect2(0, 150, 1700, 65), "color": Color("525867"), "slab": true},
		{"t": "floor", "rect": Rect2(0, 330, 1700, 40), "color": Color("4a3d33"), "plank": true},
		{"t": "water", "rect": Rect2(0, 370, 1700, 210)},
		{"t": "building", "rect": Rect2(0, -200, 420, 350), "wall": Color("5a5560"), "roof": Color("2c3040")},
		{"t": "building", "rect": Rect2(420, -200, 360, 350), "wall": Color("63564e"), "roof": Color("34303c")},
		{"t": "building", "rect": Rect2(780, -200, 300, 350), "wall": Color("4f5a5e"), "roof": Color("2c3646")},
		{"t": "building", "rect": Rect2(1080, -200, 280, 350), "wall": Color("5e4e50"), "roof": Color("303240")},
		{"t": "building", "rect": Rect2(1360, -200, 260, 350), "wall": Color("6a5a4e"), "roof": Color("2e3040")},
		{"t": "building", "rect": Rect2(1620, -200, 80, 350), "wall": Color("52505a"), "roof": Color("2a2e3c")},
		{"t": "window_row", "rect": Rect2(24, 86, 360, 34), "lit": false},
		{"t": "window_row", "rect": Rect2(444, 86, 300, 34), "lit": false},
		{"t": "window_row", "rect": Rect2(800, 86, 240, 34), "lit": false},
		{"t": "window_row", "rect": Rect2(1100, 86, 240, 34), "lit": false},
		{"t": "shop_front", "rect": Rect2(1370, 80, 220, 70), "name": "cigars"},
		{"t": "fence", "rect": Rect2(0, 362, 1700, 8)},
	]
	interacts = [
		{"id": "cigar_door", "pos": Vector2(1521, 156), "r": 30.0, "verb": "enter"},
	]
	triggers = [
		{"id": "sense1", "rect": Rect2(300, 150, 40, 230)},
		{"id": "sense2", "rect": Rect2(680, 150, 40, 230)},
		{"id": "sense3", "rect": Rect2(1020, 150, 40, 230)},
		{"id": "sense4", "rect": Rect2(1290, 150, 40, 230)},
	]
	light_spots = []
	spawns = {"from_city": Vector2(60, 250), "from_shop": Vector2(1521, 188)}
	npcs = []

# ---------------------------------------------------------------- the cigar shop (scene 5)
# 560 x 416: the storeroom at the back (north) with its drying racks and a cot, a wall with a doorway,
# the shop in front with the counter, a display table and the street door in the south wall.

func _build_cigar_shop() -> void:
	indoor = true
	bounds = Rect2(0, 0, 560, 416)
	solids = []
	deco = [
		{"t": "floor", "rect": Rect2(16, 16, 528, 384), "color": Color("3a3028"), "plank": true},
		{"t": "floor", "rect": Rect2(16, 16, 528, 150), "color": Color("2f2a26"), "slab": true},     # the storeroom
		{"t": "rug", "rect": Rect2(200, 240, 160, 110), "color": Color("4a2f2a")},
	]
	for r in [Rect2(0, 0, 560, 16), Rect2(0, 0, 16, 416), Rect2(0, 400, 248, 16), Rect2(312, 400, 248, 16), Rect2(544, 0, 16, 416),
			Rect2(16, 166, 224, 16), Rect2(320, 166, 224, 16)]:
		_wall(r)
	deco.append({"t": "bar_door", "rect": Rect2(248, 400, 64, 16)})
	deco.append({"t": "window", "rect": Rect2(60, 400, 64, 16)})
	deco.append({"t": "window", "rect": Rect2(440, 400, 64, 16)})
	# storeroom: tobacco drying on racks, a cot
	_furn("rack", Rect2(36, 30, 200, 36))
	_furn("rack", Rect2(320, 30, 200, 36))
	_furn("rack", Rect2(36, 86, 150, 36))
	_furn("sofa", Rect2(396, 96, 100, 40))
	_furn("chair", Rect2(330, 112, 24, 26))
	# shop: shelves of cigar boxes, the counter, a display table, a chair
	_furn("shelves", Rect2(30, 186, 190, 24))
	_furn("shelves", Rect2(340, 186, 190, 24))
	_furn("counter", Rect2(60, 262, 190, 30))
	_furn("table", Rect2(410, 280, 90, 46))
	_furn("chair", Rect2(380, 292, 22, 24))
	_furn("cupboard", Rect2(40, 340, 56, 44))
	interacts = [
		{"id": "cigar_exit", "pos": Vector2(280, 382), "r": 34.0, "verb": "door"},
	]
	lamps = []
	light_spots = [
		{"pos": Vector2(155, 240), "color": Color("ffb45a"), "energy": 1.0, "radius": 190.0},
		{"pos": Vector2(440, 300), "color": Color("ffb45a"), "energy": 0.8, "radius": 150.0},
		{"pos": Vector2(280, 110), "color": Color("ff9a4a"), "energy": 0.8, "radius": 170.0},
		{"pos": Vector2(280, 360), "color": Color("ffb45a"), "energy": 0.5, "radius": 110.0},
	]
	spawns = {"from_harbor": Vector2(280, 366), "storeroom": Vector2(400, 150)}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NPC_DATA))
	if typeof(parsed) == TYPE_DICTIONARY:
		npcs = (parsed.get("shop_npcs", []) as Array).duplicate(true)

# ---------------------------------------------------------------- the street

func _build_street() -> void:
	indoor = false
	bounds = Rect2(0, -300, 1920, 700)
	solids = [
		Rect2(0, -300, 696, 450),             # the north row of buildings, west of the side lane
		Rect2(744, -300, 996, 450),           # ... between the side lane and the alley
		Rect2(696, -320, 48, 20),             # the side lane's dead end
		Rect2(1830, -300, 90, 450),           # ... and east of it
		Rect2(1740, -320, 90, 20),            # the alley's dead end
		Rect2(0, 388, 1920, 10),              # iron fence along the south gardens
		Rect2(-20, -300, 20, 700), Rect2(1920, -300, 20, 700),
		# iron railings before two houses
		Rect2(30, 146, 120, 8), Rect2(290, 146, 150, 8),
		# the baker's stall counter and the carriage
		Rect2(780, 334, 112, 24), Rect2(1292, 238, 118, 54), Rect2(1238, 252, 50, 28),
		# crates, barrels
		Rect2(1700, 160, 24, 24), Rect2(1840, 170, 18, 18), Rect2(1752, 40, 26, 26), Rect2(1806, -60, 20, 20),
	]
	# gas lamp posts along the north kerb, tree trunks on the south pavement
	for x in [100, 400, 700, 1000, 1300, 1600]:
		solids.append(Rect2(x - 4, 202, 8, 8))
		lamps.append(Vector2(x, 198))
		props.append({"kind": "lamp", "pos": Vector2(x, 208)})
	for t in [Vector2(980, 352), Vector2(1600, 352), Vector2(60, 360), Vector2(1870, 358)]:
		solids.append(Rect2(t.x - 6, t.y - 6, 12, 12))
		props.append({"kind": "tree", "pos": t, "r": 56.0 if t.x < 1500 else 50.0})
	lamps.append(Vector2(1785, -120))
	solids.append(Rect2(1781, -124, 8, 8))
	props.append({"kind": "lamp", "pos": Vector2(1785, -116), "dim": true})
	props.append({"kind": "stall", "pos": Vector2(836, 346)})
	props.append({"kind": "carriage", "pos": Vector2(1350, 292)})
	props.append({"kind": "crate", "pos": Vector2(1712, 172), "size": Vector2(24, 24)})
	props.append({"kind": "crate", "pos": Vector2(1765, 53), "size": Vector2(26, 26)})
	props.append({"kind": "barrel", "pos": Vector2(1849, 179), "r": 9.0})
	props.append({"kind": "barrel", "pos": Vector2(1816, -50), "r": 10.0})

	shades = [
		{"rect": Rect2(190, 150, 84, 46), "style": "porch"},
		{"rect": Rect2(440, 150, 260, 48), "style": "awning", "c1": Color("7a2f3a"), "c2": Color("d9cdb4")},
		{"rect": Rect2(1170, 150, 180, 44), "style": "awning", "c1": Color("2f5a52"), "c2": Color("d9cdb4")},
		{"rect": Rect2(930, 150, 200, 44), "style": "awning", "c1": Color("2a3a2e"), "c2": Color("c9bd9c")},
		{"rect": Rect2(766, 330, 140, 62), "style": "awning", "c1": Color("8a6a2a"), "c2": Color("e8dcb8")},
		{"circle": Vector2(980, 345), "r": 58.0, "style": "tree"},
		{"circle": Vector2(1600, 345), "r": 52.0, "style": "tree"},
		{"circle": Vector2(60, 353), "r": 46.0, "style": "tree"},
		{"circle": Vector2(1870, 351), "r": 44.0, "style": "tree"},
		{"rect": Rect2(1740, -300, 90, 440), "style": "alley"},
		{"rect": Rect2(696, -300, 48, 440), "style": "alley"},
	]
	deco = [
		{"t": "floor", "rect": Rect2(0, 215, 1920, 115), "color": Color("4b4f5c"), "cobble": true},
		{"t": "floor", "rect": Rect2(0, 150, 1920, 65), "color": Color("565d6c"), "slab": true},
		{"t": "floor", "rect": Rect2(0, 330, 1920, 60), "color": Color("535a68"), "slab": true},
		{"t": "floor", "rect": Rect2(0, 388, 1920, 60), "color": Color("27332f"), "grass": true},
		{"t": "floor", "rect": Rect2(1740, -300, 90, 450), "color": Color("3a3d49"), "cobble": true},
		{"t": "floor", "rect": Rect2(696, -300, 48, 450), "color": Color("363944"), "cobble": true},   # the side lane
		# the north row: each house has its own brick and slate; roof above, a wall band below
		{"t": "building", "rect": Rect2(0, -300, 430, 450), "wall": Color("6a4a4c"), "roof": Color("303648")},
		{"t": "building", "rect": Rect2(430, -300, 266, 450), "wall": Color("5d6068"), "roof": Color("3a3640")},
		{"t": "building", "rect": Rect2(744, -300, 436, 450), "wall": Color("67524a"), "roof": Color("2c3444")},
		{"t": "building", "rect": Rect2(1180, -300, 180, 450), "wall": Color("4c6460"), "roof": Color("343a48")},
		{"t": "building", "rect": Rect2(1360, -300, 380, 450), "wall": Color("6a5a52"), "roof": Color("2e3242")},
		{"t": "building", "rect": Rect2(1830, -300, 90, 450), "wall": Color("5a4a52"), "roof": Color("2c3040")},
		{"t": "window_row", "rect": Rect2(24, 86, 160, 34), "lit": false},
		{"t": "house_door", "rect": Rect2(214, 112, 36, 38)},
		{"t": "window_row", "rect": Rect2(284, 86, 140, 34), "lit": false},
		{"t": "shop_front", "rect": Rect2(450, 80, 240, 70), "name": "bakery"},
		{"t": "window_row", "rect": Rect2(760, 86, 150, 34), "lit": false},
		{"t": "shop_front", "rect": Rect2(930, 80, 200, 70), "name": "pub"},
		{"t": "shop_front", "rect": Rect2(1180, 80, 160, 70), "name": "tailor"},
		{"t": "window_row", "rect": Rect2(1384, 86, 330, 34), "lit": false},
		{"t": "fence", "rect": Rect2(30, 146, 120, 8)},
		{"t": "fence", "rect": Rect2(290, 146, 150, 8)},
		{"t": "fence", "rect": Rect2(0, 388, 1920, 10)},
		{"t": "alley_door", "rect": Rect2(1766, -300, 38, 30)},
	]
	interacts = [
		{"id": "house_door", "pos": Vector2(232, 154), "r": 26.0, "verb": "enter"},
		{"id": "alley_door", "pos": Vector2(1785, -270), "r": 30.0, "verb": "look"},
		{"id": "bar_door", "pos": Vector2(1069, 156), "r": 28.0, "verb": "enter"},
	]
	triggers = [
		{"id": "alley", "rect": Rect2(1744, -300, 82, 420)},
		{"id": "lane", "rect": Rect2(696, -300, 48, 430)},
	]
	spawns = {
		"from_house": Vector2(232, 184),
		"start": Vector2(232, 184),
		"from_bar": Vector2(1069, 188),
	}
	light_spots = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NPC_DATA))
	if typeof(parsed) == TYPE_DICTIONARY:
		npcs = (parsed.get("npcs", []) as Array).duplicate(true)
	else:
		push_error("Turned: cannot read " + NPC_DATA)
