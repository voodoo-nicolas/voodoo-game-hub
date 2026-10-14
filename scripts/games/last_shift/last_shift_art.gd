extends RefCounted

## Drawing helpers for the Last Shift look: comic ink (thick near-black outlines), cel shading
## (flat color + one darker band + one highlight, light from the TOP-LEFT) and hard drop shadows.
## Palette from docs/bible/style_bible.md. Everything is drawn in code for now; the same
## helpers can be swapped for real sprites later (see last_shift_sprites.gd).
##
## RULE: cyan (CYAN_*) is reserved for infected glow and lockdown panels. Nothing else.

# --- palette (style bible)
const INK := Color("0e0e12")
const SHADOW_DEEP := Color("1b1f2a")
const CONC_D := Color("3a3d44")
const CONC_M := Color("6b6e75")
const CONC_L := Color("a3a5a8")
const STEEL := Color("5c6670")
const STEEL_HI := Color("b8c2cc")
const RUST_D := Color("5a2a14")
const RUST_M := Color("9c4a1e")
const RUST_L := Color("d9772e")
const CYAN_CORE := Color("19c3e6")     # infected / lockdown ONLY
const CYAN_GLOW := Color("a8f3ff")
const BLOOD := Color("b3161c")
const AMBER := Color("e09a1a")
const YELLOW := Color("f2d13a")
const ZOMBIE := Color("7c8577")
const ZOMBIE_PALE := Color("b7bba8")
const SKIN := Color("c98e6a")
const SKIN_LIGHT := Color("f1c7a3")
const WHITE := Color("e8e8f0")
const PURPLE := Color("6a3fd6")
const FIRE := Color("ff7a1a")

# --- small helpers

static func shade(c: Color, amount: float) -> Color:
	## amount > 0 lightens, < 0 darkens (keeps alpha).
	return c.lightened(amount) if amount > 0.0 else c.darkened(-amount)

## Filled rectangle with ink outline and cel shading (shadow band at the bottom, highlight on top).
static func ink_rect(ci: CanvasItem, r: Rect2, fill: Color, w: float = 2.0) -> void:
	ci.draw_rect(r.grow(w * 0.5), INK)
	ci.draw_rect(r, fill)
	var band := minf(r.size.y * 0.3, 5.0)
	if band > 1.0:
		ci.draw_rect(Rect2(r.position.x, r.end.y - band, r.size.x, band), shade(fill, -0.28))
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.5), shade(fill, 0.32))

## Flat rectangle with outline only (no shading), for small details.
static func flat_rect(ci: CanvasItem, r: Rect2, fill: Color, w: float = 1.5) -> void:
	ci.draw_rect(r.grow(w * 0.5), INK)
	ci.draw_rect(r, fill)

static func ink_circle(ci: CanvasItem, c: Vector2, radius: float, fill: Color, w: float = 2.0) -> void:
	ci.draw_circle(c, radius + w * 0.5, INK)
	ci.draw_circle(c, radius, fill)
	# crescent of shadow on the lower right
	ci.draw_arc(c, radius * 0.72, 0.15, PI * 0.85, 10, shade(fill, -0.26), radius * 0.5)
	ci.draw_circle(c + Vector2(-radius * 0.35, -radius * 0.4), radius * 0.2, shade(fill, 0.3))

static func ink_poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 2.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, INK, w)

## Hard oval drop shadow on the floor.
static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, alpha: float = 0.38) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, Color(0, 0, 0, alpha))

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color) -> void:
	ci.draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


