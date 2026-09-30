extends RefCounted

## Playing-card helpers for this game (each card game carries its own copy so
## its pack stays self-contained). A card is an int 0..51:
## rank = card % 13 + 1 (1 = Ace ... 13 = King), suit = card / 13
## (0 ♠, 1 ♥, 2 ♦, 3 ♣).

const SUITS := ["♠", "♥", "♦", "♣"]
const COLOR_FACE := Color(0.97, 0.97, 0.94)
const COLOR_BACK := Color(0.2, 0.35, 0.6)
const COLOR_RED := Color(0.8, 0.1, 0.12)
const COLOR_INK := Color(0.08, 0.08, 0.1)
const COLOR_HILITE := Color(1.0, 0.84, 0.1)

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
## card = -1 draws an empty slot outline.
static func draw_card(canvas: CanvasItem, rect: Rect2, card: int, face_up: bool = true, hilite: bool = false, dim: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	var radius := int(max(3.0, rect.size.x * 0.08))
	sb.set_corner_radius_all(radius)
	if card < 0:
		sb.bg_color = Color(1, 1, 1, 0.06)
		sb.set_border_width_all(2)
		sb.border_color = COLOR_HILITE if hilite else Color(1, 1, 1, 0.2)
		canvas.draw_style_box(sb, rect)
		return
	sb.bg_color = COLOR_FACE if face_up else COLOR_BACK
	sb.set_border_width_all(4 if hilite else 1)
	sb.border_color = COLOR_HILITE if hilite else Color(0.1, 0.1, 0.12)
	canvas.draw_style_box(sb, rect)
	if not face_up:
		var inner := rect.grow(-rect.size.x * 0.12)
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0, 0, 0, 0)
		sb2.set_border_width_all(2)
		sb2.border_color = Color(1, 1, 1, 0.35)
		sb2.set_corner_radius_all(max(2, radius - 2))
		canvas.draw_style_box(sb2, inner)
		return
	var font: Font = ThemeDB.fallback_font
	var col := COLOR_RED if is_red(card) else COLOR_INK
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
