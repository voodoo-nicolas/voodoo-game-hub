extends RefCounted

## Arcade category logos drawn in code (batch 2, 2026-10-13): same style and 100x100 box as
## game_logos.gd (whose helpers it reuses). Also holds the shared object helpers the arcade
## teasers use (gem, bubble, rock, invader, pac, ghost, mole, tube ...).
## Add one: `_logo_<id>(c)`, id in IDS, line in `_logo()`. Used through game_art.gd.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const BROWN := Color("c8803a")
const WHITE := Color(1, 1, 1, 0.95)

const IDS := [
	"snake", "block_drop", "paddle_ball", "brick_breaker", "bird_hop", "alien_attack",
	"frog_crossing", "gem_match", "simon", "whack_a_mole", "reaction_test", "bubble_pop",
	"rock_blaster", "city_defense", "maze_muncher", "moon_lander", "stack_tower", "sky_hop",
	"air_hockey", "barrel_climb", "cannon_duel", "crypt_crawler", "mini_golf", "pool",
]

const INVADER := [
	"..x.....x..", "...x...x...", "..xxxxxxx..", ".xx.xxx.xx.",
	"xxxxxxxxxxx", "x.xxxxxxx.x", "x.x.....x.x", "...xx.xx...",
]

static func has(id: String) -> bool:
	return id in IDS

static func draw(c: Control, id: String) -> void:
	var s: float = min(c.size.x, c.size.y)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - s) * 0.5, (c.size.y - s) * 0.5)
	c.draw_set_transform_matrix(Transform2D(0.0, Vector2(s / 100.0, s / 100.0), 0.0, origin))
	_logo(c, id)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func logo_at(c: CanvasItem, base: Transform2D, id: String, ctr: Vector2, size: float) -> void:
	var k := size / 100.0
	c.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(k, k), 0.0, ctr - Vector2(size, size) * 0.5))
	_logo(c, id)
	c.draw_set_transform_matrix(base)

static func _logo(c: CanvasItem, id: String) -> void:
	match id:
		"snake": _logo_snake(c)
		"block_drop": _logo_block_drop(c)
		"paddle_ball": _logo_paddle_ball(c)
		"brick_breaker": _logo_brick_breaker(c)
		"bird_hop": _logo_bird_hop(c)
		"alien_attack": _logo_alien_attack(c)
		"frog_crossing": _logo_frog_crossing(c)
		"gem_match": _logo_gem_match(c)
		"simon": _logo_simon(c)
		"whack_a_mole": _logo_whack_a_mole(c)
		"reaction_test": _logo_reaction_test(c)
		"bubble_pop": _logo_bubble_pop(c)
		"rock_blaster": _logo_rock_blaster(c)
		"city_defense": _logo_city_defense(c)
		"maze_muncher": _logo_maze_muncher(c)
		"moon_lander": _logo_moon_lander(c)
		"stack_tower": _logo_stack_tower(c)
		"sky_hop": _logo_sky_hop(c)
		"air_hockey": _logo_air_hockey(c)
		"barrel_climb": _logo_barrel_climb(c)
		"cannon_duel": _logo_cannon_duel(c)
		"crypt_crawler": _logo_crypt_crawler(c)
		"mini_golf": _logo_mini_golf(c)
		"pool": _logo_pool(c)

## ---------- shared object helpers ----------

