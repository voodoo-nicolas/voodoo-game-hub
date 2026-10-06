extends Control

## Word Search -- drag from the first letter of a word to its last.

const WSEngine = preload("res://scripts/games/word_search/word_search_engine.gd")
const HomeKit = preload("res://scripts/games/word_search/home_kit.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const SAVE_PATH := "user://word_search_save.json"

const HIGHLIGHTS := [Color(1, 0.4, 0.4, 0.45), Color(0.4, 0.8, 1, 0.45), Color(0.5, 1, 0.5, 0.45),
	Color(1, 0.85, 0.3, 0.45), Color(0.85, 0.5, 1, 0.45), Color(1, 0.6, 0.2, 0.45), Color(0.3, 1, 0.85, 0.45),
	Color(1, 0.5, 0.8, 0.45)]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: WSEngine
var board: Control
var theme_label: Label
var list_label: RichTextLabel
var status_label: Label
var level: int = 1
var started := false  # a puzzle is on (not just the one behind Home)
var win_dialog: ColorRect
var drag_start := Vector2i(-1, -1)
var drag_end := Vector2i(-1, -1)
var font: Font

func _ready() -> void:
	preload("res://scripts/games/word_search/word_search_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = WSEngine.new()
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
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.add_theme_font_size_override("font_size", 30)
	pause_btn.pressed.connect(_on_pause_home)
	bar.add_child(pause_btn)
	var title := Label.new()
	title.text = tr("🔍 Word Search")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	theme_label = Label.new()
	theme_label.add_theme_font_size_override("font_size", 28)
	theme_label.add_theme_color_override("font_color", HomeKit.GOLD)
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(theme_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 30)
	lm.add_theme_constant_override("margin_right", 30)
	root.add_child(lm)
	list_label = RichTextLabel.new()
	list_label.bbcode_enabled = true
	list_label.fit_content = true
	list_label.scroll_active = false
	list_label.add_theme_font_size_override("normal_font_size", 28)
	list_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lm.add_child(list_label)

	# Level and progress, centred on the bottom line; the ⚙ tab sits at its
	# right end, clear of the grid and the word list.
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", HomeKit.DIM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_bottom", 24)
	sm.add_child(status_label)
	root.add_child(sm)

	win_dialog = UI.build_dialog(tr("All found!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/word_search/word_search_help.gd"))
	_build_home()
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.975)
	add_child(drawer)

func _start_new_game() -> void:
	started = true
	engine.new_puzzle(TranslationServer.get_locale().begins_with("es"), -1, level)
	if info:
		info.start_clock()
	win_dialog.visible = false
	drag_start = Vector2i(-1, -1)
	theme_label.text = tr("Theme: %s") % engine.theme
	_update_list()
	board.queue_redraw()

func _update_list() -> void:
	var parts: Array = []
	for i in engine.words.size():
		var w: Dictionary = engine.words[i]
		if w.found:
			parts.append("[color=#6a6a78][s]%s[/s][/color]" % w.word)
		else:
			parts.append(w.word)
	list_label.text = "[center]" + "     ".join(PackedStringArray(parts)) + "[/center]"
	var found := 0
	for w in engine.words:
		if w.found:
			found += 1
	status_label.text = tr(WSEngine.LEVELS[engine.level].name) + "  ·  " + tr("%d / %d found") % [found, engine.words.size()]

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side: float = min(board.size.x - 32.0, board.size.y - 8.0)
	var cell: float = side / engine.size
	return {"cell": cell, "origin": Vector2((board.size.x - side) / 2.0, (board.size.y - side) / 2.0)}

func _center_of(g: Dictionary, c: Vector2i) -> Vector2:
	return g.origin + (Vector2(c) + Vector2(0.5, 0.5)) * g.cell

