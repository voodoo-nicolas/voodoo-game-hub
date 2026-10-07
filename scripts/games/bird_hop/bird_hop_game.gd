extends Control

## Bird Hop -- tap anywhere to flap.

const BHEngine = preload("res://scripts/games/bird_hop/bird_hop_engine.gd")
const HomeKit = preload("res://scripts/games/bird_hop/home_kit.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const UI = preload("res://scripts/common/ui.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"

const BEST_PATH := "user://bird_hop_best.json"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit: Home screen + pause menu
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
	_start()  # frozen behind the Home screen until Play

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
	title.text = tr("🐦 Bird Hop")
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
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(over_dialog)
	pause_dialog = UI.build_dialog(tr("Paused"), [
		{"text": tr("Resume"), "action": _resume},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	])
	add_child(pause_dialog)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(preload("res://scripts/games/bird_hop/bird_hop_help.gd"))
	_build_home()
	if info:
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
		if is_node_ready() and engine.started and not engine.dead and home:
			home.pause()

func _process(delta: float) -> void:
	if not paused:
		var pre_score: int = engine.score
		var was_dead: bool = engine.dead
		engine.step(min(delta, 0.05))
		if engine.dead and not was_dead:
			_sfx("hit")
		elif engine.score > pre_score:
			_sfx("pickup")
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
	var ground_y := BHEngine.GROUND * s
	# night sky with a faint grid that scrolls slower than the pillars
	board.draw_rect(Rect2(Vector2.ZERO, Vector2(board.size.x, ground_y)), Color(0.03, 0.04, 0.1))
	var step := 60.0 * s
	var gx := -fmod(engine.scroll * 0.3 * s, step)
	while gx < board.size.x:
		board.draw_line(Vector2(gx, 0), Vector2(gx, ground_y), Color(0.23, 0.55, 1.0, 0.08), 1.0)
		gx += step
	var gy0 := 0.0
	while gy0 < ground_y:
		board.draw_line(Vector2(0, gy0), Vector2(board.size.x, gy0), Color(0.23, 0.55, 1.0, 0.08), 1.0)
		gy0 += step
	# pillars: glowing lime outlines
	for p in engine.pillars:
		var x: float = p.x * s
		var gy: float = p.gap_y * s
		var gh: float = p.gap * s / 2.0
		var w := BHEngine.PILLAR_W * s
		HomeKit.glow_rect(board, Rect2(x, -4, w, gy - gh - 30 * s + 4), HomeKit.LIME, 3.0, 0.08)
		HomeKit.glow_rect(board, Rect2(x - 6 * s, gy - gh - 30 * s, w + 12 * s, 30 * s), HomeKit.LIME, 3.0, 0.2)
		HomeKit.glow_rect(board, Rect2(x - 6 * s, gy + gh, w + 12 * s, 30 * s), HomeKit.LIME, 3.0, 0.2)
		HomeKit.glow_rect(board, Rect2(x, gy + gh + 30 * s, w, ground_y - gy - gh - 30 * s), HomeKit.LIME, 3.0, 0.08)
	# ground: a magenta horizon with scrolling ticks
	board.draw_rect(Rect2(0, ground_y, board.size.x, board.size.y - ground_y), Color(0.06, 0.02, 0.1))
	HomeKit.glow_line(board, Vector2(0, ground_y), Vector2(board.size.x, ground_y), HomeKit.MAGENTA, 3.0)
	var stripe := -fmod(engine.scroll * s, 40.0 * s)
	while stripe < board.size.x:
		board.draw_line(Vector2(stripe, ground_y + 6), Vector2(stripe - 20 * s, board.size.y), Color(HomeKit.MAGENTA, 0.35), 2.0)
		stripe += 40 * s
	# the bird: a glowing gold orb with a beak, tilted with its speed
	var c := Vector2(BHEngine.BIRD_X * s, engine.bird_y * s)
	var r := BHEngine.BIRD_R * s
	var tilt: float = clamp(engine.vel / 900.0, -0.5, 1.2)
	for k in 4:  # a short trail
		board.draw_circle(c - Vector2((k + 1) * r * 0.7, -engine.vel * 0.0006 * s * (k + 1) * 10.0), r * (0.5 - k * 0.1), Color(HomeKit.GOLD, 0.12 - k * 0.025))
	board.draw_set_transform(c, tilt)
	HomeKit.glow_circle(board, Vector2.ZERO, r, HomeKit.GOLD, 3.0, 0.35)
	board.draw_circle(Vector2(r * 0.4, -r * 0.3), r * 0.26, Color(1, 1, 1))
	board.draw_circle(Vector2(r * 0.5, -r * 0.3), r * 0.12, Color(0.05, 0.03, 0.1))
	HomeKit.glow_polyline(board, PackedVector2Array([Vector2(r * 0.85, -r * 0.05), Vector2(r * 1.5, r * 0.15), Vector2(r * 0.85, r * 0.35)]), HomeKit.PINK, 2.0, true)
	HomeKit.glow_polyline(board, PackedVector2Array([Vector2(-r * 0.2, r * 0.1), Vector2(-r * 0.95, -r * 0.35 if engine.vel < 0 else r * 0.55), Vector2(-r * 0.55, r * 0.3)]), HomeKit.GOLD, 2.0, true)
	board.draw_set_transform(Vector2.ZERO, 0.0)
	var font: Font = ThemeDB.fallback_font
	var score_pos := Vector2(0, 110 * s)
	board.draw_string_outline(font, score_pos, str(engine.score), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 80, 10, Color(HomeKit.CYAN, 0.4))
	board.draw_string(font, score_pos, str(engine.score), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 80, Color(0.9, 1, 1))
	if not engine.started:
		board.draw_string(font, Vector2(0, 640 * s), tr("Tap to flap!"), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 44, HomeKit.GOLD.lerp(Color.WHITE, 0.4))
		board.draw_string(font, Vector2(0, 700 * s), tr("Best: %d") % best, HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 32, Color(1, 1, 1, 0.8))

func _on_board_input(event: InputEvent) -> void:
	if paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_flap()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and not paused:
		_flap()

# ---------- Home screen (home_kit.gd) ----------

const TITLE_FOR_HOME := preload("res://scripts/games/bird_hop/bird_hop_help.gd").TITLE

func _build_home() -> void:
	home = HomeKit.new({
		"retro": true,
		"help": preload("res://scripts/games/bird_hop/bird_hop_help.gd"),
		"info": info,
		"accent": HomeKit.GOLD,
		"subtitle": "Tap to flap. Slip through the gaps.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  Play", "sub": "Tap anywhere to fly", "action": _start}],
		"restart": _start,
		"board_note": "Your best score: pillars passed in one flight.",
	})
	add_child(home)

