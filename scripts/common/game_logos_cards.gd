extends RefCounted

## Cards category logos drawn in code (batch 4, 2026-10-13): same 100x100 box and rules as
## game_logos.gd. Holds the shared card helpers (card, back, suit, card_r, fish, spider)
## that game_teasers_cards.gd uses. Suits are DRAWN (no Unicode suit glyphs: phone fonts
## miss them); ranks are Latin letters/digits only. Add one: `_logo_<id>(c)`, id in IDS, line
## in `_logo()`. Used through game_art.gd.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const CREAM := Color(0.96, 0.94, 0.86)
const RED := Color("e8344a")
const INK := Color(0.1, 0.1, 0.18)

const HEART := 0
const DIAMOND := 1
const SPADE := 2
const CLUB := 3

const IDS := [
	"solitaire", "blackjack", "war", "crazy_eights", "go_fish", "gin_rummy", "spider", "freecell",
	"pyramid", "speed", "memory", "tri_peaks", "hearts", "video_poker", "sevens", "rummy",
]

## Transform of the logo being drawn (rotated cards compose with it).
static var _b := Transform2D.IDENTITY

static func has(id: String) -> bool:
	return id in IDS

static func draw(c: Control, id: String) -> void:
	var s: float = min(c.size.x, c.size.y)
	if s <= 0.0:
		return
	var origin := Vector2((c.size.x - s) * 0.5, (c.size.y - s) * 0.5)
	_b = Transform2D(0.0, Vector2(s / 100.0, s / 100.0), 0.0, origin)
	c.draw_set_transform_matrix(_b)
	_logo(c, id)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func logo_at(c: CanvasItem, base: Transform2D, id: String, ctr: Vector2, size: float) -> void:
	var k := size / 100.0
	_b = base * Transform2D(0.0, Vector2(k, k), 0.0, ctr - Vector2(size, size) * 0.5)
	c.draw_set_transform_matrix(_b)
	_logo(c, id)
	c.draw_set_transform_matrix(base)

static func _logo(c: CanvasItem, id: String) -> void:
	match id:
		"solitaire": _logo_solitaire(c)
		"blackjack": _logo_blackjack(c)
		"war": _logo_war(c)
		"crazy_eights": _logo_crazy_eights(c)
		"go_fish": _logo_go_fish(c)
		"gin_rummy": _logo_gin_rummy(c)
		"spider": _logo_spider(c)
		"freecell": _logo_freecell(c)
		"pyramid": _logo_pyramid(c)
		"speed": _logo_speed(c)
		"memory": _logo_memory(c)
		"tri_peaks": _logo_tri_peaks(c)
		"hearts": _logo_hearts(c)
		"video_poker": _logo_video_poker(c)
		"sevens": _logo_sevens(c)
		"rummy": _logo_rummy(c)

## ---------- shared card helpers ----------

static func suit_color(st: int) -> Color:
	return RED if st < 2 else INK

## A drawn suit symbol of radius ~r centred on `ctr`.
static func suit(c: CanvasItem, st: int, ctr: Vector2, r: float, col: Color = Color(-1, 0, 0)) -> void:
	if col.r < 0.0:
		col = suit_color(st)
	match st:
		HEART:
			c.draw_circle(ctr + Vector2(-0.5 * r, -0.3 * r), 0.56 * r, col)
			c.draw_circle(ctr + Vector2(0.5 * r, -0.3 * r), 0.56 * r, col)
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-1.04 * r, -0.12 * r), ctr + Vector2(1.04 * r, -0.12 * r), ctr + Vector2(0, 1.0 * r)]), col)
		DIAMOND:
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -1.05 * r), ctr + Vector2(0.78 * r, 0), ctr + Vector2(0, 1.05 * r), ctr + Vector2(-0.78 * r, 0)]), col)
		SPADE:
			c.draw_circle(ctr + Vector2(-0.5 * r, 0.22 * r), 0.56 * r, col)
			c.draw_circle(ctr + Vector2(0.5 * r, 0.22 * r), 0.56 * r, col)
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-1.04 * r, 0.05 * r), ctr + Vector2(1.04 * r, 0.05 * r), ctr + Vector2(0, -1.0 * r)]), col)
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, 0.2 * r), ctr + Vector2(-0.3 * r, 1.0 * r), ctr + Vector2(0.3 * r, 1.0 * r)]), col)
		CLUB:
			c.draw_circle(ctr + Vector2(0, -0.5 * r), 0.5 * r, col)
			c.draw_circle(ctr + Vector2(-0.56 * r, 0.22 * r), 0.5 * r, col)
			c.draw_circle(ctr + Vector2(0.56 * r, 0.22 * r), 0.5 * r, col)
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, 0.1 * r), ctr + Vector2(-0.3 * r, 1.0 * r), ctr + Vector2(0.3 * r, 1.0 * r)]), col)

