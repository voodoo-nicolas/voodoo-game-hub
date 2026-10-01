extends Control

## FreeCell -- tap a card (or a free-cell card) to send it to the best spot:
## foundation first, then another column, then a free cell. Cards that are
## no longer needed fly to the foundations by themselves.

const FCEngine = preload("res://scripts/games/freecell/freecell_engine.gd")
const Cards = preload("res://scripts/games/freecell/freecell_cards.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const COLOR_FELT := Color(0.05, 0.3, 0.17)

var result_recorded := false  # this deal's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var engine: FCEngine
var board: Control
var info_label: Label
var win_dialog: ColorRect
var flash_timer: Timer
var flash := Vector2i(-2, -2)   # (column or -1 for cell, index)

func _ready() -> void:
	preload("res://scripts/games/freecell/freecell_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = FCEngine.new()
	_build_ui()
	_start_new_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_FELT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
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
	title.text = tr("🆓 FreeCell")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var new_btn := Button.new()
	new_btn.text = tr("New")
	new_btn.add_theme_font_size_override("font_size", 26)
	new_btn.pressed.connect(_start_new_game)
	bar.add_child(new_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_child(controls)
	root.add_child(cm)
	var undo_btn := Button.new()
	undo_btn.text = tr("↶ Undo")
	undo_btn.custom_minimum_size = Vector2(220, 68)
	undo_btn.add_theme_font_size_override("font_size", 26)
	undo_btn.pressed.connect(_on_undo)
	controls.add_child(undo_btn)

	flash_timer = Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.25
	flash_timer.timeout.connect(_clear_flash)
	add_child(flash_timer)

	win_dialog = UI.build_dialog(tr("You Win!"), [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(win_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/freecell/freecell_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	result_recorded = false
	if info:
		info.start_clock()
	engine.new_game()
	engine.auto_foundation()
	win_dialog.visible = false
	_refresh()

func _on_undo() -> void:
	engine.undo()
	_refresh()

func _refresh() -> void:
	info_label.text = tr("Moves: %d   Free cells: %d") % [engine.moves, engine.free_cells()]
	board.queue_redraw()

func _clear_flash() -> void:
	flash = Vector2i(-2, -2)
	board.queue_redraw()

# ---------- geometry ----------

func _card_size() -> Vector2:
	var w: float = floor((board.size.x - 16.0) / 8.0) - 6.0
	return Vector2(w, floor(w * 1.4))

func _col_x(c: int) -> float:
	var cw: float = _card_size().x + 6.0
	return (board.size.x - cw * 8.0) / 2.0 + c * cw + 3.0

func _tableau_top() -> float:
	return _card_size().y + 30.0

func _gap(c: int) -> float:
	var cs := _card_size()
	var n: int = engine.cols[c].size()
	var avail: float = board.size.y - _tableau_top() - cs.y - 8.0
	return min(cs.y * 0.32, avail / max(1, n - 1))

func _draw_board() -> void:
	if engine.cols.is_empty():
		return
	var cs := _card_size()
	for i in 4:
		var rect := Rect2(Vector2(_col_x(i), 8), cs)
		Cards.draw_card(board, rect, engine.cells[i], true, flash == Vector2i(-1, i))
		var f: int = engine.found[i]
		var frect := Rect2(Vector2(_col_x(4 + i), 8), cs)
		if f == 0:
			Cards.draw_card(board, frect, -1)
			board.draw_string(ThemeDB.fallback_font, frect.position + Vector2(0, cs.y * 0.62), Cards.SUITS[i],
				HORIZONTAL_ALIGNMENT_CENTER, cs.x, int(cs.x * 0.45), Color(1, 1, 1, 0.3))
		else:
			Cards.draw_card(board, frect, i * 13 + f - 1)
	for c in 8:
		var col: Array = engine.cols[c]
		var x := _col_x(c)
		if col.is_empty():
			Cards.draw_card(board, Rect2(Vector2(x, _tableau_top()), cs), -1)
			continue
		var g := _gap(c)
		for k in col.size():
			Cards.draw_card(board, Rect2(Vector2(x, _tableau_top() + k * g), cs), col[k], true, flash == Vector2i(c, k))

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if win_dialog.visible:
		return
	var cs := _card_size()
	var pos: Vector2 = event.position
	var c := clampi(int((pos.x - _col_x(0)) / (cs.x + 6.0)), 0, 7)
	if pos.y < _tableau_top() - 10.0:
		if c < 4 and engine.cells[c] != -1:
			if engine.auto_move(-1, 0, c):
				_after_change()
			else:
				_flash(Vector2i(-1, c))
		return
	var col: Array = engine.cols[c]
	if col.is_empty():
		return
	var g := _gap(c)
	var k := clampi(int((pos.y - _tableau_top()) / g), 0, col.size() - 1)
	if pos.y > _tableau_top() + (col.size() - 1) * g + cs.y:
		return
	var start := engine.run_start(c)
	if k < start:
		_flash(Vector2i(c, k))
		return
	if engine.auto_move(c, k):
		_after_change()
	else:
		_flash(Vector2i(c, k))

func _flash(v: Vector2i) -> void:
	flash = v
	flash_timer.start()
	board.queue_redraw()

func _after_change() -> void:
	_refresh()
	if engine.is_won():
		win_dialog.get_meta("message_label").text = tr("Solved in %d moves!") % engine.moves
		if info and not result_recorded:
			result_recorded = true
			info.add("Games won")
			info.celebrate("You win!")
			var secs: float = info.stop_clock()
			var fast: bool = info.low("Best time", secs)
			var few: bool = info.low("Fewest moves", engine.moves)
			win_dialog.get_meta("message_label").text += "\n" + tr("Time: %d:%02d") % [int(secs) / 60, int(secs) % 60]
			if fast or few:
				win_dialog.get_meta("message_label").text += "  ·  " + tr("New best!")
		win_dialog.visible = true
