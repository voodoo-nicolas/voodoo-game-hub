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
var people_scale := 1.0               # people drawn this much bigger here (painted rooms: tuning people_scale.<area id>)
var pictured := false                 # the ground is one painting (a painted room, or the painted street)
var painted := false                   # the floor map is one painting that is lit already (the ambient light stays near white)
var night_lit := false                 # an outdoor painting painted at night with its own moon and lamp light (the ambient stays near white)
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
var margin := Color("4d4d4d")          # a painted area: the grey round the picture, carried on past its edge
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
	elif area_id == "night_road":
		a._build_night_road()
	else:
		a._build_house()
	a.people_scale = T.f("people_scale." + area_id)
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

## The upstairs is one painting (games/turned/art/rooms/house_up.webp, 1264 x 848 px, the owner's Gemini art
## 2026-10-29): bedroom | landing with the stairs | bathroom, seen from the front at a high angle. The map is
## traced over it: coordinates in this function are PAINTING pixels, `_u` / `_up` turn them into world px
## (UP_K world px per painting px). Painting and map are 3 rooms wide; the old square map (with the study) is
## `_build_house_classic` below. The doors between the rooms are the gaps at y 600..700 in the two thick
## partition walls; the stairs go down from the mouth in front of the dark well.
const UP_K := 0.4
const UP_ART := "rooms/house_up"

static func _u(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * UP_K, y * UP_K, w * UP_K, h * UP_K)

static func _up(x: float, y: float) -> Vector2:
	return Vector2(x * UP_K, y * UP_K)

func _build_house() -> void:
	indoor = true
	painted = true
	var paint := Vector2(1264, 848) * UP_K
	bounds = Rect2(-170, -50, paint.x + 340, paint.y + 100)   # wider than the painting: the camera centres on it
	deco = [{"t": "painting", "art": UP_ART, "rect": Rect2(Vector2.ZERO, paint)}]
	solids = []
	# the shell: above each room's back wall base, below the front edge, the slanted side walls in steps
	for r in [_u(-400, -400, 945, 750), _u(545, -400, 303, 760), _u(848, -400, 852, 798),
			_u(-400, 790, 2100, 400),
			_u(-400, 350, 570, 100), _u(-400, 450, 550, 110), _u(-400, 560, 520, 120), _u(-400, 680, 495, 110),
			_u(1095, 398, 700, 102), _u(1120, 500, 700, 100), _u(1160, 600, 700, 100), _u(1185, 700, 700, 90),
			# the partitions, with a doorway each at y 600..700
			_u(518, 350, 44, 250), _u(518, 700, 44, 90), _u(836, 360, 44, 240), _u(836, 700, 44, 90)]:
		solids.append(r)
	# bedroom
	for r in [_u(112, 400, 112, 125), _u(284, 350, 138, 52), _u(302, 360, 78, 70), _u(448, 352, 72, 58),
			_u(82, 520, 305, 190), _u(72, 705, 80, 85), _u(455, 500, 60, 100), _u(445, 700, 70, 90)]:
		solids.append(r)
	# landing: the rail, the dark well and the newel posts (the steps in front of it are the way down)
	solids.append(_u(695, 360, 145, 240))
	solids.append(_u(695, 600, 50, 80))
	# bathroom: the sink, the toilet, the curtain, the bath
	for r in [_u(885, 395, 80, 40), _u(1018, 395, 60, 45), _u(1055, 455, 120, 185), _u(915, 665, 255, 125)]:
		solids.append(r)
	# the painting already shows the coat, the calendar and the bed; only the towel is drawn, on the rim of the bath
	deco.append({"t": "item", "kind": "towel", "pos": _up(950, 655)})
	# "mark": where the gold mission marker sits (on the painted object; "pos" is where you stand to use it)
	interacts = [
		{"id": "coat", "pos": _up(345, 460), "r": 70.0 * UP_K, "verb": "look", "mark": _up(331, 370)},
		{"id": "matches", "pos": _up(185, 760), "r": 75.0 * UP_K, "verb": "take", "mark": _up(112, 690)},
		{"id": "calendar", "pos": _up(415, 430), "r": 60.0 * UP_K, "verb": "look"},
		{"id": "wardrobe", "pos": _up(262, 480), "r": 70.0 * UP_K, "verb": "look"},
		{"id": "washstand", "pos": _up(410, 600), "r": 60.0 * UP_K, "verb": "look"},
		{"id": "mirror", "pos": _up(935, 460), "r": 70.0 * UP_K, "verb": "look", "mark": _up(919, 218)},
		{"id": "toilet", "pos": _up(1028, 485), "r": 60.0 * UP_K, "verb": "look"},
		{"id": "towel", "pos": _up(930, 632), "r": 45.0 * UP_K, "verb": "look", "mark": _up(950, 650)},
		{"id": "bath", "pos": _up(1010, 632), "r": 55.0 * UP_K, "verb": "look"},
		{"id": "stairs_down", "pos": _up(790, 655), "r": 60.0 * UP_K, "verb": "down"},
	]
	lamps = []
	# the painting is lit already: only a little extra light round the window and the lamps
	light_spots = [
		{"pos": _up(355, 400), "color": Color("9db8ff"), "energy": 0.35, "radius": 110.0},
		{"pos": _up(110, 700), "color": Color("ffb45a"), "energy": 0.4, "radius": 80.0},
		{"pos": _up(700, 420), "color": Color("ffb45a"), "energy": 0.4, "radius": 90.0},
	]
	spawns = {
		"bed": _up(215, 610),
		"bedside": _up(190, 750),
		"from_down": _up(790, 660),
		"bedroom_door": _up(610, 650),   # on the landing, out of the bedroom
		"bathroom_door": _up(915, 630),  # in the bathroom, by its door
		"bathroom_out": _up(800, 700),   # on the landing, out of the bathroom
		"study_out": _up(640, 520),      # kept for the old painted-room scenes (the study is gone upstairs)
	}