# --- people ---------------------------------------------------------------------------
# Zelda-style 4-direction characters, origin = the collision box center, feet at y ~ +14,
# top of the head at y ~ -24. One routine for everyone; options say who it is:
#   facing: Vector2 (unit, 4-way)     phase: walk-cycle angle      amp: walk amount 0..1
#   t: time for the idle breathing    body/pants/skin/hair/boots/glove/band/belt: colors
#   held: "wrench" | "pistol" | "knife" | "baton" | "arm" | "coolant" | "none"   swing: 0..1 attack swing progress
#   zombie: arms reaching forward, shambling, dark eyes        mouth_open: screamers
#   badge: ID badge clipped to the chest       rolled: sleeves rolled up (forearms show)
#   tee: color of the T-shirt in the open collar     tools: tool handles sticking out of the pouches
#   v0.4 extras: vest (hi-vis, vertical straps only) | riot (riot vest + helmet) | apron | tie |
#   hat (party hat) | toque (cook's hat) | blood (stains on infected clothes)
# Reflective `band` color goes on the sleeves (elbows) and the lower legs only. There is no
# band across the chest any more (v0.3: it read as a white bar).

static func person(ci: CanvasItem, o: Dictionary) -> void:
	var f: Vector2 = o.get("facing", Vector2.DOWN)
	var amp: float = o.get("amp", 0.0)
	var phase: float = o.get("phase", 0.0)
	var t: float = o.get("t", 0.0)
	var step := sin(phase) * amp
	var lift := absf(sin(phase)) * amp * 1.6
	var oy := -lift + sin(t * 2.2) * 0.6 * (1.0 - amp)
	shadow(ci, Vector2(0, 14), 12.0, 4.5)
	if f.y < -0.5:
		_person_back(ci, o, step, oy)
	elif f.x != 0.0 and absf(f.x) >= absf(f.y):
		_person_side(ci, o, step, oy, signf(f.x))
	else:
		_person_front(ci, o, step, oy)

static func _colors(o: Dictionary) -> Dictionary:
	var body: Color = o.get("body", Color("3c3a40"))
	return {
		"body": body,
		"pants": o.get("pants", body),
		"skin": o.get("skin", SKIN),
		"hair": o.get("hair", Color("2a1f1a")),
		"boots": o.get("boots", Color("5a3a22")),
		"glove": o.get("glove", Color("8f949c")),
		"band": o.get("band", Color(0, 0, 0, 0)),
		"belt": o.get("belt", Color("6b4a2a")),
		"tee": o.get("tee", Color("1d1d22")),
	}

## Two legs + boots (front and back views). Reflective bands sit low on the shins.
static func _legs(ci: CanvasItem, c: Dictionary, sl: float, oy: float) -> void:
	ink_rect(ci, Rect2(-8, 3 + oy, 7, 9 + sl), c.pants)
	ink_rect(ci, Rect2(1, 3 + oy, 7, 9 - sl), c.pants)
	ci.draw_rect(Rect2(-2.5, 4 + oy, 1.5, 7 + sl), shade(c.pants, -0.2))   # inner-leg shade
	if c.band.a > 0.0:
		ci.draw_rect(Rect2(-8, 8.5 + oy + sl * 0.6, 7, 1.6), c.band)
		ci.draw_rect(Rect2(1, 8.5 + oy - sl * 0.6, 7, 1.6), c.band)
	ink_rect(ci, Rect2(-9, 11 + sl, 8, 4), c.boots)
	ink_rect(ci, Rect2(1, 11 - sl, 8, 4), c.boots)
	ci.draw_rect(Rect2(-8, 11.5 + sl, 3, 1), shade(c.boots, 0.35))          # toe shine
	ci.draw_rect(Rect2(2, 11.5 - sl, 3, 1), shade(c.boots, 0.35))

## One arm hanging at the side (front/back views): sleeve, forearm or cuff, glove.
static func _arm(ci: CanvasItem, c: Dictionary, x: float, y: float, rolled: bool) -> void:
	if rolled:
		ink_rect(ci, Rect2(x, y, 5, 6), c.body)
		ink_rect(ci, Rect2(x + 0.5, y + 5.5, 4, 5), c.skin, 1.5)
	else:
		ink_rect(ci, Rect2(x, y, 5, 11), c.body)
	if c.band.a > 0.0:
		ci.draw_rect(Rect2(x, y + 4.5, 5, 1.5), c.band)
	ink_rect(ci, Rect2(x - 0.5, y + 10, 6, 5), c.glove)

