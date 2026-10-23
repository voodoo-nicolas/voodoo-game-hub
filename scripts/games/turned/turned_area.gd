extends RefCounted

## One map of Turned as plain data plus geometry queries, no Nodes: the bedroom/bathroom/hall
## house, and Vellmoor's Residential Quarter street with its alley (Day 1). The world draws it
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

func _build_house() -> void:
	indoor = true
	bounds = Rect2(0, 0, 560, 416)
	# walls: outer, the wall between bedroom and bathroom, the hall wall with two doorways
	solids = [
		Rect2(0, 0, 560, 16), Rect2(0, 0, 16, 416), Rect2(0, 400, 560, 16),
		Rect2(544, 0, 16, 336), Rect2(544, 384, 16, 32), Rect2(544, 336, 16, 48),   # the last one is the front door
		Rect2(336, 16, 16, 288),
		Rect2(16, 304, 104, 16), Rect2(200, 304, 200, 16), Rect2(472, 304, 72, 16),
		# bedroom furniture
		Rect2(28, 28, 64, 128),      # bed
		Rect2(96, 24, 30, 28),       # nightstand
		Rect2(224, 28, 34, 30),      # chair with the coat
		Rect2(150, 252, 110, 40),    # dresser
		# bathroom
		Rect2(412, 22, 64, 24),      # sink
		Rect2(486, 160, 52, 134),    # bath
		Rect2(364, 250, 30, 40),     # stool
	]
	deco = [
		{"t": "floor", "rect": Rect2(16, 16, 528, 384), "color": Color("36333f"), "plank": true},   # under the doorways too
		{"t": "floor", "rect": Rect2(16, 16, 320, 288), "color": Color("3b3a4a"), "plank": true},
		{"t": "floor", "rect": Rect2(352, 16, 192, 288), "color": Color("4a5560"), "tile": true},
		{"t": "floor", "rect": Rect2(16, 320, 528, 80), "color": Color("36333f"), "plank": true},
		{"t": "rug", "rect": Rect2(130, 120, 130, 90), "color": Color("5a2b3b")},
		{"t": "rug", "rect": Rect2(220, 336, 160, 48), "color": Color("3b4a5e")},
		{"t": "wall", "rect": Rect2(0, 0, 560, 16)}, {"t": "wall", "rect": Rect2(0, 0, 16, 416)},
		{"t": "wall", "rect": Rect2(0, 400, 560, 16)}, {"t": "wall", "rect": Rect2(544, 0, 16, 336)},
		{"t": "wall", "rect": Rect2(544, 384, 16, 32)}, {"t": "wall", "rect": Rect2(336, 16, 16, 288)},
		{"t": "wall", "rect": Rect2(16, 304, 104, 16)}, {"t": "wall", "rect": Rect2(200, 304, 200, 16)},
		{"t": "wall", "rect": Rect2(472, 304, 72, 16)},
		{"t": "window", "rect": Rect2(196, 0, 64, 16)},
		{"t": "front_door", "rect": Rect2(544, 336, 16, 48)},
		{"t": "mirror", "rect": Rect2(420, 16, 48, 6)},
		{"t": "bed", "rect": Rect2(28, 28, 64, 128)},
		{"t": "furniture", "kind": "nightstand", "rect": Rect2(96, 24, 30, 28)},
		{"t": "furniture", "kind": "chair", "rect": Rect2(224, 28, 34, 30)},
		{"t": "furniture", "kind": "dresser", "rect": Rect2(150, 252, 110, 40)},
		{"t": "furniture", "kind": "sink", "rect": Rect2(412, 22, 64, 24)},
		{"t": "furniture", "kind": "bath", "rect": Rect2(486, 160, 52, 134)},
		{"t": "furniture", "kind": "stool", "rect": Rect2(364, 250, 30, 40)},
		{"t": "item", "kind": "invitation", "pos": Vector2(111, 38)},
		{"t": "item", "kind": "coat", "pos": Vector2(241, 44)},
		{"t": "item", "kind": "note", "pos": Vector2(70, 188)},
		{"t": "item", "kind": "scarf", "pos": Vector2(500, 322)},
	]
	interacts = [
		{"id": "invitation", "pos": Vector2(111, 62), "r": 34.0, "verb": "read"},
		{"id": "coat", "pos": Vector2(241, 72), "r": 34.0, "verb": "look"},
		{"id": "note", "pos": Vector2(70, 188), "r": 30.0, "verb": "read"},
		{"id": "mirror", "pos": Vector2(444, 62), "r": 36.0, "verb": "look"},
		{"id": "scarf", "pos": Vector2(500, 344), "r": 34.0, "verb": "take"},
		{"id": "front_door", "pos": Vector2(536, 360), "r": 32.0, "verb": "door"},
	]
	lamps = []
	# the window's cold morning light falling on the bedroom floor, a candle-warm hall lamp
	light_spots = [
		{"pos": Vector2(228, 90), "color": Color("9db8ff"), "energy": 0.85, "radius": 120.0},
		{"pos": Vector2(300, 360), "color": Color("ffb45a"), "energy": 0.7, "radius": 120.0},
		{"pos": Vector2(444, 100), "color": Color("b8c8ff"), "energy": 0.55, "radius": 90.0},
	]
	spawns = {
		"bed": Vector2(60, 92),
		"bedside": Vector2(110, 100),
		"from_street": Vector2(504, 360),
	}

