extends RefCounted

## Cards category TEASERS (batch 4, 2026-10-13): 160x90 mini scenes, same rules as
## game_teasers.gd. Card helpers come from game_logos_cards.gd (K).
## Add one: `_teaser_<id>(c, base)`, id in IDS, line in `_scene()`.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")
const K = preload("res://scripts/common/game_logos_cards.gd")
const T = preload("res://scripts/common/game_teasers.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const W := 160.0
const H := 90.0

const IDS := K.IDS

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
		"solitaire": _teaser_solitaire(c, base)
		"blackjack": _teaser_blackjack(c, base)
		"war": _teaser_war(c, base)
		"crazy_eights": _teaser_crazy_eights(c, base)
		"go_fish": _teaser_go_fish(c, base)
		"gin_rummy": _teaser_gin_rummy(c, base)
		"spider": _teaser_spider(c, base)
		"freecell": _teaser_freecell(c, base)
		"pyramid": _teaser_pyramid(c, base)
		"speed": _teaser_speed(c, base)
		"memory": _teaser_memory(c, base)
		"tri_peaks": _teaser_tri_peaks(c, base)
		"hearts": _teaser_hearts(c, base)
		"video_poker": _teaser_video_poker(c, base)
		"sevens": _teaser_sevens(c, base)
		"rummy": _teaser_rummy(c, base)

static func _slot(c: CanvasItem, rect: Rect2, col: Color = CYAN) -> void:
	GI._slab(c, rect, Color(0.02, 0.04, 0.08), Color(col, 0.4), rect.size.x * 0.14, 0.0)

## ---------- the 16 Cards teasers ----------

static func _teaser_solitaire(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	K.back(c, Rect2(10, 4, 17, 24))
	K.card(c, Rect2(31, 4, 17, 24), "7", K.HEART)
	for i in range(4):
		var rc := Rect2(88 + i * 18.0, 4, 17, 24)
		if i < 2:
			K.card(c, rc, "A", [K.HEART, K.SPADE][i], true, false, LIME)
		else:
			_slot(c, rc)
	var faces := ["K", "Q", "9", "5", "J", "8", "A"]
	for k in range(7):
		var x := 10.0 + k * 21.0
		var nb := mini(k, 3)
		for j in range(nb):
			K.back(c, Rect2(x, 36 + j * 5.0, 17, 24))
		K.card(c, Rect2(x, 36 + nb * 5.0, 17, 24), faces[k], (k + 1) % 4)

static func _teaser_blackjack(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var arc := GI._pts(Vector2(80, 104), 96.0, 70.0)
	c.draw_colored_polygon(arc, Color(0.02, 0.18, 0.12, 0.8))
	arc.append(arc[0])
	c.draw_polyline(arc, Color(LIME, 0.6), 1.4, true)
	K.back(c, Rect2(52, 6, 24, 34))
	K.card(c, Rect2(70, 6, 24, 34), "7", K.DIAMOND)
	K.card(c, Rect2(52, 52, 24, 34), "A", K.SPADE)
	K.card(c, Rect2(70, 52, 24, 34), "K", K.HEART)
	L.txt(c, "21", Vector2(112, 69), 16, GOLD)
	for j in range(4):
		GI._disc(c, Vector2(134, 78 - j * 4.0), 8.0, 4.0, 2.5, GOLD, GOLD)
	for j in range(3):
		GI._disc(c, Vector2(148, 80 - j * 4.0), 8.0, 4.0, 2.5, PINK, PINK)

static func _teaser_war(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	for sx in [22.0, 138.0]:
		for i in range(3):
			K.back(c, Rect2(sx - 12 + i * 1.5, 24 - i * 1.5, 24, 34))
		L.txt(c, "26", Vector2(sx, 74), 11, Color(1, 1, 1, 0.8))
	K.card_r(c, base, Vector2(64, 45), deg_to_rad(-8), 32.0, "K", K.SPADE, true, false, CYAN)
	K.card_r(c, base, Vector2(96, 45), deg_to_rad(8), 32.0, "Q", K.HEART, true, false, PINK)
	for i in range(8):
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		GI._glow_line(c, Vector2(80, 14) + d * 4.0, Vector2(80, 14) + d * 9.0, GOLD, 1.0)

static func _teaser_crazy_eights(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	for i in range(4):
		K.suit(c, i, Vector2(16 + i * 17.0, 13), 5.0, [PINK, PINK, CYAN, CYAN][i])
	c.draw_arc(Vector2(16 + 2 * 17.0, 13), 9.0, 0.0, TAU, 18, LIME, 1.6, true)
	K.card_r(c, base, Vector2(80, 38), 0.0, 30.0, "", 0, false)
	K.card_r(c, base, Vector2(116, 38), deg_to_rad(-6), 34.0, "8", K.DIAMOND, true, true, GOLD)
	var ranks := ["8", "3", "K", "8", "5"]
	for i in range(5):
		var edge: Color = GOLD if ranks[i] == "8" else CYAN
		K.card_r(c, base, Vector2(28 + i * 17.0, 76 - abs(i - 2) * 3.0), deg_to_rad((i - 2) * 9.0), 22.0, ranks[i], i % 4, true, false, edge)

static func _teaser_go_fish(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var pond := GI._pts(Vector2(80, 32), 68.0, 28.0)
	c.draw_colored_polygon(pond, Color(BLUE, 0.28))
	pond.append(pond[0])
	c.draw_polyline(pond, Color(CYAN, 0.6), 1.4, true)
	GI._glow_arc(c, Vector2(80, 32), 50.0, 0.2, 1.2, Color(CYAN, 0.6), 0.8)
	K.fish(c, Vector2(48, 34), 36.0, CYAN)
	K.fish(c, Vector2(94, 24), 30.0, PINK)
	K.fish(c, Vector2(118, 42), 28.0, LIME)
	for p in [Vector2(66, 14), Vector2(72, 8), Vector2(134, 22)]:
		c.draw_arc(p, 2.4, 0.0, TAU, 10, Color(1, 1, 1, 0.6), 1.0, true)
	var ranks := ["7", "7", "J", "3"]
	for i in range(4):
		K.card_r(c, base, Vector2(56 + i * 16.0, 74), deg_to_rad((i - 1.5) * 8.0), 24.0, ranks[i], i % 4, true, false, LIME if i < 2 else CYAN)

static func _teaser_gin_rummy(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	var ranks := ["4", "5", "6", "9", "9", "9", "J", "Q", "K", "2"]
	var sts := [K.HEART, K.HEART, K.HEART, K.SPADE, K.DIAMOND, K.CLUB, K.SPADE, K.SPADE, K.SPADE, K.DIAMOND]
	for i in range(10):
		K.card_r(c, base, Vector2(26 + i * 12.5, 46 + abs(i - 4.5) * 1.8), deg_to_rad((i - 4.5) * 5.0), 26.0, ranks[i], sts[i])
	GI._glow_poly_open(c, PackedVector2Array([Vector2(16, 78), Vector2(16, 83), Vector2(58, 83), Vector2(58, 78)]), GOLD, 1.6)
	GI._glow_poly_open(c, PackedVector2Array([Vector2(64, 78), Vector2(64, 83), Vector2(104, 83), Vector2(104, 78)]), CYAN, 1.6)

static func _teaser_spider(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, MAGENTA)
	for k in range(10):
		var x := 9.0 + k * 14.4
		var nb := 2 + (k * 3) % 6
		for j in range(nb):
			K.back(c, Rect2(x, 5 + j * 3.0, 12, 17), MAGENTA)
		K.face_suit(c, Rect2(x, 5 + nb * 3.0, 12, 17), k % 4, MAGENTA)
	K.spider(c, Vector2(80, 68), 0.85, MAGENTA.lightened(0.15))
	for i in range(5):
		K.back(c, Rect2(120 + i * 4.0, 56, 12, 17), MAGENTA)

static func _teaser_freecell(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	for i in range(4):
		var a := Rect2(6 + i * 16.0, 4, 13, 18)
		var b := Rect2(94 + i * 16.0, 4, 13, 18)
		if i == 1:
			K.face_suit(c, a, K.HEART, LIME)
		else:
			_slot(c, a)
		if i < 2:
			K.face_suit(c, b, [K.SPADE, K.DIAMOND][i], LIME)
		else:
			_slot(c, b)
	for k in range(8):
		var n := 4 + k % 3
		for j in range(n):
			K.face_suit(c, Rect2(6.5 + k * 18.9, 28 + j * 9.0, 15, 21), (k + j) % 4)

static func _teaser_pyramid(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	for r in range(6, -1, -1):
		for k in range(r + 1):
			var ctr := Vector2(80 + (k - r * 0.5) * 17.0, 12 + r * 10.2)
			var hot: bool = r == 6 and k in [1, 4]
			K.face_suit(c, Rect2(ctr - Vector2(7, 9.5), Vector2(14, 19)), (r + k) % 4, LIME if hot else CYAN)
	K.back(c, Rect2(8, 62, 14, 19))
	K.face_suit(c, Rect2(26, 62, 14, 19), K.HEART)
	L.txt(c, "13", Vector2(142, 36), 18, GOLD)
	GI._glow_line(c, Vector2(132, 46), Vector2(152, 46), GOLD, 1.2)

static func _teaser_speed(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	for i in range(4):
		K.back(c, Rect2(34 + i * 21.0, 4, 18, 25))
	K.card(c, Rect2(66, 28, 26, 36), "7", K.SPADE)
	K.card(c, Rect2(98, 28, 26, 36), "J", K.HEART)
	var ranks := ["6", "8", "K", "J"]
	for i in range(4):
		K.card(c, Rect2(34 + i * 21.0, 66, 18, 25), ranks[i], (i + 1) % 4, true, false, LIME if i < 2 else CYAN)
	for i in range(4):
		GI._glow_line(c, Vector2(8, 34 + i * 7.0), Vector2(36 - i * 3.0, 34 + i * 7.0), Color(CYAN, 0.8), 1.2)
	K.card_r(c, base, Vector2(46, 46), deg_to_rad(16), 22.0, "A", K.DIAMOND, true, false, GOLD)

static func _teaser_memory(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, MAGENTA)
	for r in range(3):
		for k in range(6):
			var rc := Rect2(10 + k * 24.0, 2 + r * 30.0, 20, 26)
			if (r == 0 and k == 1) or (r == 2 and k == 4):
				K.face_suit(c, rc, K.HEART, LIME)
			elif r == 1 and k == 3:
				K.face_suit(c, rc, K.SPADE, CYAN)
			else:
				K.back(c, rc)
	GI._glow_arc(c, Vector2(80, 45), 62.0, PI * 1.2, PI * 1.4, LIME, 1.2)

static func _teaser_tri_peaks(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	for pk in [30.0, 80.0, 130.0]:
		for r in range(3):
			for k in range(r + 1):
				var rc := Rect2(pk + (k - r * 0.5) * 16.0 - 6.5, 6 + r * 12.0, 13, 18)
				if r == 0:
					K.face_suit(c, rc, int(pk / 40.0) % 4, LIME)
				else:
					K.back(c, rc)
	for k in range(10):
		var rc := Rect2(8.5 + k * 14.8, 44, 13, 18)
		if k % 3 == 1:
			K.face_suit(c, rc, k % 4)
		else:
			K.back(c, rc)
	K.back(c, Rect2(58, 66, 20, 24))
	K.card(c, Rect2(84, 66, 20, 24), "7", K.HEART, true, false, LIME)

static func _teaser_hearts(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	GI._halo(c, Vector2(80, 45), 44.0, PINK)
	K.suit(c, K.HEART, Vector2(80, 48), 30.0, Color(PINK, 0.3))
	K.card_r(c, base, Vector2(80, 22), deg_to_rad(4), 24.0, "9", K.HEART)
	K.card_r(c, base, Vector2(58, 45), deg_to_rad(-70), 24.0, "J", K.CLUB)
	K.card_r(c, base, Vector2(102, 45), deg_to_rad(70), 24.0, "5", K.DIAMOND)
	K.card_r(c, base, Vector2(80, 68), deg_to_rad(-3), 24.0, "Q", K.SPADE, true, false, GOLD)
	L.txt(c, "13", Vector2(18, 14), 12, Color(PINK, 0.9))
	L.txt(c, "0", Vector2(142, 14), 12, Color(CYAN, 0.9))

static func _teaser_video_poker(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	GI._slab(c, Rect2(4, 4, 152, 82), Color(0.03, 0.04, 0.09), GOLD, 10, 0.6)
	var pays := ["800", "50", "25", "9", "6"]
	for i in range(5):
		L.txt(c, pays[i], Vector2(20 + i * 30.0, 14), 8, Color(GOLD, 0.9 if i == 0 else 0.55))
	var ranks := ["10", "J", "Q", "K", "A"]
	for k in range(5):
		K.card(c, Rect2(10 + k * 29.0, 28, 24, 34), ranks[k], K.SPADE, true, false, GOLD)
		GI._slab(c, Rect2(14 + k * 29.0, 22, 16, 4), GOLD.darkened(0.2), GOLD, 2, 0.0)
	for k in range(5):
		c.draw_circle(Vector2(22 + k * 29.0, 74), 4.0, Color(GOLD, 0.8))

static func _teaser_sevens(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var spans := [[4, 10], [6, 9], [3, 11], [7, 8]]
	for r in range(4):
		for k in range(13):
			var rk := k + 1
			var rc := Rect2(6 + k * 11.4, 5 + r * 20.5, 10, 16)
			if rk >= spans[r][0] and rk <= spans[r][1]:
				K.face_suit(c, rc, [K.HEART, K.SPADE, K.DIAMOND, K.CLUB][r], GOLD if rk == 7 else CYAN)
			else:
				_slot(c, rc)

static func _teaser_rummy(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var groups := [[["9", K.HEART], ["9", K.SPADE], ["9", K.DIAMOND]], [["3", K.HEART], ["4", K.HEART], ["5", K.HEART], ["6", K.HEART]], [["K", K.SPADE], ["K", K.CLUB], ["K", K.DIAMOND]]]
	var xs := [6.0, 50.0, 104.0]
	for g in range(3):
		var lst: Array = groups[g]
		for i in range(lst.size()):
			K.card(c, Rect2(xs[g] + i * 10.0, 12, 17, 24), lst[i][0], lst[i][1], true, false, GOLD)
	var star := PackedVector2Array()
	for i in range(10):
		var a := deg_to_rad(-90.0 + 36.0 * i)
		star.append(Vector2(146, 18) + Vector2(cos(a), sin(a)) * (10.0 if i % 2 == 0 else 4.5))
	c.draw_colored_polygon(star, GOLD.darkened(0.2))
	GI._glow_poly(c, star, GOLD, 1.3)
	var hand := ["2", "7", "J", "A", "8", "Q"]
	for i in range(6):
		K.card(c, Rect2(26 + i * 18.0, 54, 20, 30), hand[i], (i * 3) % 4)