## The previous upstairs (one square map with a study), kept for reference; not used since 2026-10-29.
func _build_house_classic() -> void:
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
		"bedroom_door": Vector2(160, 352),   # on the landing, out of the painted bedroom (turned_scenes.json)
		"bathroom_door": Vector2(436, 268),  # in the bathroom, by its door
		"bathroom_out": Vector2(436, 352),   # on the landing, out of the painted bathroom
		"study_out": Vector2(240, 370),      # on the landing, out of the painted study
	}

## The ground floor is one painting too (games/turned/art/rooms/house_down.webp, 1024 x 687 px, the owner's
## Gemini art 2026-11-03, made to match the upstairs): parlour | entrance hall | kitchen, the same front view.
## Coordinates below are PAINTING pixels; DN_K makes the building as wide in the world as the upstairs
## (1264 x 0.4 = 1024 x DN_K). The painting shows no doors between the rooms: the passages are gaps at the
## front (y 575..640) of the two partition walls, like the cutaway's open front. In the hall the front door
## is in the back wall, the stairs up rise behind the railing at the back right (you take them from the
## corner beside the newel post), and the cellar steps go down in the well in front of them to the locked
## cellar door. The coat stand with the grey scarf hangs by the stairs.
const DN_K := 0.49375
const DN_ART := "rooms/house_down"

static func _d(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * DN_K, y * DN_K, w * DN_K, h * DN_K)

static func _dn(x: float, y: float) -> Vector2:
	return Vector2(x * DN_K, y * DN_K)

func _build_house_down() -> void:
	indoor = true
	painted = true
	var paint := Vector2(1024, 687) * DN_K
	bounds = Rect2(-170, -50, paint.x + 340, paint.y + 100)   # wider than the painting: the camera centres on it
	deco = [{"t": "painting", "art": DN_ART, "rect": Rect2(Vector2.ZERO, paint)}]
	solids = []
	# the shell: above the back walls, below the front edge, the slanted side walls in steps
	for r in [_d(-400, -400, 1900, 690), _d(-400, 640, 1900, 400),
			_d(-400, 290, 530, 90), _d(-400, 380, 505, 90), _d(-400, 470, 480, 90), _d(-400, 560, 462, 80),
			_d(915, 290, 600, 95), _d(935, 385, 600, 85), _d(950, 470, 600, 85), _d(965, 555, 600, 85),
			# the partitions, open at the front
			_d(415, 290, 32, 285), _d(686, 290, 26, 285)]:
		solids.append(r)
	# parlour: the fireplace, the piano and its stool, the bookcase, the two armchairs, the sofa
	for r in [_d(85, 300, 80, 200), _d(198, 290, 140, 30), _d(240, 290, 56, 38), _d(338, 290, 77, 16),
			_d(185, 335, 85, 75), _d(332, 375, 63, 155), _d(112, 525, 100, 85)]:
		solids.append(r)
	# hall: the tall hall stand on the left wall, the railing round the stairwell (the stairs up behind it,
	# the cellar steps inside it)
	solids.append(_d(447, 290, 40, 82))
	solids.append(_d(565, 290, 121, 260))
	# kitchen: the jar shelves, the range along the right wall, the table (the low bench is walkable), the stool
	for r in [_d(780, 290, 120, 20), _d(870, 300, 70, 200), _d(772, 380, 78, 140), _d(905, 515, 70, 125)]:
		solids.append(r)
	# "mark": where the gold mission marker sits (on the painted object; "pos" is where you stand to use it)
	interacts = [
		{"id": "fireplace", "pos": _dn(195, 450), "r": 45.0 * DN_K, "verb": "look"},
		{"id": "piano", "pos": _dn(318, 345), "r": 40.0 * DN_K, "verb": "look"},
		{"id": "parlour_books", "pos": _dn(385, 330), "r": 40.0 * DN_K, "verb": "look"},
		{"id": "front_door", "pos": _dn(512, 312), "r": 34.0 * DN_K, "verb": "door"},
		{"id": "scarf", "pos": _dn(546, 372), "r": 24.0 * DN_K, "verb": "take", "mark": _dn(630, 215)},
		{"id": "stairs_up", "pos": _dn(546, 322), "r": 24.0 * DN_K, "verb": "up"},
		{"id": "cellar_door", "pos": _dn(635, 580), "r": 40.0 * DN_K, "verb": "door"},
		{"id": "pantry", "pos": _dn(735, 330), "r": 40.0 * DN_K, "verb": "look"},
		{"id": "shelves", "pos": _dn(840, 330), "r": 45.0 * DN_K, "verb": "look"},
		{"id": "stove", "pos": _dn(880, 525), "r": 40.0 * DN_K, "verb": "look"},
		{"id": "table", "pos": _dn(800, 565), "r": 45.0 * DN_K, "verb": "look"},
	]
	lamps = []
	# the painting is lit already: only a little extra light by the wall lamps
	light_spots = [
		{"pos": _dn(130, 250), "color": Color("ffb45a"), "energy": 0.35, "radius": 80.0},
		{"pos": _dn(470, 290), "color": Color("ffb45a"), "energy": 0.35, "radius": 80.0},
		{"pos": _dn(660, 380), "color": Color("ffb45a"), "energy": 0.35, "radius": 80.0},
	]
	spawns = {
		"from_street": _dn(520, 345),
		"from_up": _dn(530, 340),
		"witness": _dn(500, 470),        # where the man from the bar waits, on the runner
		"parlour_door": _dn(380, 605),   # kept for the hall painting's exits (the hall scene is not opened any more)
		"kitchen_door": _dn(740, 605),
	}

