extends Control

## Calcudoku -- tap a cell, then a number. Rows and columns never repeat; each
## outlined cage must make its target with the operation shown.

const CalcEngine = preload("res://scripts/games/calcudoku/calcudoku_engine.gd")
const HomeKit = preload("res://scripts/games/calcudoku/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://calcudoku_save.json"

const SIZES := [4, 5, 6]
const COLOR_CELL := Color(0.05, 0.07, 0.15)
const COLOR_SELECTED := Color(0.1, 0.25, 0.45)
const COLOR_CAGE_DONE := Color(0.06, 0.2, 0.12)
const COLOR_INK := Color(0.93, 0.97, 1.0)
const COLOR_BAD := Color("ff4f6a")
const COLOR_CAGE := Color("29e6ff")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: CalcEngine
var board: Control
var pad: HBoxContainer
var size_btn: Button
var win_dialog: ColorRect
var size_index: int = 0
var selected: int = -1
var font: Font
var started := false  # a puzzle is on the board (not just the one behind Home)

func _ready() -> void:
	preload("res://scripts/games/calcudoku/calcudoku_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = CalcEngine.new()
	_build_ui()
	_start_new_game()
	started = false  # the puzzle behind Home isn't a game in progress yet

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🔟 Calcudoku")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	var hint := Label.new()
	hint.text = tr("No repeats in any row or column. Each cage must make its number using its operation.")
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(hint)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	pad = HBoxContainer.new()
	pad.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_theme_constant_override("separation", 10)
	root.add_child(pad)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_child(bottom)
	root.add_child(bm)
	size_btn = Button.new()
	size_btn.custom_minimum_size = Vector2(220, 64)
	size_btn.add_theme_font_size_override("font_size", 26)
	size_btn.pressed.connect(_cycle_size)
	bottom.add_child(size_btn)

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/calcudoku/calcudoku_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _rebuild_pad() -> void:
	for child in pad.get_children():
		child.queue_free()
	for v in range(1, engine.n + 1):
		pad.add_child(_pad_button(str(v), v))
	pad.add_child(_pad_button("⌫", 0))

func _pad_button(text: String, v: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(86, 86)
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_number.bind(v))
	return b

func _cycle_size() -> void:
	size_index = (size_index + 1) % SIZES.size()
	_start_new_game()

func _start_new_game() -> void:
	started = true
	engine.new_puzzle(SIZES[size_index])
	if info:
		info.start_clock()
	selected = -1
	win_dialog.visible = false
	size_btn.text = tr("Size: %d×%d") % [engine.n, engine.n]
	_rebuild_pad()
	board.queue_redraw()

func _on_number(v: int) -> void:
	if selected < 0 or win_dialog.visible:
		return
	engine.values[selected] = v
	board.queue_redraw()
	if engine.is_solved():
		SaveUtil.delete(SAVE_PATH)
		var secs := 0.0
		var record := false
		if info:
			info.add("Puzzles solved")
			info.celebrate("Solved!")
			secs = info.stop_clock()
			record = info.low("Best time (%s)" % ("%d×%d" % [SIZES[size_index], SIZES[size_index]]), secs)
		win_dialog.get_meta("message_label").text = tr("Every cage adds up.")
		if info:
			win_dialog.get_meta("message_label").text += "\n" + tr("Time: %d:%02d") % [int(secs) / 60, int(secs) % 60]
			if record:
				win_dialog.get_meta("message_label").text += "  ·  " + tr("New best!")
		win_dialog.visible = true

# ---------- drawing ----------

func _cell_size() -> float:
	return floor(min(board.size.x - 32.0, board.size.y - 8.0) / engine.n)

func _origin() -> Vector2:
	var s := _cell_size() * engine.n
	return Vector2((board.size.x - s) / 2.0, (board.size.y - s) / 2.0)

func _draw_board() -> void:
	if engine.cages.is_empty():
		return
	var n: int = engine.n
	var cs := _cell_size()
	var o := _origin()
	var bad: Array = engine.conflicts()
	for i in n * n:
		var r := i / n
		var c := i % n
		var rect := Rect2(o + Vector2(c, r) * cs, Vector2(cs, cs))
		var col := COLOR_CELL
		if engine.cage_satisfied(engine.cage_of[i]):
			col = COLOR_CAGE_DONE
		if i == selected:
			col = COLOR_SELECTED
		board.draw_rect(rect, col)
		board.draw_rect(rect, Color(HomeKit.BLUE, 0.3), false, 1.0)
		var v: int = engine.values[i]
		if v > 0:
			var fs := int(cs * 0.5)
			board.draw_string(font, Vector2(rect.position.x, rect.position.y + cs * 0.62 + fs * 0.3), str(v),
				HORIZONTAL_ALIGNMENT_CENTER, cs, fs, COLOR_BAD if i in bad else COLOR_INK)
	# cage borders: a thick line wherever neighbours belong to different cages
	var thick := 4.0
	for i in n * n:
		var r := i / n
		var c := i % n
		var p := o + Vector2(c, r) * cs
		if c == n - 1 or engine.cage_of[i] != engine.cage_of[i + 1]:
			board.draw_line(p + Vector2(cs, 0), p + Vector2(cs, cs), COLOR_CAGE, thick)
		if r == n - 1 or engine.cage_of[i] != engine.cage_of[i + n]:
			board.draw_line(p + Vector2(0, cs), p + Vector2(cs, cs), COLOR_CAGE, thick)
		if c == 0:
			board.draw_line(p, p + Vector2(0, cs), COLOR_CAGE, thick)
		if r == 0:
			board.draw_line(p, p + Vector2(cs, 0), COLOR_CAGE, thick)
	for cage in engine.cages:
		var first: int = cage.cells.min()
		var p := o + Vector2(first % n, first / n) * cs
		var label: String = str(cage.target) + cage.op
		var fs := int(cs * 0.22)
		board.draw_string(font, p + Vector2(6, fs + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, HomeKit.GOLD)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (event.position - _origin()) / _cell_size()
	var c := floori(p.x)
	var r := floori(p.y)
	if r >= 0 and c >= 0 and r < engine.n and c < engine.n:
		selected = r * engine.n + c
		board.queue_redraw()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/calcudoku/calcudoku_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/calcudoku/calcudoku_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Every row and column once. Every cage hits its target.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "4 × 4", "sub": "Easy", "row": "size", "color": HomeKit.LIME, "action": _new_size.bind(0)},
			{"text": "5 × 5", "sub": "Medium", "row": "size", "color": HomeKit.CYAN, "action": _new_size.bind(1)},
			{"text": "6 × 6", "sub": "Hard", "row": "size", "color": HomeKit.PINK, "action": _new_size.bind(2)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): return "%d × %d" % [int(SaveUtil.read(SAVE_PATH).get("n", 4)), int(SaveUtil.read(SAVE_PATH).get("n", 4))] if SaveUtil.read(SAVE_PATH) else "",
		"restart": _start_new_game,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved, all sizes.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.3, 54.0)
	var o := Vector2(c.size.x / 2.0 - k * 1.5, c.size.y / 2.0 - k * 1.5)
	for i in 4:
		c.draw_line(o + Vector2(i * k, 0), o + Vector2(i * k, 3 * k), Color(HomeKit.BLUE, 0.35), 1.5)
		c.draw_line(o + Vector2(0, i * k), o + Vector2(3 * k, i * k), Color(HomeKit.BLUE, 0.35), 1.5)
	HomeKit.glow_polyline(c, PackedVector2Array([o, o + Vector2(2 * k, 0), o + Vector2(2 * k, k), o + Vector2(k, k), o + Vector2(k, 2 * k), o + Vector2(0, 2 * k)]), HomeKit.CYAN, 2.5, true)
	HomeKit.glow_rect(c, Rect2(o + Vector2(2 * k, 0), Vector2(k, 3 * k)), HomeKit.MAGENTA, 2.5)
	var font := ThemeDB.fallback_font
	c.draw_string(font, o + Vector2(6, k * 0.32), "6+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(k * 0.26), HomeKit.GOLD)
	c.draw_string(font, o + Vector2(2 * k + 6, k * 0.32), "6×", HORIZONTAL_ALIGNMENT_LEFT, -1, int(k * 0.26), HomeKit.GOLD)
	for d in [[0, 0, "1"], [1, 0, "3"], [0, 1, "2"], [2, 1, "2"], [2, 2, "3"], [1, 2, "1"]]:
		HomeKit.glow_text(c, o + Vector2(d[0] + 0.5, d[1] + 0.58) * k, d[2], int(k * 0.5), Color.WHITE)

func _new_size(i: int) -> void:
	size_index = i
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if engine.cages.is_empty() or engine.is_solved() or win_dialog.visible or not started:
		return
	SaveUtil.write(SAVE_PATH, {"n": engine.n, "size_index": size_index, "solution": engine.solution,
		"cage_of": engine.cage_of, "cages": engine.cages, "values": engine.values})

static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	size_index = clampi(int(d.get("size_index", 0)), 0, SIZES.size() - 1)
	engine.n = int(d.n)
	engine.solution = _ints(d.solution)
	engine.cage_of = _ints(d.cage_of)
	engine.values = _ints(d.values)
	engine.cages = []
	for cg in d.cages:
		engine.cages.append({"cells": _ints(cg.cells), "op": str(cg.op), "target": int(cg.target)})
	if engine.values.size() != engine.n * engine.n:
		_start_new_game()
		return
	started = true
	if info:
		info.start_clock()
	selected = -1
	win_dialog.visible = false
	size_btn.text = tr("Size: %d×%d") % [engine.n, engine.n]
	_rebuild_pad()
	board.queue_redraw()
