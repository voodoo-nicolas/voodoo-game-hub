extends Node2D

## Draws one area (turned_area.gd) in code: mode "ground" = floors, walls, buildings, furniture,
## the shade shadows; mode "overlay" = the awnings, the porch roof and tree canopies, which sit
## above the people (see-through enough to show who is under them). Placeholder look.

const Art = preload("res://scripts/games/turned/turned_art.gd")

## Shop signs (English; translated when drawn).
const SHOP_NAMES := {"bakery": "Bakery", "tailor": "Tailor"}

var area: RefCounted = null
var mode := "ground"
## Item ids the player has taken (not drawn) and ids that still glint ("look here").
var taken := {}
var glint := {}

var _t := 0.0

func setup(a: RefCounted, m: String) -> void:
	area = a
	mode = m
	if m == "overlay":
		z_index = 20
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if mode == "ground" and not glint.is_empty():
		_t += delta
		queue_redraw()

static func _h(a: int, b: int) -> float:
	var n: int = (a * 73856093) ^ (b * 19349663)
	return float(n & 0xffff) / 65535.0

func _draw() -> void:
	if area == null:
		return
	if mode == "overlay":
		_draw_overlay()
		return
	# beyond the map (the camera shows it when a room is narrower than the screen)
	draw_rect(Rect2(-4000, -4000, 9000, 9000), Color("07080d"))
	for d in area.deco:
		match d["t"]:
			"floor": _floor(d)
			"rug": _rug(d)
			"wall": _wall(d["rect"])
			"window": _wall_window(d["rect"])
			"front_door": _front_door(d["rect"])
			"mirror": _mirror(d["rect"])
			"bed": _bed(d["rect"])
			"furniture": _furniture(d["kind"], d["rect"])
			"item": _item(d)
			"building": _building(d["rect"], d["tint"])
			"window_row": _window_row(d["rect"], bool(d["lit"]))
			"house_door": _house_door(d["rect"])
			"shop_front": _shop_front(d["rect"], str(d["name"]))
			"fence": _fence(d["rect"])
			"alley_door": _alley_door(d["rect"])
	for s in area.shades:
		_shade_ground(s)

# ---------------------------------------------------------------- floors and rooms

func _floor(d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var c: Color = d["color"]
	draw_rect(r, c)
	var line := Color(0, 0, 0, 0.16)
	if d.get("plank", false):
		var y := r.position.y + 14.0
		while y < r.end.y:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), line, 1.0)
			y += 14.0
		var row := 0
		y = r.position.y
		while y < r.end.y:
			var x := r.position.x + 40.0 + float(row % 3) * 26.0
			while x < r.end.x:
				draw_line(Vector2(x, y), Vector2(x, minf(y + 14.0, r.end.y)), line, 1.0)
				x += 78.0
			y += 14.0
			row += 1
	elif d.get("tile", false):
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.06), 1.0)
			x += 16.0
		var y2 := r.position.y
		while y2 < r.end.y:
			draw_line(Vector2(r.position.x, y2), Vector2(r.end.x, y2), Color(1, 1, 1, 0.06), 1.0)
			y2 += 16.0
	elif d.get("cobble", false):
		var cy := r.position.y
		var row2 := 0
		while cy < r.end.y:
			var cx := r.position.x + float(row2 % 2) * 9.0
			while cx < r.end.x:
				var k := _h(int(cx), int(cy))
				draw_rect(Rect2(cx + 1.0, cy + 1.0, 14.0, 6.0), Color(c.r + (k - 0.5) * 0.07, c.g + (k - 0.5) * 0.07, c.b + (k - 0.5) * 0.08))
				cx += 18.0
			cy += 9.0
			row2 += 1
	elif d.get("slab", false):
		var sx := r.position.x
		while sx < r.end.x:
			draw_line(Vector2(sx, r.position.y), Vector2(sx, r.end.y), Color(0, 0, 0, 0.14), 1.0)
			sx += 32.0
		draw_line(Vector2(r.position.x, r.position.y + r.size.y * 0.5), Vector2(r.end.x, r.position.y + r.size.y * 0.5), Color(0, 0, 0, 0.1), 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(1, 1, 1, 0.07))
	elif d.get("grass", false):
		var gx := r.position.x
		while gx < r.end.x:
			var k2 := _h(int(gx), 7)
			draw_line(Vector2(gx, r.position.y + 12 + k2 * 30), Vector2(gx + 2, r.position.y + 6 + k2 * 30), Color("3a4a3d"), 1.0)
			gx += 7.0

