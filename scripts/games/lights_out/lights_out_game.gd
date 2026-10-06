extends Control

const LightsOutEngine = preload("res://scripts/games/lights_out/lights_out_engine.gd")
const HomeKit = preload("res://scripts/games/lights_out/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://lights_out_save.json"

const COLOR_ON := HomeKit.GOLD
const COLOR_OFF := HomeKit.BLUE

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var cells: Array = []
var moves_label: Label
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	preload("res://scripts/games/lights_out/lights_out_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = LightsOutEngine.new()
	_build_ui()
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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

	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	top_bar.add_child(hub_btn)

	var title := Label.new()
	title.text = tr("💡 Light Flip")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.GOLD.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.GOLD, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
	restart_btn.pressed.connect(_start_new_game)
	top_bar.add_child(restart_btn)

	moves_label = Label.new()
	moves_label.add_theme_font_size_override("font_size", 24)
	moves_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(moves_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var viewport_width: float = get_viewport_rect().size.x
	var outer_margin := 24.0
	var separation := 6
	var size := LightsOutEngine.SIZE
	var cell_size: float = floor((viewport_width - outer_margin * 2.0 - separation * (size - 1)) / size)

	var grid := GridContainer.new()
	grid.columns = size
	grid.add_theme_constant_override("h_separation", separation)
	grid.add_theme_constant_override("v_separation", separation)
	center.add_child(grid)

	for r in range(size):
		var row: Array = []
		for c in range(size):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.flat = false
			cell.focus_mode = Control.FOCUS_NONE
			cell.set_meta("sfx", "toggle")
			cell.pressed.connect(_on_cell_pressed.bind(r, c))
			grid.add_child(cell)
			row.append(cell)
		cells.append(row)

	_build_win_dialog()
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/lights_out/lights_out_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

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
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 31)
	win_label.add_theme_color_override("font_color", Color(1, 0.84, 0.04))
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_label)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(200, 48)
	again_btn.pressed.connect(func():
		win_dialog.visible = false
		_start_new_game()
	)
	box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	box.add_child(menu_btn)

# ---------- game flow ----------

func _start_new_game() -> void:
	engine.reset()
	win_dialog.visible = false
	_render()

func _on_cell_pressed(r: int, c: int) -> void:
	if win_dialog.visible:
		return
	engine.press(r, c)
	_render()
	if engine.is_solved():
		SaveUtil.delete(SAVE_PATH)
		win_label.text = tr("Solved in %d moves!") % engine.moves
		if info:
			info.add("Puzzles solved")
			info.celebrate("Solved!")
			if info.low("Fewest moves", engine.moves):
				win_label.text += "\n" + tr("New best!")
		win_dialog.visible = true

func _render() -> void:
	for r in range(LightsOutEngine.SIZE):
		for c in range(LightsOutEngine.SIZE):
			var on: bool = engine.grid[r][c]
			var sb := HomeKit.neon_box(COLOR_ON if on else COLOR_OFF, "pressed" if on else "normal")
			sb.bg_color = Color(COLOR_ON, 0.55) if on else Color(COLOR_OFF, 0.06)
			sb.shadow_size = 14 if on else 4
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				cells[r][c].add_theme_stylebox_override(state, sb)
	moves_label.text = tr("Moves: %d") % engine.moves

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/lights_out/lights_out_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/lights_out/lights_out_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Tap to flip a light and its neighbours. Turn them all off.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  New puzzle", "sub": "5 × 5 lights", "action": _new_puzzle}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): return tr("Moves: %d") % int(SaveUtil.read(SAVE_PATH).get("moves", 0)) if SaveUtil.read(SAVE_PATH) else "",
		"restart": _start_new_game,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var n := 3
	var k := minf(c.size.y / (n + 0.4), 52.0)
	var o := Vector2((c.size.x - k * n) / 2.0, (c.size.y - k * n) / 2.0)
	var lit := [1, 3, 4, 5, 7]  # a plus sign: what one tap flips
	for i in 9:
		var r := Rect2(o + Vector2(i % 3, int(i / 3)) * k + Vector2(5, 5), Vector2(k - 10, k - 10))
		if lit.has(i):
			HomeKit.glow_rect(c, r, COLOR_ON, 2.5, 0.45)
		else:
			HomeKit.glow_rect(c, r, HomeKit.BLUE, 1.5, 0.05)

## From Home: a fresh puzzle replaces any saved one.
func _new_puzzle() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _save_game() -> void:
	if engine.is_solved() or win_dialog.visible:
		return
	SaveUtil.write(SAVE_PATH, {"grid": engine.grid, "moves": engine.moves})

func _load_saved_game() -> void:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null:
		_start_new_game()
		return
	var grid: Array = []
	for row in data.get("grid", []):
		var r: Array = []
		for v in row:
			r.append(bool(v))
		grid.append(r)
	if grid.size() != LightsOutEngine.SIZE:
		_start_new_game()
		return
	engine.grid = grid
	engine.moves = int(data.get("moves", 0))
	win_dialog.visible = false
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
