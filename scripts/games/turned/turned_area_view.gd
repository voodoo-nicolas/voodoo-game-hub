extends Node2D

## Draws one area (turned_area.gd) in code. Three layers, each its own node with a mode:
##   "ground"  = the floors, as lit shader surfaces (turned_ground.gdshader: cobbles, flagstones,
##               planks, tiles, grass), under everything
##   "decor"   = walls, buildings, rugs, furniture, items and the shade shadows
##   "overlay" = the awnings, the porch roof and tree canopies, above the people (see-through
##               enough to show who is under them)
##   "glow"    = additive halos round the lamps and a slow low mist, on top of everything

const Art = preload("res://scripts/games/turned/turned_art.gd")
const T = preload("res://scripts/games/turned/turned_tuning.gd")
const GROUND_SHADER := "res://scripts/games/turned/turned_ground.gdshader"
## Height of a house's street-side wall band (the roof is above it).
const WALL_H := 78.0

## Shop signs (English; translated when drawn).
const SHOP_NAMES := {"bakery": "Bakery", "tailor": "Tailor"}

var area: RefCounted = null
var mode := "ground"
## Item ids the player has taken (not drawn) and ids that still glint ("look here").
var taken := {}
var glint := {}

var _t := 0.0
var _halo: GradientTexture2D = null
var _decals: Array = []


func setup(a: RefCounted, m: String) -> void:
	area = a
	mode = m
	if m == "overlay":
		z_index = 20
	elif m == "glow":
		z_index = 24
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		_make_halo()
	elif m == "ground":
		_build_floors()
	elif m == "decor":
		_make_decals()
	queue_redraw()

## Each floor rectangle becomes a ColorRect with the ground shader: the shader computes the
## surface from the world position, so neighbouring rects join up without seams.
func _build_floors() -> void:
	var shader := load(GROUND_SHADER) as Shader
	if shader == null:
		return
	var n := 0
	for d in area.deco:
		if d["t"] == "floor":
			var r: Rect2 = d["rect"]
			_surface(shader, r, _floor_kind(d), d["color"], float(n) * 7.3, float(d.get("wet", 0.35)))
			n += 1
		elif d["t"] == "building":
			# slate roof above, a brick wall band below (the street side)
			var b: Rect2 = d["rect"]
			var wall := Rect2(b.position.x, b.end.y - WALL_H, b.size.x, WALL_H)
			var roof := Rect2(b.position.x, b.position.y, b.size.x, b.size.y - WALL_H)
			_surface(shader, roof, 6, d["roof"], float(n) * 5.1, 0.0)
			_surface(shader, wall, 5, d["wall"], float(n) * 3.7, 0.0)
			n += 1

## Names of painted tile textures that replace a shader surface (games/turned/art/<name>.png,
## tileable, painted at SPRITE_RATIO x), by shader kind.
const TILE_NAMES := ["ground_cobble", "ground_flagstone", "ground_planks", "ground_tile", "ground_grass", "wall_brick", "roof_slate"]

func _surface(shader: Shader, r: Rect2, kind: int, color: Color, seed: float, wet: float) -> void:
	var painted := Art.tex(TILE_NAMES[kind])
	if painted != null:
		var tiles := TextureRect.new()
		tiles.texture = painted
		tiles.stretch_mode = TextureRect.STRETCH_TILE
		tiles.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tiles.position = r.position
		tiles.size = r.size * Art.SPRITE_RATIO
		tiles.scale = Vector2.ONE / Art.SPRITE_RATIO
		add_child(tiles)
		return
	var rect := ColorRect.new()
	rect.position = r.position
	rect.size = r.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not T.b("art.use_shaders"):
		# the plain look for weak devices (art.use_shaders false): flat colours
		rect.color = color
		add_child(rect)
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("wet", wet)
	rect.material = mat
	add_child(rect)

static func _floor_kind(d: Dictionary) -> int:
	if d.get("cobble", false):
		return 0
	if d.get("slab", false):
		return 1
	if d.get("plank", false):
		return 2
	if d.get("tile", false):
		return 3
	if d.get("grass", false):
		return 4
	return 1

func refresh() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if (mode == "decor" and not glint.is_empty()) or mode == "glow":
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
	if mode == "glow":
		if T.b("art.glow_layer"):
			_draw_glow()
		return
	if mode == "ground":
		# beyond the map (the camera shows it when a room is narrower than the screen)
		draw_rect(Rect2(-4000, -4000, 9000, 9000), Color("07080d"))
		return
	_draw_decals()
	for d in area.deco:
		match d["t"]:
			"rug": _rug(d)
			"wall": _wall(d["rect"])
			"window": _wall_window(d["rect"])
			"front_door": _front_door(d["rect"], bool(d.get("flip", false)))
			"cellar_door": _cellar_door(d["rect"])
			"stairs": _stairs(d["rect"], str(d["dir"]))
			"picture": _picture(d["rect"])
			"mirror": _mirror(d["rect"])
			"bed": _bed(d["rect"])
			"furniture": _furniture(d["kind"], d["rect"])
			"item": _item(d)
			"building": _building(d["rect"])
			"window_row": _window_row(d["rect"], bool(d["lit"]))
			"house_door": _house_door(d["rect"])
			"shop_front": _shop_front(d["rect"], str(d["name"]))
			"fence": _fence(d["rect"])
			"alley_door": _alley_door(d["rect"])
	for s in area.shades:
		_shade_ground(s)

# ---------------------------------------------------------------- floors and rooms