## Belt with a buckle, the hip pouches and (optionally) tool handles poking out of them.
static func _belt(ci: CanvasItem, o: Dictionary, c: Dictionary, x0: float, w: float, oy: float, back: bool) -> void:
	ci.draw_rect(Rect2(x0, 3 + oy, w, 3), c.belt)
	ci.draw_rect(Rect2(x0, 3 + oy, w, 1), shade(c.belt, 0.25))
	if not back:
		flat_rect(ci, Rect2(-2, 3 + oy, 4, 3), Color("c9a227"), 1.0)           # buckle
	if o.get("pouches", true):
		if o.get("tools", false):
			ci.draw_line(Vector2(-8, 3 + oy), Vector2(-8.5, -0.5 + oy), INK, 2.6)
			ci.draw_line(Vector2(-8, 3 + oy), Vector2(-8.5, -0.5 + oy), BLOOD, 1.4)
			ci.draw_line(Vector2(-5.5, 3 + oy), Vector2(-5, 0.5 + oy), INK, 2.6)
			ci.draw_line(Vector2(-5.5, 3 + oy), Vector2(-5, 0.5 + oy), YELLOW, 1.4)
			ci.draw_line(Vector2(6.5, 3 + oy), Vector2(7, -0.5 + oy), INK, 2.6)
			ci.draw_line(Vector2(6.5, 3 + oy), Vector2(7, -0.5 + oy), STEEL_HI, 1.4)
		flat_rect(ci, Rect2(-10, 3 + oy, 6, 6), Color("8a6a3a"), 1.0)
		flat_rect(ci, Rect2(4, 3 + oy, 6, 6), Color("8a6a3a"), 1.0)
		ci.draw_rect(Rect2(-10, 3 + oy, 6, 1.5), Color("6b4a2a"))               # pouch flaps
		ci.draw_rect(Rect2(4, 3 + oy, 6, 1.5), Color("6b4a2a"))

static func _person_front(ci: CanvasItem, o: Dictionary, step: float, oy: float) -> void:
	var c := _colors(o)
	var zombie: bool = o.get("zombie", false)
	_legs(ci, c, step * 3.0, oy)
	# arms (behind the torso edge)
	var armswing := -step * 2.0
	if zombie:
		ink_rect(ci, Rect2(-16, -4 + oy, 5, 12), c.body)
		ink_rect(ci, Rect2(11, -4 + oy, 5, 12), c.body)
		ink_rect(ci, Rect2(-16, 6 + oy, 5, 4), c.skin)
		ink_rect(ci, Rect2(11, 6 + oy, 5, 4), c.skin)
	else:
		var rolled: bool = o.get("rolled", false)
		_arm(ci, c, -15, -8 + oy + armswing, rolled)
		_arm(ci, c, 10, -8 + oy - armswing, rolled)
	# torso: flat color, a shaded right side (light from the top-left), open collar, zipper
	ink_rect(ci, Rect2(-11, -9 + oy, 22, 15), c.body)
	ci.draw_rect(Rect2(6, -7 + oy, 5, 10), shade(c.body, -0.14))
	if not zombie:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -9 + oy), Vector2(4, -9 + oy),
			Vector2(0, -4 + oy)]), c.tee)
		ink_poly(ci, PackedVector2Array([Vector2(-7, -9 + oy), Vector2(-2, -9 + oy), Vector2(-3.5, -5 + oy)]),
			shade(c.body, 0.16), 1.0)
		ink_poly(ci, PackedVector2Array([Vector2(7, -9 + oy), Vector2(2, -9 + oy), Vector2(3.5, -5 + oy)]),
			shade(c.body, 0.08), 1.0)
		ci.draw_line(Vector2(0, -4 + oy), Vector2(0, 3 + oy), shade(c.body, -0.32), 1.0)
		flat_rect(ci, Rect2(3, -5 + oy, 5, 4), shade(c.body, -0.06), 1.0)      # chest pocket
		if o.get("badge", false):
			ci.draw_line(Vector2(-6, -7 + oy), Vector2(-6, -5 + oy), INK, 1.0)
			flat_rect(ci, Rect2(-8, -5 + oy, 4, 5), WHITE, 1.0)
			ci.draw_rect(Rect2(-7.5, -4 + oy, 3, 1), PURPLE)
	_belt(ci, o, c, -11, 22, oy, false)
	if o.get("torn", false):
		# ragged hem for infected clothes
		ink_poly(ci, PackedVector2Array([Vector2(-10, 3 + oy), Vector2(-6, 7 + oy), Vector2(-2, 4 + oy),
			Vector2(3, 8 + oy), Vector2(7, 4 + oy), Vector2(10, 7 + oy), Vector2(10, 3 + oy)]), c.body, 1.2)
	_torso_extras(ci, o, c, oy, "front", 0.0)
	# held item (right hand, screen right)
	_held(ci, o, Vector2(12.5, 5 + oy), Vector2(0, 1), 0)
	var fhead := Vector2(0, -15 + oy + (2.0 if zombie else 0.0))
	_head_front(ci, o, c, fhead, zombie)
	_head_extras(ci, o, fhead, 0.0)

