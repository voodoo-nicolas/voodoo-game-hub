extends Control

## Brick Breaker -- slide to move the paddle, tap to launch the ball.

const BBEngine = preload("res://scripts/games/brick_breaker/brick_breaker_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")

const BEST_PATH := "user://brick_breaker_best.json"
const ROW_COLORS := [Color(0.95, 0.35, 0.35), Color(0.98, 0.6, 0.2), Color(0.98, 0.85, 0.25), Color(0.4, 0.85, 0.4),
	Color(0.3, 0.75, 0.95), Color(0.45, 0.45, 0.95), Color(0.75, 0.45, 0.95)]

var engine: BBEngine
var board: Control
var info_label: Label
var start_dialog: ColorRect
var over_dialog: ColorRect
var pause_dialog: ColorRect
var running := false
var best: int = 0
var banner := ""
var banner_time: float = 0.0

func _ready() -> void:
	preload("res://scripts/games/brick_breaker/brick_breaker_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BBEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	engine.reset()
	_update_info()
	start_dialog.visible = true

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
	title.text = tr("🎯 Brick Breaker")
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
	info_label.add_theme_font_size_override("font_size", 26)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(info_label)

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

	start_dialog = UI.build_dialog(tr("🎯 Brick Breaker"), [
		{"text": tr("Start"), "action": _start},
		{"text": tr("Back to Hub"), "action": UI.exit_to_hub.bind(self)},
	], true)
	start_dialog.get_meta("message_label").text = tr("Slide to move the paddle, tap to launch. Break every brick!")
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
	add_child(SettingsDrawer.new())

func _start() -> void:
	engine.reset()
	over_dialog.visible = false
	running = true
	_update_info()

func _resume() -> void:
	running = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and running:
			running = false
			pause_dialog.visible = true

func _update_info() -> void:
	info_label.text = tr("Level %d   Score: %d   Lives: %s   Best: %d") % [engine.level, engine.score, "♥".repeat(max(0, engine.lives)), best]

func _process(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
	if not running:
		board.queue_redraw()
		return
	var res := engine.step(min(delta, 0.05))
	match res:
		"cleared":
			banner = tr("Level %d!") % engine.level
			banner_time = 1.5
		"lost_life":
			banner = tr("Ouch! Tap to launch")
			banner_time = 1.5
		"game_over":
			running = false
			if engine.score > best:
				best = engine.score
				SaveUtil.write(BEST_PATH, {"best": best})
			over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
			over_dialog.visible = true
	if res != "":
		_update_info()
	elif engine.stuck == false:
		_update_info()
	board.queue_redraw()

func _scale() -> float:
	return min(board.size.x / BBEngine.FIELD.x, board.size.y / BBEngine.FIELD.y)

func _origin() -> Vector2:
	return (board.size - BBEngine.FIELD * _scale()) / 2.0

func _draw_board() -> void:
	var s := _scale()
	var o := _origin()
	board.draw_rect(Rect2(o, BBEngine.FIELD * s), Color(0.08, 0.1, 0.16))
	for b in engine.bricks:
		var r: Rect2 = b.rect
		var col: Color = ROW_COLORS[b.row % ROW_COLORS.size()]
		if b.hp > 1:
			col = col.darkened(0.45)
		var rect := Rect2(o + r.position * s, r.size * s)
		board.draw_rect(rect, col)
		board.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.25)), col.lightened(0.25))
	var pw := BBEngine.PADDLE * s
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.9, 1.0)
	sb.set_corner_radius_all(int(pw.y / 2.0))
	board.draw_style_box(sb, Rect2(o + Vector2(engine.paddle_x * s - pw.x / 2.0, BBEngine.PADDLE_Y * s), pw))
	board.draw_circle(o + engine.ball * s, BBEngine.BALL_R * s, Color(1, 1, 0.85))
	var font: Font = ThemeDB.fallback_font
	if banner_time > 0.0:
		board.draw_string(font, o + Vector2(0, BBEngine.FIELD.y * s * 0.6), banner, HORIZONTAL_ALIGNMENT_CENTER, BBEngine.FIELD.x * s, 40, Color(1, 0.9, 0.4))
	elif running and engine.stuck:
		board.draw_string(font, o + Vector2(0, BBEngine.FIELD.y * s * 0.6), tr("Tap to launch"), HORIZONTAL_ALIGNMENT_CENTER, BBEngine.FIELD.x * s, 34, Color(1, 1, 1, 0.7))

func _on_board_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		engine.set_paddle((event.position.x - _origin().x) / _scale())
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		engine.launch()
