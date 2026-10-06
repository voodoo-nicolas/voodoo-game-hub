extends Control

const SudokuGenerator = preload("res://scripts/games/sudoku/sudoku_generator.gd")
const CellButton = preload("res://scripts/games/sudoku/cell_button.gd")
const GridLines = preload("res://scripts/games/sudoku/grid_lines.gd")
const SudokuHome = preload("res://scripts/games/sudoku/sudoku_home.gd")
const SudokuHints = preload("res://scripts/games/sudoku/sudoku_hints.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

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
const COLOR_HINT_AREA := Color(0.36, 0.24, 0.44)
const COLOR_HINT_TARGET := Color(0.62, 0.48, 0.12)

var info = null  # GameInfo; null on apps without it, so guard every use
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
## Cells (r * 9 + c) that have already paid out CORRECT_CELL_POINTS, or were
## filled by a hint. Without this, erase + re-place farmed unlimited points.
var scored_cells: Dictionary = {}
## Teaching hints (sudoku_hints.gd): the step on screen (empty = none), how
## far it has been explained (1 = where to look, 2 = why), and the
## candidates earlier hints crossed out ("idx:d"), so the next one builds on them.
var current_hint: Dictionary = {}
var hint_step: int = 0
var hint_elim: Dictionary = {}
var hint_panel: PanelContainer
var hint_box: Control
var stats_box: Control
var hint_text: Label

var difficulty_screen: Control
var game_screen: Control
var loading_overlay: Control
var win_dialog: Control
var win_stats_label: Label
var pause_dialog: Control
var pause_note: Label
var stats_overlay: Control
var stats_grid: GridContainer

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
	preload("res://scripts/games/sudoku/sudoku_i18n.gd").install(self)
	Orientation.lock_portrait()
	randomize()
	_build_ui()
	_show_difficulty_screen()

## Leaving mid-generation (settings drawer -> Hub) would destroy a Thread
## that's still running, which Godot treats as an error and can crash on.
## Waiting here blocks for at most one generation.
func _exit_tree() -> void:
	if generation_thread and generation_thread.is_started():
		generation_thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _process(delta: float) -> void:
	if timer_running:
		elapsed_seconds += delta
		timer_label.text = _format_time(elapsed_seconds)

## A keyboard works too (PC, or a phone with one): 1-9 / numpad place a
## number, arrows move the selection, Backspace / Delete / 0 erase, N toggles
## notes, Ctrl+Z undoes.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or get_tree().paused:
		return
	if not game_screen.visible or pause_dialog.visible or win_dialog.visible or cells.is_empty():
		return
	var code := k.physical_keycode
	var digit := -1
	if code >= KEY_0 and code <= KEY_9:
		digit = code - KEY_0
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		digit = code - KEY_KP_0
	var handled := true
	if k.ctrl_pressed and code == KEY_Z:
		_on_undo_pressed()
	elif digit > 0 and not k.echo:
		if selected.x < 0:
			selected = Vector2i(0, 0)
		_on_number_pressed(digit)
	elif digit == 0 or code == KEY_BACKSPACE or code == KEY_DELETE:
		_on_erase_pressed()
	elif code == KEY_N and not k.echo:
		notes_button.button_pressed = not notes_button.button_pressed
		_on_notes_toggled()
	elif code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]:
		var d := Vector2i.ZERO
		match code:
			KEY_UP, KEY_W: d = Vector2i(-1, 0)
			KEY_DOWN, KEY_S: d = Vector2i(1, 0)
			KEY_LEFT, KEY_A: d = Vector2i(0, -1)
			_: d = Vector2i(0, 1)
		if selected.x < 0:
			selected = Vector2i(4, 4)
		else:
			selected = Vector2i(posmod(selected.x + d.x, 9), posmod(selected.y + d.y, 9))
		_refresh_highlights()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

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

	_build_game_screen()
	_build_loading_overlay()
	_build_win_dialog()
	_build_pause_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/sudoku/sudoku_help.gd"))
	# Home sits under the dialogs and GameInfo's own card (first-play How to Play).
	_build_home()
	if info:
		add_child(info)
		_migrate_level_stats()
		_build_stats_overlay()
	# No floating SettingsDrawer (retired, STANDARDS §6): its items are in the
	# pause menu and Home's ⚙ Options -- nor GameInfo's "?" tab, which it adds
	# when there's no drawer (How to Play is on Home and in the pause menu).
	call_deferred("_drop_info_tab")