## Card back: dark slab, inner frame and a diamond lattice mark.
static func back(c: CanvasItem, rect: Rect2, edge: Color = CYAN) -> void:
	GI._slab(c, rect, BLUE.darkened(0.7), edge, rect.size.x * 0.14, 0.45)
	var inner := rect.grow(-rect.size.x * 0.14)
	c.draw_rect(inner, Color(edge, 0.35), false, 1.0)
	var m := rect.get_center()
	var hw := inner.size.x * 0.42
	var hh := inner.size.y * 0.3
	GI._glow_poly(c, PackedVector2Array([m + Vector2(0, -hh), m + Vector2(hw, 0), m + Vector2(0, hh), m + Vector2(-hw, 0)]), edge, 1.0)
	c.draw_circle(m, hw * 0.28, Color(edge, 0.7))

## A face-up card. `big` = the rank alone, large (Crazy Eights' 8).
static func card(c: CanvasItem, rect: Rect2, rank: String, st: int, up: bool = true, big: bool = false, edge: Color = CYAN) -> void:
	if not up:
		back(c, rect, edge)
		return
	GI._slab(c, rect, CREAM, edge, rect.size.x * 0.14, 0.45)
	var col := suit_color(st)
	var w := rect.size.x
	var cx := rect.get_center().x
	if big:
		L.txt(c, rank, rect.get_center(), int(w * 0.95), col)
	elif w < 22.0:
		L.txt(c, rank, Vector2(cx, rect.position.y + rect.size.y * 0.3), int(w * 0.55), col)
		suit(c, st, Vector2(cx, rect.position.y + rect.size.y * 0.7), w * 0.22)
	else:
		L.txt(c, rank, rect.position + Vector2(w * 0.27, rect.size.y * 0.17), int(w * 0.36), col)
		suit(c, st, rect.position + Vector2(w * 0.27, rect.size.y * 0.37), w * 0.1)
		suit(c, st, rect.get_center() + Vector2(0, rect.size.y * 0.1), w * 0.27)

## A card showing just its suit (Memory, Pyramid ...).
static func face_suit(c: CanvasItem, rect: Rect2, st: int, edge: Color = CYAN) -> void:
	GI._slab(c, rect, CREAM, edge, rect.size.x * 0.14, 0.45)
	suit(c, st, rect.get_center(), minf(rect.size.x, rect.size.y * 0.7) * 0.3)

## A card of width `w` (height 1.4w) centred on `ctr`, rotated `ang`, drawn through `base`.
static func card_r(c: CanvasItem, base: Transform2D, ctr: Vector2, ang: float, w: float, rank: String, st: int, up: bool = true, big: bool = false, edge: Color = CYAN) -> void:
	c.draw_set_transform_matrix(base * Transform2D(ang, Vector2.ONE, 0.0, ctr))
	card(c, Rect2(Vector2(-w * 0.5, -w * 0.7), Vector2(w, w * 1.4)), rank, st, up, big, edge)
	c.draw_set_transform_matrix(base)

