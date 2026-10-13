extends RefCounted

## Arcade category TEASERS (batch 2, 2026-10-13): 160x90 mini scenes, same rules as
## game_teasers.gd (backdrop + helpers come from there / game_logos.gd / game_logos_arcade.gd).
## Add one: `_teaser_<id>(c, base)`, id in IDS, line in `_scene()`.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")
const A = preload("res://scripts/common/game_logos_arcade.gd")
const T = preload("res://scripts/common/game_teasers.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const BROWN := A.BROWN
const W := 160.0
const H := 90.0

const IDS := A.IDS

static func has(id: String) -> bool:
	return id in IDS

static func draw(c: Control, id: String) -> void:
	var s: float = minf(c.size.x / W, c.size.y / H)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - W * s) * 0.5, (c.size.y - H * s) * 0.5)
	var base := Transform2D(0.0, Vector2(s, s), 0.0, origin)
	c.draw_set_transform_matrix(base)
	_scene(c, base, id)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _scene(c: CanvasItem, base: Transform2D, id: String) -> void:
	match id:
		"snake": _teaser_snake(c, base)
		"block_drop": _teaser_block_drop(c, base)
		"paddle_ball": _teaser_paddle_ball(c, base)
		"brick_breaker": _teaser_brick_breaker(c, base)
		"bird_hop": _teaser_bird_hop(c, base)
		"alien_attack": _teaser_alien_attack(c, base)
		"frog_crossing": _teaser_frog_crossing(c, base)
		"gem_match": _teaser_gem_match(c, base)
		"simon": _teaser_simon(c, base)
		"whack_a_mole": _teaser_whack_a_mole(c, base)
		"reaction_test": _teaser_reaction_test(c, base)
		"bubble_pop": _teaser_bubble_pop(c, base)
		"rock_blaster": _teaser_rock_blaster(c, base)
		"city_defense": _teaser_city_defense(c, base)
		"maze_muncher": _teaser_maze_muncher(c, base)
		"moon_lander": _teaser_moon_lander(c, base)
		"stack_tower": _teaser_stack_tower(c, base)
		"sky_hop": _teaser_sky_hop(c, base)
		"air_hockey": _teaser_air_hockey(c, base)
		"barrel_climb": _teaser_barrel_climb(c, base)
		"cannon_duel": _teaser_cannon_duel(c, base)
		"crypt_crawler": _teaser_crypt_crawler(c, base)
		"mini_golf": _teaser_mini_golf(c, base)
		"pool": _teaser_pool(c, base)

static func _score(c: CanvasItem, s: String, pos: Vector2, col: Color, size: int = 12) -> void:
	L.txt(c, s, pos, size, Color(col, 0.9))

## ---------- the 24 Arcade teasers ----------

