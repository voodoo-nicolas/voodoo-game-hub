extends RefCounted

## Playing-card helpers for this game (each card game carries its own copy so
## its pack stays self-contained). Colours come from video_poker_look.gd. A card is an int 0..51:
## rank = card % 13 + 1 (1 = Ace ... 13 = King), suit = card / 13
## (0 ♠, 1 ♥, 2 ♦, 3 ♣).

const Look = preload("res://scripts/games/video_poker/video_poker_look.gd")

const SUITS := ["♠", "♥", "♦", "♣"]
const SUIT_LETTERS := "shdc"
## Corner radius of the owner's card art, as a fraction of the card's width.
const ART_RADIUS := 0.058

## Four-colour deck (an Options choice): clubs green and diamonds blue, so
## the suits can't be mixed up. Only the indices and pips the code draws change.
static var four_color := false

## The suit's colour for the corner indices and the pips the code draws.
static func suit_color(suit: int) -> Color:
	return Look.c(("suit4_" if four_color else "suit_") + SUIT_LETTERS[suit])

## Art slot of a court card or ace ("face_K_s"), "" for the number cards.
static func face_key(card: int) -> String:
	var r := rank(card)
	if r == 1 or r >= 11:
		return "face_%s_%s" % [rank_str(r), SUIT_LETTERS[suit(card)]]
	return ""

static func rank(card: int) -> int:
	return card % 13 + 1

static func suit(card: int) -> int:
	return card / 13

static func is_red(card: int) -> bool:
	return suit(card) == 1 or suit(card) == 2

static func rank_str(r: int) -> String:
	match r:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
	return str(r)

static func label(card: int) -> String:
	return rank_str(rank(card)) + SUITS[suit(card)]

static func new_deck(decks: int = 1) -> Array:
	var d: Array = []
	for k in decks:
		for c in 52:
			d.append(c)
	d.shuffle()
	return d

## Draws a card into `rect` on `canvas`. face_up=false draws the back;
## card = -1 draws an empty slot outline. The look (video_poker_look.gd) sets
## the colours: ivory and drop shadows (classic) or dark with a neon rim (voodoo).
static func draw_card(canvas: CanvasItem, rect: Rect2, card: int, face_up: bool = true, hilite: bool = false, dim: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	var radius := int(max(3.0, rect.size.x * 0.08))
	sb.set_corner_radius_all(radius)
	var neon := Look.f("glow") > 0.0
	var hi := Look.c("hilite")
	if card < 0:
		sb.bg_color = Color(1, 1, 1, 0.06) if neon else Color(0, 0, 0, 0.18)
		sb.set_border_width_all(2)
		sb.border_color = hi if hilite else (Color(1, 1, 1, 0.2) if neon else Color(1, 1, 1, 0.35))
		canvas.draw_style_box(sb, rect)
		return
	if not face_up:
		var back := Look.tex("card_back")
		if back != null:
			_shadow(canvas, rect)
			canvas.draw_texture_rect(back, rect, false)
			return
	else:
		var art: Texture2D = Look.tex(face_key(card)) if face_key(card) != "" else Look.tex("card_face")
		if art != null:
			_draw_art_card(canvas, rect, card, art, hilite, dim)
			return
	var rim: Color = Look.c("rim_red" if is_red(card) else "rim_black") if face_up else Look.c("card_back_rim")
	sb.bg_color = Look.c("card_face") if face_up else Look.c("card_back")
	sb.set_border_width_all(4 if hilite else 2)
	if neon:
		sb.border_color = hi if hilite else rim
		sb.shadow_color = Color(hi if hilite else rim, 0.45 if hilite else 0.22)
		sb.shadow_size = 8 if hilite else 4
	else:
		sb.border_color = hi if hilite else (Look.c("card_edge") if face_up else Look.c("card_back_rim"))
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(1, 2)
	canvas.draw_style_box(sb, rect)
	if not face_up:
		var inner := rect.grow(-rect.size.x * 0.12)
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0, 0, 0, 0)
		sb2.set_border_width_all(2)
		sb2.border_color = Color(Look.c("card_back_rim"), 0.6)
		sb2.set_corner_radius_all(max(2, radius - 2))
		canvas.draw_style_box(sb2, inner)
		return
	var font: Font = ThemeDB.fallback_font
	var col := Look.c("ink_red") if is_red(card) else Look.c("ink_black")
	# rank and suit on one line, so overlapped cards stay readable
	var fs := int(max(12.0, rect.size.x * 0.3))
	canvas.draw_string(font, rect.position + Vector2(rect.size.x * 0.06, fs * 0.95), label(card), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if rect.size.y > rect.size.x * 1.2:
		var big := int(rect.size.x * 0.5)
		canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.62 + big * 0.35), SUITS[suit(card)],
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, big, col)
	if dim:
		var sb3 := StyleBoxFlat.new()
		sb3.bg_color = Color(0, 0, 0, 0.45)
		sb3.set_corner_radius_all(radius)
		canvas.draw_style_box(sb3, rect)


