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
	b.shadow_color = Color(0, 0, 0, 0.55)
	b.shadow_size = 14
	b.shadow_offset = Vector2(0, 4)
	# v0.6 polish: a thicker amber lip at the top reads as a lit edge (light comes from the top-left)
	b.border_width_top = 4
	b.anti_aliasing = true
	return b

static func _button_box(bg: Color, border: Color, lift: float = 4.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(3)
	# v0.6 polish: comic "chunky" bottom lip + hard drop shadow; pressed buttons sit lower (lift 0)
	b.border_width_bottom = 3 + int(lift * 0.5)
	b.set_corner_radius_all(9)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	b.shadow_color = Color(0, 0, 0, 0.55)
	b.shadow_size = 0 if lift <= 0.0 else 2
	b.shadow_offset = Vector2(0, lift)
	b.anti_aliasing = true
	return b

static func style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _button_box(Color(0.08, 0.08, 0.11, 0.92), Color("5c6670")))
	b.add_theme_stylebox_override("hover", _button_box(Color(0.16, 0.14, 0.1, 0.95), AMBER))
	b.add_theme_stylebox_override("pressed", _button_box(Color(0.3, 0.2, 0.06, 0.95), Color("f2d13a"), 0.0))
	b.add_theme_stylebox_override("disabled", _button_box(Color(0.06, 0.06, 0.08, 0.7), Color("3a3d44")))
	b.add_theme_stylebox_override("focus", _button_box(Color(0, 0, 0, 0), Color("f2d13a")))
	b.add_theme_color_override("font_color", Color("e8e8f0"))
	b.add_theme_color_override("font_hover_color", Color("ffd479"))
	b.add_theme_color_override("font_pressed_color", Color("ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("6b6e75"))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("outline_size", 4)
	add_press_feedback(b)

## v0.6 polish: buttons squash a little when pressed and pop back (pure visual; the press itself
## is untouched). Scales around the centre, so layout containers don't move.
static func add_press_feedback(b: BaseButton) -> void:
	if b.has_meta("ls_press_fx"):
		return
	b.set_meta("ls_press_fx", true)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void: _squash(b, Vector2(0.95, 0.95), 0.06))
	b.button_up.connect(func() -> void: _squash(b, Vector2.ONE, 0.16))

static func _squash(b: BaseButton, to: Vector2, t: float) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	var tw := b.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_BACK if to == Vector2.ONE else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", to, t)
