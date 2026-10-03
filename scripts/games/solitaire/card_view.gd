extends Button

signal card_pressed(pile: String, pile_index: int, card_index: int)

const WIDTH := 84
const HEIGHT := 118

## Neon cards (reference/art/ART_STYLE.md): dark face, glowing rim --
## hearts and diamonds pink, spades and clubs cyan; backs purple.
const COLOR_FACE := Color(0.05, 0.07, 0.15)
const COLOR_BACK := Color(0.16, 0.06, 0.28)
const COLOR_BORDER := Color(0.6, 0.3, 1.0)
const COLOR_SELECTED_BORDER := Color(1.0, 0.68, 0.17)
const COLOR_RED := Color(1.0, 0.31, 0.6)
const COLOR_BLACK := Color(0.16, 0.9, 1.0)

var pile: String = ""
var pile_index: int = -1
var card_index: int = -1

var rank_label: Label
var suit_label: Label
var _base_color: Color = Color(1, 1, 1, 0.05)
var _rim: Color = COLOR_BORDER

func setup(p: String, p_index: int, c_index: int) -> void:
	pile = p
	pile_index = p_index
	card_index = c_index
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	flat = false
	focus_mode = Control.FOCUS_NONE

	rank_label = Label.new()
	rank_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rank_label.position = Vector2(6, 2)
	rank_label.add_theme_font_size_override("font_size", 24)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rank_label)

	suit_label = Label.new()
	suit_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	suit_label.add_theme_font_size_override("font_size", 37)
	suit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(suit_label)

	pressed.connect(func(): card_pressed.emit(pile, pile_index, card_index))

func show_face_up(card) -> void:
	rank_label.visible = true
	suit_label.visible = true
	rank_label.text = "%s%s" % [card.rank_str(), card.suit_symbol()]
	suit_label.text = card.suit_symbol()
	var color: Color = COLOR_RED if card.is_red() else COLOR_BLACK
	rank_label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.25))
	suit_label.add_theme_color_override("font_color", color)
	_rim = color
	_base_color = COLOR_FACE
	_set_style(_base_color, false)

func show_face_down() -> void:
	rank_label.visible = false
	suit_label.visible = false
	_rim = COLOR_BORDER
	_base_color = COLOR_BACK
	_set_style(_base_color, false)

func show_empty_slot() -> void:
	rank_label.visible = false
	suit_label.visible = false
	_rim = Color(1, 1, 1, 0.2)
	_base_color = Color(1, 1, 1, 0.05)
	_set_style(_base_color, false)

func set_selected(selected: bool) -> void:
	_set_style(_base_color, selected)

func _set_style(bg: Color, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 4 if selected else 2
	sb.border_width_top = 4 if selected else 2
	sb.border_width_right = 4 if selected else 2
	sb.border_width_bottom = 4 if selected else 2
	sb.border_color = COLOR_SELECTED_BORDER if selected else _rim
	sb.shadow_color = Color(sb.border_color, 0.35 if selected else 0.18)
	sb.shadow_size = 7 if selected else 3
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, sb)
