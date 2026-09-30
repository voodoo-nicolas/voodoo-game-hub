extends Control

const Connect4Engine = preload("res://scripts/games/connect4/connect4_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://connect4_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"
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
var online_btn: Button
## Online play (null on apps without it). my_color: host plays Red, guest
## Yellow; 0 means ordinary same-phone play.
var online: Control = null
var my_color: int = 0

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
	title.add_theme_font_size_override("font_size", 28)
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
	status_label.add_theme_font_size_override("font_size", 26)
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

	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online_btn = Button.new()
		online_btn.text = "🌐 Play Online"
		online_btn.custom_minimum_size = Vector2(0, 80)
		online_btn.add_theme_font_size_override("font_size", 30)
		online_btn.pressed.connect(_open_lobby)
		box.add_child(online_btn)

	_build_pause_dialog()
	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("connect4", "Connect Four", _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
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

func _is_online() -> bool:
	return online != null and online.is_online()

func _start_new_game() -> void:
	if online:
		online.new_game()
	_reset_board()

func _reset_board() -> void:
	engine.reset()
	game_active = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()

func _on_column_pressed(col: int) -> void:
	if not game_active:
		return
	if _is_online() and not online.can_act(engine.turn == my_color):
		return  # not your turn (or nobody to play against right now)
	if engine.drop(col) == -1:
		return
	if _is_online():
		online.send_move({"col": col})
	_after_move()

func _after_move() -> void:
	_render()
	if engine.is_over():
		_show_result()

# ---------- online ----------

func _open_lobby() -> void:
	online.open_lobby()

func _online_state() -> Dictionary:
	return {"board": engine.board, "turn": engine.turn}

func _on_online_started(my_player: int) -> void:
	my_color = Connect4Engine.RED if my_player == 1 else Connect4Engine.YELLOW
	online_btn.visible = false
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	var col: int = int(p.get("col", -1))
	if engine.turn != my_color and col >= 0 and col < Connect4Engine.COLS and not engine.is_over() and engine.drop(col) != -1:
		_after_move()

func _on_remote_state(st: Dictionary) -> void:
	var board: Array = []
	for row in st.get("board", []):
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	if board.size() != Connect4Engine.ROWS:
		return
	engine.board = board
	engine.turn = int(st.get("turn", Connect4Engine.RED))
	game_active = not engine.is_over()
	win_dialog.visible = false
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
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner()
	if w == Connect4Engine.EMPTY:
		win_label.text = "It's a draw!"
	elif _is_online():
		win_label.text = online.result_text(w == my_color)
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

	var color_name := "Red" if engine.turn == Connect4Engine.RED else "Yellow"
	if _is_online():
		status_label.text = online.status_text(engine.turn == my_color, color_name)
	else:
		status_label.text = "Turn: %s" % color_name

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
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