## The Home screen (sudoku_home.gd); `difficulty_screen` is its old name.
func _build_home() -> void:
	difficulty_screen = SudokuHome.new()
	difficulty_screen.setup(DIFFICULTIES, info)
	difficulty_screen.play.connect(_start_new_game)
	difficulty_screen.resume.connect(_load_saved_game)
	difficulty_screen.stats_requested.connect(_show_stats)
	difficulty_screen.hub_requested.connect(_on_home_hub)
	add_child(difficulty_screen)

func _on_home_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.visible = false
	add_child(game_screen)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	game_screen.add_child(root)

	# Top and bottom sections each get a share of whatever vertical space is left
	# over after the (fixed-size, width-constrained) board -- on a tall/narrow
	# phone "expand" stretch reveals extra vertical room, and without this it all
	# pools as one big empty gap around the board instead of being shared out.
	var top_section := VBoxContainer.new()
	top_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_section.size_flags_stretch_ratio = 0.5
	top_section.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top_section)

	# top icon row: back/menu on the left, pause on the right
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_section.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_margin.add_child(top_row)

	var back_btn := Button.new()
	back_btn.text = "‹"
	back_btn.add_theme_font_size_override("font_size", 39)
	back_btn.custom_minimum_size = Vector2(56, 56)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_on_pause_pressed)
	top_row.add_child(back_btn)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	var pause_icon_btn := Button.new()
	pause_icon_btn.text = "⏸"
	pause_icon_btn.add_theme_font_size_override("font_size", 33)
	pause_icon_btn.custom_minimum_size = Vector2(56, 56)
	pause_icon_btn.focus_mode = Control.FOCUS_NONE
	pause_icon_btn.pressed.connect(_on_pause_pressed)
	top_row.add_child(pause_icon_btn)

	# stats row: Time / Difficulty / Score / Mistakes
	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 16)
	stats_margin.add_theme_constant_override("margin_right", 16)
	stats_margin.add_theme_constant_override("margin_top", 12)
	top_section.add_child(stats_margin)

	var stats_row := HBoxContainer.new()
	stats_margin.add_child(stats_row)
	stats_box = stats_margin
	# A hint's text takes the stats row's place while it shows, so the
	# board and number pad never move.
	_build_hint_panel(top_section)

	var time_block := _stat_block(tr("Time"))
	timer_label = time_block.value_label
	timer_label.text = "00:00"
	stats_row.add_child(time_block.box)

	var diff_block := _stat_block(tr("Difficulty"))
	difficulty_label = diff_block.value_label
	difficulty_label.text = tr("Medium")
	stats_row.add_child(diff_block.box)

	var score_block := _stat_block(tr("Score"))
	score_label = score_block.value_label
	score_label.text = "0"
	stats_row.add_child(score_block.box)

	var mistakes_block := _stat_block(tr("Mistakes"))
	mistakes_label = mistakes_block.value_label
	mistakes_label.text = "0"
	stats_row.add_child(mistakes_block.box)

	# board -- sized to nearly fill the screen width, edge to edge
	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_center.size_flags_stretch_ratio = 1.5
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

	# Bottom section (icon actions + number pad) gets its own share of leftover
	# vertical space too -- see top_section above for why this matters.
	var bottom_section := VBoxContainer.new()
	bottom_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_section.size_flags_stretch_ratio = 0.7
	bottom_section.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_section.add_theme_constant_override("separation", 14)
	root.add_child(bottom_section)

	# icon action row: Undo / Erase / Notes / Hint
	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 12)
	controls_margin.add_theme_constant_override("margin_right", 12)
	controls_margin.add_theme_constant_override("margin_top", 4)
	bottom_section.add_child(controls_margin)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	controls_margin.add_child(controls)

	var undo_action := _icon_action_button("↺", tr("Undo"))
	undo_action.button.pressed.connect(_on_undo_pressed)
	controls.add_child(undo_action.control)

	var erase_action := _icon_action_button("⌫", tr("Erase"))
	erase_action.button.pressed.connect(_on_erase_pressed)
	controls.add_child(erase_action.control)

	var notes_action := _icon_action_button("✎", tr("Notes: Off"))
	notes_button = notes_action.button
	notes_button.toggle_mode = true
	notes_status_label = notes_action.text_label
	notes_button.pressed.connect(_on_notes_toggled)
	controls.add_child(notes_action.control)

	var hint_action := _icon_action_button("💡", tr("Hint: %d") % hints_remaining)
	hint_label = hint_action.text_label
	hint_action.button.pressed.connect(_on_hint_pressed)
	controls.add_child(hint_action.control)

	# number pad, with a checkmark replacing any digit once all 9 are correctly placed
	var pad_margin := MarginContainer.new()
	pad_margin.add_theme_constant_override("margin_left", 16)
	pad_margin.add_theme_constant_override("margin_right", 16)
	pad_margin.add_theme_constant_override("margin_bottom", 20)
	bottom_section.add_child(pad_margin)

	var pad := GridContainer.new()
	pad.columns = 9
	pad.add_theme_constant_override("h_separation", 4)
	pad_margin.add_child(pad)

	number_buttons = []
	for n in range(1, 10):
		var nb := Button.new()
		nb.text = str(n)
		nb.custom_minimum_size = Vector2(0, 80)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.focus_mode = Control.FOCUS_NONE
		nb.add_theme_font_size_override("font_size", 41)
		_style_number_button(nb)
		nb.pressed.connect(_on_number_pressed.bind(n))
		pad.add_child(nb)
		number_buttons.append(nb)

