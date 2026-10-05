extends Control

## Moon Lander: hold ⟲ / ⟳ to tilt and 🔥 to fire the engine. Land gently
## and upright on a pad.

const MlEngine = preload("res://scripts/games/moon_lander/moon_lander_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/moon_lander/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/moon_lander/moon_lander_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://moon_lander_save.json"

const LANDER := Color("29e6ff")
const GROUND := Color("9b4dff")
const PAD := Color("7dff3a")
const SAFE := Color("7dff3a")
const DANGER := Color("ff4f9a")
const PAUSE_AFTER := 1.8

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var turn_left := false
var turn_right := false
var thrust := false
var after: float = 0.0
var banner := ""
var stars: Array = []
var debris: Array = []

var field: Control
var score_label: Label
var hud_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/moon_lander/moon_lander_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MlEngine.new()
	_build_ui()
	var r := RandomNumberGenerator.new()
	for i in 80:
		stars.append([Vector2(r.randf(), r.randf() * 0.6), r.randf_range(0.5, 1.6)])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	hud_label = Label.new()
	hud_label.custom_minimum_size = Vector2(150, 64)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hud_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", LANDER.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(LANDER, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	bar.add_child(spacer)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_left", 8)
	fm.add_theme_constant_override("margin_right", 8)
	root.add_child(fm)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.draw.connect(_draw_field)
	field.resized.connect(_on_field_resized)
	fm.add_child(field)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 30)
	cm.add_theme_constant_override("margin_top", 8)
	root.add_child(cm)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 18)
	cm.add_child(controls)
	for spec in [["⟲", "left", 150], ["🔥", "thrust", 230], ["⟳", "right", 150]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(spec[2], 110)
		b.add_theme_font_size_override("font_size", 48)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		b.button_down.connect(_hold.bind(spec[1], true))
		b.button_up.connect(_hold.bind(spec[1], false))
		controls.add_child(b)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": LANDER,
		"subtitle": "Gentle on the engine, gentle on the ground. Land on a pad.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "3 landers · new terrain every landing", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _new_game,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # right of the score, above the sky
	add_child(drawer)

func _on_field_resized() -> void:
	field.queue_redraw()

func _hold(what: String, on: bool) -> void:
	match what:
		"left":
			turn_left = on
		"right":
			turn_right = on
		"thrust":
			thrust = on

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.keycode:
			KEY_LEFT, KEY_A:
				turn_left = event.pressed
			KEY_RIGHT, KEY_D:
				turn_right = event.pressed
			KEY_UP, KEY_W, KEY_SPACE:
				thrust = event.pressed

# ---------- game flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(field.size if field.size.x > 0 else Vector2(704, 900))
	started = true
	after = 0.0
	banner = ""
	debris.clear()
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Level %d") % engine.level + "\n" + "▲".repeat(maxi(0, engine.landers))

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	for d in debris:
		d[0] += d[1] * delta
		d[1].y += engine.gravity() * delta
		d[2] -= delta
	debris = debris.filter(func(d): return d[2] > 0.0)
	if after > 0.0:
		after -= delta
		if after <= 0.0:
			engine.next()
			banner = ""
			if engine.state == "over":
				_game_over()
				return
			_update_hud()
		field.queue_redraw()
		return
	var turn := (1 if turn_right else 0) - (1 if turn_left else 0)
	var res: String = engine.step(delta, turn, thrust)
	if res == "landed":
		_sfx("win")
		banner = tr("Landed! +%d") % engine.landing_points()
		after = PAUSE_AFTER
		if info:
			info.add("Landings")
			if engine.last_pad.mult == 5:
				info.add("Landings on ×5 pads")
		_update_hud()
	elif res == "crashed":
		_sfx("explode")
		banner = tr("Crashed!")
		after = PAUSE_AFTER
		for i in 24:
			debris.append([engine.pos, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30, 160), randf_range(0.6, 1.6)])
		_update_hud()
	field.queue_redraw()

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Out of landers!") + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Level %d") % engine.level
	if info:
		info.add("Games played")
		info.high("Highest level", engine.level)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

## World -> field: the world was made for the field's size at the start.
func _k() -> Vector2:
	return field.size / engine.size

