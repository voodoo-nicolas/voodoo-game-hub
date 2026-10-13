extends RefCounted

## The remaining categories' logos drawn in code (batch 5, 2026-10-13): Word (9), Dice (8),
## Party (8), Adventure (3). Same 100x100 box and rules as game_logos.gd. Dice are drawn
## with GameIcons.draw_die (never Unicode die glyphs). Letters are single Latin capitals,
## digits, ? and !; no emoji. Shared helpers (die_at, domino, mask, face, star) are used by
## game_teasers_rest.gd. Add one: `_logo_<id>(c)`, id in IDS, line in `_logo()`.

const GI = preload("res://scripts/common/game_icons.gd")
const L = preload("res://scripts/common/game_logos.gd")
const A = preload("res://scripts/common/game_logos_arcade.gd")

const CYAN := GI.CYAN
const BLUE := GI.BLUE
const MAGENTA := GI.MAGENTA
const PINK := GI.PINK
const LIME := GI.LIME
const GOLD := GI.GOLD
const BROWN := Color("c8803a")
const CREAM := Color(0.96, 0.94, 0.86)
const INK := Color(0.1, 0.1, 0.18)

const IDS := [
	"hangman", "wordle", "word_search", "crossword", "anagrams", "word_hunt", "word_ladder",
	"cryptogram", "word_chain",
	"yacht", "farkle", "liars_dice", "shut_the_box", "dominoes", "pig", "bunco", "ship_captain_crew",
	"party_spinner", "charades", "truth_or_dare", "fortune_ball", "spirit_board", "fastest_finger",
	"emoji_guess", "who_am_i",
	"geometry_wars", "star_runner", "sky_raider",
]

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
		"hangman": _logo_hangman(c)
		"wordle": _logo_wordle(c)
		"word_search": _logo_word_search(c)
		"crossword": _logo_crossword(c)
		"anagrams": _logo_anagrams(c)
		"word_hunt": _logo_word_hunt(c)
		"word_ladder": _logo_word_ladder(c)
		"cryptogram": _logo_cryptogram(c)
		"word_chain": _logo_word_chain(c)
		"yacht": _logo_yacht(c)
		"farkle": _logo_farkle(c)
		"liars_dice": _logo_liars_dice(c)
		"shut_the_box": _logo_shut_the_box(c)
		"dominoes": _logo_dominoes(c)
		"pig": _logo_pig(c)
		"bunco": _logo_bunco(c)
		"ship_captain_crew": _logo_ship_captain_crew(c)
		"party_spinner": _logo_party_spinner(c)
		"charades": _logo_charades(c)
		"truth_or_dare": _logo_truth_or_dare(c)
		"fortune_ball": _logo_fortune_ball(c)
		"spirit_board": _logo_spirit_board(c)
		"fastest_finger": _logo_fastest_finger(c)
		"emoji_guess": _logo_emoji_guess(c)
		"who_am_i": _logo_who_am_i(c)
		"geometry_wars": _logo_geometry_wars(c)
		"star_runner": _logo_star_runner(c)
		"sky_raider": _logo_sky_raider(c)

## ---------- shared helpers ----------

## A neon die of side d centred on ctr, rotated ang, drawn through `base`.
static func die_at(c: CanvasItem, base: Transform2D, ctr: Vector2, d: float, value: int, col: Color, ang: float = 0.0) -> void:
	c.draw_set_transform_matrix(base * Transform2D(ang, Vector2.ONE, 0.0, ctr))
	GI.draw_die(c, d, value, col)
	c.draw_set_transform_matrix(base)

## Pips for a domino half: value 0..6 inside a square of side s centred on ctr.
static func pips(c: CanvasItem, ctr: Vector2, s: float, v: int, col: Color) -> void:
	var o := s * 0.28
	var spots := {
		0: [], 1: [Vector2.ZERO], 2: [Vector2(-o, -o), Vector2(o, o)],
		3: [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)],
		4: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)],
		5: [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)],
		6: [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)],
	}
	for p in spots[clampi(v, 0, 6)]:
		c.draw_circle(ctr + p, s * 0.13 + 1.5, Color(col, 0.28))
		c.draw_circle(ctr + p, s * 0.13, col.lightened(0.6))

