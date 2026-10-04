extends Control

## Binary Grid: tap a cell to cycle empty -> cyan -> pink. No three of a
## colour in a row; every row and column half and half.

const BgEngine = preload("res://scripts/games/binary_grid/binary_grid_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/binary_grid/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/binary_grid/binary_grid_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://binary_grid_save.json"

const LEVELS := ["Easy", "Medium", "Hard"]
const SIZES := [6, 8, 10]
const COLS := [Color("29e6ff"), Color("ff2bd6")]
const BAD := Color("ff3b3b")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var level: int = 0
var started := false
var finished := false
var elapsed: float = 0.0
var hint_cell: int = -1
var hints_used: int = 0

var board: Control
var status_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/binary_grid/binary_grid_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = BgEngine.new()
	_build_ui()
	_deal(0)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

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
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("Binary Grid")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.CYAN.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.MAGENTA, 0.5))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 30)
	root.add_child(bm)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bm.add_child(row)
	var hint := Button.new()
	hint.text = "💡 " + tr("Hint")
	hint.custom_minimum_size = Vector2(200, 64)
	hint.pressed.connect(_hint)
	row.add_child(hint)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Next puzzle"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": LEVELS[i], "sub": "%d × %d" % [SIZES[i], SIZES[i]], "row": "levels",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Two colours, half and half, never three in a row.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved at any size.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)  # under the Hint button
	add_child(drawer)

# ---------- game flow ----------

func _new_game(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(lvl)

func _restart() -> void:
	_deal(level)

func _deal(lvl: int) -> void:
	level = lvl
	engine.new_puzzle(SIZES[lvl], rng)
	started = true
	finished = false
	elapsed = 0.0
	hint_cell = -1
	hints_used = 0
	end_dialog.visible = false
	_status()
	board.queue_redraw()

func _process(delta: float) -> void:
	if started and not finished:
		var before := int(elapsed)
		elapsed += delta
		if int(elapsed) != before:
			_status()

func _status() -> void:
	var s := int(elapsed)
	status_label.text = tr("%s   ·   %d:%02d") % [tr(LEVELS[level]), s / 60, s % 60]

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or finished:
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.o) / g.cs
	if p.x < 0 or p.y < 0 or p.x >= engine.n or p.y >= engine.n:
		return
	var i: int = int(p.y) * engine.n + int(p.x)
	if not engine.cycle(i):
		_sfx("invalid")
		return
	hint_cell = -1
	_sfx("toggle")
	board.queue_redraw()
	if engine.solved():
		_finish()

func _hint() -> void:
	if finished:
		return
	hint_cell = engine.hint()
	hints_used += 1
	_sfx("notify")
	board.queue_redraw()

func _finish() -> void:
	finished = true
	SaveUtil.delete(SAVE_PATH)
	var s := int(elapsed)
	var msg := tr("Solved!") + "\n" + tr("Time: %d:%02d") % [s / 60, s % 60]
	if info:
		info.add("Puzzles solved")
		if hints_used == 0 and info.low("Best time (%s)" % LEVELS[level], s):
			msg += "\n" + tr("New best time!")
		info.celebrate(tr("Solved!"))
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_callback(_show_end)

func _show_end() -> void:
	end_dialog.visible = finished

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side: float = minf(board.size.x - 48.0, board.size.y - 40.0)
	var cs: float = floor(side / engine.n)
	var span: float = cs * engine.n
	return {"cs": cs, "o": Vector2((board.size.x - span) / 2.0, (board.size.y - span) / 2.0)}

func _draw_board() -> void:
	if engine.cells.is_empty():
		return
	var g := _geom()
	var cs: float = g.cs
	var n: int = engine.n
	var bad: Dictionary = engine.errors()
	var font := ThemeDB.fallback_font
	HomeKit.glow_rect(board, Rect2(g.o, Vector2(cs * n, cs * n)).grow(6), Color(HomeKit.PURPLE, 0.7), 2.0)
	for i in n * n:
		var r := Rect2(g.o + Vector2(i % n, i / n) * cs, Vector2(cs, cs))
		board.draw_rect(r.grow(-2), Color(1, 1, 1, 0.04))
		var v: int = engine.cells[i]
		if v != BgEngine.EMPTY:
			var col: Color = COLS[v]
			var c := r.get_center()
			board.draw_circle(c, cs * 0.36, Color(col, 0.55 if engine.given[i] else 0.3))
			HomeKit.glow_circle(board, c, cs * 0.36, BAD if bad.has(i) else col, 2.0)
			if engine.given[i]:
				board.draw_circle(c, cs * 0.08, Color(1, 1, 1, 0.8))
		if i == hint_cell:
			HomeKit.glow_rect(board, r.grow(-3), HomeKit.GOLD, 2.5)
	# Per-row / per-column counts: n/2 of each colour when full.
	for k in n:
		var rc := [0, 0]
		var cc := [0, 0]
		for j in n:
			var a: int = engine.cells[k * n + j]
			var b: int = engine.cells[j * n + k]
			if a >= 0:
				rc[a] += 1
			if b >= 0:
				cc[b] += 1
		var done_row: bool = rc[0] == n / 2 and rc[1] == n / 2
		var done_col: bool = cc[0] == n / 2 and cc[1] == n / 2
		board.draw_circle(g.o + Vector2(n * cs + 14, (k + 0.5) * cs), 4.0, HomeKit.LIME if done_row else Color(1, 1, 1, 0.15))
		board.draw_circle(g.o + Vector2((k + 0.5) * cs, n * cs + 14), 4.0, HomeKit.LIME if done_col else Color(1, 1, 1, 0.15))

func _draw_home_logo(c: Control) -> void:
	var cs := minf(c.size.y / 4.5, 34.0)
	var pat := [0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0]
	var o := c.size / 2.0 - Vector2(cs * 2, cs * 2)
	for i in 16:
		var p := o + Vector2(i % 4 + 0.5, i / 4 + 0.5) * cs
		HomeKit.glow_circle(c, p, cs * 0.36, COLS[pat[i]], 2.0, 0.35)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or finished:
		return
	SaveUtil.write(SAVE_PATH, {"level": level, "n": engine.n, "cells": engine.cells, "given": engine.given,
		"solution": engine.solution, "time": elapsed, "hints": hints_used})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var s := int(d.get("time", 0))
	return tr(LEVELS[clampi(int(d.get("level", 0)), 0, 2)]) + "   ·   %d:%02d" % [s / 60, s % 60]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_deal(0)
		return
	level = clampi(int(d.get("level", 0)), 0, 2)
	var n := int(d.get("n", 0))
	if n != SIZES[level] or d.get("cells", []).size() != n * n:
		_deal(level)
		return
	engine.n = n
	engine.cells = []
	engine.given = []
	engine.solution = []
	for k in n * n:
		engine.cells.append(int(d.cells[k]))
		engine.given.append(bool(d.given[k]))
		engine.solution.append(int(d.solution[k]))
	engine.moves = 0
	started = true
	finished = false
	elapsed = float(d.get("time", 0.0))
	hints_used = int(d.get("hints", 0))
	hint_cell = -1
	end_dialog.visible = false
	_status()
	board.queue_redraw()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
