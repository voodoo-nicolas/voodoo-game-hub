extends Control

## Sliding 15-puzzle: put 1-15 back in order. Tap a tile in line with the gap
## to slide it (and everything between) into the gap.

const FifteenPuzzleEngine = preload("res://scripts/games/fifteen_puzzle/fifteen_puzzle_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")

const SAVE_PATH := "user://fifteen_puzzle_save.json"
const BEST_PATH := "user://fifteen_puzzle_best.json"
const COLOR_BG := Color(0.09, 0.09, 0.13)
const COLOR_TILE := Color(0.22, 0.45, 0.75)
const COLOR_TILE_HOME := Color(0.25, 0.6, 0.4)  # already in its solved spot
const COLOR_GAP := Color(0.13, 0.13, 0.17)

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
	if not _load_saved_game():
		_new_game()

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
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
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
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	win_label = win_dialog.get_meta("message_label")
	add_child(win_dialog)

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
			sb.bg_color = COLOR_TILE_HOME if n == i + 1 else COLOR_TILE
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
