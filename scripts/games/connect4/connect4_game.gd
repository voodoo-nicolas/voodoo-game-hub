extends Control

const Connect4Engine = preload("res://scripts/games/connect4/connect4_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://connect4_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_LOBBY_PATH := "res://scripts/common/online_lobby.gd"
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
var lobby: Control
## Online play: the session, and which color this phone plays (host = Red).
## my_color == 0 means ordinary same-phone play.
var online: Node = null
var my_color: int = 0
var opponent_here: bool = false

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

	if ResourceLoader.exists(ONLINE_LOBBY_PATH):
		online_btn = Button.new()
		online_btn.text = "🌐 Play Online"
		online_btn.custom_minimum_size = Vector2(0, 80)
		online_btn.add_theme_font_size_override("font_size", 30)
		online_btn.pressed.connect(_open_lobby)
		box.add_child(online_btn)

	_build_pause_dialog()
	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_LOBBY_PATH):
		lobby = load(ONLINE_LOBBY_PATH).new("connect4", "Connect Four")
		lobby.started.connect(_on_online_started)
		add_child(lobby)
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

func _start_new_game() -> void:
	if online:
		online.send("new_game")
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
	if online and (engine.turn != my_color or not opponent_here):
		return  # not your turn (or nobody to play against right now)
	if engine.drop(col) == -1:
		return
	if online:
		online.send("move", {"col": col, "board": engine.board})
	_after_move()

func _after_move() -> void:
	_render()
	if engine.is_over():
		_show_result()

# ---------- online ----------

func _int_grid(g: Variant) -> Array:
	var out: Array = []
	if typeof(g) == TYPE_ARRAY:
		for row in g:
			var r: Array = []
			if typeof(row) == TYPE_ARRAY:
				for v in row:
					r.append(int(v))
			out.append(r)
	return out

func _open_lobby() -> void:
	lobby.open()

func _on_online_started(session: Node, my_player: int) -> void:
	online = session
	my_color = Connect4Engine.RED if my_player == 1 else Connect4Engine.YELLOW
	opponent_here = true
	online.message.connect(_on_online_message)
	online.opponent_left.connect(_on_opponent_left)
	online.opponent_joined.connect(_on_opponent_back)
	online_btn.visible = false
	_reset_board()
	if my_color == Connect4Engine.RED:
		_send_sync()

func _send_sync() -> void:
	online.send("sync", {"board": engine.board, "turn": engine.turn})

## The host owns the truth: whenever the guest (re)appears it gets the whole
## board, so a dropped connection or a missed message heals itself.
func _on_opponent_back() -> void:
	opponent_here = true
	if my_color == Connect4Engine.RED:
		_send_sync()
	_render()

func _on_opponent_left() -> void:
	opponent_here = false
	_render()

func _on_online_message(event: String, p: Dictionary) -> void:
	match event:
		"move":
			var col: int = int(p.get("col", -1))
			if engine.turn != my_color and col >= 0 and col < Connect4Engine.COLS and not engine.is_over() and engine.drop(col) != -1:
				_after_move()
			# Each move carries the sender's resulting board. If ours differs
			# (a missed message, a reconnect mid-move), converge on the host's.
			if _int_grid(p.get("board", [])) != engine.board:
				if my_color == Connect4Engine.RED:
					_send_sync()
				else:
					online.send("sync_request")
		"sync":
			var board: Array = []
			for row in p.get("board", []):
				var r: Array = []
				for v in row:
					r.append(int(v))
				board.append(r)
			if board.size() == Connect4Engine.ROWS:
				engine.board = board
				engine.turn = int(p.get("turn", Connect4Engine.RED))
				game_active = not engine.is_over()
				win_dialog.visible = false
				_render()
		"sync_request":
			if my_color == Connect4Engine.RED:
				_send_sync()
		"new_game":
			_reset_board()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

func _show_result() -> void:
	game_active = false
	if not online:  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner()
	if w == Connect4Engine.EMPTY:
		win_label.text = "It's a draw!"
	elif online:
		win_label.text = "You win!" if w == my_color else "You lose!"
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
	if not online:
		status_label.text = "Turn: %s" % color_name
	elif not opponent_here:
		status_label.text = "Opponent disconnected — waiting..."
	elif engine.turn == my_color:
		status_label.text = "Your turn (%s)" % color_name
	else:
		status_label.text = "Opponent's turn (%s)" % color_name

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or online:
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
