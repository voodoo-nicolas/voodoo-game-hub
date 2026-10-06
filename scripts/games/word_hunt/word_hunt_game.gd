extends Control

## Word Hunt -- drag across touching letters to spell a word, lift to submit.
## Three minutes per board. English words only (the word list is English).

const WHEngine = preload("res://scripts/games/word_hunt/word_hunt_engine.gd")
const HomeKit = preload("res://scripts/games/word_hunt/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const ROUND_SECONDS := 180.0
const BEST_PATH := "user://word_hunt_best.json"
const COLOR_TILE := Color("3a8cff")
const COLOR_TILE_ON := Color("ffae2b")
const COLOR_TILE_SHOWN := Color("29e6ff")
const COLOR_INK := Color.WHITE

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: WHEngine
var board: Control
var word_label: Label
var info_label: Label
var found_label: Label
var tally_grid: GridContainer
## Word length -> how many words of that length are on this board.
## The last bucket (TALLY_MAX) also counts every longer word.
var totals: Dictionary = {}
const TALLY_MIN := 3
const TALLY_MAX := 8
var clock: Timer
var start_dialog: ColorRect
var end_dialog: ColorRect
var pause_dialog: ColorRect
var path: Array = []
## After a round: the missed word being shown on the board, and its tiles.
var shown_word := ""
var shown_path: Array = []
var missed_box: HFlowContainer
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
	start_dialog.visible = false  # the Home screen replaces it

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
	var hub_btn := Button.new()
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🎲 Word Hunt")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
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

	# How many words of each length this board holds, and how many are found.
	var tally_margin := MarginContainer.new()
	tally_margin.add_theme_constant_override("margin_left", 24)
	tally_margin.add_theme_constant_override("margin_right", 24)
	root.add_child(tally_margin)
	tally_grid = GridContainer.new()
	tally_grid.columns = 3
	tally_grid.add_theme_constant_override("h_separation", 18)
	tally_grid.add_theme_constant_override("v_separation", 2)
	tally_margin.add_child(tally_grid)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 24)
	sm.add_theme_constant_override("margin_right", 24)
	sm.add_theme_constant_override("margin_bottom", 24)
	sm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sm)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	sm.add_child(list)
	found_label = Label.new()
	found_label.add_theme_font_size_override("font_size", 24)
	found_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	found_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	found_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(found_label)
	# After a round: every missed word as a button that shows its path.
	missed_box = HFlowContainer.new()
	missed_box.add_theme_constant_override("h_separation", 8)
	missed_box.add_theme_constant_override("v_separation", 8)
	list.add_child(missed_box)
	root.add_child(scroll)

	clock = Timer.new()
	clock.wait_time = 0.25
	clock.timeout.connect(_on_tick)
	add_child(clock)

	start_dialog = UI.build_dialog(tr("🎲 Word Hunt"), [
		{"text": tr("Start"), "action": _start_round},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(start_dialog)
	end_dialog = UI.build_dialog(tr("Time's up!"), [
		{"text": tr("Show missed words"), "action": _show_missed},
		{"text": tr("Play Again"), "action": _show_start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/word_hunt/word_hunt_help.gd"))
	_build_home()
	if info:
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
	_clear_missed()
	var msg := tr("Drag across touching letters to make words of 3+ letters. You have 3 minutes.")
	if TranslationServer.get_locale().begins_with("es"):
		msg += "\n" + tr("Words are in English.")
	start_dialog.get_meta("message_label").text = msg
	start_dialog.visible = true
	word_label.text = ""
	found_label.text = ""
	totals.clear()
	for w in engine.all_words():
		var n: int = _bucket(w)
		totals[n] = int(totals.get(n, 0)) + 1
	_update_tally()
	_update_info()
	board.queue_redraw()

static func _bucket(w: String) -> int:
	return mini(w.length(), TALLY_MAX)

## "3 letters  2/12" per length, green once a length is complete.
func _update_tally() -> void:
	for c in tally_grid.get_children():
		c.queue_free()
	var got := {}
	for w in engine.found:
		var n: int = _bucket(w)
		got[n] = int(got.get(n, 0)) + 1
	var longest := TALLY_MIN + 3
	for n in totals:
		longest = maxi(longest, n)
	for n in range(TALLY_MIN, longest + 1):
		var total: int = int(totals.get(n, 0))
		var have: int = int(got.get(n, 0))
		var l := Label.new()
		var len_text: String = (tr("%d+ letters") if n == TALLY_MAX else tr("%d letters")) % n
		l.text = "%s  %d/%d" % [len_text, have, total]
		l.add_theme_font_size_override("font_size", 24)
		var col := Color(0.7, 0.72, 0.8)
		if total > 0 and have == total:
			col = Color(0.45, 0.95, 0.5)
		elif have > 0:
			col = Color(1, 0.85, 0.4)
		l.add_theme_color_override("font_color", col)
		tally_grid.add_child(l)

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
		if is_node_ready() and running and home:
			home.pause()

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

# ---------- missed words ----------

func _clear_missed() -> void:
	shown_word = ""
	shown_path = []
	for c in missed_box.get_children():
		c.queue_free()

## Lists every missed word (longest first) under the board; tapping one
## lights up its tiles in order, so the player can see how it was made.
func _show_missed() -> void:
	_clear_missed()
	var missed: Array = engine.all_words().filter(func(w): return not engine.found.has(w))
	var head := Label.new()
	head.text = tr("Words you missed (tap one to see it):")
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	head.custom_minimum_size = Vector2(board.size.x - 60.0, 0)
	missed_box.add_child(head)
	for w in missed:
		var b := Button.new()
		b.text = w.to_upper()
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(_show_path.bind(w))
		missed_box.add_child(b)
	if not missed.is_empty():
		_show_path(missed[0])

func _show_path(w: String) -> void:
	shown_word = w
	shown_path = engine.find_path(w)
	word_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	word_label.text = "%s  +%d" % [w.to_upper(), WHEngine.points(w)]
	board.queue_redraw()

# ---------- board ----------

func _geom() -> Dictionary:
	var side: float = min(board.size.x - 60.0, board.size.y - 10.0)
	var cell := side / WHEngine.SIZE
	return {"cell": cell, "origin": Vector2((board.size.x - side) / 2.0, (board.size.y - side) / 2.0)}

## Look (STANDARDS §9): "classic" = cream letter tiles (default); "voodoo" = the neon
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
	for i in 16:
		var r := i / 4
		var c := i % 4
		var rect := Rect2(g.origin + Vector2(c, r) * cell, Vector2(cell, cell)).grow(-6)
		var rim: Color = COLOR_TILE_ON if i in path else COLOR_TILE
		if i in shown_path:
			rim = COLOR_TILE_SHOWN
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(rim, 0.3 if rim != COLOR_TILE else 0.1)
		sb.border_color = rim
		sb.set_border_width_all(3)
		sb.shadow_color = Color(rim, 0.35)
		sb.shadow_size = 7
		sb.set_corner_radius_all(14)
		var ink: Color = COLOR_INK
		if _is_classic():
			sb.bg_color = Color("ffe9a8") if i in path else (Color("cfe0f5") if i in shown_path else Color("f4efe4"))
			sb.border_color = HomeKit.CLASSIC.yellow.darkened(0.2) if i in path else Color("8a8473")
			sb.set_border_width_all(3)
			sb.shadow_color = Color(0, 0, 0, 0.3)
			sb.shadow_size = 3
			sb.shadow_offset = Vector2(1, 2)
			ink = HomeKit.CLASSIC.ink
		board.draw_style_box(sb, rect)
		var txt: String = engine.grid[i] if engine.grid[i] != "QU" else "Qu"
		var fs := int(cell * (0.42 if txt.length() == 1 else 0.34))
		board.draw_string(font, Vector2(rect.position.x, rect.get_center().y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, ink)
	_draw_path(path, Color(0.9, 0.3, 0.1, 0.6), g)
	_draw_path(shown_path, Color(0.1, 0.45, 0.85, 0.7), g)
	# Number the shown word's tiles so the order is clear.
	for k in shown_path.size():
		var i: int = shown_path[k]
		var corner: Vector2 = g.origin + Vector2(i % 4, i / 4) * cell + Vector2(14, 12)
		var nfs := int(cell * 0.18)
		board.draw_circle(corner + Vector2(nfs * 0.6, nfs * 0.6), nfs * 0.75, Color(0.1, 0.45, 0.85))
		board.draw_string(font, corner + Vector2(0, nfs * 0.95), str(k + 1), HORIZONTAL_ALIGNMENT_CENTER, nfs * 1.2, nfs, Color.WHITE)

func _cell_center(i: int, g: Dictionary) -> Vector2:
	return g.origin + (Vector2(i % 4, i / 4) + Vector2(0.5, 0.5)) * float(g.cell)

func _draw_path(p: Array, col: Color, g: Dictionary) -> void:
	for k in range(1, p.size()):
		board.draw_line(_cell_center(p[k - 1], g), _cell_center(p[k], g), col, 10)

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
	_sfx("letter_right" if res == "ok" else "letter_wrong")
	path = []
	var col := Color(0.5, 0.95, 0.5)
	match res:
		"ok":
			word_label.text = "%s  +%d" % [w, WHEngine.points(w.to_lower())]
			var shown: Array = engine.found.duplicate()
			shown.reverse()
			found_label.text = tr("Found:") + " " + ", ".join(PackedStringArray(shown)).to_upper()
			_update_tally()
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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/word_hunt/word_hunt_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/word_hunt/word_hunt_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Drag across touching letters to make words. Three minutes!",
		"logo": _draw_home_logo,
		"modes": [{"text": "🔎  Play", "sub": "3-minute round (English words)", "action": _play_round}],
		"restart": _play_round,
		"board_note": "Your best score in one round.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.3, 52.0)
	var o := Vector2(c.size.x / 2.0 - k * 1.5, c.size.y / 2.0 - k * 1.5)
	var letters := ["W", "O", "R", "N", "E", "D", "S", "T", "H"]
	var path := [0, 1, 2, 5]
	for i in 9:
		var r := Rect2(o + Vector2(i % 3, int(i / 3)) * k, Vector2(k, k)).grow(-4)
		HomeKit.glow_rect(c, r, COLOR_TILE_ON if i in path else HomeKit.BLUE, 2.0, 0.2 if i in path else 0.06)
		HomeKit.glow_text(c, r.get_center(), letters[i], int(k * 0.5), Color.WHITE)
	var pts := PackedVector2Array()
	for i in path:
		pts.append(o + Vector2(i % 3 + 0.5, int(i / 3) + 0.5) * k)
	HomeKit.glow_polyline(c, pts, Color(COLOR_TILE_ON, 0.7), 2.0)

func _play_round() -> void:
	_show_start()
	start_dialog.visible = false
	_start_round()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