# ---------------------------------------------------------------- the street

func _build_street() -> void:
	indoor = false
	bounds = Rect2(0, -300, 1920, 700)
	solids = [
		Rect2(0, -300, 1740, 450),            # the north row of buildings, west of the alley
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
		{"rect": Rect2(766, 330, 140, 62), "style": "awning", "c1": Color("8a6a2a"), "c2": Color("e8dcb8")},
		{"circle": Vector2(980, 345), "r": 58.0, "style": "tree"},
		{"circle": Vector2(1600, 345), "r": 52.0, "style": "tree"},
		{"circle": Vector2(60, 353), "r": 46.0, "style": "tree"},
		{"circle": Vector2(1870, 351), "r": 44.0, "style": "tree"},
		{"rect": Rect2(1740, -300, 90, 440), "style": "alley"},
	]
	deco = [
		{"t": "floor", "rect": Rect2(0, 215, 1920, 115), "color": Color("4b4f5c"), "cobble": true},
		{"t": "floor", "rect": Rect2(0, 150, 1920, 65), "color": Color("6a6e7a"), "slab": true},
		{"t": "floor", "rect": Rect2(0, 330, 1920, 60), "color": Color("666a76"), "slab": true},
		{"t": "floor", "rect": Rect2(0, 388, 1920, 60), "color": Color("27332f"), "grass": true},
		{"t": "floor", "rect": Rect2(1740, -300, 90, 450), "color": Color("3a3d49"), "cobble": true},
		{"t": "building", "rect": Rect2(0, -300, 1740, 450), "tint": Color("3b2f36")},
		{"t": "building", "rect": Rect2(1830, -300, 90, 450), "tint": Color("352b33")},
		{"t": "window_row", "rect": Rect2(20, 70, 160, 50), "lit": false},
		{"t": "house_door", "rect": Rect2(214, 112, 36, 38)},
		{"t": "window_row", "rect": Rect2(280, 70, 150, 50), "lit": false},
		{"t": "shop_front", "rect": Rect2(450, 80, 240, 70), "name": "bakery"},
		{"t": "window_row", "rect": Rect2(730, 70, 400, 50), "lit": false},
		{"t": "shop_front", "rect": Rect2(1180, 80, 160, 70), "name": "tailor"},
		{"t": "window_row", "rect": Rect2(1380, 70, 330, 50), "lit": false},
		{"t": "fence", "rect": Rect2(30, 146, 120, 8)},
		{"t": "fence", "rect": Rect2(290, 146, 150, 8)},
		{"t": "fence", "rect": Rect2(0, 388, 1920, 10)},
		{"t": "alley_door", "rect": Rect2(1766, -300, 38, 30)},
	]
	interacts = [
		{"id": "house_door", "pos": Vector2(232, 154), "r": 26.0, "verb": "enter"},
		{"id": "alley_door", "pos": Vector2(1785, -270), "r": 30.0, "verb": "look"},
	]
	triggers = [
		{"id": "alley", "rect": Rect2(1744, -300, 82, 420)},
	]
	spawns = {
		"from_house": Vector2(232, 184),
		"start": Vector2(232, 184),
	}
	light_spots = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NPC_DATA))
	if typeof(parsed) == TYPE_DICTIONARY:
		npcs = (parsed.get("npcs", []) as Array).duplicate(true)
	else:
		push_error("Turned: cannot read " + NPC_DATA)
