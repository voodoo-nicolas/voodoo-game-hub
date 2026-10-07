extends Control

## Brick Breaker -- slide to move the paddle, tap to launch the ball.

const BBEngine = preload("res://scripts/games/brick_breaker/brick_breaker_engine.gd")
const HomeKit = preload("res://scripts/games/brick_breaker/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://brick_breaker_best.json"
const ROW_COLORS := [Color(0.95, 0.35, 0.35), Color(0.98, 0.6, 0.2), Color(0.98, 0.85, 0.25), Color(0.4, 0.85, 0.4),
	Color(0.3, 0.75, 0.95), Color(0.45, 0.45, 0.95), Color(0.75, 0.45, 0.95)]

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
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

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	var bg := HomeKit.backdrop()
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
	hub_btn.text = "⏸"
	hub_btn.custom_minimum_size = Vector2(76, 64)
	hub_btn.add_theme_font_size_override("font_size", 30)
	hub_btn.pressed.connect(_on_pause_home)
	bar.add_child(hub_btn)
	var title := Label.new()
	title.text = tr("🎯 Brick Breaker")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = "↺"
	restart_btn.custom_minimum_size = Vector2(76, 64)
	restart_btn.add_theme_font_size_override("font_size", 30)
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
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	start_dialog.get_meta("message_label").text = tr("Slide to move the paddle, tap to launch. Break every brick!")
	add_child(start_dialog)
	over_dialog = UI.build_dialog(tr("Game Over"), [
		{"text": tr("Play Again"), "action": _start},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/brick_breaker/brick_breaker_help.gd"))
	_build_home()
	if info:
		add_child(info)
		if best > 0:
			info.high("Best score", best)
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
		if is_node_ready() and running and home:
			home.pause()

func _update_info() -> void:
	info_label.text = tr("Level %d   Score: %d   Lives: %s   Best: %d") % [engine.level, engine.score, "♥".repeat(max(0, engine.lives)), best]

func _process(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
	if not running:
		board.queue_redraw()
		return
	var pre_score: int = engine.score
	var res := engine.step(min(delta, 0.05))
	if res == "cleared":
		_sfx("powerup")
	elif res != "":
		_sfx("explode")
	elif engine.score > pre_score:
		_sfx("hit")
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
			if info:
				info.add("Games played")
				info.best("Best score", best)
				info.high("Highest level", engine.level)
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
	board.draw_rect(Rect2(o, BBEngine.FIELD * s), Color(0.03, 0.04, 0.1))
	HomeKit.glow_rect(board, Rect2(o, BBEngine.FIELD * s), HomeKit.BLUE, 2.0)
	for b in engine.bricks:
		var r: Rect2 = b.rect
		var col: Color = ROW_COLORS[b.row % ROW_COLORS.size()]
		var rect := Rect2(o + r.position * s, r.size * s).grow(-2)
		# tough bricks are filled brighter; every brick is a glowing outline
		board.draw_rect(rect, Color(col, 0.45 if b.hp > 1 else 0.18))
		board.draw_rect(rect, col, false, 2.0)
		board.draw_rect(rect.grow(2), Color(col, 0.25), false, 3.0)
	var pw := BBEngine.PADDLE * s
	HomeKit.glow_rect(board, Rect2(o + Vector2(engine.paddle_x * s - pw.x / 2.0, BBEngine.PADDLE_Y * s), pw), HomeKit.CYAN, 2.5, 0.45)
	HomeKit.glow_circle(board, o + engine.ball * s, BBEngine.BALL_R * s, Color.WHITE, 2.0, 0.9)
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

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/brick_breaker/brick_breaker_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"retro": true,
		"help": preload("res://scripts/games/brick_breaker/brick_breaker_help.gd"),
		"info": info,
		"accent": HomeKit.CYAN,
		"subtitle": "Slide the paddle, tap to launch. Smash every brick!",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "Three lives, level after level", "action": _start}],
		"restart": _start,
		"board_note": "Your best score.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 180.0)
	var w := h * 1.4
	var o := Vector2((c.size.x - w) / 2.0, (c.size.y - h) / 2.0)
	var cols := [HomeKit.MAGENTA, HomeKit.GOLD, HomeKit.LIME]
	for row in 3:
		for i in 5:
			if row == 2 and i == 3:
				continue
			HomeKit.glow_rect(c, Rect2(o + Vector2(i * w / 5.0 + 3, row * h * 0.13 + 3), Vector2(w / 5.0 - 6, h * 0.13 - 6)), cols[row], 1.5, 0.3)
	HomeKit.glow_circle(c, o + Vector2(w * 0.62, h * 0.62), h * 0.05, Color.WHITE, 2.0, 0.8)
	HomeKit.glow_line(c, o + Vector2(w * 0.62, h * 0.62), o + Vector2(w * 0.5, h * 0.86), Color(HomeKit.CYAN, 0.5), 1.0)
	HomeKit.glow_rect(c, Rect2(o + Vector2(w * 0.32, h * 0.9), Vector2(w * 0.36, h * 0.07)), HomeKit.CYAN, 2.5, 0.4)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