## The previous ground floor (a drawn square map), kept for reference; not used since 2026-11-03.
func _build_house_down_classic() -> void:
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
		"parlour_door": Vector2(160, 280),   # out of the painted hall (turned_scenes.json)
		"kitchen_door": Vector2(436, 280),
	}

## The pub and the cigar shop are the owner's cutaway paintings too (2026-11-03, `rooms/bar.webp` and
## `rooms/cigar_shop.webp`, 1264 x 848, made to match the house). Coordinates below are PAINTING pixels;
## RM_K = 0.5 world px per painting px (a table is about 60 world px, a stool 22, people 46 tall).
const RM_K := 0.5

static func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * RM_K, y * RM_K, w * RM_K, h * RM_K)

static func _rp(x: float, y: float) -> Vector2:
	return Vector2(x * RM_K, y * RM_K)

## A painted room's frame: the picture, the camera bounds round it, and its people from turned_npcs.json
## (their "pos" there are painting pixels too, turned into world px here).
func _painted_room(art: String, npc_key: String) -> void:
	indoor = true
	painted = true
	var paint := Vector2(1264, 848) * RM_K
	bounds = Rect2(-170, -50, paint.x + 340, paint.y + 100)
	deco = [{"t": "painting", "art": art, "rect": Rect2(Vector2.ZERO, paint)}]
	solids = []
	lamps = []
	light_spots = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NPC_DATA))
	if typeof(parsed) == TYPE_DICTIONARY:
		npcs = (parsed.get(npc_key, []) as Array).duplicate(true)
		for n in npcs:
			n["pos"] = [float(n["pos"][0]) * RM_K, float(n["pos"][1]) * RM_K]

## The Crooked Lantern (`rooms/bar.webp`): the long counter and the bottle shelves across the back, the
## fireplace in the back right corner, four tables with stools, the red rug, and the street door standing
## at the front edge in the middle. The tavernkeep waits at the end of his counter, by the fire.
func _build_bar() -> void:
	_painted_room("rooms/bar", "bar_npcs")
	for r in [_r(-400, -400, 2100, 730), _r(-400, 795, 2100, 400),
			_r(-400, 330, 585, 100), _r(-400, 430, 560, 100), _r(-400, 530, 530, 100), _r(-400, 630, 505, 100), _r(-400, 730, 485, 70),
			_r(1090, 330, 600, 165), _r(1115, 495, 600, 100), _r(1140, 595, 600, 100), _r(1165, 695, 600, 105),
			_r(150, 300, 670, 100),                                  # the counter
			_r(900, 300, 400, 95),                                   # the fireplace and its hearth
			_r(380, 365, 45, 70), _r(688, 365, 47, 70),              # the counter stools
			_r(205, 430, 200, 150), _r(150, 610, 230, 130),          # the left tables and their stools
			_r(860, 425, 205, 165), _r(885, 610, 230, 135),          # the right tables and their stools
			_r(525, 595, 215, 205)]:                                 # the street door
		solids.append(r)
	interacts = [
		{"id": "bar_exit", "pos": _rp(632, 562), "r": 40.0 * RM_K, "verb": "door"},
	]
	light_spots = [{"pos": _rp(990, 340), "color": Color("ff8a3a"), "energy": 0.45, "radius": 110.0}]
	spawns = {"from_street": _rp(632, 556)}

