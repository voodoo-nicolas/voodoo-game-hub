extends Control

## Paddle Ball -- slide your finger anywhere to move your paddle (bottom).

const PBEngine = preload("res://scripts/games/paddle_ball/paddle_ball_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

var result_recorded := false  # this game's result is already in the stats
var info = null  # GameInfo; null on apps without it, so guard every use
var engine: PBEngine
var board: Control
var start_dialog: ColorRect
var end_dialog: ColorRect
var pause_dialog: ColorRect
var level_btn: Button
var difficulty: int = 1
var running := false

func _ready() -> void:
	preload("res://scripts/games/paddle_ball/paddle_ball_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = PBEngine.new()
	_build_ui()
	engine.reset(difficulty)
	_show_start()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
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
	title.text = tr("🏓 Paddle Ball")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_show_start)
	bar.add_child(restart_btn)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_left", 12)
	bm.add_theme_constant_override("margin_right", 12)
	bm.add_theme_constant_override("margin_bottom", 24)
	root.add_child(bm)
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	bm.add_child(board)

	start_dialog = UI.build_dialog(tr("🏓 Paddle Ball"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	var box: Node = start_dialog.get_meta("message_label").get_parent()
	level_btn = Button.new()
	level_btn.custom_minimum_size = Vector2(320, 64)
	level_btn.add_theme_font_size_override("font_size", 26)
	level_btn.pressed.connect(_cycle_level)
	box.add_child(level_btn)
	box.move_child(level_btn, 2)
	add_child(start_dialog)
	end_dialog = UI.build_dialog("", [
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
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/paddle_ball/paddle_ball_help.gd"))
		add_child(info)
	add_child(SettingsDrawer.new())

func _cycle_level() -> void:
	difficulty = (difficulty + 1) % 3
	_update_level()

func _update_level() -> void:
	level_btn.text = tr("Computer: %s") % [tr("Easy"), tr("Medium"), tr("Hard")][difficulty]

func _show_start() -> void:
	running = false
	end_dialog.visible = false
	_update_level()
	start_dialog.get_meta("message_label").text = tr("Slide your finger to move. First to 7 points wins!")
	start_dialog.visible = true

func _start() -> void:
	result_recorded = false
	engine.reset(difficulty)
	running = true

func _resume() -> void:
	running = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running:
			running = false
			pause_dialog.visible = true

func _process(delta: float) -> void:
	if not running:
		return
	engine.step(min(delta, 0.05))
	if engine.winner() != -1:
		running = false
		end_dialog.get_meta("message_label").text = (tr("You win!") if engine.winner() == 0 else tr("You lose!")) + \
			"\n%d – %d" % [engine.scores[0], engine.scores[1]] + _record_result("win" if engine.winner() == 0 else "loss")
		end_dialog.visible = true
	board.queue_redraw()

func _scale() -> float:
	return min(board.size.x / PBEngine.FIELD.x, board.size.y / PBEngine.FIELD.y)

func _origin() -> Vector2:
	return (board.size - PBEngine.FIELD * _scale()) / 2.0

func _draw_board() -> void:
	var s := _scale()
	var o := _origin()
	var f := PBEngine.FIELD * s
	board.draw_rect(Rect2(o, f), Color(0.08, 0.12, 0.2))
	board.draw_rect(Rect2(o, f), Color(0.3, 0.5, 0.8, 0.6), false, 3.0)
	# centre line
	var x := 0.0
	while x < f.x:
		board.draw_line(o + Vector2(x, f.y / 2.0), o + Vector2(x + 16, f.y / 2.0), Color(1, 1, 1, 0.25), 3)
		x += 32
	var font: Font = ThemeDB.fallback_font
	board.draw_string(font, o + Vector2(0, f.y / 2.0 - 30), str(engine.scores[1]), HORIZONTAL_ALIGNMENT_CENTER, f.x, 64, Color(1, 1, 1, 0.3))
	board.draw_string(font, o + Vector2(0, f.y / 2.0 + 80), str(engine.scores[0]), HORIZONTAL_ALIGNMENT_CENTER, f.x, 64, Color(1, 1, 1, 0.3))
	var pw := PBEngine.PADDLE * s
	var cpu := Rect2(o + Vector2(engine.cpu_x * s - pw.x / 2.0, 60.0 * s), pw)
	var me := Rect2(o + Vector2(engine.player_x * s - pw.x / 2.0, (PBEngine.FIELD.y - 60.0) * s), pw)
	for pair in [[cpu, Color(1, 0.4, 0.4)], [me, Color(0.4, 0.9, 1.0)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = pair[1]
		sb.set_corner_radius_all(int(pw.y / 2.0))
		board.draw_style_box(sb, pair[0])
	board.draw_circle(o + engine.ball * s, PBEngine.BALL_R * s, Color(1, 1, 0.85))

func _on_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if event is InputEventMouseMotion or event.pressed:
			engine.set_player_x((event.position.x - _origin().x) / _scale())


## Records this game's result in the stats once (end checks can run again
## after a game is over) and returns the recap line for the end screen.
func _record_result(outcome: String) -> String:
	if not info:
		return ""
	if not result_recorded:
		result_recorded = true
		info.result(outcome)
	return "\n" + info.summary()
