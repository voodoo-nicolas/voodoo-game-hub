extends Control

## Minesweeper. Tap to dig; switch the mode button to 🚩 to place flags
## instead (right-click also flags, for desktop). Tapping a revealed number
## whose flags are all placed digs its remaining neighbors.

const MinesweeperEngine = preload("res://scripts/games/minesweeper/minesweeper_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")

const BEST_PATH := "user://minesweeper_best.json"
const COLOR_BG := Color(0.09, 0.09, 0.13)
const COLOR_HIDDEN := Color(0.3, 0.36, 0.48)
const COLOR_REVEALED := Color(0.82, 0.84, 0.88)
const COLOR_EXPLODED := Color(0.9, 0.25, 0.25)
const NUMBER_COLORS := [
	Color(0, 0, 0), Color(0.1, 0.3, 0.9), Color(0.1, 0.55, 0.15), Color(0.85, 0.15, 0.15),
	Color(0.2, 0.1, 0.6), Color(0.55, 0.1, 0.1), Color(0.1, 0.5, 0.55), Color(0.1, 0.1, 0.1), Color(0.4, 0.4, 0.4),
]

var engine
var difficulty: String = "easy"
var flag_mode: bool = false
var elapsed: float = 0.0
var timer_running: bool = false
var best_times: Dictionary = {}

var start_screen: Control
var game_screen: Control
var grid: GridContainer
var cells: Array = []  # rows x cols Button
var mines_label: Label
var time_label: Label
var mode_btn: Button
var result_dialog: Control
var result_label: Label

func _ready() -> void:
	Orientation.lock_portrait()
	engine = MinesweeperEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	best_times = data if data != null else {}
	_build_ui()
	_show_start_screen()

func _process(delta: float) -> void:
	if timer_running:
		elapsed += delta
		time_label.text = "⏱ %s" % _format_time(elapsed)

func _format_time(s: float) -> String:
	var total := int(s)
	return "%02d:%02d" % [int(total / 60), total % 60]

# ---------- UI ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_start_screen()
	_build_game_screen()

	result_dialog = UI.build_dialog("", [
		{"text": "Play Again", "action": _restart},
		{"text": "Change Difficulty", "action": _show_start_screen},
		{"text": "Back to Hub", "action": UI.exit_to_hub.bind(self)},
	], true)
	result_label = result_dialog.get_meta("message_label")
	add_child(result_dialog)

	add_child(SettingsDrawer.new())

func _top_bar(parent: Control, show_new: bool) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	parent.add_child(margin)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	margin.add_child(bar)

	var hub_btn := Button.new()
	hub_btn.text = "Hub"
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)

	var title := Label.new()
	title.text = "💣 Minesweeper"
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)

	if show_new:
		var new_btn := Button.new()
		new_btn.text = "New"
		new_btn.add_theme_font_size_override("font_size", 26)
		new_btn.pressed.connect(_show_start_screen)
		bar.add_child(new_btn)