## The cigar shop (`rooms/cigar_shop.webp`): the shop on the left (the glass street door in the left wall,
## the counter, the shelves of boxes and tins, a display table), the thick wall, and the storeroom on the
## right (tobacco drying from the beams, crates and barrels, the cot). The painting shows no door between
## them: the way through is in front of the wall (y 630..680), like the house.
func _build_cigar_shop() -> void:
	_painted_room("rooms/cigar_shop", "shop_npcs")
	margin = Color("666666")                # this picture's border is a lighter grey
	for r in [_r(-400, -400, 2100, 800), _r(-400, 790, 2100, 400),
			# the shop's back wall and the left wall in steps (the door is in it)
			_r(-400, 400, 600, 100), _r(-400, 500, 570, 100), _r(-400, 600, 545, 100), _r(-400, 700, 520, 90),
			_r(200, 300, 500, 105),                                  # shelves along the back
			_r(290, 395, 300, 175), _r(585, 400, 115, 150),          # the counter and the cabinet beside it
			_r(325, 630, 190, 160),                                  # the display table
			_r(700, 300, 170, 330),                                  # the thick wall (walk past its front face)
			# the storeroom: crates, barrels, the lamp stool, the cot, the right wall
			_r(865, 290, 330, 200), _r(885, 490, 50, 110), _r(1010, 450, 400, 50), _r(1010, 500, 400, 260),
			_r(880, 680, 165, 115), _r(1190, 290, 400, 600)]:
		solids.append(r)
	interacts = [
		{"id": "cigar_exit", "pos": _rp(190, 560), "r": 45.0 * RM_K, "verb": "door"},
	]
	light_spots = [{"pos": _rp(1080, 440), "color": Color("ffb45a"), "energy": 0.4, "radius": 80.0}]
	spawns = {
		"from_harbor": _rp(215, 600),
		"storeroom": _rp(990, 625),        # beside the cot, where you wake
		"keeper_stool": _rp(965, 530),     # the shopkeeper watching you from the stool by the cot
		"witness_shop": _rp(270, 650),     # the man from the bar, beside you in the shop
	}

# ---------------------------------------------------------------- The Crooked Lantern (the bar)
# One room, 640 x 400: the counter along the north wall with the keeper behind it, three tables, a
# fireplace, the street door in the south wall. Placeholder name and layout (docs/turned/DECISIONS.md).

## The previous drawn pub (one room, 640 x 400), kept for reference; not used since 2026-11-03.
func _build_bar_classic() -> void:
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

## The drawn harbour (shader cobbles, drawn warehouses), kept for reference; not used since 2026-11-04 (the
## painted harbour, `_build_harbor`).
func _build_harbor_classic() -> void:
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

## The previous drawn cigar shop, kept for reference; not used since 2026-11-03.
func _build_cigar_shop_classic() -> void:
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

# ---------------------------------------------------------------- the night walk and the forest (scene 6)
# One long way, 2700 px: the last gas lamps of Vellmoor (x < 1000), then a dirt path through the forest
# to a small house covered in vines (x about 2500). Placeholder layout (docs/turned/DECISIONS.md).