## A domino; `rect` is the whole tile, split along its long side.
static func domino(c: CanvasItem, rect: Rect2, a: int, b: int, col: Color) -> void:
	GI._slab(c, rect, Color(0.07, 0.06, 0.1), col, minf(rect.size.x, rect.size.y) * 0.2, 0.5)
	var horizontal := rect.size.x >= rect.size.y
	var half := Vector2(rect.size.x * 0.5, rect.size.y) if horizontal else Vector2(rect.size.x, rect.size.y * 0.5)
	var s := minf(half.x, half.y)
	var ca := rect.position + half * 0.5
	var cb := ca + (Vector2(half.x, 0) if horizontal else Vector2(0, half.y))
	if horizontal:
		c.draw_line(Vector2(rect.get_center().x, rect.position.y + 3), Vector2(rect.get_center().x, rect.end.y - 3), Color(col, 0.8), 1.4)
	else:
		c.draw_line(Vector2(rect.position.x + 3, rect.get_center().y), Vector2(rect.end.x - 3, rect.get_center().y), Color(col, 0.8), 1.4)
	pips(c, ca, s, a, col)
	pips(c, cb, s, b, col)

## A theatre mask (happy or sad).
static func mask(c: CanvasItem, ctr: Vector2, k: float, col: Color, happy: bool) -> void:
	var face := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		var r := Vector2(cos(a) * 20.0, sin(a) * 25.0)
		if r.y > 8.0:
			r.x *= 1.0 - (r.y - 8.0) / 40.0
		face.append(ctr + r * k)
	c.draw_circle(ctr, 30.0 * k, Color(col, 0.1))
	c.draw_colored_polygon(face, col.darkened(0.5))
	GI._glow_poly(c, face, col, 1.8)
	for sx in [-1.0, 1.0]:
		var eye := PackedVector2Array([ctr + Vector2(sx * 5.0, -6.0) * k, ctr + Vector2(sx * 14.0, -10.0 if happy else -4.0) * k, ctr + Vector2(sx * 14.0, -2.0) * k])
		c.draw_colored_polygon(eye, Color(0.02, 0.03, 0.06))
	if happy:
		c.draw_arc(ctr + Vector2(0, 6) * k, 11.0 * k, 0.3, PI - 0.3, 14, Color(0.02, 0.03, 0.06), 2.4 * k, true)
	else:
		c.draw_arc(ctr + Vector2(0, 20) * k, 10.0 * k, PI + 0.4, TAU - 0.4, 14, Color(0.02, 0.03, 0.06), 2.4 * k, true)

## A simple smiley-style face: kind 0 smile, 1 sunglasses, 2 heart eyes.
static func face(c: CanvasItem, ctr: Vector2, r: float, kind: int) -> void:
	GI._sphere(c, ctr, r, GOLD)
	var dark := Color(0.12, 0.08, 0.02)
	match kind:
		1:
			c.draw_rect(Rect2(ctr + Vector2(-0.62, -0.38) * r, Vector2(0.52, 0.34) * r), dark)
			c.draw_rect(Rect2(ctr + Vector2(0.10, -0.38) * r, Vector2(0.52, 0.34) * r), dark)
			c.draw_line(ctr + Vector2(-0.1, -0.28) * r, ctr + Vector2(0.1, -0.28) * r, dark, 1.4)
		2:
			for sx in [-1.0, 1.0]:
				var p := ctr + Vector2(sx * 0.36, -0.22) * r
				c.draw_circle(p + Vector2(-0.1, -0.05) * r, 0.14 * r, PINK)
				c.draw_circle(p + Vector2(0.1, -0.05) * r, 0.14 * r, PINK)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.23, 0) * r, p + Vector2(0.23, 0) * r, p + Vector2(0, 0.24) * r]), PINK)
		_:
			for sx in [-1.0, 1.0]:
				c.draw_circle(ctr + Vector2(sx * 0.34, -0.2) * r, 0.1 * r, dark)
	c.draw_arc(ctr + Vector2(0, 0.08) * r, 0.5 * r, 0.35, PI - 0.35, 12, dark, maxf(1.2, 0.09 * r), true)

