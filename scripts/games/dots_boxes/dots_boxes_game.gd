extends Control

const DotsBoxesEngine = preload("res://scripts/games/dots_boxes/dots_boxes_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const SAVE_PATH := "user://dots_boxes_save.json"

const COLOR_P1 := Color(0.25, 0.55, 0.95)   # blue
const COLOR_P2 := Color(0.9, 0.25, 0.3)     # red
const COLOR_DOT := Color(0.92, 0.92, 0.95)
const COLOR_EDGE_HIDDEN := Color(1, 1, 1, 0)
const COLOR_HOVER := Color(1, 1, 1, 0.35)
const COLOR_SELECTED := Color(1, 0.85, 0.2, 0.95)
const COLOR_BOX_FILL_ALPHA := 0.5
const BOARD_PADDING := 10.0
const AI_PLAYER := 2
const AI_MOVE_DELAY := 0.7

const SIZE_OPTIONS := [
	{"label": "5 × 5", "rows": 5, "cols": 5},
	{"label": "7 × 7", "rows": 7, "cols": 7},
	{"label": "10 × 10", "rows": 10, "cols": 10},
]

var engine
var rows: int = 5
var cols: int = 5
var game_active: bool = false
var vs_computer: bool = false
var pending_vs_computer: bool = false
var ai_thinking: bool = false
var touch_mode: bool = false
var selected_edge: Variant = null  # {"o","r","c"} or null

var size_screen: Control
var game_screen: Control
var board_slot: CenterContainer
var board_wrap: Control

var mode_2p_tab: Button
var mode_cpu_tab: Button

var status_label: Label
var score_p1_label: Label
var score_p2_label: Label
var confirm_btn: Button
var pause_dialog: Control
var win_dialog: Control
var win_label: Label

var h_buttons: Array = []   # [r][c] Button, r in 0..rows, c in 0..cols-1
var v_buttons: Array = []   # [r][c] Button, r in 0..rows-1, c in 0..cols
var h_lines_view: Array = []
var v_lines_view: Array = []
var box_panels: Array = []  # [r][c] ColorRect

func _ready() -> void:
	Orientation.lock_portrait()
	touch_mode = DisplayServer.is_touchscreen_available()
	engine = DotsBoxesEngine.new()
	_build_ui()
	if not _load_saved_game():
		_show_size_screen()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_size_screen()
	_build_game_screen()
	_build_pause_dialog()
	_build_win_dialog()
	add_child(SettingsDrawer.new())

func _build_size_screen() -> void:
	size_screen = Control.new()
	size_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(size_screen)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	size_screen.add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_margin.add_child(hub_btn)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "Dots and Boxes"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	box.add_child(mode_row)

	mode_2p_tab = Button.new()
	mode_2p_tab.text = "2 Players"
	mode_2p_tab.custom_minimum_size = Vector2(0, 44)
	mode_2p_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_2p_tab.focus_mode = Control.FOCUS_NONE
	mode_2p_tab.pressed.connect(func(): _set_pending_mode(false))
	mode_row.add_child(mode_2p_tab)

	mode_cpu_tab = Button.new()
	mode_cpu_tab.text = "vs Computer"
	mode_cpu_tab.custom_minimum_size = Vector2(0, 44)
	mode_cpu_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_cpu_tab.focus_mode = Control.FOCUS_NONE
	mode_cpu_tab.pressed.connect(func(): _set_pending_mode(true))
	mode_row.add_child(mode_cpu_tab)

	var subtitle := Label.new()
	subtitle.text = "Choose a board size"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	for opt in SIZE_OPTIONS:
		var btn := Button.new()
		btn.text = opt.label
		btn.custom_minimum_size = Vector2(220, 52)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_start_new_game.bind(opt.rows, opt.cols))
		box.add_child(btn)

	_set_pending_mode(false)

func _set_pending_mode(is_cpu: bool) -> void:
	pending_vs_computer = is_cpu
	_style_mode_tab(mode_2p_tab, not is_cpu)
	_style_mode_tab(mode_cpu_tab, is_cpu)