func _rug(d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var c: Color = d["color"]
	draw_rect(r, c)
	draw_rect(r.grow(-6), Color(c.r * 1.25, c.g * 1.25, c.b * 1.25), false, 2.0)
	draw_rect(r.grow(-14), Color(0, 0, 0, 0.12), false, 1.0)

func _wall(r: Rect2) -> void:
	draw_rect(r, Color("1a1c28"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color("3a3e52"))
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Color(0, 0, 0, 0.35))

func _wall_window(r: Rect2) -> void:
	draw_rect(r.grow(-2), Color("8fa4d8"))
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color("1a1c28"), 2.0)

func _front_door(r: Rect2) -> void:
	draw_rect(r, Color("4a3426"))
	draw_rect(r.grow(-3), Color("5a402e"), false, 2.0)
	draw_circle(Vector2(r.position.x + 4, r.get_center().y), 2.0, Color("c9a15b"))

func _mirror(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(-2, -2), r.size + Vector2(4, 8)), Color("6a5a48"))
	draw_rect(Rect2(r.position, r.size + Vector2(0, 4)), Color("a9b8cc"))

func _bed(r: Rect2) -> void:
	var t := Art.tex("bed")
	if t != null:
		draw_texture(t, r.position)
		return
	draw_rect(r, Color("2d2a3a"))
	draw_rect(r.grow(-3), Color("8a8aa0"))
	draw_rect(Rect2(r.position.x + 8, r.position.y + 8, r.size.x - 16, 24), Color("c8c8d6"))   # pillow
	draw_rect(Rect2(r.position.x + 3, r.end.y - 22, r.size.x - 6, 19), Color("3d4a68"))        # folded blanket at the foot

func _furniture(kind: String, r: Rect2) -> void:
	match kind:
		"nightstand":
			draw_rect(r, Color("4a3a30"))
			draw_rect(r.grow(-3), Color("5d4a3c"))
		"chair":
			draw_rect(r, Color("3f3026"))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 7), Color("2f241c"))
		"dresser":
			draw_rect(r, Color("4a3a30"))
			draw_rect(r.grow(-4), Color("574436"))
			for i in 3:
				draw_circle(Vector2(r.position.x + 24 + i * 31, r.position.y + r.size.y * 0.5), 2.0, Color("c9a15b"))
		"sink":
			draw_rect(r, Color("c9ccd6"))
			draw_rect(r.grow(-6), Color("8f95a8"))
			draw_circle(Vector2(r.get_center().x, r.position.y + 4), 2.5, Color("6a6f80"))
		"bath":
			draw_rect(r, Color("c9ccd6"))
			draw_rect(r.grow(-6), Color("7f8aa8"))
			draw_rect(r.grow(-6), Color("5a6482"), false, 1.0)
		"stool":
			draw_rect(r, Color("5d4a3c"))
			draw_rect(r.grow(-5), Color("6d5848"))

func _item(d: Dictionary) -> void:
	var kind: String = d["kind"]
	if taken.has(kind):
		return
	var p: Vector2 = d["pos"]
	match kind:
		"invitation":
			draw_rect(Rect2(p.x - 8, p.y - 6, 16, 11), Color("e6dcc4"))
			draw_polyline(PackedVector2Array([Vector2(p.x + 8, p.y - 6), Vector2(p.x + 4, p.y - 2), Vector2(p.x + 8, p.y + 1), Vector2(p.x + 5, p.y + 5)]), Color("5a4a38"), 1.0)
		"coat":
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 15, p.y - 6), Vector2(p.x + 15, p.y - 6), Vector2(p.x + 18, p.y + 22), Vector2(p.x - 18, p.y + 22)]), Color("1d2029"))
			draw_line(Vector2(p.x, p.y - 6), Vector2(p.x, p.y + 22), Color("0b0d14"), 1.5)
		"note":
			draw_rect(Rect2(p.x - 7, p.y - 5, 14, 10), Color("d8cfb8"))
			draw_line(Vector2(p.x - 4, p.y - 1), Vector2(p.x + 3, p.y - 1), Color("6a5a48"), 1.0)
		"scarf":
			draw_rect(Rect2(p.x - 3, p.y - 2, 6, 3), Color("3a3430"))
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 7, p.y), Vector2(p.x + 7, p.y), Vector2(p.x + 5, p.y + 18), Vector2(p.x - 5, p.y + 18)]), Art.SCARF)
	if glint.has(kind):
		var pulse := 0.5 + 0.5 * sin(_t * 3.2)
		draw_arc(p, 11.0 + pulse * 3.0, 0.0, TAU, 20, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.35 + pulse * 0.35), 1.5)

# ---------------------------------------------------------------- the street

func _building(r: Rect2, tint: Color) -> void:
	draw_rect(r, tint)
	var y0 := r.end.y - 62.0
	var y := y0
	var row := 0
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.2), 1.0)
		var x := r.position.x + float(row % 2) * 10.0
		while x < r.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 9.0, r.end.y)), Color(0, 0, 0, 0.14), 1.0)
			x += 20.0
		y += 9.0
		row += 1
	draw_rect(Rect2(r.position.x, r.end.y - 10, r.size.x, 10), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(r.position.x, r.end.y - 11, r.size.x, 1), Color(1, 1, 1, 0.08))