static func fish(c: CanvasItem, ctr: Vector2, size: float, col: Color) -> void:
	var s := size / 52.0
	c.draw_circle(ctr, 30.0 * s, Color(col, 0.1))
	var tail := PackedVector2Array([ctr + Vector2(-20, 0) * s, ctr + Vector2(-38, -15) * s, ctr + Vector2(-38, 15) * s])
	c.draw_colored_polygon(tail, col.darkened(0.45))
	GI._glow_poly(c, tail, col, 1.4)
	var fin := PackedVector2Array([ctr + Vector2(-4, -13) * s, ctr + Vector2(8, -25) * s, ctr + Vector2(14, -12) * s])
	c.draw_colored_polygon(fin, col.darkened(0.3))
	GI._glow_poly(c, fin, col, 1.2)
	c.draw_colored_polygon(GI._pts(ctr, 26.0 * s, 15.0 * s), col.darkened(0.5))
	GI._glow_poly(c, GI._pts(ctr, 26.0 * s, 15.0 * s), col, 1.8)
	GI._glow_arc(c, ctr + Vector2(-2, 0) * s, 12.0 * s, -1.0, 1.0, col.lightened(0.3), 1.2)
	c.draw_circle(ctr + Vector2(14, -4) * s, 3.6 * s, Color.WHITE)
	c.draw_circle(ctr + Vector2(15, -4) * s, 1.7 * s, Color(0, 0, 0, 0.9))

static func spider(c: CanvasItem, ctr: Vector2, k: float, col: Color) -> void:
	for side in [-1.0, 1.0]:
		for i in range(4):
			var y := (i - 1.5)
			var p := PackedVector2Array([
				ctr + Vector2(side * 5.0, y * 3.0) * k,
				ctr + Vector2(side * (15.0 + (i % 2) * 3.0), y * 8.0 - 9.0) * k,
				ctr + Vector2(side * 27.0, y * 12.0 + 3.0) * k])
			GI._glow_poly_open(c, p, col, 1.1 * k)
	GI._sphere(c, ctr + Vector2(0, 6) * k, 10.0 * k, col)
	GI._sphere(c, ctr + Vector2(0, -7) * k, 6.5 * k, col)
	for sx in [-2.5, 2.5]:
		c.draw_circle(ctr + Vector2(sx, -8) * k, 1.7 * k, Color.WHITE)

## ---------- the 16 Cards logos ----------

static func _logo_solitaire(c: CanvasItem) -> void:
	card(c, Rect2(10, 8, 34, 48), "", 0, false)
	card(c, Rect2(10, 22, 34, 48), "", 0, false)
	card(c, Rect2(10, 36, 34, 48), "A", HEART)
	card(c, Rect2(54, 14, 34, 48), "", 0, false)
	card(c, Rect2(54, 28, 34, 48), "K", SPADE)

static func _logo_blackjack(c: CanvasItem) -> void:
	card_r(c, _b, Vector2(38, 44), deg_to_rad(-12), 34.0, "A", SPADE)
	card_r(c, _b, Vector2(62, 44), deg_to_rad(12), 34.0, "K", HEART)
	L.txt(c, "21", Vector2(50, 86), 18, GOLD)
	GI._glow_line(c, Vector2(28, 92), Vector2(72, 92), GOLD, 1.2)

static func _logo_war(c: CanvasItem) -> void:
	card_r(c, _b, Vector2(32, 54), deg_to_rad(-14), 36.0, "K", SPADE, true, false, CYAN)
	card_r(c, _b, Vector2(68, 54), deg_to_rad(14), 36.0, "Q", DIAMOND, true, false, PINK)
	var bolt := PackedVector2Array([Vector2(53, 8), Vector2(44, 28), Vector2(51, 28), Vector2(46, 46), Vector2(58, 22), Vector2(51, 22)])
	c.draw_colored_polygon(bolt, GOLD.lightened(0.3))
	GI._glow_poly(c, bolt, GOLD, 1.4)