func _draw_field() -> void:
	var s := field.size
	field.draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.012, 0.04))
	for st in stars:
		field.draw_circle(st[0] * s, st[1], Color(1, 1, 1, 0.35))
	if engine.terrain.is_empty():
		return
	var k := _k()
	var pts := PackedVector2Array()
	for p in engine.terrain:
		pts.append(p * k)
	var fill := pts.duplicate()
	fill.append(Vector2(s.x, s.y))
	fill.append(Vector2(0, s.y))
	field.draw_colored_polygon(fill, Color(GROUND, 0.12))
	HomeKit.glow_polyline(field, pts, GROUND, 2.0)
	var font := ThemeDB.fallback_font
	for p in engine.pads:
		var a := Vector2(p.x0, p.y) * k
		var b := Vector2(p.x1, p.y) * k
		HomeKit.glow_line(field, a, b, PAD, 4.0)
		field.draw_string(font, Vector2(a.x, a.y + 30), "×%d" % p.mult, HORIZONTAL_ALIGNMENT_CENTER, b.x - a.x, 22, PAD)
	for d in debris:
		field.draw_circle(d[0] * k, 2.5, Color(HomeKit.GOLD, clampf(d[2], 0.0, 1.0)))
	if engine.state != "crashed" and engine.state != "over":
		_draw_lander(field, engine.pos * k, engine.angle, 1.0, thrust and engine.fuel > 0.0 and engine.state == "flying")
	# HUD: fuel, speeds (green when safe), altitude.
	var safe_vy: bool = engine.vel.y <= engine.safe_vy()
	var safe_vx: bool = absf(engine.vel.x) <= engine.safe_vx()
	var safe_a: bool = absf(engine.angle) <= engine.safe_tilt()
	var y := 26.0
	field.draw_rect(Rect2(14, y - 14, 160, 14), Color(1, 1, 1, 0.1))
	var fuel_k: float = engine.fuel / engine.max_fuel()
	field.draw_rect(Rect2(14, y - 14, 160 * clampf(fuel_k, 0.0, 1.0), 14), HomeKit.GOLD if fuel_k > 0.25 else DANGER)
	field.draw_string(font, Vector2(182, y), tr("Fuel"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, HomeKit.DIM)
	field.draw_string(font, Vector2(14, y + 28), tr("Down: %d") % int(engine.vel.y), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, SAFE if safe_vy else DANGER)
	field.draw_string(font, Vector2(14, y + 54), tr("Sideways: %d") % int(absf(engine.vel.x)), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, SAFE if safe_vx else DANGER)
	field.draw_string(font, Vector2(14, y + 80), tr("Tilt: %d°") % int(rad_to_deg(engine.angle)), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, SAFE if safe_a else DANGER)
	field.draw_string(font, Vector2(14, y + 106), tr("Height: %d") % int(engine.altitude()), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, HomeKit.DIM)
	if banner != "":
		HomeKit.glow_text(field, Vector2(s.x / 2.0, s.y * 0.33), banner, 40, SAFE if engine.state == "landed" else DANGER)

func _draw_lander(c: CanvasItem, p: Vector2, a: float, sc: float, flame: bool) -> void:
	var t := Transform2D(a, p)
	var body := PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(14, 4), Vector2(-14, 4)])
	var pts := PackedVector2Array()
	for v in body:
		pts.append(t * (v * sc))
	c.draw_colored_polygon(pts, Color(LANDER, 0.15))
	HomeKit.glow_polyline(c, pts, LANDER, 2.0, true)
	for side in [-1, 1]:
		HomeKit.glow_line(c, t * (Vector2(side * 10, 4) * sc), t * (Vector2(side * 16, 18) * sc), LANDER, 1.8)
		HomeKit.glow_line(c, t * (Vector2(side * 19, 18) * sc), t * (Vector2(side * 13, 18) * sc), LANDER, 1.8)
	c.draw_circle(t * (Vector2(0, -6) * sc), 4.0 * sc, Color(LANDER, 0.7))
	if flame:
		var f := randf_range(16.0, 30.0)
		HomeKit.glow_polyline(c, PackedVector2Array([t * (Vector2(-6, 6) * sc), t * (Vector2(0, 6 + f) * sc), t * (Vector2(6, 6) * sc)]), HomeKit.GOLD, 2.0)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.4, 46.0)
	var o := c.size / 2.0
	var ground := PackedVector2Array([o + Vector2(-k * 3.2, k * 1.4), o + Vector2(-k * 2.0, k * 0.6), o + Vector2(-k * 0.8, k * 1.2),
		o + Vector2(k * 0.8, k * 1.2), o + Vector2(k * 1.8, k * 0.3), o + Vector2(k * 3.2, k * 1.4)])
	HomeKit.glow_polyline(c, ground, GROUND, 2.0)
	HomeKit.glow_line(c, o + Vector2(-k * 0.8, k * 1.2), o + Vector2(k * 0.8, k * 1.2), PAD, 4.0)
	_draw_lander(c, o + Vector2(0, -k * 0.6), 0.15, k / 22.0, true)

# ---------- pause / save ----------

func _on_pause() -> void:
	turn_left = false
	turn_right = false
	thrust = false
	home.pause()

func _go_home() -> void:
	home.go_home()

## Score, level and landers left; Resume starts a fresh descent.
func _save_game() -> void:
	if not started or engine.state == "over":
		return
	SaveUtil.write(SAVE_PATH, {"score": engine.score, "level": engine.level + (1 if engine.state == "landed" else 0),
		"landers": engine.landers if engine.state != "crashed" or engine.landers > 0 else 1})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0)) + "   ·   " + tr("Level %d") % int(d.get("level", 1))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	_new_game()
	if d == null:
		return
	engine.score = int(d.get("score", 0))
	engine.level = maxi(1, int(d.get("level", 1)))
	engine.landers = maxi(1, int(d.get("landers", 3)))
	engine.new_terrain()
	_update_hud()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
