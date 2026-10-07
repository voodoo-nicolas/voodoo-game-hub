extends RefCounted

## Playing-card helpers for this game (each card game carries its own copy so
## its pack stays self-contained). A card is an int 0..51:
## rank = card % 13 + 1 (1 = Ace ... 13 = King), suit = card / 13
## (0 ♠, 1 ♥, 2 ♦, 3 ♣).

const SUITS := ["♠", "♥", "♦", "♣"]
## Neon cards (reference/art/ART_STYLE.md): a dark face with a glowing rim,
## hearts and diamonds in pink, spades and clubs in cyan.
const COLOR_FACE := Color(0.05, 0.07, 0.15)
const COLOR_BACK := Color(0.16, 0.06, 0.28)
const COLOR_RED := Color("ff4f9a")
const COLOR_INK := Color(0.9, 0.98, 1.0)
const COLOR_HILITE := Color("ffae2b")
const RIM_RED := Color("ff2bd6")
const RIM_BLACK := Color("29e6ff")
const RIM_BACK := Color("9b4dff")

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

## Look (STANDARDS §9): true = traditional cards (ivory face, red / black ink,
## blue back, plain drop shadow; the default), false = the neon cards above.
## The game's `_set_skin()` sets it, then redraws.
static var classic: bool = true
const CLASSIC_FACE := Color(0.98, 0.97, 0.93)
const CLASSIC_RED := Color(0.78, 0.1, 0.14)
const CLASSIC_BLACK := Color(0.07, 0.07, 0.1)
const CLASSIC_BACK := Color(0.1, 0.24, 0.62)

## Draws a card into `rect` on `canvas`. face_up=false draws the back;
## card = -1 draws an empty slot outline.
static func draw_card(canvas: CanvasItem, rect: Rect2, card: int, face_up: bool = true, hilite: bool = false, dim: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	var radius := int(max(3.0, rect.size.x * 0.08))
	sb.set_corner_radius_all(radius)
	if classic:
		_draw_classic(canvas, rect, card, face_up, hilite, dim, sb, radius)
		return
	if card < 0:
		sb.bg_color = Color(1, 1, 1, 0.06)
		sb.set_border_width_all(2)
		sb.border_color = COLOR_HILITE if hilite else Color(1, 1, 1, 0.2)
		canvas.draw_style_box(sb, rect)
		return
	var rim: Color = (RIM_RED if is_red(card) else RIM_BLACK) if face_up else RIM_BACK
	sb.bg_color = COLOR_FACE if face_up else COLOR_BACK
	sb.set_border_width_all(4 if hilite else 2)
	sb.border_color = COLOR_HILITE if hilite else rim
	sb.shadow_color = Color(COLOR_HILITE if hilite else rim, 0.45 if hilite else 0.22)
	sb.shadow_size = 8 if hilite else 4
	canvas.draw_style_box(sb, rect)
	if not face_up:
		var inner := rect.grow(-rect.size.x * 0.12)
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0, 0, 0, 0)
		sb2.set_border_width_all(2)
		sb2.border_color = Color(RIM_BACK.lightened(0.3), 0.6)
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

static func _draw_classic(canvas: CanvasItem, rect: Rect2, card: int, face_up: bool, hilite: bool, dim: bool, sb: StyleBoxFlat, radius: int) -> void:
	if card < 0:
		sb.bg_color = Color(0, 0, 0, 0.18)
		sb.set_border_width_all(2)
		sb.border_color = COLOR_HILITE if hilite else Color(1, 1, 1, 0.35)
		canvas.draw_style_box(sb, rect)
		return
	sb.bg_color = CLASSIC_FACE if face_up else CLASSIC_BACK
	sb.set_border_width_all(4 if hilite else 2)
	sb.border_color = COLOR_HILITE if hilite else (Color(0.45, 0.45, 0.5) if face_up else Color.WHITE)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 2)
	canvas.draw_style_box(sb, rect)
	if not face_up:
		var inner := rect.grow(-rect.size.x * 0.12)
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0, 0, 0, 0)
		sb2.set_border_width_all(2)
		sb2.border_color = Color(0.55, 0.7, 1.0, 0.6)
		sb2.set_corner_radius_all(max(2, radius - 2))
		canvas.draw_style_box(sb2, inner)
		return
	var font: Font = ThemeDB.fallback_font
	var col := CLASSIC_RED if is_red(card) else CLASSIC_BLACK
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