static func _logo_crazy_eights(c: CanvasItem) -> void:
	for i in range(7):
		var a := deg_to_rad(-90.0 + (i - 3) * 22.0)
		var d := Vector2(cos(a), sin(a))
		GI._glow_line(c, Vector2(50, 54) + d * 40.0, Vector2(50, 54) + d * 48.0, GOLD, 1.2)
	card_r(c, _b, Vector2(50, 56), deg_to_rad(-6), 48.0, "8", DIAMOND, true, true, GOLD)
	for i in range(4):
		suit(c, i, Vector2(16 + i * 23.0, 88), 6.0, [PINK, PINK, CYAN, CYAN][i])

static func _logo_go_fish(c: CanvasItem) -> void:
	card_r(c, _b, Vector2(30, 66), deg_to_rad(-18), 30.0, "A", HEART)
	fish(c, Vector2(60, 38), 60.0, CYAN)
	GI._glow_arc(c, Vector2(84, 66), 10.0, -0.3, PI, CYAN, 1.2)

static func _logo_gin_rummy(c: CanvasItem) -> void:
	var ranks := ["5", "6", "7"]
	for i in range(3):
		card_r(c, _b, Vector2(30 + i * 20.0, 48 - abs(i - 1) * 3.0), deg_to_rad((i - 1) * 16.0), 36.0, ranks[i], HEART)
	GI._glow_poly_open(c, PackedVector2Array([Vector2(14, 82), Vector2(14, 88), Vector2(86, 88), Vector2(86, 82)]), GOLD, 1.8)

static func _logo_spider(c: CanvasItem) -> void:
	card(c, Rect2(24, 8, 52, 78), "", 0, false, false, MAGENTA)
	spider(c, Vector2(50, 47), 1.05, MAGENTA.lightened(0.15))

static func _logo_freecell(c: CanvasItem) -> void:
	for i in range(4):
		var rc := Rect2(8 + i * 22.0, 8, 18, 26)
		if i == 1:
			card(c, rc, "K", HEART, true, false, LIME)
		else:
			GI._slab(c, rc, Color(0.02, 0.04, 0.08), Color(CYAN, 0.45), 4, 0.0)
	card(c, Rect2(20, 44, 26, 38), "Q", SPADE)
	card(c, Rect2(34, 52, 26, 38), "J", DIAMOND)
	card(c, Rect2(50, 44, 26, 38), "A", CLUB)

static func _logo_pyramid(c: CanvasItem) -> void:
	for r in range(2, -1, -1):
		for k in range(r + 1):
			var ctr := Vector2(50 + (k - r * 0.5) * 24.0, 24 + r * 20.0)
			face_suit(c, Rect2(ctr - Vector2(11, 15), Vector2(22, 30)), (r + k) % 4)
	L.txt(c, "13", Vector2(50, 90), 12, GOLD)

static func _logo_speed(c: CanvasItem) -> void:
	for i in range(4):
		GI._glow_line(c, Vector2(4, 30 + i * 12.0), Vector2(30 - i * 3.0, 30 + i * 12.0), Color(CYAN, 0.8), 1.4)
	card_r(c, _b, Vector2(58, 52), deg_to_rad(14), 42.0, "A", HEART, true, false, CYAN)
	var bolt := PackedVector2Array([Vector2(86, 10), Vector2(74, 30), Vector2(81, 30), Vector2(76, 46), Vector2(90, 24), Vector2(83, 24)])
	c.draw_colored_polygon(bolt, GOLD.lightened(0.3))
	GI._glow_poly(c, bolt, GOLD, 1.3)

