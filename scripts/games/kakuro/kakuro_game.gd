extends Control

## Kakuro -- tap a white cell, then a digit. Each run of white cells must add
## up to the clue at its start (→ across, ↓ down) without repeating a digit.

const KakuroEngine = preload("res://scripts/games/kakuro/kakuro_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")

const SIZES := [6, 8]
const COLOR_BLACK := Color(0.2, 0.2, 0.26)
const COLOR_CELL := Color(0.95, 0.95, 0.92)
const COLOR_RUN := Color(0.86, 0.92, 1.0)
const COLOR_SELECTED := Color(0.7, 0.84, 1.0)
const COLOR_INK := Color(0.12, 0.12, 0.16)
const COLOR_BAD := Color(0.85, 0.15, 0.15)

var engine: KakuroEngine
var board: Control
var size_btn: Button
var win_dialog: ColorRect
var size_index: int = 0
var selected: int = -1
var font: Font

func _ready() -> void:
	preload("res://scripts/games/kakuro/kakuro_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = KakuroEngine.new()
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
	root.add_theme_constant_override("separation", 12)
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
	title.text = tr("➗ Kakuro")
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
	hint.text = tr("Each run adds up to its clue (top-right → across, bottom-left ↓ down). No repeats in a run.")
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

	var pad := GridContainer.new()
	pad.columns = 5
	pad.add_theme_constant_override("h_separation", 10)
	pad.add_theme_constant_override("v_separation", 10)
	var pc := CenterContainer.new()
	pc.add_child(pad)
	root.add_child(pc)
	for v in range(1, 10):
		pad.add_child(_pad_button(str(v), v))
	pad.add_child(_pad_button("⌫", 0))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 30)
	bm.add_child(bottom)
	root.add_child(bm)
	size_btn = Button.new()
	size_btn.custom_minimum_size = Vector2(220, 60)
	size_btn.add_theme_font_size_override("font_size", 26)
	size_btn.pressed.connect(_cycle_size)
	bottom.add_child(size_btn)

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(win_dialog)
	add_child(SettingsDrawer.new())

func _pad_button(text: String, v: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 76)
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
	size_btn.text = tr("Small") if size_index == 0 else tr("Large")
	board.queue_redraw()

func _on_number(v: int) -> void:
	if selected < 0 or win_dialog.visible:
		return
	engine.values[selected] = v
	board.queue_redraw()
	if engine.is_solved():
		win_dialog.get_meta("message_label").text = tr("Every sum checks out.")
		win_dialog.visible = true

# ---------- drawing ----------

func _cell_size() -> float:
	return floor(min(board.size.x - 24.0, board.size.y - 8.0) / engine.size)

func _origin() -> Vector2:
	var s := _cell_size() * engine.size
	return Vector2((board.size.x - s) / 2.0, (board.size.y - s) / 2.0)

func _draw_board() -> void:
	if engine.white.is_empty():
		return
	var n: int = engine.size
	var cs := _cell_size()
	var o := _origin()
	var bad: Array = engine.conflicts()
	var run_cells: Array = []
	if selected >= 0:
		for ri in engine.cell_runs[selected]:
			if ri >= 0:
				run_cells.append_array(engine.runs[ri].cells)
	for i in n * n:
		var rect := Rect2(o + Vector2(i % n, i / n) * cs, Vector2(cs, cs)).grow(-1)
		if not engine.white[i]:
			board.draw_rect(rect, COLOR_BLACK)
			continue
		var col := COLOR_CELL
		if i == selected:
			col = COLOR_SELECTED
		elif i in run_cells:
			col = COLOR_RUN
		board.draw_rect(rect, col)
		var v: int = engine.values[i]
		if v > 0:
			var fs := int(cs * 0.55)
			board.draw_string(font, Vector2(rect.position.x, rect.position.y + cs * 0.5 + fs * 0.36), str(v),
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, COLOR_BAD if i in bad else COLOR_INK)
	var cfs := int(cs * 0.28)
	for ri in engine.runs.size():
		var run: Dictionary = engine.runs[ri]
		var cc: int = run.clue_cell
		var p := o + Vector2(cc % n, cc / n) * cs
		board.draw_line(p + Vector2(2, 2), p + Vector2(cs - 2, cs - 2), Color(0.45, 0.45, 0.52), 1.5)
		var done: bool = engine.run_complete_ok(ri)
		var tc := Color(0.5, 0.8, 0.5) if done else Color(1, 1, 1)
		if run.across:
			board.draw_string(font, p + Vector2(cs * 0.5, cs * 0.42), str(run.sum), HORIZONTAL_ALIGNMENT_CENTER, cs * 0.5, cfs, tc)
		else:
			board.draw_string(font, p + Vector2(0, cs * 0.9), str(run.sum), HORIZONTAL_ALIGNMENT_CENTER, cs * 0.5, cfs, tc)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (event.position - _origin()) / _cell_size()
	var c := floori(p.x)
	var r := floori(p.y)
	var n: int = engine.size
	if r >= 0 and c >= 0 and r < n and c < n and engine.white[r * n + c]:
		selected = r * n + c
		board.queue_redraw()