## The hint's explanation, in the stats row's place; hidden until 💡 is tapped.
## Tapping it closes it.
func _build_hint_panel(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.visible = false
	parent.add_child(margin)
	hint_box = margin
	hint_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.17)
	sb.border_color = Color(0.95, 0.75, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	hint_panel.add_theme_stylebox_override("panel", sb)
	hint_panel.gui_input.connect(_on_hint_panel_input)
	margin.add_child(hint_panel)
	hint_text = Label.new()
	hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_text.add_theme_font_size_override("font_size", 22)
	hint_text.add_theme_color_override("font_color", Color(0.98, 0.92, 0.75))
	hint_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(hint_text)

func _on_hint_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_clear_hint()

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
	header_label.add_theme_font_size_override("font_size", 21)
	header_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header_label)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 33)
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
	icon_label.add_theme_font_size_override("font_size", 39)
	icon_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(icon_label)

	var text_label := Label.new()
	text_label.text = label_text
	text_label.add_theme_font_size_override("font_size", 21)
	text_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
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
	label.text = tr("Generating puzzle...")
	label.add_theme_font_size_override("font_size", 31)
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
	title.text = tr("Puzzle Solved!")
	title.add_theme_font_size_override("font_size", 41)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	win_stats_label = Label.new()
	win_stats_label.add_theme_font_size_override("font_size", 28)
	win_stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	win_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_stats_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(220, 56)
	again_btn.add_theme_font_size_override("font_size", 28)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game(difficulty)
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 Sudoku Home")
	menu_btn.custom_minimum_size = Vector2(220, 50)
	menu_btn.add_theme_font_size_override("font_size", 25)
	menu_btn.pressed.connect(func():
		win_dialog.visible = false
		_show_difficulty_screen()
	)
	box.add_child(menu_btn)
	# No hub button here: only the Landing links to the hub (STANDARDS N1).