func _rug(d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var c: Color = d["color"]
	draw_rect(r.grow(2.0), Color(0, 0, 0, 0.3))
	draw_rect(r, c)
	# a woven border, an inner field, fringes at both ends
	draw_rect(r.grow(-5), Color(c.r * 1.35, c.g * 1.3, c.b * 1.25), false, 2.0)
	draw_rect(r.grow(-9), Color(c.r * 0.7, c.g * 0.7, c.b * 0.7), true)
	var x := r.position.x + 14.0
	while x < r.end.x - 14.0:
		draw_rect(Rect2(x, r.position.y + 12.0, 6.0, r.size.y - 24.0), Color(c.r * 0.85, c.g * 0.85, c.b * 0.85, 0.5))
		x += 12.0
	draw_arc(r.get_center(), minf(r.size.x, r.size.y) * 0.28, 0.0, TAU, 28, Color(c.r * 1.5, c.g * 1.4, c.b * 1.3, 0.55), 2.0)
	for i in 14:
		var fy := r.position.y + 6.0 + i * (r.size.y - 12.0) / 13.0
		draw_line(Vector2(r.position.x - 4.0, fy), Vector2(r.position.x, fy), Color(0.8, 0.75, 0.6, 0.5), 1.0)
		draw_line(Vector2(r.end.x, fy), Vector2(r.end.x + 4.0, fy), Color(0.8, 0.75, 0.6, 0.5), 1.0)

func _wall(r: Rect2) -> void:
	# a wall seen from above: plaster top, dark edge, and its shadow falling on the floor either side
	var horizontal := r.size.x >= r.size.y
	if horizontal:
		_grad_rect(Rect2(r.position.x, r.position.y - 7.0, r.size.x, 7.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.35))
		_grad_rect(Rect2(r.position.x, r.end.y, r.size.x, 8.0), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.0))
	else:
		draw_polygon(PackedVector2Array([Vector2(r.position.x - 7.0, r.position.y), r.position, Vector2(r.position.x, r.end.y), Vector2(r.position.x - 7.0, r.end.y)]), PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)]))
		draw_polygon(PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(r.end.x + 8.0, r.position.y), Vector2(r.end.x + 8.0, r.end.y), Vector2(r.end.x, r.end.y)]), PackedColorArray([Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.4)]))
	draw_rect(r, Color("56586c"))
	draw_rect(r.grow(-2.5), Color("65677c"))
	draw_rect(r, Color("1a1c28"), false, 1.5)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.5)), Color(1, 1, 1, 0.18))

func _wall_window(r: Rect2) -> void:
	draw_rect(r.grow(1.0), Color("2a2c3a"))
	_grad_rect(r.grow(-2), Color("b8c8f0"), Color("7f94c8"))
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color("1a1c28"), 2.0)
	# a shaft of cold morning light falling across the floor
	var p := r.position
	draw_polygon(PackedVector2Array([Vector2(p.x + 4, r.end.y), Vector2(r.end.x - 4, r.end.y), Vector2(r.end.x + 92.0, r.end.y + 170.0), Vector2(p.x + 46.0, r.end.y + 170.0)]),
		PackedColorArray([Color(0.75, 0.82, 1.0, 0.2), Color(0.75, 0.82, 1.0, 0.2), Color(0.75, 0.82, 1.0, 0.0), Color(0.75, 0.82, 1.0, 0.0)]))
	draw_line(Vector2(r.get_center().x + 4.0, r.end.y), Vector2(r.get_center().x + 66.0, r.end.y + 170.0), Color(0.1, 0.12, 0.2, 0.12), 3.0)

## `flip`: the door is in a west wall, so the handle is on its east (inner) side.
func _front_door(r: Rect2, flip: bool = false) -> void:
	draw_rect(r, Color("4a3426"))
	draw_rect(r.grow(-3), Color("5a402e"), false, 2.0)
	draw_circle(Vector2(r.end.x - 4 if flip else r.position.x + 4, r.get_center().y), 2.0, Color("c9a15b"))

## The locked cellar door in a south wall: dark planks, iron bands, a big old lock.
func _cellar_door(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(-3, -4), r.size + Vector2(6, 4)), Color("14120f"))
	draw_rect(r, Color("2c2118"))
	for i in 5:
		draw_line(Vector2(r.position.x + 4.0 + i * 7.0, r.position.y), Vector2(r.position.x + 4.0 + i * 7.0, r.end.y), Color(0, 0, 0, 0.35), 1.0)
	draw_rect(Rect2(r.position.x, r.position.y + 3.0, r.size.x, 2.5), Color("4a4d58"))
	draw_rect(Rect2(r.position.x, r.end.y - 5.5, r.size.x, 2.5), Color("4a4d58"))
	draw_rect(Rect2(r.get_center().x - 4.0, r.position.y + 5.0, 8.0, 6.0), Color("2a2c34"))
	draw_circle(Vector2(r.get_center().x, r.position.y + 8.0), 1.6, Color("c9a15b"))

## Stairs seen from above: treads across the block, darker the way down, lighter the way up, a banister.
func _stairs(r: Rect2, dir: String) -> void:
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Color("2a2018"))
	var n := 6
	var w := r.size.x / float(n)
	for i in n:
		var k := float(i) / float(n - 1)
		var shade := (1.0 - k) * 0.55 + 0.45 if dir == "up" else 1.0 - k * 0.7
		var c := Color("6a5442")
		draw_rect(Rect2(r.position.x + i * w, r.position.y + 2.0, w - 1.0, r.size.y - 4.0), Color(c.r * shade, c.g * shade, c.b * shade))
		draw_line(Vector2(r.position.x + i * w, r.position.y + 2.0), Vector2(r.position.x + i * w, r.end.y - 2.0), Color(1, 1, 1, 0.10), 1.0)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3.0), Color("3a2b22"))
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), Color("3a2b22"))
	draw_rect(r, Color("14100c"), false, 1.2)

## A framed picture hung on a wall (a thin strip along the wall).
func _picture(r: Rect2) -> void:
	draw_rect(r.grow(1.0), Color("2a1f18"))
	var k := _h(int(r.position.x), int(r.position.y))
	_grad_rect(r, Color(0.28 + k * 0.2, 0.3, 0.38), Color(0.14, 0.15 + k * 0.1, 0.2))

func _mirror(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(-2, -2), r.size + Vector2(4, 8)), Color("6a5a48"))
	draw_rect(Rect2(r.position, r.size + Vector2(0, 4)), Color("a9b8cc"))

