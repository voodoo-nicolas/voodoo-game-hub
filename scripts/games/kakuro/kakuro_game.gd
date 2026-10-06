extends Control

## Kakuro -- tap a white cell, then a digit. Each run of white cells must add
## up to the clue at its start (→ across, ↓ down) without repeating a digit.

const KakuroEngine = preload("res://scripts/games/kakuro/kakuro_engine.gd")
const HomeKit = preload("res://scripts/games/kakuro/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SIZES := [6, 8]
const COLOR_BLACK := Color(0.1, 0.05, 0.18)
const COLOR_CELL := Color(0.05, 0.07, 0.15)
const COLOR_RUN := Color(0.07, 0.15, 0.28)
const COLOR_SELECTED := Color(0.1, 0.25, 0.45)
const COLOR_INK := Color(0.93, 0.97, 1.0)
const COLOR_BAD := Color("ff4f6a")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://kakuro_save.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: KakuroEngine
var board: Control
var size_btn: Button
var win_dialog: ColorRect
var started := false  # a puzzle is on (not just the one behind Home)
var size_index: int = 0
var selected: int = -1
var font: Font

func _ready() -> void:
	preload("res://scripts/games/kakuro/kakuro_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = KakuroEngine.new()
	_build_ui()
	_start_new_game()
	started = false

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	bg = HomeKit.backdrop()
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
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
	title.text = tr("➗ Kakuro")
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
	hint.text = tr("Each run adds up to its clue (top-right → across, bottom-left ↓ down). No repeats in a run.")
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

	var pad := GridContainer.new()
	pad.columns = 5
	pad.add_theme_constant_override("h_separation", 10)
	pad.add_theme_constant_override("v_separation", 10)
	var pc := CenterContainer.new()
	pc.add_child(pad)
	root.add_child(pc)
	for v in range(1, 10):
		pad.add_child(_pad_button(str(v), v))
	pad.add_child(_pad_button("⌫", 0))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 30)
	bm.add_child(bottom)
	root.add_child(bm)
	size_btn = Button.new()
	size_btn.custom_minimum_size = Vector2(220, 60)
	size_btn.add_theme_font_size_override("font_size", 26)
	size_btn.pressed.connect(_cycle_size)
	bottom.add_child(size_btn)

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/kakuro/kakuro_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _pad_button(text: String, v: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 76)
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
	size_btn.text = tr("Small") if size_index == 0 else tr("Large")
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
			record = info.low("Best time (%s)" % ("Small" if size_index == 0 else "Large"), secs)
		win_dialog.get_meta("message_label").text = tr("Every sum checks out.")
		if info:
			win_dialog.get_meta("message_label").text += "\n" + tr("Time: %d:%02d") % [int(secs) / 60, int(secs) % 60]
			if record:
				win_dialog.get_meta("message_label").text += "  ·  " + tr("New best!")
		win_dialog.visible = true

## A keyboard works too: 1-9 / numpad enter a digit, Backspace / Delete / 0
## erase, arrows move the selection.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or get_tree().paused or not started or win_dialog.visible:
		return
	var code := k.physical_keycode
	var digit := -1
	if code >= KEY_0 and code <= KEY_9:
		digit = code - KEY_0
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		digit = code - KEY_KP_0
	if code == KEY_BACKSPACE or code == KEY_DELETE or digit == 0:
		_on_number(0)
	elif digit > 0 and digit <= 9:
		if selected < 0:
			_move_selection(Vector2i(1, 0))
		_on_number(digit)
	elif code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var d := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0)}[code] as Vector2i
		_move_selection(d)
	else:
		return
	get_viewport().set_input_as_handled()

## Steps the selection one white cell in direction d (wrapping), or picks the
## first one when nothing is selected.
func _move_selection(d: Vector2i) -> void:
	var n: int = engine.size
	if selected < 0:
		for i in n * n:
			if engine.white[i]:
				selected = i
				break
		board.queue_redraw()
		return
	var cur := Vector2i(selected % n, selected / n)
	for _step in n * n:
		cur = Vector2i(posmod(cur.x + d.x, n), posmod(cur.y + d.y, n))
		if engine.white[cur.y * n + cur.x]:
			selected = cur.y * n + cur.x
			board.queue_redraw()
			return

# ---------- drawing ----------

func _cell_size() -> float:
	return floor(min(board.size.x - 24.0, board.size.y - 8.0) / engine.size)

func _origin() -> Vector2:
	var s := _cell_size() * engine.size
	return Vector2((board.size.x - s) / 2.0, (board.size.y - s) / 2.0)

## Look (STANDARDS §9): "classic" = pencil and paper (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
var skin: String = "classic"
var bg: ColorRect

func _set_skin(name: String) -> void:
	skin = "voodoo" if name == "voodoo" else "classic"
	if bg:
		bg.color = HomeKit.CLASSIC.table if skin == "classic" else HomeKit.BG
		if bg.get_child_count() > 0:
			bg.get_child(0).visible = skin != "classic"
	if board:
		board.queue_redraw()

func _is_classic() -> bool:
	return skin == "classic"