static func _head_front(ci: CanvasItem, o: Dictionary, c: Dictionary, head: Vector2, zombie: bool) -> void:
	# ears, head, messy hair with a highlight
	ci.draw_circle(head + Vector2(-8, 1), 2.6, INK)
	ci.draw_circle(head + Vector2(8, 1), 2.6, INK)
	ci.draw_circle(head + Vector2(-8, 1), 1.6, c.skin)
	ci.draw_circle(head + Vector2(8, 1), 1.6, shade(c.skin, -0.15))
	ink_circle(ci, head, 8.0, c.skin)
	var hair: Color = c.hair
	var hp := PackedVector2Array([Vector2(-8.4, 1), Vector2(-8.7, -4), Vector2(-6.5, -8.5), Vector2(-4.5, -11),
		Vector2(-2.5, -9.4), Vector2(0, -11.4), Vector2(2.2, -9.6), Vector2(4.8, -10.8), Vector2(6.6, -8),
		Vector2(8.7, -4), Vector2(8.4, 1), Vector2(6.6, -2.6), Vector2(3, -4.6), Vector2(-1, -3.6),
		Vector2(-5, -4.6), Vector2(-6.6, -2)])
	for i in hp.size():
		hp[i] += head
	ci.draw_colored_polygon(hp, hair)
	ci.draw_line(head + Vector2(-5, -7.5), head + Vector2(-1, -8.5), shade(hair, 0.3), 1.4)
	var eye := Color("ff3a2a") if o.get("red_eyes", false) else INK
	if zombie:
		ci.draw_circle(head + Vector2(-3, 0.5), 2.0, INK)
		ci.draw_circle(head + Vector2(3, 0.5), 2.0, INK)
	else:
		ci.draw_line(head + Vector2(-5, -2.2), head + Vector2(-1.5, -1.7), shade(hair, -0.2), 1.5)
		ci.draw_line(head + Vector2(1.5, -1.7), head + Vector2(5, -2.2), shade(hair, -0.2), 1.5)
		ci.draw_circle(head + Vector2(-3, 0.5), 1.3, eye)
		ci.draw_circle(head + Vector2(3, 0.5), 1.3, eye)
		ci.draw_rect(Rect2(head.x - 0.7, head.y + 1.6, 1.4, 1.8), shade(c.skin, -0.22))   # nose
	if o.get("mouth_open", false):
		ci.draw_circle(head + Vector2(0, 4.5), 2.6, INK)
	else:
		if o.get("stubble", true):
			ci.draw_arc(head + Vector2(0, 0.5), 6.2, 0.35, PI - 0.35, 10, Color(0, 0, 0, 0.2), 3.2)
		ci.draw_line(head + Vector2(-2, 4.6), head + Vector2(2, 4.3), shade(c.skin, -0.45), 1.0)