func _style_mode_tab(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.45, 0.28) if active else Color(0.16, 0.16, 0.2)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.15, 1.0, 0.55) if active else Color(0.35, 0.35, 0.4)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1) if active else Color(0.65, 0.65, 0.7))

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.visible = false
	add_child(game_screen)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	game_screen.add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_bar)

	var pause_btn := Button.new()
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(func(): _start_new_game(rows, cols))
	top_bar.add_child(restart_btn)

	var title := Label.new()
	title.text = "Dots and Boxes"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	top_bar.add_child(spacer)

	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 40)
	root.add_child(score_row)

	score_p1_label = Label.new()
	score_p1_label.add_theme_font_size_override("font_size", 20)
	score_p1_label.add_theme_color_override("font_color", COLOR_P1)
	score_row.add_child(score_p1_label)

	score_p2_label = Label.new()
	score_p2_label.add_theme_font_size_override("font_size", 20)
	score_p2_label.add_theme_color_override("font_color", COLOR_P2)
	score_row.add_child(score_p2_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	confirm_btn = Button.new()
	confirm_btn.text = "Confirm Line"
	confirm_btn.custom_minimum_size = Vector2(0, 44)
	confirm_btn.disabled = true
	confirm_btn.visible = touch_mode
	confirm_btn.pressed.connect(_on_confirm_pressed)
	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 40)
	confirm_margin.add_theme_constant_override("margin_right", 40)
	confirm_margin.add_child(confirm_btn)
	root.add_child(confirm_margin)

	board_slot = CenterContainer.new()
	board_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board_slot)

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
	resume_btn.pressed.connect(func():
		pause_dialog.visible = false
		_maybe_ai_move()
	)
	box.add_child(resume_btn)

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.custom_minimum_size = Vector2(200, 44)
	new_game_btn.pressed.connect(func():
		pause_dialog.visible = false
		game_active = false
		SaveUtil.delete(SAVE_PATH)
		game_screen.visible = false
		_show_size_screen()
	)
	box.add_child(new_game_btn)

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
	win_label.add_theme_font_size_override("font_size", 22)
	win_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	win_label.custom_minimum_size = Vector2(220, 0)
	box.add_child(win_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again (Same Setup)"
	again_btn.custom_minimum_size = Vector2(240, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game(rows, cols)
	)
	box.add_child(again_btn)

	var new_size_btn := Button.new()
	new_size_btn.text = "Change Board Size"
	new_size_btn.custom_minimum_size = Vector2(240, 44)
	new_size_btn.pressed.connect(func():
		win_dialog.visible = false
		game_screen.visible = false
		_show_size_screen()
	)
	box.add_child(new_size_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(240, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

# ---------- game flow ----------

func _show_size_screen() -> void:
	size_screen.visible = true
	game_screen.visible = false

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

func _player_label(player: int) -> String:
	if player == 1:
		return "Blue"
	return "Computer" if vs_computer else "Red"

func _start_new_game(p_rows: int, p_cols: int) -> void:
	rows = p_rows
	cols = p_cols
	vs_computer = pending_vs_computer
	engine.reset(rows, cols)
	game_active = true
	selected_edge = null
	ai_thinking = false
	size_screen.visible = false
	game_screen.visible = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_build_board()
	_render()

func _on_edge_pressed(orientation: String, r: int, c: int) -> void:
	if not game_active or pause_dialog.visible:
		return
	if vs_computer and engine.current_player == AI_PLAYER:
		return
	var taken: bool = engine.is_h_taken(r, c) if orientation == "h" else engine.is_v_taken(r, c)
	if taken:
		return
	if touch_mode:
		selected_edge = {"o": orientation, "r": r, "c": c}
		_render()
	else:
		_commit_edge(orientation, r, c)

func _on_confirm_pressed() -> void:
	if selected_edge == null:
		return
	var o: String = selected_edge.o
	var r: int = selected_edge.r
	var c: int = selected_edge.c
	selected_edge = null
	_commit_edge(o, r, c)

func _commit_edge(orientation: String, r: int, c: int) -> void:
	var res: Dictionary = engine.play_line(orientation, r, c)
	if not res.valid:
		return
	_render()
	if engine.game_over:
		_show_result()
		return
	_maybe_ai_move()

func _maybe_ai_move() -> void:
	if not game_active or pause_dialog.visible or not vs_computer or engine.current_player != AI_PLAYER:
		return
	ai_thinking = true
	_render()
	await get_tree().create_timer(AI_MOVE_DELAY).timeout
	ai_thinking = false
	if not game_active or pause_dialog.visible:
		return
	var m: Dictionary = engine.pick_ai_move()
	var res: Dictionary = engine.play_line(m.o, m.r, m.c)
	if not res.valid:
		return
	_render()
	if engine.game_over:
		_show_result()
		return
	_maybe_ai_move()

func _on_edge_mouse_entered(orientation: String, r: int, c: int, line: ColorRect) -> void:
	if touch_mode or not game_active:
		return
	if vs_computer and engine.current_player == AI_PLAYER:
		return
	if _edge_owner(orientation, r, c) == 0:
		line.color = COLOR_HOVER

func _on_edge_mouse_exited(orientation: String, r: int, c: int, line: ColorRect) -> void:
	if touch_mode:
		return
	line.color = _owner_color(_edge_owner(orientation, r, c))

func _edge_owner(orientation: String, r: int, c: int) -> int:
	return engine.h_lines[r][c] if orientation == "h" else engine.v_lines[r][c]

func _show_result() -> void:
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	var p1 := _player_label(1)
	var p2 := _player_label(2)
	if engine.winner == 0:
		win_label.text = "It's a tie!\n%s %d - %s %d" % [p1, engine.scores[1], p2, engine.scores[2]]
	else:
		var name := _player_label(engine.winner)
		win_label.text = "%s wins!\n%s %d - %s %d" % [name, p1, engine.scores[1], p2, engine.scores[2]]
	win_dialog.visible = true

# ---------- board construction ----------

func _build_board() -> void:
	if board_wrap:
		board_wrap.queue_free()

	var viewport_width: float = get_viewport_rect().size.x
	var board_margin := 12.0
	var max_dim: int = max(rows, cols)
	var cell_size: float = floor((viewport_width - board_margin * 2.0 - BOARD_PADDING * 2.0) / max_dim)
	var board_w: float = cell_size * cols + BOARD_PADDING * 2.0
	var board_h: float = cell_size * rows + BOARD_PADDING * 2.0
	var touch_thickness: float = max(20.0, cell_size * 0.32)
	var line_thickness: float = max(4.0, cell_size * 0.07)
	var dot_size: float = max(8.0, cell_size * 0.14)

	board_wrap = Control.new()
	board_wrap.custom_minimum_size = Vector2(board_w, board_h)
	board_slot.add_child(board_wrap)

	box_panels = []
	for r in range(rows):
		var row: Array = []
		for c in range(cols):
			var panel := ColorRect.new()
			panel.color = COLOR_EDGE_HIDDEN
			panel.position = Vector2(BOARD_PADDING + c * cell_size, BOARD_PADDING + r * cell_size)
			panel.size = Vector2(cell_size, cell_size)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_wrap.add_child(panel)
			row.append(panel)
		box_panels.append(row)

	h_buttons = []
	h_lines_view = []
	for r in range(rows + 1):
		var brow: Array = []
		var vrow: Array = []
		for c in range(cols):
			var btn := Button.new()
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.position = Vector2(BOARD_PADDING + c * cell_size, BOARD_PADDING + r * cell_size - touch_thickness / 2.0)
			btn.size = Vector2(cell_size, touch_thickness)
			_style_edge_button(btn)
			btn.pressed.connect(_on_edge_pressed.bind("h", r, c))
			board_wrap.add_child(btn)

			var line := ColorRect.new()
			line.color = COLOR_EDGE_HIDDEN
			line.position = Vector2(0, (touch_thickness - line_thickness) / 2.0)
			line.size = Vector2(cell_size, line_thickness)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(line)
			btn.mouse_entered.connect(_on_edge_mouse_entered.bind("h", r, c, line))
			btn.mouse_exited.connect(_on_edge_mouse_exited.bind("h", r, c, line))

			brow.append(btn)
			vrow.append(line)
		h_buttons.append(brow)
		h_lines_view.append(vrow)

	v_buttons = []
	v_lines_view = []
	for r in range(rows):
		var brow2: Array = []
		var vrow2: Array = []
		for c in range(cols + 1):
			var btn := Button.new()
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.position = Vector2(BOARD_PADDING + c * cell_size - touch_thickness / 2.0, BOARD_PADDING + r * cell_size)
			btn.size = Vector2(touch_thickness, cell_size)
			_style_edge_button(btn)
			btn.pressed.connect(_on_edge_pressed.bind("v", r, c))
			board_wrap.add_child(btn)

			var line := ColorRect.new()
			line.color = COLOR_EDGE_HIDDEN
			line.position = Vector2((touch_thickness - line_thickness) / 2.0, 0)
			line.size = Vector2(line_thickness, cell_size)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(line)
			btn.mouse_entered.connect(_on_edge_mouse_entered.bind("v", r, c, line))
			btn.mouse_exited.connect(_on_edge_mouse_exited.bind("v", r, c, line))

			brow2.append(btn)
			vrow2.append(line)
		v_buttons.append(brow2)
		v_lines_view.append(vrow2)

	for r in range(rows + 1):
		for c in range(cols + 1):
			var dot := ColorRect.new()
			dot.color = COLOR_DOT
			dot.position = Vector2(BOARD_PADDING + c * cell_size - dot_size / 2.0, BOARD_PADDING + r * cell_size - dot_size / 2.0)
			dot.size = Vector2(dot_size, dot_size)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_wrap.add_child(dot)

func _style_edge_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, sb)

# ---------- rendering ----------

func _render() -> void:
	for r in range(rows + 1):
		for c in range(cols):
			h_lines_view[r][c].color = _owner_color(engine.h_lines[r][c])
	for r in range(rows):
		for c in range(cols + 1):
			v_lines_view[r][c].color = _owner_color(engine.v_lines[r][c])
	for r in range(rows):
		for c in range(cols):
			var box_owner_val: int = engine.box_owner[r][c]
			if box_owner_val == 0:
				box_panels[r][c].color = COLOR_EDGE_HIDDEN
			else:
				var col: Color = COLOR_P1 if box_owner_val == 1 else COLOR_P2
				box_panels[r][c].color = Color(col.r, col.g, col.b, COLOR_BOX_FILL_ALPHA)

	if touch_mode and selected_edge != null:
		var sel: Dictionary = selected_edge
		var sel_line: ColorRect = h_lines_view[sel.r][sel.c] if sel.o == "h" else v_lines_view[sel.r][sel.c]
		sel_line.color = COLOR_SELECTED

	score_p1_label.text = "%s: %d" % [_player_label(1), engine.scores[1]]
	score_p2_label.text = "%s: %d" % [_player_label(2), engine.scores[2]]

	if touch_mode:
		confirm_btn.disabled = selected_edge == null

	if not game_active:
		return
	if vs_computer and engine.current_player == AI_PLAYER and ai_thinking:
		status_label.add_theme_color_override("font_color", COLOR_P2)
		status_label.text = "Computer is thinking..."
	else:
		var turn_color: Color = COLOR_P1 if engine.current_player == 1 else COLOR_P2
		status_label.add_theme_color_override("font_color", turn_color)
		status_label.text = "%s's turn" % _player_label(engine.current_player)

func _owner_color(line_owner: int) -> Color:
	if line_owner == 0:
		return COLOR_EDGE_HIDDEN
	return COLOR_P1 if line_owner == 1 else COLOR_P2

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {
		"rows": rows,
		"cols": cols,
		"vs_computer": vs_computer,
		"h_lines": engine.h_lines,
		"v_lines": engine.v_lines,
		"box_owner": engine.box_owner,
		"current_player": engine.current_player,
		"scores": {"1": engine.scores[1], "2": engine.scores[2]},
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false
	rows = int(data.rows)
	cols = int(data.cols)
	vs_computer = bool(data.get("vs_computer", false))
	engine.rows = rows
	engine.cols = cols
	engine.h_lines = _to_int_grid(data.h_lines)
	engine.v_lines = _to_int_grid(data.v_lines)
	engine.box_owner = _to_int_grid(data.box_owner)
	engine.current_player = int(data.current_player)
	engine.scores = {1: int(data.scores["1"]), 2: int(data.scores["2"])}
	engine.game_over = false
	engine.winner = 0

	game_active = true
	selected_edge = null
	ai_thinking = false
	size_screen.visible = false
	game_screen.visible = true
	win_dialog.visible = false
	pause_dialog.visible = false
	_build_board()
	_render()
	_maybe_ai_move()
	return true

func _to_int_grid(grid: Array) -> Array:
	var out: Array = []
	for row in grid:
		var r: Array = []
		for v in row:
			r.append(int(v))
		out.append(r)
	return out