## A pie slice (spinner wheel).
static func pie(c: CanvasItem, ctr: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var p := PackedVector2Array([ctr])
	for i in range(11):
		var a := lerpf(a0, a1, i / 10.0)
		p.append(ctr + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(p, col.darkened(0.4))
	GI._glow_poly(c, p, col, 1.6)

static func star(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in range(10):
		var a := deg_to_rad(-90.0 + 36.0 * i)
		p.append(ctr + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	c.draw_circle(ctr, r * 1.3, Color(col, 0.12))
	c.draw_colored_polygon(p, col.darkened(0.25))
	GI._glow_poly(c, p, col, 1.4)

static func sparkle(c: CanvasItem, ctr: Vector2, r: float, col: Color) -> void:
	GI._glow_line(c, ctr + Vector2(-r, 0), ctr + Vector2(r, 0), col, 1.0)
	GI._glow_line(c, ctr + Vector2(0, -r), ctr + Vector2(0, r), col, 1.0)

## ---------- Word ----------

static func _logo_hangman(c: CanvasItem) -> void:
	GI._glow_line(c, Vector2(8, 88), Vector2(46, 88), BROWN, 2.4)
	GI._glow_line(c, Vector2(20, 88), Vector2(20, 10), BROWN, 2.4)
	GI._glow_line(c, Vector2(20, 10), Vector2(60, 10), BROWN, 2.4)
	GI._glow_line(c, Vector2(60, 10), Vector2(60, 22), BROWN, 1.6)
	c.draw_arc(Vector2(60, 30), 8.0, 0.0, TAU, 18, PINK, 2.2, true)
	for s in [[Vector2(60, 38), Vector2(60, 60)], [Vector2(60, 44), Vector2(48, 54)], [Vector2(60, 44), Vector2(72, 54)], [Vector2(60, 60), Vector2(50, 74)]]:
		GI._glow_line(c, s[0], s[1], PINK, 2.0)
	for i in range(3):
		GI._glow_line(c, Vector2(52 + i * 15.0, 92), Vector2(62 + i * 15.0, 92), CYAN, 1.6)
	L.txt(c, "A", Vector2(67, 84), 14, GOLD)

static func _logo_wordle(c: CanvasItem) -> void:
	var letters := ["T", "R", "A", "L", "I", "N", "E", "S", "O"]
	var state := [0, 1, 2, 2, 2, 1, 2, 2, 2]
	for i in range(9):
		var col: Color = [Color(0.4, 0.43, 0.52), GOLD, LIME][state[i]]
		var rc := Rect2(8 + (i % 3) * 29.0, 8 + floori(i / 3.0) * 29.0, 26, 26)
		GI._slab(c, rc, col.darkened(0.45), col, 5, 0.4 if state[i] > 0 else 0.0)
		L.txt(c, letters[i], rc.get_center(), 17, Color.WHITE)

static func _logo_word_search(c: CanvasItem) -> void:
	var rows := ["RTKO", "SUNV", "BPDA", "LEIX"]
	GI._slab(c, Rect2(4, 28, 70, 18), Color(GOLD, 0.35), GOLD, 9, 0.6)
	for r in range(4):
		for k in range(4):
			L.txt(c, rows[r][k], Vector2(14 + k * 19.0, 18 + r * 19.0), 14, Color(1, 1, 1, 0.95) if r == 1 else Color(CYAN, 0.9))
	c.draw_arc(Vector2(76, 72), 13.0, 0.0, TAU, 20, LIME, 3.0, true)
	GI._glow_line(c, Vector2(85, 81), Vector2(94, 92), LIME, 3.4)

static func _logo_crossword(c: CanvasItem) -> void:
	var rows := ["ST#E", "#A#N", "RIM#", "#E#S"]
	for r in range(4):
		for k in range(4):
			var rc := Rect2(6 + k * 22.0, 6 + r * 22.0, 20, 20)
			var ch: String = rows[r][k]
			if ch == "#":
				GI._slab(c, rc, Color(0.02, 0.04, 0.08), Color(CYAN, 0.35), 3, 0.0)
			else:
				GI._slab(c, rc, CREAM, CYAN, 3, 0.3)
				L.txt(c, ch, rc.get_center(), 14, INK)
	L.txt(c, "1", Vector2(10, 11), 7, INK)

static func _logo_anagrams(c: CanvasItem) -> void:
	var top := ["R", "O", "M"]
	var bot := ["M", "O", "R"]
	for i in range(3):
		var rc := Rect2(12 + i * 28.0, 10, 24, 28)
		GI._slab(c, rc, CREAM, CYAN, 5, 0.4)
		L.txt(c, top[i], rc.get_center(), 18, INK)
		var rb := Rect2(12 + i * 28.0, 62, 24, 28)
		GI._slab(c, rb, CREAM, LIME, 5, 0.4)
		L.txt(c, bot[i], rb.get_center(), 18, INK)
	GI._glow_arc(c, Vector2(50, 50), 18.0, PI * 0.1, PI * 0.9, GOLD, 1.6)
	GI._glow_arc(c, Vector2(50, 50), 18.0, PI * 1.1, PI * 1.9, GOLD, 1.6)
	GI._glow_poly_open(c, PackedVector2Array([Vector2(36, 55), Vector2(32, 50), Vector2(40, 49)]), GOLD, 1.4)
	GI._glow_poly_open(c, PackedVector2Array([Vector2(64, 45), Vector2(68, 50), Vector2(60, 51)]), GOLD, 1.4)

static func _logo_word_hunt(c: CanvasItem) -> void:
	var letters := "RATESNOLIDHPCMUY"
	var path := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 2), Vector2i(3, 3)]
	var pts := PackedVector2Array()
	for p in path:
		pts.append(Vector2(15.5 + p.x * 23.0, 15.5 + p.y * 23.0))
	for r in range(4):
		for k in range(4):
			var rc := Rect2(5 + k * 23.0, 5 + r * 23.0, 21, 21)
			var on: bool = Vector2i(k, r) in path
			GI._slab(c, rc, CREAM.darkened(0.0 if on else 0.35), GOLD if on else CYAN, 5, 0.5 if on else 0.0)
			L.txt(c, letters[r * 4 + k], rc.get_center(), 14, INK)
	GI._glow_poly_open(c, pts, GOLD, 1.8)

static func _logo_word_ladder(c: CanvasItem) -> void:
	var words := ["CAT", "COT", "DOT", "DOG"]
	var hot := [-1, 1, 0, 2]
	for r in range(4):
		for k in range(3):
			var rc := Rect2(14 + k * 24.0, 6 + r * 24.0, 22, 20)
			var h: bool = hot[r] == k
			GI._slab(c, rc, CREAM, GOLD if h else CYAN, 4, 0.5 if h else 0.0)
			L.txt(c, words[r][k], rc.get_center(), 14, INK)
	for x in [8, 92]:
		GI._glow_line(c, Vector2(x, 4), Vector2(x, 96), Color(CYAN, 0.7), 1.2)

static func _logo_cryptogram(c: CanvasItem) -> void:
	var codes := ["7", "19", "3"]
	var letters := ["H", "", "E"]
	for i in range(3):
		var x := 18.0 + i * 30.0
		L.txt(c, codes[i], Vector2(x, 24), 15, GOLD)
		var rc := Rect2(x - 12, 40, 24, 28)
		if letters[i] == "":
			L.cell(c, rc, CYAN, false, 5.0)
			L.txt(c, "?", rc.get_center(), 16, Color(CYAN, 0.9))
		else:
			GI._slab(c, rc, CREAM, LIME, 5, 0.4)
			L.txt(c, letters[i], rc.get_center(), 18, INK)
	c.draw_arc(Vector2(24, 84), 6.0, 0.0, TAU, 14, GOLD, 2.0, true)
	GI._glow_line(c, Vector2(30, 84), Vector2(54, 84), GOLD, 2.0)
	GI._glow_line(c, Vector2(46, 84), Vector2(46, 90), GOLD, 1.6)
	GI._glow_line(c, Vector2(52, 84), Vector2(52, 90), GOLD, 1.6)

static func _logo_word_chain(c: CanvasItem) -> void:
	var pairs := ["AT", "TE", "EN"]
	var cols := [CYAN, PINK, LIME]
	for i in range(3):
		var rc := Rect2(4 + i * 29.0, 37 + (i % 2) * 8.0, 40, 26)
		GI._slab(c, rc, Color(0.03, 0.05, 0.1), cols[i], 13, 0.6)
		L.txt(c, pairs[i], rc.get_center(), 15, Color.WHITE)
	L.txt(c, "A", Vector2(14, 20), 12, Color(CYAN, 0.8))
	L.txt(c, "N", Vector2(86, 82), 12, Color(LIME, 0.8))

## ---------- Dice ----------

static func _logo_yacht(c: CanvasItem) -> void:
	var cols := [CYAN, PINK, LIME, GOLD, MAGENTA]
	var pos := [Vector2(28, 28), Vector2(72, 26), Vector2(50, 50), Vector2(26, 74), Vector2(74, 74)]
	for i in range(5):
		die_at(c, _b, pos[i], 25.0, 6, cols[i], deg_to_rad((i - 2) * 8.0))

static func _logo_farkle(c: CanvasItem) -> void:
	die_at(c, _b, Vector2(26, 44), 30.0, 1, GOLD, deg_to_rad(-10))
	die_at(c, _b, Vector2(56, 40), 30.0, 5, CYAN, deg_to_rad(6))
	die_at(c, _b, Vector2(78, 66), 28.0, 5, CYAN, deg_to_rad(-8))
	L.txt(c, "350", Vector2(36, 84), 16, GOLD)
	for i in range(5):
		var a := deg_to_rad(-150.0 + i * 25.0)
		GI._glow_line(c, Vector2(26, 44) + Vector2(cos(a), sin(a)) * 24.0, Vector2(26, 44) + Vector2(cos(a), sin(a)) * 31.0, GOLD, 1.0)

static func _logo_liars_dice(c: CanvasItem) -> void:
	die_at(c, _b, Vector2(30, 80), 22.0, 5, CYAN, deg_to_rad(-8))
	die_at(c, _b, Vector2(62, 84), 20.0, 3, PINK, deg_to_rad(10))
	var cup := PackedVector2Array([Vector2(34, 10), Vector2(76, 10), Vector2(84, 66), Vector2(26, 66)])
	c.draw_colored_polygon(cup, GOLD.darkened(0.6))
	GI._glow_poly(c, cup, GOLD, 2.0)
	GI._slab(c, Rect2(22, 62, 66, 10), GOLD.darkened(0.45), GOLD, 4, 0.5)
	L.txt(c, "?", Vector2(55, 38), 32, Color(1, 1, 1, 0.92))

static func _logo_shut_the_box(c: CanvasItem) -> void:
	GI._slab(c, Rect2(4, 20, 92, 60), BROWN.darkened(0.65), BROWN, 10, 0.5)
	var shut := [1, 4, 6]
	for i in range(9):
		var row := 0 if i < 5 else 1
		var k := i if i < 5 else i - 5
		var x := (12.0 + k * 16.0) if row == 0 else (20.0 + k * 16.0)
		var rc := Rect2(x, 28 + row * 26.0, 14, 22)
		if (i + 1) in shut:
			GI._slab(c, rc, Color(0.02, 0.03, 0.05), Color(BROWN, 0.5), 3, 0.0)
		else:
			GI._slab(c, rc, CREAM, GOLD, 3, 0.3)
			L.txt(c, str(i + 1), rc.get_center(), 11, INK)

static func _logo_dominoes(c: CanvasItem) -> void:
	domino(c, Rect2(14, 8, 28, 56), 6, 3, CYAN)
	domino(c, Rect2(34, 66, 58, 28), 3, 5, PINK)
	GI._glow_line(c, Vector2(28, 66), Vector2(36, 72), GOLD, 1.4)

static func _logo_pig(c: CanvasItem) -> void:
	var pink := Color("ff8fb8")
	for sx in [-1.0, 1.0]:
		var ear := PackedVector2Array([Vector2(50 + sx * 14.0, 28), Vector2(50 + sx * 34.0, 12), Vector2(50 + sx * 32.0, 38)])
		c.draw_colored_polygon(ear, pink.darkened(0.35))
		GI._glow_poly(c, ear, pink, 1.4)
	GI._sphere(c, Vector2(50, 52), 30.0, pink)
	GI._ellipse(c, Vector2(50, 62), 14.0, 10.0, pink.darkened(0.3))
	GI._glow_poly(c, GI._pts(Vector2(50, 62), 14.0, 10.0), Color(pink, 0.9), 1.4)
	for sx in [-1.0, 1.0]:
		GI._ellipse(c, Vector2(50 + sx * 5.0, 62), 2.4, 3.4, Color(0.2, 0.05, 0.1))
		c.draw_circle(Vector2(50 + sx * 14.0, 44), 3.4, Color.WHITE)
		c.draw_circle(Vector2(50 + sx * 14.0, 44.5), 1.6, Color(0, 0, 0, 0.9))
	die_at(c, _b, Vector2(80, 80), 20.0, 1, GOLD, deg_to_rad(10))

static func _logo_bunco(c: CanvasItem) -> void:
	star(c, Vector2(50, 20), 13.0, GOLD)
	for i in range(3):
		die_at(c, _b, Vector2(24 + i * 26.0, 66), 25.0, 3, CYAN if i != 1 else PINK, deg_to_rad((i - 1) * 10.0))
	for i in range(3):
		var a := deg_to_rad(-60.0 + i * 60.0)
		GI._glow_line(c, Vector2(50, 20) + Vector2(cos(a), sin(a)) * 20.0 + Vector2(0, 8), Vector2(50, 20) + Vector2(cos(a), sin(a)) * 27.0 + Vector2(0, 8), GOLD, 1.0)

static func _logo_ship_captain_crew(c: CanvasItem) -> void:
	for i in range(4):
		c.draw_arc(Vector2(14 + i * 24.0, 86), 10.0, PI * 1.1, PI * 1.9, 10, Color(CYAN, 0.8), 1.6, true)
	var hull := PackedVector2Array([Vector2(16, 60), Vector2(84, 60), Vector2(72, 78), Vector2(28, 78)])
	c.draw_colored_polygon(hull, CYAN.darkened(0.55))
	GI._glow_poly(c, hull, CYAN, 2.0)
	GI._glow_line(c, Vector2(50, 60), Vector2(50, 10), Color(1, 1, 1, 0.85), 1.8)
	var s1 := PackedVector2Array([Vector2(53, 14), Vector2(53, 54), Vector2(82, 54)])
	var s2 := PackedVector2Array([Vector2(47, 22), Vector2(47, 54), Vector2(22, 54)])
	c.draw_colored_polygon(s1, PINK.darkened(0.3))
	c.draw_colored_polygon(s2, GOLD.darkened(0.3))
	GI._glow_poly(c, s1, PINK, 1.4)
	GI._glow_poly(c, s2, GOLD, 1.4)
	die_at(c, _b, Vector2(82, 22), 18.0, 6, LIME, deg_to_rad(12))

## ---------- Party ----------

static func _logo_party_spinner(c: CanvasItem) -> void:
	var cols := [PINK, CYAN, GOLD, LIME, BLUE, MAGENTA]
	for i in range(6):
		var col: Color = cols[i]
		pie(c, Vector2(50, 54), 38.0, -PI * 0.5 + i * TAU / 6.0 + 0.04, -PI * 0.5 + (i + 1) * TAU / 6.0 - 0.04, col)
	GI._sphere(c, Vector2(50, 54), 8.0, Color(0.95, 0.97, 1.0))
	var tip := PackedVector2Array([Vector2(50, 12), Vector2(43, 0), Vector2(57, 0)])
	c.draw_colored_polygon(tip, Color.WHITE)
	GI._glow_poly(c, tip, Color.WHITE, 1.2)

static func _logo_charades(c: CanvasItem) -> void:
	mask(c, Vector2(36, 40), 1.25, GOLD, true)
	mask(c, Vector2(66, 62), 1.1, CYAN, false)

static func _logo_truth_or_dare(c: CanvasItem) -> void:
	GI._slab(c, Rect2(6, 12, 50, 44), CYAN.darkened(0.6), CYAN, 12, 0.6)
	c.draw_colored_polygon(PackedVector2Array([Vector2(16, 54), Vector2(12, 70), Vector2(30, 54)]), CYAN.darkened(0.45))
	L.txt(c, "T", Vector2(31, 34), 32, Color(1, 1, 1, 0.95))
	GI._slab(c, Rect2(44, 44, 50, 44), PINK.darkened(0.6), PINK, 12, 0.6)
	c.draw_colored_polygon(PackedVector2Array([Vector2(84, 86), Vector2(88, 98), Vector2(70, 86)]), PINK.darkened(0.45))
	L.txt(c, "D", Vector2(69, 66), 32, Color(1, 1, 1, 0.95))
	var flame := PackedVector2Array([Vector2(82, 36), Vector2(76, 26), Vector2(80, 28), Vector2(78, 16), Vector2(90, 30), Vector2(86, 30), Vector2(90, 38)])
	c.draw_colored_polygon(flame, GOLD)
	GI._glow_poly(c, flame, Color("ff8a2b"), 1.2)

static func _logo_fortune_ball(c: CanvasItem) -> void:
	GI._slab(c, Rect2(28, 84, 44, 8), BLUE.darkened(0.6), BLUE, 3, 0.4)
	GI._halo(c, Vector2(50, 46), 42.0, BLUE)
	GI._sphere(c, Vector2(50, 46), 34.0, Color(0.25, 0.27, 0.45))
	c.draw_circle(Vector2(50, 44), 16.0, Color(0.02, 0.04, 0.12))
	c.draw_arc(Vector2(50, 44), 16.0, 0.0, TAU, 24, CYAN, 2.0, true)
	var tri := PackedVector2Array([Vector2(50, 33), Vector2(60, 51), Vector2(40, 51)])
	c.draw_colored_polygon(tri, BLUE.darkened(0.2))
	GI._glow_poly(c, tri, CYAN, 1.2)
	L.txt(c, "?", Vector2(50, 46), 11, Color.WHITE)
	sparkle(c, Vector2(14, 22), 6.0, GOLD)
	sparkle(c, Vector2(88, 30), 5.0, GOLD)
	sparkle(c, Vector2(82, 8), 4.0, CYAN)

static func _logo_spirit_board(c: CanvasItem) -> void:
	var letters := "ABCDEFG"
	for i in range(7):
		var a := deg_to_rad(200.0 + i * 23.3)
		var p := Vector2(50, 78) + Vector2(cos(a), sin(a)) * 42.0
		L.txt(c, letters[i], p, 11, Color(CYAN, 0.9))
	var plan := PackedVector2Array([Vector2(50, 34), Vector2(68, 64), Vector2(60, 90), Vector2(40, 90), Vector2(32, 64)])
	c.draw_colored_polygon(plan, BROWN.darkened(0.55))
	GI._glow_poly(c, plan, BROWN, 2.0)
	c.draw_circle(Vector2(50, 66), 9.0, Color(LIME, 0.2))
	c.draw_arc(Vector2(50, 66), 9.0, 0.0, TAU, 18, LIME, 2.2, true)
	sparkle(c, Vector2(12, 16), 5.0, GOLD)
	sparkle(c, Vector2(90, 14), 4.0, GOLD)

static func _logo_fastest_finger(c: CanvasItem) -> void:
	for r in [14.0, 26.0, 38.0]:
		c.draw_arc(Vector2(50, 36), r, 0.0, TAU, 28, Color(CYAN, 0.7 - r * 0.012), 2.0, true)
	GI._slab(c, Rect2(40, 34, 20, 56), Color("e8a98a").darkened(0.5), Color("e8a98a"), 10, 0.5)
	c.draw_arc(Vector2(50, 44), 6.0, PI, TAU, 10, Color("e8a98a").lightened(0.3), 1.4, true)
	var bolt := PackedVector2Array([Vector2(82, 8), Vector2(72, 26), Vector2(78, 26), Vector2(74, 40), Vector2(88, 20), Vector2(82, 20)])
	c.draw_colored_polygon(bolt, GOLD.lightened(0.3))
	GI._glow_poly(c, bolt, GOLD, 1.2)

static func _logo_emoji_guess(c: CanvasItem) -> void:
	face(c, Vector2(34, 66), 22.0, 0)
	c.draw_circle(Vector2(58, 44), 3.2, Color(1, 1, 1, 0.8))
	c.draw_circle(Vector2(66, 34), 4.6, Color(1, 1, 1, 0.8))
	GI._slab(c, Rect2(52, 4, 42, 28), Color(0.03, 0.05, 0.1), CYAN, 14, 0.6)
	L.txt(c, "?", Vector2(73, 18), 22, GOLD)

static func _logo_who_am_i(c: CanvasItem) -> void:
	var cone := PackedVector2Array([Vector2(50, 0), Vector2(8, 96), Vector2(92, 96)])
	c.draw_colored_polygon(cone, Color(1, 1, 1, 0.06))
	var body := PackedVector2Array([Vector2(18, 92), Vector2(24, 66), Vector2(40, 58), Vector2(60, 58), Vector2(76, 66), Vector2(82, 92)])
	c.draw_colored_polygon(body, CYAN.darkened(0.75))
	GI._glow_poly(c, body, CYAN, 1.8)
	GI._ellipse(c, Vector2(50, 40), 17.0, 20.0, CYAN.darkened(0.75))
	GI._glow_poly(c, GI._pts(Vector2(50, 40), 17.0, 20.0), CYAN, 1.8)
	GI._slab(c, Rect2(28, 20, 44, 7), CYAN.darkened(0.5), CYAN, 3, 0.0)
	L.txt(c, "?", Vector2(50, 44), 28, GOLD)

## ---------- Adventure ----------

static func _logo_geometry_wars(c: CanvasItem) -> void:
	for p in [Vector2(20, 22), Vector2(80, 26)]:
		var dia := PackedVector2Array([p + Vector2(0, -11), p + Vector2(11, 0), p + Vector2(0, 11), p + Vector2(-11, 0)])
		GI._glow_poly(c, dia, PINK, 1.8)
	GI._glow_poly(c, PackedVector2Array([Vector2(74, 62), Vector2(88, 62), Vector2(88, 76), Vector2(74, 76)]), GOLD, 1.8)
	for i in range(4):
		var a := TAU * i / 4.0 + 0.4
		GI._glow_line(c, Vector2(22, 72), Vector2(22, 72) + Vector2(cos(a), sin(a)) * 12.0, LIME, 1.8)
	var ship := PackedVector2Array([Vector2(50, 36), Vector2(60, 62), Vector2(50, 56), Vector2(40, 62)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.5))
	GI._glow_poly(c, ship, CYAN, 2.2)
	GI._glow_line(c, Vector2(50, 32), Vector2(50, 8), Color(1, 1, 1, 0.9), 1.6)
	for i in range(8):
		var a := TAU * i / 8.0
		GI._glow_line(c, Vector2(50, 84) + Vector2(cos(a), sin(a)) * 4.0, Vector2(50, 84) + Vector2(cos(a), sin(a)) * 11.0, GOLD, 1.0)

static func _logo_star_runner(c: CanvasItem) -> void:
	for i in range(5):
		GI._glow_line(c, Vector2(4, 40 + i * 6.0), Vector2(34 - i * 3.0, 40 + i * 6.0), Color(CYAN, 0.8 - i * 0.12), 1.4)
	var ship := PackedVector2Array([Vector2(60, 52), Vector2(34, 42), Vector2(40, 52), Vector2(34, 62)])
	c.draw_colored_polygon(ship, CYAN.darkened(0.5))
	GI._glow_poly(c, ship, CYAN, 2.0)
	star(c, Vector2(76, 26), 12.0, GOLD)
	star(c, Vector2(86, 62), 8.0, GOLD)
	star(c, Vector2(62, 84), 6.0, GOLD)

static func _logo_sky_raider(c: CanvasItem) -> void:
	var plane := PackedVector2Array([Vector2(50, 6), Vector2(57, 34), Vector2(92, 62), Vector2(92, 70), Vector2(58, 58), Vector2(56, 78), Vector2(66, 88), Vector2(66, 92), Vector2(50, 86), Vector2(34, 92), Vector2(34, 88), Vector2(44, 78), Vector2(42, 58), Vector2(8, 70), Vector2(8, 62), Vector2(43, 34)])
	c.draw_colored_polygon(plane, CYAN.darkened(0.55))
	GI._glow_poly(c, plane, CYAN, 2.0)
	GI._sphere(c, Vector2(50, 38), 5.0, GOLD)
	for x in [26.0, 74.0]:
		GI._glow_line(c, Vector2(x, 52), Vector2(x, 38), Color(1, 1, 1, 0.9), 1.6)
	GI._glow_line(c, Vector2(26, 34), Vector2(26, 22), PINK, 1.6)
	GI._glow_line(c, Vector2(74, 34), Vector2(74, 22), PINK, 1.6)
