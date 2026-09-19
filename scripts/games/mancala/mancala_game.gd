extends Control

const MancalaEngine = preload("res://scripts/games/mancala/mancala_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://mancala_save.json"
const COLOR_PIT := Color(0.35, 0.24, 0.15)
const COLOR_PIT_ACTIVE := Color(0.5, 0.35, 0.18)
const COLOR_STORE := Color(0.25, 0.17, 0.1)

var engine
var game_active: bool = false
var pit_buttons: Dictionary = {}  # index -> Button
var pit_labels: Dictionary = {}  # index -> Label
var store_labels: Dictionary = {}  # index -> Label
var status_label: Label
var pause_dialog: Control
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = MancalaEngine.new()
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
	root.add_theme_constant_override("separation", 14)
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
	title.text = "Mancala"
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var viewport_width: float = get_viewport_rect().size.x
	var store_width: float = floor(viewport_width * 0.16)
	var pit_area_width: float = viewport_width - store_width * 2.0 - 24.0
	var pit_size: float = floor((pit_area_width - 5.0 * 6.0) / 6.0)
	var store_height: float = pit_size * 2.0 + 6.0

	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 12)
	center.add_child(board_row)

	board_row.add_child(_make_store(MancalaEngine.P2_STORE, store_width, store_height))

	var pits_col := VBoxContainer.new()
	pits_col.add_theme_constant_override("separation", 6)
	board_row.add_child(pits_col)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	pits_col.add_child(top_row)
	for i in [12, 11, 10, 9, 8, 7]:
		top_row.add_child(_make_pit(i, pit_size))

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	pits_col.add_child(bottom_row)
	for i in range(0, 6):
		bottom_row.add_child(_make_pit(i, pit_size))

	board_row.add_child(_make_store(MancalaEngine.P1_STORE, store_width, store_height))

	_build_pause_dialog()
	_build_win_dialog()
	add_child(SettingsDrawer.new())

func _make_pit(index: int, size: float) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(size, size)
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_pit_pressed.bind(index))
	pit_buttons[index] = btn

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(size * 0.4))
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)
	pit_labels[index] = label

	return btn

func _make_store(index: int, width: float, height: float) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_STORE
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(width * 0.5))
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	panel.add_child(label)
	store_labels[index] = label

	return panel

func _build_pause_dialog() -> void:
	pause_dialog = Ui.build_dialog("Paused", [
		{"text": "Resume", "action": Callable()},
		{"text": "Restart", "action": _start_new_game},
		{"text": "Exit to Hub", "action": Ui.exit_to_hub.bind(self)},
	])
	add_child(pause_dialog)

func _build_win_dialog() -> void:
	win_dialog = Ui.build_dialog("", [
		{"text": "Play Again", "action": _start_new_game},
		{"text": "Back to Hub", "action": Ui.exit_to_hub.bind(self)},
	], true)
	add_child(win_dialog)
	win_label = win_dialog.get_meta("message_label")

func _start_new_game() -> void:
	engine.reset()
	game_active = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

func _on_pit_pressed(index: int) -> void:
	if not game_active:
		return
	if not engine.legal_pits(engine.current_player).has(index):
		return
	var result: Dictionary = engine.sow(index)
	if not result.valid:
		return
	_render()
	if engine.game_over:
		_show_result()
	elif result.extra_turn:
		status_label.text = "Player %d goes again!" % engine.current_player

func _show_result() -> void:
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	var p1: int = engine.board[MancalaEngine.P1_STORE]
	var p2: int = engine.board[MancalaEngine.P2_STORE]
	if engine.winner == 0:
		win_label.text = "It's a tie! %d - %d" % [p1, p2]
	else:
		win_label.text = "Player %d wins! %d - %d" % [engine.winner, p1, p2]
	win_dialog.visible = true

# ---------- rendering ----------

func _render() -> void:
	for i in pit_labels.keys():
		pit_labels[i].text = str(engine.board[i])
	for i in store_labels.keys():
		store_labels[i].text = str(engine.board[i])

	var current: int = engine.current_player
	for i in pit_buttons.keys():
		var is_current_side: bool = (current == 1 and i >= 0 and i <= 5) or (current == 2 and i >= 7 and i <= 12)
		var can_play: bool = is_current_side and engine.board[i] > 0 and game_active
		_style_pit(pit_buttons[i], COLOR_PIT_ACTIVE if can_play else COLOR_PIT)

	if game_active:
		status_label.text = "Player %d's turn" % current

func _style_pit(btn: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	var radius: int = int(btn.custom_minimum_size.x / 2.0)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, sb)

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false
	var board: Array = []
	for v in data.board:
		board.append(int(v))
	engine.board = board
	engine.current_player = int(data.current_player)
	engine.game_over = false
	game_active = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()
	return true