static func _person_back(ci: CanvasItem, o: Dictionary, step: float, oy: float) -> void:
	var c := _colors(o)
	var zombie: bool = o.get("zombie", false)
	_legs(ci, c, step * 3.0, oy)
	var armswing := step * 2.0
	if zombie:
		ink_rect(ci, Rect2(-16, -10 + oy, 5, 11), c.body)
		ink_rect(ci, Rect2(11, -10 + oy, 5, 11), c.body)
	else:
		var rolled: bool = o.get("rolled", false)
		_arm(ci, c, -15, -8 + oy + armswing, rolled)
		_arm(ci, c, 10, -8 + oy - armswing, rolled)
	ink_rect(ci, Rect2(-10, -9 + oy, 20, 14), c.body)
	ci.draw_rect(Rect2(5, -7 + oy, 5, 9), shade(c.body, -0.14))
	ci.draw_rect(Rect2(-10, -9 + oy, 20, 2), shade(c.body, -0.25))            # collar
	ci.draw_line(Vector2(0, -6 + oy), Vector2(0, 2 + oy), shade(c.body, -0.22), 1.0)   # back seam
	_belt(ci, o, c, -10, 20, oy, true)
	_torso_extras(ci, o, c, oy, "back", 0.0)
	_held(ci, o, Vector2(12.5, 5 + oy), Vector2(0, -1), 0)
	var head := Vector2(0, -15 + oy + (2.0 if zombie else 0.0))
	ci.draw_circle(head + Vector2(-8, 1), 2.4, INK)
	ci.draw_circle(head + Vector2(8, 1), 2.4, INK)
	ci.draw_circle(head + Vector2(-8, 1), 1.4, c.skin)
	ci.draw_circle(head + Vector2(8, 1), 1.4, shade(c.skin, -0.15))
	ink_circle(ci, head, 8.0, c.hair)
	ci.draw_arc(head + Vector2(0, 2), 5.0, 0.3, PI - 0.3, 8, shade(c.hair, 0.12), 2.0)
	ci.draw_line(head + Vector2(-4, -6), head + Vector2(0, -7.5), shade(c.hair, 0.3), 1.4)
	ci.draw_rect(Rect2(head.x - 5, head.y + 6, 10, 2.5), shade(c.skin, -0.1))   # neck
	_head_extras(ci, o, head, 0.0)

