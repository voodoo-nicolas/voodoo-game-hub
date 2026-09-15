extends Control

const SudokuGenerator = preload("res://scripts/games/sudoku/sudoku_generator.gd")
const CellButton = preload("res://scripts/games/sudoku/cell_button.gd")
const GridLines = preload("res://scripts/games/sudoku/grid_lines.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const SAVE_PATH := "user://sudoku_save.json"

const DIFFICULTIES := ["easy", "medium", "hard", "expert"]
const DIFFICULTY_MULTIPLIER := {"easy": 1.0, "medium": 1.5, "hard": 2.0, "expert": 3.0}
const CORRECT_CELL_POINTS := 10
const MISTAKE_PENALTY := 5
const TIME_BONUS_CAP_SECONDS := 600
const STARTING_HINTS := 3
const MAX_UNDO_HISTORY := 200

const COLOR_BASE := Color(0.15, 0.15, 0.19)
const COLOR_SELECTED := Color(0.25, 0.5, 0.7)
const COLOR_PEER := Color(0.24, 0.3, 0.36)
const COLOR_SAME_VALUE := Color(0.32, 0.37, 0.22)
const COLOR_ERROR_BG := Color(0.45, 0.15, 0.17)

var puzzle: Array = []
var solution: Array = []
var cells: Array = []  # 9x9 of CellButton
var selected: Vector2i = Vector2i(-1, -1)
var notes_mode: bool = false
var mistakes: int = 0
var score: int = 0
var difficulty: String = "medium"
var elapsed_seconds: float = 0.0
var timer_running: bool = false
var game_active: bool = false
var generation_thread: Thread
var hints_remaining: int = STARTING_HINTS
var move_history: Array = []

var difficulty_screen: Control
var game_screen: Control
var loading_overlay: Control
var win_dialog: Control
var win_stats_label: Label
var pause_dialog: Control
var continue_button: Button

var grid_container: GridContainer
var timer_label: Label
var mistakes_label: Label
var score_label: Label
var difficulty_label: Label
var notes_button: Button
var hint_label: Label
var notes_status_label: Label
var number_buttons: Array = []

func _ready() -> void:
	Orientation.lock_portrait()
	randomize()
	_build_ui()
	_show_difficulty_screen()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _process(delta: float) -> void:
	if timer_running:
		elapsed_seconds += delta
		timer_label.text = _format_time(elapsed_seconds)

func _format_time(s: float) -> String:
	var total := int(s)
	return "%02d:%02d" % [int(total / 60), total % 60]

# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_difficulty_screen()
	_build_game_screen()
	_build_loading_overlay()
	_build_win_dialog()
	_build_pause_dialog()
	add_child(SettingsDrawer.new())

func _build_difficulty_screen() -> void:
	difficulty_screen = CenterContainer.new()
	difficulty_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(difficulty_screen)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	difficulty_screen.add_child(box)

	var title := Label.new()
	title.text = "Sudoku"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a difficulty"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(240, 56)
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.visible = false
	continue_button.pressed.connect(_load_saved_game)
	box.add_child(continue_button)

	for d in DIFFICULTIES:
		var btn := Button.new()
		btn.text = d.capitalize()
		btn.custom_minimum_size = Vector2(240, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func(): _start_new_game(d))
		box.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = "Back to Hub"
	back_btn.custom_minimum_size = Vector2(240, 44)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(back_btn)

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.visible = false
	add_child(game_screen)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	game_screen.add_child(root)

	# top icon row: back/menu on the left, pause on the right
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_right", 12)
	root.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_margin.add_child(top_row)

	var back_btn := Button.new()
	back_btn.text = "‹"
	back_btn.add_theme_font_size_override("font_size", 26)
	back_btn.custom_minimum_size = Vector2(44, 44)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_on_pause_pressed)
	top_row.add_child(back_btn)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	var pause_icon_btn := Button.new()
	pause_icon_btn.text = "⏸"
	pause_icon_btn.add_theme_font_size_override("font_size", 20)
	pause_icon_btn.custom_minimum_size = Vector2(44, 44)
	pause_icon_btn.focus_mode = Control.FOCUS_NONE
	pause_icon_btn.pressed.connect(_on_pause_pressed)
	top_row.add_child(pause_icon_btn)

	# stats row: Time / Difficulty / Score / Mistakes
	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 16)
	stats_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(stats_margin)

	var stats_row := HBoxContainer.new()
	stats_margin.add_child(stats_row)

	var time_block := _stat_block("Time")
	timer_label = time_block.value_label
	timer_label.text = "00:00"
	stats_row.add_child(time_block.box)

	var diff_block := _stat_block("Difficulty")
	difficulty_label = diff_block.value_label
	difficulty_label.text = "Medium"
	stats_row.add_child(diff_block.box)

	var score_block := _stat_block("Score")
	score_label = score_block.value_label
	score_label.text = "0"
	stats_row.add_child(score_block.box)

	var mistakes_block := _stat_block("Mistakes")
	mistakes_label = mistakes_block.value_label
	mistakes_label.text = "0"
	stats_row.add_child(mistakes_block.box)

	# board -- sized to nearly fill the screen width, edge to edge
	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board_center)

	var viewport_width: float = get_viewport_rect().size.x
	var board_margin := 8.0
	var separation := 2.0
	var cell_size: float = floor((viewport_width - board_margin * 2.0 - separation * 8.0) / 9.0)
	var board_size: float = cell_size * 9.0 + separation * 8.0

	var board_wrap := Control.new()
	board_wrap.custom_minimum_size = Vector2(board_size, board_size)
	board_center.add_child(board_wrap)

	grid_container = GridContainer.new()
	grid_container.columns = 9
	grid_container.add_theme_constant_override("h_separation", int(separation))
	grid_container.add_theme_constant_override("v_separation", int(separation))
	board_wrap.add_child(grid_container)

	var grid_lines := GridLines.new()
	grid_lines.setup(cell_size, separation)
	grid_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_wrap.add_child(grid_lines)

	for r in range(9):
		var row: Array = []
		for c in range(9):
			var cell := CellButton.new()
			cell.setup(r, c, cell_size)
			cell.cell_pressed.connect(_on_cell_pressed)
			grid_container.add_child(cell)
			row.append(cell)
		cells.append(row)

	# icon action row: Undo / Erase / Notes / Hint
	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 12)
	controls_margin.add_theme_constant_override("margin_right", 12)
	controls_margin.add_theme_constant_override("margin_top", 4)
	root.add_child(controls_margin)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	controls_margin.add_child(controls)

	var undo_action := _icon_action_button("↺", "Undo")
	undo_action.button.pressed.connect(_on_undo_pressed)
	controls.add_child(undo_action.control)

	var erase_action := _icon_action_button("⌫", "Erase")
	erase_action.button.pressed.connect(_on_erase_pressed)
	controls.add_child(erase_action.control)

	var notes_action := _icon_action_button("✎", "Notes: Off")
	notes_button = notes_action.button
	notes_button.toggle_mode = true
	notes_status_label = notes_action.text_label
	notes_button.pressed.connect(_on_notes_toggled)
	controls.add_child(notes_action.control)

	var hint_action := _icon_action_button("💡", "Hint: %d" % hints_remaining)
	hint_label = hint_action.text_label
	hint_action.button.pressed.connect(_on_hint_pressed)
	controls.add_child(hint_action.control)

	# number pad, with a checkmark replacing any digit once all 9 are correctly placed
	var pad_margin := MarginContainer.new()
	pad_margin.add_theme_constant_override("margin_left", 16)
	pad_margin.add_theme_constant_override("margin_right", 16)
	pad_margin.add_theme_constant_override("margin_bottom", 20)
	root.add_child(pad_margin)

	var pad := GridContainer.new()
	pad.columns = 9
	pad.add_theme_constant_override("h_separation", 4)
	pad_margin.add_child(pad)

	number_buttons = []
	for n in range(1, 10):
		var nb := Button.new()
		nb.text = str(n)
		nb.custom_minimum_size = Vector2(0, 68)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.focus_mode = Control.FOCUS_NONE
		nb.add_theme_font_size_override("font_size", 28)
		_style_number_button(nb)
		nb.pressed.connect(_on_number_pressed.bind(n))
		pad.add_child(nb)
		number_buttons.append(nb)

