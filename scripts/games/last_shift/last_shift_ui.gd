extends RefCounted

## Shared look for panels and buttons: dark ink boxes with an amber edge (comic-book UI).

const INK := Color("0e0e12")
const AMBER := Color("e09a1a")

static func panel_style() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	b.border_color = AMBER
	b.set_border_width_all(3)
	b.set_corner_radius_all(10)
	b.shadow_color = Color(0, 0, 0, 0.5)
	b.shadow_size = 8
	return b

static func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(3)
	b.set_corner_radius_all(9)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b

static func style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _button_box(Color(0.08, 0.08, 0.11, 0.92), Color("5c6670")))
	b.add_theme_stylebox_override("hover", _button_box(Color(0.16, 0.14, 0.1, 0.95), AMBER))
	b.add_theme_stylebox_override("pressed", _button_box(Color(0.3, 0.2, 0.06, 0.95), Color("f2d13a")))
	b.add_theme_stylebox_override("disabled", _button_box(Color(0.06, 0.06, 0.08, 0.7), Color("3a3d44")))
	b.add_theme_stylebox_override("focus", _button_box(Color(0, 0, 0, 0), Color("f2d13a")))
	b.add_theme_color_override("font_color", Color("e8e8f0"))
	b.add_theme_color_override("font_hover_color", Color("ffd479"))
	b.add_theme_color_override("font_pressed_color", Color("ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("6b6e75"))
