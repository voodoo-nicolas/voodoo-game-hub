extends RefCounted

## Art for Turned, drawn in code (cold greys and blues, warm amber for lamps) with outlines,
## shading and lighting. Real art swaps in by file name: if `res://games/turned/art/<name>.png`
## exists, `sprite(...)` draws it instead of the shapes (docs/turned/ART_SPEC.md: names, sizes,
## anchors, how to paint them). PNGs are painted at SPRITE_RATIO pixels per world pixel, so they
## stay sharp when the camera zooms in. Every file added there also needs a media/CREDITS.json
## entry (hub.py check).

const ART_DIR := "res://games/turned/art/"
## Sprites are painted at this many PNG pixels per world pixel (1 m = 32 world px).
const SPRITE_RATIO := 2.0
## People are drawn this much bigger than the first placeholder (35 px tall -> 46 px: the middle between
## it and the 58 px of the owner's reference). Painted people (`person` sprites) are drawn into a canvas
## PERSON_CANVAS_H world px tall whatever their resolution, so a 1024 x 1024 PNG works as well as 128 x 128
## (the figure fills ~72% of the canvas, feet at 92%).
const PERSON_SCALE := 1.3
const PERSON_CANVAS_H := 64.0

const AMBER := Color("ffb45a")
const AMBER_DIM := Color("c98a3e")
const INK := Color("0b0d14")
const BLOOD := Color("8a1c2b")
const BLOOD_BRIGHT := Color("c4283c")
const SKIN_PALE := Color("cfc3c6")
const PLAYER_COAT := Color("3f4f6e")
const PLAYER_COAT_DARK := Color("2c3750")
const SCARF := Color("8d8f98")

static var _cache := {}

## The swapped-in texture for `name`, or null (then the caller draws its placeholder).
static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D = null
	var path := ART_DIR + name + ".png"
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[name] = t
	return t

## Draws `name.png` with its anchor (fractions of its size) at the origin; false if there is none.
## `canvas_h` > 0 draws it that many world px tall (any PNG resolution), else at SPRITE_RATIO.
static func sprite(ci: CanvasItem, name: String, anchor: Vector2, alpha: float = 1.0, flip: bool = false, canvas_h: float = 0.0) -> bool:
	var t := tex(name)
	if t == null:
		return false
	var size := t.get_size() / SPRITE_RATIO
	if canvas_h > 0.0:
		size = t.get_size() * (canvas_h / t.get_size().y)
	if flip:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	ci.draw_texture_rect(t, Rect2(-size * anchor, size), false, Color(1, 1, 1, alpha))
	if flip:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

static func ellipse_points(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	ci.draw_colored_polygon(ellipse_points(c, rx, ry), color)

static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, alpha: float = 0.3) -> void:
	ellipse(ci, c, rx, ry, Color(0, 0, 0, alpha))

