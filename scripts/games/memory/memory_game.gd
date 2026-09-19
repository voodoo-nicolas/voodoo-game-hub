extends Control

const MemoryEngine = preload("res://scripts/games/memory/memory_engine.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://memory_save.json"
const SYMBOLS := ["🍕", "🚀", "🎧", "🐼", "🌵", "⚽", "🎨", "🍩"]
const MISMATCH_DELAY := 0.7
const COLOR_HIDDEN := Color(0.18, 0.18, 0.24)
const COLOR_FLIPPED := Color(0.25, 0.5, 0.7)
const COLOR_MATCHED := Color(0.2, 0.45, 0.28)

var engine
var game_active: bool = false
var waiting_for_resolve: bool = false

var status_label: Label
var cell_buttons: Array = []  # 16 Buttons
var pause_dialog: Control
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = MemoryEngine.new()
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
	root.add_theme_constant_override("separation", 10)
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
	title.text = "Memory"
	title.add_theme_font_size_override("font_size", 22)
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

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)

	var viewport_width: float = get_viewport_rect().size.x
	var outer_margin := 20.0
	var separation := 8
	var cell_size: float = floor((viewport_width - outer_margin * 2.0 - separation * 3.0) / 4.0)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	box.add_child(grid)

	for i in range(16):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.add_theme_font_size_override("font_size", int(cell_size * 0.45))
		cell.flat = false
		cell.focus_mode = Control.FOCUS_NONE
		_style_cell(cell, COLOR_HIDDEN)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cell_buttons.append(cell)

	_build_pause_dialog()
	_build_win_dialog()
	add_child(SettingsDrawer.new())

func _style_cell(cell: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell.add_theme_stylebox_override(state, sb)

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
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
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
	waiting_for_resolve = false
	win_dialog.visible = false
	pause_dialog.visible = false
	_render()

func _on_cell_pressed(i: int) -> void:
	if not game_active or waiting_for_resolve:
		return
	var result: String = engine.flip(i)
	match result:
		"match":
			_render()
			if engine.is_over():
				_show_win()
		"mismatch":
			_render()
			waiting_for_resolve = true
			var timer := get_tree().create_timer(MISMATCH_DELAY)
			timer.timeout.connect(_on_mismatch_resolved)
		"first":
			_render()
		"ignored":
			pass

func _on_mismatch_resolved() -> void:
	engine.resolve_mismatch()
	waiting_for_resolve = false
	_render()

func _on_pause_pressed() -> void:
	if not game_active:
		return
	_save_game()
	pause_dialog.visible = true

func _show_win() -> void:
	game_active = false
	SaveUtil.delete(SAVE_PATH)
	win_label.text = "Solved in %d moves!" % engine.moves
	win_dialog.visible = true

func _render() -> void:
	for i in range(16):
		var btn: Button = cell_buttons[i]
		var face_up: bool = engine.matched[i] or engine.flipped.has(i)
		if face_up:
			btn.text = SYMBOLS[engine.deck[i]]
			_style_cell(btn, COLOR_MATCHED if engine.matched[i] else COLOR_FLIPPED)
		else:
			btn.text = ""
			_style_cell(btn, COLOR_HIDDEN)

	status_label.text = "Moves: %d" % engine.moves

# ---------- save / load ----------

func _save_game() -> void:
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {
		"deck": engine.deck,
		"matched": engine.matched,
		"moves": engine.moves,
	})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		return false
	engine.deck = []
	for v in data.deck:
		engine.deck.append(int(v))
	engine.matched = []
	for v in data.matched:
		engine.matched.append(bool(v))
	engine.moves = int(data.moves)
	engine.flipped = []

	if engine.is_over():
		return false

	game_active = true
	waiting_for_resolve = false
	_render()
	return true
