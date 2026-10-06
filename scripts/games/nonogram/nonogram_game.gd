extends Control

## Nonogram -- tap or drag to fill cells; switch the mode to ✕ to mark cells
## you know are empty. Clues turn grey once their line matches.

const NonoEngine = preload("res://scripts/games/nonogram/nonogram_engine.gd")
const HomeKit = preload("res://scripts/games/nonogram/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const SIZES := [5, 10, 15]
const COLOR_FILL := Color("29e6ff")
const COLOR_CELL := Color(0.06, 0.08, 0.16)
const COLOR_CLUE := Color("ffae2b")
const COLOR_CLUE_DONE := Color(0.4, 0.42, 0.5)
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://nonogram_save.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: NonoEngine
var board: Control
var size_btn: Button
var mode_btn: Button
var win_dialog: ColorRect
var started := false  # a puzzle is on (not just the one behind Home)
var size_index: int = 1
var mark_mode: bool = false
var painting: bool = false
var paint_value: int = 0
var font: Font

func _ready() -> void:
	preload("res://scripts/games/nonogram/nonogram_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = NonoEngine.new()
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
	title.text = tr("🖼️ Nonogram")
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
	hint.text = tr("Numbers are the runs of filled squares in each row and column, in order.")
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

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 36)
	cm.add_child(controls)
	root.add_child(cm)
	mode_btn = Button.new()
	mode_btn.custom_minimum_size = Vector2(260, 76)
	mode_btn.add_theme_font_size_override("font_size", 28)
	mode_btn.pressed.connect(_toggle_mode)
	controls.add_child(mode_btn)
	size_btn = Button.new()
	size_btn.custom_minimum_size = Vector2(200, 76)
	size_btn.add_theme_font_size_override("font_size", 28)
	size_btn.pressed.connect(_cycle_size)
	controls.add_child(size_btn)

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/nonogram/nonogram_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	started = true
	engine.new_puzzle(SIZES[size_index])
	if info:
		info.start_clock()
	win_dialog.visible = false
	_update_buttons()
	board.queue_redraw()

func _cycle_size() -> void:
	size_index = (size_index + 1) % SIZES.size()
	_start_new_game()

func _toggle_mode() -> void:
	mark_mode = not mark_mode
	_update_buttons()

func _update_buttons() -> void:
	mode_btn.text = tr("Mode: ✕ Mark") if mark_mode else tr("Mode: ■ Fill")
	size_btn.text = "%d×%d" % [engine.n, engine.n]

# ---------- geometry ----------

func _clue_space() -> Vector2:
	var max_row := 1
	var max_col := 1
	for c in engine.row_clues:
		max_row = max(max_row, c.size())
	for c in engine.col_clues:
		max_col = max(max_col, c.size())
	return Vector2(max_row, max_col)

func _layout() -> Dictionary:
	var cs_count := _clue_space()
	var n: int = engine.n
	var cell: float = floor(min((board.size.x - 24.0) / (n + cs_count.x * 0.62), (board.size.y - 10.0) / (n + cs_count.y * 0.62)))
	var clue_w: float = cs_count.x * cell * 0.62
	var clue_h: float = cs_count.y * cell * 0.62
	var total := Vector2(clue_w + cell * n, clue_h + cell * n)
	var origin := Vector2((board.size.x - total.x) / 2.0 + clue_w, (board.size.y - total.y) / 2.0 + clue_h)
	return {"cell": cell, "origin": origin, "clue_w": clue_w, "clue_h": clue_h}

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
	if engine.solution.is_empty():
		return
	var L := _layout()
	var cell: float = L.cell
	var o: Vector2 = L.origin
	var n: int = engine.n
	var fs := int(clamp(cell * 0.5, 14.0, 30.0))
	for r in n:
		for c in n:
			var rect := Rect2(o + Vector2(c, r) * cell, Vector2(cell, cell)).grow(-1)
			var v: int = engine.get_cell(r, c)
			if _is_classic():
				board.draw_rect(rect, HomeKit.CLASSIC.ink if v == NonoEngine.FILLED else HomeKit.CLASSIC.paper)
				board.draw_rect(rect, HomeKit.CLASSIC.pencil, false, 1.0)
			else:
				board.draw_rect(rect, Color(COLOR_FILL, 0.75) if v == NonoEngine.FILLED else COLOR_CELL)
				board.draw_rect(rect, Color(HomeKit.BLUE, 0.35), false, 1.0)
			if v == NonoEngine.MARKED:
				var m := cell * 0.28
				var ce := rect.get_center()
				board.draw_line(ce - Vector2(m, m), ce + Vector2(m, m), HomeKit.PINK, 3)
				board.draw_line(ce + Vector2(-m, m), ce + Vector2(m, -m), HomeKit.PINK, 3)
	# thicker lines every 5 cells
	for i in range(0, n + 1, 5):
		board.draw_line(o + Vector2(i * cell, 0), o + Vector2(i * cell, n * cell), HomeKit.CLASSIC.ink if _is_classic() else Color(HomeKit.PURPLE, 0.9), 2)
		board.draw_line(o + Vector2(0, i * cell), o + Vector2(n * cell, i * cell), HomeKit.CLASSIC.ink if _is_classic() else Color(HomeKit.PURPLE, 0.9), 2)
	var step := cell * 0.62
	for r in n:
		var clue: Array = engine.row_clues[r]
		var col := COLOR_CLUE_DONE if engine.row_done(r) else COLOR_CLUE
		if _is_classic():
			col = HomeKit.CLASSIC.pencil if engine.row_done(r) else Color("e6e1cf")
		var shown: Array = clue if not clue.is_empty() else [0]
		for k in shown.size():
			var x: float = o.x - (shown.size() - k) * step
			board.draw_string(font, Vector2(x, o.y + (r + 0.5) * cell + fs * 0.36), str(shown[k]), HORIZONTAL_ALIGNMENT_CENTER, step, fs, col)
	for c in n:
		var clue: Array = engine.col_clues[c]
		var col := COLOR_CLUE_DONE if engine.col_done(c) else COLOR_CLUE
		if _is_classic():
			col = HomeKit.CLASSIC.pencil if engine.col_done(c) else Color("e6e1cf")
		var shown: Array = clue if not clue.is_empty() else [0]
		for k in shown.size():
			var y: float = o.y - (shown.size() - k - 0.5) * step
			board.draw_string(font, Vector2(o.x + c * cell, y + fs * 0.36), str(shown[k]), HORIZONTAL_ALIGNMENT_CENTER, cell, fs, col)

func _cell_at(pos: Vector2) -> Vector2i:
	var L := _layout()
	var p: Vector2 = (pos - L.origin) / L.cell
	var c := Vector2i(floori(p.x), floori(p.y))
	if c.x < 0 or c.y < 0 or c.x >= engine.n or c.y >= engine.n:
		return Vector2i(-1, -1)
	return c

func _on_board_input(event: InputEvent) -> void:
	if win_dialog.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			painting = false
			return
		var c := _cell_at(event.position)
		if c.x < 0:
			return
		var want := NonoEngine.MARKED if mark_mode else NonoEngine.FILLED
		# Dragging paints what the first tap did: fill, or clear if already filled.
		paint_value = NonoEngine.EMPTY if engine.get_cell(c.y, c.x) == want else want
		painting = true
		_paint(c)
	elif event is InputEventMouseMotion and painting:
		var c := _cell_at(event.position)
		if c.x >= 0:
			_paint(c)

func _paint(c: Vector2i) -> void:
	if engine.get_cell(c.y, c.x) == paint_value:
		return
	engine.set_cell(c.y, c.x, paint_value)
	_sfx("tick")
	board.queue_redraw()
	if engine.is_solved():
		SaveUtil.delete(SAVE_PATH)
		painting = false
		var secs := 0.0
		var record := false
		if info:
			info.add("Puzzles solved")
			info.celebrate("Solved!")
			secs = info.stop_clock()
			record = info.low("Best time (%s)" % ("%d×%d" % [SIZES[size_index], SIZES[size_index]]), secs)
		win_dialog.get_meta("message_label").text = tr("Every line matches its clues.")
		if info:
			win_dialog.get_meta("message_label").text += "\n" + tr("Time: %d:%02d") % [int(secs) / 60, int(secs) % 60]
			if record:
				win_dialog.get_meta("message_label").text += "  ·  " + tr("New best!")
		win_dialog.visible = true

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/nonogram/nonogram_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/nonogram/nonogram_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Use the number clues to fill in the hidden picture.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "5 × 5", "row": "size", "color": HomeKit.LIME, "action": _new_size.bind(0)},
			{"text": "10 × 10", "row": "size", "color": HomeKit.CYAN, "action": _new_size.bind(1)},
			{"text": "15 × 15", "row": "size", "color": HomeKit.PINK, "action": _new_size.bind(2)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _start_new_game,
		"board": "Puzzles solved",
		"board_note": "Pictures revealed, all sizes.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 6.0, 28.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.0, c.size.y / 2.0 - k * 2.2)
	var heart := ["01010", "11111", "11111", "01110", "00100"]
	var font := ThemeDB.fallback_font
	for r in 5:
		for col in 5:
			var rect := Rect2(o + Vector2(col, r) * k, Vector2(k, k)).grow(-1)
			if heart[r][col] == "1":
				c.draw_rect(rect, Color(COLOR_FILL, 0.6))
				c.draw_rect(rect, COLOR_FILL, false, 1.5)
			else:
				c.draw_rect(rect, Color(HomeKit.BLUE, 0.25), false, 1.0)
	for r in 5:
		c.draw_string(font, o + Vector2(-k * 1.6, (r + 0.75) * k), ["1 1", "5", "5", "3", "1"][r], HORIZONTAL_ALIGNMENT_RIGHT, k * 1.4, int(k * 0.6), HomeKit.GOLD)

func _new_size(i: int) -> void:
	size_index = i
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or win_dialog.visible or engine.solution.is_empty():
		return
	SaveUtil.write(SAVE_PATH, {"size_index": size_index, "n": engine.n, "solution": engine.solution,
		"rows": engine.row_clues, "cols": engine.col_clues, "cells": engine.cells})

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
		_start_new_game()
		return
	size_index = clampi(int(d.get("size_index", 0)), 0, SIZES.size() - 1)
	_start_new_game()
	engine.n = int(d.n)
	engine.solution = _ints(d.solution)
	engine.row_clues = []
	for rc in d.rows:
		engine.row_clues.append(_ints(rc))
	engine.col_clues = []
	for cc in d.cols:
		engine.col_clues.append(_ints(cc))
	engine.cells = _ints(d.cells)
	_update_buttons()
	board.queue_redraw()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
