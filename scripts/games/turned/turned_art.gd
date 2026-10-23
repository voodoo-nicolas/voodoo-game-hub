extends RefCounted

## Placeholder art for Turned, all drawn in code from simple shapes (cold greys and blues, warm
## amber for lamps). Real art swaps in by file name: if `res://games/turned/art/<name>.png`
## exists, `tex(name)` returns it and the draw helpers use it instead of the shapes
## (names: player, npc_<id>, lamp, tree, stall, carriage, horse, crate, barrel, bed).
## Every file added there also needs a media/CREDITS.json entry (hub.py check).

const ART_DIR := "res://games/turned/art/"

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
static func person(ci: CanvasItem, look: Dictionary, face: Vector2, walk: float = 0.0, sneak: bool = false,
		scarf: bool = false, sprite: String = "", alpha: float = 1.0) -> void:
	if sprite != "":
		var t := tex(sprite)
		if t != null:
			ci.draw_texture(t, -t.get_size() * Vector2(0.5, 0.92), Color(1, 1, 1, alpha))
			return
	var coat := Color(str(look.get("coat", "3f4f6e")))
	var skin := Color(str(look.get("skin", "cfc3c6")))
	var accent := Color(str(look.get("accent", "8d8f98")))
	var hat := str(look.get("hat", ""))
	coat.a = alpha
	skin.a = alpha
	var squash := 0.88 if sneak else 1.0
	ci.draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, squash))
	shadow(ci, Vector2(0, 2), 11.0, 5.0, 0.28 * alpha)
	var swing := sin(walk) * 3.0
	var leg := Color(0.12, 0.12, 0.16, alpha)
	ci.draw_rect(Rect2(-5, -9 + swing * 0.5, 4, 10), leg)
	ci.draw_rect(Rect2(1, -9 - swing * 0.5, 4, 10), leg)
	# coat: a rounded body, darker hem
	ci.draw_colored_polygon(ellipse_points(Vector2(0, -14), 8.5, 9.0), coat)
	ci.draw_colored_polygon(ellipse_points(Vector2(0, -8), 8.0, 4.0), tinted(coat, 0.75))
	ci.draw_circle(Vector2(-9, -13 + swing * 0.4), 2.6, skin)
	ci.draw_circle(Vector2(9, -13 - swing * 0.4), 2.6, skin)
	if scarf:
		ci.draw_colored_polygon(ellipse_points(Vector2(0, -21), 6.8, 3.2), Color(SCARF.r, SCARF.g, SCARF.b, alpha))
	# head, face direction, hat
	ci.draw_circle(Vector2(0, -27), 6.5, skin)
	var eye := Color(0.08, 0.08, 0.1, alpha)
	if face.y > 0.35:
		ci.draw_circle(Vector2(-2.4, -26.5), 0.9, eye)
		ci.draw_circle(Vector2(2.4, -26.5), 0.9, eye)
	elif absf(face.x) > 0.35 and face.y > -0.35:
		ci.draw_circle(Vector2(signf(face.x) * 3.4, -26.5), 0.9, eye)
	var cap := Color(coat.r * 0.7, coat.g * 0.7, coat.b * 0.7, alpha)
	match hat:
		"bowler":
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -30), 7.4, 3.2), cap)
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -32.5), 4.8, 3.4), cap)
		"top":
			ci.draw_rect(Rect2(-4.5, -39, 9, 9), cap)
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -30), 7.6, 2.6), cap)
		"cap", "flat":
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -30.5), 6.8, 3.0), accent if hat == "flat" else cap)
		"parasol":
			ci.draw_colored_polygon(ellipse_points(Vector2(9, -34), 12.0, 6.5), Color(accent.r, accent.g, accent.b, alpha))
			ci.draw_line(Vector2(9, -34), Vector2(7, -16), Color(0.2, 0.15, 0.1, alpha), 1.2)
		_:
			ci.draw_colored_polygon(ellipse_points(Vector2(0, -30), 6.2, 2.6), Color(0.16, 0.12, 0.1, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A gas lamp post (y-sorted prop); the warm glow is a PointLight2D the world adds.
static func lamp(ci: CanvasItem, dim: bool = false) -> void:
	var t := tex("lamp")
	if t != null:
		ci.draw_texture(t, -t.get_size() * Vector2(0.5, 0.9))
		return
	shadow(ci, Vector2(0, 1), 7.0, 3.0, 0.3)
	ci.draw_rect(Rect2(-2, -34, 4, 36), Color("1d2029"))
	ci.draw_rect(Rect2(-5, -2, 10, 4), Color("2a2e3a"))
	ci.draw_rect(Rect2(-5, -42, 10, 9), Color("23262f"))
	var glow := AMBER_DIM if dim else AMBER
	ci.draw_rect(Rect2(-3.5, -40.5, 7, 6), glow)
	ci.draw_circle(Vector2(0, -37.5), 9.0, Color(glow.r, glow.g, glow.b, 0.18))

## A tree's trunk (the canopy is drawn above everything by the overlay).
static func tree_trunk(ci: CanvasItem) -> void:
	var t := tex("tree")
	if t != null:
		ci.draw_texture(t, -t.get_size() * Vector2(0.5, 0.9))
		return
	shadow(ci, Vector2(0, 3), 13.0, 5.0, 0.3)
	ci.draw_rect(Rect2(-4, -26, 8, 28), Color("3a2c2a"))
	ci.draw_rect(Rect2(-5, -2, 10, 4), Color("2c2120"))

static func crate(ci: CanvasItem, size: Vector2) -> void:
	var t := tex("crate")
	if t != null:
		ci.draw_texture(t, -t.get_size() * 0.5)
		return
	var r := Rect2(-size * 0.5, size)
	shadow(ci, Vector2(0, size.y * 0.5), size.x * 0.6, 4.0, 0.25)
	ci.draw_rect(r, Color("5b4633"))
	ci.draw_rect(r, Color("2d231a"), false, 1.5)
	ci.draw_line(r.position, r.end, Color("3a2c20"), 1.5)
	ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color("3a2c20"), 1.5)

static func barrel(ci: CanvasItem, r: float) -> void:
	var t := tex("barrel")
	if t != null:
		ci.draw_texture(t, -t.get_size() * 0.5)
		return
	shadow(ci, Vector2(0, r * 0.7), r * 1.1, r * 0.45, 0.25)
	ci.draw_circle(Vector2.ZERO, r, Color("4a3a2c"))
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 18, Color("1f1812"), 1.5)
	ci.draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 14, Color("2c2218"), 1.2)

