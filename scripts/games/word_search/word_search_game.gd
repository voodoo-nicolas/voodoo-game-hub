extends Control

## Word Search -- drag from the first letter of a word to its last.

const WSEngine = preload("res://scripts/games/word_search/word_search_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")

const HIGHLIGHTS := [Color(1, 0.4, 0.4, 0.45), Color(0.4, 0.8, 1, 0.45), Color(0.5, 1, 0.5, 0.45),
	Color(1, 0.85, 0.3, 0.45), Color(0.85, 0.5, 1, 0.45), Color(1, 0.6, 0.2, 0.45), Color(0.3, 1, 0.85, 0.45),
	Color(1, 0.5, 0.8, 0.45)]

var engine: WSEngine
var board: Control
var theme_label: Label
var list_label: RichTextLabel
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

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	hub_btn.text = tr("Hub")
	hub_btn.add_theme_font_size_override("font_size", 26)
	hub_btn.pressed.connect(UI.exit_to_hub.bind(self))
	bar.add_child(hub_btn)
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
	theme_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(theme_label)

	board = Control.new()
	board.custom_minimum_size = Vector2(0, 660)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 30)
	lm.add_theme_constant_override("margin_right", 30)
	lm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(lm)
	list_label = RichTextLabel.new()
	list_label.bbcode_enabled = true
	list_label.fit_content = true
	list_label.scroll_active = false
	list_label.add_theme_font_size_override("normal_font_size", 28)
	list_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lm.add_child(list_label)

	win_dialog = UI.build_dialog(tr("All found!"), [
		{"text": tr("Next Puzzle"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(win_dialog)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	engine.new_puzzle(TranslationServer.get_locale().begins_with("es"))
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

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side: float = min(board.size.x - 32.0, board.size.y - 8.0)
	var cell: float = side / WSEngine.SIZE
	return {"cell": cell, "origin": Vector2((board.size.x - side) / 2.0, (board.size.y - side) / 2.0)}

func _center_of(g: Dictionary, c: Vector2i) -> Vector2:
	return g.origin + (Vector2(c) + Vector2(0.5, 0.5)) * g.cell

func _draw_board() -> void:
	if engine.grid.is_empty():
		return
	var g := _geom()
	var cell: float = g.cell
	board.draw_rect(Rect2(g.origin, Vector2(cell, cell) * WSEngine.SIZE), Color(0.95, 0.93, 0.87))
	for i in engine.words.size():
		var w: Dictionary = engine.words[i]
		if w.found:
			var e: Vector2i = w.start + w.dir * (w.word.length() - 1)
			board.draw_line(_center_of(g, w.start), _center_of(g, e), HIGHLIGHTS[i % HIGHLIGHTS.size()], cell * 0.75)
	if drag_start.x >= 0 and drag_end.x >= 0:
		var cells := WSEngine.line(drag_start, drag_end)
		if not cells.is_empty():
			board.draw_line(_center_of(g, drag_start), _center_of(g, drag_end), Color(0.3, 0.5, 1, 0.4), cell * 0.75)
	var fs := int(cell * 0.55)
	for i in WSEngine.SIZE * WSEngine.SIZE:
		var p := Vector2i(i % WSEngine.SIZE, i / WSEngine.SIZE)
		var c := _center_of(g, p)
		board.draw_string(font, Vector2(c.x - cell / 2.0, c.y + fs * 0.36), engine.grid[i], HORIZONTAL_ALIGNMENT_CENTER, cell, fs, Color(0.12, 0.12, 0.16))

func _cell_at(pos: Vector2) -> Vector2i:
	var g := _geom()
	var p: Vector2 = (pos - g.origin) / g.cell
	var c := Vector2i(clampi(floori(p.x), 0, WSEngine.SIZE - 1), clampi(floori(p.y), 0, WSEngine.SIZE - 1))
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
					win_dialog.get_meta("message_label").text = tr("You found all %d words.") % engine.words.size()
					win_dialog.visible = true
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
