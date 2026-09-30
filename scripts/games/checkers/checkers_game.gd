extends Control

const CheckersEngine = preload("res://scripts/games/checkers/checkers_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://checkers_save.json"
## Not preloaded: apps older than v0.14 don't have it, and the game must still
## run there (without the Online button).
const ONLINE_MATCH_PATH := "res://scripts/common/online_match.gd"

const COLOR_DARK_SQUARE := Color(0.3, 0.2, 0.15)
const COLOR_LIGHT_SQUARE := Color(0.55, 0.42, 0.32)
const COLOR_SELECTED := Color(1.0, 0.84, 0.04)
const COLOR_DEST := Color(0.4, 0.9, 0.4, 0.55)
const COLOR_P1 := Color(0.8, 0.15, 0.15)
const COLOR_P2 := Color(0.93, 0.9, 0.85)

var engine
var game_active: bool = false
var selected: Vector2i = Vector2i(-1, -1)
var dest_map: Dictionary = {}  # Vector2i(dest) -> Vector2i(captured) or (-1,-1)

var squares: Array = []  # 8x8 Buttons
var piece_views: Array = []  # 8x8 Panel (may be null-equivalent hidden)
var king_labels: Array = []  # 8x8 Label
var status_label: Label
var pause_dialog: Control
var win_dialog: Control
var win_label: Label
var online_btn: Button
## Online play (null on apps without it). Host is Player 1 (red, bottom),
## guest Player 2 (white) and sees the board flipped so their own pieces are
## at the bottom. my_side: 1 / -1 as the engine counts; 0 = same-phone play.
var online: Control = null
var my_side: int = 0
var flipped: bool = false

func _ready() -> void:
	preload("res://scripts/games/checkers/checkers_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CheckersEngine.new()
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
	pause_btn.text = tr("Pause")
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = tr("Checkers")
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
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
	var board_margin := 12.0
	var cell_size: float = floor((viewport_width - board_margin * 2.0) / 8.0)
	var board_size: float = cell_size * 8.0

	var board_wrap := Control.new()
	board_wrap.custom_minimum_size = Vector2(board_size, board_size)
	center.add_child(board_wrap)

	var grid := GridContainer.new()
	grid.columns = 8
	board_wrap.add_child(grid)

	squares.resize(64)
	piece_views.resize(64)
	king_labels.resize(64)

	for r in range(8):
		for c in range(8):
			var idx := r * 8 + c
			var sq := Button.new()
			sq.custom_minimum_size = Vector2(cell_size, cell_size)
			sq.flat = false
			sq.focus_mode = Control.FOCUS_NONE
			sq.pressed.connect(_on_square_pressed.bind(r, c))
			grid.add_child(sq)
			squares[idx] = sq

			var piece := PanelContainer.new()
			piece.custom_minimum_size = Vector2(cell_size * 0.78, cell_size * 0.78)
			piece.size = piece.custom_minimum_size
			piece.position = Vector2(cell_size * 0.11, cell_size * 0.11)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.visible = false
			sq.add_child(piece)
			piece_views[idx] = piece

			var king_label := Label.new()
			king_label.text = "♛"
			king_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			king_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			king_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			king_label.add_theme_font_size_override("font_size", int(cell_size * 0.4))
			king_label.add_theme_color_override("font_color", Color(1, 0.84, 0.1))
			king_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			king_label.visible = false
			piece.add_child(king_label)
			king_labels[idx] = king_label

	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online_btn = Button.new()
		online_btn.text = tr("🌐 Play Online")
		online_btn.custom_minimum_size = Vector2(0, 80)
		online_btn.add_theme_font_size_override("font_size", 30)
		online_btn.pressed.connect(func(): online.open_lobby())
		var btn_margin := MarginContainer.new()
		btn_margin.add_theme_constant_override("margin_bottom", 40)
		btn_margin.add_theme_constant_override("margin_left", 60)
		btn_margin.add_theme_constant_override("margin_right", 60)
		btn_margin.add_child(online_btn)
		root.add_child(btn_margin)

	_build_pause_dialog()
	_build_win_dialog()
	if ResourceLoader.exists(ONLINE_MATCH_PATH):
		online = load(ONLINE_MATCH_PATH).new("checkers", tr("Checkers"), _online_state)
		online.started.connect(_on_online_started)
		online.remote_move.connect(_on_remote_move)
		online.remote_state.connect(_on_remote_state)
		online.remote_new_game.connect(_reset_board)
		online.status_changed.connect(_render)
		add_child(online)
	add_child(SettingsDrawer.new())

func _build_pause_dialog() -> void:
	pause_dialog = Ui.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": Callable()},
		{"text": tr("Restart"), "action": _start_new_game},
		{"text": tr("Exit to Hub"), "action": Ui.exit_to_hub.bind(self)},
	])
	add_child(pause_dialog)

func _build_win_dialog() -> void:
	win_dialog = Ui.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": Ui.exit_to_hub.bind(self)},
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
	selected = Vector2i(-1, -1)
	dest_map = {}
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

## Screen square -> board square. The guest's view is rotated 180 degrees.
func _view_index(r: int, c: int) -> int:
	return (7 - r) * 8 + (7 - c) if flipped else r * 8 + c