static func _teaser_snake(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var pts := PackedVector2Array([Vector2(16, 72), Vector2(64, 72), Vector2(64, 44), Vector2(106, 44), Vector2(106, 20), Vector2(86, 20)])
	c.draw_polyline(pts, Color(LIME, 0.18), 16.0, true)
	c.draw_polyline(pts, LIME.darkened(0.5), 10.0, true)
	c.draw_polyline(pts, LIME.darkened(0.1), 6.0, true)
	var head := pts[5]
	GI._sphere(c, head + Vector2(-2, 0), 8.0, LIME)
	for sgn in [-1.0, 1.0]:
		c.draw_circle(head + Vector2(-4, 4.5 * sgn), 2.3, Color.WHITE)
		c.draw_circle(head + Vector2(-5, 4.5 * sgn), 1.1, Color(0, 0, 0, 0.9))
	GI._glow_line(c, head + Vector2(-10, 0), head + Vector2(-17, 0), PINK, 1.2)
	GI._sphere(c, Vector2(66, 18), 7.0, PINK)
	_score(c, "12", Vector2(138, 12), GOLD, 14)

static func _teaser_block_drop(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, MAGENTA)
	var key := {"C": CYAN, "M": MAGENTA, "L": LIME, "G": GOLD, "P": PINK, "B": BLUE}
	var rows := ["....MM....", "...MMM....", "", "", "", "", "..C.......", "C.CCL.GG..", "CCCLLLGGB.", "CCPLLPGBB.", "PCPPLPGGBB"]
	var x0 := 50.0
	var y0 := 4.0
	for r in range(rows.size()):
		var row: String = rows[r]
		for k in range(row.length()):
			var ch := row[k]
			if ch != ".":
				var col: Color = key[ch]
				L.cell(c, Rect2(x0 + k * 6.0, y0 + r * 7.6, 5.4, 7.0), col, true, 1.0)
	GI._glow_poly(c, PackedVector2Array([Vector2(x0 - 2, 2), Vector2(x0 + 62, 2), Vector2(x0 + 62, 88), Vector2(x0 - 2, 88)]), Color(MAGENTA, 0.7), 1.0)
	_score(c, "340", Vector2(24, 14), GOLD, 14)
	for p in [Vector2(122, 18), Vector2(130, 18), Vector2(138, 18), Vector2(130, 26)]:
		L.cell(c, Rect2(p, Vector2(7, 7)), CYAN, true, 1.0)

static func _teaser_paddle_ball(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	for y in range(4, 88, 10):
		c.draw_line(Vector2(80, y), Vector2(80, y + 5), Color(1, 1, 1, 0.3), 2.0)
	_score(c, "3", Vector2(56, 16), CYAN, 24)
	_score(c, "2", Vector2(104, 16), PINK, 24)
	GI._slab(c, Rect2(10, 30, 6, 28), CYAN.darkened(0.4), CYAN, 3, 0.7)
	GI._slab(c, Rect2(144, 48, 6, 28), PINK.darkened(0.4), PINK, 3, 0.7)
	for i in range(6):
		c.draw_circle(Vector2(70 + i * 6, 56 - i * 3), 1.6 + i * 0.5, Color(GOLD, 0.12 + i * 0.1))
	GI._sphere(c, Vector2(106, 38), 5.5, GOLD)

static func _teaser_brick_breaker(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, PINK)
	var cols := [PINK, GOLD, LIME, CYAN]
	for r in range(4):
		for k in range(8):
			if (r == 3 and k in [2, 3]) or (r == 2 and k == 5):
				continue
			var col: Color = cols[r]
			GI._slab(c, Rect2(8 + k * 18.5, 8 + r * 10, 16.5, 8), col.darkened(0.35), col, 2, 0.4)
	for i in range(5):
		c.draw_circle(Vector2(96 - i * 5, 54 + i * 3.4), 1.6 + (4 - i) * 0.5, Color(CYAN, 0.12 + (4 - i) * 0.1))
	GI._sphere(c, Vector2(98, 52), 5.0, CYAN)
	GI._slab(c, Rect2(60, 80, 44, 6), CYAN.darkened(0.4), CYAN, 3, 0.7)

static func _teaser_bird_hop(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var gaps := [[18, 48], [34, 64], [10, 40]]
	for i in range(3):
		var x := 22.0 + i * 52.0
		var top: float = gaps[i][0]
		var bot: float = gaps[i][1]
		GI._slab(c, Rect2(x, -4, 18, top + 4), LIME.darkened(0.5), LIME, 2, 0.3)
		GI._slab(c, Rect2(x - 3, top - 7, 24, 7), LIME.darkened(0.35), LIME, 2, 0.3)
		GI._slab(c, Rect2(x, bot + 18, 18, 80 - bot), LIME.darkened(0.5), LIME, 2, 0.3)
		GI._slab(c, Rect2(x - 3, bot + 18, 24, 7), LIME.darkened(0.35), LIME, 2, 0.3)
	A.logo_at(c, base, "bird_hop", Vector2(52, 44), 38.0)
	_score(c, "7", Vector2(80, 12), Color.WHITE, 18)

static func _teaser_alien_attack(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var cols := [PINK, GOLD, LIME]
	for r in range(3):
		for k in range(6):
			if r == 1 and k == 3:
				continue
			A.invader(c, Vector2(26 + k * 21, 12 + r * 14), 14.0, cols[r])
	for k in range(3):
		GI._slab(c, Rect2(24 + k * 48, 66, 18, 8), CYAN.darkened(0.6), CYAN, 3, 0.3)
	GI._glow_line(c, Vector2(80, 50), Vector2(80, 62), CYAN, 1.8)
	var ship := PackedVector2Array([Vector2(80, 76), Vector2(72, 88), Vector2(88, 88)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.4))
	GI._glow_poly(c, ship, CYAN, 1.5)
	GI._glow_line(c, Vector2(118, 24), Vector2(118, 32), PINK, 1.2)

static func _teaser_frog_crossing(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, LIME)
	# river (top two lanes), road (middle two), grass strips
	c.draw_rect(Rect2(0, 6, W, 28), Color(BLUE, 0.22))
	c.draw_rect(Rect2(0, 38, W, 28), Color(0.08, 0.09, 0.14, 0.9))
	c.draw_rect(Rect2(0, 70, W, 20), Color(LIME, 0.12))
	for x in range(0, 160, 14):
		c.draw_line(Vector2(x, 52), Vector2(x + 7, 52), Color(1, 1, 1, 0.35), 1.4)
	var logs := [Rect2(14, 10, 40, 8), Rect2(86, 10, 34, 8), Rect2(40, 22, 36, 8), Rect2(110, 22, 40, 8)]
	for r in logs:
		GI._slab(c, r, BROWN.darkened(0.5), BROWN, 4, 0.0)
	var cars := [[Rect2(20, 41, 22, 9), PINK], [Rect2(98, 41, 26, 9), GOLD], [Rect2(58, 55, 24, 9), CYAN], [Rect2(130, 55, 20, 9), PINK]]
	for cr in cars:
		var col: Color = cr[1]
		GI._slab(c, cr[0], col.darkened(0.4), col, 3, 0.5)
	A.logo_at(c, base, "frog_crossing", Vector2(80, 78), 22.0)

static func _teaser_gem_match(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, MAGENTA)
	var cols := [CYAN, PINK, LIME, GOLD, BLUE]
	for r in range(5):
		for k in range(7):
			var idx := (r * 3 + k * 2 + (r * k) % 3) % 5
			var ctr := Vector2(35 + k * 15.0, 12 + r * 15.0)
			c.draw_rect(Rect2(ctr - Vector2(7, 7), Vector2(14, 14)), Color(1, 1, 1, 0.04))
			A.gem(c, ctr, 5.8, cols[idx])
	GI._glow_poly(c, PackedVector2Array([Vector2(66, 36), Vector2(80, 36), Vector2(80, 50), Vector2(66, 50)]), Color.WHITE, 1.2)
	_score(c, "850", Vector2(16, 14), GOLD, 12)

static func _teaser_simon(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	A.logo_at(c, base, "simon", Vector2(80, 45), 86.0)
	var cols := [LIME, PINK, GOLD, CYAN, PINK]
	for i in range(5):
		var col: Color = cols[i]
		c.draw_circle(Vector2(14 + i * 7, 80), 2.6, Color(col, 0.9 if i < 4 else 0.25))
	_score(c, "4", Vector2(142, 14), GOLD, 20)

static func _teaser_whack_a_mole(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, BROWN)
	var holes := [Vector2(32, 38), Vector2(80, 38), Vector2(128, 38), Vector2(56, 72), Vector2(104, 72)]
	var up := [false, true, false, false, true]
	for i in range(5):
		A.mole(c, holes[i], 0.9, up[i])
	A.tube(c, Vector2(138, 74), -PI * 0.6, 30.0, 4.0, BROWN)
	GI._slab(c, Rect2(116, 50, 28, 14), GOLD.darkened(0.5), GOLD, 4, 0.5)
	_score(c, "9", Vector2(16, 12), GOLD, 16)

static func _teaser_reaction_test(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	for k in range(3):
		c.draw_arc(Vector2(80, 42), 30.0 + k * 9.0, 0.0, TAU, 40, Color(LIME, 0.28 - k * 0.08), 2.0, true)
	GI._sphere(c, Vector2(80, 42), 26.0, LIME)
	L.txt(c, "!", Vector2(80, 42), 34, Color(1, 1, 1, 0.95))
	L.txt(c, "0.24", Vector2(80, 80), 15, Color(CYAN, 0.95))

static func _teaser_bubble_pop(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var list := [
		[Vector2(24, 62), 18.0, CYAN], [Vector2(56, 30), 14.0, PINK], [Vector2(88, 66), 21.0, LIME],
		[Vector2(122, 28), 16.0, GOLD], [Vector2(138, 66), 11.0, PINK], [Vector2(20, 22), 8.0, GOLD],
		[Vector2(60, 76), 7.0, BLUE], [Vector2(104, 12), 6.0, CYAN],
	]
	for b in list:
		A.bubble(c, b[0], b[1], b[2])
	for i in range(8):
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		GI._glow_line(c, Vector2(56, 30) + d * 20.0, Vector2(56, 30) + d * 27.0, PINK, 0.8)

static func _teaser_rock_blaster(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	A.star_field(c, Rect2(0, 0, W, H), 18, 7)
	A.rock(c, Vector2(30, 28), 18.0, 0.6, GOLD)
	A.rock(c, Vector2(124, 24), 14.0, 2.1, GOLD)
	A.rock(c, Vector2(136, 66), 9.0, 4.0, GOLD)
	A.rock(c, Vector2(26, 70), 7.0, 1.0, GOLD)
	GI._glow_line(c, Vector2(80, 44), Vector2(112, 28), PINK, 1.6)
	var ship := PackedVector2Array([Vector2(86, 40), Vector2(68, 56), Vector2(76, 50), Vector2(76, 62)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.55))
	GI._glow_poly(c, ship, CYAN, 1.8)
	_score(c, "420", Vector2(80, 12), Color.WHITE, 12)

static func _teaser_city_defense(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	var hs := [16, 26, 20, 34, 18, 28, 22, 30, 16, 24]
	for i in range(10):
		var h: int = hs[i]
		GI._slab(c, Rect2(8 + i * 15, 88 - h, 12, h), BLUE.darkened(0.6), BLUE, 2, 0.3)
	GI._glow_arc(c, Vector2(80, 90), 76.0, PI * 1.1, PI * 1.9, CYAN, 1.2)
	for p in [[Vector2(20, 4), Vector2(40, 52)], [Vector2(70, 2), Vector2(62, 40)], [Vector2(130, 6), Vector2(112, 56)], [Vector2(150, 8), Vector2(138, 60)]]:
		GI._glow_line(c, p[0], p[1], PINK, 1.2)
		c.draw_circle(p[1], 2.4, Color.WHITE)
	c.draw_circle(Vector2(62, 40), 14.0, Color(GOLD, 0.22))
	c.draw_circle(Vector2(62, 40), 9.0, Color(GOLD, 0.5))
	c.draw_circle(Vector2(62, 40), 4.0, Color.WHITE)
	_score(c, "6", Vector2(146, 78), CYAN, 12)

static func _teaser_maze_muncher(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	var walls := [Rect2(10, 8, 40, 16), Rect2(62, 8, 36, 16), Rect2(110, 8, 40, 16), Rect2(10, 34, 20, 22), Rect2(130, 34, 20, 22), Rect2(44, 36, 72, 14), Rect2(10, 66, 52, 16), Rect2(98, 66, 52, 16)]
	for w in walls:
		GI._slab(c, w, Color(BLUE, 0.1), BLUE, 6, 0.4)
	for k in range(10):
		c.draw_circle(Vector2(34 + k * 10, 30), 1.6, Color(1, 1, 1, 0.85))
		c.draw_circle(Vector2(36 + k * 9, 60), 1.6, Color(1, 1, 1, 0.85))
	A.pac(c, Vector2(48, 60), 8.0, GOLD)
	A.ghost(c, Vector2(100, 60), 7.0, PINK)
	A.ghost(c, Vector2(118, 30), 7.0, CYAN)
	c.draw_circle(Vector2(20, 60), 3.4, Color(1, 1, 1, 0.9))
	_score(c, "230", Vector2(80, 88), GOLD, 9)

static func _teaser_moon_lander(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	A.star_field(c, Rect2(0, 0, W, 60), 16, 11)
	var g := PackedVector2Array([Vector2(0, 90), Vector2(0, 74), Vector2(30, 78), Vector2(46, 70), Vector2(60, 80), Vector2(104, 80), Vector2(120, 68), Vector2(146, 76), Vector2(160, 70), Vector2(160, 90)])
	c.draw_colored_polygon(g, Color(0.12, 0.14, 0.2))
	GI._glow_poly_open(c, g.slice(1, 9), Color(1, 1, 1, 0.5), 1.2)
	GI._glow_line(c, Vector2(60, 80), Vector2(104, 80), LIME, 2.4)
	A.logo_at(c, base, "moon_lander", Vector2(86, 40), 50.0)
	L.meter(c, Rect2(10, 10, 40, 6), GOLD, 0.6)
	_score(c, "18", Vector2(140, 14), CYAN, 12)

static func _teaser_stack_tower(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, PINK)
	var cols := [CYAN, BLUE, LIME, GOLD, PINK, CYAN, MAGENTA]
	var xs := [48, 50, 52, 50, 54, 52, 56]
	var ws := [64, 60, 56, 54, 50, 48, 44]
	for i in range(7):
		var col: Color = cols[i]
		GI._slab(c, Rect2(xs[i], 76 - i * 11, ws[i], 10), col.darkened(0.4), col, 3, 0.5)
	GI._slab(c, Rect2(96, -2, 44, 10), GOLD.darkened(0.4), GOLD, 3, 0.5)
	GI._glow_line(c, Vector2(92, 3), Vector2(86, 3), Color(1, 1, 1, 0.5), 1.4)
	GI._slab(c, Rect2(112, 40, 12, 6), PINK.darkened(0.4), Color(PINK, 0.4), 2, 0.0)
	_score(c, "14", Vector2(24, 16), Color.WHITE, 24)

static func _teaser_sky_hop(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var ps := [Vector2(24, 80), Vector2(70, 62), Vector2(116, 44), Vector2(40, 38), Vector2(100, 14), Vector2(18, 12)]
	for i in range(ps.size()):
		var col: Color = BLUE if i % 3 == 2 else LIME
		GI._slab(c, Rect2(ps[i].x, ps[i].y, 30, 6), col.darkened(0.45), col, 3, 0.5)
	GI._glow_line(c, Vector2(131, 44), Vector2(131, 37), GOLD, 1.6)
	A.logo_at(c, base, "sky_hop", Vector2(84, 40), 40.0)
	for i in range(3):
		c.draw_circle(Vector2(84, 62 + i * 5), 1.6 - i * 0.4, Color(1, 1, 1, 0.5))
	_score(c, "230", Vector2(138, 80), GOLD, 12)

static func _teaser_air_hockey(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	GI._slab(c, Rect2(10, 6, 140, 78), Color(0.02, 0.05, 0.1), CYAN, 12, 0.6)
	GI._slab(c, Rect2(8, 30, 5, 30), Color(0, 0, 0), Color(0, 0, 0, 0), 2, 0.0)
	GI._slab(c, Rect2(147, 30, 5, 30), Color(0, 0, 0), Color(0, 0, 0, 0), 2, 0.0)
	c.draw_line(Vector2(80, 8), Vector2(80, 82), Color(CYAN, 0.5), 1.4)
	c.draw_arc(Vector2(80, 45), 14.0, 0.0, TAU, 28, Color(CYAN, 0.5), 1.4, true)
	GI._sphere(c, Vector2(34, 48), 10.0, CYAN)
	GI._sphere(c, Vector2(122, 36), 10.0, PINK)
	c.draw_circle(Vector2(92, 52), 5.0, Color(0.05, 0.05, 0.1))
	c.draw_arc(Vector2(92, 52), 5.0, 0.0, TAU, 14, GOLD, 1.8, true)
	_score(c, "3", Vector2(60, 18), CYAN, 14)
	_score(c, "1", Vector2(100, 18), PINK, 14)

static func _teaser_barrel_climb(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, PINK)
	GI._glow_line(c, Vector2(4, 24), Vector2(150, 32), PINK, 2.4)
	GI._glow_line(c, Vector2(10, 52), Vector2(156, 44), PINK, 2.4)
	GI._glow_line(c, Vector2(4, 80), Vector2(150, 88), PINK, 2.4)
	for x in [120, 36]:
		var y0 := 36.0 if x == 36 else 28.0
		var y1 := 50.0 if x == 36 else 48.0
		GI._glow_line(c, Vector2(x, y0 + 8), Vector2(x, y1 + 10), CYAN, 1.2)
		GI._glow_line(c, Vector2(x + 8, y0 + 8), Vector2(x + 8, y1 + 10), CYAN, 1.2)
	for k in range(4):
		GI._glow_line(c, Vector2(36, 48 + k * 5), Vector2(44, 48 + k * 5), CYAN, 1.0)
		GI._glow_line(c, Vector2(120, 38 + k * 5), Vector2(128, 38 + k * 5), CYAN, 1.0)
	for p in [Vector2(96, 22), Vector2(60, 36), Vector2(110, 54)]:
		GI._sphere(c, p, 6.0, BROWN)
		GI._glow_line(c, p + Vector2(-5, 0), p + Vector2(5, 0), GOLD, 1.0)
	GI._sphere(c, Vector2(24, 70), 4.5, LIME)
	GI._slab(c, Rect2(20, 74, 8, 8), LIME.darkened(0.4), LIME, 2, 0.0)
	GI._sphere(c, Vector2(144, 16), 6.0, PINK)

static func _teaser_cannon_duel(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	var hills := PackedVector2Array([Vector2(0, 90), Vector2(0, 66), Vector2(30, 60), Vector2(56, 74), Vector2(80, 80), Vector2(104, 74), Vector2(130, 60), Vector2(160, 66), Vector2(160, 90)])
	c.draw_colored_polygon(hills, Color(0.05, 0.12, 0.1))
	GI._glow_poly_open(c, hills.slice(1, 8), LIME, 1.2)
	A.tube(c, Vector2(26, 54), -0.8, 22.0, 8.0, CYAN)
	A.tube(c, Vector2(134, 54), -PI + 0.8, 22.0, 8.0, PINK)
	GI._sphere(c, Vector2(26, 56), 8.0, CYAN)
	GI._sphere(c, Vector2(134, 56), 8.0, PINK)
	for i in range(11):
		var t := i / 10.0
		c.draw_circle(Vector2(42.0 + t * 76.0, 44.0 - sin(t * PI) * 34.0), 1.6, Color(GOLD, 0.8))
	GI._sphere(c, Vector2(100, 32), 4.0, GOLD)
	c.draw_circle(Vector2(130, 44), 8.0, Color(GOLD, 0.25))
	GI._glow_poly(c, PackedVector2Array([Vector2(66, 12), Vector2(82, 16), Vector2(66, 20)]), CYAN, 1.2)

static func _teaser_crypt_crawler(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	GI._slab(c, Rect2(8, 6, 144, 78), Color(0.03, 0.04, 0.08, 0.9), Color(CYAN, 0.6), 8, 0.3)
	for p in [Vector2(14, 12), Vector2(146, 12), Vector2(14, 78), Vector2(146, 78)]:
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(3.5, 1), p + Vector2(-3.5, 1)]), Color(GOLD, 0.9))
		c.draw_circle(p + Vector2(0, -2), 7.0, Color(GOLD, 0.12))
	A.logo_at(c, base, "crypt_crawler", Vector2(112, 38), 34.0)
	A.logo_at(c, base, "crypt_crawler", Vector2(66, 62), 22.0)
	GI._sphere(c, Vector2(44, 40), 8.0, CYAN)
	GI._glow_line(c, Vector2(52, 36), Vector2(66, 28), Color.WHITE, 1.4)
	GI._slab(c, Rect2(122, 62, 22, 14), GOLD.darkened(0.5), GOLD, 3, 0.5)
	L.meter(c, Rect2(24, 12, 40, 5), PINK, 0.7)

static func _teaser_mini_golf(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	GI._slab(c, Rect2(8, 10, 144, 72), LIME.darkened(0.7), LIME, 22, 0.5)
	GI._slab(c, Rect2(70, 30, 8, 34), CYAN.darkened(0.5), CYAN, 3, 0.5)
	GI._ellipse(c, Vector2(128, 50), 8.0, 4.0, Color(0, 0, 0))
	GI._glow_line(c, Vector2(128, 50), Vector2(128, 18), Color.WHITE, 1.2)
	var flag := PackedVector2Array([Vector2(128, 18), Vector2(142, 23), Vector2(128, 29)])
	c.draw_colored_polygon(flag, PINK)
	for i in range(9):
		var t := i / 8.0
		c.draw_circle(Vector2(32.0 + t * 38.0, 62.0 - sin(t * PI) * 26.0), 1.5, Color(1, 1, 1, 0.55))
	GI._sphere(c, Vector2(26, 62), 6.0, Color(0.85, 0.9, 1.0))
	_score(c, "2", Vector2(20, 24), GOLD, 14)

static func _teaser_pool(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	GI._slab(c, Rect2(6, 6, 148, 78), Color(0.02, 0.2, 0.14), GOLD, 14, 0.5)
	for p in [Vector2(10, 10), Vector2(80, 8), Vector2(150, 10), Vector2(10, 80), Vector2(80, 82), Vector2(150, 80)]:
		c.draw_circle(p, 5.0, Color(0, 0, 0))
	var cols := [GOLD, PINK, CYAN, LIME, MAGENTA, BLUE]
	var n := 0
	for k in range(4):
		for j in range(k + 1):
			var col: Color = cols[n % cols.size()]
			if n == 4:
				col = Color(0.15, 0.15, 0.2)
			GI._sphere(c, Vector2(110.0 + k * 8.0, 45.0 + (j - k * 0.5) * 9.0), 4.3, col)
			n += 1
	GI._sphere(c, Vector2(40, 45), 4.5, Color(0.95, 0.95, 1.0))
	for i in range(5):
		c.draw_circle(Vector2(46 + i * 8, 45), 1.1, Color(1, 1, 1, 0.55))
	GI._glow_line(c, Vector2(34, 45), Vector2(12, 45), GOLD, 1.8)