## Look (STANDARDS §9): "classic" = a paper grid with ink letters (default); "voodoo" = the neon
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
	if engine.grid.is_empty():
		return
	var g := _geom()
	var cell: float = g.cell
	if cell < 8.0:
		return  # not laid out yet: text this small has a font size of 0
	var n: int = engine.size
	var grid_rect := Rect2(g.origin, Vector2(cell, cell) * n)
	if _is_classic():
		board.draw_rect(grid_rect, HomeKit.CLASSIC.paper)
		board.draw_rect(grid_rect, HomeKit.CLASSIC.pencil, false, 2.0)
	else:
		board.draw_rect(grid_rect, HomeKit.PANEL)
		HomeKit.glow_rect(board, grid_rect.grow(4), HomeKit.CYAN, 2.0)
	for i in engine.words.size():
		var w: Dictionary = engine.words[i]
		if w.found:
			var e: Vector2i = w.start + w.dir * (w.word.length() - 1)
			_draw_capsule(_center_of(g, w.start), _center_of(g, e), cell * 0.4, HIGHLIGHTS[i % HIGHLIGHTS.size()])
	if drag_start.x >= 0 and drag_end.x >= 0:
		var cells := WSEngine.line(drag_start, drag_end)
		if not cells.is_empty():
			_draw_capsule(_center_of(g, drag_start), _center_of(g, drag_end), cell * 0.4, Color(0.3, 0.5, 1, 0.4))
	var fs := int(cell * 0.55)
	for i in n * n:
		var p := Vector2i(i % n, i / n)
		var c := _center_of(g, p)
		board.draw_string(font, Vector2(c.x - cell / 2.0, c.y + fs * 0.36), engine.grid[i], HORIZONTAL_ALIGNMENT_CENTER, cell, fs, HomeKit.CLASSIC.ink if _is_classic() else HomeKit.WHITE)

## A pill with round ends that reach past the first and last letters' centres
## by `radius`, so both end letters sit fully inside it. One polygon, so the
## see-through color doesn't double up where ends and middle would overlap.
func _draw_capsule(a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	var dir := (b - a).normalized() if a != b else Vector2.RIGHT
	var normal := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:  # half circle around b
		var t := -PI / 2.0 + PI * i / steps
		pts.append(b + (dir * cos(t) + normal * -sin(t)) * radius)
	for i in steps + 1:  # half circle around a
		var t := PI / 2.0 + PI * i / steps
		pts.append(a + (dir * cos(t) + normal * -sin(t)) * radius)
	board.draw_colored_polygon(pts, color)

func _cell_at(pos: Vector2) -> Vector2i:
	var g := _geom()
	var p: Vector2 = (pos - g.origin) / g.cell
	var c := Vector2i(clampi(floori(p.x), 0, engine.size - 1), clampi(floori(p.y), 0, engine.size - 1))
	return c

func _on_board_input(event: InputEvent) -> void:
	if win_dialog.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start = _cell_at(event.position)
			drag_end = drag_start
		elif drag_start.x >= 0:
			if engine.try_select(drag_start, drag_end) >= 0:
				_update_list()
				if engine.all_found():
					SaveUtil.delete(SAVE_PATH)
					var secs := 0.0
					var record := false
					if info:
						info.add("Puzzles solved")
						info.celebrate("Solved!")
						secs = info.stop_clock()
						record = info.low("Best time (%s)" % WSEngine.LEVELS[engine.level].name, secs)
					win_dialog.get_meta("message_label").text = tr("You found all %d words.") % engine.words.size()
					if info:
						win_dialog.get_meta("message_label").text += "\n" + tr("Time: %d:%02d") % [int(secs) / 60, int(secs) % 60]
						if record:
							win_dialog.get_meta("message_label").text += "  ·  " + tr("New best!")
					win_dialog.visible = true
				else:
					_sfx("letter_right")
			drag_start = Vector2i(-1, -1)
		board.queue_redraw()
	elif event is InputEventMouseMotion and drag_start.x >= 0:
		var c := _cell_at(event.position)
		# snap to the nearest straight line so sloppy diagonals still work
		var d := c - drag_start
		if not WSEngine.line(drag_start, c).is_empty():
			drag_end = c
		elif abs(d.x) > 2 * abs(d.y):
			drag_end = Vector2i(c.x, drag_start.y)
		elif abs(d.y) > 2 * abs(d.x):
			drag_end = Vector2i(drag_start.x, c.y)
		else:
			var n: int = min(abs(d.x), abs(d.y))
			drag_end = drag_start + Vector2i(signi(d.x) * n, signi(d.y) * n)
		board.queue_redraw()

func _sfx(sound: String) -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound)

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/word_search/word_search_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/word_search/word_search_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Find every hidden word in the grid.",
		"logo": _draw_home_logo,
		"modes": [
			{"text": "Easy", "sub": "8 × 8 · 6 words", "row": "level", "color": HomeKit.LIME, "action": _new_level.bind(0)},
			{"text": "Medium", "sub": "10 × 10 · 8 words", "row": "level", "color": HomeKit.CYAN, "action": _new_level.bind(1)},
			{"text": "Hard", "sub": "14 × 14 · 12 words", "row": "level", "color": HomeKit.PINK, "action": _new_level.bind(2)},
		],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"restart": _start_new_game,
		"board": "Puzzles solved",
		"board_note": "Puzzles solved, every level.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