static func tinted(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

## One simple person, feet at the origin. `look`: coat, hat, skin, accent (hex strings).
## `face` is the way they look; `walk` advances the leg swing; `sneak` crouches them.
## Dark outlines, a lit upper-left and a shaded underside give the flat shapes some weight.
static func person(ci: CanvasItem, look: Dictionary, face: Vector2, walk: float = 0.0, sneak: bool = false,
		scarf: bool = false, sprite_name: String = "", alpha: float = 1.0) -> void:
	if sprite_name != "":
		# painted art: a sprite per direction (name_down / name_up / name_side, side faces right and
		# is mirrored for left), else a single name.png
		var dir := "down" if face.y > 0.35 else ("up" if face.y < -0.35 else "side")
		if sprite(ci, sprite_name + "_" + dir, Vector2(0.5, 0.92), alpha, dir == "side" and face.x < 0.0, PERSON_CANVAS_H):
			return
		if sprite(ci, sprite_name, Vector2(0.5, 0.92), alpha, false, PERSON_CANVAS_H):
			return
	var coat := Color(str(look.get("coat", "3f4f6e")))
	var skin := Color(str(look.get("skin", "cfc3c6")))
	var accent := Color(str(look.get("accent", "8d8f98")))
	var hat := str(look.get("hat", ""))
	var line := Color(0.04, 0.04, 0.07, 0.85 * alpha)
	coat.a = alpha
	skin.a = alpha
	var squash := 0.88 if sneak else 1.0
	ci.draw_set_transform(Vector2(0, 0), 0.0, Vector2(PERSON_SCALE, squash * PERSON_SCALE))
	shadow(ci, Vector2(1, 2), 12.0, 5.5, 0.34 * alpha)
	var swing := sin(walk) * 3.2
	var leg := Color(0.1, 0.1, 0.14, alpha)
	ci.draw_rect(Rect2(-5.5, -9 + swing * 0.5, 4.5, 11), leg)
	ci.draw_rect(Rect2(1.0, -9 - swing * 0.5, 4.5, 11), leg)
	ci.draw_rect(Rect2(-6.0, 0.5 + swing * 0.5, 5.5, 2.5), Color(0.06, 0.05, 0.07, alpha))      # shoes
	ci.draw_rect(Rect2(0.5, 0.5 - swing * 0.5, 5.5, 2.5), Color(0.06, 0.05, 0.07, alpha))
	# arms: coat-coloured sleeves to the hands
	var arm_l := Vector2(-9.5, -13.5 + swing * 0.4)
	var arm_r := Vector2(9.5, -13.5 - swing * 0.4)
	ci.draw_line(Vector2(-7, -19), arm_l, line, 5.4)
	ci.draw_line(Vector2(7, -19), arm_r, line, 5.4)
	ci.draw_line(Vector2(-7, -19), arm_l, tinted(coat, 0.85), 3.6)
	ci.draw_line(Vector2(7, -19), arm_r, tinted(coat, 0.85), 3.6)
	ci.draw_circle(arm_l, 2.7, skin)
	ci.draw_circle(arm_r, 2.7, skin)
	# coat: a body with an outline, a darker hem and a lit shoulder
	var body := ellipse_points(Vector2(0, -14), 9.0, 9.5)
	ci.draw_colored_polygon(body, coat)
	ci.draw_colored_polygon(ellipse_points(Vector2(0, -7), 8.4, 4.2), tinted(coat, 0.68))
	ci.draw_colored_polygon(ellipse_points(Vector2(-2.5, -18), 5.5, 4.0), Color(minf(coat.r * 1.45, 1.0), minf(coat.g * 1.45, 1.0), minf(coat.b * 1.45, 1.0), 0.45 * alpha))
	var ol := body.duplicate()
	ol.append(body[0])
	ci.draw_polyline(ol, line, 1.3)
	ci.draw_line(Vector2(0, -22), Vector2(0, -6), Color(0, 0, 0, 0.3 * alpha), 1.0)             # coat seam
	if scarf:
		ci.draw_colored_polygon(ellipse_points(Vector2(0, -21.5), 7.2, 3.4), Color(SCARF.r, SCARF.g, SCARF.b, alpha))
		ci.draw_colored_polygon(ellipse_points(Vector2(-1.5, -22.3), 4.5, 1.6), Color(1, 1, 1, 0.2 * alpha))
	# head with outline, light and the face
	ci.draw_circle(Vector2(0, -27.5), 7.3, line)
	ci.draw_circle(Vector2(0, -27.5), 6.3, skin)
	ci.draw_circle(Vector2(-1.8, -29.2), 3.6, Color(1, 1, 1, 0.16 * alpha))
	var eye := Color(0.08, 0.08, 0.1, alpha)
	var hair := Color(0.16, 0.12, 0.1, alpha)
	if face.y > 0.35:
		ci.draw_circle(Vector2(-2.4, -27.0), 0.95, eye)
		ci.draw_circle(Vector2(2.4, -27.0), 0.95, eye)
		ci.draw_line(Vector2(-1.2, -24.6), Vector2(1.2, -24.6), Color(0.35, 0.18, 0.18, 0.7 * alpha), 0.8)
	elif absf(face.x) > 0.35 and face.y > -0.35:
		ci.draw_circle(Vector2(signf(face.x) * 3.4, -27.0), 0.95, eye)
		ci.draw_circle(Vector2(signf(face.x) * 6.0, -26.0), 0.9, skin)                           # a nose in profile
	else:
		ci.draw_colored_polygon(ellipse_points(Vector2(0, -28.5), 6.0, 5.0), hair)               # facing away: the back of the head
	var cap := Color(coat.r * 0.7, coat.g * 0.7, coat.b * 0.7, alpha)
	match hat:
		"bowler":
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -31), 8.4, 3.4), cap)
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -33.5), 5.2, 3.8), cap)
			ci.draw_colored_polygon(ellipse_points(Vector2(-1.5, -34.5), 2.4, 1.4), Color(1, 1, 1, 0.2 * alpha))
		"top":
			ci.draw_rect(Rect2(-4.8, -41, 9.6, 10), cap)
			ci.draw_rect(Rect2(-4.8, -41, 2.4, 10), Color(1, 1, 1, 0.13 * alpha))
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -31), 8.0, 2.8), cap)
			ci.draw_rect(Rect2(-4.8, -33.5, 9.6, 1.6), Color(accent.r, accent.g, accent.b, alpha))
		"cap", "flat":
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -31.5), 7.6, 3.4), accent if hat == "flat" else cap)
			ci.draw_colored_polygon(ellipse_points(Vector2(-1, -32.5), 4.4, 1.6), Color(1, 1, 1, 0.14 * alpha))
		"parasol":
			var pc := Color(accent.r, accent.g, accent.b, alpha)
			ci.draw_line(Vector2(9, -34), Vector2(7, -16), Color(0.2, 0.15, 0.1, alpha), 1.4)
			ci.draw_colored_polygon(ellipse_points(Vector2(9, -35), 13.0, 7.0), tinted(pc, 0.6))
			ci.draw_colored_polygon(ellipse_points(Vector2(8, -36), 11.0, 5.6), pc)
			for i in 4:
				var a := -PI * 0.5 + (float(i) - 1.5) * 0.7
				ci.draw_line(Vector2(9, -35), Vector2(9, -35) + Vector2(cos(a), sin(a) * 0.55) * 12.0, Color(0, 0, 0, 0.25 * alpha), 0.8)
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -31.5), 6.4, 2.4), hair)
		_:
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -31), 6.6, 2.8), hair)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A gas lamp post (y-sorted prop); the warm glow is a PointLight2D the world adds, the bloom is
## the additive "glow" layer.
static func lamp(ci: CanvasItem, dim: bool = false) -> void:
	if sprite(ci, "lamp", Vector2(0.5, 0.9)):
		return
	shadow(ci, Vector2(0, 1), 8.0, 3.2, 0.34)
	ci.draw_rect(Rect2(-5.5, -4.0, 11, 6), Color("171922"))                      # plinth
	ci.draw_rect(Rect2(-4.0, -7.0, 8, 4), Color("2a2e3a"))
	ci.draw_rect(Rect2(-1.8, -36, 3.6, 30), Color("1b1e27"))                     # post
	ci.draw_rect(Rect2(-1.8, -36, 1.2, 30), Color(1, 1, 1, 0.14))
	ci.draw_rect(Rect2(-3.2, -24, 6.4, 2.2), Color("2a2e3a"))                    # collar
	ci.draw_rect(Rect2(-6.5, -44, 13, 2.5), Color("23262f"))                     # lantern base
	ci.draw_rect(Rect2(-5.5, -43, 11, 9), Color("14161d"))
	var glow := AMBER_DIM if dim else AMBER
	ci.draw_rect(Rect2(-4.0, -42, 8, 7), glow)
	ci.draw_rect(Rect2(-4.0, -42, 8, 7), Color(1, 1, 1, 0.18))
	ci.draw_line(Vector2(0, -42), Vector2(0, -35), Color(0.1, 0.06, 0.02, 0.6), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -44), Vector2(7, -44), Vector2(0, -50)]), Color("1b1e27"))
	ci.draw_circle(Vector2(0, -50.5), 1.4, Color("2a2e3a"))