static func _person_side(ci: CanvasItem, o: Dictionary, step: float, oy: float, side: float) -> void:
	var c := _colors(o)
	var zombie: bool = o.get("zombie", false)
	var sl := step * 4.0
	# far leg (darker) and near leg swing along x
	ink_rect(ci, Rect2(-4 - sl, 3 + oy, 7, 9), shade(c.pants, -0.2))
	ink_rect(ci, Rect2(-3 + sl, 3 + oy, 7, 9), c.pants)
	ink_rect(ci, Rect2(-4 - sl + (side * 1.5), 11, 9, 4), shade(c.boots, -0.15))
	ink_rect(ci, Rect2(-3 + sl + (side * 1.5), 11, 9, 4), c.boots)
	ci.draw_rect(Rect2(-3 + sl + side * 1.5 + (5.0 if side > 0 else 1.0), 11.5, 3, 1), shade(c.boots, 0.35))
	if c.band.a > 0.0:
		ci.draw_rect(Rect2(-3 + sl, 8.5 + oy, 7, 1.6), c.band)
	# far arm (behind torso)
	ink_rect(ci, Rect2(-3 + step * 3.0, -8 + oy, 5, 10), shade(c.body, -0.2))
	# torso
	ink_rect(ci, Rect2(-8, -9 + oy, 16, 15), c.body)
	ci.draw_rect(Rect2(-8 if side > 0 else 4, -7 + oy, 4, 10), shade(c.body, -0.14))   # back half
	if not zombie:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(side * 2, -9 + oy), Vector2(side * 7, -9 + oy),
			Vector2(side * 5, -5 + oy)]), c.tee)
		ci.draw_rect(Rect2(-8, -9 + oy, 16, 1.5), shade(c.body, 0.14))          # collar
	ci.draw_rect(Rect2(-8, 3 + oy, 16, 3), c.belt)
	ci.draw_rect(Rect2(-8, 3 + oy, 16, 1), shade(c.belt, 0.25))
	if o.get("pouches", true):
		if o.get("tools", false):
			ci.draw_line(Vector2(-1 + side * 2.0, 3 + oy), Vector2(-1.5 + side * 2.0, -0.5 + oy), INK, 2.6)
			ci.draw_line(Vector2(-1 + side * 2.0, 3 + oy), Vector2(-1.5 + side * 2.0, -0.5 + oy), BLOOD, 1.4)
		flat_rect(ci, Rect2(-3 + side * 2.0, 3 + oy, 6, 6), Color("8a6a3a"), 1.0)
		ci.draw_rect(Rect2(-3 + side * 2.0, 3 + oy, 6, 1.5), Color("6b4a2a"))
	_torso_extras(ci, o, c, oy, "side", side)
	# near arm in front (holds the item, or reaches out for zombies)
	if zombie:
		ink_rect(ci, Rect2(side * 1.0 - (0.0 if side > 0 else 14.0), -8 + oy, 14, 5), c.body)
		ink_rect(ci, Rect2(side * 14.0 - (0.0 if side > 0 else 4.0), -8 + oy, 4, 5), c.skin)
	else:
		var swing: float = o.get("swing", 0.0)
		var ax := -2.5 + side * 1.5 - step * 3.0 * side
		if o.get("rolled", false):
			ink_rect(ci, Rect2(ax, -8 + oy, 5, 6), c.body)
			ink_rect(ci, Rect2(ax + 0.5, -2.5 + oy, 4, 5), c.skin, 1.5)
		else:
			ink_rect(ci, Rect2(ax, -8 + oy, 5, 11), c.body)
		if c.band.a > 0.0:
			ci.draw_rect(Rect2(ax, -3.5 + oy, 5, 1.5), c.band)
		ink_rect(ci, Rect2(ax - 0.5, 2 + oy, 6, 5), c.glove)
		var dir_vec := Vector2(side, 0.4).normalized()
		_held(ci, o, Vector2(-step * 3.0 * side, 5 + oy), dir_vec, swing)
	# head
	var head := Vector2(side * 1.5, -15 + oy + (2.0 if zombie else 0.0))
	ink_circle(ci, head, 8.0, c.skin)
	ci.draw_circle(head + Vector2(-side * 2.0, 1.5), 1.9, shade(c.skin, -0.2))   # ear
	ci.draw_arc(head + Vector2(-side * 2.0, 1.5), 1.9, 0.0, TAU, 8, shade(c.skin, -0.4), 0.8)
	# hair: back and top of the head, a few spikes
	ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-side * 8.4, 3), head + Vector2(-side * 8.6, -5),
		head + Vector2(-side * 5, -10.5), head + Vector2(-side * 2, -9.4), head + Vector2(side * 1, -11),
		head + Vector2(side * 3.5, -9.2), head + Vector2(side * 7, -4), head + Vector2(side * 2, -4.5),
		head + Vector2(-side * 3, -2), head + Vector2(-side * 4, 3)]), c.hair)
	ci.draw_line(head + Vector2(-side * 4, -8), head + Vector2(side * 0.5, -9), shade(c.hair, 0.3), 1.4)
	# face: brow, eye, nose, stubble, mouth
	if zombie:
		ci.draw_circle(head + Vector2(side * 4, 0), 2.0, INK)
	else:
		ci.draw_line(head + Vector2(side * 3.0, -2.3), head + Vector2(side * 6, -2.0), shade(c.hair, -0.2), 1.2)
		ci.draw_circle(head + Vector2(side * 4, -0.2), 1.3, INK)
		if o.get("stubble", true):
			ci.draw_arc(head + Vector2(side * 2.5, 1.5), 5.0, 0.2 if side > 0 else PI * 0.5, PI * 0.5 if side > 0 else PI - 0.2,
				6, Color(0, 0, 0, 0.2), 3.0)
	ink_rect(ci, Rect2(head.x + side * 7.5 - (0.5 if side > 0 else 1.5), head.y + 1.0, 2, 2.5), c.skin, 1.0)   # nose
	if o.get("mouth_open", false):
		ci.draw_circle(head + Vector2(side * 4.5, 4.5), 2.4, INK)
	_head_extras(ci, o, head, side)

