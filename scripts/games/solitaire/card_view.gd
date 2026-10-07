extends Button

signal card_pressed(pile: String, pile_index: int, card_index: int)
## The finger/mouse went down on this card and moved past DRAG_START: the game
## takes over (drag and drop). Taps still go through card_pressed.
signal drag_started(pile: String, pile_index: int, card_index: int)
const DRAG_START := 14.0
var _press_at := Vector2.ZERO
var _pressing := false
var _suppress_press := false

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
## Classic cards (the default since players asked for "normal" colours):
## white faces, red and black suits, blue backs, on green felt.
const CLASSIC_FACE := Color(0.98, 0.97, 0.93)
const CLASSIC_RED := Color(0.8, 0.08, 0.12)
const CLASSIC_BLACK := Color(0.07, 0.07, 0.1)
const CLASSIC_RIM := Color(0.45, 0.45, 0.5)
const CLASSIC_BACK := Color(0.1, 0.24, 0.62)
const CLASSIC_BACK_LINE := Color(0.55, 0.7, 1.0, 0.55)

## Which look every card uses; the game sets it from the player's choice.
static var classic: bool = true
var _face_down := false

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

	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if _suppress_press:  # the release that ended a drag is not a tap
		_suppress_press = false
		return
	card_pressed.emit(pile, pile_index, card_index)

## Only the left button / a finger (a phone sends the mouse copy first).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressing = event.pressed
		_press_at = event.global_position
		if event.pressed:
			_suppress_press = false
	elif event is InputEventMouseMotion and _pressing and event.global_position.distance_to(_press_at) > DRAG_START:
		_pressing = false
		_suppress_press = true
		drag_started.emit(pile, pile_index, card_index)

func show_face_up(card) -> void:
	rank_label.visible = true
	suit_label.visible = true
	rank_label.text = "%s%s" % [card.rank_str(), card.suit_symbol()]
	suit_label.text = card.suit_symbol()
	_face_down = false
	if classic:
		var ink: Color = CLASSIC_RED if card.is_red() else CLASSIC_BLACK
		rank_label.add_theme_color_override("font_color", ink)
		suit_label.add_theme_color_override("font_color", ink)
		_rim = CLASSIC_RIM
		_base_color = CLASSIC_FACE
	else:
		var color: Color = COLOR_RED if card.is_red() else COLOR_BLACK
		rank_label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.25))
		suit_label.add_theme_color_override("font_color", color)
		_rim = color
		_base_color = COLOR_FACE
	_set_style(_base_color, false)
	queue_redraw()

func show_face_down() -> void:
	rank_label.visible = false
	suit_label.visible = false
	_face_down = true
	_rim = Color.WHITE if classic else COLOR_BORDER
	_base_color = CLASSIC_BACK if classic else COLOR_BACK
	_set_style(_base_color, false)
	queue_redraw()

func show_empty_slot() -> void:
	rank_label.visible = false
	suit_label.visible = false
	_face_down = false
	_rim = Color(1, 1, 1, 0.35 if classic else 0.2)
	_base_color = Color(0, 0, 0, 0.18) if classic else Color(1, 1, 1, 0.05)
	_set_style(_base_color, false)
	queue_redraw()

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
	if classic and not selected:
		sb.shadow_color = Color(0, 0, 0, 0.3)  # a plain drop shadow, no glow
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(1, 2)
	else:
		sb.shadow_color = Color(sb.border_color, 0.35 if selected else 0.18)
		sb.shadow_size = 7 if selected else 3
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, sb)

## Voodoo backs: the voodoo doll (the app's own drawing, apps v0.21+).
const VOODOO_PATH := "res://scripts/common/voodoo.gd"
static var _voodoo: Variant = null

## Classic backs get a lattice inside a white frame.
func _draw() -> void:
	if not classic and _face_down:
		if _voodoo == null and ResourceLoader.exists(VOODOO_PATH):
			_voodoo = load(VOODOO_PATH)
		if _voodoo != null:
			_voodoo.draw_doll(self, size / 2.0, minf(size.x, size.y) * 0.8, Color(0.85, 0.75, 0.55), Color(0.12, 0.05, 0.18), COLOR_BORDER)
		return
	if not (classic and _face_down):
		return
	var inner := Rect2(Vector2(7, 7), size - Vector2(14, 14))
	draw_rect(inner, CLASSIC_BACK_LINE, false, 1.5)
	var step := 12.0
	var x := -inner.size.y
	while x < inner.size.x:
		var a := inner.position + Vector2(x, 0)
		var b := a + Vector2(inner.size.y, inner.size.y)
		var c := inner.position + Vector2(x + inner.size.y, 0)
		var d := c + Vector2(-inner.size.y, inner.size.y)
		draw_line(_clip(inner, a, b, true), _clip(inner, a, b, false), CLASSIC_BACK_LINE, 1.0)
		draw_line(_clip(inner, c, d, true), _clip(inner, c, d, false), CLASSIC_BACK_LINE, 1.0)
		x += step

## The start (or end) of segment a-b clipped to rect r (a-b runs at 45°).
func _clip(r: Rect2, a: Vector2, b: Vector2, start: bool) -> Vector2:
	var dir := (b - a).normalized()
	var t0 := 0.0
	var t1 := a.distance_to(b)
	for axis in 2:
		if absf(dir[axis]) < 0.0001:
			continue
		var lo := (r.position[axis] - a[axis]) / dir[axis]
		var hi := (r.end[axis] - a[axis]) / dir[axis]
		t0 = maxf(t0, minf(lo, hi))
		t1 = minf(t1, maxf(lo, hi))
	return a + dir * (t0 if start else maxf(t0, t1))