func _bed(r: Rect2) -> void:
	var t := Art.tex("bed")
	if t != null:
		draw_texture_rect(t, r, false)
		return
	draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Color("2c211b"))                                                    # wooden frame
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8.0), Color("3a2b22"))     # headboard
	var m := Rect2(r.position.x + 4.0, r.position.y + 8.0, r.size.x - 8.0, r.size.y - 12.0)
	_grad_rect(m, Color("b9bdd2"), Color("9a9fb8"))                                  # sheet
	var pil := Rect2(r.position.x + 9.0, r.position.y + 12.0, r.size.x - 18.0, 24.0)
	draw_rect(pil, Color("dcdfee"))
	_grad_rect(pil, Color(1, 1, 1, 0.0), Color(0.3, 0.3, 0.45, 0.28))
	draw_rect(pil, Color("7a7e96"), false, 1.0)
	var bl := Rect2(r.position.x + 4.0, r.end.y - 30.0, r.size.x - 8.0, 26.0)        # blanket thrown to the foot
	_grad_rect(bl, Color("4a5a80"), Color("34405e"))
	for i in 4:
		draw_line(Vector2(bl.position.x, bl.position.y + 4.0 + i * 6.0), Vector2(bl.end.x, bl.position.y + 6.0 + i * 6.0), Color(1, 1, 1, 0.08), 1.0)
	draw_rect(bl, Color("1c2438"), false, 1.2)