func _on_pause_home() -> void:
	home.pause()

func _go_home() -> void:
	home.go_home()

func _draw_home_logo(c: Control) -> void:
	var h := minf(c.size.y, 180.0)
	var o := Vector2(c.size.x / 2.0, c.size.y / 2.0)
	for side in [-1, 1]:
		var x: float = o.x + side * h * 0.55
		HomeKit.glow_rect(c, Rect2(x - h * 0.12, o.y - h / 2.0, h * 0.24, h * 0.32), HomeKit.LIME, 2.5, 0.12)
		HomeKit.glow_rect(c, Rect2(x - h * 0.12, o.y + h * 0.18, h * 0.24, h * 0.32), HomeKit.LIME, 2.5, 0.12)
	HomeKit.glow_circle(c, o, h * 0.14, HomeKit.GOLD, 3.0, 0.35)
	c.draw_circle(o + Vector2(h * 0.05, -h * 0.04), h * 0.03, Color.WHITE)
	HomeKit.glow_polyline(c, PackedVector2Array([o + Vector2(h * 0.13, 0), o + Vector2(h * 0.24, h * 0.03), o + Vector2(h * 0.13, h * 0.06)]), HomeKit.PINK, 2.0)
	HomeKit.glow_polyline(c, PackedVector2Array([o + Vector2(-h * 0.1, 0), o + Vector2(-h * 0.24, -h * 0.1), o + Vector2(-h * 0.14, h * 0.04)]), HomeKit.GOLD, 2.0)

func _flap() -> void:
	if not engine.dead:
		_sfx("jump")
	engine.flap()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