## The drawn night road (placeholder layout), kept for reference; not used since 2026-11-04 (the painted night
## road, `_build_night_road`).
func _build_night_road_classic() -> void:
	indoor = false
	bounds = Rect2(0, -200, 2700, 600)
	solids = [
		Rect2(0, -200, 1000, 350),            # the houses
		Rect2(1000, -200, 1700, 320),         # the forest on the north side
		Rect2(0, 388, 2700, 12),              # the edge of the road, the edge of the wood
		Rect2(-20, -200, 20, 600), Rect2(2700, -200, 20, 600),
		Rect2(2470, 20, 190, 140),            # the vine house
	]
	for x in [120, 340, 600, 880]:
		solids.append(Rect2(x - 4, 202, 8, 8))
		lamps.append(Vector2(x, 198))
		props.append({"kind": "lamp", "pos": Vector2(x, 208)})
	for t in [Vector2(1080, 150), Vector2(1150, 330), Vector2(1230, 160), Vector2(1300, 335), Vector2(1390, 148), Vector2(1450, 325),
			Vector2(1540, 165), Vector2(1610, 340), Vector2(1700, 152), Vector2(1760, 330), Vector2(1850, 160), Vector2(1930, 336),
			Vector2(2010, 150), Vector2(2090, 326), Vector2(2180, 164), Vector2(2260, 338), Vector2(2340, 150), Vector2(2420, 330)]:
		solids.append(Rect2(t.x - 6, t.y - 6, 12, 12))
		props.append({"kind": "tree", "pos": t, "r": 52.0})
		shades.append({"circle": Vector2(t.x, t.y - 7), "r": 50.0, "style": "tree"})
	# The forest floor, from the hub's sprite library (decoration: low enough to walk through, so
	# no solids): the path's south verge, the gaps between the south trees, the gaps in the north
	# row (the canopies hide the rest), a dead tree with an owl, bats over the old man's house.
	for f in [["forest/fern", 1060, 266], ["forest/mushroom_cluster", 1190, 262], ["forest/fern", 1340, 270],
			["forest/small_bush", 1505, 268], ["forest/fern", 1660, 264], ["forest/mushroom_cluster", 1805, 266],
			["forest/fern", 1975, 268], ["forest/boulder_sm", 2130, 270], ["forest/fern", 2290, 264],
			["forest/large_bush", 1225, 360], ["forest/tree_stump", 1375, 345], ["forest/berry_bush", 1530, 370],
			["forest/boulder_lg", 1685, 355], ["forest/fern", 1845, 300], ["forest/mushroom_cluster", 1845, 372],
			["forest/small_bush", 2010, 350], ["forest/tree_stump", 2175, 365], ["forest/large_bush", 2340, 352],
			["forest/fern", 1155, 190], ["forest/mushroom_cluster", 1310, 188], ["forest/small_bush", 1465, 192],
			["forest/fern", 1775, 190], ["forest/boulder_sm", 1930, 192], ["forest/fern", 2095, 188],
			["forest/mushroom_cluster", 2260, 190], ["forest/dead_tree", 1620, 192]]:
		props.append({"kind": "lib", "sprite": f[0], "pos": Vector2(f[1], f[2])})
	props.append({"kind": "lib", "sprite": "forest/owl", "pos": Vector2(1622, 193), "lift": 30.0})
	for b in [[2560, 40, 80, 26, 0.18], [2540, 64, 60, 20, 0.23], [1070, 120, 50, 18, 0.2]]:
		props.append({"kind": "lib", "sprite": "dungeon/bat", "pos": Vector2(b[0], b[1]), "fly": [b[2], b[3], b[4]]})
	deco = [
		{"t": "floor", "rect": Rect2(0, 215, 1000, 115), "color": Color("464a58"), "cobble": true},
		{"t": "floor", "rect": Rect2(0, 150, 1000, 65), "color": Color("525867"), "slab": true},
		{"t": "floor", "rect": Rect2(0, 330, 1000, 58), "color": Color("4c5260"), "slab": true},
		{"t": "floor", "rect": Rect2(1000, 120, 1700, 268), "color": Color("1e2822"), "grass": true},
		{"t": "floor", "rect": Rect2(1000, 196, 1700, 56), "color": Color("4a4234"), "slab": true},       # the path
		{"t": "building", "rect": Rect2(0, -200, 320, 350), "wall": Color("5a5058"), "roof": Color("2c3040")},
		{"t": "building", "rect": Rect2(320, -200, 380, 350), "wall": Color("5e5248"), "roof": Color("34303c")},
		{"t": "building", "rect": Rect2(700, -200, 300, 350), "wall": Color("4f585e"), "roof": Color("2c3646")},
		{"t": "window_row", "rect": Rect2(30, 86, 260, 34), "lit": false},
		{"t": "window_row", "rect": Rect2(350, 86, 320, 34), "lit": false},
		{"t": "window_row", "rect": Rect2(730, 86, 240, 34), "lit": false},
		{"t": "vine_house", "rect": Rect2(2470, 20, 190, 140)},
	]
	interacts = [
		{"id": "priest_door", "pos": Vector2(2566, 176), "r": 32.0, "verb": "enter"},
	]
	triggers = [
		{"id": "walk1", "rect": Rect2(150, 150, 40, 238)},
		{"id": "walk2", "rect": Rect2(520, 150, 40, 238)},
		{"id": "walk3", "rect": Rect2(820, 150, 40, 238)},
		{"id": "gate", "rect": Rect2(1010, 150, 40, 238)},
		{"id": "branch", "rect": Rect2(1690, 150, 40, 238)},
		{"id": "house", "rect": Rect2(2340, 150, 40, 238)},
	]
	light_spots = [
		{"pos": Vector2(2520, 108), "color": Color("ffb45a"), "energy": 0.9, "radius": 120.0},
	]
	spawns = {"start": Vector2(60, 245)}
	npcs = []

# ---------------------------------------------------------------- painted walks: the harbour, the night road

## The owner's pictures joined left to right by tools/turned_walk_join.py into `rooms/<area>.webp` (2026-11-04,
## DECISIONS B-16). turned_walks.json (the tool writes it) holds each panel [picture, x_from, x_to, blend into
## the next] and the cut-outs [name, panel, box x, y, w, h, base y]. Coordinates below are PANEL pixels (the
## picture's own), k = the panel's index: joined x = 56 + off_k + (x - x_from_k), joined y = y - 3, then WALK_K
## world px per picture px (the street's scale). Both are painted at night with their own moon and lamp light.
const WALK_K := 0.55
const WALK_DATA := "res://scripts/games/turned/turned_walks.json"
var _wfrom: Array = []
var _woff: Array = []

func _wp(k: int, x: float, y: float) -> Vector2:
	return Vector2((56.0 + float(_woff[k]) + x - float(_wfrom[k])) * WALK_K, (y - 3.0) * WALK_K)

func _wr(k: int, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_wp(k, x, y), Vector2(w, h) * WALK_K)

