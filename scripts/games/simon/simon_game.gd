extends Control

const SimonEngine = preload("res://scripts/games/simon/simon_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")

const BEST_PATH := "user://simon_best.json"

const PAD_COLORS := [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.95, 0.75, 0.2), Color(0.4, 0.85, 0.4)]
const PAD_DIM := 0.45
const FLASH_DURATION := 0.4
const GAP_DURATION := 0.2

var engine
var accepting_input: bool = false
var playing_sequence: bool = false

var status_label: Label
var best_label: Label
var pads: Array = []  # 4 PanelContainer
var start_dialog: Control
var game_over_label: Label
var best_level: int = 0

func _ready() -> void:
	Orientation.lock_portrait()
	engine = SimonEngine.new()
	_build_ui()
	_load_best()
	_show_start_dialog()

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

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = "Simon"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 14)
	best_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	top_bar.add_child(best_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var viewport_width: float = get_viewport_rect().size.x
	var pad_size: float = min(280.0, floor((viewport_width - 24.0 * 2.0 - 12.0) / 2.0))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	for i in range(4):
		var pad := PanelContainer.new()
		pad.custom_minimum_size = Vector2(pad_size, pad_size)
		_set_pad_color(pad, i, false)

		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_pad_pressed.bind(i))
		pad.add_child(btn)

		grid.add_child(pad)
		pads.append(pad)

	_build_start_dialog()
	add_child(SettingsDrawer.new())

func _set_pad_color(pad: PanelContainer, i: int, lit: bool) -> void:
	var sb := StyleBoxFlat.new()
	var c: Color = PAD_COLORS[i]
	sb.bg_color = c if lit else Color(c.r * PAD_DIM, c.g * PAD_DIM, c.b * PAD_DIM)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	pad.add_theme_stylebox_override("panel", sb)

func _build_start_dialog() -> void:
	start_dialog = ColorRect.new()
	start_dialog.color = Color(0, 0, 0, 0.8)
	start_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	start_dialog.visible = false
	add_child(start_dialog)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_dialog.add_child(center)

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
	game_over_label.text = "Simon"
	game_over_label.add_theme_font_size_override("font_size", 24)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(game_over_label)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size = Vector2(200, 48)
	start_btn.pressed.connect(_start_game)
	box.add_child(start_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Back to Hub"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/hub.tscn"))
	box.add_child(menu_btn)

# ---------- game flow ----------

func _show_start_dialog() -> void:
	game_over_label.text = "Simon"
	status_label.text = "Watch, then repeat the sequence"
	start_dialog.visible = true

func _start_game() -> void:
	start_dialog.visible = false
	engine.reset()
	_next_round()

func _next_round() -> void:
	engine.next_round()
	status_label.text = "Level %d" % engine.level
	await _play_sequence()
	accepting_input = true

func _play_sequence() -> void:
	playing_sequence = true
	accepting_input = false
	for pad_index in engine.sequence:
		_set_pad_color(pads[pad_index], pad_index, true)
		await get_tree().create_timer(FLASH_DURATION).timeout
		_set_pad_color(pads[pad_index], pad_index, false)
		await get_tree().create_timer(GAP_DURATION).timeout
	playing_sequence = false

func _on_pad_pressed(i: int) -> void:
	if not accepting_input or playing_sequence:
		return
	_set_pad_color(pads[i], i, true)
	var reset_timer := get_tree().create_timer(0.15)
	reset_timer.timeout.connect(func(): _set_pad_color(pads[i], i, false))

	var result: String = engine.tap(i)
	match result:
		"correct":
			pass
		"round_complete":
			accepting_input = false
			if engine.level > best_level:
				best_level = engine.level
				_save_best()
				_update_best_label()
			var pause_timer := get_tree().create_timer(0.6)
			pause_timer.timeout.connect(_next_round)
		"wrong":
			accepting_input = false
			game_over_label.text = "Game Over — reached level %d" % engine.level
			status_label.text = ""
			start_dialog.visible = true

func _update_best_label() -> void:
	best_label.text = "Best: %d" % best_level

func _save_best() -> void:
	SaveUtil.write(BEST_PATH, {"best_level": best_level})
	if Auth.is_logged_in():
		Auth.push_stat("simon_best_level", best_level)

func _load_best() -> void:
	var data = SaveUtil.read(BEST_PATH)
	best_level = int(data.best_level) if data != null else 0
	_update_best_label()
	if Auth.is_logged_in():
		Auth.reconcile_stat("simon_best_level", best_level, func(merged: int):
			best_level = merged
			SaveUtil.write(BEST_PATH, {"best_level": merged})
			_update_best_label()
		)