func _furniture(kind: String, r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.3))
	# painted art: furn_<kind>.png fills the footprint (docs/turned/ART_SPEC.md)
	var painted := Art.tex("furn_" + kind)
	if painted != null:
		draw_texture_rect(painted, r, false)
		return
	match kind:
		"nightstand":
			draw_rect(r, Color("4a382c"))
			_grad_rect(r.grow(-2), Color("6a5240"), Color("523f31"))
			draw_rect(Rect2(r.position.x + 4, r.end.y - 9, r.size.x - 8, 5), Color("34271f"))
			draw_circle(Vector2(r.end.x - 7, r.position.y + 7), 3.4, Color("d8cfa8"))       # a candle
			draw_circle(Vector2(r.end.x - 7, r.position.y + 7), 1.6, Color("ffcf7a"))
		"chair":
			draw_rect(r, Color("3a2c22"))
			_grad_rect(r.grow(-2), Color("55402f"), Color("45342a"))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6), Color("2a1f18"))
		"dresser":
			draw_rect(r, Color("46362b"))
			_grad_rect(r.grow(-2), Color("6a5442"), Color("554335"))
			for i in 3:
				var dx := r.position.x + 5.0 + i * 34.0
				draw_rect(Rect2(dx, r.position.y + 6.0, 30.0, r.size.y - 12.0), Color(0, 0, 0, 0.18), false, 1.0)
				draw_circle(Vector2(dx + 15.0, r.position.y + r.size.y * 0.5), 2.2, Color("d4a85a"))
			draw_rect(Rect2(r.position.x + 6, r.position.y - 3, 14, 4), Color("8a6a4a"))
		"sink":
			draw_rect(r, Color("d4d8e4"))
			_grad_rect(r.grow(-2), Color("eef0f8"), Color("c4c9d8"))
			draw_circle(r.get_center() + Vector2(0, 5), 12.0, Color("8f95a8"))
			draw_circle(r.get_center() + Vector2(0, 5), 9.0, Color("a9afc2"))
			draw_circle(Vector2(r.get_center().x, r.position.y + 4), 2.5, Color("6a6f80"))
		"bath":
			draw_rect(r, Color("d4d8e4"))
			draw_rect(r.grow(-5), Color("a9b4d0"))
			_grad_rect(r.grow(-7), Color("c8d2ec"), Color("8f9ec0"))
			draw_circle(Vector2(r.get_center().x, r.position.y + 12), 3.0, Color("6a6f80"))
			draw_rect(r, Color("8a90a4"), false, 1.2)
		"stool":
			draw_circle(r.get_center(), r.size.x * 0.5, Color("46362b"))
			draw_circle(r.get_center(), r.size.x * 0.5 - 3.0, Color("6a5442"))
		"wardrobe":
			draw_rect(r, Color("2e231c"))
			_grad_rect(r.grow(-2), Color("5a4636"), Color("42332a"))
			draw_line(Vector2(r.get_center().x, r.position.y + 3), Vector2(r.get_center().x, r.end.y - 3), Color(0, 0, 0, 0.45), 1.5)
			draw_rect(Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, 4), Color(1, 1, 1, 0.08))
			draw_circle(Vector2(r.get_center().x - 5, r.get_center().y + 4), 2.0, Color("d4a85a"))
			draw_circle(Vector2(r.get_center().x + 5, r.get_center().y + 4), 2.0, Color("d4a85a"))
		"candlestand":
			draw_circle(r.get_center(), r.size.x * 0.5, Color("2a2018"))
			draw_circle(r.get_center(), r.size.x * 0.5 - 2.0, Color("8a6a3a"))
			draw_circle(r.get_center(), 3.6, Color("d8cfa8"))
			draw_circle(r.get_center(), 1.8, Color("ffcf7a"))
		"toilet":
			draw_rect(Rect2(r.position.x + 3, r.position.y, r.size.x - 6, 12), Color("c4c9d8"))           # the high tank
			draw_rect(Rect2(r.position.x + 3, r.position.y, r.size.x - 6, 3), Color(1, 1, 1, 0.3))
			draw_colored_polygon(Art.ellipse_points(Vector2(r.get_center().x, r.position.y + 28), 13.0, 13.0), Color("e2e5f0"))
			draw_colored_polygon(Art.ellipse_points(Vector2(r.get_center().x, r.position.y + 29), 9.0, 9.0), Color("8f95a8"))
			draw_line(Vector2(r.get_center().x, r.position.y + 12), Vector2(r.get_center().x, r.position.y + 18), Color("6a6f80"), 1.2)
		"cabinet":
			draw_rect(r, Color("3a2c22"))
			_grad_rect(r.grow(-2), Color("55402f"), Color("42332a"))
			for i in 4:
				var bc: Color = [Color("4a7a5a"), Color("c98a3e"), Color("5a6aa8"), Color("a8a8b0")][i]
				draw_circle(Vector2(r.position.x + 7.0 + (i % 2) * 15.0, r.position.y + 9.0 + (i / 2) * 15.0), 4.0, bc)
				draw_circle(Vector2(r.position.x + 7.0 + (i % 2) * 15.0, r.position.y + 9.0 + (i / 2) * 15.0), 1.5, Color(1, 1, 1, 0.5))
		"washstand":
			draw_rect(r, Color("4a382c"))
			_grad_rect(r.grow(-2), Color("c4c9d8"), Color("a4a9b8"))                                       # marble top
			draw_circle(r.get_center() + Vector2(-3, 4), 11.0, Color("8f95a8"))                            # the bowl
			draw_circle(r.get_center() + Vector2(-3, 4), 8.5, Color("5a7aa8"))
			draw_circle(Vector2(r.end.x - 7, r.position.y + 9), 5.0, Color("5a7aa8"))                      # the jug
			draw_circle(Vector2(r.end.x - 7, r.position.y + 9), 2.5, Color("a9c4e8"))
		"towelrail":
			draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color("8a6a3a"), 2.5)
			draw_circle(Vector2(r.get_center().x, r.position.y), 3.0, Color("c9a15b"))
			draw_circle(Vector2(r.get_center().x, r.end.y), 3.0, Color("c9a15b"))
		"plant":
			draw_circle(r.get_center(), r.size.x * 0.5, Color("3a2c22"))
			for i in 7:
				var a := TAU * float(i) / 7.0
				draw_colored_polygon(Art.ellipse_points(r.get_center() + Vector2(cos(a), sin(a)) * 8.0, 7.0, 4.0), Color("2f5a3e"))
			draw_circle(r.get_center(), 4.0, Color("3f7a52"))
		"clock":
			draw_rect(r, Color("2a1f18"))
			_grad_rect(r.grow(-2), Color("55402f"), Color("3a2c22"))
			draw_circle(Vector2(r.get_center().x, r.position.y + 9), 6.0, Color("d8cfa8"))                # the face
			draw_line(Vector2(r.get_center().x, r.position.y + 9), Vector2(r.get_center().x + 3, r.position.y + 6), Color("14161f"), 1.2)
			draw_line(Vector2(r.get_center().x, r.position.y + 9), Vector2(r.get_center().x - 1, r.position.y + 13), Color("14161f"), 1.2)
			draw_line(Vector2(r.get_center().x, r.position.y + 17), Vector2(r.get_center().x, r.end.y - 4), Color("c9a15b"), 1.5)   # the pendulum
		"desk":
			draw_rect(r, Color("2e231c"))
			_grad_rect(r.grow(-2), Color("5a4636"), Color("46362b"))
			draw_rect(r.grow(-8), Color("2f4a3a"))                                                         # leather inlay
			draw_rect(Rect2(r.position.x + 14, r.position.y + 9, 14, 10), Color("d8cfb8"))                 # papers
			draw_rect(Rect2(r.position.x + 18, r.position.y + 12, 14, 10), Color("e6dcc4"))
			draw_circle(Vector2(r.end.x - 14, r.position.y + 12), 3.0, Color("14161f"))                    # inkwell
		"bookshelf":
			draw_rect(r, Color("2a1f18"))
			var x := r.position.x + 2.0
			var i := 0
			while x < r.end.x - 4.0:
				var k := _h(int(r.position.x) + i * 7, 3)
				var bw := 3.0 + k * 3.0
				var bc := Color(0.25 + k * 0.4, 0.18 + k * 0.2, 0.16 + (1.0 - k) * 0.3)
				draw_rect(Rect2(x, r.position.y + 2.0, bw, r.size.y - 4.0), bc)
				draw_line(Vector2(x, r.position.y + 2.0), Vector2(x, r.end.y - 2.0), Color(0, 0, 0, 0.35), 1.0)
				x += bw + 0.5
				i += 1
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), Color(1, 1, 1, 0.1))
		"globe":
			draw_circle(r.get_center(), r.size.x * 0.5, Color("2a1f18"))
			draw_circle(r.get_center(), r.size.x * 0.5 - 3.0, Color("3e5a7a"))
			draw_colored_polygon(Art.ellipse_points(r.get_center() + Vector2(-2, -1), 5.0, 4.0), Color("5a7a52"))
			draw_circle(r.get_center() + Vector2(-4, -5), 3.0, Color(1, 1, 1, 0.16))
		"armchair":
			draw_rect(r, Color("3a1f26"))
			_grad_rect(r.grow(-3), Color("6a3040"), Color("4a2230"))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8), Color("2e1820"))                     # the back
			draw_rect(Rect2(r.position.x, r.position.y + 8, 7, r.size.y - 8), Color("2e1820"))             # the arms
			draw_rect(Rect2(r.end.x - 7, r.position.y + 8, 7, r.size.y - 8), Color("2e1820"))
		"floorlamp":
			draw_circle(r.get_center(), r.size.x * 0.5 + 6.0, Color(1.0, 0.7, 0.35, 0.18))
			draw_circle(r.get_center(), r.size.x * 0.5, Color("8a6a3a"))
			draw_circle(r.get_center(), r.size.x * 0.5 - 3.0, Color("ffcf7a"))
		"fireplace":
			draw_rect(r, Color("3a3d4a"))
			draw_rect(r.grow(-6), Color("14120f"))
			_grad_rect(Rect2(r.position.x + 12, r.position.y + 12, r.size.x - 24, r.size.y - 14), Color("5a2a14"), Color("b8541e"))
			draw_circle(Vector2(r.get_center().x - 10, r.end.y - 6), 3.0, Color("ffcf7a"))
			draw_circle(Vector2(r.get_center().x + 6, r.end.y - 5), 2.4, Color("ff9a4a"))
			draw_rect(Rect2(r.position.x - 3, r.position.y + r.size.y - 4, r.size.x + 6, 4), Color("4a4d5a"))   # the hearth stone
		"sofa":
			draw_rect(r, Color("2e2a3a"))
			_grad_rect(r.grow(-3), Color("4e5a7a"), Color("38425e"))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 9), Color("262234"))
			draw_rect(Rect2(r.position.x, r.position.y + 9, 8, r.size.y - 9), Color("262234"))
			draw_rect(Rect2(r.end.x - 8, r.position.y + 9, 8, r.size.y - 9), Color("262234"))
			draw_line(Vector2(r.get_center().x, r.position.y + 10), Vector2(r.get_center().x, r.end.y - 4), Color(0, 0, 0, 0.3), 1.0)
		"piano":
			draw_rect(r, Color("0e0e14"))
			_grad_rect(r.grow(-2), Color("2a2a36"), Color("14141c"))
			draw_rect(Rect2(r.end.x - 11, r.position.y + 4, 8, r.size.y - 8), Color("e6e2d4"))             # the keys face east
			var ky := r.position.y + 4.0
			while ky < r.end.y - 6.0:
				draw_line(Vector2(r.end.x - 11, ky), Vector2(r.end.x - 3, ky), Color(0, 0, 0, 0.5), 1.0)
				ky += 4.5
			draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 3, r.size.y - 6), Color(1, 1, 1, 0.1))
		"stove":
			draw_rect(r, Color("14141a"))
			_grad_rect(r.grow(-2), Color("2e2e38"), Color("1c1c24"))
			for i in 2:
				draw_circle(Vector2(r.position.x + 15.0 + i * 28.0, r.position.y + 20.0), 9.0, Color("0c0c10"))
				draw_circle(Vector2(r.position.x + 15.0 + i * 28.0, r.position.y + 20.0), 6.0, Color("2a1c18"))
			draw_rect(Rect2(r.end.x - 12, r.position.y - 3, 8, 6), Color("3a3d4a"))                        # the flue
		"basin":
			draw_rect(r, Color("5a4a3a"))
			_grad_rect(r.grow(-2), Color("8a8e9a"), Color("6a6e7a"))
			draw_rect(Rect2(r.position.x + 8, r.position.y + 5, r.size.x - 16, r.size.y - 10), Color("4a5a6a"))
			draw_circle(Vector2(r.get_center().x, r.position.y + 3), 2.5, Color("c9a15b"))
		"shelves":
			draw_rect(r, Color("2a1f18"))
			var jy := r.position.y + 6.0
			var j := 0
			while jy < r.end.y - 6.0:
				var jc: Color = [Color("8a3a3a"), Color("c98a3e"), Color("5a7a4a"), Color("6a4a7a")][j % 4]
				draw_circle(Vector2(r.get_center().x, jy), 5.0, jc)
				draw_circle(Vector2(r.get_center().x - 1.5, jy - 1.5), 1.6, Color(1, 1, 1, 0.35))
				jy += 12.0
				j += 1
		"table":
			draw_rect(r, Color("3a2c22"))
			_grad_rect(r.grow(-2), Color("6a5442"), Color("55402f"))
			if r.size.x > 60.0:                                                                            # two cups: one full, one clean
				draw_circle(Vector2(r.position.x + 22, r.get_center().y), 5.0, Color("d8d4c8"))
				draw_circle(Vector2(r.position.x + 22, r.get_center().y), 3.2, Color("4a2a1a"))
				draw_circle(Vector2(r.end.x - 22, r.get_center().y), 5.0, Color("d8d4c8"))
				draw_circle(Vector2(r.end.x - 22, r.get_center().y), 3.2, Color("e8e4d8"))
			else:
				draw_circle(r.get_center(), 3.4, Color("d8cfa8"))                                          # a candle
				draw_circle(r.get_center(), 1.6, Color("ffcf7a"))
		"cupboard":
			draw_rect(r, Color("2e231c"))
			_grad_rect(r.grow(-2), Color("5a4636"), Color("42332a"))
			draw_line(Vector2(r.get_center().x, r.position.y + 3), Vector2(r.get_center().x, r.end.y - 3), Color(0, 0, 0, 0.45), 1.5)
			draw_colored_polygon(Art.ellipse_points(Vector2(r.position.x + 14, r.position.y + 12), 8.0, 4.5), Color("a8783a"))   # a loaf
		"console":
			draw_rect(r, Color("2e231c"))
			_grad_rect(r.grow(-2), Color("5a4636"), Color("46362b"))
			draw_circle(Vector2(r.position.x + 16, r.get_center().y), 6.0, Color("a9afc2"))                # a silver tray
			draw_circle(Vector2(r.end.x - 14, r.get_center().y), 4.0, Color("3a5a6a"))                     # a vase
		"coatstand":
			draw_circle(r.get_center(), r.size.x * 0.5, Color("2a1f18"))
			draw_circle(r.get_center(), 3.5, Color("5a4636"))
			for i in 4:
				var a := TAU * float(i) / 4.0 + 0.4
				draw_line(r.get_center(), r.get_center() + Vector2(cos(a), sin(a)) * 8.0, Color("c9a15b"), 1.4)

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
		"towel":
			draw_rect(Rect2(p.x - 7, p.y - 6, 14, 28), Color("d8d4c8"))
			draw_rect(Rect2(p.x - 7, p.y + 10, 14, 12), Color("8a3a32"))
			draw_circle(Vector2(p.x - 1, p.y + 14), 3.0, Color("5a1a1c"))
			draw_rect(Rect2(p.x - 7, p.y - 6, 14, 28), Color("6a6a70"), false, 1.0)
		"scarf":
			draw_rect(Rect2(p.x - 3, p.y - 2, 6, 3), Color("3a3430"))
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 7, p.y), Vector2(p.x + 7, p.y), Vector2(p.x + 5, p.y + 18), Vector2(p.x - 5, p.y + 18)]), Art.SCARF)
	if glint.has(kind):
		var pulse := 0.5 + 0.5 * sin(_t * 3.2)
		draw_arc(p, 11.0 + pulse * 3.0, 0.0, TAU, 20, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.35 + pulse * 0.35), 1.5)

