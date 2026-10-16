extends RefCounted

## Item and weapon icons, drawn in code in the comic-ink style (last_shift_art.gd). One function
## draws any icon at any size, so the same pictures are used on the B button, the weapon wheel,
## the bag screen and the HUD. Icons are designed in a 32 x 32 box centered on (0, 0).
## No cyan (cyan = infected / lockdown only).

const A = preload("res://scripts/games/last_shift/last_shift_art.gd")

const GLOVE := Color("8f949c")
const GUNMETAL := Color("2b2d33")
const BRASS := Color("c9a227")
const BILL := Color("5f9a55")

## Draws icon `kind` centered at `center`, `size` pixels across. `alpha` dims it (locked items).
## Kinds: fist knife wrench pistol medkit snack bullets money keycard maint_key sec_key cutters party_hat bag wheel
## v0.5: arm (the severed arm) coolant (coolant can) chef_hat map
static func draw(ci: CanvasItem, kind: String, center: Vector2, size: float, alpha: float = 1.0) -> void:
	var k := size / 32.0
	ci.draw_set_transform(center, 0.0, Vector2(k, k))
	match kind:
		"fist": _fist(ci, alpha)
		"knife": _knife(ci, alpha)
		"wrench": _wrench(ci, alpha)
		"pistol": _pistol(ci, alpha)
		"medkit": _medkit(ci, alpha)
		"snack": _snack(ci, alpha)
		"bullets": _bullets(ci, alpha)
		"money": _money(ci, alpha)
		"keycard": _keycard(ci, alpha)
		"maint_key": _key(ci, alpha, BRASS)
		"sec_key": _key(ci, alpha, A.STEEL_HI)
		"cutters": _cutters(ci, alpha)
		"party_hat": _party_hat(ci, alpha)
		"arm": _arm(ci, alpha)
		"coolant": _coolant(ci, alpha)
		"chef_hat": _chef_hat(ci, alpha)
		"map": _map(ci, alpha)
		"bag": _bag(ci, alpha)
		"wheel": _wheel(ci, alpha)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _c(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)

static func _box(ci: CanvasItem, r: Rect2, fill: Color, alpha: float, ink: float = 2.0) -> void:
	ci.draw_rect(r.grow(ink * 0.5), _c(A.INK, alpha))
	ci.draw_rect(r, _c(fill, alpha))

static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, alpha: float, ink: float = 2.0) -> void:
	ci.draw_colored_polygon(pts, _c(fill, alpha))
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, _c(A.INK, alpha), ink)

static func _fist(ci: CanvasItem, a: float) -> void:
	# a clenched glove seen from the front: wrist, palm, four knuckles, the thumb across
	_box(ci, Rect2(-7, 8, 14, 7), A.shade(GLOVE, -0.2), a)                 # wrist cuff
	_box(ci, Rect2(-11, -4, 22, 14), GLOVE, a)                              # palm
	for i in 4:
		_box(ci, Rect2(-11 + i * 5.6, -11, 5.2, 9), A.shade(GLOVE, 0.12), a, 1.6)
		ci.draw_rect(Rect2(-10 + i * 5.6, -10, 3.2, 2), _c(Color(1, 1, 1, 0.35), a))
	_poly(ci, PackedVector2Array([Vector2(-12, 0), Vector2(2, -1), Vector2(4, 3), Vector2(-10, 5)]),
		A.shade(GLOVE, -0.08), a, 1.6)

static func _knife(ci: CanvasItem, a: float) -> void:
	# kitchen knife, diagonal: steel blade top-right, dark handle bottom-left
	_poly(ci, PackedVector2Array([Vector2(-2, 3), Vector2(13, -13), Vector2(15, -11), Vector2(3, 7)]),
		A.STEEL_HI, a, 1.8)
	ci.draw_line(Vector2(0, 4), Vector2(13, -11), _c(Color.WHITE, a), 1.2)
	_poly(ci, PackedVector2Array([Vector2(-3, 1), Vector2(1, 5), Vector2(-1, 7), Vector2(-5, 3)]),
		A.STEEL, a, 1.6)                                                    # bolster
	_poly(ci, PackedVector2Array([Vector2(-4, 4), Vector2(0, 8), Vector2(-11, 16), Vector2(-14, 13)]),
		Color("3a2a1e"), a, 1.8)                                            # handle
	ci.draw_circle(Vector2(-7, 10), 1.0, _c(A.STEEL_HI, a))                 # rivet

