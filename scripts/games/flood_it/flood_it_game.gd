extends Control

## Flood It: tap a colour below the board; the flood from the top-left
## corner takes that colour and grows. Fill the board within the limit.

const FiEngine = preload("res://scripts/games/flood_it/flood_it_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/flood_it/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/flood_it/flood_it_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://flood_it_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const SIZES := [10, 14, 18]
const N_COLORS := [5, 6, 7]
const PALETTE := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b"), Color("9b4dff"), Color("ff3b3b"), Color("f5f5ff")]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var level: int = 0
var started := false
var finished := false
var wave: Dictionary = {}  # cell -> time since it joined the flood (for a ripple)

var board: Control
var status_label: Label
var color_row: HBoxContainer
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/flood_it/flood_it_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = FiEngine.new()
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
	title.text = tr("Flood It")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HomeKit.CYAN.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(HomeKit.CYAN, 0.5))
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
	status_label.add_theme_font_size_override("font_size", 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 34)
	cm.add_theme_constant_override("margin_left", 12)
	cm.add_theme_constant_override("margin_right", 12)
	root.add_child(cm)
	color_row = HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	color_row.add_theme_constant_override("separation", 10)
	cm.add_child(color_row)

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
		"subtitle": "Pick a colour, grow the flood. Fill the board before you run out of moves.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Puzzles solved",
		"board_note": "Boards flooded, any size.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.06)  # beside the title
	add_child(drawer)

func _make_color_buttons() -> void:
	for c in color_row.get_children():
		c.queue_free()
	var w: float = minf(92.0, (get_viewport_rect().size.x - 40.0) / engine.colors - 10.0)
	for i in engine.colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(w, w)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		var sb := HomeKit.neon_box(PALETTE[i], "normal")
		sb.bg_color = Color(PALETTE[i], 0.6)
		sb.set_corner_radius_all(int(w / 2.0))
		var sbp := sb.duplicate()
		sbp.bg_color = Color(PALETTE[i], 0.9)
		for st in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("pressed", sbp)
		b.pressed.connect(_pick.bind(i))
		color_row.add_child(b)

# ---------- game flow ----------

func _new_game(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(lvl)

func _restart() -> void:
	_deal(level)

func _deal(lvl: int) -> void:
	level = lvl
	engine.new_board(SIZES[lvl], N_COLORS[lvl], rng)
	started = true
	finished = false
	wave.clear()
	end_dialog.visible = false
	_make_color_buttons()
	_render()

func _render() -> void:
	status_label.text = tr("Moves: %d / %d") % [engine.moves, engine.limit]
	status_label.add_theme_color_override("font_color", HomeKit.PINK if engine.limit - engine.moves <= 2 else HomeKit.WHITE)
	board.queue_redraw()

func _on_board_input(event: InputEvent) -> void:
	# Tapping a cell picks its colour too.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.o) / g.cs
	if p.x >= 0 and p.y >= 0 and p.x < engine.size and p.y < engine.size:
		_pick(engine.grid[int(p.y) * engine.size + int(p.x)])

func _pick(c: int) -> void:
	if finished:
		return
	var before: Dictionary = engine.flooded()
	if not engine.pick(c):
		_sfx("invalid")
		return
	_sfx("pickup")
	for i in engine.flooded():
		if not before.has(i):
			wave[i] = 0.0
	_render()
	if engine.won():
		_finish(true)
	elif engine.lost():
		_finish(false)

func _process(delta: float) -> void:
	if wave.is_empty():
		return
	for k in wave.keys():
		wave[k] += delta
		if wave[k] > 0.5:
			wave.erase(k)
	board.queue_redraw()

func _finish(won: bool) -> void:
	finished = true
	SaveUtil.delete(SAVE_PATH)
	var msg: String
	if won:
		msg = tr("Flooded in %d moves!") % engine.moves
		if info:
			info.add("Puzzles solved")
			info.result("win")
			if info.low("Fewest moves (%s)" % LEVELS[level], engine.moves):
				msg += "\n" + tr("New best!")
	else:
		msg = tr("Out of moves!")
		if info:
			info.result("loss")
	if info:
		msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_callback(_show_end)

func _show_end() -> void:
	end_dialog.visible = finished

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side: float = minf(board.size.x - 32.0, board.size.y - 10.0)
	var cs: float = floor(side / engine.size)
	var span: float = cs * engine.size
	return {"cs": cs, "o": Vector2((board.size.x - span) / 2.0, (board.size.y - span) / 2.0)}

func _draw_board() -> void:
	if engine.grid.is_empty():
		return
	var g := _geom()
	var cs: float = g.cs
	var n: int = engine.size
	var span := cs * n
	var flood: Dictionary = engine.flooded()
	HomeKit.glow_rect(board, Rect2(g.o, Vector2(span, span)).grow(6), Color(PALETTE[engine.grid[0]], 0.8), 2.0)
	for i in n * n:
		var r := Rect2(g.o + Vector2(i % n, i / n) * cs, Vector2(cs, cs))
		var col: Color = PALETTE[engine.grid[i]]
		var a := 0.85 if flood.has(i) else 0.55
		if wave.has(i):
			col = col.lerp(Color.WHITE, 0.6 * (1.0 - wave[i] / 0.5))
		board.draw_rect(r.grow(-1), Color(col, a))
		if not flood.has(i):
			board.draw_rect(r.grow(-1), Color(0, 0, 0, 0.18), false, 1.0)

func _draw_home_logo(c: Control) -> void:
	var cs := minf(c.size.y / 5.0, 30.0)
	var o := c.size / 2.0 - Vector2(cs * 2.5, cs * 2.5)
	var cells := [0, 0, 0, 1, 2, 0, 0, 3, 1, 4, 0, 3, 3, 2, 1, 1, 2, 4, 4, 0, 2, 1, 0, 3, 2]
	for i in 25:
		var r := Rect2(o + Vector2(i % 5, i / 5) * cs, Vector2(cs, cs)).grow(-1.5)
		c.draw_rect(r, Color(PALETTE[cells[i]], 0.85 if cells[i] == 0 else 0.5))
	HomeKit.glow_rect(c, Rect2(o, Vector2(cs * 5, cs * 5)).grow(4), PALETTE[0], 2.0)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or finished:
		return
	SaveUtil.write(SAVE_PATH, {"level": level, "grid": engine.grid, "moves": engine.moves, "limit": engine.limit})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr(LEVELS[clampi(int(d.get("level", 0)), 0, 2)]) + "   ·   " + tr("Moves: %d / %d") % [int(d.get("moves", 0)), int(d.get("limit", 0))]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_deal(0)
		return
	var lvl := clampi(int(d.get("level", 0)), 0, 2)
	_deal(lvl)
	if d.get("grid", []).size() != SIZES[lvl] * SIZES[lvl]:
		return
	engine.grid = []
	for v in d.grid:
		engine.grid.append(int(v))
	engine.moves = int(d.get("moves", 0))
	engine.limit = int(d.get("limit", engine.limit))
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
