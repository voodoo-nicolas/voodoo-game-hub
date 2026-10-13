extends RefCounted

## Word / Dice / Party / Adventure TEASERS (batch 5, 2026-10-13): 160x90 mini scenes for the
## 28 remaining games. Same rules as game_teasers.gd; helpers from game_logos_rest.gd (R).
## Add one: `_teaser_<id>(c, base)`, id in IDS, line in `_scene()`.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")
const R = preload("res://scripts/common/game_logos_rest.gd")
const T = preload("res://scripts/common/game_teasers.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const BROWN := R.BROWN
const CREAM := R.CREAM
const INK := R.INK
const W := 160.0
const H := 90.0

const IDS := R.IDS

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
		"hangman": _teaser_hangman(c, base)
		"wordle": _teaser_wordle(c, base)
		"word_search": _teaser_word_search(c, base)
		"crossword": _teaser_crossword(c, base)
		"anagrams": _teaser_anagrams(c, base)
		"word_hunt": _teaser_word_hunt(c, base)
		"word_ladder": _teaser_word_ladder(c, base)
		"cryptogram": _teaser_cryptogram(c, base)
		"word_chain": _teaser_word_chain(c, base)
		"yacht": _teaser_yacht(c, base)
		"farkle": _teaser_farkle(c, base)
		"liars_dice": _teaser_liars_dice(c, base)
		"shut_the_box": _teaser_shut_the_box(c, base)
		"dominoes": _teaser_dominoes(c, base)
		"pig": _teaser_pig(c, base)
		"bunco": _teaser_bunco(c, base)
		"ship_captain_crew": _teaser_ship_captain_crew(c, base)
		"party_spinner": _teaser_party_spinner(c, base)
		"charades": _teaser_charades(c, base)
		"truth_or_dare": _teaser_truth_or_dare(c, base)
		"fortune_ball": _teaser_fortune_ball(c, base)
		"spirit_board": _teaser_spirit_board(c, base)
		"fastest_finger": _teaser_fastest_finger(c, base)
		"emoji_guess": _teaser_emoji_guess(c, base)
		"who_am_i": _teaser_who_am_i(c, base)
		"geometry_wars": _teaser_geometry_wars(c, base)
		"star_runner": _teaser_star_runner(c, base)
		"sky_raider": _teaser_sky_raider(c, base)

static func _tile(c: CanvasItem, rect: Rect2, ch: String, col: Color, size: int, face: Color = CREAM) -> void:
	GI._slab(c, rect, face, col, 4, 0.4)
	L.txt(c, ch, rect.get_center(), size, INK)

## ---------- Word ----------

static func _teaser_hangman(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BROWN)
	GI._glow_line(c, Vector2(10, 82), Vector2(50, 82), BROWN, 2.2)
	GI._glow_line(c, Vector2(22, 82), Vector2(22, 8), BROWN, 2.2)
	GI._glow_line(c, Vector2(22, 8), Vector2(56, 8), BROWN, 2.2)
	GI._glow_line(c, Vector2(56, 8), Vector2(56, 18), BROWN, 1.5)
	c.draw_arc(Vector2(56, 25), 7.0, 0.0, TAU, 16, PINK, 2.0, true)
	for s in [[Vector2(56, 32), Vector2(56, 54)], [Vector2(56, 38), Vector2(45, 48)], [Vector2(56, 38), Vector2(67, 48)]]:
		GI._glow_line(c, s[0], s[1], PINK, 1.8)
	var word := "A_E_A"
	for i in range(5):
		var x := 82.0 + i * 14.0
		if word[i] == "_":
			GI._glow_line(c, Vector2(x - 5, 22), Vector2(x + 5, 22), CYAN, 1.6)
		else:
			L.txt(c, word[i], Vector2(x, 17), 14, GOLD)
			GI._glow_line(c, Vector2(x - 5, 22), Vector2(x + 5, 22), GOLD, 1.2)
	var keys := "ABCDEFGHIJKLMNOPQRSTUVWX"
	for i in range(24):
		var rc := Rect2(80 + (i % 8) * 9.0, 36 + floori(i / 8.0) * 13.0, 8, 11)
		var used: bool = i in [0, 4, 7, 11, 13, 17, 19]
		L.cell(c, rc, CYAN if not used else PINK, used, 2.0)
		L.txt(c, keys[i], rc.get_center(), 7, Color(1, 1, 1, 0.9 if used else 0.55))

static func _teaser_wordle(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, LIME)
	var rows := ["CRANE", "LIGHT", "BRAIN", "BRAID"]
	var pats := ["xggxx", "xyxxx", "ggggx", "ggggg"]
	for r in range(6):
		for k in range(5):
			var rc := Rect2(48 + k * 13.0, 3 + r * 14.5, 12, 13)
			if r < 4:
				var st: String = pats[r][k]
				var col: Color = LIME if st == "g" else (GOLD if st == "y" else Color(0.4, 0.43, 0.52))
				GI._slab(c, rc, col.darkened(0.45), col, 3, 0.4 if st != "x" else 0.0)
				L.txt(c, rows[r][k], rc.get_center(), 9, Color.WHITE)
			else:
				L.cell(c, rc, CYAN, false, 3.0)

static func _teaser_word_search(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	GI._slab(c, Rect2(12, 28, 52, 12), Color(GOLD, 0.35), GOLD, 6, 0.6)
	for r in range(8):
		for k in range(8):
			var ch := String.chr(65 + (r * 7 + k * 11 + r * k) % 26)
			var hot: bool = r == 3 and k < 5
			L.txt(c, ch, Vector2(15 + k * 11.0, 9 + r * 10.5), 9, Color(1, 1, 1, 0.95) if hot else Color(CYAN, 0.8))
	for i in range(4):
		var y := 20.0 + i * 15.0
		GI._glow_line(c, Vector2(112, y), Vector2(146 - (i * 5) % 14, y), Color(1, 1, 1, 0.5), 2.0)
		if i < 2:
			GI._glow_line(c, Vector2(110, y), Vector2(148 - (i * 5) % 14, y), PINK, 1.2)

static func _teaser_crossword(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var rows := ["S.TOP#.", "#A#E.#N", "BRIM#EA", ".E#SIT#", "#TAPE.S"]
	for r in range(5):
		for k in range(7):
			var rc := Rect2(8 + k * 14.0, 6 + r * 15.0, 13, 14)
			var ch: String = rows[r][k]
			if ch == "#":
				GI._slab(c, rc, Color(0.02, 0.04, 0.08), Color(CYAN, 0.3), 2, 0.0)
			elif ch == ".":
				GI._slab(c, rc, CREAM, CYAN, 2, 0.2)
			else:
				GI._slab(c, rc, CREAM, CYAN, 2, 0.2)
				L.txt(c, ch, rc.get_center(), 10, INK)
	for i in range(5):
		GI._glow_line(c, Vector2(114, 16 + i * 14.0), Vector2(150 - (i * 7) % 16, 16 + i * 14.0), Color(1, 1, 1, 0.45), 2.0)
		L.txt(c, str(i + 1), Vector2(108, 16 + i * 14.0), 8, GOLD)

static func _teaser_anagrams(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	L.meter(c, Rect2(14, 6, 132, 6), PINK, 0.6)
	var top := ["T", "R", "A", "E", "N", "S"]
	for i in range(6):
		c.draw_set_transform_matrix(base * Transform2D(deg_to_rad((i % 3 - 1) * 10.0), Vector2.ONE, 0.0, Vector2(30 + i * 20.0, 30 + (i % 2) * 6.0)))
		_tile(c, Rect2(-8, -10, 16, 20), top[i], CYAN, 12)
	c.draw_set_transform_matrix(base)
	var ans := "STRANE"
	for i in range(6):
		var rc := Rect2(22 + i * 20.0, 58, 16, 22)
		if i < 3:
			_tile(c, rc, ans[i], LIME, 12)
		else:
			L.cell(c, rc, LIME, false, 4.0)
	GI._glow_arc(c, Vector2(80, 44), 20.0, PI * 0.15, PI * 0.85, GOLD, 1.4)

static func _teaser_word_hunt(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	var letters := "RATESNOLIDHPCMUY"
	var path := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3)]
	var pts := PackedVector2Array()
	for p in path:
		pts.append(Vector2(30.0 + p.x * 21.0, 14.0 + p.y * 21.0))
	for r in range(4):
		for k in range(4):
			var rc := Rect2(20 + k * 21.0, 4 + r * 21.0, 19, 19)
			var on: bool = Vector2i(k, r) in path
			GI._slab(c, rc, CREAM.darkened(0.0 if on else 0.35), GOLD if on else CYAN, 4, 0.5 if on else 0.0)
			L.txt(c, letters[r * 4 + k], rc.get_center(), 12, INK)
	GI._glow_poly_open(c, pts, GOLD, 1.6)
	L.meter(c, Rect2(112, 8, 38, 6), GOLD, 0.5)
	for i in range(4):
		GI._glow_line(c, Vector2(112, 28 + i * 12.0), Vector2(146 - i * 6.0, 28 + i * 12.0), Color(1, 1, 1, 0.5), 2.0)
		L.txt(c, "+" + str(4 + i * 2), Vector2(152, 28 + i * 12.0), 7, LIME)

static func _teaser_word_ladder(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var words := ["COLD", "CORD", "CARD", "WARD", "WARM"]
	var hot := [-1, 2, 1, 0, 3]
	for r in range(5):
		for k in range(4):
			var rc := Rect2(36 + k * 21.0, 3 + r * 17.0, 19, 15)
			var h: bool = hot[r] == k
			GI._slab(c, rc, CREAM, GOLD if h else CYAN, 3, 0.5 if h else 0.0)
			L.txt(c, words[r][k], rc.get_center(), 11, INK)
	for x in [24, 132]:
		GI._glow_line(c, Vector2(x, 2), Vector2(x, 88), Color(CYAN, 0.7), 1.2)
	for y in range(8, 86, 17):
		GI._glow_line(c, Vector2(24, y), Vector2(32, y), Color(CYAN, 0.7), 1.0)
		GI._glow_line(c, Vector2(124, y), Vector2(132, y), Color(CYAN, 0.7), 1.0)

static func _teaser_cryptogram(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	var codes := [[7, 19, 3, 3, 12, 5, 8], [14, 3, 21, 7, 19, 9, 3]]
	var letters := [["H", "", "E", "E", "", "A", ""], ["", "E", "", "H", "", "", "E"]]
	for r in range(2):
		for k in range(7):
			var x := 12.0 + k * 20.0
			var y := 14.0 + r * 40.0
			L.txt(c, str(codes[r][k]), Vector2(x + 8, y), 9, GOLD)
			var rc := Rect2(x, y + 7, 16, 20)
			if letters[r][k] == "":
				L.cell(c, rc, CYAN, false, 3.0)
			else:
				_tile(c, rc, letters[r][k], LIME, 12)
	c.draw_arc(Vector2(24, 84), 4.0, 0.0, TAU, 12, GOLD, 1.6, true)
	GI._glow_line(c, Vector2(28, 84), Vector2(46, 84), GOLD, 1.6)

static func _teaser_word_chain(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var words := ["ARM", "MAP", "PEN", "NET", "TOP"]
	var pos := [Vector2(8, 14), Vector2(58, 14), Vector2(108, 14), Vector2(32, 54), Vector2(82, 54)]
	var cols := [CYAN, PINK, LIME, GOLD, CYAN]
	for i in range(5):
		var rc := Rect2(pos[i], Vector2(44, 24))
		GI._slab(c, rc, Color(0.03, 0.05, 0.1), cols[i], 12, 0.6)
		for k in range(3):
			var hot: bool = (k == 0 and i > 0 and i != 3) or (k == 2 and i < 4 and i != 2)
			L.txt(c, words[i][k], rc.position + Vector2(10 + k * 12.0, 12), 13, GOLD if hot else Color.WHITE)
	GI._glow_line(c, Vector2(52, 26), Vector2(58, 26), GOLD, 1.4)
	GI._glow_line(c, Vector2(102, 26), Vector2(108, 26), GOLD, 1.4)
	GI._glow_poly_open(c, PackedVector2Array([Vector2(140, 38), Vector2(140, 46), Vector2(64, 46), Vector2(64, 54)]), GOLD, 1.2)
	GI._glow_line(c, Vector2(76, 66), Vector2(82, 66), GOLD, 1.4)

## ---------- Dice ----------

static func _teaser_yacht(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	GI._slab(c, Rect2(6, 6, 104, 78), Color(0.02, 0.1, 0.07), LIME, 14, 0.4)
	var cols := [CYAN, PINK, LIME, GOLD, MAGENTA]
	var pos := [Vector2(28, 28), Vector2(60, 26), Vector2(90, 30), Vector2(42, 60), Vector2(76, 62)]
	for i in range(5):
		R.die_at(c, base, pos[i], 24.0, 6 if i < 4 else 5, cols[i], deg_to_rad((i - 2) * 14.0))
	GI._slab(c, Rect2(114, 6, 40, 78), Color(0.03, 0.05, 0.1), GOLD, 6, 0.4)
	for i in range(6):
		GI._glow_line(c, Vector2(118, 16 + i * 12.0), Vector2(134, 16 + i * 12.0), Color(1, 1, 1, 0.4), 1.4)
		L.txt(c, str([30, 25, 18, 50, 12, 24][i]), Vector2(145, 16 + i * 12.0), 8, GOLD)

static func _teaser_farkle(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	var vals := [1, 5, 5]
	for i in range(3):
		R.die_at(c, base, Vector2(36 + i * 34.0, 28), 26.0, vals[i], GOLD, deg_to_rad((i - 1) * 8.0))
	var vals2 := [2, 3, 6]
	for i in range(3):
		R.die_at(c, base, Vector2(58 + i * 34.0, 64), 22.0, vals2[i], Color(0.5, 0.55, 0.7), deg_to_rad((i - 1) * -10.0))
	L.txt(c, "350", Vector2(22, 70), 18, GOLD)
	GI._glow_line(c, Vector2(8, 50), Vector2(152, 50), Color(1, 1, 1, 0.2), 1.0)

static func _teaser_liars_dice(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	var xs := [30.0, 80.0, 130.0]
	for i in range(3):
		var lift: float = -22.0 if i == 1 else 0.0
		if i == 1:
			R.die_at(c, base, Vector2(xs[i] - 12, 60), 14.0, 5, CYAN, 0.1)
			R.die_at(c, base, Vector2(xs[i] + 4, 62), 14.0, 3, PINK, -0.1)
			R.die_at(c, base, Vector2(xs[i] + 18, 60), 14.0, 5, LIME, 0.2)
		var cup := PackedVector2Array([Vector2(xs[i] - 12, 28 + lift), Vector2(xs[i] + 12, 28 + lift), Vector2(xs[i] + 17, 66 + lift), Vector2(xs[i] - 17, 66 + lift)])
		c.draw_colored_polygon(cup, GOLD.darkened(0.6))
		GI._glow_poly(c, cup, GOLD, 1.6)
		GI._slab(c, Rect2(xs[i] - 20, 62 + lift, 40, 8), GOLD.darkened(0.45), GOLD, 3, 0.4)
	GI._slab(c, Rect2(98, 4, 54, 20), Color(0.03, 0.05, 0.1), CYAN, 10, 0.6)
	L.txt(c, "4", Vector2(114, 14), 14, Color.WHITE)
	R.die_at(c, base, Vector2(136, 14), 12.0, 5, GOLD)

static func _teaser_shut_the_box(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, BROWN)
	GI._slab(c, Rect2(4, 6, 152, 56), BROWN.darkened(0.65), BROWN, 10, 0.5)
	var shut := [1, 4, 6, 9]
	for i in range(9):
		var rc := Rect2(10 + i * 16.0, 12, 14, 44)
		if (i + 1) in shut:
			GI._slab(c, rc, Color(0.02, 0.03, 0.05), Color(BROWN, 0.5), 3, 0.0)
		else:
			GI._slab(c, rc, CREAM, GOLD, 3, 0.3)
			L.txt(c, str(i + 1), rc.get_center(), 12, INK)
	R.die_at(c, base, Vector2(62, 76), 18.0, 4, CYAN, 0.1)
	R.die_at(c, base, Vector2(88, 76), 18.0, 3, CYAN, -0.1)
	L.txt(c, "7", Vector2(114, 76), 18, GOLD)

static func _teaser_dominoes(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var row1 := [[6, 3], [3, 5], [5, 5], [5, 2]]
	var cols := [CYAN, PINK, LIME, GOLD]
	for i in range(4):
		R.domino(c, Rect2(8 + i * 30.0, 8, 28, 14), row1[i][0], row1[i][1], cols[i])
	R.domino(c, Rect2(128, 8, 14, 28), 2, 4, CYAN)
	R.domino(c, Rect2(128, 38, 14, 28), 4, 1, PINK)
	var row2 := [[6, 1], [6, 6], [3, 6]]
	for i in range(3):
		R.domino(c, Rect2(98 - i * 30.0, 70, 28, 14), row2[i][0], row2[i][1], [LIME, GOLD, CYAN][i])
	GI._glow_arc(c, Vector2(80, 46), 28.0, PI * 1.2, PI * 1.8, GOLD, 1.0)

static func _teaser_pig(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	R.logo_at(c, base, "pig", Vector2(40, 46), 66.0)
	R.die_at(c, base, Vector2(96, 36), 30.0, 4, GOLD, deg_to_rad(-8))
	L.txt(c, "+4", Vector2(96, 66), 14, LIME)
	L.meter(c, Rect2(116, 12, 36, 6), CYAN, 0.7)
	L.meter(c, Rect2(116, 24, 36, 6), PINK, 0.4)
	L.txt(c, "72", Vector2(134, 42), 11, CYAN)
	L.txt(c, "40", Vector2(134, 56), 11, PINK)

static func _teaser_bunco(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	R.star(c, Vector2(80, 18), 12.0, GOLD)
	for i in range(3):
		R.die_at(c, base, Vector2(48 + i * 32.0, 56), 28.0, 3, CYAN if i != 1 else PINK, deg_to_rad((i - 1) * 12.0))
	L.txt(c, "21", Vector2(18, 20), 14, CYAN)
	L.txt(c, "9", Vector2(142, 20), 14, PINK)
	for i in range(6):
		R.sparkle(c, Vector2(20 + i * 24.0, 84), 3.0, GOLD)

static func _teaser_ship_captain_crew(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	R.logo_at(c, base, "ship_captain_crew", Vector2(36, 42), 70.0)
	var vals := [6, 5, 4, 2, 3]
	for i in range(5):
		var hot: bool = i < 3
		R.die_at(c, base, Vector2(80 + (i % 3) * 24.0, 18 + floori(i / 3.0) * 30.0 + 6), 20.0, vals[i], GOLD if hot else Color(0.5, 0.55, 0.7), deg_to_rad((i - 2) * 6.0))
	L.txt(c, "5", Vector2(142, 76), 16, LIME)

## ---------- Party ----------

static func _teaser_party_spinner(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, MAGENTA)
	R.logo_at(c, base, "party_spinner", Vector2(80, 46), 86.0)
	var cols := [PINK, CYAN, GOLD, LIME, BLUE]
	for i in range(5):
		GI._sphere(c, Vector2(20 if i < 3 else 140, 18 + (i % 3) * 24.0), 7.0, cols[i])
	for i in range(14):
		var fx := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var fy := fposmod(sin(i * 78.233) * 24634.6345, 1.0)
		c.draw_circle(Vector2(fx * W, fy * H), 1.4, Color(cols[i % 5], 0.8))

static func _teaser_charades(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	var cone := PackedVector2Array([Vector2(80, 0), Vector2(36, 90), Vector2(124, 90)])
	c.draw_colored_polygon(cone, Color(1, 1, 1, 0.08))
	for sx in [0.0, 1.0]:
		var x0 := 0.0 if sx == 0.0 else 160.0
		var d := 1.0 if sx == 0.0 else -1.0
		var curtain := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + d * 30.0, 0), Vector2(x0 + d * 16.0, 45), Vector2(x0 + d * 28.0, 90), Vector2(x0, 90)])
		c.draw_colored_polygon(curtain, PINK.darkened(0.6))
		GI._glow_poly_open(c, curtain.slice(1, 4), PINK, 1.4)
	R.logo_at(c, base, "charades", Vector2(80, 44), 62.0)
	L.meter(c, Rect2(50, 8, 60, 6), GOLD, 0.65)
	L.txt(c, "5", Vector2(140, 14), 12, GOLD)
	GI._slab(c, Rect2(40, 82, 80, 6), BROWN.darkened(0.4), BROWN, 2, 0.0)

static func _teaser_truth_or_dare(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, PINK)
	R.logo_at(c, base, "truth_or_dare", Vector2(48, 46), 80.0)
	GI._slab(c, Rect2(98, 14, 50, 62), Color(0.03, 0.05, 0.1), GOLD, 10, 0.5)
	for i in range(4):
		GI._glow_line(c, Vector2(106, 28 + i * 12.0), Vector2(140 - (i * 5) % 12, 28 + i * 12.0), Color(1, 1, 1, 0.5), 2.0)
	R.sparkle(c, Vector2(144, 10), 4.0, GOLD)
	R.sparkle(c, Vector2(100, 84), 3.0, CYAN)

static func _teaser_fortune_ball(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	R.logo_at(c, base, "fortune_ball", Vector2(80, 46), 80.0)
	for p in [Vector2(20, 20), Vector2(140, 26), Vector2(26, 66), Vector2(134, 70), Vector2(112, 8), Vector2(44, 10)]:
		R.sparkle(c, p, 4.0, GOLD if int(p.x) % 2 == 0 else CYAN)
	GI._glow_arc(c, Vector2(80, 46), 44.0, PI * 1.1, PI * 1.5, CYAN, 1.0)

static func _teaser_spirit_board(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, BROWN)
	GI._slab(c, Rect2(6, 6, 148, 78), BROWN.darkened(0.7), BROWN, 12, 0.5)
	var up := "ABCDEFGHIJKLM"
	var lo := "NOPQRSTUVWXYZ"
	for i in range(13):
		L.txt(c, up[i], Vector2(18 + i * 10.4, 24 - abs(i - 6) * 0.8), 8, Color(CYAN, 0.9))
		L.txt(c, lo[i], Vector2(18 + i * 10.4, 38 - abs(i - 6) * 0.8), 8, Color(CYAN, 0.9))
	for i in range(10):
		L.txt(c, str((i + 1) % 10), Vector2(30 + i * 11.0, 52), 8, Color(GOLD, 0.85))
	var plan := PackedVector2Array([Vector2(86, 52), Vector2(100, 70), Vector2(94, 84), Vector2(78, 84), Vector2(72, 70)])
	c.draw_colored_polygon(plan, BROWN.darkened(0.45))
	GI._glow_poly(c, plan, BROWN, 1.6)
	c.draw_arc(Vector2(86, 70), 6.0, 0.0, TAU, 14, LIME, 1.8, true)
	R.sparkle(c, Vector2(20, 72), 4.0, GOLD)
	R.sparkle(c, Vector2(142, 72), 4.0, GOLD)

static func _teaser_fastest_finger(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	var cols := [PINK, CYAN, LIME, GOLD]
	for i in range(4):
		var rc := Rect2(6 + (i % 2) * 76.0, 6 + floori(i / 2.0) * 42.0, 72, 38)
		var hot: bool = i in [1, 2]
		GI._slab(c, rc, Color(cols[i], 0.12 if not hot else 0.3), cols[i], 8, 0.6 if hot else 0.1)
		if hot:
			for r in [6.0, 12.0, 18.0]:
				c.draw_arc(rc.get_center(), r, 0.0, TAU, 20, Color(cols[i], 0.7 - r * 0.02), 1.6, true)
			GI._sphere(c, rc.get_center(), 4.0, Color.WHITE)
	L.txt(c, "0.31", Vector2(80, 45), 14, Color.WHITE)

static func _teaser_emoji_guess(c: CanvasItem, _base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	for i in range(3):
		var rc := Rect2(22 + i * 46.0, 8, 40, 40)
		GI._slab(c, rc, Color(0.03, 0.05, 0.1), CYAN, 10, 0.5)
		R.face(c, rc.get_center(), 14.0, i)
	for i in range(5):
		var rc := Rect2(30 + i * 20.0, 58, 17, 22)
		if i < 2:
			_tile(c, rc, ["F", "U"][i], LIME, 13)
		else:
			L.cell(c, rc, LIME, false, 4.0)
	L.txt(c, "?", Vector2(142, 69), 16, Color(GOLD, 0.9))

static func _teaser_who_am_i(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	R.logo_at(c, base, "who_am_i", Vector2(42, 46), 82.0)
	for i in range(4):
		var rc := Rect2(92, 8 + i * 20.0, 58, 16)
		var open: bool = i < 2
		GI._slab(c, rc, Color(0.03, 0.05, 0.1), GOLD if open else Color(CYAN, 0.4), 8, 0.5 if open else 0.0)
		if open:
			GI._glow_line(c, Vector2(100, 16 + i * 20.0), Vector2(142 - i * 14.0, 16 + i * 20.0), Color(1, 1, 1, 0.6), 2.0)
		else:
			L.txt(c, "?", rc.get_center(), 11, Color(CYAN, 0.7))

## ---------- Adventure ----------

static func _teaser_geometry_wars(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, CYAN)
	for i in range(1, 8):
		var y := i * 11.0
		var pts := PackedVector2Array()
		for k in range(17):
			pts.append(Vector2(k * 10.0, y + sin(k * 0.9 + i) * 2.5 * (1.0 if abs(k - 8) < 4 else 0.3)))
		c.draw_polyline(pts, Color(CYAN, 0.18), 1.0, true)
	for p in [Vector2(24, 20), Vector2(130, 18), Vector2(110, 66)]:
		GI._glow_poly(c, PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0)]), PINK, 1.6)
	for p in [Vector2(46, 70), Vector2(142, 46)]:
		GI._glow_poly(c, PackedVector2Array([p + Vector2(-7, -7), p + Vector2(7, -7), p + Vector2(7, 7), p + Vector2(-7, 7)]), GOLD, 1.6)
	for i in range(4):
		var a := TAU * i / 4.0 + 0.4
		GI._glow_line(c, Vector2(20, 54), Vector2(20, 54) + Vector2(cos(a), sin(a)) * 10.0, LIME, 1.6)
	for i in range(8):
		var a := TAU * i / 8.0
		GI._glow_line(c, Vector2(100, 34) + Vector2(cos(a), sin(a)) * 3.0, Vector2(100, 34) + Vector2(cos(a), sin(a)) * 10.0, GOLD, 1.0)
	R.logo_at(c, base, "geometry_wars", Vector2(76, 50), 46.0)
	L.txt(c, "1280", Vector2(136, 80), 10, GOLD)

static func _teaser_star_runner(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, GOLD)
	_stars(c)
	R.logo_at(c, base, "star_runner", Vector2(80, 46), 88.0)
	for p in [Vector2(120, 70), Vector2(132, 18), Vector2(30, 20)]:
		GI._glow_poly(c, PackedVector2Array([p + Vector2(-6, 0), p + Vector2(0, -8), p + Vector2(7, -2), p + Vector2(5, 7), p + Vector2(-4, 8)]), Color(BROWN, 0.9), 1.2)
	L.meter(c, Rect2(10, 82, 140, 4), GOLD, 0.45)

static func _stars(c: CanvasItem) -> void:
	for i in range(22):
		var fx := fposmod(sin((i + 5) * 12.9898) * 43758.5453, 1.0)
		var fy := fposmod(sin((i + 5) * 78.233) * 24634.6345, 1.0)
		c.draw_circle(Vector2(fx * W, fy * H), 0.9 + fx * 0.7, Color(1, 1, 1, 0.3 + fy * 0.4))

static func _teaser_sky_raider(c: CanvasItem, base: Transform2D) -> void:
	T.backdrop(c, BLUE)
	for p in [Vector2(30, 20), Vector2(120, 40), Vector2(70, 70), Vector2(140, 80)]:
		c.draw_circle(p, 9.0, Color(1, 1, 1, 0.05))
		c.draw_circle(p + Vector2(10, 3), 7.0, Color(1, 1, 1, 0.05))
	for p in [Vector2(40, 18), Vector2(80, 10), Vector2(118, 20)]:
		GI._glow_poly(c, PackedVector2Array([p + Vector2(0, 10), p + Vector2(10, -4), p + Vector2(4, -4), p + Vector2(0, -10), p + Vector2(-4, -4), p + Vector2(-10, -4)]), PINK, 1.6)
	R.logo_at(c, base, "sky_raider", Vector2(80, 64), 40.0)
	for x in [72.0, 88.0]:
		GI._glow_line(c, Vector2(x, 46), Vector2(x, 30), Color(1, 1, 1, 0.9), 1.4)
	c.draw_circle(Vector2(80, 20), 8.0, Color(GOLD, 0.3))
	c.draw_circle(Vector2(80, 20), 4.0, Color.WHITE)
	L.txt(c, "950", Vector2(140, 10), 10, GOLD)
