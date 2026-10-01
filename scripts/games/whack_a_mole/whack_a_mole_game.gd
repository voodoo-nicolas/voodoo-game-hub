extends Control

const WhackEngine = preload("res://scripts/games/whack_a_mole/whack_a_mole_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://whackamole_best.json"
const COLOR_HOLE := Color(0.28, 0.2, 0.13)
const COLOR_MOLE := Color(0.5, 0.32, 0.15)

var info = null  # GameInfo; null on apps without it, so guard every use
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
var pause_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/whack_a_mole/whack_a_mole_i18n.gd").install(self)
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
			time_label.text = tr("Time: %d") % ceili(engine.time_remaining)

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
	hub_btn.text = tr("Hub")
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("🔨 Whack-a-Mole")
	title.add_theme_font_size_override("font_size", 28)
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
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	stats_row.add_child(score_label)

	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 26)
	time_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	stats_row.add_child(time_label)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 26)
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
	start_btn.text = tr("Start Round")
	start_btn.custom_minimum_size = Vector2(220, 56)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.pressed.connect(_start_round)
	box.add_child(start_btn)

	_build_result_dialog()
	_build_pause_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/whack_a_mole/whack_a_mole_help.gd"))
		add_child(info)
		if best_score > 0:
			info.high("Best score", best_score)
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
	result_label.add_theme_font_size_override("font_size", 31)
	result_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		result_dialog.visible = false
		_start_round()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("Back to Hub")
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
		score_label.text = tr("Score: %d") % engine.score
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
	if info:
		info.add("Rounds played")
		info.best("Best score", best_score)
	result_label.text = tr("Time's up!\nScore: %d") % engine.score
	result_dialog.visible = true
	start_btn.visible = true
	start_btn.text = tr("Play Again")

func _update_labels() -> void:
	score_label.text = tr("Score: %d") % engine.score
	time_label.text = tr("Time: %d") % ceili(engine.time_remaining)
	best_label.text = tr("Best: %d") % best_score

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
	best_score = int(data.get("best", 0)) if data != null else 0
	if Auth.is_logged_in():
		# A method, not a lambda: if the player leaves before the reply lands,
		# a method callable on a freed scene is skipped instead of erroring.
		Auth.reconcile_stat("whackamole_best", best_score, _on_best_reconciled)

func _on_best_reconciled(merged: int) -> void:
	best_score = merged
	if info:
		info.high("Best score", merged)
	SaveUtil.write(BEST_PATH, {"best": merged})
	if is_node_ready():  # can land before _build_ui() if the request fails instantly
		_update_labels()

# ---------- auto-pause ----------

## Leaving the app (home button, a phone call) pauses mid-round instead of
## letting the game run on unseen. Pausing the whole tree stops this scene's
## Timers and _process; the dialog itself keeps processing so it can resume.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and engine.running and not get_tree().paused:
			get_tree().paused = true
			pause_dialog.visible = true

func _resume() -> void:
	get_tree().paused = false

func _exit_paused_to_hub() -> void:
	get_tree().paused = false
	Ui.exit_to_hub(self)

## Never leave the tree paused behind us -- the next scene would be frozen.
func _exit_tree() -> void:
	get_tree().paused = false

func _build_pause_dialog() -> void:
	pause_dialog = Ui.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("Exit to Hub"), "action": _exit_paused_to_hub},
	])
	pause_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_dialog)
