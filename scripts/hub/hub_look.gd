extends RefCounted

## Shared look of the Netflix-style Game Browser (Theme-style helpers): every
## label gets a dark outline (size 5) and a soft shadow so it reads over art.
## Colours come from Settings.DARK: this layout is art-first and always dark,
## whatever theme the rest of the hub uses.

const OUTLINE := 5
const OUTLINE_COLOR := Color(0, 0, 0, 0.92)
const SHADOW_COLOR := Color(0, 0, 0, 0.6)
const TILE_SIZE := Vector2(140, 80)
const TILE_RADIUS := 8
const SIDE := 14

static func pal() -> Dictionary:
	return Settings.DARK

## Outline + shadow on a Label / Button, with the given size and colour.
static func text(c: Control, size: int, color: Color = Color.WHITE) -> void:
	c.add_theme_font_size_override("font_size", size)
	c.add_theme_color_override("font_color", color)
	c.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	c.add_theme_constant_override("outline_size", OUTLINE)
	if c is Label:
		c.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
		c.add_theme_constant_override("shadow_offset_x", 1)
		c.add_theme_constant_override("shadow_offset_y", 2)
	if c is Button:
		for k in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			c.add_theme_color_override(k, color)

static func label(txt: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	text(l, size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A button with no background (the text is outlined instead).
static func ghost_button(txt: String, size: int, color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 48
	text(b, size, color)
	return b

## A filled pill button (Play = green, Favourite = glass).
static func pill_button(txt: String, fill: Color, border: Color, size: int = 22) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	text(b, size, Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.shadow_color = Color(border, 0.45)
	sb.shadow_size = 8
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	return b

## Rounded outline drawn over a tile: dim when idle, neon glow when selected.
static func tile_border(selected: bool) -> StyleBoxFlat:
	var p := pal()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(TILE_RADIUS)
	if selected:
		sb.border_color = p.link
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(1, 1, 1, 0.14)
		sb.set_border_width_all(1)
	return sb

## Sits under the tile picture: the neon glow of the selected tile. (A glow drawn on the
## transparent outline would wash over the picture, so this panel is solid and covered.)
static func tile_glow(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 1) if selected else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(TILE_RADIUS)
	if selected:
		sb.shadow_color = Color(pal().link, 0.85)
		sb.shadow_size = 14
	return sb

static func clip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(TILE_RADIUS)
	return sb
