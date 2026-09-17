extends Control

const CheckersEngine = preload("res://scripts/games/checkers/checkers_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const SAVE_PATH := "user://checkers_save.json"

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

func _ready() -> void:
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
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = "Checkers"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
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

	_build_pause_dialog()
	_build_win_dialog()
	add_child(SettingsDrawer.new())

func _panel_style() -> StyleBoxFlat:
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
	return sb

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
	panel.add_theme_stylebox_override("panel", _panel_style())
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
	panel.add_theme_stylebox_override("panel", _panel_style())
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

func _on_square_pressed(r: int, c: int) -> void:
	if not game_active:
		return
	var pos := Vector2i(r, c)

	if dest_map.has(pos):
		var captured: Vector2i = dest_map[pos]
		var result: Dictionary = engine.move(selected, pos)
		if result.valid:
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

func _show_result() -> void:
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	win_label.text = "Player %d wins!" % (1 if engine.winner == 1 else 2)
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
			var idx := r * 8 + c
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
	if engine.must_continue_from.x >= 0:
		status_label.text = "Player %d must continue capturing!" % (1 if engine.current_player == 1 else 2)
	else:
		status_label.text = "Player %d's turn" % (1 if engine.current_player == 1 else 2)

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
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {
		"board": engine.board,
		"current_player": engine.current_player,
		"must_continue_from": [engine.must_continue_from.x, engine.must_continue_from.y],
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
	engine.game_over = false
	engine.winner = 0
	game_active = true
	selected = Vector2i(-1, -1)
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()
	return true
