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

const SoundLib = preload("res://scripts/games/bird_hop/sound_lib.gd")
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
var stars: Array = []       # [x 0..1, y 0..0.6, size, phase]
var city_far: Array = []    # [x, width, height] in field units
var city_near: Array = []
const CITY_LOOP := 1200.0

func _ready() -> void:
	preload("res://scripts/games/bird_hop/bird_hop_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BHEngine.new()
	var data = SaveUtil.read(BEST_PATH)
	if data != null:
		best = int(data.get("best", 0))
	_make_city()
	_build_ui()
	_start()  # frozen behind the Home screen until Play
	_music("lively")

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
			SoundLib.play(self, "scifi/impact_metal")
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

func _make_city() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for arr in [city_far, city_near]:
		var x := 0.0
		var far: bool = arr == city_far
		while x < CITY_LOOP:
			var bw := r.randf_range(50.0, 110.0)
			arr.append([x, bw, r.randf_range(90.0, 260.0) if far else r.randf_range(50.0, 190.0)])
			x += bw + r.randf_range(0.0, 18.0)
	for i in 55:
		stars.append([r.randf(), r.randf() * 0.6, r.randf_range(1.0, 2.6), r.randf() * TAU])

func _scale() -> float:
	return board.size.y / BHEngine.FIELD.y

func _draw_board() -> void:
	var s := _scale()
	var ground_y := BHEngine.GROUND * s
	var w := board.size.x
	# Neon night sky: deep indigo fading to magenta at the horizon.
	var bands := 14
	for i in bands:
		var t := float(i) / (bands - 1)
		board.draw_rect(Rect2(0, ground_y * i / bands, w, ground_y / bands + 1.0), Color(0.03, 0.02, 0.12).lerp(Color(0.32, 0.06, 0.42), pow(t, 2.2)))
	for st in stars:
		var tw := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003 + st[3])
		board.draw_rect(Rect2(st[0] * w, st[1] * ground_y, st[2], st[2]), Color(0.8, 0.95, 1.0, 0.3 + 0.5 * tw))
	# A glowing moon.
	HomeKit.glow_circle(board, Vector2(w * 0.2, ground_y * 0.14), 34.0 * s, HomeKit.CYAN, 3.0, 0.25)
	# The city: a dim far skyline and a brighter near one, drifting slower than the pillars.
	for layer in 2:
		var arr: Array = city_far if layer == 0 else city_near
		var spd := 0.12 if layer == 0 else 0.3
		var col := Color(0.55, 0.2, 0.95) if layer == 0 else HomeKit.CYAN
		var shift := fmod(engine.scroll * spd, CITY_LOOP)
		for rep_i in 2:
			for bd in arr:
				var bx: float = (bd[0] - shift + rep_i * CITY_LOOP) * s
				if bx > w or bx + bd[1] * s < 0.0:
					continue
				var bh: float = bd[2] * s
				var r := Rect2(bx, ground_y - bh, bd[1] * s, bh)
				board.draw_rect(r, Color(0.04, 0.02, 0.12, 0.9))
				board.draw_rect(r, Color(col, 0.5 if layer == 1 else 0.3), false, 1.5)
				var wy := r.position.y + 14.0 * s
				while wy < ground_y - 8.0 * s:
					board.draw_line(Vector2(bx + 6 * s, wy), Vector2(bx + bd[1] * s - 6 * s, wy), Color(col, 0.18), 1.0)
					wy += 22.0 * s
	# Pillars: neon pipes with a bright rim, an inner highlight and a ring on the mouth.
	for p in engine.pillars:
		var x: float = p.x * s
		var gy: float = p.gap_y * s
		var gh: float = p.gap * s / 2.0
		var pw := BHEngine.PILLAR_W * s
		var pc: Color = HomeKit.CYAN if int(p.x / BHEngine.SPACING + engine.scroll / BHEngine.SPACING) % 2 == 0 else HomeKit.PURPLE
		var top_h := gy - gh - 30 * s
		var bot_y := gy + gh + 30 * s
		board.draw_rect(Rect2(x, -4, pw, top_h + 4), Color(pc.darkened(0.8), 0.9))
		board.draw_rect(Rect2(x, bot_y, pw, ground_y - bot_y), Color(pc.darkened(0.8), 0.9))
		board.draw_line(Vector2(x + pw * 0.22, 0), Vector2(x + pw * 0.22, top_h), Color(pc, 0.45), 2.0)
		board.draw_line(Vector2(x + pw * 0.22, bot_y), Vector2(x + pw * 0.22, ground_y), Color(pc, 0.45), 2.0)
		HomeKit.glow_rect(board, Rect2(x, -4, pw, top_h + 4), pc, 3.0, 0.0)
		HomeKit.glow_rect(board, Rect2(x - 6 * s, top_h, pw + 12 * s, 30 * s), pc, 3.0, 0.25)
		HomeKit.glow_rect(board, Rect2(x - 6 * s, gy + gh, pw + 12 * s, 30 * s), pc, 3.0, 0.25)
		HomeKit.glow_rect(board, Rect2(x, bot_y, pw, ground_y - bot_y), pc, 3.0, 0.0)
	# Ground: a long neon pipe with joints, over a dark floor.
	board.draw_rect(Rect2(0, ground_y, w, board.size.y - ground_y), Color(0.05, 0.02, 0.1))
	var ph := 46.0 * s
	board.draw_rect(Rect2(0, ground_y, w, ph), Color(0.12, 0.04, 0.22))
	HomeKit.glow_line(board, Vector2(0, ground_y), Vector2(w, ground_y), HomeKit.MAGENTA, 3.0)
	HomeKit.glow_line(board, Vector2(0, ground_y + ph), Vector2(w, ground_y + ph), HomeKit.CYAN, 2.0)
	board.draw_line(Vector2(0, ground_y + ph * 0.3), Vector2(w, ground_y + ph * 0.3), Color(1, 1, 1, 0.18), 2.0)
	var joint := -fmod(engine.scroll * s, 150.0 * s)
	while joint < w:
		board.draw_rect(Rect2(joint, ground_y - 3 * s, 14 * s, ph + 6 * s), Color(HomeKit.PINK, 0.8))
		joint += 150.0 * s
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
	HomeKit.glow_polyline(board, PackedVector2Array([Vector2(-r * 0.2, r * 0.1), Vector2(-r * 0.95, -r * 0.35 if engine.vel < 0 else r * 0.55), Vector2(-r * 0.55, r * 0.3)]), HomeKit.CYAN, 2.5, true)
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
		"art": "res://games/bird_hop/landing_bg.jpg",
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
		SoundLib.play(self, "impact/soft_medium", -8.0)
	engine.flap()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## The hub's shared music library (Music autoload, apps from v0.33; older
## ones play no music).
func _music(style: String) -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play(style, self, 0, 1.5)