## The baker's stall: counter with bread, origin at the counter's top-centre.
static func stall(ci: CanvasItem) -> void:
	var t := tex("stall")
	if t != null:
		ci.draw_texture(t, -t.get_size() * Vector2(0.5, 0.2))
		return
	shadow(ci, Vector2(0, 28), 58.0, 6.0, 0.25)
	ci.draw_rect(Rect2(-56, -12, 112, 24), Color("6a4a30"))
	ci.draw_rect(Rect2(-56, -12, 112, 24), Color("2d1f14"), false, 1.5)
	for i in 6:
		ci.draw_colored_polygon(ellipse_points(Vector2(-44 + i * 17, -4), 7.0, 4.5), Color("c28a4a"))
		ci.draw_arc(Vector2(-44 + i * 17, -4), 5.0, PI * 1.1, PI * 1.9, 6, Color("8a5a28"), 1.0)

## The parked carriage (origin at the base of its body) and the horse that goes with it.
static func carriage(ci: CanvasItem) -> void:
	var t := tex("carriage")
	if t != null:
		ci.draw_texture(t, -t.get_size() * Vector2(0.5, 0.9))
		return
	shadow(ci, Vector2(0, 2), 66.0, 7.0, 0.28)
	ci.draw_rect(Rect2(-58, -54, 118, 54), Color("23252f"))
	ci.draw_rect(Rect2(-58, -54, 118, 54), Color("0e0f14"), false, 2.0)
	ci.draw_rect(Rect2(-50, -46, 28, 24), Color("3a4560"))
	ci.draw_rect(Rect2(-14, -46, 28, 24), Color("3a4560"))
	ci.draw_rect(Rect2(22, -46, 28, 24), Color("3a4560"))
	ci.draw_rect(Rect2(-58, -60, 118, 8), Color("2c2f3a"))
	for wx in [-40, 38]:
		ci.draw_circle(Vector2(wx, -2), 10.0, Color("14151b"))
		ci.draw_circle(Vector2(wx, -2), 6.0, Color("5a4630"))
	# the horse, in front of it
	ci.draw_colored_polygon(ellipse_points(Vector2(-92, -18), 22.0, 11.0), Color("4a3a30"))
	ci.draw_colored_polygon(ellipse_points(Vector2(-116, -24), 8.0, 6.0), Color("3f3128"))
	ci.draw_rect(Rect2(-108, -2, 4, 10), Color("2c211b"))
	ci.draw_rect(Rect2(-80, -2, 4, 10), Color("2c211b"))

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
