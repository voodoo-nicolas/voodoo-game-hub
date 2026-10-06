extends Control

## Minesweeper. Tap to dig; switch the mode button to 🚩 to place flags
## instead (right-click also flags, for desktop). Tapping a revealed number
## whose flags are all placed digs its remaining neighbors.

const MinesweeperEngine = preload("res://scripts/games/minesweeper/minesweeper_engine.gd")
const HomeKit = preload("res://scripts/games/minesweeper/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://minesweeper_best.json"
const SAVE_PATH := "user://minesweeper_save.json"
const COLOR_BG := HomeKit.BG
const COLOR_HIDDEN := Color(0.12, 0.2, 0.42)
const COLOR_REVEALED := Color(0.04, 0.05, 0.1)
const COLOR_EXPLODED := Color("ff2b6b")
const NUMBER_COLORS := [
	Color(1, 1, 1), Color("29e6ff"), Color("7dff3a"), Color("ff4f9a"),
	Color("9b4dff"), Color("ffae2b"), Color("2bffd0"), Color(1, 1, 1), Color(0.7, 0.7, 0.8),
]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
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
	preload("res://scripts/games/minesweeper/minesweeper_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MinesweeperEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	best_times = data if data != null else {}
	_build_ui()
	_restart()  # a board behind the Home screen, which replaces the old start screen

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
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	_build_start_screen()
	_build_game_screen()

	result_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("Change Difficulty"), "action": _show_start_screen},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	result_label = result_dialog.get_meta("message_label")
	add_child(result_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/minesweeper/minesweeper_help.gd"))
	_build_home()
	if info:
		add_child(info)
		for d in best_times:
			info.low("Best time (%s)" % str(d).capitalize(), float(best_times[d]))
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("💣 Mines")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)

	if show_new:
		var new_btn := Button.new()
		new_btn.text = "↺"
		new_btn.custom_minimum_size = Vector2(76, 64)
		new_btn.add_theme_font_size_override("font_size", 30)
		new_btn.pressed.connect(_restart)
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
	prompt.text = tr("Choose a board")
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(prompt)

	for d in ["easy", "medium", "hard"]:
		var spec: Dictionary = MinesweeperEngine.DIFFICULTIES[d]
		var btn := Button.new()
		btn.text = tr("%s  —  %d×%d, %d mines") % [tr(d.capitalize()), spec.rows, spec.cols, spec.mines]
		btn.custom_minimum_size = Vector2(520, 96)
		btn.add_theme_font_size_override("font_size", 30)
		btn.pressed.connect(_start_game.bind(d))
		box.add_child(btn)

	var hint := Label.new()
	hint.text = tr("Tap to dig. Switch to 🚩 mode to flag mines.\nTap a number with all its flags placed to clear around it.")
	hint.add_theme_font_size_override("font_size", 24)
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
	_sfx("explode" if result == "lost" else "tick")
	if result == "lost":
		_finish(false)
	elif result == "won":
		_finish(true)

func _flag(r: int, c: int) -> void:
	if engine.game_over:
		return
	engine.toggle_flag(r, c)
	_sfx("toggle")
	_render()

func _finish(won: bool) -> void:
	timer_running = false
	SaveUtil.delete(SAVE_PATH)
	var msg: String
	if info:
		info.result("win" if won else "loss")
		if won:
			info.low("Best time (%s)" % difficulty.capitalize(), elapsed)
	if won:
		var best = best_times.get(difficulty)
		var is_record: bool = best == null or elapsed < float(best)
		if is_record:
			best_times[difficulty] = elapsed
			SaveUtil.write(BEST_PATH, best_times)
		msg = tr("You cleared the board!\nTime: %s%s") % [_format_time(elapsed), tr("\nNew best!") if is_record else tr("\nBest: %s") % _format_time(float(best))]
	else:
		msg = tr("Boom! You hit a mine.")
	result_label.text = msg
	# Let the player see the final board for a moment before the dialog.
	create_tween().tween_callback(_show_result).set_delay(0.8)

func _show_result() -> void:
	if engine.game_over and game_screen.visible:  # not if they already hit New
		result_dialog.visible = true

# ---------- rendering ----------

func _render() -> void:
	mines_label.text = "💣 %d" % engine.flags_left()
	mode_btn.text = tr("🚩 Flag mode") if flag_mode else tr("⛏ Dig mode")
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
			if color == COLOR_HIDDEN:
				sb.border_color = Color(HomeKit.BLUE, 0.9)
				sb.set_border_width_all(1)
			elif color == COLOR_REVEALED:
				sb.border_color = Color(HomeKit.BLUE, 0.18)
				sb.set_border_width_all(1)
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				btn.add_theme_stylebox_override(state, sb)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/minesweeper/minesweeper_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/minesweeper/minesweeper_help.gd"),
		"info": info,
		"accent": HomeKit.PINK,
		"subtitle": "Dig every safe square. Numbers count the mines next door.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "🙂 Easy", "sub": "9 × 9", "row": "lvl", "color": HomeKit.LIME, "action": _new_board.bind("easy")},
			{"text": "😐 Medium", "sub": "12 × 12", "row": "lvl", "color": HomeKit.CYAN, "action": _new_board.bind("medium")},
			{"text": "😈 Hard", "sub": "14 × 14", "row": "lvl", "color": HomeKit.PINK, "action": _new_board.bind("hard")},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): var d = SaveUtil.read(SAVE_PATH); return "" if d == null else tr(str(d.difficulty).capitalize()),
		"restart": _restart,
		"board": "Wins",
		"board_note": "Boards cleared, any size.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.3, 52.0)
	var o := Vector2(c.size.x / 2.0 - k * 1.5, c.size.y / 2.0 - k * 1.5)
	var cells := [["1", 0], ["", 1], ["2", 0], ["1", 0], ["💣", 2], ["", 1], ["🚩", 1], ["2", 0], ["1", 0]]
	for i in 9:
		var r := Rect2(o + Vector2(i % 3, int(i / 3)) * k, Vector2(k, k)).grow(-3)
		var hidden: bool = cells[i][1] == 1
		HomeKit.glow_rect(c, r, HomeKit.BLUE if hidden else (HomeKit.PINK if cells[i][1] == 2 else Color(HomeKit.CYAN, 0.6)), 2.0, 0.3 if hidden else 0.06)
		if cells[i][0] != "":
			HomeKit.glow_text(c, r.get_center(), cells[i][0], int(k * 0.5), NUMBER_COLORS[int(cells[i][0])] if cells[i][0].is_valid_int() else Color.WHITE)

func _new_board(d: String) -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_game(d)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not game_screen.visible or engine.game_over or not engine.mines_placed:
		return
	SaveUtil.write(SAVE_PATH, {"difficulty": difficulty, "mines": engine.mines, "adjacent": engine.adjacent,
		"revealed": engine.revealed, "flagged": engine.flagged, "count": engine.revealed_count, "elapsed": elapsed})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

static func _grid(a: Variant, as_bool: bool) -> Array:
	var out: Array = []
	for row in a:
		var r: Array = []
		for v in row:
			r.append(bool(v) if as_bool else int(v))
		out.append(r)
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_game("easy")
		return
	_start_game(str(d.difficulty))
	engine.mines = _grid(d.mines, true)
	engine.adjacent = _grid(d.adjacent, false)
	engine.revealed = _grid(d.revealed, true)
	engine.flagged = _grid(d.flagged, true)
	engine.revealed_count = int(d.count)
	engine.mines_placed = true
	elapsed = float(d.get("elapsed", 0.0))
	timer_running = true
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