## A painted walk's frame: the panels' offsets, the picture, the bounds, and its cut-outs as y-sorted props.
func _walk_begin() -> void:
	indoor = false
	pictured = true
	night_lit = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(WALK_DATA))
	var d: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		d = parsed.get(id, {})
	else:
		push_error("Turned: cannot read " + WALK_DATA)
	margin = Color(str(d.get("margin", "4d4d4d")))        # the picture's own grey, carried on past its edge
	var off := 0.0
	for p in d.get("panels", []):
		_wfrom.append(float(p[1]))
		_woff.append(off)
		off += float(p[2]) - float(p[1]) - float(p[3])
	var paint := Vector2(off + 112.0, 845.0) * WALK_K
	bounds = Rect2(-20, -10, paint.x + 40, paint.y + 20)
	deco = [{"t": "painting", "art": "rooms/" + id, "rect": Rect2(Vector2.ZERO, paint)}]
	for c in d.get("cuts", []):
		var k := int(c[1])
		var box := _wr(k, float(c[2]), float(c[3]), float(c[4]), float(c[5]))
		props.append({"kind": "cut", "name": id + "/" + str(c[0]), "rect": box, "pos": Vector2(box.get_center().x, _wp(k, 0, float(c[6])).y)})

## Vellmoor Harbor (HR-01, HR-04, HR-05): she comes down the side lane at the west end; warehouses along the far
## side to y 393, the slab pavement, the cobbled road, an iron railing (a gap in the middle of each picture) and
## the quay planks to the water at y 690. The cigar shop (striped awning, door at x 790..845) is near the east end.
func _build_harbor() -> void:
	_walk_begin()
	solids = [
		_wr(0, -400, -400, 460, 1600), _wr(0, 60, -400, 60, 793), _wr(0, 120, -400, 95, 630),   # the west end, the lane
		_wr(0, 215, -400, 989, 780), _wr(1, 60, -400, 1144, 780), _wr(2, 60, -400, 1144, 780),   # the warehouses
		_wr(2, 1204, -400, 400, 1600),                                                         # past the east end
		_wr(1, 628, 380, 84, 25),                                   # the chandler's barrels
		_wr(2, 628, 380, 150, 25),                                  # the cigar shop's bow window
		_wr(2, 876, 640, 46, 20),                                   # a barrel on the planks
	]
	for k in 3:
		solids.append_array([
			_wr(k, 518, 380, 84, 30),                               # a crate and a barrel by the wall
			_wr(k, 225, 462, 16, 14), _wr(k, 935, 462, 16, 14),     # the lamp posts
			_wr(k, 60, 590, 285, 50), _wr(k, 918, 590, 286, 50),    # the railings
			_wr(k, 378, 630, 147, 44), _wr(k, 527, 628, 36, 24),    # crates and a barrel on the planks
			_wr(k, 60, 690, 1144, 400),                             # the quay's edge
		])
		lamps.append_array([_wp(k, 233, 280) + Vector2(0, 28), _wp(k, 943, 280) + Vector2(0, 28)])
	light_spots = [
		{"pos": _wp(1, 910, 255), "color": Color("ffb45a"), "energy": 0.5, "radius": 70.0},     # the hanging lanterns
		{"pos": _wp(2, 910, 255), "color": Color("ffb45a"), "energy": 0.5, "radius": 70.0},
		{"pos": _wp(2, 700, 350), "color": Color("ffb45a"), "energy": 0.35, "radius": 80.0},    # the shop window
	]
	shades = []
	interacts = [
		{"id": "cigar_door", "pos": _wp(2, 817, 405), "r": 30.0, "verb": "enter"},
	]
	triggers = [
		{"id": "sense1", "rect": _wr(0, 700, 380, 40, 320)},
		{"id": "sense2", "rect": _wr(1, 150, 380, 40, 320)},
		{"id": "sense3", "rect": _wr(1, 750, 380, 40, 320)},
		{"id": "sense4", "rect": _wr(2, 300, 380, 40, 320)},
	]
	spawns = {"from_city": _wp(0, 165, 370), "from_shop": _wp(2, 817, 425)}
	npcs = []

