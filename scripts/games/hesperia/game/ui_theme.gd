extends RefCounted
## Shared UI theme (visual pass 2026-11): dark lacquer panels with a bronze rim and drop shadow, flat buttons
## that light up with a gold left bar on hover/focus, styled LineEdit. Built in code (no .tres to keep in sync).

const BRONZE := Color(0.80, 0.60, 0.30)
const GOLD := Color(1.0, 0.86, 0.45)
const INK := Color(0.055, 0.05, 0.08, 0.95)
const TEXT := Color(0.88, 0.85, 0.78)
const DIM := Color(0.48, 0.46, 0.44)

const FONT_PATH := "res://games/hesperia/fonts/Micro5.ttf"
static var _font: Font = null

## Micro 5 (OFL, fonts/OFL_Micro5.txt), pixel-crisp; falls back to the engine font if missing.
## Applied through this game's themes only, so the hub's own UI keeps its font.
static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			var f: FontFile = load(FONT_PATH)
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.hinting = TextServer.HINTING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font = f
		else:
			_font = ThemeDB.fallback_font
	return _font

static func panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.border_color = BRONZE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(6)
	sb.anti_aliasing = false
	return sb

static func _btn_box(bg: Color, bar: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bar
	sb.border_width_left = 2
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.anti_aliasing = false
	return sb

static func build() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.set_stylebox("panel", "PanelContainer", panel_box())
	th.set_stylebox("normal", "Button", _btn_box(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.0)))
	th.set_stylebox("hover", "Button", _btn_box(Color(0.8, 0.6, 0.3, 0.18), GOLD))
	th.set_stylebox("focus", "Button", _btn_box(Color(0.8, 0.6, 0.3, 0.22), GOLD))
	th.set_stylebox("pressed", "Button", _btn_box(Color(0.8, 0.6, 0.3, 0.38), Color(1, 1, 1)))
	th.set_stylebox("disabled", "Button", _btn_box(Color(0.8, 0.6, 0.3, 0.08), BRONZE.darkened(0.3)))
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color(1, 0.97, 0.88))
	th.set_color("font_focus_color", "Button", Color(1, 0.97, 0.88))
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", DIM)
	th.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.6))
	th.set_constant("outline_size", "Button", 0)
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))   # no shadow: it fattens 5px pixel glyphs
	th.set_constant("shadow_offset_y", "Label", 1)
	th.set_constant("shadow_offset_x", "Label", 0)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0, 0, 0, 0.45)
	le.border_color = BRONZE.darkened(0.25)
	le.border_width_bottom = 1
	le.set_content_margin_all(3)
	le.anti_aliasing = false
	th.set_stylebox("normal", "LineEdit", le)
	var lef := le.duplicate() as StyleBoxFlat
	lef.border_color = GOLD
	th.set_stylebox("focus", "LineEdit", lef)
	th.set_color("font_color", "LineEdit", Color(1, 0.97, 0.88))
	th.set_color("font_placeholder_color", "LineEdit", DIM)
	th.set_color("caret_color", "LineEdit", GOLD)
	return th

## Flat title-menu button (S4 Monument: no boxes, selected = white, others 60% grey).
static func flat_button(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", Color(0.7, 0.66, 0.62))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.4, 0.42))
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.9))
	b.add_theme_constant_override("outline_size", 2)
