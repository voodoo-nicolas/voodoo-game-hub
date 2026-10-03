extends Control

## Block Drop -- drag sideways on the well to move, tap to rotate, flick down
## to drop. The buttons below do the same.

const BDEngine = preload("res://scripts/games/block_drop/block_drop_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://block_drop_best.json"
const PREFS_PATH := "user://block_drop_prefs.json"
## [name, first level, step-time multiplier]
const DIFFICULTIES := [["Easy", 1, 1.4], ["Normal", 1, 1.0], ["Hard", 5, 1.0]]
## [name, columns, rows]
const BOARDS := [["Classic", 10, 20], ["Big", 12, 24], ["Huge", 14, 28]]
const COLORS := [Color(0.3, 0.85, 0.95), Color(0.98, 0.85, 0.25), Color(0.7, 0.4, 0.95), Color(0.4, 0.85, 0.4),
	Color(0.95, 0.35, 0.35), Color(0.3, 0.5, 0.95), Color(0.98, 0.6, 0.2)]

var info = null  # GameInfo; null on apps without it, so guard every use
var engine: BDEngine
var board: Control
var side: Control
var gravity: Timer
var start_dialog: ColorRect
var over_dialog: ColorRect
var pause_dialog: ColorRect
var running := false
var best: int = 0
var drag_origin := Vector2.ZERO
var drag_moved := 0
var dragging := false
var drag_time: int = 0
var difficulty: int = 1
var board_size: int = 0

func _ready() -> void:
	preload("res://scripts/games/block_drop/block_drop_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BDEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	var prefs = SaveUtil.read(PREFS_PATH)
	if prefs != null:
		difficulty = clampi(int(prefs.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)
		board_size = clampi(int(prefs.get("board", 0)), 0, BOARDS.size() - 1)
	_build_ui()
	engine.reset()
	start_dialog.visible = true

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
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
	title.text = tr("🧱 Block Drop")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	var play := HBoxContainer.new()
	play.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play.add_theme_constant_override("separation", 10)
	root.add_child(play)
	board = Control.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_stretch_ratio = 3.0
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(board.queue_redraw)
	play.add_child(board)
	side = Control.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.draw.connect(_draw_side)
	play.add_child(side)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_child(controls)
	root.add_child(cm)
	controls.add_child(_ctrl("◀", _on_left))
	controls.add_child(_ctrl("↺", _on_rotate_left))
	controls.add_child(_ctrl("↻", _on_rotate))
	controls.add_child(_ctrl("▼", _on_soft))
	controls.add_child(_ctrl("⇊", _on_hard))
	controls.add_child(_ctrl("▶", _on_right))

	gravity = Timer.new()
	gravity.timeout.connect(_on_gravity)
	add_child(gravity)

	start_dialog = UI.build_dialog(tr("🧱 Block Drop"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	start_dialog.get_meta("message_label").text = tr("Fill whole rows to clear them. Tap to rotate, drag to move, flick down to drop.")
	_add_mode_pickers(start_dialog)
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("Exit to Hub"), "action": UI.exit_to_hub.bind(self)},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/block_drop/block_drop_help.gd"))
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.62)  # beside the Next panel, clear of ▶
	add_child(drawer)

## Two rows of choices above Start: how fast (Difficulty) and how big the
## well is (Board) -- a bigger well means smaller pieces with more room.
func _add_mode_pickers(dialog: Control) -> void:
	var msg: Label = dialog.get_meta("message_label")
	var box: VBoxContainer = msg.get_parent()
	var at := msg.get_index() + 1
	var rows := [[tr("Difficulty"), DIFFICULTIES, "difficulty"], [tr("Board"), BOARDS, "board"]]
	for spec in rows:
		var label := Label.new()
		label.text = spec[0]
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		box.move_child(label, at)
		at += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		box.move_child(row, at)
		at += 1
		var group := ButtonGroup.new()
		for i in spec[1].size():
			var b := Button.new()
			b.text = tr(spec[1][i][0])
			b.toggle_mode = true
			b.button_group = group
			b.custom_minimum_size = Vector2(104, 52)
			b.add_theme_font_size_override("font_size", 22)
			b.button_pressed = i == (difficulty if spec[2] == "difficulty" else board_size)
			b.pressed.connect(_pick_mode.bind(spec[2], i))
			var on := StyleBoxFlat.new()
			on.bg_color = Color(0.25, 0.5, 0.95)
			on.set_corner_radius_all(10)
			b.add_theme_stylebox_override("pressed", on)
			row.add_child(b)

func _pick_mode(kind: String, i: int) -> void:
	if kind == "difficulty":
		difficulty = i
	else:
		board_size = i
	SaveUtil.write(PREFS_PATH, {"difficulty": difficulty, "board": board_size})

func _ctrl(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(106, 96)
	b.add_theme_font_size_override("font_size", 38)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b

func _start() -> void:
	var d: Array = DIFFICULTIES[difficulty]
	var b: Array = BOARDS[board_size]
	engine.configure(b[1], b[2], d[1], d[2])
	engine.reset()
	over_dialog.visible = false
	running = true
	gravity.wait_time = engine.step_seconds()
	gravity.start()
	_redraw()

func _resume() -> void:
	running = true
	gravity.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running:
			running = false
			gravity.stop()
			pause_dialog.visible = true

func _redraw() -> void:
	board.queue_redraw()
	side.queue_redraw()

func _after_lock(_cleared: int) -> void:
	gravity.wait_time = engine.step_seconds()
	if engine.over:
		running = false
		gravity.stop()
		if engine.score > best:
			best = engine.score
			SaveUtil.write(BEST_PATH, {"best": best})
		if info:
			info.add("Games played")
			info.best("Best score", best)
			info.high("Most lines", engine.lines)
		over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
		over_dialog.visible = true
	_redraw()

func _on_gravity() -> void:
	if not running:
		return
	var r := engine.tick()
	if r >= 0:
		_after_lock(r)
	else:
		_redraw()

func _on_left() -> void:
	if running:
		engine.move(-1)
		_redraw()

func _on_right() -> void:
	if running:
		engine.move(1)
		_redraw()

func _on_rotate() -> void:
	if running:
		engine.rotate(1)
		_redraw()

func _on_rotate_left() -> void:
	if running:
		engine.rotate(-1)
		_redraw()

func _on_soft() -> void:
	if running:
		var r := engine.tick()
		engine.score += 1
		if r >= 0:
			_after_lock(r)
		else:
			_redraw()

func _on_hard() -> void:
	if running:
		_after_lock(engine.hard_drop())

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_LEFT: _on_left()
		KEY_RIGHT: _on_right()
		KEY_UP: _on_rotate()
		KEY_Z: _on_rotate_left()
		KEY_DOWN: _on_soft()
		KEY_SPACE: _on_hard()

# ---------- drawing ----------

func _cell() -> float:
	return floor(min(board.size.x / engine.w, board.size.y / engine.h))

func _origin() -> Vector2:
	var c := _cell()
	return Vector2((board.size.x - c * engine.w) / 2.0, (board.size.y - c * engine.h) / 2.0)

func _block(canvas: CanvasItem, rect: Rect2, col: Color) -> void:
	canvas.draw_rect(rect.grow(-1), col)
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, rect.size.y * 0.18)), col.lightened(0.3))

func _draw_board() -> void:
	var c := _cell()
	var o := _origin()
	board.draw_rect(Rect2(o, Vector2(c * engine.w, c * engine.h)), Color(0.12, 0.12, 0.17))
	for x in range(1, engine.w):
		board.draw_line(o + Vector2(x * c, 0), o + Vector2(x * c, c * engine.h), Color(1, 1, 1, 0.04))
	for i in engine.w * engine.h:
		var v: int = engine.well[i]
		if v != 0:
			_block(board, Rect2(o + Vector2(i % engine.w, i / engine.w) * c, Vector2(c, c)), COLORS[v - 1])
	if engine.over:
		return
	var gy := engine.ghost_y()
	for cell in engine.cells(engine.piece, engine.rot, Vector2i(engine.pos.x, gy)):
		if cell.y >= 0:
			board.draw_rect(Rect2(o + Vector2(cell) * c, Vector2(c, c)).grow(-2), Color(1, 1, 1, 0.12), false, 2.0)
	for cell in engine.cells():
		if cell.y >= 0:
			_block(board, Rect2(o + Vector2(cell) * c, Vector2(c, c)), COLORS[engine.piece])

func _draw_side() -> void:
	var font: Font = ThemeDB.fallback_font
	var y := 30.0
	for pair in [[tr("Score"), engine.score], [tr("Lines"), engine.lines], [tr("Level"), engine.level], [tr("Best"), best]]:
		side.draw_string(font, Vector2(0, y), pair[0], HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 22, Color(0.65, 0.65, 0.75))
		side.draw_string(font, Vector2(0, y + 36), str(pair[1]), HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 32, Color(1, 1, 1))
		y += 90
	side.draw_string(font, Vector2(0, y), tr("Next"), HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 22, Color(0.65, 0.65, 0.75))
	var c: float = min(30.0, side.size.x / 5.0)
	for cell in engine.cells(engine.next_piece, 0, Vector2i.ZERO):
		_block(side, Rect2(Vector2(side.size.x / 2.0 - 2 * c + cell.x * c, y + 20 + cell.y * c), Vector2(c, c)), COLORS[engine.next_piece])

func _on_board_input(event: InputEvent) -> void:
	if not running:
		return
	var c := _cell()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_origin = event.position
			drag_moved = 0
			drag_time = Time.get_ticks_msec()
		elif dragging:
			dragging = false
			var d: Vector2 = event.position - drag_origin
			var quick: bool = Time.get_ticks_msec() - drag_time < 300
			if drag_moved == 0 and d.length() < c * 0.6:
				_on_rotate()
			elif d.y > c * 2.5 and d.y > abs(d.x) * 1.5 and quick:
				_on_hard()
	elif event is InputEventMouseMotion and dragging:
		var steps := int((event.position.x - drag_origin.x) / c)
		while steps > drag_moved:
			engine.move(1)
			drag_moved += 1
		while steps < drag_moved:
			engine.move(-1)
			drag_moved -= 1
		_redraw()
