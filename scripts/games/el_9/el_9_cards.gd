extends RefCounted

## Spanish deck (baraja española, 48 cards: 1-12 in four suits) drawn in code, no image files (own work, nothing to credit).
## Each card game carries its own copy so its pack stays self-contained.
## A card is an int 0..47: suit = card / 12 (0 oros, 1 copas, 2 espadas, 3 bastos),
## number = card % 12 + 1 (10 sota, 11 caballo, 12 rey).

const SUIT_NAMES := ["oros", "copas", "espadas", "bastos"]
const SUIT_ICONS := ["🪙", "🍷", "⚔️", "🌿"]
const SUIT_COLORS := [Color("d9a21b"), Color("c4282f"), Color("2a5ea8"), Color("2f8a3c")]
const SUIT_COLORS_NEON := [Color("ffd23c"), Color("ff4fa3"), Color("3cc8ff"), Color("8cff5a")]
const COLOR_HILITE := Color("ffae2b")

static var classic: bool = true

static func suit(card: int) -> int:
	return card / 12

static func idx(card: int) -> int:
	return card % 12

static func number(card: int) -> int:
	return idx(card) + 1

static func make(s: int, num: int) -> int:
	return s * 12 + num - 1

static func label(card: int) -> String:
	return str(number(card)) + " " + SUIT_NAMES[suit(card)]

static func short(card: int) -> String:
	return str(number(card)) + SUIT_ICONS[suit(card)]

static func new_deck() -> Array:
	var d: Array = []
	for c in 48:
		d.append(c)
	d.shuffle()
	return d

static func _col(s: int) -> Color:
	return SUIT_COLORS[s] if classic else SUIT_COLORS_NEON[s]

## Draws a card into `rect`. face_up=false draws the back; card = -1 an empty slot.
static func draw_card(canvas: CanvasItem, rect: Rect2, card: int, face_up: bool = true, hilite: bool = false, dim: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	var radius := int(max(3.0, rect.size.x * 0.08))
	sb.set_corner_radius_all(radius)
	if card < 0:
		sb.bg_color = Color(0, 0, 0, 0.18) if classic else Color(1, 1, 1, 0.06)
		sb.set_border_width_all(2)
		sb.border_color = COLOR_HILITE if hilite else Color(1, 1, 1, 0.3)
		canvas.draw_style_box(sb, rect)
		return
	var face := Color(0.98, 0.95, 0.86) if classic else Color(0.05, 0.07, 0.15)
	var back := Color(0.55, 0.1, 0.12) if classic else Color(0.16, 0.06, 0.28)
	sb.bg_color = face if face_up else back
	sb.set_border_width_all(4 if hilite else 2)
	if face_up:
		sb.border_color = COLOR_HILITE if hilite else (Color(0.45, 0.4, 0.3) if classic else _col(suit(card)))
	else:
		sb.border_color = COLOR_HILITE if hilite else (Color.WHITE if classic else Color("9b4dff"))
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(1, 2)
	canvas.draw_style_box(sb, rect)
	if not face_up:
		var inner := rect.grow(-rect.size.x * 0.12)
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0, 0, 0, 0)
		sb2.set_border_width_all(2)
		sb2.border_color = Color(1, 0.85, 0.5, 0.7)
		sb2.set_corner_radius_all(max(2, radius - 2))
		canvas.draw_style_box(sb2, inner)
		return
	var s := suit(card)
	var col := _col(s)
	var font: Font = ThemeDB.fallback_font
	var fs := int(max(12.0, rect.size.x * 0.34))
	canvas.draw_string(font, rect.position + Vector2(rect.size.x * 0.07, fs * 0.95), str(number(card)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var r := minf(rect.size.x, rect.size.y * 0.7) * 0.28
	var ctr := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.62)
	_draw_suit(canvas, s, ctr, r, col)
	if number(card) >= 10:
		var f2 := int(max(10.0, rect.size.x * 0.2))
		var nm: String = {10: "SOTA", 11: "CABALLO", 12: "REY"}[number(card)]
		canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y - 6), nm, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, f2, col)
	if dim:
		var sb3 := StyleBoxFlat.new()
		sb3.bg_color = Color(0, 0, 0, 0.45)
		sb3.set_corner_radius_all(radius)
		canvas.draw_style_box(sb3, rect)

static func _draw_suit(c: CanvasItem, s: int, p: Vector2, r: float, col: Color) -> void:
	match s:
		0:  # oros: a coin
			c.draw_circle(p, r, col)
			c.draw_circle(p, r * 0.72, col.darkened(0.25))
			c.draw_circle(p, r * 0.4, col)
		1:  # copas: a cup
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(r * 0.6, r * 0.2), p + Vector2(-r * 0.6, r * 0.2)]), col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.12, r * 0.2), Vector2(r * 0.24, r * 0.6)), col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.6, r * 0.8), Vector2(r * 1.2, r * 0.2)), col)
		2:  # espadas: a sword
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.2), p + Vector2(r * 0.22, r * 0.3), p + Vector2(-r * 0.22, r * 0.3)]), col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.7, r * 0.3), Vector2(r * 1.4, r * 0.18)), col)
			c.draw_rect(Rect2(p + Vector2(-r * 0.1, r * 0.48), Vector2(r * 0.2, r * 0.6)), col)
		_:  # bastos: a club
			c.draw_line(p + Vector2(-r * 0.6, r), p + Vector2(r * 0.6, -r), col, maxf(3.0, r * 0.45))
			c.draw_circle(p + Vector2(r * 0.6, -r), r * 0.4, col)
