extends Control

const TicTacToeEngine = preload("res://scripts/games/tictactoe/tictactoe_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://tictactoe_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_LOBBY_PATH := "res://scripts/common/online_lobby.gd"
const COLOR_BASE := Color(0.15, 0.15, 0.19)
const COLOR_WIN := Color(0.25, 0.5, 0.3)

var engine
var game_active: bool = false

var status_label: Label
var cells: Array = []  # 9 Buttons
var pause_dialog: Control
var win_dialog: Control
var win_label: Label
var online_btn: Button
var lobby: Control
## Online play: the session, and which mark this phone plays (host = X).
## my_mark == 0 means ordinary same-phone play.
var online: Node = null
var my_mark: int = 0
var opponent_here: bool = false

func _ready() -> void:
	Orientation.lock_portrait()
	engine = TicTacToeEngine.new()
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
	title.text = "Tic-Tac-Toe"
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
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var grid := GridContainer.new()
	grid.columns = 3
	var separation := 8
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	box.add_child(grid)

	var viewport_width: float = get_viewport_rect().size.x
	var outer_margin := 24.0
	var cell_size: float = floor((viewport_width - outer_margin * 2.0 - separation * 2.0) / 3.0)

	for i in range(9):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.add_theme_font_size_override("font_size", int(cell_size * 0.45))
		cell.flat = false
		cell.focus_mode = Control.FOCUS_NONE
		_style_cell(cell, COLOR_BASE)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cells.append(cell)

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
		lobby = load(ONLINE_LOBBY_PATH).new("tictactoe", "Tic-Tac-Toe")
		lobby.started.connect(_on_online_started)
		add_child(lobby)
	add_child(SettingsDrawer.new())

func _style_cell(cell: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.4, 0.48)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell.add_theme_stylebox_override(state, sb)

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

func _on_cell_pressed(i: int) -> void:
	if online and (engine.turn != my_mark or not opponent_here):
		return  # not your turn (or nobody to play against right now)
	if engine.move(i):
		if online:
			online.send("move", {"i": i, "board": engine.board})
		_after_move()

func _after_move() -> void:
	_render()
	if engine.is_over():
		_show_result()

# ---------- online ----------

func _int_array(a: Variant) -> Array:
	var out: Array = []
	if typeof(a) == TYPE_ARRAY:
		for v in a:
			out.append(int(v))
	return out

func _open_lobby() -> void:
	lobby.open()

func _on_online_started(session: Node, my_player: int) -> void:
	online = session
	my_mark = TicTacToeEngine.X if my_player == 1 else TicTacToeEngine.O
	opponent_here = true
	online.message.connect(_on_online_message)
	online.opponent_left.connect(_on_opponent_left)
	online.opponent_joined.connect(_on_opponent_back)
	online_btn.visible = false
	_reset_board()
	if my_mark == TicTacToeEngine.X:
		_send_sync()

func _send_sync() -> void:
	online.send("sync", {"board": engine.board, "turn": engine.turn})

## The host owns the truth: whenever the guest (re)appears it gets the whole
## board, so a dropped connection or a missed message heals itself.
func _on_opponent_back() -> void:
	opponent_here = true
	if my_mark == TicTacToeEngine.X:
		_send_sync()
	_render()

func _on_opponent_left() -> void:
	opponent_here = false
	_render()

func _on_online_message(event: String, p: Dictionary) -> void:
	match event:
		"move":
			if engine.turn != my_mark and engine.move(int(p.get("i", -1))):
				_after_move()
			# Each move carries the sender's resulting board. If ours differs
			# (a missed message, a reconnect mid-move), converge on the host's.
			if _int_array(p.get("board", [])) != engine.board:
				if my_mark == TicTacToeEngine.X:
					_send_sync()
				else:
					online.send("sync_request")
		"sync":
			var board: Array = []
			for v in p.get("board", []):
				board.append(int(v))
			if board.size() == 9:
				engine.board = board
				engine.turn = int(p.get("turn", TicTacToeEngine.X))
				game_active = not engine.is_over()
				win_dialog.visible = false
				_render()
		"sync_request":
			if my_mark == TicTacToeEngine.X:
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
	if w == TicTacToeEngine.EMPTY:
		win_label.text = "It's a draw!"
	elif online:
		win_label.text = "You win!" if w == my_mark else "You lose!"
	else:
		win_label.text = "%s wins!" % ("X" if w == TicTacToeEngine.X else "O")
	win_dialog.visible = true

func _render() -> void:
	for i in range(9):
		var v: int = engine.board[i]
		cells[i].text = "X" if v == TicTacToeEngine.X else ("O" if v == TicTacToeEngine.O else "")
		cells[i].add_theme_color_override("font_color", Color(0.55, 0.8, 1.0) if v == TicTacToeEngine.X else Color(1.0, 0.6, 0.4))

	if engine.is_over():
		var w: int = engine.winner()
		if w != TicTacToeEngine.EMPTY:
			for line in TicTacToeEngine.WIN_LINES:
				if engine.board[line[0]] == w and engine.board[line[1]] == w and engine.board[line[2]] == w:
					for idx in line:
						_style_cell(cells[idx], COLOR_WIN)
	else:
		for c in cells:
			_style_cell(c, COLOR_BASE)

	var mark_name := "X" if engine.turn == TicTacToeEngine.X else "O"
	if not online:
		status_label.text = "Turn: %s" % mark_name
	elif not opponent_here:
		status_label.text = "Opponent disconnected — waiting..."
	elif engine.turn == my_mark:
		status_label.text = "Your turn (%s)" % mark_name
	else:
		status_label.text = "Opponent's turn (%s)" % mark_name

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
	for v in data.board:
		board.append(int(v))
	engine.board = board
	engine.turn = int(data.turn)
	game_active = not engine.is_over()
	_render()
	return game_active
