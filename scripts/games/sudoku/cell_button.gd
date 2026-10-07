extends Button

signal cell_pressed(row: int, col: int)

const COLOR_GIVEN := Color(0.92, 0.92, 0.92)
const COLOR_EDITABLE := Color(0.55, 0.8, 1.0)
const COLOR_ERROR := Color(1.0, 0.4, 0.4)
const COLOR_NOTE := Color(0.85, 0.88, 0.97)
## A note matching the selected cell's number: a green chip behind it, like
## the same-number cells' green background.
const COLOR_NOTE_MATCH := Color(0.62, 1.0, 0.45)
const COLOR_NOTE_MATCH_BG := Color(0.32, 0.5, 0.18)

var row: int = -1
var col: int = -1
var value: int = 0
var is_given: bool = false
var is_error: bool = false
var notes: Array = [false, false, false, false, false, false, false, false, false]

var value_label: Label
## Classic skin (a printed puzzle): ink givens, blue pencil entries, light
## cell lines. Set by the game's _set_skin, then update_display().
var classic: bool = false
const CLASSIC_GIVEN := Color("1d2433")
const CLASSIC_EDITABLE := Color("1e5bd8")
const CLASSIC_ERROR := Color("d62828")
const CLASSIC_NOTE := Color("5b6478")
const CLASSIC_NOTE_MATCH := Color("1f6b3a")
const CLASSIC_NOTE_MATCH_BG := Color("d5ebcf")
const CLASSIC_THIN_LINE := Color("b8b2a2")
var notes_layer: Control
var note_font_size: int = 18
## The digit whose note stands out (the selected cell's number), 0 = none.
var match_note: int = 0

func setup(r: int, c: int, cell_size: float = 72.0) -> void:
	row = r
	col = c
	custom_minimum_size = Vector2(cell_size, cell_size)
	# flat=true suppresses the idle-state stylebox in Godot, which would hide our
	# background/border overrides while the button isn't hovered or pressed.
	flat = false
	focus_mode = Control.FOCUS_NONE

	value_label = Label.new()
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", int(cell_size * 0.4))
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value_label)

	# Notes are drawn, not a 3x3 grid of Labels: a Label's line height is
	# taller than a third of the cell, so the bottom row (7 8 9) was clipped.
	notes_layer = Control.new()
	notes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	notes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_layer.draw.connect(_draw_notes)
	add_child(notes_layer)
	note_font_size = max(14, int(cell_size * 0.28))

	pressed.connect(func(): cell_pressed.emit(row, col))
	set_background(Color(0.16, 0.16, 0.2))
	update_display()

func set_as_given(v: int) -> void:
	is_given = true
	value = v
	update_display()

func set_value(v: int) -> void:
	if is_given:
		return
	value = v
	is_error = false
	if v != 0:
		for i in range(9):
			notes[i] = false
	update_display()

func clear_value() -> void:
	set_value(0)

func mark_error() -> void:
	is_error = true
	update_display()

func toggle_note(n: int) -> void:
	if is_given or value != 0:
		return
	notes[n - 1] = not notes[n - 1]
	update_display()

func set_match_note(n: int) -> void:
	if n == match_note:
		return
	match_note = n
	if value == 0:
		notes_layer.queue_redraw()

func update_display() -> void:
	if value != 0:
		value_label.text = str(value)
		value_label.visible = true
		notes_layer.visible = false
		if is_given:
			value_label.add_theme_color_override("font_color", CLASSIC_GIVEN if classic else COLOR_GIVEN)
		elif is_error:
			value_label.add_theme_color_override("font_color", CLASSIC_ERROR if classic else COLOR_ERROR)
		else:
			value_label.add_theme_color_override("font_color", CLASSIC_EDITABLE if classic else COLOR_EDITABLE)
	else:
		value_label.visible = false
		notes_layer.visible = true
		notes_layer.queue_redraw()

## Each note centred in its third of the cell: 1 2 3 / 4 5 6 / 7 8 9.
func _draw_notes() -> void:
	var font := get_theme_default_font()
	var s := notes_layer.size
	var third := Vector2(s.x / 3.0, s.y / 3.0)
	var ascent := font.get_ascent(note_font_size)
	var height := font.get_height(note_font_size)
	for i in range(9):
		if not notes[i]:
			continue
		var text := str(i + 1)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, note_font_size).x
		var centre := Vector2((i % 3 + 0.5) * third.x, (int(i / 3) + 0.5) * third.y)
		var pos := Vector2(centre.x - w / 2.0, centre.y - height / 2.0 + ascent)
		if i + 1 == match_note:
			var chip := Rect2(centre - third * 0.46, third * 0.92)
			var m: Color = CLASSIC_NOTE_MATCH if classic else COLOR_NOTE_MATCH
			notes_layer.draw_rect(chip, CLASSIC_NOTE_MATCH_BG if classic else COLOR_NOTE_MATCH_BG)
			notes_layer.draw_rect(chip, m, false, 1.5)
			notes_layer.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, note_font_size, m)
		else:
			notes_layer.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, note_font_size, CLASSIC_NOTE if classic else COLOR_NOTE)

const THIN_LINE := 1
const COLOR_THIN_LINE := Color(0.42, 0.42, 0.5)

func set_background(color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = THIN_LINE
	sb.border_width_top = THIN_LINE
	sb.border_width_right = THIN_LINE
	sb.border_width_bottom = THIN_LINE
	sb.border_color = CLASSIC_THIN_LINE if classic else COLOR_THIN_LINE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, sb)