## A tree's trunk (the canopy is drawn above everything by the overlay).
static func tree_trunk(ci: CanvasItem) -> void:
	if sprite(ci, "tree", Vector2(0.5, 0.9)):
		return
	shadow(ci, Vector2(2, 3), 16.0, 6.0, 0.34)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, 3), Vector2(-4, -6), Vector2(4, -6), Vector2(8, 3), Vector2(3, 1), Vector2(-3, 1)]), Color("2a2020"))  # roots
	ci.draw_rect(Rect2(-4.5, -30, 9, 26), Color("3a2c2a"))
	ci.draw_rect(Rect2(-4.5, -30, 3, 26), Color("4d3b36"))
	ci.draw_rect(Rect2(-4.5, -30, 9, 26), Color("15100f"), false, 1.0)
	for i in 4:
		ci.draw_line(Vector2(-2 + i * 1.5, -26 + i * 6), Vector2(-1 + i * 1.5, -22 + i * 6), Color(0, 0, 0, 0.25), 1.0)

static func crate(ci: CanvasItem, size: Vector2) -> void:
	if sprite(ci, "crate", Vector2(0.5, 0.5)):
		return
	var r := Rect2(-size * 0.5, size)
	shadow(ci, Vector2(2, size.y * 0.5 + 1), size.x * 0.65, 4.5, 0.32)
	ci.draw_rect(r, Color("5b4633"))
	var n := 3
	for i in n:                                                                   # planks
		var py := r.position.y + i * size.y / n
		ci.draw_rect(Rect2(r.position.x, py, size.x, size.y / n - 1.0), Color(0.36 + 0.03 * i, 0.27 + 0.02 * i, 0.19))
		ci.draw_line(Vector2(r.position.x, py + 1.0), Vector2(r.end.x, py + 1.0), Color(1, 1, 1, 0.1), 1.0)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 3.0, size.y), Color("2d231a"))  # battens
	ci.draw_rect(Rect2(r.end.x - 3.0, r.position.y, 3.0, size.y), Color("2d231a"))
	ci.draw_line(r.position, r.end, Color("2d231a"), 1.5)
	ci.draw_rect(r, Color("1b150f"), false, 1.2)

