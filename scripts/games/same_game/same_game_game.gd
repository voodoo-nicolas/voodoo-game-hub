extends Control

## Block Collapse: tap a group of matching blocks to clear it. The first
## tap shows the group and what it's worth; tap again to clear.

const SgEngine = preload("res://scripts/games/same_game/same_game_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/same_game/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/same_game/same_game_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://same_game_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const DIMS := [[8, 10, 3], [10, 12, 4], [12, 15, 5]]
const PALETTE := [Color("29e6ff"), Color("ff2bd6"), Color("7dff3a"), Color("ffae2b"), Color("9b4dff")]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var rng := RandomNumberGenerator.new()
var level: int = 1
var started := false
var finished := false
var picked: Array = []   # the highlighted group (first tap)

var board: Control
var score_label: Label
var info_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/same_game/same_game_i18n.gd").install(self)
	Orientation.lock_portrait()
	rng.randomize()
	engine = SgEngine.new()
	_build_ui()
	_deal(1)
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
	root.add_theme_constant_override("separation", 10)
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
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.add_theme_color_override("font_color", HomeKit.PURPLE.lerp(Color.WHITE, 0.6))
	score_label.add_theme_color_override("font_outline_color", Color(HomeKit.PURPLE, 0.6))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.pressed.connect(_restart)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.add_theme_color_override("font_color", HomeKit.DIM)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

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
	var undo := Button.new()
	undo.text = "↶ " + tr("Undo")
	undo.custom_minimum_size = Vector2(200, 64)
	undo.pressed.connect(_undo)
	row.add_child(undo)

	end_dialog = UI.build_dialog("", [
		{"text": tr("New game"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": LEVELS[i], "sub": tr("%d colours") % DIMS[i][2], "row": "levels",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": HomeKit.PURPLE,
		"subtitle": "Clear groups of matching blocks. Big groups score big.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)  # under the Undo button
	add_child(drawer)

# ---------- game flow ----------

func _new_game(lvl: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	_deal(lvl)

func _restart() -> void:
	_deal(level)

func _deal(lvl: int) -> void:
	level = lvl
	var d: Array = DIMS[lvl]
	engine.new_board(d[0], d[1], d[2], rng)
	started = true
	finished = false
	picked = []
	end_dialog.visible = false
	_render()

func _render() -> void:
	score_label.text = str(engine.score)
	if picked.size() >= 2:
		info_label.text = tr("%d blocks: +%d — tap again to clear") % [picked.size(), SgEngine.points_for(picked.size())]
	else:
		info_label.text = tr("%s   ·   Blocks left: %d") % [tr(LEVELS[level]), engine.remaining()]
	board.queue_redraw()

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or finished:
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.o) / g.cs
	if p.x < 0 or p.x >= engine.cols or p.y < 0 or p.y >= engine.rows:
		picked = []
		_render()
		return
	var x := int(p.x)
	var y: int = engine.rows - 1 - int(p.y)
	var cell := Vector2i(x, y)
	if cell in picked:
		var n: int = engine.remove(x, y)
		picked = []
		_sfx("explode" if n >= 10 else "merge")
		_render()
		_check_end()
		return
	picked = engine.group(x, y)
	if picked.size() < 2:
		picked = []
		_sfx("invalid")
	else:
		_sfx("toggle")
	_render()

func _check_end() -> void:
	if engine.has_moves():
		return
	finished = true
	SaveUtil.delete(SAVE_PATH)
	var left: int = engine.remaining()
	var msg := (tr("Board cleared! +%d") % SgEngine.CLEAR_BONUS if left == 0 else tr("No more groups — %d blocks left.") % left) + "\n" + tr("Score: %d") % engine.score
	if info:
		info.add("Games played")
		if left == 0:
			info.add("Boards cleared")
		info.low("Fewest blocks left", left)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_callback(_show_end)

func _show_end() -> void:
	end_dialog.visible = finished

func _undo() -> void:
	if finished:
		return
	if engine.undo():
		picked = []
		_sfx("back")
		_render()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var cs: float = floor(minf((board.size.x - 24.0) / engine.cols, (board.size.y - 10.0) / engine.rows))
	var o := Vector2((board.size.x - cs * engine.cols) / 2.0, board.size.y - cs * engine.rows - 5.0)
	return {"cs": cs, "o": o}

## Look (STANDARDS §9): "classic" = solid coloured blocks (default); "voodoo" = the neon
## board. Set by the kit (Options → Look).
const CLASSIC_PAL := [Color("d62828"), Color("2a9d4a"), Color("1e5bd8"), Color("f6c90e"), Color("7b3fb0")]
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
	if engine.grid.is_empty():
		return
	var g := _geom()
	var cs: float = g.cs
	if _is_classic():
		board.draw_rect(Rect2(g.o, Vector2(cs * engine.cols, cs * engine.rows)).grow(4), HomeKit.CLASSIC.wood_frame)
	else:
		HomeKit.glow_rect(board, Rect2(g.o, Vector2(cs * engine.cols, cs * engine.rows)).grow(4), Color(HomeKit.PURPLE, 0.6), 1.5)
	for x in engine.cols:
		for y in engine.rows:
			var v: int = engine.grid[x][y]
			if v == SgEngine.EMPTY:
				continue
			var r := Rect2(g.o + Vector2(x, engine.rows - 1 - y) * cs, Vector2(cs, cs)).grow(-2)
			var col: Color = PALETTE[v]
			var hot: bool = Vector2i(x, y) in picked
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col, 0.75 if hot else 0.35)
			sb.border_color = Color.WHITE if hot else col
			sb.set_border_width_all(3 if hot else 2)
			sb.set_corner_radius_all(int(cs * 0.2))
			sb.shadow_color = Color(col, 0.5 if hot else 0.15)
			sb.shadow_size = 8 if hot else 2
			if _is_classic():
				col = CLASSIC_PAL[v % CLASSIC_PAL.size()]
				sb.bg_color = col.lightened(0.25) if hot else col
				sb.border_color = Color.WHITE if hot else col.darkened(0.35)
				sb.set_border_width_all(3)
				sb.shadow_color = Color(0, 0, 0, 0.3)
				sb.shadow_size = 2
				sb.shadow_offset = Vector2(1, 2)
			board.draw_style_box(sb, r)

func _draw_home_logo(c: Control) -> void:
	var cs := minf(c.size.y / 4.5, 34.0)
	var cols := [[0, 0, 1], [2, 0, 1, 3], [2, 2], [3, 1, 1, 0], [0, 3]]
	var o := Vector2(c.size.x / 2.0 - cs * 2.5, c.size.y / 2.0 + cs * 2.0)
	for x in cols.size():
		for y in cols[x].size():
			var r := Rect2(o + Vector2(x * cs, -(y + 1) * cs), Vector2(cs, cs)).grow(-2)
			HomeKit.glow_rect(c, r, PALETTE[cols[x][y]], 2.0, 0.3)

# ---------- pause / save ----------

func _on_pause() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or finished:
		return
	SaveUtil.write(SAVE_PATH, {"level": level, "grid": engine.grid, "score": engine.score})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr(LEVELS[clampi(int(d.get("level", 0)), 0, 2)]) + "   ·   " + tr("Score: %d") % int(d.get("score", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_deal(1)
		return
	var lvl := clampi(int(d.get("level", 1)), 0, 2)
	_deal(lvl)
	var gr: Array = d.get("grid", [])
	if gr.size() != engine.cols:
		return
	engine.grid = []
	for col in gr:
		var cc: Array = []
		for v in col:
			cc.append(int(v))
		engine.grid.append(cc)
	engine.score = int(d.get("score", 0))
	_render()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
