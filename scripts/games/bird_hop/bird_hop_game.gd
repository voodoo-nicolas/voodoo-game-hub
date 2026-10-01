extends Control

## Bird Hop -- tap anywhere to flap.

const BHEngine = preload("res://scripts/games/bird_hop/bird_hop_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://bird_hop_best.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var engine: BHEngine
var board: Control
var over_dialog: ColorRect
var pause_dialog: ColorRect
var best: int = 0
var paused := false
var over_shown := false

func _ready() -> void:
	preload("res://scripts/games/bird_hop/bird_hop_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BHEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_build_ui()
	_start()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.13)
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
	title.text = tr("🐦 Bird Hop")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var restart_btn := Button.new()
	restart_btn.text = tr("Restart")
	restart_btn.add_theme_font_size_override("font_size", 26)
	restart_btn.pressed.connect(_start)
	bar.add_child(restart_btn)

	var bm := MarginContainer.new()
	bm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bm.add_theme_constant_override("margin_bottom", 24)
	root.add_child(bm)
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.clip_contents = true
	board.draw.connect(_draw_board)
	board.gui_input.connect(_on_board_input)
	bm.add_child(board)

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
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/bird_hop/bird_hop_help.gd"))
		add_child(info)
		if best > 0:
			info.high("Best score", best)
	add_child(SettingsDrawer.new())

func _start() -> void:
	engine.reset()
	over_dialog.visible = false
	over_shown = false
	paused = false

func _resume() -> void:
	paused = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and engine.started and not engine.dead:
			paused = true
			pause_dialog.visible = true

func _process(delta: float) -> void:
	if not paused:
		engine.step(min(delta, 0.05))
	if engine.dead and not over_shown:
		over_shown = true
		if engine.score > best:
			best = engine.score
			SaveUtil.write(BEST_PATH, {"best": best})
		if info:
			info.add("Games played")
			info.best("Best score", best)
		over_dialog.get_meta("message_label").text = tr("Score: %d") % engine.score + "\n" + tr("Best: %d") % best
		over_dialog.visible = true
	board.queue_redraw()

func _scale() -> float:
	return board.size.y / BHEngine.FIELD.y

func _draw_board() -> void:
	var s := _scale()
	# the field is as tall as the board; it stretches wider on wide screens,
	# so draw relative to the bird's fixed x and let pillars run across
	var sky := Rect2(Vector2.ZERO, Vector2(board.size.x, BHEngine.GROUND * s))
	board.draw_rect(sky, Color(0.45, 0.72, 0.95))
	# distant hills
	var hx := -fmod(engine.scroll * 0.3 * s, 300.0 * s)
	while hx < board.size.x:
		board.draw_circle(Vector2(hx + 150 * s, BHEngine.GROUND * s + 40 * s), 170 * s, Color(0.55, 0.8, 0.55))
		hx += 300 * s
	for p in engine.pillars:
		var x: float = p.x * s
		var gy: float = p.gap_y * s
		var gh: float = p.gap * s / 2.0
		var w := BHEngine.PILLAR_W * s
		var col := Color(0.35, 0.75, 0.3)
		board.draw_rect(Rect2(x, 0, w, gy - gh), col)
		board.draw_rect(Rect2(x, gy + gh, w, BHEngine.GROUND * s - gy - gh), col)
		board.draw_rect(Rect2(x - 6 * s, gy - gh - 30 * s, w + 12 * s, 30 * s), col.darkened(0.2))
		board.draw_rect(Rect2(x - 6 * s, gy + gh, w + 12 * s, 30 * s), col.darkened(0.2))
	board.draw_rect(Rect2(0, BHEngine.GROUND * s, board.size.x, board.size.y - BHEngine.GROUND * s), Color(0.85, 0.72, 0.45))
	var stripe := -fmod(engine.scroll * s, 40.0 * s)
	while stripe < board.size.x:
		board.draw_rect(Rect2(stripe, BHEngine.GROUND * s, 20 * s, 12 * s), Color(0.6, 0.8, 0.35))
		stripe += 40 * s
	# the bird, tilted with its speed
	var c := Vector2(BHEngine.BIRD_X * s, engine.bird_y * s)
	var r := BHEngine.BIRD_R * s
	var tilt: float = clamp(engine.vel / 900.0, -0.5, 1.2)
	board.draw_set_transform(c, tilt)
	board.draw_circle(Vector2.ZERO, r, Color(1, 0.85, 0.2))
	board.draw_circle(Vector2(r * 0.4, -r * 0.3), r * 0.28, Color(1, 1, 1))
	board.draw_circle(Vector2(r * 0.5, -r * 0.3), r * 0.13, Color(0, 0, 0))
	board.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.8, 0), Vector2(r * 1.45, r * 0.15), Vector2(r * 0.8, r * 0.35)]), Color(1, 0.5, 0.15))
	board.draw_circle(Vector2(-r * 0.3, r * 0.2), r * 0.45, Color(1, 0.95, 0.6))
	board.draw_set_transform(Vector2.ZERO, 0.0)
	var font: Font = ThemeDB.fallback_font
	board.draw_string(font, Vector2(0, 110 * s), str(engine.score), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 72, Color(1, 1, 1))
	if not engine.started:
		board.draw_string(font, Vector2(0, 640 * s), tr("Tap to flap!"), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 40, Color(1, 1, 1))
		board.draw_string(font, Vector2(0, 700 * s), tr("Best: %d") % best, HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 30, Color(1, 1, 1, 0.8))

func _on_board_input(event: InputEvent) -> void:
	if paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		engine.flap()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and not paused:
		engine.flap()