# ---------------------------------------------------------------- the street

## A vertical gradient rectangle (top colour to bottom colour).
func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

## What sits on a house besides its surfaces: the eave over the wall, the stone plinth, the
## shadow the wall throws on the pavement, the roof ridge, chimneys.
func _building(r: Rect2, _tint_unused: Color = Color.WHITE) -> void:
	var wall_top := r.end.y - WALL_H
	# eave: a dark overhang with a lit lip, and its shadow down the wall
	draw_rect(Rect2(r.position.x, wall_top - 7.0, r.size.x, 7.0), Color("171a24"))
	draw_rect(Rect2(r.position.x, wall_top - 7.0, r.size.x, 1.5), Color(1, 1, 1, 0.14))
	_grad_rect(Rect2(r.position.x, wall_top, r.size.x, 16.0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.0))
	# ground-floor plinth in stone, and the darkness gathering at the foot of the wall
	draw_rect(Rect2(r.position.x, r.end.y - 9.0, r.size.x, 9.0), Color("3a3d4a"))
	draw_rect(Rect2(r.position.x, r.end.y - 9.0, r.size.x, 1.5), Color(1, 1, 1, 0.12))
	# party wall between houses
	draw_rect(Rect2(r.position.x - 1.5, wall_top - 7.0, 3.0, WALL_H + 7.0), Color("141620"))
	# the shadow of the wall on the pavement
	_grad_rect(Rect2(r.position.x, r.end.y, r.size.x, 15.0), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.0))
	# roof: ridge line down the middle of the visible roof, chimneys
	if r.end.y - r.position.y > 200.0:
		var ridge := wall_top - 70.0
		draw_rect(Rect2(r.position.x, ridge, r.size.x, 4.0), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(r.position.x, ridge + 4.0, r.size.x, 2.0), Color(1, 1, 1, 0.1))
		var cx := r.position.x + 30.0
		var i := 0
		while cx < r.end.x - 40.0:
			var k := _h(int(r.position.x) + i * 31, 5)
			_chimney(Vector2(cx + k * 30.0, wall_top - 28.0 - k * 22.0))
			cx += 120.0 + k * 60.0
			i += 1

