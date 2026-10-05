extends Control

const G2048Engine = preload("res://scripts/games/g2048/g2048_engine.gd")
const HomeKit = preload("res://scripts/games/g2048/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const Ui = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://g2048_save.json"
const BOARD_SEPARATION := 6
const BOARD_PADDING := 8
const BOARD_OUTER_MARGIN := 16.0
const SWIPE_MIN_DISTANCE := 24.0

const TILE_COLORS := {
	0: Color(0.06, 0.08, 0.15),
	2: Color("3a8cff"),
	4: Color("29e6ff"),
	8: Color("ffae2b"),
	16: Color("ff8a2b"),
	32: Color("ff5a4f"),
	64: Color("ff2b6b"),
	128: Color("2bffd0"),
	256: Color("29b6ff"),
	512: Color("9b4dff"),
	1024: Color("ff2bd6"),
	2048: Color("7dff3a"),
}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
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
	preload("res://scripts/games/g2048/g2048_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = G2048Engine.new()
	_build_ui()
	_start_new_game()  # behind the Home screen; Resume / New game there

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _input(event: InputEvent) -> void:
	# _input sees every swipe, even ones over an open dialog -- without this,
	# swiping while paused (or on the "2048!" banner) moved tiles behind it.
	if not game_active or pause_dialog.visible or end_dialog.visible:
		touch_active = false
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
	var score_before: int = engine.score
	if engine.move(dir):
		_sfx("merge" if engine.score > score_before else "slide")
		_render()
		if not shown_2048_banner and engine.has_2048():
			shown_2048_banner = true
			_show_end(tr("You reached 2048!"), true)
		elif not engine.can_move():
			_show_end(tr("Game Over"), false)

# ---------- UI construction ----------

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

	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_pressed)
	top_bar.add_child(pause_btn)

	var title := Label.new()
	title.text = "2048"
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
	hint.text = tr("Swipe or use arrow keys")
	hint.add_theme_font_size_override("font_size", 24)
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
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/g2048/g2048_help.gd"))
	_build_home()
	if info:
		add_child(info)
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
	title.text = tr("Paused")
	title.add_theme_font_size_override("font_size", 33)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = tr("Resume")
	resume_btn.custom_minimum_size = Vector2(200, 48)
	resume_btn.pressed.connect(func(): pause_dialog.visible = false)
	box.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.custom_minimum_size = Vector2(200, 44)
	restart_btn.pressed.connect(func():
		pause_dialog.visible = false
		_start_new_game()
	)
	box.add_child(restart_btn)

	var exit_btn := Button.new()
	exit_btn.text = tr("Exit to Hub")
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
	home.pause()

func _show_end(title: String, can_continue: bool) -> void:
	if not can_continue:
		game_active = false
		SaveUtil.delete(SAVE_PATH)

	end_title.text = tr("%s\nScore: %d") % [title, engine.score]
	if info and not can_continue:
		var top := 0
		for row in engine.grid:
			for v in row:
				top = maxi(top, int(v))
		info.add("Games played")
		var record: bool = info.best("Best score", engine.score)
		info.high("Best tile", top)
		end_title.text += "\n" + (tr("New best!") if record else tr("Best: %d") % int(info.get_stat("Best score")))

	for child in end_buttons_box.get_children():
		if child != end_title:
			end_buttons_box.remove_child(child)
			child.queue_free()

	if can_continue:
		var continue_btn := Button.new()
		continue_btn.text = tr("Keep Going")
		continue_btn.custom_minimum_size = Vector2(200, 48)
		continue_btn.pressed.connect(func(): end_dialog.visible = false)
		end_buttons_box.add_child(continue_btn)

	var again_btn := Button.new()
	again_btn.text = tr("Play Again")
	again_btn.custom_minimum_size = Vector2(200, 44)
	again_btn.pressed.connect(func():
		end_dialog.visible = false
		_start_new_game()
	)
	end_buttons_box.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = tr("🏠 %s Home") % tr(TITLE_FOR_HOME)
	menu_btn.custom_minimum_size = Vector2(320, 64)
	menu_btn.pressed.connect(_go_home)
	end_buttons_box.add_child(menu_btn)

	end_dialog.visible = true

func _render() -> void:
	for r in range(G2048Engine.SIZE):
		for c in range(G2048Engine.SIZE):
			var v: int = engine.grid[r][c]
			var color: Color = TILE_COLORS.get(v, Color(0.71, 0.95, 0.41))
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(10)
			if v == 0:
				sb.bg_color = color
			else:
				# neon tile: tinted glass with a glowing rim in the value's colour
				sb.bg_color = Color(color, 0.22)
				sb.border_color = color
				sb.set_border_width_all(3)
				sb.shadow_color = Color(color, 0.4)
				sb.shadow_size = 8
			tile_panels[r][c].add_theme_stylebox_override("panel", sb)
			var text: String = str(v) if v != 0 else ""
			tile_labels[r][c].text = text
			tile_labels[r][c].add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.55))
			var scale: float = 0.4 if text.length() <= 2 else (0.32 if text.length() == 3 else 0.26)
			tile_labels[r][c].add_theme_font_size_override("font_size", int(tile_size * scale))

	score_label.text = tr("Score: %d") % engine.score

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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/g2048/g2048_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/g2048/g2048_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Slide and merge the tiles. Can you reach 2048?",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  New game", "sub": "4 × 4", "action": _new_2048}],
		"save_path": SAVE_PATH,
		"resume": _resume_saved,
		"resume_text": func(): return tr("Score: %d") % int((SaveUtil.read(SAVE_PATH) if SaveUtil.read(SAVE_PATH) else {}).get("score", 0)),
		"restart": _start_new_game,
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 2.2, 80.0)
	var o := Vector2(c.size.x / 2.0 - k, c.size.y / 2.0 - k)
	var tiles := [["2", HomeKit.CYAN], ["0", HomeKit.LIME], ["4", HomeKit.GOLD], ["8", HomeKit.PINK]]
	for i in 4:
		var r := Rect2(o + Vector2(i % 2, int(i / 2)) * k, Vector2(k, k)).grow(-4)
		HomeKit.glow_rect(c, r, tiles[i][1], 2.5, 0.18)
		HomeKit.glow_text(c, r.get_center(), tiles[i][0], int(k * 0.55), Color.WHITE)

func _new_2048() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _resume_saved() -> void:
	if not _load_saved_game():
		_start_new_game()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
