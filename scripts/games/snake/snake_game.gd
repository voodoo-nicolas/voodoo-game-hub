extends Control

const SnakeEngine = preload("res://scripts/games/snake/snake_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const BEST_PATH := "user://snake_best.json"
const GRID_SIZE := 15
const STEP_SECONDS := 0.15
const COLOR_BG := Color(0.1, 0.14, 0.1)
const COLOR_SNAKE := Color(0.3, 0.85, 0.4)
const COLOR_HEAD := Color(0.5, 0.95, 0.55)
const COLOR_FOOD := Color(0.9, 0.3, 0.3)

var engine
var best_score: int = 0
var cells: Array = []  # GRID_SIZE x GRID_SIZE Panel
var score_label: Label
var best_label: Label
var step_timer: Timer
var start_overlay: Control
var game_over_dialog: Control
var game_over_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = SnakeEngine.new()
	_load_best()
	_build_ui()
	_show_start_overlay()

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
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = "🐍 Snake"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_show_start_overlay)
	top_bar.add_child(restart_btn)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 30)
	root.add_child(stats_row)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	stats_row.add_child(score_label)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 20)
	best_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	stats_row.add_child(best_label)

	var board_center := CenterContainer.new()
	root.add_child(board_center)

	var viewport_width: float = get_viewport_rect().size.x
	var margin := 16.0
	var cell_size: float = floor((viewport_width - margin * 2.0) / GRID_SIZE)
	var board_size: float = cell_size * GRID_SIZE

	var board_panel := PanelContainer.new()
	var board_sb := StyleBoxFlat.new()
	board_sb.bg_color = COLOR_BG
	board_panel.add_theme_stylebox_override("panel", board_sb)
	board_panel.custom_minimum_size = Vector2(board_size, board_size)
	board_center.add_child(board_panel)

	var grid := GridContainer.new()
	grid.columns = GRID_SIZE
	board_panel.add_child(grid)

	for r in range(GRID_SIZE):
		var row: Array = []
		for c in range(GRID_SIZE):
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.color = COLOR_BG
			grid.add_child(cell)
			row.append(cell)
		cells.append(row)

	var pad_center := CenterContainer.new()
	pad_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pad_center)
	pad_center.add_child(_build_dpad())

	step_timer = Timer.new()
	step_timer.wait_time = STEP_SECONDS
	step_timer.timeout.connect(_on_step)
	add_child(step_timer)

	_build_start_overlay()
	_build_game_over_dialog()
	add_child(SettingsDrawer.new())

func _build_dpad() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)

	var blank1 := Control.new()
	blank1.custom_minimum_size = Vector2(64, 64)
	grid.add_child(blank1)
	grid.add_child(_dpad_button("▲", SnakeEngine.Dir.UP))
	var blank2 := Control.new()
	blank2.custom_minimum_size = Vector2(64, 64)
	grid.add_child(blank2)

	grid.add_child(_dpad_button("◀", SnakeEngine.Dir.LEFT))
	var blank3 := Control.new()
	blank3.custom_minimum_size = Vector2(64, 64)
	grid.add_child(blank3)
	grid.add_child(_dpad_button("▶", SnakeEngine.Dir.RIGHT))

	var blank4 := Control.new()
	blank4.custom_minimum_size = Vector2(64, 64)
	grid.add_child(blank4)
	grid.add_child(_dpad_button("▼", SnakeEngine.Dir.DOWN))
	var blank5 := Control.new()
	blank5.custom_minimum_size = Vector2(64, 64)
	grid.add_child(blank5)

	return grid

func _dpad_button(label_text: String, dir: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(64, 64)
	btn.add_theme_font_size_override("font_size", 24)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): engine.set_direction(dir))
	return btn

func _build_start_overlay() -> void:
	start_overlay = ColorRect.new()
	start_overlay.color = Color(0, 0, 0, 0.8)
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.visible = false
	add_child(start_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var label := Label.new()
	label.text = "🐍 Snake"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size = Vector2(200, 56)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_start_game)
	box.add_child(start_btn)

func _build_game_over_dialog() -> void:
	game_over_dialog = ColorRect.new()
	game_over_dialog.color = Color(0, 0, 0, 0.75)
	game_over_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_dialog.visible = false
	add_child(game_over_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_dialog.add_child(center)

	var panel := PanelContainer.new()
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
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	game_over_label = Label.new()
	game_over_label.add_theme_font_size_override("font_size", 24)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(game_over_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		game_over_dialog.visible = false
		_start_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

# ---------- game flow ----------

func _show_start_overlay() -> void:
	step_timer.stop()
	game_over_dialog.visible = false
	start_overlay.visible = true

func _start_game() -> void:
	engine.reset(GRID_SIZE)
	start_overlay.visible = false
	game_over_dialog.visible = false
	_render()
	step_timer.start()

func _on_step() -> void:
	var ended: bool = engine.step()
	_render()
	if ended:
		step_timer.stop()
		if engine.score > best_score:
			best_score = engine.score
			_save_best()
			_render()
		game_over_label.text = "Game Over!\nScore: %d" % engine.score
		game_over_dialog.visible = true

func _render() -> void:
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			cells[r][c].color = COLOR_BG
	for i in range(engine.snake.size()):
		var seg: Vector2i = engine.snake[i]
		cells[seg.y][seg.x].color = COLOR_HEAD if i == 0 else COLOR_SNAKE
	if engine.food.x >= 0:
		cells[engine.food.y][engine.food.x].color = COLOR_FOOD
	score_label.text = "Score: %d" % engine.score
	best_label.text = "Best: %d" % best_score

# ---------- persistence ----------

func _save_best() -> void:
	SaveUtil.write(BEST_PATH, {"best": best_score})

func _load_best() -> void:
	var data = SaveUtil.read(BEST_PATH)
	best_score = int(data.best) if data != null else 0