func _window_row(r: Rect2, lit: bool) -> void:
	var x := r.position.x
	while x + 26.0 <= r.end.x:
		Art.window(self, Rect2(x, r.position.y, 26, r.size.y), lit)
		x += 46.0

func _house_door(r: Rect2) -> void:
	draw_rect(r.grow(4), Color("2a2230"))
	draw_rect(r, Color("4a3426"))
	draw_rect(r.grow(-4), Color("5a402e"), false, 2.0)
	draw_circle(Vector2(r.end.x - 7, r.get_center().y + 4), 2.0, Color("c9a15b"))
	draw_rect(Rect2(r.position.x - 6, r.end.y, r.size.x + 12, 5), Color("56596a"))

func _shop_front(r: Rect2, shop: String) -> void:
	draw_rect(r, Color("231e28"))
	Art.window(self, Rect2(r.position.x + 12, r.position.y + 14, r.size.x * 0.5, r.size.y - 26), true)
	var door := Rect2(r.position.x + r.size.x * 0.62, r.position.y + 10, 30, r.size.y - 10)
	draw_rect(door, Color("3d2d24"))
	draw_rect(door.grow(-3), Color("4d392c"), false, 1.5)
	var font := ThemeDB.fallback_font
	var label := tr(SHOP_NAMES.get(shop, shop)).to_upper()
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_rect(Rect2(r.position.x + 6, r.position.y - 4, w + 14, 14), Color("17141b"))
	draw_string(font, Vector2(r.position.x + 13, r.position.y + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Art.AMBER)

func _fence(r: Rect2) -> void:
	var c := Color("15171f")
	draw_line(Vector2(r.position.x, r.position.y + 2), Vector2(r.end.x, r.position.y + 2), c, 2.0)
	draw_line(Vector2(r.position.x, r.end.y - 1), Vector2(r.end.x, r.end.y - 1), c, 2.0)
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), c, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, r.position.y), Vector2(x + 2, r.position.y), Vector2(x, r.position.y - 4)]), c)
		x += 8.0

func _alley_door(r: Rect2) -> void:
	draw_rect(r, Color("2a2420"))
	draw_rect(r.grow(-4), Color("3a2f28"), false, 2.0)
	draw_circle(Vector2(r.end.x - 8, r.get_center().y + 2), 2.0, Color("8a7a58"))

# ---------------------------------------------------------------- shade

func _shade_ground(s: Dictionary) -> void:
	var style: String = s.get("style", "")
	var col := Color(0.04, 0.06, 0.16, 0.34 if style == "alley" else 0.26)
	if s.has("rect"):
		draw_rect(s["rect"], col)
	else:
		draw_circle(s["circle"], float(s["r"]), col)

func _draw_overlay() -> void:
	for s in area.shades:
		var style: String = s.get("style", "")
		match style:
			"awning":
				_awning(s["rect"], s["c1"], s["c2"])
			"porch":
				_porch(s["rect"])
			"tree":
				_canopy(s["circle"], float(s["r"]))

func _awning(r: Rect2, c1: Color, c2: Color) -> void:
	var stripe := 20.0
	var x := r.position.x
	var i := 0
	while x < r.end.x:
		var w := minf(stripe, r.end.x - x)
		var c := c1 if i % 2 == 0 else c2
		draw_rect(Rect2(x, r.position.y, w, r.size.y - 8), Color(c.r, c.g, c.b, 0.58))
		draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y - 8), Vector2(x + w, r.end.y - 8), Vector2(x + w * 0.5, r.end.y)]), Color(c.r, c.g, c.b, 0.58))
		x += stripe
		i += 1
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Color(0, 0, 0, 0.4), 2.0)

func _porch(r: Rect2) -> void:
	draw_rect(r, Color(0.12, 0.13, 0.2, 0.55))
	for i in 5:
		var y := r.position.y + 6 + i * 8
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.06), 1.0)
	draw_rect(r, Color("0b0d14"), false, 2.0)

func _canopy(c: Vector2, rad: float) -> void:
	var base := Color(0.1, 0.17, 0.17, 0.78)
	draw_circle(c, rad, base)
	for i in 7:
		var a := TAU * float(i) / 7.0
		draw_circle(c + Vector2(cos(a), sin(a)) * rad * 0.55, rad * 0.5, Color(0.13, 0.22, 0.2, 0.72))
	draw_circle(c + Vector2(-rad * 0.2, -rad * 0.2), rad * 0.38, Color(0.18, 0.28, 0.24, 0.55))