const HIVIS := Color("ff7a1a")
const RIOT := Color("2a3448")
const GORE := Color("7a0e12")

## Things worn over the torso: hi-vis vest, riot vest, apron, tie, blood stains.
## `view` = "front" | "back" | "side" (`side` = -1 / 1 for the side view).
static func _torso_extras(ci: CanvasItem, o: Dictionary, c: Dictionary, oy: float, view: String, side: float) -> void:
	var x0 := -11.0 if view == "front" else (-10.0 if view == "back" else -8.0)
	var w := 22.0 if view == "front" else (20.0 if view == "back" else 16.0)
	if o.get("riot", false):
		# riot vest: dark armored panels and shoulder pads
		ink_rect(ci, Rect2(x0, -9 + oy, w, 12), RIOT, 1.5)
		ci.draw_rect(Rect2(x0 + 2, -6 + oy, w - 4, 1.2), shade(RIOT, 0.25))
		ci.draw_rect(Rect2(x0 + 2, -2 + oy, w - 4, 1.2), shade(RIOT, 0.25))
		if view != "side":
			ink_rect(ci, Rect2(x0 - 4, -10 + oy, 6, 5), shade(RIOT, 0.1), 1.2)
			ink_rect(ci, Rect2(x0 + w - 2, -10 + oy, 6, 5), shade(RIOT, 0.1), 1.2)
	elif o.get("vest", false):
		# hi-vis vest: orange panels with VERTICAL reflective straps (never a bar across the chest)
		if view == "front":
			ink_rect(ci, Rect2(-11, -9 + oy, 8, 12), HIVIS, 1.2)
			ink_rect(ci, Rect2(3, -9 + oy, 8, 12), HIVIS, 1.2)
			ci.draw_rect(Rect2(-8, -9 + oy, 2, 12), Color(0.9, 0.9, 0.92))
			ci.draw_rect(Rect2(6, -9 + oy, 2, 12), Color(0.9, 0.9, 0.92))
		else:
			ink_rect(ci, Rect2(x0, -9 + oy, w, 12), HIVIS, 1.2)
			if view == "back":
				ci.draw_rect(Rect2(-6, -9 + oy, 2, 12), Color(0.9, 0.9, 0.92))
				ci.draw_rect(Rect2(4, -9 + oy, 2, 12), Color(0.9, 0.9, 0.92))
	if o.get("apron", false):
		if view == "front":
			ink_rect(ci, Rect2(-8, -6 + oy, 16, 17), Color("e8e4dc"), 1.2)
			ci.draw_rect(Rect2(-8, 6 + oy, 16, 3), Color("c8c0b4"))
		elif view == "side":
			ink_rect(ci, Rect2(side * 4.0 - 2.0, -6 + oy, 4, 17), Color("e8e4dc"), 1.2)
		else:
			ci.draw_line(Vector2(-8, -1 + oy), Vector2(8, -1 + oy), Color("e8e4dc"), 1.5)
	if o.get("tie", false) and view == "front":
		ink_poly(ci, PackedVector2Array([Vector2(-1.5, -8 + oy), Vector2(1.5, -8 + oy), Vector2(2.5, 1 + oy),
			Vector2(0, 3.5 + oy), Vector2(-2.5, 1 + oy)]), BLOOD, 1.0)
	if o.get("blood", false):
		# a few dark stains (comic, not gory)
		ci.draw_circle(Vector2(x0 + w * 0.3, -3 + oy), 3.2, GORE)
		ci.draw_circle(Vector2(x0 + w * 0.65, 1 + oy), 2.2, GORE)
		ci.draw_rect(Rect2(x0 + w * 0.3 - 0.8, -3 + oy, 1.6, 7), GORE)

