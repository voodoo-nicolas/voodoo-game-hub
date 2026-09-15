extends Button

signal cell_pressed(row: int, col: int)

const COLOR_GIVEN := Color(0.92, 0.92, 0.92)
const COLOR_EDITABLE := Color(0.55, 0.8, 1.0)
const COLOR_ERROR := Color(1.0, 0.4, 0.4)
const COLOR_NOTE := Color(0.75, 0.78, 0.88)

var row: int = -1
var col: int = -1
var value: int = 0
var is_given: bool = false
var is_error: bool = false
var notes: Array = [false, false, false, false, false, false, false, false, false]

var value_label: Label
var notes_grid: GridContainer
var note_labels: Array = []

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

	notes_grid = GridContainer.new()
	notes_grid.columns = 3
	notes_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	notes_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(9):
		var l := Label.new()
		l.text = ""
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", max(14, int(cell_size * 0.26)))
		l.add_theme_color_override("font_color", COLOR_NOTE)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		note_labels.append(l)
		notes_grid.add_child(l)
	add_child(notes_grid)

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

func update_display() -> void:
	if value != 0:
		value_label.text = str(value)
		value_label.visible = true
		notes_grid.visible = false
		if is_given:
			value_label.add_theme_color_override("font_color", COLOR_GIVEN)
		elif is_error:
			value_label.add_theme_color_override("font_color", COLOR_ERROR)
		else:
			value_label.add_theme_color_override("font_color", COLOR_EDITABLE)
	else:
		value_label.visible = false
		notes_grid.visible = true
		for i in range(9):
			note_labels[i].text = str(i + 1) if notes[i] else ""

const THIN_LINE := 1
const COLOR_THIN_LINE := Color(0.42, 0.42, 0.5)

func set_background(color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = THIN_LINE
	sb.border_width_top = THIN_LINE
	sb.border_width_right = THIN_LINE
	sb.border_width_bottom = THIN_LINE
	sb.border_color = COLOR_THIN_LINE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, sb)