static func barrel(ci: CanvasItem, r: float) -> void:
	if sprite(ci, "barrel", Vector2(0.5, 0.5)):
		return
	shadow(ci, Vector2(2, r * 0.75), r * 1.15, r * 0.5, 0.32)
	ci.draw_circle(Vector2.ZERO, r, Color("1b150f"))
	ci.draw_circle(Vector2.ZERO, r - 1.2, Color("5a4634"))
	for i in 8:                                                                   # staves
		var a := TAU * float(i) / 8.0
		ci.draw_line(Vector2(cos(a), sin(a)) * 2.0, Vector2(cos(a), sin(a)) * (r - 1.2), Color(0, 0, 0, 0.3), 1.0)
	ci.draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 16, Color("2b241c"), 1.8)        # hoop
	ci.draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.4, Color(1, 1, 1, 0.08))

## The baker's stall: counter with bread, origin at the counter's top-centre.
static func stall(ci: CanvasItem) -> void:
	if sprite(ci, "stall", Vector2(0.5, 0.2)):
		return
	shadow(ci, Vector2(2, 28), 60.0, 6.5, 0.3)
	ci.draw_rect(Rect2(-56, -12, 112, 25), Color("2c1f15"))
	ci.draw_rect(Rect2(-55, -11, 110, 12), Color("7a5636"))                       # counter top
	ci.draw_rect(Rect2(-55, -11, 110, 2), Color(1, 1, 1, 0.14))
	ci.draw_rect(Rect2(-55, 1, 110, 11), Color("4a3322"))                         # counter front, with panels
	for i in 5:
		ci.draw_rect(Rect2(-50 + i * 21, 3, 18, 7), Color("3a281a"))
	ci.draw_colored_polygon(ellipse_points(Vector2(-8, -5), 40.0, 5.0), Color("e6dfc8"))   # a cloth with the loaves on it
	for i in 7:
		var x := -44.0 + i * 14.5
		ci.draw_colored_polygon(ellipse_points(Vector2(x, -5.5), 6.2, 3.8), Color("8a5a2a"))
		ci.draw_colored_polygon(ellipse_points(Vector2(x - 1.0, -6.4), 5.0, 2.6), Color("c28a4a"))
		ci.draw_line(Vector2(x - 3, -6.2), Vector2(x + 1, -4.8), Color("7a4a1e"), 1.0)
	ci.draw_rect(Rect2(-60, -14, 5, 28), Color("1d1510"))                         # canopy posts
	ci.draw_rect(Rect2(55, -14, 5, 28), Color("1d1510"))
	ci.draw_circle(Vector2(0, -18), 5.0, Color(1.0, 0.72, 0.35, 0.16))