static func _wrench(ci: CanvasItem, a: float) -> void:
	# red pipe wrench, diagonal, steel jaw at the top
	var hand0 := Vector2(-12, 12)
	var hand1 := Vector2(6, -6)
	ci.draw_line(hand0, hand1, _c(A.INK, a), 8.0)
	ci.draw_line(hand0, hand1, _c(A.BLOOD, a), 5.0)
	ci.draw_line(hand0 + Vector2(1, -2), hand1 + Vector2(1, -2), _c(A.shade(A.BLOOD, 0.35), a), 1.5)
	_poly(ci, PackedVector2Array([Vector2(2, -10), Vector2(10, -16), Vector2(15, -11), Vector2(12, -8),
		Vector2(14, -4), Vector2(9, -1), Vector2(5, -5)]), A.STEEL_HI, a, 1.8)
	ci.draw_circle(Vector2(7, -7), 1.6, _c(A.INK, a))

static func _pistol(ci: CanvasItem, a: float) -> void:
	# side view, barrel to the right
	_box(ci, Rect2(-12, -9, 26, 8), GUNMETAL, a)                            # slide
	ci.draw_rect(Rect2(-11, -8, 24, 1.5), _c(Color(1, 1, 1, 0.3), a))
	_poly(ci, PackedVector2Array([Vector2(-10, -1), Vector2(-2, -1), Vector2(-4, 13), Vector2(-12, 12)]),
		A.shade(GUNMETAL, 0.1), a)                                          # grip
	ci.draw_arc(Vector2(1, 1), 4.0, 0.0, PI, 8, _c(A.INK, a), 1.8)          # trigger guard
	ci.draw_rect(Rect2(10, -11, 2, 2), _c(A.INK, a))                        # front sight

static func _medkit(ci: CanvasItem, a: float) -> void:
	_box(ci, Rect2(-4, -14, 8, 4), A.CONC_M, a, 1.6)                       # handle
	_box(ci, Rect2(-13, -10, 26, 21), A.WHITE, a)
	ci.draw_rect(Rect2(-13, 7, 26, 4), _c(A.shade(A.WHITE, -0.25), a))
	ci.draw_rect(Rect2(-2.5, -6, 5, 14), _c(A.BLOOD, a))
	ci.draw_rect(Rect2(-7, -1.5, 14, 5), _c(A.BLOOD, a))

static func _snack(ci: CanvasItem, a: float) -> void:
	# a candy bar in its wrapper (crimped ends)
	_poly(ci, PackedVector2Array([Vector2(-15, -6), Vector2(-11, -8), Vector2(-11, 8), Vector2(-15, 6)]),
		A.FIRE, a, 1.6)
	_poly(ci, PackedVector2Array([Vector2(15, -6), Vector2(11, -8), Vector2(11, 8), Vector2(15, 6)]),
		A.FIRE, a, 1.6)
	_box(ci, Rect2(-11, -8, 22, 16), A.FIRE, a)
	ci.draw_rect(Rect2(-7, -4, 14, 8), _c(A.YELLOW, a))
	ci.draw_rect(Rect2(-5, -2, 10, 2), _c(A.RUST_D, a))

static func _bullets(ci: CanvasItem, a: float) -> void:
	for i in 3:
		var x := -11.0 + i * 8.0
		_box(ci, Rect2(x, -2, 6, 13), BRASS, a, 1.6)                        # case
		_poly(ci, PackedVector2Array([Vector2(x, -2), Vector2(x + 6, -2), Vector2(x + 4.5, -9),
			Vector2(x + 1.5, -9)]), A.shade(BRASS, -0.3), a, 1.4)           # bullet head
		ci.draw_rect(Rect2(x + 1, -1, 1.5, 11), _c(Color(1, 1, 1, 0.35), a))

