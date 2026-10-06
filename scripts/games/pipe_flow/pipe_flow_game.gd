extends Control

## Pipe Flow: turn the pipe pieces until every one is joined to the pump in
## the middle, with no open ends. Water lights up each piece as it connects.

const PipeEngine = preload("res://scripts/games/pipe_flow/pipe_flow_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/pipe_flow/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/pipe_flow/pipe_flow_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://pipe_flow_save.json"

const LEVELS := ["Easy", "Medium", "Hard", "Expert"]
const SIZES := [5, 7, 9, 11]
const COLOR_DRY := Color("9b4dff")
const COLOR_WET := Color("29e6ff")
const COLOR_PUMP := Color("ffae2b")
const COLOR_LEAK := Color("ff4f9a")
const TURN_SPEED := 14.0  # radians per second for the quarter-turn animation

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var level: int = 0
var elapsed: float = 0.0
var started := false  # a real game is on (not just the board behind Home)
var solved := false
var water: Dictionary = {}  # cells the water reaches
var spin: Dictionary = {}  # cell -> angle still to turn (animation)
var win_t: float = -1.0  # seconds since solved, for the flow ripple

var board: Control
var status_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/pipe_flow/pipe_flow_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = PipeEngine.new()
	_build_ui()
	_new_board(0)
	started = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

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
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🚰 Pipe Flow")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", COLOR_WET.lerp(Color.WHITE, 0.7))
	title.add_theme_color_override("font_outline_color", Color(COLOR_WET, 0.5))
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
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var hint := Label.new()
	hint.text = tr("Tap a pipe to turn it.")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", HomeKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_bottom", 28)
	hm.add_child(hint)
	root.add_child(hm)

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
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK, HomeKit.GOLD][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": COLOR_WET,
		"subtitle": "Turn the pipes until the water reaches every one.",
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
	drawer.set("default_frac", 0.975)  # by the hint line, under the board
	add_child(drawer)

# ---------- game flow ----------

func _new_game(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_new_board(lvl)

func _restart() -> void:
	_new_board(level)

func _new_board(lvl: int) -> void:
	level = lvl
	engine.new_board(SIZES[lvl], rng)
	elapsed = 0.0
	solved = false
	started = true
	spin.clear()
	win_t = -1.0
	end_dialog.visible = false
	_update()

func _update() -> void:
	water = engine.filled()
	_status()
	board.queue_redraw()

func _status() -> void:
	status_label.text = tr("%s   ·   Moves: %d   ·   %s") % [tr(LEVELS[level]), engine.moves, _clock(elapsed)]

static func _clock(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]

func _process(delta: float) -> void:
	if started and not solved:
		var before := int(elapsed)
		elapsed += delta
		if int(elapsed) != before:
			_status()
	if not spin.is_empty():
		for c in spin.keys():
			spin[c] = move_toward(spin[c], 0.0, delta * TURN_SPEED)
			if spin[c] == 0.0:
				spin.erase(c)
		board.queue_redraw()
	if win_t >= 0.0 and win_t < 3.0:
		win_t += delta
		board.queue_redraw()

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if solved:
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.origin) / g.cell
	if p.x < 0 or p.y < 0 or p.x >= engine.size or p.y >= engine.size:
		return
	var cell: int = int(p.y) * engine.size + int(p.x)
	if PipeEngine.rotated(engine.mask[cell]) == engine.mask[cell]:
		return  # a cross: turning changes nothing
	engine.rotate(cell)
	spin[cell] = spin.get(cell, 0.0) - PI / 2.0
	_sfx("slide")
	_update()
	if engine.is_solved():
		_on_solved()

func _on_solved() -> void:
	solved = true
	win_t = 0.0
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Solved in %d moves!") % engine.moves + "\n" + tr("Time: %s") % _clock(elapsed)
	if info:
		info.add("Puzzles solved")
		var secs := int(elapsed)
		if info.low("Best time (%s)" % LEVELS[level], secs):
			msg += "\n" + tr("New best time!")
		info.celebrate(tr("Solved!"))
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(1.4)
	t.tween_callback(_show_end)

func _show_end() -> void:
	end_dialog.visible = true

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side: float = minf(board.size.x - 40.0, board.size.y - 20.0)
	var cell: float = floor(side / engine.size)
	var span: float = cell * engine.size
	return {"cell": cell, "origin": Vector2((board.size.x - span) / 2.0, (board.size.y - span) / 2.0)}

## Look (STANDARDS §9): "classic" = a grey plate with copper pipes and blue water (default); "voodoo" = the neon
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
	if engine.mask.is_empty():
		return
	var g := _geom()
	var cell: float = g.cell
	var n: int = engine.size
	var frame := Rect2(g.origin, Vector2(cell * n, cell * n))
	if _is_classic():
		board.draw_rect(frame.grow(8), HomeKit.CLASSIC.wood_frame)
	else:
		board.draw_rect(frame.grow(8), Color(0.03, 0.04, 0.09))
		HomeKit.glow_rect(board, frame.grow(8), Color(COLOR_DRY, 0.7), 2.0)
	for i in n * n:
		var center: Vector2 = g.origin + Vector2(i % n + 0.5, i / n + 0.5) * cell
		if _is_classic():
			board.draw_rect(Rect2(center - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), Color("d8dde3"))
			board.draw_rect(Rect2(center - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), Color(0, 0, 0, 0.18), false, 1.0)
		else:
			board.draw_rect(Rect2(center - Vector2(cell, cell) * 0.46, Vector2(cell, cell) * 0.92), Color(1, 1, 1, 0.025))
		_draw_piece(i, center, cell)

func _draw_piece(i: int, center: Vector2, cell: float) -> void:
	var m: int = engine.mask[i]
	var wet := water.has(i)
	var col := COLOR_WET if wet else COLOR_DRY
	if _is_classic():
		col = Color("1e7fd6") if wet else Color("b87333")
	if wet and win_t >= 0.0:
		# A ripple of light running out from the pump once it's solved.
		var dist := (center - _cell_center(engine.source)).length() / cell
		var wave := clampf(1.0 - absf(dist - win_t * 6.0) / 1.5, 0.0, 1.0)
		col = col.lerp(Color.WHITE, wave * 0.7)
	var angle: float = spin.get(i, 0.0)
	var w := cell * (0.2 if wet else 0.16)
	var half := cell * 0.5
	for k in 4:
		var d: Array = PipeEngine.DIRS[k]
		if m & d[0] == 0:
			continue
		var dir := Vector2(d[1], d[2]).rotated(angle)
		if _is_classic():
			board.draw_line(center, center + dir * half, col, w * 1.1)
		else:
			HomeKit.glow_line(board, center, center + dir * half, col, w * 0.45)
		if wet and not solved and engine.leaks(i) & d[0] and angle == 0.0:
			board.draw_circle(center + dir * half * 0.86, w * 0.42, COLOR_LEAK)
	board.draw_circle(center, w * 0.5, col)
	if _is_classic() and (i == engine.source or PipeEngine.is_end(m)):
		var pc: Color = HomeKit.CLASSIC.red if i == engine.source else col.darkened(0.3)
		board.draw_circle(center, cell * (0.26 if i == engine.source else 0.18), pc)
		board.draw_arc(center, cell * (0.26 if i == engine.source else 0.18), 0, TAU, 20, pc.darkened(0.4), 2.0, true)
	elif i == engine.source:
		HomeKit.glow_circle(board, center, cell * 0.28, COLOR_PUMP, 3.0, 0.5)
		board.draw_circle(center, cell * 0.12, COLOR_PUMP.lerp(Color.WHITE, 0.5))
	elif PipeEngine.is_end(m):
		HomeKit.glow_circle(board, center, cell * 0.2, col, 2.5, 0.25 if wet else 0.08)

func _cell_center(i: int) -> Vector2:
	var g := _geom()
	return g.origin + Vector2(i % engine.size + 0.5, i / engine.size + 0.5) * g.cell

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.2, 56.0)
	var o := Vector2(c.size.x / 2.0 - k * 1.5, c.size.y / 2.0 - k * 1.5)
	# A little 3x3 board: a pump in the middle, wet pipes running out of it.
	var masks := [2, 14, 8, 2, 15, 8, 2, 11, 1]
	for i in 9:
		var ctr := o + Vector2(i % 3 + 0.5, i / 3 + 0.5) * k
		var col: Color = COLOR_WET if i != 8 else COLOR_DRY
		for d in PipeEngine.DIRS:
			if masks[i] & d[0]:
				HomeKit.glow_line(c, ctr, ctr + Vector2(d[1], d[2]) * k * 0.5, col, k * 0.09)
		c.draw_circle(ctr, k * 0.1, col)
	HomeKit.glow_circle(c, o + Vector2(1.5, 1.5) * k, k * 0.26, COLOR_PUMP, 3.0, 0.5)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or solved:
		return
	SaveUtil.write(SAVE_PATH, {"level": level, "n": engine.size, "mask": engine.mask,
		"source": engine.source, "moves": engine.moves, "time": elapsed})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	return tr(LEVELS[clampi(int(d.get("level", 0)), 0, LEVELS.size() - 1)]) + "   ·   " + _clock(float(d.get("time", 0)))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	var n := int(d.get("n", 0)) if d else 0
	if d == null or d.get("mask", []).size() != n * n or n < 2:
		_new_board(0)
		return
	_new_board(clampi(int(d.get("level", 0)), 0, LEVELS.size() - 1))
	engine.size = n
	engine.mask = []
	for v in d.mask:
		engine.mask.append(int(v))
	engine.source = int(d.get("source", (n / 2) * n + n / 2))
	engine.moves = int(d.get("moves", 0))
	elapsed = float(d.get("time", 0.0))
	_update()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