## The game is over, so there's nothing to save -- straight back to the hub.
func _on_win_hub_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

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
	title.text = tr("Paused")
	title.add_theme_font_size_override("font_size", 41)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = tr("Resume")
	resume_btn.custom_minimum_size = Vector2(240, 56)
	resume_btn.add_theme_font_size_override("font_size", 28)
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)

	var new_puzzle_btn := Button.new()
	new_puzzle_btn.text = tr("New Puzzle (Same Difficulty)")
	new_puzzle_btn.custom_minimum_size = Vector2(240, 50)
	new_puzzle_btn.add_theme_font_size_override("font_size", 23)
	new_puzzle_btn.pressed.connect(func():
		pause_dialog.visible = false
		game_active = false
		SaveUtil.delete(SAVE_PATH)
		_start_new_game(difficulty)
	)
	box.add_child(new_puzzle_btn)

	var change_diff_btn := Button.new()
	change_diff_btn.text = tr("🏠 Sudoku Home")
	change_diff_btn.custom_minimum_size = Vector2(240, 50)
	change_diff_btn.add_theme_font_size_override("font_size", 24)
	change_diff_btn.pressed.connect(func():
		# Saved, so Home offers Resume -- leaving no longer throws the puzzle away.
		_save_game()
		_show_difficulty_screen()
	)
	box.add_child(change_diff_btn)

	# The rest of the standard pause menu (STANDARDS §6); no hub button (N1).
	for spec in [[tr("❓ How to Play"), _on_pause_help], [tr("📊 Statistics"), _show_stats],
			[tr("📸 Screenshot"), _on_pause_screenshot], [tr("⚙ Options"), _on_pause_options]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(240, 50)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(spec[1])
		box.add_child(b)
	pause_note = Label.new()
	pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_note.add_theme_font_size_override("font_size", 20)
	box.add_child(pause_note)

func _drop_info_tab() -> void:
	if info and "tab_button" in info and is_instance_valid(info.tab_button):
		info.tab_button.queue_free()
	elif info and not is_queued_for_deletion():
		call_deferred("_drop_info_tab_late")

func _drop_info_tab_late() -> void:
	if info and "tab_button" in info and is_instance_valid(info.tab_button):
		info.tab_button.queue_free()

func _on_pause_help() -> void:
	if info:
		info.open()

func _on_pause_options() -> void:
	difficulty_screen._show_options(self, true)

## 📸 the board as it is under the menu.
func _on_pause_screenshot() -> void:
	pause_dialog.visible = false
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var img: Image = get_viewport().get_texture().get_image()
	pause_dialog.visible = true
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var stamp := int(Time.get_unix_time_from_system())
	img.save_png("user://screenshots/sudoku_%d.png" % stamp)
	var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures != "":
		img.save_png(pictures.path_join("viral_sudoku_%d.png" % stamp))
	pause_note.text = tr("Screenshot saved!")

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
	scored_cells = {}
	hint_elim = {}
	_clear_hint()
	hint_label.text = tr("Hint: %d") % hints_remaining
	selected = Vector2i(-1, -1)
	notes_mode = false
	notes_status_label.text = tr("Notes: Off")
	notes_button.button_pressed = false

	_populate_board()
	difficulty_label.text = difficulty.capitalize()
	_update_status_bar()
	if info:
		info.add("_played_" + difficulty)

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
	var snap := _record_undo(r, c)
	cell.set_value(n)
	_clear_hint()

	if n == solution[r][c]:
		snap["peers"] = _clear_peer_notes(r, c, n)
		snap["peer_digit"] = n
		if not scored_cells.has(r * 9 + c):
			scored_cells[r * 9 + c] = true
			score += CORRECT_CELL_POINTS
		_update_number_pad()
		_check_win()
	else:
		cell.mark_error()
		mistakes += 1
		score = max(0, score - MISTAKE_PENALTY)

	_update_status_bar()

## A correct number crosses itself out of the notes in its row, column and
## box. Returns what it cleared, so Undo can put the notes back.
func _clear_peer_notes(r: int, c: int, n: int) -> Array:
	var cleared := []
	for rr in range(9):
		for cc in range(9):
			if rr == r and cc == c:
				continue
			var peer: bool = rr == r or cc == c or (int(rr / 3) == int(r / 3) and int(cc / 3) == int(c / 3))
			var cell: CellButton = cells[rr][cc]
			if peer and cell.value == 0 and cell.notes[n - 1]:
				cleared.append([rr, cc])
				cell.notes[n - 1] = false
				cell.update_display()
	return cleared

func _on_erase_pressed() -> void:
	if selected.x < 0:
		return
	var cell: CellButton = cells[selected.x][selected.y]
	if cell.is_given:
		return
	_record_undo(selected.x, selected.y)
	cell.clear_value()
	_clear_hint()
	_refresh_highlights()
	_update_number_pad()

func _on_notes_toggled() -> void:
	notes_mode = notes_button.button_pressed
	notes_status_label.text = tr("Notes: On") if notes_mode else tr("Notes: Off")

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
func _record_undo(r: int, c: int) -> Dictionary:
	var cell: CellButton = cells[r][c]
	var snap := {
		"row": r, "col": c,
		"value": cell.value,
		"notes": cell.notes.duplicate(),
		"is_error": cell.is_error,
		"score": score,
		"mistakes": mistakes,
		"scored": scored_cells.has(r * 9 + c),
	}
	move_history.append(snap)
	if move_history.size() > MAX_UNDO_HISTORY:
		move_history.pop_front()
	return snap

func _on_undo_pressed() -> void:
	if not game_active or move_history.is_empty():
		return
	var snap: Dictionary = move_history.pop_back()
	var cell: CellButton = cells[snap.row][snap.col]
	cell.value = snap.value
	cell.notes = snap.notes.duplicate()
	cell.is_error = snap.is_error
	cell.update_display()
	for p in snap.get("peers", []):
		var peer: CellButton = cells[p[0]][p[1]]
		peer.notes[snap.peer_digit - 1] = true
		peer.update_display()
	_clear_hint()
	score = snap.score
	mistakes = snap.mistakes
	if snap.get("scored", false):
		scored_cells[snap.row * 9 + snap.col] = true
	else:
		scored_cells.erase(snap.row * 9 + snap.col)
	selected = Vector2i(snap.row, snap.col)
	_update_status_bar()
	_refresh_highlights()
	_update_number_pad()

## 💡 teaches the next step instead of filling a square: the first tap
## shows where to look (and costs a hint), a second tap explains why.
## A red number gets pointed out first, for free.
func _on_hint_pressed() -> void:
	if not game_active:
		return
	if not current_hint.is_empty() and hint_step == 1:
		hint_step = 2
		if current_hint.cell >= 0 and current_hint.kind != "fewest":
			scored_cells[current_hint.cell] = true  # a revealed square earns no points
		_show_hint()
		return
	for r in range(9):
		for c in range(9):
			if cells[r][c].is_error:
				current_hint = {"kind": "error", "cell": r * 9 + c, "cells": [], "unit": []}
				hint_step = 2
				_show_hint()
				return
	if hints_remaining <= 0:
		current_hint = {"kind": "none", "cell": -1, "cells": [], "unit": []}
		hint_step = 2
		_show_hint()
		return
	var grid := []
	for r in range(9):
		for c in range(9):
			grid.append(cells[r][c].value)
	var prefer := selected.x * 9 + selected.y if selected.x >= 0 else -1
	current_hint = SudokuHints.find(grid, hint_elim, prefer)
	if current_hint.is_empty():
		return
	for key in current_hint.elim:
		hint_elim[key] = true
	hint_step = 1
	hints_remaining -= 1
	hint_label.text = tr("Hint: %d") % hints_remaining
	_show_hint()

func _show_hint() -> void:
	var h := current_hint
	var t := ""
	var digit_list := _join_digits(h.get("digits", []))
	match h.kind:
		"error":
			t = tr("A red number is wrong. Erase it first, then ask again.")
		"none":
			t = tr("No hints left for this puzzle. Look for a number that fits in only one square of a box.")
		"hidden":
			if hint_step == 1:
				t = {"box": tr("Look at the highlighted box. The %d fits in only one of its squares. Can you find it?"),
					"row": tr("Look at the highlighted row. The %d fits in only one of its squares. Can you find it?"),
					"column": tr("Look at the highlighted column. The %d fits in only one of its squares. Can you find it?"),
				}[h.unit_kind] % h.digit
			else:
				t = {"box": tr("Every other empty square in this box already sees a %d in its row or column, so the %d must go in the gold square."),
					"row": tr("Every other empty square in this row already sees a %d in its column or box, so the %d must go in the gold square."),
					"column": tr("Every other empty square in this column already sees a %d in its row or box, so the %d must go in the gold square."),
				}[h.unit_kind] % [h.digit, h.digit]
		"naked":
			if hint_step == 1:
				t = tr("Look at the gold square. Check its row, column and box: only one number is missing from all of them.")
			else:
				t = tr("Its row, column and box already use %s. The only number left is %d.") % [_join_digits(h.seen), h.digit]
		"pointing":
			if hint_step == 1:
				t = tr("Look at the highlighted box: where can the %d go in it?") % h.digit
			else:
				t = (tr("In this box the %d can only go in one row, so no other square of that row can be a %d. Cross it out of your notes.") if h.line_kind == "row"
					else tr("In this box the %d can only go in one column, so no other square of that column can be a %d. Cross it out of your notes.")) % [h.digit, h.digit]
		"pair":
			if hint_step == 1:
				t = tr("Look at the two gold squares. Which numbers can each of them be?")
			else:
				t = {"box": tr("Both can only be %s. Those two numbers are used up by this pair, so no other square in this box can be either of them."),
					"row": tr("Both can only be %s. Those two numbers are used up by this pair, so no other square in this row can be either of them."),
					"column": tr("Both can only be %s. Those two numbers are used up by this pair, so no other square in this column can be either of them."),
				}[h.unit_kind] % (tr("%d or %d") % [h.digits[0], h.digits[1]])
		"fewest":
			if hint_step == 1:
				t = tr("No square is easy right now. The gold square has only %d possible numbers.") % h.digits.size()
			else:
				t = tr("It can be %s. Pencil them in with Notes, and look at what each one would block.") % digit_list
	if hint_step == 1:
		t = tr("%s\nTap 💡 again to see why.") % t
	hint_text.text = t
	hint_box.visible = true
	stats_box.visible = false
	if _hint_cell_shown():
		selected = Vector2i(int(h.cell / 9), h.cell % 9)
	_refresh_highlights()

## Whether the gold square may be shown yet: a hidden single's square is
## the puzzle the first step asks the player to find.
func _hint_cell_shown() -> bool:
	if current_hint.is_empty() or current_hint.cell < 0:
		return false
	return current_hint.kind in ["naked", "fewest", "error"] or hint_step == 2

func _join_digits(digits: Array) -> String:
	var parts := PackedStringArray()
	for d in digits:
		parts.append(str(d))
	return ", ".join(parts)

func _clear_hint() -> void:
	current_hint = {}
	hint_step = 0
	if hint_box:
		hint_box.visible = false
		stats_box.visible = true

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
	win_stats_label.text = tr("Time: %s   Mistakes: %d\nFinal Score: %d") % [_format_time(elapsed_seconds), mistakes, final_score]
	if info:
		var d := difficulty
		info.add("Puzzles solved")
		info.celebrate("Solved!")
		info.add("_solved_" + d)
		info.add("_time_sum_" + d, int(round(elapsed_seconds)))
		var fast: bool = info.low("_best_time_" + d, elapsed_seconds)
		var level_high: bool = info.high("_best_score_" + d, final_score)
		var high: bool = info.best("Best score", final_score)
		if mistakes == 0:
			info.add("Perfect games")
			info.add("_perfect_" + d)
		high = high or level_high
		if fast or high:
			win_stats_label.text += "\n" + tr("New best!")
	win_dialog.visible = true

# ---------- statistics per difficulty ----------

## Per-level stats are "_" keys (GameInfo's card hides those -- it shows the
## totals; the table below shows each level). Earlier versions kept two of
## them as visible "Puzzles solved (Medium)" / "Best time (Medium)" keys.
func _migrate_level_stats() -> void:
	if not ("stats" in info):
		return
	for d in DIFFICULTIES:
		var level: String = d.capitalize()
		var old_time := "Best time (%s)" % level
		var old_solved := "Puzzles solved (%s)" % level
		if not info.stats.has(old_time) and not info.stats.has(old_solved):
			continue
		if info.stats.has(old_time):
			info.stats["_best_time_" + d] = info.stats[old_time]
			info.stats.erase(old_time)
		var n := int(info.stats.get(old_solved, 0))
		info.stats.erase(old_solved)
		info.stats["_solved_" + d] = int(info.stats.get("_solved_" + d, 0)) + n
		# Those solves have no time in "_time_sum_", so Avg. time skips them. add() saves.
		info.add("_untimed_" + d, n)

func _build_stats_overlay() -> void:
	stats_overlay = ColorRect.new()
	stats_overlay.color = Color(0.05, 0.05, 0.08, 0.97)
	stats_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_overlay.visible = false
	add_child(stats_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var title := Label.new()
	title.text = tr("📊 Statistics")
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	stats_grid = GridContainer.new()
	stats_grid.columns = DIFFICULTIES.size() + 1
	stats_grid.add_theme_constant_override("h_separation", 14)
	stats_grid.add_theme_constant_override("v_separation", 16)
	box.add_child(stats_grid)

	var close_btn := Button.new()
	close_btn.text = tr("Close")
	close_btn.custom_minimum_size = Vector2(260, 56)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): stats_overlay.visible = false)
	box.add_child(close_btn)