static func _logo_memory(c: CanvasItem) -> void:
	for r in range(2):
		for k in range(3):
			var rc := Rect2(10 + k * 29.0, 12 + r * 40.0, 24, 34)
			if (r == 0 and k == 1) or (r == 1 and k == 2):
				face_suit(c, rc, HEART, LIME)
			else:
				back(c, rc)
	GI._glow_arc(c, Vector2(50, 50), 44.0, PI * 1.0, PI * 1.3, LIME, 1.2)

static func _logo_tri_peaks(c: CanvasItem) -> void:
	for pk in [20.0, 50.0, 80.0]:
		for r in range(3):
			for k in range(r + 1):
				var rc := Rect2(pk + (k - r * 0.5) * 11.0 - 5.0, 8 + r * 12.0, 10, 14)
				if r == 0:
					face_suit(c, rc, int(pk / 30.0) % 4, LIME)
				else:
					back(c, rc)
	for k in range(10):
		var rc := Rect2(6 + k * 9.0, 50, 8, 12)
		if k % 3 == 0:
			face_suit(c, rc, k % 4)
		else:
			back(c, rc)
	back(c, Rect2(34, 70, 16, 24))
	card(c, Rect2(54, 70, 16, 24), "7", HEART)

static func _logo_hearts(c: CanvasItem) -> void:
	GI._halo(c, Vector2(50, 46), 40.0, PINK)
	suit(c, HEART, Vector2(50, 40), 30.0, PINK.darkened(0.2))
	suit(c, HEART, Vector2(47, 36), 24.0, PINK)
	c.draw_circle(Vector2(36, 28), 4.0, Color(1, 1, 1, 0.55))
	card_r(c, _b, Vector2(74, 72), deg_to_rad(12), 30.0, "Q", SPADE, true, false, CYAN)

static func _logo_video_poker(c: CanvasItem) -> void:
	GI._slab(c, Rect2(4, 18, 92, 62), Color(0.03, 0.04, 0.09), GOLD, 8, 0.6)
	var ranks := ["10", "J", "Q", "K", "A"]
	for k in range(5):
		card(c, Rect2(9 + k * 17.0, 30, 15, 24), ranks[k], SPADE, true, false, GOLD)
	for k in [1, 3]:
		GI._slab(c, Rect2(11 + k * 17.0, 23, 11, 4), GOLD.darkened(0.2), GOLD, 2, 0.0)
	for k in range(5):
		c.draw_circle(Vector2(16 + k * 17.0, 68), 3.4, Color(GOLD, 0.8))

static func _logo_sevens(c: CanvasItem) -> void:
	var rows := [["5", "6", "7", "8", "9"], ["", "", "7", "", ""], ["", "6", "7", "8", ""]]
	for r in range(3):
		for k in range(5):
			var rk: String = rows[r][k]
			var rc := Rect2(6 + k * 18.0, 8 + r * 30.0, 16, 24)
			if rk == "":
				GI._slab(c, rc, Color(0.02, 0.04, 0.08), Color(CYAN, 0.25), 3, 0.0)
			else:
				card(c, rc, rk, [HEART, SPADE, DIAMOND][r], true, false, GOLD if rk == "7" else CYAN)

static func _logo_rummy(c: CanvasItem) -> void:
	var sts := [HEART, SPADE, DIAMOND]
	for i in range(3):
		card_r(c, _b, Vector2(28 + i * 22.0, 56 - abs(i - 1) * 3.0), deg_to_rad((i - 1) * 14.0), 36.0, "9", sts[i])
	GI._glow_poly_open(c, PackedVector2Array([Vector2(12, 88), Vector2(12, 92), Vector2(88, 92), Vector2(88, 88)]), GOLD, 1.6)
	var star := PackedVector2Array()
	for i in range(10):
		var a := deg_to_rad(-90.0 + 36.0 * i)
		star.append(Vector2(80, 18) + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 5.0))
	c.draw_colored_polygon(star, GOLD.darkened(0.2))
	GI._glow_poly(c, star, GOLD, 1.4)
