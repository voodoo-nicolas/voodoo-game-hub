extends Control

## Word Hunt -- drag across touching letters to spell a word, lift to submit.
## Three minutes per board. English words only (the word list is English).

const WHEngine = preload("res://scripts/games/word_hunt/word_hunt_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const ROUND_SECONDS := 180.0
const BEST_PATH := "user://word_hunt_best.json"
const COLOR_TILE := Color(0.96, 0.9, 0.75)
const COLOR_TILE_ON := Color(1.0, 0.75, 0.3)
const COLOR_INK := Color(0.15, 0.1, 0.05)

var info = null  # GameInfo; null on apps without it, so guard every use
var engine: WHEngine
var board: Control
var word_label: Label
var info_label: Label
var found_label: Label
var clock: Timer
var start_dialog: ColorRect
var end_dialog: ColorRect
var pause_dialog: ColorRect
var path: Array = []
var dragging := false
var time_left: float = ROUND_SECONDS
var running := false
var best: int = 0
var font: Font

func _ready() -> void:
	preload("res://scripts/games/word_hunt/word_hunt_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = WHEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	engine.load_words()
	_show_start()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var hub_btn := Button.new()
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🎲 Word Hunt")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_show_start)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 26)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	word_label = Label.new()
	word_label.add_theme_font_size_override("font_size", 40)
	word_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.custom_minimum_size = Vector2(0, 56)
	root.add_child(word_label)

	board = Control.new()
	board.custom_minimum_size = Vector2(0, 560)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 24)
	sm.add_theme_constant_override("margin_right", 24)
	sm.add_theme_constant_override("margin_bottom", 24)
	sm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sm)
	found_label = Label.new()
	found_label.add_theme_font_size_override("font_size", 24)
	found_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	found_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	found_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sm.add_child(found_label)
	root.add_child(scroll)

	clock = Timer.new()
	clock.wait_time = 0.25
	clock.timeout.connect(_on_tick)
	add_child(clock)

	start_dialog = UI.build_dialog(tr("🎲 Word Hunt"), [
		{"text": tr("Start"), "action": _start_round},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(start_dialog)
	end_dialog = UI.build_dialog(tr("Time's up!"), [
		{"text": tr("Play Again"), "action": _show_start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("Exit to Hub"), "action": UI.exit_to_hub.bind(self)},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/word_hunt/word_hunt_help.gd"))
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	add_child(SettingsDrawer.new())

func _show_start() -> void:
	running = false
	clock.stop()
	end_dialog.visible = false
	engine.new_board()
	path = []
	var msg := tr("Drag across touching letters to make words of 3+ letters. You have 3 minutes.")
	if TranslationServer.get_locale().begins_with("es"):
		msg += "\n" + tr("Words are in English.")
	start_dialog.get_meta("message_label").text = msg
	start_dialog.visible = true
	word_label.text = ""
	found_label.text = ""
	_update_info()
	board.queue_redraw()

func _start_round() -> void:
	time_left = ROUND_SECONDS
	running = true
	clock.start()
	_update_info()

func _resume() -> void:
	running = true
	clock.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running:
			running = false
			clock.stop()
			pause_dialog.visible = true

func _on_tick() -> void:
	if not running:
		return
	time_left -= clock.wait_time
	if time_left <= 0.0:
		time_left = 0.0
		_end_round()
	_update_info()

func _update_info() -> void:
	var t := int(ceil(time_left))
	info_label.text = tr("⏱ %d:%02d   Score: %d   Best: %d") % [t / 60, t % 60, engine.score, best]

func _end_round() -> void:
	running = false
	clock.stop()
	dragging = false
	path = []
	if engine.score > best:
		best = engine.score
		SaveUtil.write(BEST_PATH, {"best": best})
	if info:
		info.add("Rounds played")
		info.best("Best score", best)
		info.high("Most words found", engine.found.size())
	var all := engine.all_words()
	var missed: Array = all.filter(func(w): return not engine.found.has(w))
	var msg := tr("Score: %d — %d of %d words found.") % [engine.score, engine.found.size(), all.size()]
	if not missed.is_empty():
		msg += "\n" + tr("Longest you missed:") + " " + ", ".join(PackedStringArray(missed.slice(0, 4))).to_upper()
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	board.queue_redraw()

# ---------- board ----------

func _geom() -> Dictionary:
	var side: float = min(board.size.x - 60.0, board.size.y - 10.0)
	var cell := side / WHEngine.SIZE
	return {"cell": cell, "origin": Vector2((board.size.x - side) / 2.0, (board.size.y - side) / 2.0)}

func _draw_board() -> void:
	if engine.grid.is_empty():
		return
	var g := _geom()
	var cell: float = g.cell
	for i in 16:
		var r := i / 4
		var c := i % 4
		var rect := Rect2(g.origin + Vector2(c, r) * cell, Vector2(cell, cell)).grow(-6)
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLOR_TILE_ON if i in path else COLOR_TILE
		sb.set_corner_radius_all(14)
		board.draw_style_box(sb, rect)
		var txt: String = engine.grid[i] if engine.grid[i] != "QU" else "Qu"
		var fs := int(cell * (0.42 if txt.length() == 1 else 0.34))
		board.draw_string(font, Vector2(rect.position.x, rect.get_center().y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, COLOR_INK)
	for k in range(1, path.size()):
		var a: Vector2 = g.origin + (Vector2(path[k - 1] % 4, path[k - 1] / 4) + Vector2(0.5, 0.5)) * cell
		var b: Vector2 = g.origin + (Vector2(path[k] % 4, path[k] / 4) + Vector2(0.5, 0.5)) * cell
		board.draw_line(a, b, Color(0.9, 0.3, 0.1, 0.6), 10)

func _cell_at(pos: Vector2, strict: bool) -> int:
	var g := _geom()
	var p: Vector2 = (pos - g.origin) / g.cell
	var c := floori(p.x)
	var r := floori(p.y)
	if r < 0 or c < 0 or r > 3 or c > 3:
		return -1
	# while dragging, only react near a tile's centre so diagonals are easy
	if strict and Vector2(p.x - c - 0.5, p.y - r - 0.5).length() > 0.38:
		return -1
	return r * 4 + c

func _on_board_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var i := _cell_at(event.position, false)
			if i >= 0:
				dragging = true
				path = [i]
				_show_word()
		elif dragging:
			dragging = false
			_submit()
	elif event is InputEventMouseMotion and dragging:
		var i := _cell_at(event.position, true)
		if i < 0:
			return
		if path.size() >= 2 and i == path[path.size() - 2]:
			path.pop_back()   # sliding back undoes the last letter
		elif not path.has(i) and WHEngine.adjacent(path.back(), i):
			path.append(i)
		_show_word()

func _show_word() -> void:
	word_label.remove_theme_color_override("font_color")
	word_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	word_label.text = engine.path_word(path).to_upper()
	board.queue_redraw()

func _submit() -> void:
	var w := engine.path_word(path).to_upper()
	var res := engine.submit(path)
	path = []
	var col := Color(0.5, 0.95, 0.5)
	match res:
		"ok":
			word_label.text = "%s  +%d" % [w, WHEngine.points(w.to_lower())]
			var shown: Array = engine.found.duplicate()
			shown.reverse()
			found_label.text = tr("Found:") + " " + ", ".join(PackedStringArray(shown)).to_upper()
		"repeat":
			word_label.text = tr("%s — already found") % w
			col = Color(0.9, 0.8, 0.4)
		"unknown":
			word_label.text = tr("%s — not a word") % w
			col = Color(1, 0.45, 0.45)
		_:
			word_label.text = ""
	word_label.add_theme_color_override("font_color", col)
	_update_info()
	board.queue_redraw()
