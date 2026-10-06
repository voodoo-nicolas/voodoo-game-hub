extends Control

## Crossword -- tap a square to pick a word (tap again to switch between
## across and down), then type with the keyboard below.

const CWEngine = preload("res://scripts/games/crossword/crossword_engine.gd")
const HomeKit = preload("res://scripts/games/crossword/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_CELL := Color(0.05, 0.07, 0.15)
const COLOR_WORD := Color(0.08, 0.2, 0.36)
const COLOR_CURSOR := Color(0.42, 0.3, 0.06)
const COLOR_INK := Color(0.93, 0.97, 1.0)
const COLOR_WRONG := Color("ff4f6a")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const SAVE_PATH := "user://crossword_save.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
var engine: CWEngine
var board: Control
var clue_label: Label
var keyboard: VBoxContainer
var win_dialog: ColorRect
var cursor := Vector2i(-1, -1)
var across := true
var show_wrong := false
var spanish := false
var font: Font
var started := false  # a puzzle is on (not just the one behind Home)
var puzzle_seed: int = 0

func _ready() -> void:
	preload("res://scripts/games/crossword/crossword_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = CWEngine.new()
	spanish = TranslationServer.get_locale().begins_with("es")
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
	title.text = tr("📝 Crossword")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	var clue_panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.12, 0.24)
	sb.border_color = Color(HomeKit.CYAN, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	clue_panel.add_theme_stylebox_override("panel", sb)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 16)
	cm.add_theme_constant_override("margin_right", 16)
	cm.add_child(clue_panel)
	root.add_child(cm)
	clue_label = Label.new()
	clue_label.add_theme_font_size_override("font_size", 26)
	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	clue_label.custom_minimum_size = Vector2(0, 70)
	clue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clue_panel.add_child(clue_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 12)
	root.add_child(tools)
	tools.add_child(_tool_button("◀", _jump.bind(-1), 0.14))
	tools.add_child(_tool_button(tr("Check"), _on_check, 0.3))
	tools.add_child(_tool_button(tr("Reveal letter"), _on_reveal, 0.38))
	tools.add_child(_tool_button("▶", _jump.bind(1), 0.14))

	keyboard = VBoxContainer.new()
	keyboard.add_theme_constant_override("separation", 6)
	var km := MarginContainer.new()
	km.add_theme_constant_override("margin_bottom", 26)
	km.add_theme_constant_override("margin_left", 6)
	km.add_theme_constant_override("margin_right", 6)
	km.add_child(keyboard)
	root.add_child(km)
	var rows := ["QWERTYUIOP", "ASDFGHJKLÑ" if spanish else "ASDFGHJKL", "ZXCVBNM"]
	for i in rows.size():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		keyboard.add_child(row)
		for ch in rows[i]:
			row.add_child(_key(ch, ch))
		if i == 2:
			row.add_child(_key("⌫", ""))

	win_dialog = UI.build_dialog(tr("Solved!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/crossword/crossword_help.gd"))
	_build_home()
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

## `share` is the part of the screen width the button takes.
func _tool_button(text: String, action: Callable, share: float = 0.25) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(floor((get_viewport_rect().size.x - 60.0) * share), 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(action)
	return b

func _key(label: String, value: String) -> Button:
	var b := Button.new()
	b.text = label
	# ten keys across the screen, whatever its width
	var kw: float = floor((get_viewport_rect().size.x - 12.0 - 9 * 5.0) / 10.0)
	b.custom_minimum_size = Vector2(kw if value != "" else kw * 1.7, 76)
	b.add_theme_font_size_override("font_size", 28)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("sfx", "key")
	b.pressed.connect(_on_key.bind(value))
	return b

func _start_new_game(p_seed: int = -1) -> void:
	started = true
	puzzle_seed = p_seed if p_seed >= 0 else randi() % 1000000000
	engine.new_puzzle(spanish, puzzle_seed)
	if info:
		info.start_clock()
	win_dialog.visible = false
	show_wrong = false
	var first: Dictionary = engine.entries[0]
	cursor = first.pos
	across = first.across
	_refresh()

func _current_entry() -> Variant:
	var e = engine.entry_at(cursor, across)
	if e == null:
		across = not across
		e = engine.entry_at(cursor, across)
	return e

func _refresh() -> void:
	var e = _current_entry()
	if e != null:
		clue_label.text = "%d %s: %s" % [e.number, tr("Across") if e.across else tr("Down"), e.clue]
	board.queue_redraw()

# ---------- input ----------

func _on_key(value: String) -> void:
	if win_dialog.visible or cursor.x < 0:
		return
	var e = _current_entry()
	if e == null:
		return
	var d := Vector2i(1, 0) if e.across else Vector2i(0, 1)
	show_wrong = false
	if value == "":
		if engine.letters.get(cursor, "") == "" and engine.is_cell(cursor - d) and cursor != e.pos:
			cursor -= d
		engine.letters[cursor] = ""
	else:
		engine.letters[cursor] = value
		var end: Vector2i = e.pos + d * (e.answer.length() - 1)
		if cursor != end:
			cursor += d
		if engine.is_solved():
			SaveUtil.delete(SAVE_PATH)
			var secs := 0.0
			var record := false
			if info:
				info.add("Puzzles solved")
				info.celebrate("Solved!")
				secs = info.stop_clock()
				record = info.low("Best time", secs)
			win_dialog.get_meta("message_label").text = tr("Every word is right.")
			if info:
				win_dialog.get_meta("message_label").text += "\n" + tr("Time: %d:%02d") % [int(secs) / 60, int(secs) % 60]
				if record:
					win_dialog.get_meta("message_label").text += "  ·  " + tr("New best!")
			win_dialog.visible = true
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	# physical keyboard support (PC test build)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE:
			_on_key("")
		elif event.unicode > 0:
			var ch := String.chr(event.unicode).to_upper()
			if (ch >= "A" and ch <= "Z") or ch == "Ñ":
				_on_key(ch)

func _jump(delta: int) -> void:
	var e = _current_entry()
	var i: int = engine.entries.find(e)
	var n: Dictionary = engine.entries[(i + delta + engine.entries.size()) % engine.entries.size()]
	across = n.across
	cursor = n.pos
	# land on the first empty square of the word
	var d := Vector2i(1, 0) if n.across else Vector2i(0, 1)
	for k in n.answer.length():
		if engine.letters.get(n.pos + d * k, "") == "":
			cursor = n.pos + d * k
			break
	_refresh()

func _on_check() -> void:
	show_wrong = true
	board.queue_redraw()

func _on_reveal() -> void:
	if cursor.x < 0:
		return
	engine.letters[cursor] = engine.solution[cursor]
	_on_key(engine.solution[cursor])

# ---------- drawing ----------

func _geom() -> Dictionary:
	var cell: float = floor(min((board.size.x - 24.0) / engine.w, (board.size.y - 8.0) / engine.h))
	cell = min(cell, 72.0)
	return {"cell": cell, "origin": Vector2((board.size.x - cell * engine.w) / 2.0, (board.size.y - cell * engine.h) / 2.0)}

## Look (STANDARDS §9): "classic" = paper cells with ink letters (default); "voodoo" = the neon
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
	var g := _geom()
	var cell: float = g.cell
	var e = _current_entry()
	var word_cells: Array = []
	if e != null:
		var d := Vector2i(1, 0) if e.across else Vector2i(0, 1)
		for k in e.answer.length():
			word_cells.append(e.pos + d * k)
	var wrong: Array = engine.wrong_cells() if show_wrong else []
	for c in engine.solution:
		var rect := Rect2(g.origin + Vector2(c) * cell, Vector2(cell, cell))
		var col := COLOR_CELL
		if c == cursor:
			col = COLOR_CURSOR
		elif c in word_cells:
			col = COLOR_WORD
		if _is_classic():
			col = HomeKit.CLASSIC.paper
			if c == cursor:
				col = Color("ffe9a8")
			elif c in word_cells:
				col = Color("cfe0f5")
		board.draw_rect(rect, col)
		if _is_classic():
			board.draw_rect(rect, HomeKit.CLASSIC.ink, false, 1.5)
		else:
			board.draw_rect(rect, Color(HomeKit.CYAN, 0.55) if c != cursor else HomeKit.GOLD, false, 2.0)
		if engine.numbers.has(c):
			board.draw_string(font, rect.position + Vector2(3, cell * 0.28), str(engine.numbers[c]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell * 0.24), HomeKit.CLASSIC.pencil if _is_classic() else HomeKit.GOLD)
		var ch: String = engine.letters.get(c, "")
		if ch != "":
			var fs := int(cell * 0.55)
			board.draw_string(font, Vector2(rect.position.x, rect.position.y + cell * 0.6 + fs * 0.3), ch, HORIZONTAL_ALIGNMENT_CENTER, cell, fs,
				COLOR_WRONG if c in wrong else (HomeKit.CLASSIC.ink if _is_classic() else COLOR_INK))

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := _geom()
	var p: Vector2 = (event.position - g.origin) / g.cell
	var c := Vector2i(floori(p.x), floori(p.y))
	if not engine.is_cell(c):
		return
	if c == cursor:
		# switch direction if the other way has a word here
		if engine.entry_at(c, not across) != null:
			across = not across
	else:
		cursor = c
		if engine.entry_at(c, across) == null:
			across = not across
	_refresh()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/crossword/crossword_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"help": preload("res://scripts/games/crossword/crossword_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Fill the grid from the clues.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  New crossword", "sub": "About ten words", "action": _new_crossword}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": func(): return tr("%d letters in") % int((SaveUtil.read(SAVE_PATH) if SaveUtil.read(SAVE_PATH) else {}).get("letters", []).size()),
		"restart": _new_crossword,
		"board": "Puzzles solved",
		"board_note": "Crosswords solved, all time.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.6, 40.0)
	var o := Vector2(c.size.x / 2.0 - k * 2.5, c.size.y / 2.0 - k * 2.0)
	var cells := {Vector2i(0, 1): "N", Vector2i(1, 1): "E", Vector2i(2, 1): "O", Vector2i(3, 1): "N",
		Vector2i(2, 0): "V", Vector2i(2, 2): "O", Vector2i(2, 3): "D", Vector2i(4, 1): ""}
	for p in cells:
		var r := Rect2(o + Vector2(p) * k, Vector2(k, k)).grow(-1)
		c.draw_rect(r, COLOR_CELL)
		c.draw_rect(r, Color(HomeKit.CYAN, 0.8), false, 2.0)
		if cells[p] != "":
			HomeKit.glow_text(c, r.get_center(), cells[p], int(k * 0.55), Color.WHITE)
	HomeKit.glow_rect(c, Rect2(o + Vector2(4, 1) * k, Vector2(k, k)).grow(-1), HomeKit.GOLD, 2.0)

func _new_crossword() -> void:
	SaveUtil.delete(SAVE_PATH)
	_start_new_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

## A puzzle is rebuilt from its seed, so only the seed and your letters are kept.
func _save_game() -> void:
	if not started or win_dialog.visible or engine.is_solved():
		return
	var typed: Array = []
	for cell in engine.letters:
		if str(engine.letters[cell]) != "":
			typed.append([cell.x, cell.y, engine.letters[cell]])
	SaveUtil.write(SAVE_PATH, {"seed": puzzle_seed, "spanish": spanish, "letters": typed})

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_start_new_game()
		return
	spanish = bool(d.get("spanish", spanish))
	_start_new_game(int(d.get("seed", -1)))
	for t in d.get("letters", []):
		engine.letters[Vector2i(int(t[0]), int(t[1]))] = str(t[2])
	_refresh()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
