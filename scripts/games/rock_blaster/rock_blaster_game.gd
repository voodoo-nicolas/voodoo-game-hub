extends Control

## Rock Blaster: tap anywhere to turn and shoot that way; hold to fly
## towards your finger (firing as you go). The field wraps at the edges.

const RbEngine = preload("res://scripts/games/rock_blaster/rock_blaster_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/rock_blaster/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/rock_blaster/rock_blaster_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://rock_blaster_save.json"

const HOLD_TIME := 0.16
const ROCK_COLORS := [Color("9b4dff"), Color("ff2bd6"), Color("ffae2b")]
const SHIP_COLOR := Color("29e6ff")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var touching := false
var touch_pos := Vector2.ZERO
var touch_time: float = 0.0
var tap_fire := false
var sparks: Array = []  # [pos, vel, life, colour]
var stars: Array = []

var field: Control
var score_label: Label
var hud_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/rock_blaster/rock_blaster_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = RbEngine.new()
	_build_ui()
	var r := RandomNumberGenerator.new()
	for i in 70:
		stars.append([Vector2(r.randf(), r.randf()), r.randf_range(0.5, 1.6)])

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
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hud_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", SHIP_COLOR.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(SHIP_COLOR, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_left", 8)
	fm.add_theme_constant_override("margin_right", 8)
	fm.add_theme_constant_override("margin_bottom", 16)
	root.add_child(fm)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	field.resized.connect(_on_field_resized)
	fm.add_child(field)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _new_game},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": SHIP_COLOR,
		"subtitle": "Tap to shoot, hold to fly. Split the rocks before they split you.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "3 ships · extra ship every 10,000", "action": _new_game}],
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
	drawer.set("default_frac", 0.05)  # right of the score, above the field
	add_child(drawer)

func _on_field_resized() -> void:
	if field.size.x > 0.0:
		engine.size = field.size
	field.queue_redraw()

# ---------- game flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(field.size if field.size.x > 0 else Vector2(704, 1000))
	started = true
	sparks.clear()
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Wave %d") % engine.wave + "\n" + "▲".repeat(maxi(0, engine.lives))

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touching = true
			touch_time = 0.0
			touch_pos = event.position
		else:
			if touching and touch_time < HOLD_TIME and engine.alive and not engine.over:
				# A quick tap: snap round and fire once that way.
				engine.ship_angle = (event.position - engine.ship_pos).angle()
				tap_fire = true
			touching = false
	elif event is InputEventMouseMotion and touching:
		touch_pos = event.position

func _process(delta: float) -> void:
	if not started or engine.over and sparks.is_empty():
		return
	delta = minf(delta, 0.05)
	if touching:
		touch_time += delta
	var holding := touching and touch_time >= HOLD_TIME
	var events: Array = engine.step(delta, touch_pos if holding else null, holding, holding or tap_fire)
	tap_fire = false
	for e in events:
		match e[0]:
			"shot":
				_sfx("shoot")
			"boom":
				_burst(e[1], ROCK_COLORS[e[2]] if e.size() > 2 else SHIP_COLOR, 14 - e[2] * 3)
				_sfx("explode" if e[2] == 0 else "hit")
			"hit":
				_sfx("lose")
			"wave":
				_sfx("powerup")
			"life":
				_sfx("record")
	for s in sparks:
		s[0] += s[1] * delta
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	if not events.is_empty():
		_update_hud()
	if engine.over and not end_dialog.visible and started:
		_game_over()
	field.queue_redraw()

func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 220.0)
		sparks.append([at, v, randf_range(0.3, 0.8), col])

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Game over!") + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Wave %d") % engine.wave
	if info:
		info.add("Games played")
		info.high("Highest wave", engine.wave)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _draw_field() -> void:
	var s := field.size
	field.draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.015, 0.04))
	for st in stars:
		field.draw_circle(st[0] * s, st[1], Color(1, 1, 1, 0.35))
	HomeKit.glow_rect(field, Rect2(Vector2.ZERO, s).grow(-1), Color(HomeKit.PURPLE, 0.5), 1.5)
	for r in engine.rocks:
		var rad: float = RbEngine.ROCK_R[r.s]
		var pts := PackedVector2Array()
		for p in r.shape:
			pts.append(r.p + p.rotated(r.rot) * rad)
		HomeKit.glow_polyline(field, pts, ROCK_COLORS[r.s], 2.0, true)
	for b in engine.bullets:
		field.draw_circle(b.p, 5.0, Color(SHIP_COLOR, 0.3))
		field.draw_circle(b.p, 2.6, Color.WHITE)
	for sp in sparks:
		field.draw_circle(sp[0], 2.0, Color(sp[3], clampf(sp[2] * 2.0, 0.0, 1.0)))
	if engine.alive and started and (engine.safe <= 0.0 or int(engine.safe * 8.0) % 2 == 0):
		_draw_ship(field, engine.ship_pos, engine.ship_angle, touching and touch_time >= HOLD_TIME)
	if touching and touch_time >= HOLD_TIME:
		field.draw_arc(touch_pos, 26, 0, TAU, 24, Color(SHIP_COLOR, 0.35), 2.0, true)

