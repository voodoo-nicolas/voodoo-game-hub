extends Control

## Gem Match -- swipe a gem onto its neighbour (or tap one, then the other)
## to swap them. Make lines of 3+.

const GMEngine = preload("res://scripts/games/gem_match/gem_match_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")

const BEST_PATH := "user://gem_match_best.json"
const GEM_COLORS := [Color(0.95, 0.3, 0.35), Color(0.3, 0.65, 1), Color(0.35, 0.9, 0.45), Color(1, 0.85, 0.25),
	Color(0.75, 0.45, 1), Color(1, 0.55, 0.2)]

var engine: GMEngine
var board: Control
var info_label: Label
var over_dialog: ColorRect
var step_timer: Timer
var selected: int = -1
var flashing: Array = []
var busy := false
var best: int = 0
var hint_pair: Array = []
var press_cell: int = -1
var press_pos := Vector2.ZERO

func _ready() -> void:
	preload("res://scripts/games/gem_match/gem_match_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = GMEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	_start()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.13)
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
	title.text = tr("💎 Gem Match")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 28)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

	board = Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	root.add_child(board)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 36)
	rm.add_child(row)
	root.add_child(rm)
	var hint_btn := Button.new()
	hint_btn.text = tr("💡 Hint")
	hint_btn.custom_minimum_size = Vector2(220, 70)
	hint_btn.add_theme_font_size_override("font_size", 26)
	hint_btn.pressed.connect(_on_hint)
	row.add_child(hint_btn)

	step_timer = Timer.new()
	step_timer.one_shot = true
	step_timer.timeout.connect(_resolve_step)
	add_child(step_timer)

	over_dialog = UI.build_dialog(tr("Out of Moves"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(over_dialog)
	add_child(SettingsDrawer.new())

func _start() -> void:
	step_timer.stop()
	engine.reset()
	selected = -1
	flashing = []
	busy = false
	hint_pair = []
	over_dialog.visible = false
	_update_info()
	board.queue_redraw()

func _update_info() -> void:
	info_label.text = tr("Score: %d   Moves: %d   Best: %d") % [engine.score, engine.moves_left, best]

# ---------- resolving matches ----------

func _attempt(a: int, b: int) -> void:
	selected = -1
	hint_pair = []
	if engine.try_swap(a, b):
		busy = true
		_update_info()
		_resolve_step()
	board.queue_redraw()

## Alternates: flash the matches -> clear & drop -> look again.
func _resolve_step() -> void:
	if flashing.is_empty():
		flashing = engine.find_matches()
		if flashing.is_empty():
			_settled()
			return
		step_timer.wait_time = 0.22
		step_timer.start()
	else:
		engine.clear_matches()
		engine.collapse()
		flashing = []
		_update_info()
		step_timer.wait_time = 0.18
		step_timer.start()
	board.queue_redraw()

func _settled() -> void:
	busy = false
	if not engine.has_moves():
		engine.reshuffle()
	if engine.moves_left <= 0:
		if engine.score > best:
			best = engine.score
			SaveUtil.write(BEST_PATH, {"best": best})
		over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
		over_dialog.visible = true
	_update_info()
	board.queue_redraw()

func _on_hint() -> void:
	if not busy:
		hint_pair = engine.hint()
		board.queue_redraw()

# ---------- drawing & input ----------

func _cell() -> float:
	return floor(min(board.size.x - 24.0, board.size.y - 8.0) / GMEngine.SIZE)

func _origin() -> Vector2:
	var c := _cell() * GMEngine.SIZE
	return Vector2((board.size.x - c) / 2.0, (board.size.y - c) / 2.0)

func _draw_board() -> void:
	if engine.grid.is_empty():
		return
	var cs := _cell()
	var o := _origin()
	for i in GMEngine.SIZE * GMEngine.SIZE:
		var p := o + Vector2(i % GMEngine.SIZE, i / GMEngine.SIZE) * cs
		board.draw_rect(Rect2(p, Vector2(cs, cs)), Color(1, 1, 1, 0.04 if (i + i / GMEngine.SIZE) % 2 == 0 else 0.08))
		if i == selected or i in hint_pair:
			board.draw_rect(Rect2(p, Vector2(cs, cs)).grow(-2), Color(1, 1, 1, 0.8), false, 3.0)
		var k: int = engine.grid[i]
		if k < 0:
			continue
		var col: Color = GEM_COLORS[k]
		if i in flashing:
			col = Color(1, 1, 1)
		_draw_gem(p + Vector2(cs, cs) / 2.0, cs * 0.38, k, col)

func _draw_gem(c: Vector2, r: float, kind: int, col: Color) -> void:
	var sides: int = [0, 4, 3, 6, 5, 8][kind]
	if sides == 0:
		board.draw_circle(c, r, col)
	else:
		var pts := PackedVector2Array()
		var rot := -PI / 2.0 if sides != 4 else 0.0
		for k in sides:
			var a := rot + TAU * k / sides
			pts.append(c + Vector2(cos(a), sin(a)) * r * (1.1 if sides == 3 else 1.0))
		board.draw_colored_polygon(pts, col)
	board.draw_circle(c - Vector2(r * 0.3, r * 0.3), r * 0.2, Color(1, 1, 1, 0.45))

func _cell_at(pos: Vector2) -> int:
	var p: Vector2 = (pos - _origin()) / _cell()
	var c := floori(p.x)
	var r := floori(p.y)
	if r < 0 or c < 0 or r >= GMEngine.SIZE or c >= GMEngine.SIZE:
		return -1
	return r * GMEngine.SIZE + c

func _on_board_input(event: InputEvent) -> void:
	if busy or over_dialog.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_cell = _cell_at(event.position)
			press_pos = event.position
		elif press_cell >= 0:
			var d: Vector2 = event.position - press_pos
			if d.length() > _cell() * 0.4:
				# swipe: swap with the neighbour in that direction
				var n := press_cell
				if abs(d.x) > abs(d.y):
					n += 1 if d.x > 0 else -1
				else:
					n += GMEngine.SIZE if d.y > 0 else -GMEngine.SIZE
				if n >= 0 and n < GMEngine.SIZE * GMEngine.SIZE and GMEngine.adjacent(press_cell, n):
					_attempt(press_cell, n)
			elif selected >= 0 and GMEngine.adjacent(selected, press_cell):
				_attempt(selected, press_cell)
			else:
				selected = -1 if selected == press_cell else press_cell
				board.queue_redraw()
			press_cell = -1
