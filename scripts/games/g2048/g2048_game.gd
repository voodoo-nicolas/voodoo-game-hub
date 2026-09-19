extends Control

const G2048Engine = preload("res://scripts/games/g2048/g2048_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://g2048_save.json"
const BOARD_SEPARATION := 6
const BOARD_PADDING := 8
const BOARD_OUTER_MARGIN := 16.0
const SWIPE_MIN_DISTANCE := 24.0

const TILE_COLORS := {
	0: Color(0.15, 0.15, 0.19),
	2: Color(0.23, 0.23, 0.28),
	4: Color(0.27, 0.27, 0.34),
	8: Color(1.0, 0.76, 0.29),
	16: Color(1.0, 0.66, 0.29),
	32: Color(1.0, 0.56, 0.36),
	64: Color(1.0, 0.42, 0.36),
	128: Color(0.18, 0.85, 0.77),
	256: Color(0.37, 0.78, 1.0),
	512: Color(0.69, 0.55, 1.0),
	1024: Color(1.0, 0.56, 0.78),
	2048: Color(0.71, 0.95, 0.41),
}

var engine
var game_active: bool = false
var tile_size: float = 76.0
var shown_2048_banner: bool = false

var score_label: Label
var tile_labels: Array = []  # 4x4 of Label
var tile_panels: Array = []  # 4x4 of PanelContainer
var pause_dialog: Control
var end_dialog: Control
var end_title: Label
var end_buttons_box: VBoxContainer

var touch_start: Vector2 = Vector2.ZERO
var touch_active: bool = false

func _ready() -> void:
	Orientation.lock_portrait()
	engine = G2048Engine.new()
	_build_ui()
	if not _load_saved_game():
		_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _input(event: InputEvent) -> void:
	if not game_active:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: _try_move("left")
			KEY_RIGHT: _try_move("right")
			KEY_UP: _try_move("up")
			KEY_DOWN: _try_move("down")

	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			touch_active = true
		elif touch_active:
			touch_active = false
			var delta: Vector2 = event.position - touch_start
			if delta.length() >= SWIPE_MIN_DISTANCE:
				if abs(delta.x) > abs(delta.y):
					_try_move("right" if delta.x > 0 else "left")
				else:
					_try_move("down" if delta.y > 0 else "up")

func _try_move(dir: String) -> void:
	if engine.move(dir):
		_render()
		if not shown_2048_banner and engine.has_2048():
			shown_2048_banner = true
			_show_end("You reached 2048!", true)
		elif not engine.can_move():
			_show_end("Game Over", false)

# ---------- UI construction ----------

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
	title.text = "2048"
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

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(score_label)

	var hint := Label.new()
	hint.text = "Swipe or use arrow keys"
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var viewport_width: float = get_viewport_rect().size.x
	var available: float = viewport_width - BOARD_OUTER_MARGIN * 2.0 - BOARD_PADDING * 2.0
	tile_size = floor((available - BOARD_SEPARATION * (G2048Engine.SIZE - 1)) / G2048Engine.SIZE)

	var board_panel := PanelContainer.new()
	var board_sb := StyleBoxFlat.new()
	board_sb.bg_color = Color(0.1, 0.1, 0.13)
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
	grid.columns = G2048Engine.SIZE
	grid.add_theme_constant_override("h_separation", BOARD_SEPARATION)
	grid.add_theme_constant_override("v_separation", BOARD_SEPARATION)
	board_panel.add_child(grid)

	for r in range(G2048Engine.SIZE):
		var label_row: Array = []
		var panel_row: Array = []
		for c in range(G2048Engine.SIZE):
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(tile_size, tile_size)
			var sb := StyleBoxFlat.new()
			sb.bg_color = TILE_COLORS[0]
			sb.corner_radius_top_left = 8
			sb.corner_radius_top_right = 8
			sb.corner_radius_bottom_left = 8
			sb.corner_radius_bottom_right = 8
			panel.add_theme_stylebox_override("panel", sb)

			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", int(tile_size * 0.4))
			panel.add_child(label)

			grid.add_child(panel)
			label_row.append(label)
			panel_row.append(panel)
		tile_labels.append(label_row)
		tile_panels.append(panel_row)

	_build_pause_dialog()
	_build_end_dialog()
	add_child(SettingsDrawer.new())

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
	title.add_theme_font_size_override("font_size", 33)
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

func _build_end_dialog() -> void:
	end_dialog = ColorRect.new()
	end_dialog.color = Color(0, 0, 0, 0.75)
	end_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_dialog.visible = false
	add_child(end_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_dialog.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)

	end_buttons_box = VBoxContainer.new()
	end_buttons_box.add_theme_constant_override("separation", 14)
	panel.add_child(end_buttons_box)

	end_title = Label.new()
	end_title.add_theme_font_size_override("font_size", 31)
	end_title.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_buttons_box.add_child(end_title)

# ---------- game flow ----------

func _start_new_game() -> void:
	engine.reset()
	game_active = true
	shown_2048_banner = false
	end_dialog.visible = false
	pause_dialog.visible = false
	_render()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

func _show_end(title: String, can_continue: bool) -> void:
	if not can_continue:
		game_active = false
		SaveUtil.delete(SAVE_PATH)

	end_title.text = "%s\nScore: %d" % [title, engine.score]

	for child in end_buttons_box.get_children():
		if child != end_title:
			end_buttons_box.remove_child(child)
			child.queue_free()

	if can_continue:
		var continue_btn := Button.new()
		continue_btn.text = "Keep Going"
		continue_btn.custom_minimum_size = Vector2(200, 48)
		continue_btn.pressed.connect(func(): end_dialog.visible = false)
		end_buttons_box.add_child(continue_btn)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 44)
	again_btn.pressed.connect(func():
		end_dialog.visible = false
		_start_new_game()
	)
	end_buttons_box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	end_buttons_box.add_child(menu_btn)

	end_dialog.visible = true

func _render() -> void:
	for r in range(G2048Engine.SIZE):
		for c in range(G2048Engine.SIZE):
			var v: int = engine.grid[r][c]
			var color: Color = TILE_COLORS.get(v, Color(0.71, 0.95, 0.41))
			var sb := StyleBoxFlat.new()
			sb.bg_color = color
			sb.corner_radius_top_left = 8
			sb.corner_radius_top_right = 8
			sb.corner_radius_bottom_left = 8
			sb.corner_radius_bottom_right = 8
			tile_panels[r][c].add_theme_stylebox_override("panel", sb)
			var text: String = str(v) if v != 0 else ""
			tile_labels[r][c].text = text
			tile_labels[r][c].add_theme_color_override("font_color", Color(0.2, 0.2, 0.2) if v != 0 and v <= 4 else Color(1, 1, 1))
			var scale: float = 0.4 if text.length() <= 2 else (0.32 if text.length() == 3 else 0.26)
			tile_labels[r][c].add_theme_font_size_override("font_size", int(tile_size * scale))

	score_label.text = "Score: %d" % engine.score

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {"grid": engine.grid, "score": engine.score, "shown_2048_banner": shown_2048_banner})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false
	var grid: Array = []
	for row in data.grid:
		var r: Array = []
		for v in row:
			r.append(int(v))
		grid.append(r)
	engine.grid = grid
	engine.score = int(data.score)
	shown_2048_banner = bool(data.get("shown_2048_banner", false))
	game_active = engine.can_move()
	_render()
	return game_active
