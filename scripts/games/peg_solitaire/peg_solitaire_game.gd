extends Control

## Peg Solitaire -- tap a peg, then tap the hole to jump into. Builds its whole
## UI in code; the board is one Control drawn in _draw_board().

const PegEngine = preload("res://scripts/games/peg_solitaire/peg_solitaire_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")

const COLOR_BOARD := Color(0.35, 0.22, 0.12)
const COLOR_HOLE := Color(0.18, 0.1, 0.05)
const COLOR_PEG := Color(0.95, 0.75, 0.25)
const COLOR_SELECTED := Color(0.4, 0.9, 1.0)
const COLOR_TARGET := Color(0.4, 0.9, 1.0, 0.45)

var engine: PegEngine
var board: Control
var status_label: Label
var end_dialog: ColorRect
var selected := Vector2i(-1, -1)

func _ready() -> void:
	preload("res://scripts/games/peg_solitaire/peg_solitaire_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = PegEngine.new()
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
	root.add_theme_constant_override("separation", 14)
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
	title.text = tr("📌 Peg Solitaire")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start_new_game)
	bar.add_child(restart_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var hint := Label.new()
	hint.text = tr("Jump a peg over another into an empty hole. Leave just one!")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(hint)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 40)
	bm.add_child(bottom)
	root.add_child(bm)
	var undo_btn := Button.new()
	undo_btn.text = tr("↶ Undo")
	undo_btn.custom_minimum_size = Vector2(240, 70)
	undo_btn.add_theme_font_size_override("font_size", 28)
	undo_btn.pressed.connect(_on_undo)
	bottom.add_child(undo_btn)

	end_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("↶ Undo"), "action": _on_undo},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	add_child(SettingsDrawer.new())

func _start_new_game() -> void:
	engine.reset()
	selected = Vector2i(-1, -1)
	end_dialog.visible = false
	_refresh()

func _on_undo() -> void:
	engine.undo()
	selected = Vector2i(-1, -1)
	_refresh()

func _refresh() -> void:
	status_label.text = tr("Pegs left: %d") % engine.peg_count()
	board.queue_redraw()

# ---------- board geometry ----------

func _cell_size() -> float:
	return floor(min(board.size.x - 32.0, board.size.y - 16.0) / PegEngine.SIZE)

func _origin() -> Vector2:
	var s := _cell_size() * PegEngine.SIZE
	return Vector2((board.size.x - s) / 2.0, (board.size.y - s) / 2.0)

func _draw_board() -> void:
	var cs := _cell_size()
	var o := _origin()
	var full := cs * PegEngine.SIZE
	# the cross-shaped wooden board
	board.draw_rect(Rect2(o + Vector2(cs * 2, 0), Vector2(cs * 3, full)), COLOR_BOARD)
	board.draw_rect(Rect2(o + Vector2(0, cs * 2), Vector2(full, cs * 3)), COLOR_BOARD)
	var targets: Array = engine.targets_from(selected.y, selected.x) if selected.x >= 0 else []
	for r in PegEngine.SIZE:
		for c in PegEngine.SIZE:
			if not PegEngine.is_hole(r, c):
				continue
			var center := o + Vector2(c + 0.5, r + 0.5) * cs
			board.draw_circle(center, cs * 0.22, COLOR_HOLE)
			if engine.at(r, c) == PegEngine.PEG:
				var col := COLOR_SELECTED if Vector2i(c, r) == selected else COLOR_PEG
				board.draw_circle(center, cs * 0.36, col)
				board.draw_circle(center - Vector2(cs * 0.1, cs * 0.1), cs * 0.1, Color(1, 1, 1, 0.35))
			elif Vector2i(c, r) in targets:
				board.draw_circle(center, cs * 0.3, COLOR_TARGET)

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if end_dialog.visible:
		return
	var cs := _cell_size()
	var p: Vector2 = (event.position - _origin()) / cs
	var cell := Vector2i(floori(p.x), floori(p.y))
	if not PegEngine.is_hole(cell.y, cell.x):
		selected = Vector2i(-1, -1)
		board.queue_redraw()
		return
	if engine.at(cell.y, cell.x) == PegEngine.PEG:
		selected = Vector2i(-1, -1) if cell == selected else cell
	elif selected.x >= 0 and engine.try_move(selected.y, selected.x, cell.y, cell.x):
		# keep chaining from the landing hole when another jump is possible
		selected = cell if not engine.targets_from(cell.y, cell.x).is_empty() else Vector2i(-1, -1)
		_refresh()
		_check_end()
		return
	board.queue_redraw()

func _check_end() -> void:
	if engine.has_moves():
		return
	var left: int = engine.peg_count()
	var msg: String
	if left == 1 and engine.at(3, 3) == PegEngine.PEG:
		msg = tr("Perfect! One peg, dead centre.")
	elif left == 1:
		msg = tr("Solved! Just one peg left.")
	else:
		msg = tr("No more jumps. %d pegs left.") % left
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