func _draw_board() -> void:
	if engine.white.is_empty():
		return
	var n: int = engine.size
	var cs := _cell_size()
	if cs < 8.0:
		return  # not laid out yet: text this small has a font size of 0
	var o := _origin()
	var bad: Array = engine.conflicts()
	var run_cells: Array = []
	if selected >= 0:
		for ri in engine.cell_runs[selected]:
			if ri >= 0:
				run_cells.append_array(engine.runs[ri].cells)
	for i in n * n:
		var rect := Rect2(o + Vector2(i % n, i / n) * cs, Vector2(cs, cs)).grow(-1)
		if not engine.white[i]:
			board.draw_rect(rect, Color("3a4150") if _is_classic() else COLOR_BLACK)
			continue
		var col := COLOR_CELL
		if _is_classic():
			col = HomeKit.CLASSIC.paper
		if i == selected:
			col = COLOR_SELECTED
		elif i in run_cells:
			col = COLOR_RUN
		if _is_classic() and i == selected:
			col = Color("ffe9a8")
		elif _is_classic() and i in run_cells:
			col = Color("e6e1cf")
		board.draw_rect(rect, col)
		if _is_classic():
			board.draw_rect(rect, HomeKit.CLASSIC.pencil if i != selected else HomeKit.CLASSIC.red, false, 1.5)
		else:
			board.draw_rect(rect, Color(HomeKit.CYAN, 0.45) if i != selected else HomeKit.GOLD, false, 1.5)
		var v: int = engine.values[i]
		if v > 0:
			var fs := int(cs * 0.55)
			board.draw_string(font, Vector2(rect.position.x, rect.position.y + cs * 0.5 + fs * 0.36), str(v),
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, COLOR_BAD if i in bad else (HomeKit.CLASSIC.ink if _is_classic() else COLOR_INK))
	var cfs := int(cs * 0.28)
	for ri in engine.runs.size():
		var run: Dictionary = engine.runs[ri]
		var cc: int = run.clue_cell
		var p := o + Vector2(cc % n, cc / n) * cs
		board.draw_line(p + Vector2(2, 2), p + Vector2(cs - 2, cs - 2), Color(0.45, 0.45, 0.52), 1.5)
		var done: bool = engine.run_complete_ok(ri)
		var tc: Color = HomeKit.LIME if done else HomeKit.GOLD
		if _is_classic():
			tc = Color("2a7d3a") if done else Color("e6e1cf")
		if run.across:
			board.draw_string(font, p + Vector2(cs * 0.5, cs * 0.42), str(run.sum), HORIZONTAL_ALIGNMENT_CENTER, cs * 0.5, cfs, tc)
		else:
			board.draw_string(font, p + Vector2(0, cs * 0.9), str(run.sum), HORIZONTAL_ALIGNMENT_CENTER, cs * 0.5, cfs, tc)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (event.position - _origin()) / _cell_size()
	var c := floori(p.x)
	var r := floori(p.y)
	var n: int = engine.size
	if r >= 0 and c >= 0 and r < n and c < n and engine.white[r * n + c]:
		selected = r * n + c
		board.queue_redraw()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/kakuro/kakuro_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/kakuro/kakuro_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Fill the white squares with 1–9 so every run adds up to its clue.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "Small", "sub": "6 × 6", "row": "size", "color": HomeKit.LIME, "action": _new_size.bind(0)},
			{"text": "Large", "sub": "8 × 8", "row": "size", "color": HomeKit.PINK, "action": _new_size.bind(1)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _start_new_game,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved, both sizes.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.3, 54.0)
	var o := Vector2(c.size.x / 2.0 - k * 1.5, c.size.y / 2.0 - k * 1.5)
	var font := ThemeDB.fallback_font
	for i in 9:
		var r := Rect2(o + Vector2(i % 3, int(i / 3)) * k, Vector2(k, k)).grow(-2)
		var clue: bool = i % 3 == 0 or i < 3
		if clue:
			c.draw_rect(r, Color(HomeKit.PURPLE, 0.18))
			c.draw_line(r.position, r.end, Color(HomeKit.PURPLE, 0.6), 1.5)
		else:
			HomeKit.glow_rect(c, r, HomeKit.CYAN, 2.0, 0.08)
	c.draw_string(font, o + Vector2(k * 1.5, k * 0.45), "4", HORIZONTAL_ALIGNMENT_LEFT, -1, int(k * 0.3), HomeKit.GOLD)
	c.draw_string(font, o + Vector2(k * 2.5, k * 0.45), "9", HORIZONTAL_ALIGNMENT_LEFT, -1, int(k * 0.3), HomeKit.GOLD)
	c.draw_string(font, o + Vector2(k * 0.05, k * 1.95), "10", HORIZONTAL_ALIGNMENT_LEFT, -1, int(k * 0.3), HomeKit.GOLD)
	for d in [[1, 1, "3"], [2, 1, "7"], [1, 2, "1"], [2, 2, "2"]]:
		HomeKit.glow_text(c, o + Vector2(d[0] + 0.5, d[1] + 0.55) * k, d[2], int(k * 0.5), Color.WHITE)

func _new_size(i: int) -> void:
	size_index = i
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or win_dialog.visible or engine.white.is_empty():
		return
	SaveUtil.write(SAVE_PATH, {"size_index": size_index, "size": engine.size, "white": engine.white, "runs": engine.runs,
		"cell_runs": engine.cell_runs, "solution": engine.solution, "values": engine.values})

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
	_start_new_game()
	engine.size = int(d.size)
	engine.white = []
	for v in d.white:
		engine.white.append(bool(v))
	engine.runs = []
	for r in d.runs:
		engine.runs.append({"cells": _ints(r.cells), "sum": int(r.sum), "across": bool(r.across), "clue_cell": int(r.clue_cell)})
	engine.cell_runs = []
	for cr in d.cell_runs:
		engine.cell_runs.append(_ints(cr))
	engine.solution = _ints(d.solution)
	engine.values = _ints(d.values)
	selected = -1
	board.queue_redraw()