func _build_start_screen() -> void:
	start_screen = VBoxContainer.new()
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_screen.add_theme_constant_override("separation", 24)
	add_child(start_screen)
	_top_bar(start_screen, false)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	start_screen.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var prompt := Label.new()
	prompt.text = "Choose a board"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(prompt)

	for d in ["easy", "medium", "hard"]:
		var spec: Dictionary = MinesweeperEngine.DIFFICULTIES[d]
		var btn := Button.new()
		btn.text = "%s  —  %d×%d, %d mines" % [d.capitalize(), spec.rows, spec.cols, spec.mines]
		btn.custom_minimum_size = Vector2(520, 96)
		btn.add_theme_font_size_override("font_size", 30)
		btn.pressed.connect(_start_game.bind(d))
		box.add_child(btn)

	var hint := Label.new()
	hint.text = "Tap to dig. Switch to 🚩 mode to flag mines.\nTap a number with all its flags placed to clear around it."
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func _build_game_screen() -> void:
	game_screen = VBoxContainer.new()
	game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_screen.add_theme_constant_override("separation", 18)
	add_child(game_screen)
	_top_bar(game_screen, true)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 60)
	game_screen.add_child(stats)
	mines_label = Label.new()
	mines_label.add_theme_font_size_override("font_size", 32)
	stats.add_child(mines_label)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 32)
	stats.add_child(time_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_screen.add_child(center)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	center.add_child(grid)

	var mode_margin := MarginContainer.new()
	mode_margin.add_theme_constant_override("margin_bottom", 40)
	game_screen.add_child(mode_margin)
	var mode_center := CenterContainer.new()
	mode_margin.add_child(mode_center)
	mode_btn = Button.new()
	mode_btn.custom_minimum_size = Vector2(360, 96)
	mode_btn.add_theme_font_size_override("font_size", 34)
	mode_btn.focus_mode = Control.FOCUS_NONE
	mode_btn.pressed.connect(_toggle_mode)
	mode_center.add_child(mode_btn)

func _build_board() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cells = []
	grid.columns = engine.cols
	var width: float = get_viewport_rect().size.x - 32.0
	var cell_size: float = floor((width - 3 * (engine.cols - 1)) / engine.cols)
	var font_size := int(cell_size * 0.55)
	for r in range(engine.rows):
		var row: Array = []
		for c in range(engine.cols):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(cell_size, cell_size)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", font_size)
			btn.pressed.connect(_on_cell_pressed.bind(r, c))
			btn.gui_input.connect(_on_cell_gui_input.bind(r, c))
			grid.add_child(btn)
			row.append(btn)
		cells.append(row)

# ---------- flow ----------

func _show_start_screen() -> void:
	timer_running = false
	start_screen.visible = true
	game_screen.visible = false

func _start_game(d: String) -> void:
	difficulty = d
	_restart()

func _restart() -> void:
	engine.reset(difficulty)
	elapsed = 0.0
	timer_running = false
	time_label.text = "⏱ 00:00"
	flag_mode = false
	start_screen.visible = false
	game_screen.visible = true
	_build_board()
	_render()

func _toggle_mode() -> void:
	flag_mode = not flag_mode
	_render()

func _on_cell_gui_input(event: InputEvent, r: int, c: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_flag(r, c)

func _on_cell_pressed(r: int, c: int) -> void:
	if engine.game_over:
		return
	if flag_mode and not engine.revealed[r][c]:
		_flag(r, c)
		return
	var result: String = engine.reveal(r, c)
	if result == "ignored":
		return
	timer_running = true
	_render()
	if result == "lost":
		_finish(false)
	elif result == "won":
		_finish(true)

func _flag(r: int, c: int) -> void:
	if engine.game_over:
		return
	engine.toggle_flag(r, c)
	_render()

func _finish(won: bool) -> void:
	timer_running = false
	var msg: String
	if won:
		var best = best_times.get(difficulty)
		var is_record: bool = best == null or elapsed < float(best)
		if is_record:
			best_times[difficulty] = elapsed
			SaveUtil.write(BEST_PATH, best_times)
		msg = "You cleared the board!\nTime: %s%s" % [_format_time(elapsed), "\nNew best!" if is_record else "\nBest: %s" % _format_time(float(best))]
	else:
		msg = "Boom! You hit a mine."
	result_label.text = msg
	# Let the player see the final board for a moment before the dialog.
	create_tween().tween_callback(_show_result).set_delay(0.8)

func _show_result() -> void:
	if engine.game_over and game_screen.visible:  # not if they already hit New
		result_dialog.visible = true

# ---------- rendering ----------

func _render() -> void:
	mines_label.text = "💣 %d" % engine.flags_left()
	mode_btn.text = "🚩 Flag mode" if flag_mode else "⛏ Dig mode"
	for r in range(engine.rows):
		for c in range(engine.cols):
			var btn: Button = cells[r][c]
			var color := COLOR_HIDDEN
			var text := ""
			var text_color := Color(1, 1, 1)
			if engine.revealed[r][c]:
				color = COLOR_REVEALED
				var n: int = engine.adjacent[r][c]
				if n > 0:
					text = str(n)
					text_color = NUMBER_COLORS[n]
			elif engine.game_over and engine.mines[r][c] and not engine.flagged[r][c]:
				color = COLOR_EXPLODED if Vector2i(r, c) == engine.exploded else COLOR_REVEALED
				text = "💣"
			elif engine.flagged[r][c]:
				text = "🚩"
				if engine.game_over and not engine.mines[r][c]:
					text = "❌"  # wrong flag, shown after losing
			btn.text = text
			btn.add_theme_color_override("font_color", text_color)
			btn.add_theme_color_override("font_pressed_color", text_color)
			btn.add_theme_color_override("font_hover_color", text_color)
			var sb := StyleBoxFlat.new()
			sb.bg_color = color
			sb.set_corner_radius_all(4)
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				btn.add_theme_stylebox_override(state, sb)