func _style_number_button(nb: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.18, 0.24)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.45, 0.55)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	var sb_disabled := sb.duplicate()
	sb_disabled.bg_color = Color(0.1, 0.16, 0.11)
	sb_disabled.border_color = Color(0.3, 0.5, 0.35)
	for state in ["normal", "hover", "pressed", "focus"]:
		nb.add_theme_stylebox_override(state, sb)
	nb.add_theme_stylebox_override("disabled", sb_disabled)
	nb.add_theme_color_override("font_color", Color(1, 1, 1))
	nb.add_theme_color_override("font_disabled_color", Color(0.5, 0.9, 0.6))

func _stat_block(header: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header_label := Label.new()
	header_label.text = header
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header_label)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", Color(1, 1, 1))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_label)

	return {"box": box, "value_label": value_label}

## Icon on top, small status label below, with an invisible full-rect button for input.
func _icon_action_button(icon: String, label_text: String) -> Dictionary:
	var control := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	control.add_theme_stylebox_override("panel", sb)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	control.add_child(box)

	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(icon_label)

	var text_label := Label.new()
	text_label.text = label_text
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text_label)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	control.add_child(button)

	return {"control": control, "icon_label": icon_label, "text_label": text_label, "button": button}

func _build_loading_overlay() -> void:
	loading_overlay = ColorRect.new()
	loading_overlay.color = Color(0.05, 0.05, 0.08, 0.9)
	loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_overlay.visible = false
	add_child(loading_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_overlay.add_child(center)

	var label := Label.new()
	label.text = "Generating puzzle..."
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	center.add_child(label)

func _build_win_dialog() -> void:
	win_dialog = ColorRect.new()
	win_dialog.color = Color(0, 0, 0, 0.75)
	win_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.visible = false
	add_child(win_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_dialog.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Puzzle Solved!"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	win_stats_label = Label.new()
	win_stats_label.add_theme_font_size_override("font_size", 16)
	win_stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	win_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_stats_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game(difficulty)
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Choose Difficulty"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func():
		win_dialog.visible = false
		_show_difficulty_screen()
	)
	box.add_child(menu_btn)

func _build_pause_dialog() -> void:
	pause_dialog = ColorRect.new()
	pause_dialog.color = Color(0, 0, 0, 0.75)
	pause_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dialog.visible = false
	add_child(pause_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dialog.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.18)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(220, 48)
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)

	var new_puzzle_btn := Button.new()
	new_puzzle_btn.text = "New Puzzle (Same Difficulty)"
	new_puzzle_btn.custom_minimum_size = Vector2(220, 44)
	new_puzzle_btn.pressed.connect(func():
		pause_dialog.visible = false
		game_active = false
		SaveUtil.delete(SAVE_PATH)
		_start_new_game(difficulty)
	)
	box.add_child(new_puzzle_btn)

	var change_diff_btn := Button.new()
	change_diff_btn.text = "Change Difficulty"
	change_diff_btn.custom_minimum_size = Vector2(220, 44)
	change_diff_btn.pressed.connect(func():
		pause_dialog.visible = false
		game_active = false
		SaveUtil.delete(SAVE_PATH)
		_show_difficulty_screen()
	)
	box.add_child(change_diff_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit to Hub"
	exit_btn.custom_minimum_size = Vector2(220, 44)
	exit_btn.pressed.connect(func():
		_save_game()
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
	)
	box.add_child(exit_btn)

# ---------- screen state ----------

func _show_difficulty_screen() -> void:
	timer_running = false
	game_active = false
	difficulty_screen.visible = true
	game_screen.visible = false
	win_dialog.visible = false
	pause_dialog.visible = false
	_refresh_continue_button()

func _show_game_screen() -> void:
	difficulty_screen.visible = false
	game_screen.visible = true

# ---------- game flow ----------

func _start_new_game(d: String) -> void:
	difficulty = d
	loading_overlay.visible = true
	difficulty_screen.visible = false
	game_screen.visible = false

	generation_thread = Thread.new()
	generation_thread.start(_generate_worker.bind(d))

func _generate_worker(d: String) -> void:
	var result := SudokuGenerator.generate_puzzle(d)
	call_deferred("_on_generation_complete", result)

func _on_generation_complete(result: Dictionary) -> void:
	generation_thread.wait_to_finish()
	puzzle = result.puzzle
	solution = result.solution
	mistakes = 0
	score = 0
	elapsed_seconds = 0.0
	hints_remaining = STARTING_HINTS
	move_history = []
	selected = Vector2i(-1, -1)
	notes_mode = false
	notes_status_label.text = "Notes: Off"
	notes_button.button_pressed = false

	_populate_board()
	difficulty_label.text = difficulty.capitalize()
	_update_status_bar()

	loading_overlay.visible = false
	_show_game_screen()
	timer_running = true
	game_active = true

func _populate_board() -> void:
	for r in range(9):
		for c in range(9):
			var cell: CellButton = cells[r][c]
			cell.is_given = false
			cell.value = 0
			cell.is_error = false
			for i in range(9):
				cell.notes[i] = false
			var v: int = puzzle[r][c]
			if v != 0:
				cell.set_as_given(v)
			else:
				cell.update_display()
	_refresh_highlights()
	_update_number_pad()

func _on_cell_pressed(r: int, c: int) -> void:
	selected = Vector2i(r, c)
	_refresh_highlights()

func _on_number_pressed(n: int) -> void:
	if selected.x < 0:
		return
	var cell: CellButton = cells[selected.x][selected.y]
	if cell.is_given:
		return
	if notes_mode:
		_record_undo(selected.x, selected.y)
		cell.toggle_note(n)
	else:
		_place_number(selected.x, selected.y, n)
	_refresh_highlights()

func _place_number(r: int, c: int, n: int) -> void:
	var cell: CellButton = cells[r][c]
	if cell.value == n:
		return
	_record_undo(r, c)
	var was_correct_before: bool = cell.value != 0 and cell.value == solution[r][c]
	cell.set_value(n)

	if n == solution[r][c]:
		if not was_correct_before:
			score += CORRECT_CELL_POINTS
		_update_number_pad()
		_check_win()
	else:
		cell.mark_error()
		mistakes += 1
		score = max(0, score - MISTAKE_PENALTY)

	_update_status_bar()

func _on_erase_pressed() -> void:
	if selected.x < 0:
		return
	var cell: CellButton = cells[selected.x][selected.y]
	if cell.is_given:
		return
	_record_undo(selected.x, selected.y)
	cell.clear_value()
	_refresh_highlights()
	_update_number_pad()

func _on_notes_toggled() -> void:
	notes_mode = notes_button.button_pressed
	notes_status_label.text = "Notes: On" if notes_mode else "Notes: Off"

func _on_pause_pressed() -> void:
	if not game_active:
		return
	timer_running = false
	_save_game()
	pause_dialog.visible = true

func _on_resume_pressed() -> void:
	pause_dialog.visible = false
	timer_running = true

## Snapshots a cell's full state plus current score/mistakes before a mutating action,
## so _on_undo_pressed can restore everything in one step regardless of what changed.
func _record_undo(r: int, c: int) -> void:
	var cell: CellButton = cells[r][c]
	move_history.append({
		"row": r, "col": c,
		"value": cell.value,
		"notes": cell.notes.duplicate(),
		"is_error": cell.is_error,
		"score": score,
		"mistakes": mistakes,
	})
	if move_history.size() > MAX_UNDO_HISTORY:
		move_history.pop_front()

func _on_undo_pressed() -> void:
	if not game_active or move_history.is_empty():
		return
	var snap: Dictionary = move_history.pop_back()
	var cell: CellButton = cells[snap.row][snap.col]
	cell.value = snap.value
	cell.notes = snap.notes.duplicate()
	cell.is_error = snap.is_error
	cell.update_display()
	score = snap.score
	mistakes = snap.mistakes
	selected = Vector2i(snap.row, snap.col)
	_update_status_bar()
	_refresh_highlights()
	_update_number_pad()

func _on_hint_pressed() -> void:
	if not game_active or hints_remaining <= 0 or selected.x < 0:
		return
	var cell: CellButton = cells[selected.x][selected.y]
	var correct: int = solution[selected.x][selected.y]
	if cell.is_given or cell.value == correct:
		return
	_record_undo(selected.x, selected.y)
	cell.set_value(correct)
	cell.is_error = false
	cell.update_display()
	hints_remaining -= 1
	hint_label.text = "Hint: %d" % hints_remaining
	_update_status_bar()
	_refresh_highlights()
	_update_number_pad()
	_check_win()

## Digit n gets a checkmark in the number pad once all 9 correct instances are placed.
func _digit_complete(n: int) -> bool:
	var count := 0
	for r in range(9):
		for c in range(9):
			if cells[r][c].value == n and n == solution[r][c]:
				count += 1
	return count >= 9

func _update_number_pad() -> void:
	for n in range(1, 10):
		var btn: Button = number_buttons[n - 1]
		if _digit_complete(n):
			btn.text = "✓"
			btn.disabled = true
		else:
			btn.text = str(n)
			btn.disabled = false

func _check_win() -> void:
	for r in range(9):
		for c in range(9):
			var cell: CellButton = cells[r][c]
			if cell.value != solution[r][c]:
				return
	timer_running = false
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	var final_score := _compute_final_score()
	win_stats_label.text = "Time: %s   Mistakes: %d\nFinal Score: %d" % [_format_time(elapsed_seconds), mistakes, final_score]
	win_dialog.visible = true

func _compute_final_score() -> int:
	var multiplier: float = DIFFICULTY_MULTIPLIER.get(difficulty, 1.0)
	var time_bonus: int = max(0, TIME_BONUS_CAP_SECONDS - int(elapsed_seconds))
	return int(round((score + time_bonus) * multiplier))

func _update_status_bar() -> void:
	mistakes_label.text = "%d" % mistakes
	score_label.text = "%d" % score

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	var values := []
	var notes_data := []
	for r in range(9):
		for c in range(9):
			var cell: CellButton = cells[r][c]
			values.append(cell.value)
			notes_data.append(cell.notes.duplicate())

	SaveUtil.write(SAVE_PATH, {
		"puzzle": puzzle,
		"solution": solution,
		"values": values,
		"notes": notes_data,
		"mistakes": mistakes,
		"score": score,
		"elapsed_seconds": elapsed_seconds,
		"difficulty": difficulty,
		"hints_remaining": hints_remaining,
	})

func _refresh_continue_button() -> void:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		continue_button.visible = false
		return
	continue_button.visible = true
	continue_button.text = "Continue (%s - %s)" % [str(data.get("difficulty", "medium")).capitalize(), _format_time(float(data.get("elapsed_seconds", 0.0)))]

func _load_saved_game() -> void:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return

	puzzle = _to_int_grid(data.puzzle)
	solution = _to_int_grid(data.solution)
	difficulty = str(data.difficulty)
	mistakes = int(data.mistakes)
	score = int(data.score)
	elapsed_seconds = float(data.elapsed_seconds)
	hints_remaining = int(data.get("hints_remaining", STARTING_HINTS))
	move_history = []
	selected = Vector2i(-1, -1)
	notes_mode = false
	notes_status_label.text = "Notes: Off"
	notes_button.button_pressed = false
	hint_label.text = "Hint: %d" % hints_remaining

	var values: Array = data.values
	var notes_data: Array = data.notes

	for r in range(9):
		for c in range(9):
			var idx: int = r * 9 + c
			var cell: CellButton = cells[r][c]
			cell.is_given = false
			cell.is_error = false
			cell.value = 0
			for i in range(9):
				cell.notes[i] = false

			var given_v: int = puzzle[r][c]
			if given_v != 0:
				cell.set_as_given(given_v)
			else:
				var v: int = int(values[idx])
				cell.value = v
				var stored_notes: Array = notes_data[idx]
				for i in range(9):
					cell.notes[i] = bool(stored_notes[i])
				if v != 0 and v != solution[r][c]:
					cell.is_error = true
				cell.update_display()

	difficulty_label.text = difficulty.capitalize()
	_update_status_bar()
	_refresh_highlights()
	_update_number_pad()
	game_active = true
	difficulty_screen.visible = false
	_show_game_screen()
	timer_running = true

func _to_int_grid(arr: Array) -> Array:
	var out := []
	for row in arr:
		var r := []
		for v in row:
			r.append(int(v))
		out.append(r)
	return out

# ---------- highlighting ----------

func _refresh_highlights() -> void:
	for r in range(9):
		for c in range(9):
			cells[r][c].set_background(COLOR_BASE)

	if selected.x >= 0:
		var sel_value: int = cells[selected.x][selected.y].value
		var sbr := int(selected.x / 3) * 3
		var sbc := int(selected.y / 3) * 3

		for r in range(9):
			for c in range(9):
				var is_peer: bool = r == selected.x or c == selected.y or (int(r / 3) * 3 == sbr and int(c / 3) * 3 == sbc)
				if is_peer:
					cells[r][c].set_background(COLOR_PEER)
				if sel_value != 0 and cells[r][c].value == sel_value:
					cells[r][c].set_background(COLOR_SAME_VALUE)

		cells[selected.x][selected.y].set_background(COLOR_SELECTED)

	# errors always win, so a mistake stays visible even under peer/selection highlighting
	for r in range(9):
		for c in range(9):
			if cells[r][c].is_error:
				cells[r][c].set_background(COLOR_ERROR_BG)