# ---------- the owner's card art ----------

static func _shadow(canvas: CanvasItem, rect: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	sb.set_corner_radius_all(int(rect.size.x * ART_RADIUS))
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = maxi(2, int(rect.size.x * 0.03))
	sb.shadow_offset = Vector2(1, maxf(2.0, rect.size.x * 0.02))
	canvas.draw_style_box(sb, rect)

## A face card or ace is the art as it is, with a big readable index laid over
## its tiny corner one; a number card is the blank marble face with the pips
## and indices drawn in code.
static func _draw_art_card(canvas: CanvasItem, rect: Rect2, card: int, art: Texture2D, hilite: bool, dim: bool) -> void:
	var r := rank(card)
	var number := r >= 2 and r <= 10
	if hilite:
		# the glow goes behind the art: a shadow drawn over it would wash the card orange
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0, 0, 0, 0)
		glow.set_corner_radius_all(int(rect.size.x * ART_RADIUS))
		glow.shadow_color = Color(Look.c("hilite"), 0.55)
		glow.shadow_size = 9
		canvas.draw_style_box(glow, rect)
	else:
		_shadow(canvas, rect)
	canvas.draw_texture_rect(art, rect, false)
	var col := suit_color(suit(card))
	if number:
		_draw_pips(canvas, rect, r, suit(card), col)
		_draw_index(canvas, rect, card, col, false, false)
		_draw_index(canvas, rect, card, col, false, true)
	else:
		_draw_index(canvas, rect, card, col, true, false)
	var radius := int(rect.size.x * ART_RADIUS)
	if dim:
		var sb3 := StyleBoxFlat.new()
		sb3.bg_color = Color(0, 0, 0, 0.5)
		sb3.set_corner_radius_all(radius)
		canvas.draw_style_box(sb3, rect)
	if hilite:
		var hb := StyleBoxFlat.new()
		hb.bg_color = Color(0, 0, 0, 0)
		hb.set_corner_radius_all(radius)
		hb.set_border_width_all(4)
		hb.border_color = Look.c("hilite")
		canvas.draw_style_box(hb, rect)