func _chimney(p: Vector2) -> void:
	# seen from above: a brick box, its top lit, a dark flue, a long soft shadow to the lower left
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 8), p + Vector2(9, 8), p + Vector2(-22, 30), p + Vector2(-40, 30)]), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(p + Vector2(-9, -9), Vector2(18, 18)), Color("5e3f3c"))
	draw_rect(Rect2(p + Vector2(-9, -9), Vector2(18, 18)), Color("22171a"), false, 1.5)
	draw_rect(Rect2(p + Vector2(-6, -6), Vector2(12, 12)), Color("100c0e"))
	draw_rect(Rect2(p + Vector2(-9, -9), Vector2(18, 2.5)), Color(1, 1, 1, 0.18))

## A row of windows: stone lintel, frame, a sky-reflecting or lit pane, mullions, sill.
func _window_row(r: Rect2, _lit_unused: bool) -> void:
	var x := r.position.x
	while x + 24.0 <= r.end.x:
		var lit := _h(int(x), int(r.position.y)) > 0.72
		_window(Rect2(x, r.position.y, 24.0, r.size.y), lit)
		x += 46.0

func _window(r: Rect2, lit: bool) -> void:
	draw_rect(Rect2(r.position.x - 4.0, r.position.y - 6.0, r.size.x + 8.0, 5.0), Color("2b2d38"))             # lintel
	draw_rect(Rect2(r.position.x - 4.0, r.position.y - 6.0, r.size.x + 8.0, 1.2), Color(1, 1, 1, 0.14))
	draw_rect(r.grow(2.0), Color("14161f"))                                                                    # frame
	if lit:
		_grad_rect(r, Color(1.0, 0.74, 0.36, 0.95), Color(0.9, 0.5, 0.2, 0.9))
		draw_rect(Rect2(r.position.x + 3.0, r.position.y + 6.0, 6.0, r.size.y - 12.0), Color(0.45, 0.25, 0.12, 0.5))   # a curtain
	else:
		_grad_rect(r, Color("5a6c8c"), Color("1d2538"))
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(2, 2), r.position + Vector2(10, 2), r.position + Vector2(3, r.size.y - 4), r.position + Vector2(2, r.size.y - 4)]), Color(1, 1, 1, 0.1))
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color("14161f"), 1.8)
	draw_line(Vector2(r.position.x, r.position.y + r.size.y * 0.42), Vector2(r.end.x, r.position.y + r.size.y * 0.42), Color("14161f"), 1.8)
	draw_rect(Rect2(r.position.x - 3.0, r.end.y + 1.0, r.size.x + 6.0, 3.5), Color("3a3d4a"))                    # sill
	draw_rect(Rect2(r.position.x - 3.0, r.end.y + 1.0, r.size.x + 6.0, 1.0), Color(1, 1, 1, 0.16))
	if lit:
		_grad_rect(Rect2(r.position.x - 6.0, r.end.y + 4.0, r.size.x + 12.0, 12.0), Color(1.0, 0.7, 0.35, 0.16), Color(1.0, 0.7, 0.35, 0.0))

func _house_door(r: Rect2) -> void:
	# stone steps and a threshold, the frame, a panelled door, a fanlight, a lantern
	draw_rect(Rect2(r.position.x - 8.0, r.end.y - 2.0, r.size.x + 16.0, 5.0), Color("5a5d6c"))
	draw_rect(Rect2(r.position.x - 5.0, r.end.y + 2.0, r.size.x + 10.0, 4.0), Color("4d5060"))
	draw_rect(Rect2(r.position.x - 5.0, r.position.y - 9.0, r.size.x + 10.0, r.size.y + 9.0), Color("1a1822"))
	draw_rect(Rect2(r.position.x - 5.0, r.position.y - 9.0, r.size.x + 10.0, 3.0), Color("3a3d4a"))
	draw_rect(r, Color("4a3426"))
	_grad_rect(r, Color(1, 1, 1, 0.07), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(r.position.x + 4.0, r.position.y + 4.0, r.size.x * 0.5 - 6.0, r.size.y * 0.42), Color("3a281c"))
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 + 2.0, r.position.y + 4.0, r.size.x * 0.5 - 6.0, r.size.y * 0.42), Color("3a281c"))
	draw_rect(Rect2(r.position.x + 4.0, r.position.y + r.size.y * 0.55, r.size.x - 8.0, r.size.y * 0.38), Color("3a281c"))
	draw_circle(Vector2(r.end.x - 7.0, r.get_center().y + 4.0), 2.0, Color("d4a85a"))
	# the lantern beside it
	draw_rect(Rect2(r.end.x + 8.0, r.position.y + 2.0, 6.0, 9.0), Color("1d2029"))
	draw_rect(Rect2(r.end.x + 9.0, r.position.y + 3.5, 4.0, 6.0), Art.AMBER)
	draw_circle(Vector2(r.end.x + 11.0, r.position.y + 6.5), 11.0, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.16))

