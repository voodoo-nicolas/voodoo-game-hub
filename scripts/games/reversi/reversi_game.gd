extends Control

const ReversiEngine = preload("res://scripts/games/reversi/reversi_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const SAVE_PATH := "user://reversi_save.json"

const COLOR_BOARD := Color(0.08, 0.35, 0.16)
const COLOR_HINT := Color(0.15, 0.5, 0.22)
const COLOR_BLACK := Color(0.08, 0.08, 0.1)
const COLOR_WHITE := Color(0.95, 0.95, 0.92)

var engine
var game_active: bool = false
var legal_now: Array = []

var squares: Array = []
var piece_views: Array = []
var hint_views: Array = []
var status_label: Label
var score_label: Label
var pause_dialog: Control
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = ReversiEngine.new()
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
	root.add_theme_constant_override("separation", 12)
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
	title.text = "Reversi"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(score_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
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

	var board_sb := StyleBoxFlat.new()
	board_sb.bg_color = Color(0.05, 0.2, 0.09)
	board_sb.border_width_left = 4
	board_sb.border_width_top = 4
	board_sb.border_width_right = 4
	board_sb.border_width_bottom = 4
	board_sb.border_color = Color(0.02, 0.12, 0.05)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", board_sb)
	board_panel.custom_minimum_size = Vector2(board_size, board_size)
	center.add_child(board_panel)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	board_panel.add_child(grid)

	squares.resize(64)
	piece_views.resize(64)
	hint_views.resize(64)

	for r in range(8):
		for c in range(8):
			var idx := r * 8 + c
			var sq := Button.new()
			sq.custom_minimum_size = Vector2(cell_size, cell_size)
			sq.flat = false
			sq.focus_mode = Control.FOCUS_NONE
			_style_square(sq, COLOR_BOARD)
			sq.pressed.connect(_on_square_pressed.bind(r, c))
			grid.add_child(sq)
			squares[idx] = sq

			var piece := PanelContainer.new()
			piece.custom_minimum_size = Vector2(cell_size * 0.82, cell_size * 0.82)
			piece.size = piece.custom_minimum_size
			piece.position = Vector2(cell_size * 0.09, cell_size * 0.09)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.visible = false
			sq.add_child(piece)
			piece_views[idx] = piece

			var hint := PanelContainer.new()
			hint.custom_minimum_size = Vector2(cell_size * 0.28, cell_size * 0.28)
			hint.size = hint.custom_minimum_size
			hint.position = Vector2(cell_size * 0.36, cell_size * 0.36)
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hint.visible = false
			var hint_sb := StyleBoxFlat.new()
			hint_sb.bg_color = Color(1, 1, 1, 0.35)
			var hr := int(hint.custom_minimum_size.x / 2.0)
			hint_sb.corner_radius_top_left = hr
			hint_sb.corner_radius_top_right = hr
			hint_sb.corner_radius_bottom_left = hr
			hint_sb.corner_radius_bottom_right = hr
			hint.add_theme_stylebox_override("panel", hint_sb)
			sq.add_child(hint)
			hint_views[idx] = hint

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
	if not legal_now.has(Vector2i(r, c)):
		return
	var mover: int = engine.current_player
	var result: Dictionary = engine.place(r, c)
	if not result.valid:
		return
	_render()
	if engine.game_over:
		_show_result()
	elif result.passed:
		var passed_player_name: String = "Black" if mover == ReversiEngine.BLACK else "White"
		status_label.text = "%s has no move — turn passes back!" % ("White" if mover == ReversiEngine.BLACK else "Black")

func _show_result() -> void:
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	var w: int = engine.winner()
	var s: Dictionary = engine.score()
	if w == ReversiEngine.EMPTY:
		win_label.text = "It's a tie! %d - %d" % [s.black, s.white]
	else:
		win_label.text = "%s wins! %d - %d" % ["Black" if w == ReversiEngine.BLACK else "White", s.black, s.white]
	win_dialog.visible = true

# ---------- rendering ----------

func _render() -> void:
	legal_now = engine.legal_moves(engine.current_player)
	var legal_set := {}
	for m in legal_now:
		legal_set[m] = true

	for r in range(8):
		for c in range(8):
			var idx := r * 8 + c
			var v: int = engine.board[r][c]
			var piece: PanelContainer = piece_views[idx]
			if v == ReversiEngine.EMPTY:
				piece.visible = false
			else:
				piece.visible = true
				_style_piece(piece, COLOR_BLACK if v == ReversiEngine.BLACK else COLOR_WHITE)
			hint_views[idx].visible = legal_set.has(Vector2i(r, c)) and game_active

	var s: Dictionary = engine.score()
	score_label.text = "⚫ Black: %d      ⚪ White: %d" % [s.black, s.white]
	if game_active:
		status_label.text = "%s's turn" % ("Black" if engine.current_player == ReversiEngine.BLACK else "White")

func _style_square(sq: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.03, 0.15, 0.06)
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
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0, 0, 0, 0.5)
	piece.add_theme_stylebox_override("panel", sb)

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
	for row in data.board:
		var r: Array = []
		for v in row:
			r.append(int(v))
		board.append(r)
	engine.board = board
	engine.current_player = int(data.current_player)
	engine.game_over = false
	game_active = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()
	return true