func _on_square_pressed(vr: int, vc: int) -> void:
	if not game_active:
		return
	if _is_online() and not online.can_act(engine.current_player == my_side):
		return
	var r: int = 7 - vr if flipped else vr
	var c: int = 7 - vc if flipped else vc
	var pos := Vector2i(r, c)

	if dest_map.has(pos):
		var from := selected
		var result: Dictionary = engine.move(selected, pos)
		if result.valid:
			if _is_online():
				online.send_move({"from": [from.x, from.y], "to": [pos.x, pos.y]})
			if result.chain_continues:
				selected = pos
			else:
				selected = Vector2i(-1, -1)
			_render()
			if engine.game_over:
				_show_result()
		return

	if pos == selected:
		selected = Vector2i(-1, -1)
		_render()
		return

	if engine.must_continue_from.x >= 0:
		return  # mid-chain: only the forced piece's destinations are selectable

	var lm: Dictionary = engine.legal_moves_for(r, c)
	if not lm.captures.is_empty() or not lm.moves.is_empty():
		selected = pos
	else:
		selected = Vector2i(-1, -1)
	_render()

# ---------- online ----------

func _online_state() -> Dictionary:
	return {
		"board": engine.board, "current_player": engine.current_player,
		"must_continue_from": [engine.must_continue_from.x, engine.must_continue_from.y],
		"quiet_moves": engine.quiet_moves, "game_over": engine.game_over, "winner": engine.winner,
	}

func _on_online_started(my_player: int) -> void:
	my_side = 1 if my_player == 1 else -1
	flipped = my_side == -1
	online_btn.visible = false
	_reset_board()

func _on_remote_move(p: Dictionary) -> void:
	if not game_active or engine.current_player == my_side:
		return
	var f: Array = p.get("from", [-1, -1])
	var t: Array = p.get("to", [-1, -1])
	var result: Dictionary = engine.move(Vector2i(int(f[0]), int(f[1])), Vector2i(int(t[0]), int(t[1])))
	if result.valid:
		selected = Vector2i(-1, -1)
		_render()
		if engine.game_over:
			_show_result()

func _on_remote_state(st: Dictionary) -> void:
	var board: Array = []
	for row in st.get("board", []):
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	if board.size() != 8:
		return
	engine.board = board
	engine.current_player = int(st.get("current_player", 1))
	var mc: Array = st.get("must_continue_from", [-1, -1])
	engine.must_continue_from = Vector2i(int(mc[0]), int(mc[1]))
	engine.quiet_moves = int(st.get("quiet_moves", 0))
	engine.game_over = bool(st.get("game_over", false))
	engine.winner = int(st.get("winner", 0))
	game_active = not engine.game_over
	selected = Vector2i(-1, -1)
	win_dialog.visible = false
	_render()
	if engine.game_over:
		_show_result()

func _show_result() -> void:
	game_active = false
	if not _is_online():  # an online game ending mustn't wipe a paused local one
		SaveUtil.delete(SAVE_PATH)
	if engine.winner == 0:
		win_label.text = tr("Draw — 40 moves each with no captures")
	elif _is_online():
		win_label.text = online.result_text(engine.winner == my_side)
	else:
		win_label.text = tr("Player %d wins!") % (1 if engine.winner == 1 else 2)
	win_dialog.visible = true

# ---------- rendering ----------

func _render() -> void:
	dest_map = {}
	if selected.x >= 0:
		var lm: Dictionary = engine.legal_moves_for(selected.x, selected.y)
		var moves: Array = lm.captures if not lm.captures.is_empty() else lm.moves
		for m in moves:
			if lm.captures.is_empty():
				dest_map[m] = Vector2i(-1, -1)
			else:
				dest_map[m.to] = m.captured

	for r in range(8):
		for c in range(8):
			var idx := _view_index(r, c)
			var sq: Button = squares[idx]
			var is_dark: bool = (r + c) % 2 == 1
			var pos := Vector2i(r, c)

			var square_color: Color
			if pos == selected:
				square_color = COLOR_SELECTED
			elif dest_map.has(pos):
				square_color = COLOR_DEST
			else:
				square_color = COLOR_DARK_SQUARE if is_dark else COLOR_LIGHT_SQUARE
			_style_square(sq, square_color)

			var v: int = engine.board[r][c]
			var piece: PanelContainer = piece_views[idx]
			var king_label: Label = king_labels[idx]
			if v == 0:
				piece.visible = false
			else:
				piece.visible = true
				var owner_color: Color = COLOR_P1 if v > 0 else COLOR_P2
				_style_piece(piece, owner_color)
				king_label.visible = absi(v) == 2

	if not game_active:
		return
	if _is_online():
		var turn_text := tr("Red") if engine.current_player == 1 else tr("White")
		if engine.must_continue_from.x >= 0:
			turn_text += tr(" — keep capturing!")
		status_label.text = online.status_text(engine.current_player == my_side, turn_text)
	elif engine.must_continue_from.x >= 0:
		status_label.text = tr("Player %d must continue capturing!") % (1 if engine.current_player == 1 else 2)
	else:
		status_label.text = tr("Player %d's turn") % (1 if engine.current_player == 1 else 2)

func _style_square(sq: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		sq.add_theme_stylebox_override(state, sb)

func _style_piece(piece: PanelContainer, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	var radius: int = int(piece.custom_minimum_size.x / 2.0)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.4)
	piece.add_theme_stylebox_override("panel", sb)

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active or _is_online():
		return  # online games aren't resumable alone
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"must_continue_from": [engine.must_continue_from.x, engine.must_continue_from.y],
		"quiet_moves": engine.quiet_moves,
	})

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
	engine.current_player = int(data.current_player)
	var mc: Array = data.must_continue_from
	engine.must_continue_from = Vector2i(int(mc[0]), int(mc[1]))
	engine.quiet_moves = int(data.get("quiet_moves", 0))
	engine.game_over = false
	engine.winner = 0
	game_active = true
	selected = Vector2i(-1, -1)
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()
	return true