static func _money(ci: CanvasItem, a: float) -> void:
	_box(ci, Rect2(-14, -6, 26, 14), A.shade(BILL, -0.15), a, 1.6)          # bill behind
	_box(ci, Rect2(-12, -9, 26, 14), BILL, a)
	ci.draw_arc(Vector2(1, -2), 4.5, 0.0, TAU, 12, _c(A.shade(BILL, -0.35), a), 1.5)
	ci.draw_string(ThemeDB.fallback_font, Vector2(-2.5, 2), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		_c(A.shade(BILL, -0.5), a))

static func _keycard(ci: CanvasItem, a: float) -> void:
	_box(ci, Rect2(-13, -9, 26, 18), A.WHITE, a)
	ci.draw_rect(Rect2(-13, -5, 26, 4), _c(A.PURPLE, a))
	ci.draw_rect(Rect2(-10, 2, 8, 4), _c(A.CONC_M, a))

static func _key(ci: CanvasItem, a: float, col: Color) -> void:
	ci.draw_circle(Vector2(-7, -5), 7.5, _c(A.INK, a))
	ci.draw_circle(Vector2(-7, -5), 6.0, _c(col, a))
	ci.draw_circle(Vector2(-7, -5), 2.2, _c(A.INK, a))
	_box(ci, Rect2(-2, -6.5, 16, 4), col, a, 1.6)                           # shaft
	_box(ci, Rect2(8, -3, 2.5, 5), col, a, 1.2)                             # teeth
	_box(ci, Rect2(12, -3, 2.5, 4), col, a, 1.2)

static func _bag(ci: CanvasItem, a: float) -> void:
	# a canvas tool bag with a strap and a front pocket
	ci.draw_arc(Vector2(0, -6), 8.0, PI, TAU, 12, _c(A.INK, a), 4.0)
	ci.draw_arc(Vector2(0, -6), 8.0, PI, TAU, 12, _c(Color("8a6a3a"), a), 2.0)
	_box(ci, Rect2(-13, -6, 26, 19), Color("8a6a3a"), a)
	_box(ci, Rect2(-8, 2, 16, 8), Color("6b4a2a"), a, 1.6)
	ci.draw_rect(Rect2(-2, 1, 4, 3), _c(BRASS, a))

static func _wheel(ci: CanvasItem, a: float) -> void:
	# the weapon wheel button: a ring cut in four with a dot
	for i in 4:
		var a0 := -PI * 0.5 + i * PI * 0.5 + 0.15
		ci.draw_arc(Vector2.ZERO, 11.0, a0, a0 + PI * 0.5 - 0.3, 8, _c(A.INK, a), 7.0)
		ci.draw_arc(Vector2.ZERO, 11.0, a0, a0 + PI * 0.5 - 0.3, 8, _c(A.WHITE, a), 4.0)
	ci.draw_circle(Vector2.ZERO, 3.0, _c(A.AMBER, a))

static func _cutters(ci: CanvasItem, a: float) -> void:
	# bolt cutters: two long red grips crossing at a steel jaw
	ci.draw_line(Vector2(-12, 14), Vector2(4, -4), _c(A.INK, a), 6.0)
	ci.draw_line(Vector2(-12, 14), Vector2(4, -4), _c(A.BLOOD, a), 3.5)
	ci.draw_line(Vector2(0, 16), Vector2(6, -2), _c(A.INK, a), 6.0)
	ci.draw_line(Vector2(0, 16), Vector2(6, -2), _c(A.BLOOD, a), 3.5)
	_poly(ci, PackedVector2Array([Vector2(2, -4), Vector2(8, -4), Vector2(12, -14), Vector2(6, -12)]), A.STEEL_HI, a, 1.6)

static func _party_hat(ci: CanvasItem, a: float) -> void:
	# a pink cone with yellow stripes and a pom-pom
	_poly(ci, PackedVector2Array([Vector2(-11, 12), Vector2(11, 12), Vector2(0, -12)]), Color("e84a8a"), a)
	ci.draw_line(Vector2(-6, 2), Vector2(6, 2), _c(A.YELLOW, a), 2.0)
	ci.draw_line(Vector2(-8.5, 7), Vector2(8.5, 7), _c(A.YELLOW, a), 2.0)
	ci.draw_circle(Vector2(0, -13), 3.5, _c(A.INK, a))
	ci.draw_circle(Vector2(0, -13), 2.5, _c(A.YELLOW, a))