## The night walk (NR-05, NR-06, NR-07, NR-03, the vine house half of NR-04): out of the cigar shop's door along
## the harbour street (the water filled in: bollards, planks, a near pavement, a low wall at y 748), the last
## half-timbered houses and the last lamp, the stone gate where the cobbles end, then the forest path (y 440..640)
## past two dead trees (NR-07's low branch is the "branch" beat) to the small house buried in vines.
func _build_night_road() -> void:
	_walk_begin()
	solids = [
		# NR-05: the west end, the far row, the bow window, the crate by the wall, the near wall
		_wr(0, -400, -400, 460, 1600), _wr(0, 60, -400, 1032, 780), _wr(0, 628, 380, 150, 25), _wr(0, 518, 380, 84, 30),
		_wr(0, 60, 735, 1032, 400),
		_wr(0, 225, 462, 16, 14), _wr(0, 935, 462, 16, 14), _wr(0, 1052, 700, 16, 18),         # the lamps
		_wr(0, 378, 630, 147, 44), _wr(0, 527, 628, 36, 24), _wr(0, 876, 640, 46, 20),         # crates, barrels
		# NR-06: the last houses, the gate (the back post to y 495, the front post and its leaf), the bush, the wood
		_wr(1, 60, -400, 668, 780), _wr(1, 728, -400, 160, 895), _wr(1, 888, -400, 232, 830),
		_wr(1, 225, 462, 16, 14), _wr(1, 60, 735, 580, 400), _wr(1, 640, 615, 180, 400),
		_wr(1, 800, 655, 115, 400), _wr(1, 858, 600, 50, 400), _wr(1, 820, 650, 300, 400),
		# NR-07, NR-03: the forest either side of the path, two boulders
		_wr(2, 60, -400, 1070, 840), _wr(2, 60, 640, 1070, 400), _wr(2, 615, 625, 145, 80), _wr(2, 820, 612, 170, 90),
		_wr(3, 170, -400, 860, 840), _wr(3, 170, 650, 860, 400),
		# NR-04: the vine house (its step at y 495..523 is open), the wood, the east end
		_wr(4, 700, -400, 15, 840), _wr(4, 715, -400, 435, 895), _wr(4, 700, 650, 504, 400), _wr(4, 1130, -400, 474, 1600),
	]
	for x in [70, 205, 340, 680]:
		solids.append(_wr(0, x - 7, 628, 14, 16))                   # the bollards
	for x in [205, 340, 510, 680]:
		solids.append(_wr(1, x - 7, 628, 14, 16))
	lamps = [_wp(0, 233, 280) + Vector2(0, 28), _wp(0, 943, 280) + Vector2(0, 28), _wp(0, 1060, 470) + Vector2(0, 28),
		_wp(1, 233, 280) + Vector2(0, 28)]
	light_spots = [
		{"pos": _wp(0, 910, 255), "color": Color("ffb45a"), "energy": 0.5, "radius": 70.0},     # the shop's lantern
		{"pos": _wp(4, 805, 380), "color": Color("ffb45a"), "energy": 0.9, "radius": 120.0},    # the vine house window
	]
	shades = []
	interacts = [
		{"id": "priest_door", "pos": _wp(4, 900, 520), "r": 32.0, "verb": "enter"},
	]
	triggers = [
		{"id": "walk1", "rect": _wr(0, 980, 380, 40, 360)},
		{"id": "walk2", "rect": _wr(1, 150, 380, 40, 360)},
		{"id": "walk3", "rect": _wr(1, 440, 380, 40, 360)},
		{"id": "gate", "rect": _wr(1, 740, 380, 40, 260)},
		{"id": "branch", "rect": _wr(2, 560, 430, 40, 220)},
		{"id": "house", "rect": _wr(3, 900, 430, 40, 220)},
	]
	spawns = {"start": _wp(0, 817, 425)}
	npcs = []

# ---------------------------------------------------------------- the street

## The street as the owner's painting (2026-11-04, DECISIONS B-15): ST-01..03 joined left to right into
## `rooms/street.webp` by tools/turned_street_cuts.py (frames cut at the joins). Coordinates below are
## PANEL pixels of each picture (k = 0, 1, 2 for ST-01..03), the same as the tool's: joined x = x - 4 +
## 1120 k, joined y = y - 3, then ST_K world px per picture px. Each panel: the far row of houses and shops
## down to y 415, the far pavement 415..490, the cobbled road 495..695, the near kerb to the railings at 718.
## West to east: the dark gap, her house (porch, steps), the grey house, the bakery | the side lane, a house,
## The Crooked Lantern, the tailor | a house, the alley with the old door, the corner house. The trees, lamp
## posts, the stall and the carriage are cut out of the picture (props "cut") so people walk behind them.
const ST_K := 0.55
const ST_ART := "rooms/street"
const ST_STEP := 1120.0

static func _sp(k: int, x: float, y: float) -> Vector2:
	return Vector2((x - 4.0 + ST_STEP * k) * ST_K, (y - 3.0) * ST_K)

static func _sr(k: int, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_sp(k, x, y), Vector2(w, h) * ST_K)