func _shop_front(r: Rect2, shop: String) -> void:
	draw_rect(r, Color("1c1822"))
	draw_rect(Rect2(r.position.x, r.position.y - 4.0, r.size.x, 4.0), Color("2a2430"))
	var win := Rect2(r.position.x + 12.0, r.position.y + 16.0, r.size.x * 0.5, r.size.y - 30.0)
	draw_rect(win.grow(3.0), Color("0f0d14"))
	_grad_rect(win, Color(1.0, 0.8, 0.45, 0.95), Color(0.75, 0.42, 0.18, 0.95))
	# shelves and goods silhouetted against the glow
	for i in 3:
		var sy := win.position.y + 10.0 + i * (win.size.y / 3.2)
		draw_rect(Rect2(win.position.x, sy + 8.0, win.size.x, 2.0), Color(0.25, 0.14, 0.07, 0.8))
		var gx := win.position.x + 8.0
		while gx < win.end.x - 10.0:
			var k := _h(int(gx), i + int(r.position.x))
			draw_rect(Rect2(gx, sy + 8.0 - 4.0 - k * 5.0, 8.0 + k * 6.0, 4.0 + k * 5.0), Color(0.3, 0.17, 0.08, 0.7))
			gx += 14.0 + k * 8.0
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("0f0d14"), 2.0)
	_grad_rect(Rect2(win.position.x - 8.0, win.end.y + 3.0, win.size.x + 16.0, 14.0), Color(1.0, 0.7, 0.35, 0.18), Color(1.0, 0.7, 0.35, 0.0))
	var door := Rect2(r.position.x + r.size.x * 0.62, r.position.y + 12.0, 30.0, r.size.y - 12.0)
	draw_rect(door.grow(2.0), Color("0f0d14"))
	draw_rect(door, Color("3d2d24"))
	_grad_rect(Rect2(door.position.x + 4.0, door.position.y + 4.0, door.size.x - 8.0, door.size.y * 0.4), Color(1.0, 0.78, 0.42, 0.7), Color(0.8, 0.5, 0.25, 0.7))
	draw_circle(Vector2(door.end.x - 5.0, door.get_center().y + 6.0), 1.8, Color("d4a85a"))
	var font := ThemeDB.fallback_font
	var label := tr(SHOP_NAMES.get(shop, shop)).to_upper()
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var sign_r := Rect2(r.position.x + 6.0, r.position.y - 17.0, w + 18.0, 15.0)
	draw_rect(sign_r, Color("14111a"))
	draw_rect(sign_r, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.5), false, 1.0)
	draw_string(font, sign_r.position + Vector2(9, 11.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Art.AMBER)

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
	var drop := 9.0
	while x < r.end.x:
		var w := minf(stripe, r.end.x - x)
		var c := c1 if i % 2 == 0 else c2
		var top := Color(c.r * 1.1, c.g * 1.1, c.b * 1.1, 0.5)
		var bot := Color(c.r * 0.72, c.g * 0.72, c.b * 0.72, 0.5)
		_grad_rect(Rect2(x, r.position.y, w, r.size.y - drop), top, bot)
		draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y - drop), Vector2(x + w, r.end.y - drop), Vector2(x + w * 0.5, r.end.y)]), bot)
		draw_line(Vector2(x, r.end.y - drop), Vector2(x + w * 0.5, r.end.y), Color(0, 0, 0, 0.25), 1.0)
		draw_line(Vector2(x + w, r.end.y - drop), Vector2(x + w * 0.5, r.end.y), Color(0, 0, 0, 0.25), 1.0)
		x += stripe
		i += 1
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Color(0, 0, 0, 0.45), 2.0)
	draw_line(Vector2(r.position.x, r.position.y + 1.5), Vector2(r.end.x, r.position.y + 1.5), Color(1, 1, 1, 0.14), 1.0)

func _porch(r: Rect2) -> void:
	# a small slate roof over the door: two pitches, a ridge, its shadow on the step
	var mid := r.position.x + r.size.x * 0.5
	var a := Color(0.16, 0.18, 0.26, 0.86)
	var b := Color(0.1, 0.11, 0.17, 0.86)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x * 0.5, r.size.y), a)
	draw_rect(Rect2(mid, r.position.y, r.size.x * 0.5, r.size.y), b)
	for i in 5:
		var y := r.position.y + 6.0 + i * 8.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.07), 1.0)
	draw_rect(Rect2(mid - 1.5, r.position.y, 3.0, r.size.y), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), Color("0b0d14"))
	for px in [r.position.x + 3.0, r.end.x - 3.0]:
		draw_circle(Vector2(px, r.end.y - 3.0), 2.6, Color("0b0d14"))
	_grad_rect(Rect2(r.position.x, r.end.y, r.size.x, 12.0), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.0))

func _canopy(c: Vector2, rad: float) -> void:
	var painted := Art.tex("tree_canopy")
	if painted != null:
		draw_texture_rect(painted, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, Color(1, 1, 1, 0.88))
		return
	# a tree seen from above: dark underside, then layers of leaf clusters lit from the upper left
	draw_circle(c + Vector2(3, 4), rad * 1.02, Color(0.02, 0.05, 0.06, 0.4))
	draw_circle(c, rad, Color(0.07, 0.14, 0.13, 0.82))
	var seed := int(c.x) * 7 + int(c.y)
	for layer in 3:
		var n := 9 - layer * 2
		var rr := rad * (0.62 - layer * 0.14)
		var cr := rad * (0.46 - layer * 0.08)
		var lift := float(layer)
		for i in n:
			var k := _h(seed + i * 13, layer * 5 + 1)
			var a := TAU * (float(i) + k * 0.6) / float(n)
			var p := c + Vector2(cos(a), sin(a)) * rr + Vector2(-lift * 2.0, -lift * 3.0)
			var g := 0.16 + layer * 0.07 + k * 0.05
			draw_circle(p, cr, Color(g * 0.55, g * 1.05, g * 0.8, 0.8))
			draw_circle(p + Vector2(-cr * 0.25, -cr * 0.3), cr * 0.5, Color(g * 0.8, g * 1.5, g * 1.05, 0.5))
	for i in 26:
		var a2 := _h(seed + i * 3, 77) * TAU
		var d := sqrt(_h(seed + i * 5, 99)) * rad * 0.86
		draw_circle(c + Vector2(cos(a2), sin(a2)) * d, 1.6, Color(0.5, 0.65, 0.45, 0.5))


