extends Control

const WhackEngine = preload("res://scripts/games/whack_a_mole/whack_a_mole_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const BEST_PATH := "user://whackamole_best.json"
const COLOR_HOLE := Color(0.28, 0.2, 0.13)
const COLOR_MOLE := Color(0.5, 0.32, 0.15)

var engine
var best_score: int = 0
var hole_buttons: Array = []
var mole_labels: Array = []
var score_label: Label
var time_label: Label
var best_label: Label
var start_btn: Button
var result_dialog: Control
var result_label: Label
var mole_timer: Timer
var mole_visible_timer: Timer

func _ready() -> void:
	Orientation.lock_portrait()
	engine = WhackEngine.new()
	engine.running = false
	_load_best()
	_build_ui()
	_update_labels()

func _process(delta: float) -> void:
	if engine.running:
		if engine.tick(delta):
			_end_round()
		else:
			time_label.text = "Time: %d" % ceili(engine.time_remaining)

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
	top_margin.add_child(top_bar)

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = "🔨 Whack-a-Mole"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(spacer)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 30)
	root.add_child(stats_row)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	stats_row.add_child(score_label)

	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	stats_row.add_child(time_label)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 20)
	best_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	stats_row.add_child(best_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var viewport_width: float = get_viewport_rect().size.x
	var outer_margin := 30.0
	var separation := 10
	var hole_size: float = floor((viewport_width - outer_margin * 2.0 - separation * 2.0) / 3.0)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	box.add_child(grid)

	for i in range(WhackEngine.HOLE_COUNT):
		var hole := Button.new()
		hole.custom_minimum_size = Vector2(hole_size, hole_size)
		hole.flat = false
		hole.focus_mode = Control.FOCUS_NONE
		_style_hole(hole, COLOR_HOLE)
		hole.pressed.connect(_on_hole_pressed.bind(i))
		grid.add_child(hole)
		hole_buttons.append(hole)

		var mole := Label.new()
		mole.text = "🐹"
		mole.set_anchors_preset(Control.PRESET_FULL_RECT)
		mole.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mole.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mole.add_theme_font_size_override("font_size", int(hole_size * 0.55))
		mole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mole.visible = false
		hole.add_child(mole)
		mole_labels.append(mole)

	start_btn = Button.new()
	start_btn.text = "Start Round"
	start_btn.custom_minimum_size = Vector2(220, 56)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_start_round)
	box.add_child(start_btn)

	_build_result_dialog()
	add_child(SettingsDrawer.new())

func _build_result_dialog() -> void:
	result_dialog = ColorRect.new()
	result_dialog.color = Color(0, 0, 0, 0.75)
	result_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.visible = false
	add_child(result_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_dialog.add_child(center)

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

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 24)
	result_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_label)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		result_dialog.visible = false
		_start_round()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_round() -> void:
	engine.reset()
	result_dialog.visible = false
	start_btn.visible = false
	for m in mole_labels:
		m.visible = false
	_update_labels()
	_schedule_next_pop()

func _schedule_next_pop() -> void:
	if not engine.running:
		return
	if is_instance_valid(mole_timer):
		mole_timer.queue_free()
	mole_timer = Timer.new()
	mole_timer.wait_time = randf_range(0.5, 1.1)
	mole_timer.one_shot = true
	add_child(mole_timer)
	mole_timer.timeout.connect(_pop_mole)
	mole_timer.start()

func _pop_mole() -> void:
	if not engine.running:
		return
	var hole: int = engine.pop_random_hole()
	mole_labels[hole].visible = true

	if is_instance_valid(mole_visible_timer):
		mole_visible_timer.queue_free()
	mole_visible_timer = Timer.new()
	mole_visible_timer.wait_time = randf_range(0.6, 0.9)
	mole_visible_timer.one_shot = true
	add_child(mole_visible_timer)
	mole_visible_timer.timeout.connect(_on_mole_timeout)
	mole_visible_timer.start()

func _on_mole_timeout() -> void:
	if engine.active_hole >= 0:
		mole_labels[engine.active_hole].visible = false
		engine.hide_mole()
	_schedule_next_pop()

func _on_hole_pressed(hole: int) -> void:
	if not engine.running:
		return
	if engine.whack(hole):
		mole_labels[hole].visible = false
		score_label.text = "Score: %d" % engine.score
		_schedule_next_pop()

func _end_round() -> void:
	for m in mole_labels:
		m.visible = false
	if is_instance_valid(mole_timer):
		mole_timer.queue_free()
	if is_instance_valid(mole_visible_timer):
		mole_visible_timer.queue_free()

	if engine.score > best_score:
		best_score = engine.score
		_save_best()

	_update_labels()
	result_label.text = "Time's up!\nScore: %d" % engine.score
	result_dialog.visible = true
	start_btn.visible = true
	start_btn.text = "Play Again"

func _update_labels() -> void:
	score_label.text = "Score: %d" % engine.score
	time_label.text = "Time: %d" % ceili(engine.time_remaining)
	best_label.text = "Best: %d" % best_score

func _style_hole(hole: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	var radius: int = int(hole.custom_minimum_size.x * 0.2)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		hole.add_theme_stylebox_override(state, sb)

# ---------- persistence ----------

func _save_best() -> void:
	SaveUtil.write(BEST_PATH, {"best": best_score})
	if Auth.is_logged_in():
		Auth.push_stat("whackamole_best", best_score)

func _load_best() -> void:
	var data = SaveUtil.read(BEST_PATH)
	best_score = int(data.best) if data != null else 0
	if Auth.is_logged_in():
		Auth.reconcile_stat("whackamole_best", best_score, func(merged: int):
			best_score = merged
			SaveUtil.write(BEST_PATH, {"best": merged})
			_update_labels()
		)
