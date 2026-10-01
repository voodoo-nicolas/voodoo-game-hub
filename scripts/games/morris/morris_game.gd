extends Control

## Nine Men's Morris vs the computer. You are white and move first.

const MorrisEngine = preload("res://scripts/games/morris/morris_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const HUMAN := 1
const CPU := 2
const COLOR_LINE := Color(0.75, 0.6, 0.4)
const COLOR_BOARD := Color(0.3, 0.2, 0.12)
const COLOR_WHITE := Color(0.95, 0.93, 0.88)
const COLOR_BLACK := Color(0.12, 0.12, 0.14)
const COLOR_HILITE := Color(0.4, 0.9, 1.0)
const COLOR_REMOVE := Color(1.0, 0.3, 0.3)

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var engine: MorrisEngine
var board: Control
var status_label: Label
var info_label: Label
var cpu_timer: Timer
var end_dialog: ColorRect
var selected: int = -1
var must_remove := false
var difficulty_btn: Button
var depth: int = 2

func _ready() -> void:
	preload("res://scripts/games/morris/morris_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MorrisEngine.new()
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
	title.text = tr("✳️ Nine Men's Morris")
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
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

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
	bm.add_theme_constant_override("margin_bottom", 36)
	bm.add_child(bottom)
	root.add_child(bm)
	difficulty_btn = Button.new()
	difficulty_btn.custom_minimum_size = Vector2(280, 64)
	difficulty_btn.add_theme_font_size_override("font_size", 26)
	difficulty_btn.pressed.connect(_toggle_difficulty)
	bottom.add_child(difficulty_btn)

	cpu_timer = Timer.new()
	cpu_timer.one_shot = true
	cpu_timer.wait_time = 0.5
	cpu_timer.timeout.connect(_cpu_turn)
	add_child(cpu_timer)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _start_new_game},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/morris/morris_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _toggle_difficulty() -> void:
	depth = 3 if depth == 2 else 2
	_update_labels()

func _start_new_game() -> void:
	result_recorded = false
	cpu_timer.stop()
	engine.reset()
	selected = -1
	must_remove = false
	end_dialog.visible = false
	_update_labels()

func _update_labels() -> void:
	difficulty_btn.text = tr("Computer: Hard") if depth == 3 else tr("Computer: Normal")
	info_label.text = tr("You: %d to place, %d on board   ·   CPU: %d to place, %d on board") % [
		engine.to_place[0], engine.count(HUMAN), engine.to_place[1], engine.count(CPU)]
	if engine.winner != 0:
		status_label.text = ""
	elif engine.turn == CPU:
		status_label.text = tr("Computer is thinking...")
	elif must_remove:
		status_label.text = tr("Mill! Tap a black piece to remove it.")
	elif engine.placing(HUMAN):
		status_label.text = tr("Tap a point to place a piece.")
	elif engine.flying(HUMAN):
		status_label.text = tr("Only 3 left: you can fly anywhere!")
	else:
		status_label.text = tr("Select a piece, then an empty neighbour.")
	board.queue_redraw()

# ---------- player input ----------

func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.turn != HUMAN or engine.winner != 0:
		return
	var pos := _point_at(event.position)
	if pos < 0:
		return
	if must_remove:
		if pos in engine.removable(CPU):
			engine.remove_piece(pos)
			must_remove = false
			_end_human_turn()
		return
	var legal: Array = engine.moves_for(HUMAN)
	if engine.placing(HUMAN):
		if [-1, pos] in legal:
			_after_move(engine.apply_move(-1, pos))
		return
	if engine.board[pos] == HUMAN:
		selected = pos
		board.queue_redraw()
	elif selected >= 0 and [selected, pos] in legal:
		var from := selected
		selected = -1
		_after_move(engine.apply_move(from, pos))

func _after_move(mill: bool) -> void:
	if mill and not engine.removable(CPU).is_empty():
		must_remove = true
		_update_labels()
		return
	_end_human_turn()

func _end_human_turn() -> void:
	engine.end_turn()
	_update_labels()
	if not _check_game_over():
		cpu_timer.start()

func _cpu_turn() -> void:
	var m: Array = engine.best_move(depth)
	engine.apply_move(m[0], m[1])
	if m[2] >= 0:
		engine.remove_piece(m[2])
	engine.end_turn()
	_update_labels()
	_check_game_over()

func _check_game_over() -> bool:
	if engine.winner == 0:
		return false
	var msg: String
	if engine.winner == HUMAN:
		msg = tr("You win!")
	elif engine.winner == CPU:
		msg = tr("You lose!")
	else:
		msg = tr("Draw — no mills for too long.")
	msg += _record_result("win" if engine.winner == HUMAN else ("loss" if engine.winner == CPU else "draw"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	return true

# ---------- drawing ----------

func _geom() -> Dictionary:
	var side: float = min(board.size.x - 60.0, board.size.y - 30.0)
	var step := side / 6.0
	return {"step": step, "origin": Vector2((board.size.x - side) / 2.0, (board.size.y - side) / 2.0)}

func _point_pos(i: int, g: Dictionary) -> Vector2:
	return g.origin + Vector2(MorrisEngine.COORDS[i]) * g.step

func _point_at(p: Vector2) -> int:
	var g := _geom()
	for i in 24:
		if p.distance_to(_point_pos(i, g)) < g.step * 0.45:
			return i
	return -1

func _draw_board() -> void:
	if engine.board.is_empty():
		return
	var g := _geom()
	var step: float = g.step
	board.draw_rect(Rect2(g.origin - Vector2(step, step) * 0.5, Vector2(step, step) * 7.0), COLOR_BOARD)
	for m in MorrisEngine.MILLS:
		board.draw_line(_point_pos(m[0], g), _point_pos(m[2], g), COLOR_LINE, 4)
	var removable: Array = engine.removable(CPU) if must_remove else []
	var targets: Array = []
	if selected >= 0:
		for mv in engine.moves_for(HUMAN):
			if mv[0] == selected:
				targets.append(mv[1])
	for i in 24:
		var p := _point_pos(i, g)
		var v: int = engine.board[i]
		if v == MorrisEngine.EMPTY:
			board.draw_circle(p, step * 0.1, COLOR_LINE)
			if i in targets:
				board.draw_circle(p, step * 0.2, Color(COLOR_HILITE, 0.5))
			continue
		var col := COLOR_WHITE if v == HUMAN else COLOR_BLACK
		board.draw_circle(p, step * 0.32, col)
		board.draw_arc(p, step * 0.32, 0, TAU, 32, Color(0.5, 0.5, 0.5), 2)
		if i == selected:
			board.draw_arc(p, step * 0.38, 0, TAU, 32, COLOR_HILITE, 5)
		elif i in removable:
			board.draw_arc(p, step * 0.38, 0, TAU, 32, COLOR_REMOVE, 4)


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()