static func gem(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array([
		ctr + Vector2(0, -r), ctr + Vector2(r * 0.85, -r * 0.35), ctr + Vector2(r * 0.85, r * 0.35),
		ctr + Vector2(0, r), ctr + Vector2(-r * 0.85, r * 0.35), ctr + Vector2(-r * 0.85, -r * 0.35)])
	c.draw_circle(ctr, r * 1.3, Color(col, 0.12))
	c.draw_colored_polygon(p, col.darkened(0.5))
	c.draw_colored_polygon(PackedVector2Array([p[0], p[1], ctr, p[5]]), col)
	c.draw_colored_polygon(PackedVector2Array([p[1], p[2], ctr]), col.darkened(0.25))
	GI._glow_poly(c, p, col.lightened(0.25), 1.3)
	c.draw_line(p[5], ctr, Color(1, 1, 1, 0.45), 1.0, true)
	c.draw_line(ctr, p[1], Color(1, 1, 1, 0.45), 1.0, true)

## An annular sector (Simon pads).
static func wedge(c: CanvasItem, ctr: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color, lit: bool) -> void:
	var p := PackedVector2Array()
	for i in range(11):
		var a := lerpf(a0, a1, i / 10.0)
		p.append(ctr + Vector2(cos(a), sin(a)) * r1)
	for i in range(10, -1, -1):
		var a := lerpf(a0, a1, i / 10.0)
		p.append(ctr + Vector2(cos(a), sin(a)) * r0)
	c.draw_colored_polygon(p, col if lit else col.darkened(0.6))
	GI._glow_poly(c, p, col, 2.2 if lit else 1.1)

static func bubble(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	c.draw_circle(ctr, r, Color(col, 0.16))
	c.draw_arc(ctr, r, 0.0, TAU, 28, Color(col, 0.25), 5.0, true)
	c.draw_arc(ctr, r, 0.0, TAU, 28, col, 1.8, true)
	c.draw_arc(ctr, r * 0.66, PI * 1.12, PI * 1.55, 8, Color(1, 1, 1, 0.85), 1.8, true)

## A lumpy asteroid outline.
static func rock(c: CanvasItem, ctr: Vector2, r: float, seed_v: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in range(10):
		var a := TAU * i / 10.0
		p.append(ctr + Vector2(cos(a), sin(a)) * r * (0.78 + 0.22 * sin(i * 2.3 + seed_v)))
	c.draw_colored_polygon(p, col.darkened(0.7))
	GI._glow_poly(c, p, col, 1.8)

static func invader(c: CanvasItem, ctr: Vector2, w: float, col: Color) -> void:
	var u := w / 11.0
	var o := ctr - Vector2(w * 0.5, 4.0 * u)
	for pass_i in range(2):
		for r in range(8):
			var row: String = INVADER[r]
			for k in range(11):
				if row[k] == "x":
					var rc := Rect2(o + Vector2(k * u, r * u), Vector2(u, u))
					if pass_i == 0:
						c.draw_rect(rc.grow(u * 0.3), Color(col, 0.18))
					else:
						c.draw_rect(rc, col)

static func pac(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array([ctr])
	for i in range(25):
		var a := 0.45 + (TAU - 0.9) * i / 24.0
		p.append(ctr + Vector2(cos(a), sin(a)) * r)
	c.draw_circle(ctr, r * 1.25, Color(col, 0.13))
	c.draw_colored_polygon(p, col.darkened(0.15))
	GI._glow_poly(c, p, col, 1.6)
	c.draw_circle(ctr + Vector2(r * 0.1, -r * 0.5), r * 0.1, Color(0, 0, 0, 0.85))

static func ghost(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in range(13):
		var a := PI + PI * i / 12.0
		p.append(ctr + Vector2(cos(a), sin(a)) * r)
	p.append(ctr + Vector2(r, r))
	p.append(ctr + Vector2(r * 0.5, r * 0.7))
	p.append(ctr + Vector2(0, r))
	p.append(ctr + Vector2(-r * 0.5, r * 0.7))
	p.append(ctr + Vector2(-r, r))
	c.draw_circle(ctr, r * 1.3, Color(col, 0.12))
	c.draw_colored_polygon(p, col.darkened(0.25))
	GI._glow_poly(c, p, col, 1.5)
	for sx in [-0.4, 0.4]:
		c.draw_circle(ctr + Vector2(sx * r, -r * 0.2), r * 0.27, Color.WHITE)
		c.draw_circle(ctr + Vector2(sx * r + r * 0.08, -r * 0.2), r * 0.13, BLUE.darkened(0.3))

## A mole popping out of its hole (hole centre `ctr`, scale k).
static func mole(c: CanvasItem, ctr: Vector2, k: float, up: bool = true) -> void:
	c.draw_colored_polygon(GI._pts(ctr, 23.0 * k, 7.5 * k), Color(0.02, 0.03, 0.05))
	if up:
		var p := PackedVector2Array()
		for i in range(17):
			var a := PI + PI * i / 16.0
			p.append(ctr + Vector2(cos(a) * 16.0 * k, sin(a) * 28.0 * k))
		c.draw_colored_polygon(p, BROWN.darkened(0.45))
		GI._glow_poly_open(c, p, BROWN, 1.6)
		for sx in [-1.0, 1.0]:
			c.draw_circle(ctr + Vector2(sx * 6.0 * k, -17.0 * k), 3.2 * k, Color.WHITE)
			c.draw_circle(ctr + Vector2(sx * 6.0 * k, -16.5 * k), 1.5 * k, Color(0, 0, 0, 0.9))
		c.draw_circle(ctr + Vector2(0, -10.0 * k), 3.4 * k, PINK)
	var rim := GI._pts(ctr, 23.0 * k, 7.5 * k).slice(0, 21)
	c.draw_polyline(rim, Color(CYAN, 0.8), 1.6, true)

## A cannon barrel / thick bar from `from` at angle `ang` (radians).
static func tube(c: CanvasItem, from: Vector2, ang: float, length: float, w: float, col: Color) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x) * w * 0.5
	var p := PackedVector2Array([from + n, from + d * length + n * 0.8, from + d * length - n * 0.8, from - n])
	c.draw_colored_polygon(p, col.darkened(0.45))
	GI._glow_poly(c, p, col, 1.6)

static func star_field(c: CanvasItem, area: Rect2, n: int, seed_v: int) -> void:
	for i in range(n):
		var fx := fposmod(sin((i + seed_v) * 12.9898) * 43758.5453, 1.0)
		var fy := fposmod(sin((i + seed_v) * 78.233) * 24634.6345, 1.0)
		c.draw_circle(area.position + Vector2(fx * area.size.x, fy * area.size.y), 0.9 + fx * 0.8, Color(1, 1, 1, 0.35 + fy * 0.4))

## ---------- the 24 Arcade logos ----------

static func _logo_snake(c: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for i in range(13):
		var t := i / 12.0
		pts.append(Vector2(12.0 + 66.0 * t, 64.0 - sin(t * TAU * 1.15 + 0.4) * 17.0))
	c.draw_polyline(pts, Color(LIME, 0.18), 18.0, true)
	c.draw_polyline(pts, LIME.darkened(0.5), 11.0, true)
	c.draw_polyline(pts, LIME.darkened(0.1), 7.0, true)
	c.draw_polyline(pts, Color(1, 1, 1, 0.35), 1.6, true)
	var head := pts[12]
	var dir := (pts[12] - pts[11]).normalized()
	var side := Vector2(-dir.y, dir.x)
	GI._sphere(c, head + dir * 2.0, 9.0, LIME)
	for sgn in [-1.0, 1.0]:
		c.draw_circle(head + dir * 3.0 + side * 5.0 * sgn, 2.6, Color.WHITE)
		c.draw_circle(head + dir * 4.0 + side * 5.0 * sgn, 1.2, Color(0, 0, 0, 0.9))
	GI._glow_line(c, head + dir * 11.0, head + dir * 19.0, PINK, 1.4)
	GI._sphere(c, Vector2(26, 24), 8.0, PINK)

static func _logo_block_drop(c: CanvasItem) -> void:
	var cells := [
		[1, 0, MAGENTA], [0, 1, MAGENTA], [1, 1, MAGENTA], [2, 1, MAGENTA],
		[0, 2, CYAN], [1, 2, CYAN], [2, 2, CYAN], [3, 2, CYAN], [3, 1, GOLD], [3, 0, GOLD],
	]
	for cl in cells:
		var col: Color = cl[2]
		GI._slab(c, Rect2(10 + cl[0] * 20, 20 + cl[1] * 20, 18, 18), col.darkened(0.35), col, 3, 0.5)

static func _logo_paddle_ball(c: CanvasItem) -> void:
	for y in range(8, 92, 12):
		c.draw_line(Vector2(50, y), Vector2(50, y + 6), Color(1, 1, 1, 0.3), 2.0)
	GI._slab(c, Rect2(10, 30, 9, 42), CYAN.darkened(0.4), CYAN, 4, 0.7)
	GI._slab(c, Rect2(81, 22, 9, 42), PINK.darkened(0.4), PINK, 4, 0.7)
	for i in range(4):
		c.draw_circle(Vector2(40 + i * 5, 52 - i * 2), 2.0 + i * 0.7, Color(GOLD, 0.15 + i * 0.1))
	GI._sphere(c, Vector2(62, 44), 7.0, GOLD)

static func _logo_brick_breaker(c: CanvasItem) -> void:
	var cols := [PINK, GOLD, LIME]
	for r in range(3):
		for k in range(5):
			if r == 2 and k == 2:
				continue
			var col: Color = cols[r]
			GI._slab(c, Rect2(8 + k * 17, 12 + r * 11, 15, 8), col.darkened(0.35), col, 2, 0.4)
	for i in range(3):
		c.draw_circle(Vector2(44 + i * 5, 62 + i * 5), 2.0 + i * 0.6, Color(CYAN, 0.2 + i * 0.15))
	GI._sphere(c, Vector2(62, 52), 6.0, CYAN)
	GI._slab(c, Rect2(28, 84, 44, 7), CYAN.darkened(0.4), CYAN, 3, 0.7)

static func _logo_bird_hop(c: CanvasItem) -> void:
	for p in [Rect2(70, -4, 20, 34), Rect2(70, 64, 20, 40)]:
		GI._slab(c, p, LIME.darkened(0.5), LIME, 2, 0.4)
	GI._slab(c, Rect2(66, 26, 28, 8), LIME.darkened(0.35), LIME, 3, 0.4)
	GI._slab(c, Rect2(66, 60, 28, 8), LIME.darkened(0.35), LIME, 3, 0.4)
	GI._sphere(c, Vector2(36, 48), 20.0, GOLD)
	GI._ellipse(c, Vector2(30, 54), 11.0, 7.0, GOLD.darkened(0.45))
	GI._glow_poly(c, GI._pts(Vector2(30, 54), 11.0, 7.0), Color(GOLD, 0.8), 1.2)
	c.draw_circle(Vector2(44, 42), 5.0, Color.WHITE)
	c.draw_circle(Vector2(46, 42), 2.4, Color(0, 0, 0, 0.9))
	c.draw_colored_polygon(PackedVector2Array([Vector2(54, 48), Vector2(68, 52), Vector2(54, 57)]), Color("ff8a2b"))

static func _logo_alien_attack(c: CanvasItem) -> void:
	invader(c, Vector2(50, 38), 72.0, LIME)
	GI._glow_line(c, Vector2(50, 66), Vector2(50, 78), CYAN, 2.0)
	var ship := PackedVector2Array([Vector2(50, 78), Vector2(40, 92), Vector2(60, 92)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.4))
	GI._glow_poly(c, ship, CYAN, 1.6)

static func _logo_frog_crossing(c: CanvasItem) -> void:
	for sx in [-1.0, 1.0]:
		GI._ellipse(c, Vector2(50 + sx * 25, 74), 9.0, 12.0, LIME.darkened(0.45))
		GI._glow_poly(c, GI._pts(Vector2(50 + sx * 25, 74), 9.0, 12.0), LIME, 1.4)
		GI._ellipse(c, Vector2(50 + sx * 22, 40), 6.0, 9.0, LIME.darkened(0.45))
	GI._sphere(c, Vector2(50, 56), 22.0, LIME)
	for sx in [-1.0, 1.0]:
		GI._sphere(c, Vector2(50 + sx * 13, 30), 9.0, LIME)
		c.draw_circle(Vector2(50 + sx * 13, 29), 5.0, Color.WHITE)
		c.draw_circle(Vector2(50 + sx * 13, 28), 2.4, Color(0, 0, 0, 0.9))
	c.draw_arc(Vector2(50, 54), 9.0, 0.3, PI - 0.3, 12, Color(0, 0.2, 0, 0.7), 2.0, true)

static func _logo_gem_match(c: CanvasItem) -> void:
	gem(c, Vector2(32, 34), 21.0, CYAN)
	gem(c, Vector2(68, 34), 21.0, PINK)
	gem(c, Vector2(50, 68), 21.0, LIME)

static func _logo_simon(c: CanvasItem) -> void:
	var cols := [LIME, PINK, GOLD, CYAN]
	for q in range(4):
		var col: Color = cols[q]
		wedge(c, Vector2(50, 50), 15.0, 42.0, q * PI * 0.5 + 0.1 - PI, (q + 1) * PI * 0.5 - 0.1 - PI, col, q == 1)
	c.draw_circle(Vector2(50, 50), 10.0, Color(0.05, 0.07, 0.12))
	c.draw_arc(Vector2(50, 50), 10.0, 0.0, TAU, 20, Color(1, 1, 1, 0.5), 1.4, true)

static func _logo_whack_a_mole(c: CanvasItem) -> void:
	mole(c, Vector2(42, 74), 1.3)
	tube(c, Vector2(78, 70), -PI * 0.62, 44.0, 5.0, BROWN)
	GI._slab(c, Rect2(60, 14, 34, 20), GOLD.darkened(0.5), GOLD, 5, 0.5)
	GI._glow_line(c, Vector2(88, 52), Vector2(96, 44), Color(1, 1, 1, 0.5), 1.4)

static func _logo_reaction_test(c: CanvasItem) -> void:
	GI._slab(c, Rect2(42, 8, 16, 9), CYAN.darkened(0.5), CYAN, 3, 0.0)
	c.draw_circle(Vector2(50, 56), 36.0, Color(CYAN, 0.12))
	c.draw_circle(Vector2(50, 56), 32.0, Color(0.03, 0.06, 0.12))
	c.draw_arc(Vector2(50, 56), 32.0, 0.0, TAU, 40, CYAN, 3.2, true)
	for i in range(12):
		var a := TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		c.draw_line(Vector2(50, 56) + d * 26.0, Vector2(50, 56) + d * 30.0, Color(1, 1, 1, 0.6), 1.4)
	GI._glow_line(c, Vector2(50, 56), Vector2(50, 56) + Vector2(cos(-1.0), sin(-1.0)) * 24.0, PINK, 2.4)
	GI._sphere(c, Vector2(50, 56), 4.0, GOLD)
	GI._glow_arc(c, Vector2(50, 56), 21.0, -PI * 0.5, -1.0, LIME, 2.0)

static func _logo_bubble_pop(c: CanvasItem) -> void:
	bubble(c, Vector2(36, 62), 24.0, CYAN)
	bubble(c, Vector2(68, 40), 17.0, PINK)
	bubble(c, Vector2(74, 74), 11.0, LIME)
	bubble(c, Vector2(26, 22), 8.0, GOLD)
	for i in range(6):
		var a := TAU * i / 6.0 + 0.3
		var d := Vector2(cos(a), sin(a))
		GI._glow_line(c, Vector2(26, 22) + d * 12.0, Vector2(26, 22) + d * 17.0, GOLD, 1.0)

static func _logo_rock_blaster(c: CanvasItem) -> void:
	rock(c, Vector2(26, 28), 18.0, 0.6, GOLD)
	rock(c, Vector2(76, 30), 14.0, 2.1, GOLD)
	rock(c, Vector2(80, 72), 9.0, 4.0, GOLD)
	GI._glow_line(c, Vector2(50, 54), Vector2(50, 14), PINK, 1.8)
	var ship := PackedVector2Array([Vector2(50, 56), Vector2(40, 82), Vector2(50, 76), Vector2(60, 82)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.55))
	GI._glow_poly(c, ship, CYAN, 2.0)
	GI._glow_line(c, Vector2(46, 86), Vector2(54, 86), GOLD, 1.6)

static func _logo_city_defense(c: CanvasItem) -> void:
	var hs := [22, 34, 26, 40, 24, 30]
	for i in range(6):
		var h: int = hs[i]
		GI._slab(c, Rect2(8 + i * 14, 90 - h, 12, h), BLUE.darkened(0.6), BLUE, 2, 0.3)
	GI._glow_arc(c, Vector2(50, 90), 44.0, PI * 1.12, PI * 1.88, CYAN, 1.4)
	GI._glow_line(c, Vector2(18, 8), Vector2(32, 38), PINK, 1.4)
	GI._glow_line(c, Vector2(84, 6), Vector2(66, 34), PINK, 1.4)
	c.draw_circle(Vector2(50, 30), 14.0, Color(GOLD, 0.22))
	c.draw_circle(Vector2(50, 30), 9.0, Color(GOLD, 0.5))
	c.draw_circle(Vector2(50, 30), 4.0, Color.WHITE)

static func _logo_maze_muncher(c: CanvasItem) -> void:
	pac(c, Vector2(26, 50), 19.0, GOLD)
	c.draw_circle(Vector2(52, 50), 2.8, Color(1, 1, 1, 0.9))
	c.draw_circle(Vector2(62, 50), 2.8, Color(1, 1, 1, 0.9))
	ghost(c, Vector2(80, 48), 14.0, PINK)

static func _logo_moon_lander(c: CanvasItem) -> void:
	star_field(c, Rect2(4, 4, 92, 50), 9, 3)
	var ground := PackedVector2Array([Vector2(0, 100), Vector2(0, 80), Vector2(14, 84), Vector2(28, 78), Vector2(34, 86), Vector2(66, 86), Vector2(74, 79), Vector2(90, 84), Vector2(100, 78), Vector2(100, 100)])
	c.draw_colored_polygon(ground, Color(0.12, 0.14, 0.2))
	GI._glow_poly_open(c, ground.slice(1, 9), Color(1, 1, 1, 0.5), 1.4)
	GI._glow_line(c, Vector2(34, 86), Vector2(66, 86), LIME, 2.4)
	GI._glow_line(c, Vector2(40, 56), Vector2(30, 78), CYAN, 1.8)
	GI._glow_line(c, Vector2(60, 56), Vector2(70, 78), CYAN, 1.8)
	GI._slab(c, Rect2(36, 40, 28, 16), CYAN.darkened(0.55), CYAN, 5, 0.5)
	GI._sphere(c, Vector2(50, 32), 11.0, CYAN)
	var flame := PackedVector2Array([Vector2(44, 58), Vector2(50, 78), Vector2(56, 58)])
	c.draw_colored_polygon(flame, Color(GOLD, 0.85))
	c.draw_colored_polygon(PackedVector2Array([Vector2(47, 58), Vector2(50, 70), Vector2(53, 58)]), Color(1, 1, 1, 0.9))

static func _logo_stack_tower(c: CanvasItem) -> void:
	var cols := [CYAN, BLUE, LIME, GOLD, PINK]
	var xs := [16, 20, 22, 26, 34]
	var ws := [68, 60, 56, 48, 32]
	for i in range(5):
		var col: Color = cols[i]
		GI._slab(c, Rect2(xs[i] + (6 if i == 4 else 0), 80 - i * 15, ws[i], 13), col.darkened(0.4), col, 3, 0.5)
	GI._glow_line(c, Vector2(76, 20), Vector2(88, 20), Color(1, 1, 1, 0.6), 1.4)
	GI._glow_line(c, Vector2(84, 14), Vector2(90, 20), Color(1, 1, 1, 0.6), 1.4)
	GI._glow_line(c, Vector2(84, 26), Vector2(90, 20), Color(1, 1, 1, 0.6), 1.4)

static func _logo_sky_hop(c: CanvasItem) -> void:
	GI._slab(c, Rect2(10, 82, 36, 8), LIME.darkened(0.45), LIME, 3, 0.5)
	GI._slab(c, Rect2(56, 58, 36, 8), LIME.darkened(0.45), LIME, 3, 0.5)
	GI._slab(c, Rect2(14, 32, 36, 8), BLUE.darkened(0.3), BLUE, 3, 0.5)
	GI._glow_line(c, Vector2(74, 58), Vector2(74, 50), GOLD, 1.8)
	GI._glow_poly_open(c, PackedVector2Array([Vector2(68, 50), Vector2(80, 50), Vector2(68, 46), Vector2(80, 46)]), GOLD, 1.2)
	GI._sphere(c, Vector2(66, 26), 12.0, GOLD)
	c.draw_circle(Vector2(70, 22), 3.6, Color.WHITE)
	c.draw_circle(Vector2(71.5, 22), 1.6, Color(0, 0, 0, 0.9))
	c.draw_circle(Vector2(63, 22), 3.2, Color.WHITE)
	c.draw_circle(Vector2(64.5, 22), 1.4, Color(0, 0, 0, 0.9))
	GI._glow_line(c, Vector2(62, 37), Vector2(56, 46), GOLD, 1.8)
	GI._glow_line(c, Vector2(70, 37), Vector2(76, 46), GOLD, 1.8)

static func _logo_air_hockey(c: CanvasItem) -> void:
	GI._slab(c, Rect2(16, 6, 68, 88), Color(0.02, 0.05, 0.1), CYAN, 12, 0.6)
	GI._slab(c, Rect2(36, 4, 28, 5), Color(0, 0, 0), Color(0, 0, 0, 0), 2, 0.0)
	GI._slab(c, Rect2(36, 91, 28, 5), Color(0, 0, 0), Color(0, 0, 0, 0), 2, 0.0)
	c.draw_line(Vector2(18, 50), Vector2(82, 50), Color(CYAN, 0.5), 1.6)
	c.draw_arc(Vector2(50, 50), 11.0, 0.0, TAU, 24, Color(CYAN, 0.5), 1.4, true)
	GI._sphere(c, Vector2(40, 24), 9.0, PINK)
	GI._sphere(c, Vector2(58, 72), 9.0, CYAN)
	c.draw_circle(Vector2(56, 46), 5.0, Color(0.05, 0.05, 0.1))
	c.draw_arc(Vector2(56, 46), 5.0, 0.0, TAU, 14, GOLD, 1.8, true)

static func _logo_barrel_climb(c: CanvasItem) -> void:
	GI._glow_line(c, Vector2(6, 38), Vector2(94, 48), PINK, 3.2)
	GI._glow_line(c, Vector2(6, 84), Vector2(94, 74), PINK, 3.2)
	GI._glow_line(c, Vector2(74, 52), Vector2(74, 77), CYAN, 1.8)
	GI._glow_line(c, Vector2(84, 51), Vector2(84, 76), CYAN, 1.8)
	for y in range(56, 76, 6):
		GI._glow_line(c, Vector2(74, y), Vector2(84, y), CYAN, 1.2)
	GI._sphere(c, Vector2(34, 24), 13.0, BROWN)
	GI._glow_arc(c, Vector2(34, 24), 13.0, PI * 1.1, PI * 1.9, GOLD, 1.2)
	GI._glow_arc(c, Vector2(34, 24), 13.0, PI * 0.1, PI * 0.9, GOLD, 1.2)
	GI._glow_line(c, Vector2(22, 24), Vector2(46, 24), GOLD, 1.4)
	GI._sphere(c, Vector2(20, 62), 6.0, LIME)
	GI._slab(c, Rect2(15, 68, 10, 12), LIME.darkened(0.4), LIME, 2, 0.0)

static func _logo_cannon_duel(c: CanvasItem) -> void:
	var hills := PackedVector2Array([Vector2(0, 100), Vector2(0, 74), Vector2(30, 82), Vector2(50, 90), Vector2(70, 82), Vector2(100, 74), Vector2(100, 100)])
	c.draw_colored_polygon(hills, Color(0.05, 0.12, 0.1))
	GI._glow_poly_open(c, hills.slice(1, 6), LIME, 1.2)
	tube(c, Vector2(20, 70), -0.9, 26.0, 9.0, CYAN)
	tube(c, Vector2(80, 70), -PI + 0.9, 26.0, 9.0, PINK)
	GI._sphere(c, Vector2(20, 72), 9.0, CYAN)
	GI._sphere(c, Vector2(80, 72), 9.0, PINK)
	for i in range(9):
		var t := i / 8.0
		var p := Vector2(34.0 + t * 32.0, 56.0 - sin(t * PI) * 36.0)
		c.draw_circle(p, 1.8, Color(GOLD, 0.8))
	GI._sphere(c, Vector2(66, 56), 4.0, GOLD)

static func _logo_crypt_crawler(c: CanvasItem) -> void:
	var bone := Color(0.9, 0.9, 0.82)
	c.draw_circle(Vector2(50, 44), 40.0, Color(CYAN, 0.1))
	GI._ellipse(c, Vector2(50, 40), 30.0, 28.0, bone.darkened(0.45))
	GI._ellipse(c, Vector2(48, 38), 26.0, 24.0, bone)
	GI._slab(c, Rect2(34, 58, 32, 18), bone.darkened(0.15), bone.darkened(0.4), 5, 0.0)
	for x in [40, 46, 52, 58]:
		c.draw_line(Vector2(x, 62), Vector2(x, 76), Color(0.2, 0.2, 0.25), 1.4)
	for sx in [-1.0, 1.0]:
		GI._ellipse(c, Vector2(50 + sx * 12, 42), 9.0, 10.0, Color(0.02, 0.03, 0.06))
		c.draw_circle(Vector2(50 + sx * 12, 43), 3.4, Color(CYAN, 0.35))
		c.draw_circle(Vector2(50 + sx * 12, 43), 2.0, CYAN.lightened(0.5))
	c.draw_colored_polygon(PackedVector2Array([Vector2(50, 50), Vector2(45, 59), Vector2(55, 59)]), Color(0.05, 0.05, 0.08))

static func _logo_mini_golf(c: CanvasItem) -> void:
	GI._slab(c, Rect2(8, 22, 84, 66), LIME.darkened(0.7), LIME, 18, 0.5)
	GI._ellipse(c, Vector2(70, 66), 9.0, 4.5, Color(0, 0, 0))
	GI._glow_line(c, Vector2(70, 66), Vector2(70, 24), Color(1, 1, 1, 0.9), 1.4)
	var flag := PackedVector2Array([Vector2(70, 24), Vector2(86, 30), Vector2(70, 37)])
	c.draw_colored_polygon(flag, PINK)
	GI._glow_poly(c, flag, PINK, 1.2)
	for i in range(5):
		c.draw_circle(Vector2(32 + i * 8, 74 - i * 2.2), 1.8, Color(1, 1, 1, 0.5))
	GI._sphere(c, Vector2(24, 76), 7.0, Color(0.85, 0.9, 1.0))

static func _logo_pool(c: CanvasItem) -> void:
	GI._glow_line(c, Vector2(96, 8), Vector2(60, 40), GOLD, 2.4)
	GI._sphere(c, Vector2(76, 70), 14.0, GOLD)
	GI._sphere(c, Vector2(40, 52), 28.0, Color(0.32, 0.34, 0.46))
	c.draw_circle(Vector2(40, 46), 12.0, Color(0.95, 0.95, 1.0))
	L.txt(c, "8", Vector2(40, 46), 17, Color(0.05, 0.05, 0.1))