static func _arm(ci: CanvasItem, a: float) -> void:
	# a severed forearm, diagonal: a grey-green hand top-right, a bloody stump bottom-left
	ci.draw_line(Vector2(-12, 12), Vector2(7, -7), _c(A.INK, a), 9.0)
	ci.draw_line(Vector2(-12, 12), Vector2(7, -7), _c(A.ZOMBIE, a), 6.0)
	_poly(ci, PackedVector2Array([Vector2(4, -10), Vector2(10, -15), Vector2(15, -12), Vector2(14, -5),
		Vector2(9, -2)]), A.ZOMBIE, a, 1.6)                                  # the hand
	for i in 3:
		ci.draw_line(Vector2(11 + i * 1.5, -14 + i * 2.5), Vector2(15 + i * 1.5, -17 + i * 2.5), _c(A.INK, a), 1.4)
	ci.draw_circle(Vector2(-12, 12), 4.5, _c(A.INK, a))
	ci.draw_circle(Vector2(-12, 12), 3.2, _c(A.BLOOD, a))                   # the stump
	ci.draw_circle(Vector2(-12, 12), 1.2, _c(Color("e8dcc0"), a))           # bone

static func _coolant(ci: CanvasItem, a: float) -> void:
	# a white pressure can with a blue band, a nozzle and a frost puff
	_box(ci, Rect2(-7, -9, 14, 22), Color("e8eef4"), a)
	ci.draw_rect(Rect2(-7, -1, 14, 6), _c(Color("4a7ac0"), a))
	_box(ci, Rect2(-3, -14, 6, 5), A.STEEL, a, 1.4)
	ci.draw_circle(Vector2(9, -14), 3.0, _c(Color(0.9, 0.95, 1.0, 0.9), a))
	ci.draw_circle(Vector2(13, -11), 2.2, _c(Color(0.9, 0.95, 1.0, 0.7), a))

static func _chef_hat(ci: CanvasItem, a: float) -> void:
	# a tall white cook's hat (toque): a band and a puffy top
	_box(ci, Rect2(-9, 3, 18, 9), Color("f0ece4"), a)
	ci.draw_circle(Vector2(-6, -4), 7.5, _c(A.INK, a))
	ci.draw_circle(Vector2(6, -4), 7.5, _c(A.INK, a))
	ci.draw_circle(Vector2(0, -9), 8.5, _c(A.INK, a))
	ci.draw_circle(Vector2(-6, -4), 6.0, _c(Color("f0ece4"), a))
	ci.draw_circle(Vector2(6, -4), 6.0, _c(Color("f0ece4"), a))
	ci.draw_circle(Vector2(0, -9), 7.0, _c(Color("f0ece4"), a))
	ci.draw_rect(Rect2(-8, 4, 16, 2), _c(Color(0, 0, 0, 0.12), a))

static func _map(ci: CanvasItem, a: float) -> void:
	# a folded floor plan: three panels, a route line and a pin
	_poly(ci, PackedVector2Array([Vector2(-14, -10), Vector2(-5, -13), Vector2(-5, 11), Vector2(-14, 14)]), Color("d8d2c0"), a, 1.6)
	_poly(ci, PackedVector2Array([Vector2(-5, -13), Vector2(5, -10), Vector2(5, 14), Vector2(-5, 11)]), Color("c4bea8"), a, 1.6)
	_poly(ci, PackedVector2Array([Vector2(5, -10), Vector2(14, -13), Vector2(14, 11), Vector2(5, 14)]), Color("d8d2c0"), a, 1.6)
	ci.draw_polyline(PackedVector2Array([Vector2(-11, 8), Vector2(-2, 2), Vector2(4, 5), Vector2(10, -5)]), _c(A.BLOOD, a), 2.0)
	ci.draw_circle(Vector2(10, -6), 3.0, _c(A.INK, a))
	ci.draw_circle(Vector2(10, -6), 2.0, _c(A.AMBER, a))