## Rank and a small suit at a corner (the opposite corner, upside down, with
## `flipped`). `plate` puts a dark plate behind it, to cover the art's own tiny index.
static func _draw_index(canvas: CanvasItem, rect: Rect2, card: int, col: Color, plate: bool, flipped: bool) -> void:
	var w := rect.size.x
	var text := rank_str(rank(card))
	var fs := int(maxf(11.0, w * (0.235 if text.length() > 1 else 0.28)))
	var font: Font = ThemeDB.fallback_font
	var pw := w * (0.33 if text.length() > 1 else 0.28)
	var ph := fs * 1.0 + pw * 0.98
	var origin := rect.position + Vector2(w * 0.035, w * 0.035)
	if flipped:
		canvas.draw_set_transform(rect.end - Vector2(w * 0.035, w * 0.035), PI, Vector2.ONE)
		origin = Vector2.ZERO
	if plate:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Look.c("plate")
		sb.set_corner_radius_all(int(w * 0.05))
		sb.border_color = Look.c("plate_edge")
		sb.set_border_width_all(1)
		canvas.draw_style_box(sb, Rect2(origin, Vector2(pw, ph)))
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	canvas.draw_string(font, origin + Vector2((pw - tw) / 2.0, fs * 0.92), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	_draw_suit(canvas, suit(card), origin + Vector2(pw / 2.0, fs * 1.0 + pw * 0.5), pw * 0.58, col)
	if flipped:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Pip positions of the number cards as fractions of the card: columns at
## 0.31 / 0.5 / 0.69, rows from 0.2 to 0.8; the lower half is drawn upside down.
const PIPS := {
	2: [[0.5, 0.2], [0.5, 0.8]],
	3: [[0.5, 0.2], [0.5, 0.5], [0.5, 0.8]],
	4: [[0.31, 0.2], [0.69, 0.2], [0.31, 0.8], [0.69, 0.8]],
	5: [[0.31, 0.2], [0.69, 0.2], [0.5, 0.5], [0.31, 0.8], [0.69, 0.8]],
	6: [[0.31, 0.2], [0.69, 0.2], [0.31, 0.5], [0.69, 0.5], [0.31, 0.8], [0.69, 0.8]],
	7: [[0.31, 0.2], [0.69, 0.2], [0.5, 0.35], [0.31, 0.5], [0.69, 0.5], [0.31, 0.8], [0.69, 0.8]],
	8: [[0.31, 0.2], [0.69, 0.2], [0.5, 0.35], [0.31, 0.5], [0.69, 0.5], [0.5, 0.65], [0.31, 0.8], [0.69, 0.8]],
	9: [[0.31, 0.2], [0.69, 0.2], [0.31, 0.4], [0.69, 0.4], [0.5, 0.5], [0.31, 0.6], [0.69, 0.6], [0.31, 0.8], [0.69, 0.8]],
	10: [[0.31, 0.2], [0.69, 0.2], [0.5, 0.3], [0.31, 0.4], [0.69, 0.4], [0.31, 0.6], [0.69, 0.6], [0.5, 0.7], [0.31, 0.8], [0.69, 0.8]],
}

static func _draw_pips(canvas: CanvasItem, rect: Rect2, r: int, su: int, col: Color) -> void:
	var size := rect.size.x * (0.27 if r <= 3 else 0.24)
	for p in PIPS[r]:
		var c := rect.position + Vector2(rect.size.x * p[0], rect.size.y * p[1])
		_draw_suit(canvas, su, c, size, col, p[1] > 0.5)

## A suit sign `size` tall, centred on `c`; `flip` turns it upside down.
static func _draw_suit(canvas: CanvasItem, su: int, c: Vector2, size: float, col: Color, flip: bool = false) -> void:
	var k := size / 2.0
	var sy := -1.0 if flip else 1.0
	var at := func(x: float, y: float) -> Vector2: return c + Vector2(x * k, y * k * sy)
	var circle := func(x: float, y: float, rad: float) -> void: canvas.draw_circle(c + Vector2(x * k, y * k * sy), rad * k, col)
	match su:
		0:  # spade: an upside-down heart with a stem
			circle.call(-0.4, 0.12, 0.46)
			circle.call(0.4, 0.12, 0.46)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(-0.84, 0.02), at.call(0.84, 0.02), at.call(0.0, -1.0)]), col)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(0.0, 0.2), at.call(0.3, 1.0), at.call(-0.3, 1.0)]), col)
		1:  # heart
			circle.call(-0.4, -0.3, 0.46)
			circle.call(0.4, -0.3, 0.46)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(-0.84, -0.18), at.call(0.84, -0.18), at.call(0.0, 1.0)]), col)
		2:  # diamond
			canvas.draw_colored_polygon(PackedVector2Array([at.call(0.0, -1.0), at.call(0.66, 0.0), at.call(0.0, 1.0), at.call(-0.66, 0.0)]), col)
		_:  # club: three leaves and a stem
			circle.call(0.0, -0.52, 0.4)
			circle.call(-0.52, 0.16, 0.4)
			circle.call(0.52, 0.16, 0.4)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(-0.4, 0.1), at.call(0.0, -0.4), at.call(0.4, 0.1), at.call(0.0, 0.5)]), col)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(0.0, 0.2), at.call(0.3, 1.0), at.call(-0.3, 1.0)]), col)