## Things worn on the head: party hat, cook's hat, riot helmet.
static func _head_extras(ci: CanvasItem, o: Dictionary, head: Vector2, side: float) -> void:
	if o.get("riot", false):
		var hp := PackedVector2Array()
		for i in 13:
			var a := PI + i * PI / 12.0
			hp.append(head + Vector2(cos(a) * 9.5, sin(a) * 9.0 - 1.0))
		hp.append(head + Vector2(9.5, 1))
		hp.append(head + Vector2(-9.5, 1))
		ink_poly(ci, hp, RIOT, 1.6)
		ci.draw_rect(Rect2(head.x - 9.5, head.y - 2, 19, 2), shade(RIOT, 0.3))          # visor (up)
	if o.get("hat", false):
		var col: Color = o.get("hat_color", Color("e84a8a"))
		ink_poly(ci, PackedVector2Array([head + Vector2(-5, -7), head + Vector2(5, -7), head + Vector2(side * 2.0, -19)]), col, 1.4)
		ci.draw_line(head + Vector2(-3, -11), head + Vector2(3, -11), YELLOW, 1.4)
		ci.draw_circle(head + Vector2(side * 2.0, -19), 1.8, YELLOW)
	if o.get("toque", false):
		ink_rect(ci, Rect2(head.x - 6, head.y - 13, 12, 6), Color("f0ece4"), 1.4)
		ink_circle(ci, head + Vector2(0, -15), 5.5, Color("f0ece4"), 1.4)

## The item in the hand: wrench / pistol / knife / baton, rotated by `swing` (0..1) during an attack.
static func _held(ci: CanvasItem, o: Dictionary, hand: Vector2, dir: Vector2, swing: float) -> void:
	var held: String = o.get("held", "none")
	if held == "none":
		return
	var d := dir.rotated(-1.1 + swing * 2.2) if swing > 0.0 else dir
	match held:
		"wrench":
			# long red pipe wrench with steel jaw (like the concept sheet)
			var tip := hand + d * 15.0
			ci.draw_line(hand, tip, INK, 6.0)
			ci.draw_line(hand, tip, Color("b3161c"), 3.5)
			var n := Vector2(-d.y, d.x)
			ink_poly(ci, PackedVector2Array([tip + n * 4.0, tip + d * 5.0 + n * 4.0, tip + d * 5.0 - n * 1.0,
				tip + d * 2.0 - n * 1.0, tip - n * 4.0]), STEEL_HI, 1.4)
		"pistol":
			var tip := hand + d * 9.0
			ci.draw_line(hand, tip, INK, 6.0)
			ci.draw_line(hand, tip, Color("2b2d33"), 3.5)
			ci.draw_line(hand + Vector2(-d.y, d.x) * 0.0, hand + Vector2(0, 5), INK, 4.0)
			ci.draw_line(hand, hand + Vector2(0, 4), Color("2b2d33"), 2.0)
		"knife":
			# short dark handle, then a steel blade
			var mid := hand + d * 4.0
			var tip := hand + d * 12.0
			ci.draw_line(hand, mid, INK, 5.0)
			ci.draw_line(hand, mid, Color("3a2a1e"), 3.0)
			ci.draw_line(mid, tip, INK, 4.5)
			ci.draw_line(mid, tip, STEEL_HI, 2.5)
		"baton":
			var tip := hand + d * 15.0
			ci.draw_line(hand, tip, INK, 5.0)
			ci.draw_line(hand, tip, Color("2a2a30"), 3.0)
		"arm":
			# v0.5: a severed arm held by the wrist: grey-green forearm, a hand at the far end, a
			# bloody stump at the elbow
			var tip := hand + d * 20.0
			ci.draw_line(hand, tip, INK, 7.0)
			ci.draw_line(hand, tip, ZOMBIE, 4.5)
			ink_circle(ci, tip, 3.6, ZOMBIE, 1.2)
			ci.draw_circle(hand - d * 1.5, 2.6, BLOOD)
		"coolant":
			# v0.5: a small white-and-blue coolant can
			ink_rect(ci, Rect2(hand.x - 3.5, hand.y - 6, 7, 10), Color("e8eef4"), 1.2)
			ci.draw_rect(Rect2(hand.x - 3.5, hand.y - 2, 7, 3), Color("4a7ac0"))
			ci.draw_rect(Rect2(hand.x - 1, hand.y - 9, 2, 3), INK)