func _draw_ship(c: CanvasItem, p: Vector2, a: float, flame: bool) -> void:
	var r := RbEngine.SHIP_R * 1.5
	var pts := PackedVector2Array([p + Vector2(r, 0).rotated(a), p + Vector2(-r * 0.75, r * 0.65).rotated(a),
		p + Vector2(-r * 0.4, 0).rotated(a), p + Vector2(-r * 0.75, -r * 0.65).rotated(a)])
	c.draw_colored_polygon(pts, Color(SHIP_COLOR, 0.15))
	HomeKit.glow_polyline(c, pts, SHIP_COLOR, 2.2, true)
	if flame:
		var f := randf_range(0.8, 1.3)
		HomeKit.glow_polyline(c, PackedVector2Array([p + Vector2(-r * 0.55, r * 0.3).rotated(a),
			p + Vector2(-r * (0.9 + f * 0.6), 0).rotated(a), p + Vector2(-r * 0.55, -r * 0.3).rotated(a)]), HomeKit.GOLD, 2.0)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 3.2, 50.0)
	var o := c.size / 2.0
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for spot in [[Vector2(-2.0, -0.4), 1.0, 0], [Vector2(1.9, 0.5), 0.6, 1], [Vector2(0.9, -0.9), 0.35, 2]]:
		var pts := PackedVector2Array()
		for i in 10:
			pts.append(o + spot[0] * k + Vector2.RIGHT.rotated(TAU * i / 10.0) * k * spot[1] * r.randf_range(0.75, 1.05))
		HomeKit.glow_polyline(c, pts, ROCK_COLORS[spot[2]], 2.5, true)
	_draw_ship(c, o + Vector2(-0.1, 0.6) * k, -PI / 2.0 + 0.5, true)
	for i in 3:
		c.draw_circle(o + Vector2(0.15 + i * 0.22, 0.15 - i * 0.38) * k, 3.0, Color.WHITE)

# ---------- pause / save ----------

func _on_pause() -> void:
	touching = false
	home.pause()

func _go_home() -> void:
	home.go_home()

static func _v(v: Vector2) -> Array:
	return [v.x, v.y]

static func _p(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _save_game() -> void:
	if not started or engine.over:
		return
	var rocks: Array = []
	for r in engine.rocks:
		var shape: Array = []
		for p in r.shape:
			shape.append(_v(p))
		rocks.append({"p": _v(r.p), "v": _v(r.v), "s": r.s, "rot": r.rot, "spin": r.spin, "shape": shape})
	SaveUtil.write(SAVE_PATH, {"score": engine.score, "lives": engine.lives, "wave": engine.wave, "next_life": engine.next_life,
		"ship": _v(engine.ship_pos), "vel": _v(engine.ship_vel), "angle": engine.ship_angle, "alive": engine.alive,
		"rocks": rocks, "size": _v(engine.size)})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0)) + "   ·   " + tr("Wave %d") % int(d.get("wave", 1))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game()
		return
	_new_game()
	var old := _p(d.get("size", [engine.size.x, engine.size.y]))
	var k := Vector2(engine.size.x / maxf(1.0, old.x), engine.size.y / maxf(1.0, old.y))
	engine.score = int(d.get("score", 0))
	engine.lives = int(d.get("lives", 3))
	engine.wave = int(d.get("wave", 1))
	engine.next_life = int(d.get("next_life", RbEngine.EXTRA_LIFE_EVERY))
	engine.ship_pos = _p(d.get("ship", [0, 0])) * k
	engine.ship_vel = _p(d.get("vel", [0, 0]))
	engine.ship_angle = float(d.get("angle", -PI / 2.0))
	engine.safe = RbEngine.SAFE_TIME
	engine.rocks = []
	for r in d.get("rocks", []):
		var shape := PackedVector2Array()
		for p in r.get("shape", []):
			shape.append(_p(p))
		engine.rocks.append({"p": _p(r.p) * k, "v": _p(r.v), "s": int(r.s), "rot": float(r.rot), "spin": float(r.spin), "shape": shape})
	if engine.rocks.is_empty():
		engine.next_wave()
	_update_hud()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
