extends Control

## Crossword -- tap a square to pick a word (tap again to switch between
## across and down), then type with the keyboard below.

const CWEngine = preload("res://scripts/games/crossword/crossword_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_CELL := Color(0.97, 0.97, 0.94)
const COLOR_WORD := Color(0.8, 0.9, 1.0)
const COLOR_CURSOR := Color(1.0, 0.85, 0.35)
const COLOR_INK := Color(0.1, 0.1, 0.14)
const COLOR_WRONG := Color(0.85, 0.15, 0.15)

var info = null  # GameInfo; null on apps without it, so guard every use
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

func _ready() -> void:
	preload("res://scripts/games/crossword/crossword_i18n.gd").install(self)
	Orientation.lock_portrait()
	font = ThemeDB.fallback_font
	engine = CWEngine.new()
	spanish = TranslationServer.get_locale().begins_with("es")
	_build_ui()
	_start_new_game()

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
	sb.bg_color = Color(0.16, 0.2, 0.3)
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
	tools.add_child(_tool_button(tr("◀ Prev"), _jump.bind(-1)))
	tools.add_child(_tool_button(tr("Check"), _on_check))
	tools.add_child(_tool_button(tr("Reveal letter"), _on_reveal))
	tools.add_child(_tool_button(tr("Next ▶"), _jump.bind(1)))

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
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/crossword/crossword_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _tool_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 58)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	return b

func _key(label: String, value: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(64 if value != "" else 110, 76)
	b.add_theme_font_size_override("font_size", 28)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_key.bind(value))
	return b

func _start_new_game() -> void:
	engine.new_puzzle(spanish)
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
		board.draw_rect(rect, col)
		board.draw_rect(rect, Color(0.3, 0.3, 0.35), false, 2.0)
		if engine.numbers.has(c):
			board.draw_string(font, rect.position + Vector2(3, cell * 0.28), str(engine.numbers[c]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell * 0.24), COLOR_INK)
		var ch: String = engine.letters.get(c, "")
		if ch != "":
			var fs := int(cell * 0.55)
			board.draw_string(font, Vector2(rect.position.x, rect.position.y + cell * 0.6 + fs * 0.3), ch, HORIZONTAL_ALIGNMENT_CENTER, cell, fs,
				COLOR_WRONG if c in wrong else COLOR_INK)

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
