extends Control

const Connect4Engine = preload("res://scripts/games/connect4/connect4_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://connect4_save.json"
const BOARD_SEPARATION := 4
const BOARD_PADDING := 8
const BOARD_OUTER_MARGIN := 8.0
const COLOR_EMPTY := Color(0.15, 0.15, 0.19)
const COLOR_RED := Color(0.9, 0.3, 0.3)
const COLOR_YELLOW := Color(0.95, 0.8, 0.2)

var engine
var game_active: bool = false
var cell_size: float = 46.0

var status_label: Label
var cell_views: Array = []  # ROWS x COLS of Panel/ColorRect-like nodes (we'll use PanelContainer with StyleBoxFlat)
var pause_dialog: Control
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = Connect4Engine.new()
	_build_ui()
	if not _load_saved_game():
		_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_bar)

	var pause_btn := Button.new()
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = "Connect Four"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var viewport_width: float = get_viewport_rect().size.x
	var available: float = viewport_width - BOARD_OUTER_MARGIN * 2.0 - BOARD_PADDING * 2.0
	cell_size = floor((available - BOARD_SEPARATION * (Connect4Engine.COLS - 1)) / Connect4Engine.COLS)

	var board_panel := PanelContainer.new()
	var board_sb := StyleBoxFlat.new()
	board_sb.bg_color = Color(0.12, 0.2, 0.4)
	board_sb.corner_radius_top_left = 10
	board_sb.corner_radius_top_right = 10
	board_sb.corner_radius_bottom_left = 10
	board_sb.corner_radius_bottom_right = 10
	board_sb.content_margin_left = BOARD_PADDING
	board_sb.content_margin_right = BOARD_PADDING
	board_sb.content_margin_top = BOARD_PADDING
	board_sb.content_margin_bottom = BOARD_PADDING
	board_panel.add_theme_stylebox_override("panel", board_sb)
	box.add_child(board_panel)

	var grid := GridContainer.new()
	grid.columns = Connect4Engine.COLS
	grid.add_theme_constant_override("h_separation", BOARD_SEPARATION)
	grid.add_theme_constant_override("v_separation", BOARD_SEPARATION)
	board_panel.add_child(grid)

	for r in range(Connect4Engine.ROWS):
		var row: Array = []
		for c in range(Connect4Engine.COLS):
			var slot := Button.new()
			slot.custom_minimum_size = Vector2(cell_size, cell_size)
			slot.flat = false
			slot.focus_mode = Control.FOCUS_NONE
			_style_slot(slot, COLOR_EMPTY)
			slot.pressed.connect(_on_column_pressed.bind(c))
			grid.add_child(slot)
			row.append(slot)
		cell_views.append(row)

	_build_pause_dialog()
	_build_win_dialog()
	add_child(SettingsDrawer.new())

func _style_slot(slot: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	var radius: int = int(cell_size / 2.0)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		slot.add_theme_stylebox_override(state, sb)

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
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
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
	resume_btn.custom_minimum_size = Vector2(200, 48)
	resume_btn.pressed.connect(func(): pause_dialog.visible = false)
	box.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size = Vector2(200, 44)
	restart_btn.pressed.connect(func():
		pause_dialog.visible = false
		_start_new_game()
	)
	box.add_child(restart_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit to Hub"
	exit_btn.custom_minimum_size = Vector2(200, 44)
	exit_btn.pressed.connect(func():
		_save_game()
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
	)
	box.add_child(exit_btn)

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
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 24)
	win_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	engine.reset()
	game_active = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()

func _on_column_pressed(col: int) -> void:
	if not game_active:
		return
	if engine.drop(col) == -1:
		return
	_render()
	if engine.is_over():
		_show_result()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

func _show_result() -> void:
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner()
	if w == Connect4Engine.EMPTY:
		win_label.text = "It's a draw!"
	else:
		win_label.text = "%s wins!" % ("Red" if w == Connect4Engine.RED else "Yellow")
	win_dialog.visible = true

func _render() -> void:
	for r in range(Connect4Engine.ROWS):
		for c in range(Connect4Engine.COLS):
			var v: int = engine.board[r][c]
			var color: Color = COLOR_EMPTY
			if v == Connect4Engine.RED:
				color = COLOR_RED
			elif v == Connect4Engine.YELLOW:
				color = COLOR_YELLOW
			_style_slot(cell_views[r][c], color)

	status_label.text = "Turn: %s" % ("Red" if engine.turn == Connect4Engine.RED else "Yellow")

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {"board": engine.board, "turn": engine.turn})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false
	var board: Array = []
	for row in data.board:
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	engine.board = board
	engine.turn = int(data.turn)
	game_active = not engine.is_over()
	_render()
	return game_active