## A 4x4 letter grid with WORD ringed along the top and a diagonal ringed below.
func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.6, 40.0)
	var o := Vector2(c.size.x / 2.0 - k * 2, c.size.y / 2.0 - k * 2)
	_logo_pill(c, o, k, Vector2i(0, 0), Vector2i(3, 0), HomeKit.LIME)
	_logo_pill(c, o, k, Vector2i(0, 1), Vector2i(2, 3), HomeKit.MAGENTA)
	HomeKit.glow_rect(c, Rect2(o, Vector2(k, k) * 4).grow(6), HomeKit.CYAN, 2.0)
	var letters := "WORDSAQEZMFKXTLH"
	for i in 16:
		HomeKit.glow_text(c, o + (Vector2(i % 4, int(i / 4)) + Vector2(0.5, 0.55)) * k, letters[i], int(k * 0.55), Color.WHITE)

func _logo_pill(c: Control, o: Vector2, k: float, a: Vector2i, b: Vector2i, col: Color) -> void:
	var pa := o + (Vector2(a) + Vector2(0.5, 0.5)) * k
	var pb := o + (Vector2(b) + Vector2(0.5, 0.5)) * k
	c.draw_line(pa, pb, Color(col, 0.22), k * 0.8)
	c.draw_circle(pa, k * 0.4, Color(col, 0.22))
	c.draw_circle(pb, k * 0.4, Color(col, 0.22))
	HomeKit.glow_line(c, pa, pb, col, 2.0)

func _new_level(i: int) -> void:
	level = i
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	if not started or win_dialog.visible or engine.grid.is_empty():
		return
	var ws: Array = []
	for w in engine.words:
		ws.append({"word": w.word, "x": w.start.x, "y": w.start.y, "dx": w.dir.x, "dy": w.dir.y, "found": w.found})
	var secs = info.get("_clock") if info else null
	SaveUtil.write(SAVE_PATH, {"level": engine.level, "theme": engine.theme, "grid": engine.grid, "words": ws,
		"secs": float(secs) if secs != null else 0.0})

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("grid"):
		_start_new_game()
		return
	level = clampi(int(d.get("level", 1)), 0, WSEngine.LEVELS.size() - 1)
	_start_new_game()  # sets up the level, clock and labels; the saved puzzle replaces it
	engine.theme = str(d.theme)
	engine.grid = []
	for ch in d.grid:
		engine.grid.append(str(ch))
	engine.words = []
	for w in d.words:
		engine.words.append({"word": str(w.word), "start": Vector2i(int(w.x), int(w.y)),
			"dir": Vector2i(int(w.dx), int(w.dy)), "found": bool(w.found)})
	if info and info.get("_clock") != null:
		info.set("_clock", float(d.get("secs", 0.0)))
	theme_label.text = tr("Theme: %s") % engine.theme
	_update_list()
	board.queue_redraw()