func _show_stats() -> void:
	if not info or stats_overlay == null:
		return
	for c in stats_grid.get_children():
		c.queue_free()
	var col_w: float = floor((get_rect().size.x - 40.0 - 14.0 * DIFFICULTIES.size()) / (DIFFICULTIES.size() + 1.4))
	_stats_cell("", col_w * 1.4, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	for d in DIFFICULTIES:
		_stats_cell(tr(d.capitalize()), col_w, Color(0.55, 0.8, 1.0))
	for row in ["Played", "Solved", "Solve rate", "Perfect", "Best time", "Avg. time", "Best score"]:
		_stats_cell(tr(row), col_w * 1.4, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
		for d in DIFFICULTIES:
			_stats_cell(_level_stat(row, d), col_w, Color.WHITE)
	stats_overlay.visible = true

func _stats_cell(text: String, width: float, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = align
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	stats_grid.add_child(l)

func _level_stat(row: String, d: String) -> String:
	var solved := int(_stat("_solved_" + d, 0))
	# Saves from before "played" was counted can have more solves than plays.
	var played: int = max(int(_stat("_played_" + d, 0)), solved)
	match row:
		"Played":
			return str(played)
		"Solved":
			return str(solved)
		"Solve rate":
			return "%d%%" % roundi(100.0 * solved / played) if played > 0 else "—"
		"Perfect":
			return str(int(_stat("_perfect_" + d, 0)))
		"Best time":
			var t = _stat("_best_time_" + d, null)
			return _format_time(float(t)) if t != null else "—"
		"Avg. time":
			var sum := int(_stat("_time_sum_" + d, 0))
			# Solves recorded before the time sum existed have no time to average.
			var timed: int = solved - int(_stat("_untimed_" + d, 0))
			return _format_time(float(sum) / timed) if sum > 0 and timed > 0 else "—"
		"Best score":
			var b = _stat("_best_score_" + d, null)
			return str(int(b)) if b != null else "—"
	return ""

## A GameInfo stat, read from its dictionary (get_stat() is v0.21+).
func _stat(key: String, default: Variant = 0) -> Variant:
	return info.stats.get(key, default) if info and "stats" in info else default

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
		"scored_cells": scored_cells.keys(),
	})

func _refresh_continue_button() -> void:
	difficulty_screen.refresh(SaveUtil.read(SAVE_PATH))

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
	scored_cells = {}
	hint_elim = {}
	_clear_hint()
	for key in data.get("scored_cells", []):
		scored_cells[int(key)] = true
	selected = Vector2i(-1, -1)
	notes_mode = false
	notes_status_label.text = tr("Notes: Off")
	notes_button.button_pressed = false
	hint_label.text = tr("Hint: %d") % hints_remaining

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
				# Saves from before scored_cells existed: whatever is correct
				# on the board now has already been paid for.
				if not data.has("scored_cells") and v != 0 and v == solution[r][c]:
					scored_cells[idx] = true
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
	var match_digit: int = cells[selected.x][selected.y].value if selected.x >= 0 else 0
	for r in range(9):
		for c in range(9):
			cells[r][c].set_background(COLOR_BASE)
			cells[r][c].set_match_note(match_digit)

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

	if not current_hint.is_empty():
		var shade := []
		shade.append_array(current_hint.unit)
		if hint_step == 2:
			shade.append_array(current_hint.get("line", []))
		for i in shade:
			if i != selected.x * 9 + selected.y:
				cells[int(i / 9)][i % 9].set_background(COLOR_HINT_AREA)
		var gold: Array = current_hint.cells.duplicate()
		if _hint_cell_shown():
			gold.append(current_hint.cell)
		if current_hint.kind in ["hidden", "pointing"] and hint_step == 2:
			# the numbers doing the blocking
			for r in range(9):
				for c in range(9):
					if cells[r][c].value == current_hint.digit and not cells[r][c].is_error:
						cells[r][c].set_background(COLOR_SAME_VALUE)
		for i in gold:
			cells[int(i / 9)][i % 9].set_background(COLOR_HINT_TARGET)

	# errors always win, so a mistake stays visible even under peer/selection highlighting
	for r in range(9):
		for c in range(9):
			if cells[r][c].is_error:
				cells[r][c].set_background(COLOR_ERROR_BG)
