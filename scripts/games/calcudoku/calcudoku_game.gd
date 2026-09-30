extends Control

## Calcudoku -- tap a cell, then a number. Rows and columns never repeat; each
## outlined cage must make its target with the operation shown.

const CalcEngine = preload("res://scripts/games/calcudoku/calcudoku_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")

const SIZES := [4, 5, 6]
const COLOR_CELL := Color(0.95, 0.95, 0.92)
const COLOR_SELECTED := Color(0.75, 0.88, 1.0)
const COLOR_CAGE_DONE := Color(0.85, 0.95, 0.85)
const COLOR_INK := Color(0.12, 0.12, 0.16)
const COLOR_BAD := Color(0.85, 0.15, 0.15)

var engine: CalcEngine
var board: Control
var pad: HBoxContainer
var size_btn: Button
var win_dialog: ColorRect
var size_index: int = 0
var selected: int = -1
var font: Font

func _ready() -> void:
	preload("res://scripts/games/calcudoku/calcudoku_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = CalcEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🔟 Calcudoku")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	var hint := Label.new()
	hint.text = tr("No repeats in any row or column. Each cage must make its number using its operation.")
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(hint)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	pad = HBoxContainer.new()
	pad.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_theme_constant_override("separation", 10)
	root.add_child(pad)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_child(bottom)
	root.add_child(bm)
	size_btn = Button.new()
	size_btn.custom_minimum_size = Vector2(220, 64)
	size_btn.add_theme_font_size_override("font_size", 26)
	size_btn.pressed.connect(_cycle_size)
	bottom.add_child(size_btn)

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(win_dialog)
	add_child(SettingsDrawer.new())

func _rebuild_pad() -> void:
	for child in pad.get_children():
		child.queue_free()
	for v in range(1, engine.n + 1):
		pad.add_child(_pad_button(str(v), v))
	pad.add_child(_pad_button("⌫", 0))

func _pad_button(text: String, v: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(86, 86)
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_number.bind(v))
	return b

func _cycle_size() -> void:
	size_index = (size_index + 1) % SIZES.size()
	_start_new_game()

func _start_new_game() -> void:
	engine.new_puzzle(SIZES[size_index])
	selected = -1
	win_dialog.visible = false
	size_btn.text = tr("Size: %d×%d") % [engine.n, engine.n]
	_rebuild_pad()
	board.queue_redraw()

func _on_number(v: int) -> void:
	if selected < 0 or win_dialog.visible:
		return
	engine.values[selected] = v
	board.queue_redraw()
	if engine.is_solved():
		win_dialog.get_meta("message_label").text = tr("Every cage adds up.")
		win_dialog.visible = true

# ---------- drawing ----------

func _cell_size() -> float:
	return floor(min(board.size.x - 32.0, board.size.y - 8.0) / engine.n)

func _origin() -> Vector2:
	var s := _cell_size() * engine.n
	return Vector2((board.size.x - s) / 2.0, (board.size.y - s) / 2.0)

func _draw_board() -> void:
	if engine.cages.is_empty():
		return
	var n: int = engine.n
	var cs := _cell_size()
	var o := _origin()
	var bad: Array = engine.conflicts()
	for i in n * n:
		var r := i / n
		var c := i % n
		var rect := Rect2(o + Vector2(c, r) * cs, Vector2(cs, cs))
		var col := COLOR_CELL
		if engine.cage_satisfied(engine.cage_of[i]):
			col = COLOR_CAGE_DONE
		if i == selected:
			col = COLOR_SELECTED
		board.draw_rect(rect, col)
		board.draw_rect(rect, Color(0.7, 0.7, 0.72), false, 1.0)
		var v: int = engine.values[i]
		if v > 0:
			var fs := int(cs * 0.5)
			board.draw_string(font, Vector2(rect.position.x, rect.position.y + cs * 0.62 + fs * 0.3), str(v),
				HORIZONTAL_ALIGNMENT_CENTER, cs, fs, COLOR_BAD if i in bad else COLOR_INK)
	# cage borders: a thick line wherever neighbours belong to different cages
	var thick := 4.0
	for i in n * n:
		var r := i / n
		var c := i % n
		var p := o + Vector2(c, r) * cs
		if c == n - 1 or engine.cage_of[i] != engine.cage_of[i + 1]:
			board.draw_line(p + Vector2(cs, 0), p + Vector2(cs, cs), COLOR_INK, thick)
		if r == n - 1 or engine.cage_of[i] != engine.cage_of[i + n]:
			board.draw_line(p + Vector2(0, cs), p + Vector2(cs, cs), COLOR_INK, thick)
		if c == 0:
			board.draw_line(p, p + Vector2(0, cs), COLOR_INK, thick)
		if r == 0:
			board.draw_line(p, p + Vector2(cs, 0), COLOR_INK, thick)
	for cage in engine.cages:
		var first: int = cage.cells.min()
		var p := o + Vector2(first % n, first / n) * cs
		var label: String = str(cage.target) + cage.op
		var fs := int(cs * 0.22)
		board.draw_string(font, p + Vector2(6, fs + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_INK)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (event.position - _origin()) / _cell_size()
	var c := floori(p.x)
	var r := floori(p.y)
	if r >= 0 and c >= 0 and r < engine.n and c < engine.n:
		selected = r * engine.n + c
		board.queue_redraw()