func _build_street() -> void:
	indoor = false
	pictured = true
	var paint := Vector2(3496, 845) * ST_K
	bounds = Rect2(-20, -10, paint.x + 40, paint.y + 20)
	deco = [{"t": "painting", "art": ST_ART, "rect": Rect2(Vector2.ZERO, paint)}]
	margin = Color("878787")                # the pictures' grey border
	solids = [
		# her end: the dark gap and her house to the steps, the steps (you climb to the door), the rest
		_sr(0, -400, -400, 735, 815), _sr(0, 335, -400, 135, 780), _sr(0, 470, -400, 710, 815),
		# the side lane (x 140..212, back wall at 185), her neighbour, the pub (its doorway open to 395),
		# the tailor
		_sr(1, 60, -400, 80, 815), _sr(1, 140, -400, 72, 585), _sr(1, 212, -400, 123, 815),
		_sr(1, 335, -400, 135, 780), _sr(1, 470, -400, 265, 815), _sr(1, 735, -400, 55, 795), _sr(1, 790, -400, 390, 815),
		# the corner: the long house, the alley (between the crates and the barrels to its old door), the
		# corner house and past the east edge
		_sr(2, 60, -400, 275, 815), _sr(2, 335, -400, 135, 780), _sr(2, 470, -400, 380, 815),
		_sr(2, 850, -400, 102, 772), _sr(2, 952, -400, 63, 618), _sr(2, 1015, -400, 85, 768), _sr(2, 1100, -400, 900, 815),
		# the railings along the gardens, and the ends of the street
		_sr(0, -400, 718, 1580, 600), _sr(1, 60, 718, 1120, 600), _sr(2, 60, 718, 1900, 600),
		_sr(0, -400, -400, 460, 1600), _sr(2, 1204, -400, 800, 1600),
		# lamp posts (far kerb, near kerb), the stall, the carriage and its horse
		_sr(0, 226, 460, 16, 14), _sr(1, 226, 460, 16, 14), _sr(2, 226, 460, 16, 14),
		_sr(0, 999, 700, 16, 18), _sr(1, 102, 700, 16, 18), _sr(1, 999, 700, 16, 18), _sr(2, 102, 700, 16, 18),
		_sr(1, 208, 676, 155, 42),
		_sr(2, 168, 628, 252, 64), _sr(2, 428, 646, 128, 36),
	]
	# the cut-outs: [name, panel, box x, y, w, h (as in the tool), base y (their foot, for the y-sort)]
	for c in [["tree_w", 0, 8, 468, 236, 334, 800], ["tree_mid", 1, 645, 466, 240, 336, 800], ["tree_e", 2, 922, 466, 254, 336, 800],
			["lamp_far0", 0, 210, 252, 48, 226, 472], ["lamp_far1", 1, 210, 252, 48, 226, 472], ["lamp_far2", 2, 210, 252, 48, 226, 472],
			["lamp_near0", 0, 982, 494, 50, 228, 718], ["lamp_near1", 1, 86, 494, 50, 228, 718],
			["lamp_near2", 1, 982, 494, 50, 228, 718], ["lamp_near3", 2, 86, 494, 50, 228, 718],
			["stall", 1, 200, 562, 176, 198, 718], ["carriage", 2, 158, 476, 458, 220, 692]]:
		var box := _sr(c[1], c[2], c[3], c[4], c[5])
		props.append({"kind": "cut", "name": "street/" + str(c[0]), "rect": box, "pos": Vector2(box.get_center().x, _sp(c[1], 0, c[6]).y)})
	# gas light: the heads of the lamp posts (a lamp is its light; the glow sits 28 px above it)
	lamps = [_sp(0, 234, 280) + Vector2(0, 28), _sp(1, 234, 280) + Vector2(0, 28), _sp(2, 234, 280) + Vector2(0, 28),
		_sp(0, 1007, 522) + Vector2(0, 28), _sp(1, 110, 522) + Vector2(0, 28), _sp(1, 1007, 522) + Vector2(0, 28),
		_sp(2, 110, 522) + Vector2(0, 28)]
	light_spots = [
		{"pos": _sp(2, 885, 165), "color": Color("ffb45a"), "energy": 0.5, "radius": 90.0},     # the alley's wall lamps
		{"pos": _sp(2, 1020, 115), "color": Color("ffb45a"), "energy": 0.35, "radius": 70.0},
	]
	shades = [
		{"rect": _sr(0, 330, 372, 150, 66), "style": "painted"},             # her porch, over the steps
		{"rect": _sr(0, 833, 400, 300, 48), "style": "painted"},             # the bakery's awning
		{"rect": _sr(1, 557, 395, 290, 53), "style": "painted"},             # the pub's awning
		{"rect": _sr(1, 1003, 400, 128, 48), "style": "painted"},            # the tailor's awning
		{"rect": _sr(1, 132, 150, 88, 268), "style": "alley"},               # the side lane
		{"rect": _sr(2, 848, 190, 262, 228), "style": "alley"},              # the alley
		{"circle": _sp(0, 126, 662), "r": 95.0 * ST_K, "style": "painted"},  # the trees' shadows on the road
		{"circle": _sp(1, 765, 662), "r": 95.0 * ST_K, "style": "painted"},
		{"circle": _sp(2, 1058, 662), "r": 95.0 * ST_K, "style": "painted"},
	]
	interacts = [
		{"id": "house_door", "pos": _sp(0, 418, 392), "r": 30.0, "verb": "enter"},
		{"id": "alley_door", "pos": _sp(2, 985, 238), "r": 30.0, "verb": "look"},
		{"id": "bar_door", "pos": _sp(1, 762, 420), "r": 30.0, "verb": "enter"},
	]
	triggers = [
		{"id": "alley", "rect": _sr(2, 850, 190, 260, 215)},
		{"id": "lane", "rect": _sr(1, 132, 150, 88, 265)},
	]
	spawns = {
		"from_house": _sp(0, 404, 402),
		"start": _sp(0, 404, 402),
		"from_bar": _sp(1, 762, 438),
	}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NPC_DATA))
	if typeof(parsed) == TYPE_DICTIONARY:
		npcs = (parsed.get("npcs", []) as Array).duplicate(true)
	else:
		push_error("Turned: cannot read " + NPC_DATA)

## The drawn street (shader cobbles, drawn houses and awnings), kept for reference; not used since
## 2026-11-04 (the painted street above).
func _build_street_classic() -> void:
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
