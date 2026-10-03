extends Control

## Sliding 15-puzzle: put 1-15 back in order. Tap a tile in line with the gap
## to slide it (and everything between) into the gap.

const FifteenPuzzleEngine = preload("res://scripts/games/fifteen_puzzle/fifteen_puzzle_engine.gd")
const HomeKit = preload("res://scripts/games/fifteen_puzzle/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SAVE_PATH := "user://fifteen_puzzle_save.json"
const BEST_PATH := "user://fifteen_puzzle_best.json"
const COLOR_BG := Color("070a14")
const COLOR_TILE := Color("3a8cff")
const COLOR_TILE_HOME := Color("7dff3a")  # already in its solved spot
const COLOR_GAP := Color(0.04, 0.05, 0.1)

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine
var elapsed: float = 0.0
var timer_running: bool = false
var game_active: bool = false
var best: Dictionary = {}

var buttons: Array = []
var moves_label: Label
var time_label: Label
var best_label: Label
var win_dialog: Control
var win_label: Label

func _ready() -> void:
	preload("res://scripts/games/fifteen_puzzle/fifteen_puzzle_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = FifteenPuzzleEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	best = data if data != null else {}
	_build_ui()
	engine.reset()  # a board behind the Home screen; Home offers Resume / New
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _process(delta: float) -> void:
	if timer_running:
		elapsed += delta
		time_label.text = "⏱ %s" % _format_time(elapsed)

func _format_time(s: float) -> String:
	var total := int(s)
	return "%02d:%02d" % [int(total / 60), total % 60]

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	root.add_child(top_margin)
	var bar := HBoxContainer.new()
	top_margin.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🔲 15-Puzzle")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("Shuffle")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_new_game)
	bar.add_child(new_btn)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 50)
	root.add_child(stats)
	moves_label = Label.new()
	moves_label.add_theme_font_size_override("font_size", 30)
	stats.add_child(moves_label)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 30)
	stats.add_child(time_label)

	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 24)
	best_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(best_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var grid := GridContainer.new()
	grid.columns = FifteenPuzzleEngine.SIZE
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	var width: float = get_viewport_rect().size.x - 60.0
	var tile_size: float = floor((width - 30) / FifteenPuzzleEngine.SIZE)
	for i in range(FifteenPuzzleEngine.SIZE * FifteenPuzzleEngine.SIZE):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(tile_size, tile_size)
		btn.add_theme_font_size_override("font_size", int(tile_size * 0.45))
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_tile_pressed.bind(i))
		grid.add_child(btn)
		buttons.append(btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	root.add_child(spacer)

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Play Again"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	win_label = win_dialog.get_meta("message_label")
	add_child(win_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/fifteen_puzzle/fifteen_puzzle_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best.has("moves"):
			info.low("Fewest moves", int(best.moves))
			info.low("Best time", float(best.time))
	add_child(SettingsDrawer.new())

func _new_game() -> void:
	engine.reset()
	elapsed = 0.0
	timer_running = false
	game_active = true
	time_label.text = "⏱ 00:00"
	win_dialog.visible = false
	SaveUtil.delete(SAVE_PATH)
	_render()

func _on_tile_pressed(i: int) -> void:
	if not game_active or not engine.tap(i):
		return
	timer_running = true
	_render()
	if engine.is_solved():
		_win()

func _win() -> void:
	game_active = false
	timer_running = false
	SaveUtil.delete(SAVE_PATH)
	var record := ""
	if not best.has("moves") or engine.moves < int(best.moves):
		best["moves"] = engine.moves
		record += tr("\nFewest moves yet!")
	if not best.has("time") or elapsed < float(best.time):
		best["time"] = elapsed
		record += tr("\nFastest time yet!")
	SaveUtil.write(BEST_PATH, best)
	if info:
		info.add("Puzzles solved")
		info.celebrate("Solved!")
		info.low("Fewest moves", engine.moves)
		info.low("Best time", elapsed)
	win_label.text = tr("%d moves in %s%s") % [engine.moves, _format_time(elapsed), record]
	_render()
	create_tween().tween_callback(func(): win_dialog.visible = not game_active).set_delay(0.5)

func _render() -> void:
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		var n: int = engine.tiles[i]
		btn.text = str(n) if n != 0 else ""
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		if n == 0:
			sb.bg_color = COLOR_GAP
		else:
			# neon tile: dark glass, glowing rim (green once it's home)
			var col: Color = COLOR_TILE_HOME if n == i + 1 else COLOR_TILE
			sb = HomeKit.neon_box(col, "normal")
			sb.bg_color = Color(col, 0.2)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(12)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(state, sb)
	moves_label.text = tr("Moves: %d") % engine.moves
	if best.has("moves"):
		best_label.text = tr("Best: %d moves · %s") % [int(best.moves), _format_time(float(best.time))]
	else:
		best_label.text = tr("Tiles turn green when they're in the right spot")

func _save_game() -> void:
	if not game_active:
		return
	SaveUtil.write(SAVE_PATH, {"tiles": engine.tiles, "moves": engine.moves, "elapsed": elapsed})

func _load_saved_game() -> bool:
	var data = SaveUtil.read(SAVE_PATH)
	if data == null or typeof(data.get("tiles")) != TYPE_ARRAY or data.tiles.size() != 16:
		return false
	engine.tiles = []
	for v in data.tiles:
		engine.tiles.append(int(v))
	engine.moves = int(data.get("moves", 0))
	elapsed = float(data.get("elapsed", 0.0))
	game_active = true
	time_label.text = "⏱ %s" % _format_time(elapsed)
	_render()
	return true

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/fifteen_puzzle/fifteen_puzzle_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/fifteen_puzzle/fifteen_puzzle_help.gd"),
		"info": info,
		"accent": HomeKit.BLUE,
		"subtitle": "Slide the tiles back into order, 1 to 15.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  New puzzle", "sub": "4 × 4", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _resume_saved,
		"resume_text": func(): return tr("Moves: %d") % int((SaveUtil.read(SAVE_PATH) if SaveUtil.read(SAVE_PATH) else {}).get("moves", 0)),
		"restart": _new_game,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.2, 52.0)
	var o := Vector2(c.size.x / 2.0 - k * 1.5, c.size.y / 2.0 - k * 1.5)
	var nums := ["1", "2", "3", "5", "", "6", "4", "7", "8"]
	for i in 9:
		if nums[i] == "":
			continue
		var r := Rect2(o + Vector2(i % 3, int(i / 3)) * k, Vector2(k, k)).grow(-3)
		var home_spot: bool = nums[i] in ["1", "2", "3"]
		HomeKit.glow_rect(c, r, COLOR_TILE_HOME if home_spot else COLOR_TILE, 2.0, 0.2)
		HomeKit.glow_text(c, r.get_center(), nums[i], int(k * 0.5), Color.WHITE)

func _resume_saved() -> void:
	if not _load_saved_game():
		_new_game()