# ---------------------------------------------------------------- street details on the ground

## Puddles, manholes, leaves and kerb stones, placed once from fixed numbers (same every run).
func _make_decals() -> void:
	_decals = []
	if area.id != "street":
		return
	for i in 26:
		var x := 40.0 + _h(i, 1) * 1840.0
		var y := 232.0 + _h(i, 2) * 84.0
		_decals.append({"t": "puddle", "p": Vector2(x, y), "rx": 12.0 + _h(i, 3) * 26.0, "ry": 4.0 + _h(i, 4) * 6.0})
	for i in 8:
		_decals.append({"t": "puddle", "p": Vector2(30.0 + _h(i, 11) * 1860.0, 340.0 + _h(i, 12) * 40.0), "rx": 10.0 + _h(i, 13) * 18.0, "ry": 3.0 + _h(i, 14) * 4.0})
	for mp in [Vector2(520, 268), Vector2(1450, 298), Vector2(1785, 40)]:
		_decals.append({"t": "manhole", "p": mp})
	for i in 70:
		var on_walk := _h(i, 21) > 0.4
		var y2 := (160.0 + _h(i, 22) * 48.0) if on_walk else (334.0 + _h(i, 23) * 50.0)
		_decals.append({"t": "leaf", "p": Vector2(10.0 + _h(i, 24) * 1900.0, y2), "a": _h(i, 25) * TAU, "k": _h(i, 26)})
	for i in 40:
		_decals.append({"t": "leaf", "p": Vector2(1745.0 + _h(i, 31) * 80.0, -290.0 + _h(i, 32) * 430.0), "a": _h(i, 33) * TAU, "k": _h(i, 34)})

func _draw_decals() -> void:
	if area.id != "street" or not T.b("art.decals"):
		return
	# kerbs: a lit stone edge and a dark gutter on both sides of the road
	for ky in [212.0, 329.0]:
		draw_rect(Rect2(0, ky, 1920, 4), Color(0.62, 0.64, 0.72, 0.55))
		draw_rect(Rect2(0, ky + 4.0, 1920, 3), Color(0, 0, 0, 0.35))
	for d in _decals:
		match d["t"]:
			"puddle":
				var p: Vector2 = d["p"]
				var rx: float = d["rx"]
				var ry: float = d["ry"]
				draw_colored_polygon(Art.ellipse_points(p, rx + 1.5, ry + 1.0), Color(0.03, 0.05, 0.1, 0.35))
				draw_colored_polygon(Art.ellipse_points(p, rx, ry * 0.8), Color(0.2, 0.28, 0.42, 0.38))
				draw_colored_polygon(Art.ellipse_points(p + Vector2(-rx * 0.15, -ry * 0.2), rx * 0.6, ry * 0.4), Color(0.55, 0.65, 0.82, 0.22))
			"manhole":
				var q: Vector2 = d["p"]
				draw_circle(q, 12.0, Color("14161e"))
				draw_circle(q, 10.0, Color("2a2d3a"))
				for k in 4:
					draw_line(q + Vector2(-8, -6 + k * 4.0), q + Vector2(8, -6 + k * 4.0), Color("14161e"), 1.0)
				draw_arc(q, 10.0, 0.0, TAU, 18, Color(1, 1, 1, 0.12), 1.0)
			"leaf":
				var lp: Vector2 = d["p"]
				var kk: float = d["k"]
				var col := Color(0.42 + kk * 0.3, 0.26 + kk * 0.12, 0.1, 0.8) if kk > 0.3 else Color(0.28, 0.32, 0.18, 0.8)
				draw_set_transform(lp, float(d["a"]), Vector2(1.0, 0.55))
				draw_circle(Vector2.ZERO, 2.4, col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- glow and mist (additive)

func _make_halo() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	_halo = GradientTexture2D.new()
	_halo.gradient = g
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)
	_halo.width = 128
	_halo.height = 128

func _draw_glow() -> void:
	if _halo == null:
		return
	# lamp heads: a bright core and a wide soft bloom
	for lp in area.lamps:
		var head: Vector2 = lp + Vector2(0, -28)
		var flick := 0.92 + 0.08 * sin(_t * 6.0 + lp.x * 0.3)
		draw_texture_rect(_halo, Rect2(head - Vector2(46, 46), Vector2(92, 92)), false, Color(1.0, 0.66, 0.28, 0.34 * flick))
		draw_texture_rect(_halo, Rect2(head - Vector2(14, 14), Vector2(28, 28)), false, Color(1.0, 0.86, 0.55, 0.7 * flick))
	# lit windows and shop glass spill a little warmth
	for d in area.deco:
		if d["t"] == "shop_front":
			var r: Rect2 = d["rect"]
			draw_texture_rect(_halo, Rect2(r.position.x - 10.0, r.position.y + 6.0, r.size.x * 0.7 + 40.0, r.size.y + 70.0), false, Color(1.0, 0.7, 0.35, 0.16))
	# a slow low mist drifting along the street
	if area.id == "street":
		for i in 7:
			var x := fposmod(float(i) * 330.0 + _t * (5.0 + i), 2400.0) - 240.0
			var y := 250.0 + sin(_t * 0.15 + i * 2.1) * 60.0 + float(i % 3) * 40.0
			draw_texture_rect(_halo, Rect2(x - 260.0, y - 40.0, 520.0, 80.0), false, Color(0.5, 0.6, 0.8, 0.035))