## The parked carriage (origin at the base of its body) and the horse that goes with it.
static func carriage(ci: CanvasItem) -> void:
	if sprite(ci, "carriage", Vector2(0.5, 0.9)):
		return
	shadow(ci, Vector2(0, 3), 68.0, 8.0, 0.32)
	# body: dark lacquer with a lit roof edge, three windows with a faint glow, a driver's bench
	ci.draw_rect(Rect2(-58, -55, 118, 55), Color("14151c"))
	ci.draw_rect(Rect2(-56, -53, 114, 51), Color("272a38"))
	ci.draw_rect(Rect2(-58, -62, 118, 9), Color("323648"))
	ci.draw_rect(Rect2(-58, -62, 118, 2), Color(1, 1, 1, 0.16))
	for i in 3:
		var wx := -50.0 + i * 36.0
		ci.draw_rect(Rect2(wx - 1, -48, 30, 26), Color("0c0d12"))
		ci.draw_rect(Rect2(wx + 1, -46, 26, 22), Color("46557a"))
		ci.draw_rect(Rect2(wx + 1, -46, 10, 22), Color(1, 1, 1, 0.1))
	ci.draw_rect(Rect2(-58, -20, 118, 3), Color("8a6a3a"))                       # brass trim
	ci.draw_rect(Rect2(58, -48, 12, 18), Color("20232e"))                          # driver's bench at the rear
	ci.draw_circle(Vector2(-60, -40), 3.0, Color("ffb45a"))                         # side lamps
	ci.draw_circle(Vector2(-60, -40), 7.0, Color(1.0, 0.7, 0.3, 0.18))
	for wx in [-40, 38]:
		ci.draw_circle(Vector2(wx, -2), 11.0, Color("0b0b10"))
		ci.draw_circle(Vector2(wx, -2), 8.5, Color("5a4630"))
		for k in 6:
			var a := TAU * float(k) / 6.0
			ci.draw_line(Vector2(wx, -2), Vector2(wx, -2) + Vector2(cos(a), sin(a)) * 8.0, Color("2a1f14"), 1.2)
		ci.draw_circle(Vector2(wx, -2), 2.4, Color("1b1b22"))
	# the horse, in front of the carriage
	ci.draw_rect(Rect2(-110, -4, 4, 12), Color("2a201a"))
	ci.draw_rect(Rect2(-104, -4, 4, 12), Color("2a201a"))
	ci.draw_rect(Rect2(-80, -4, 4, 12), Color("2a201a"))
	ci.draw_rect(Rect2(-74, -4, 4, 12), Color("2a201a"))
	ci.draw_colored_polygon(ellipse_points(Vector2(-92, -18), 23.0, 11.5), Color("4a382e"))
	ci.draw_colored_polygon(ellipse_points(Vector2(-95, -21), 17.0, 6.5), Color("5c473a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-108, -24), Vector2(-122, -34), Vector2(-129, -30), Vector2(-116, -16)]), Color("40302a"))   # neck and head
	ci.draw_colored_polygon(ellipse_points(Vector2(-126, -29), 6.0, 3.4), Color("4a382e"))
	ci.draw_line(Vector2(-110, -27), Vector2(-100, -29), Color("1b1411"), 3.0)    # mane
	ci.draw_line(Vector2(-70, -22), Vector2(-60, -14), Color("1b1411"), 3.0)      # tail
	ci.draw_line(Vector2(-86, -10), Vector2(-60, -22), Color("2a1f14"), 1.2)      # shafts

## Window rows, doors and shop fronts for the facades.
static func window(ci: CanvasItem, r: Rect2, lit: bool) -> void:
	ci.draw_rect(r, Color("0f1119"))
	ci.draw_rect(r, Color("2a2e3d"), false, 2.0)
	if lit:
		ci.draw_rect(r.grow(-3), Color(AMBER.r, AMBER.g, AMBER.b, 0.55))
	else:
		ci.draw_rect(r.grow(-3), Color("1c2233"))
		ci.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color("0f1119"), 2.0)
		ci.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color("0f1119"), 2.0)
