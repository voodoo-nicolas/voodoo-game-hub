extends Control

## Sky Hop: hold the left or right side of the screen to steer the bouncing
## hopper from platform to platform, as high as it can go.

const ShEngine = preload("res://scripts/games/sky_hop/sky_hop_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/sky_hop/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/sky_hop/sky_hop_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://sky_hop_save.json"

const KIND_COLORS := {"plain": Color("29e6ff"), "move": Color("9b4dff"), "crumble": Color("ff4f9a"), "spring": Color("7dff3a")}
const HOPPER := Color("ffae2b")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var steer: float = 0.0
var key_steer: float = 0.0
var squash: float = 0.0
var face: float = 1.0

var field: Control
var score_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/sky_hop/sky_hop_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = ShEngine.new()
	_build_ui()
	engine.reset()

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
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.add_theme_color_override("font_color", HOPPER.lerp(Color.WHITE, 0.6))
	score_label.add_theme_color_override("font_outline_color", Color(HOPPER, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_bottom", 20)
	root.add_child(fm)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	field.resized.connect(field.queue_redraw)
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
		"accent": HOPPER,
		"subtitle": "Bounce up and up. Hold a side of the screen to steer.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "How high can you hop?", "action": _new_game}],
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
	drawer.set("default_frac", 0.05)  # right of the score
	add_child(drawer)

# ---------- game flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset()
	started = true
	steer = 0.0
	end_dialog.visible = false
	score_label.text = "0"

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		steer = (-1.0 if event.position.x < field.size.x / 2.0 else 1.0) if event.pressed else 0.0
	elif event is InputEventMouseMotion and steer != 0.0:
		steer = -1.0 if event.position.x < field.size.x / 2.0 else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			key_steer = -1.0 if event.pressed else (0.0 if key_steer < 0.0 else key_steer)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			key_steer = 1.0 if event.pressed else (0.0 if key_steer > 0.0 else key_steer)

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.04)
	var s: float = steer if steer != 0.0 else key_steer
	if s != 0.0:
		face = s
	var ev: Array = engine.step(delta, s)
	squash = maxf(0.0, squash - delta * 4.0)
	for e in ev:
		match e:
			"bounce":
				squash = 0.35
				_sfx("jump")
			"spring":
				squash = 0.5
				_sfx("powerup")
			"crumble":
				_sfx("hit")
			"over":
				_game_over()
	score_label.text = str(engine.score())
	field.queue_redraw()

func _game_over() -> void:
	started = false
	steer = 0.0
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("You fell!") + "\n" + tr("Height: %d") % engine.score()
	if info:
		info.add("Games played")
		if info.high("Best score", engine.score()):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	_sfx("lose")
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _scale() -> float:
	return minf(field.size.x / ShEngine.WIDTH, field.size.y / ShEngine.VIEW_H)

func _to_screen(x: float, y: float) -> Vector2:
	var k := _scale()
	var ox := (field.size.x - ShEngine.WIDTH * k) / 2.0
	return Vector2(ox + x * k, field.size.y - (y - engine.cam) * k)

func _draw_field() -> void:
	var k := _scale()
	field.draw_rect(Rect2(Vector2.ZERO, field.size), Color(0.01, 0.015, 0.045))
	# Height marks every 100.
	var font := ThemeDB.fallback_font
	var mark: float = floor(engine.cam / 100.0) * 100.0
	while mark < engine.cam + ShEngine.VIEW_H * 1.2:
		var y := _to_screen(0, mark).y
		field.draw_line(Vector2(0, y), Vector2(field.size.x, y), Color(HomeKit.BLUE, 0.12), 1.0)
		field.draw_string(font, Vector2(6, y - 4), str(int(mark)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(HomeKit.DIM, 0.5))
		mark += 100.0
	for p in engine.platforms:
		if p.gone:
			continue
		var a := _to_screen(p.x, p.y)
		var b := _to_screen(p.x + ShEngine.PLAT_W, p.y)
		var col: Color = KIND_COLORS[p.kind]
		if p.kind == "crumble":
			for i in 3:
				var t0 := i / 3.0 + 0.03
				var t1 := (i + 1) / 3.0 - 0.03
				HomeKit.glow_line(field, a.lerp(b, t0), a.lerp(b, t1), col, k * 1.2)
		else:
			HomeKit.glow_line(field, a, b, col, k * 1.4)
		if p.kind == "spring":
			var m := a.lerp(b, 0.5)
			HomeKit.glow_polyline(field, PackedVector2Array([m + Vector2(-k * 2, 0), m + Vector2(-k, -k * 2), m + Vector2(k, -k), m + Vector2(k * 2, -k * 3)]), col, 1.5)
	var hp := _to_screen(engine.px, engine.py)
	_draw_hopper(field, hp, k, squash, face)
	# Also draw it on the other side while it wraps past an edge.
	if engine.px < 5.0:
		_draw_hopper(field, _to_screen(engine.px + ShEngine.WIDTH, engine.py), k, squash, face)
	elif engine.px > ShEngine.WIDTH - 5.0:
		_draw_hopper(field, _to_screen(engine.px - ShEngine.WIDTH, engine.py), k, squash, face)
	if started and engine.best < 20.0:
		field.draw_string(font, Vector2(0, field.size.y * 0.3), tr("Hold left or right to steer"), HORIZONTAL_ALIGNMENT_CENTER, field.size.x, 26, HomeKit.DIM)

func _draw_hopper(c: CanvasItem, feet: Vector2, k: float, sq: float, dir: float) -> void:
	var w := k * 4.5 * (1.0 + sq * 0.5)
	var h := k * 5.5 * (1.0 - sq * 0.4)
	var center := feet - Vector2(0, h)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * w, sin(a) * h))
	c.draw_colored_polygon(pts, Color(HOPPER, 0.25))
	HomeKit.glow_polyline(c, pts, HOPPER, 2.0, true)
	for sx in [-0.35, 0.35]:
		var e := center + Vector2(w * sx + dir * w * 0.15, -h * 0.2)
		c.draw_circle(e, k * 1.1, Color.WHITE)
		c.draw_circle(e + Vector2(dir * k * 0.4, 0), k * 0.5, Color(0.05, 0.05, 0.15))

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 32.0, 5.0)
	var o := c.size / 2.0
	for p in [[-14.0, 14.0, "plain"], [6.0, 2.0, "spring"], [-6.0, -12.0, "move"]]:
		HomeKit.glow_line(c, o + Vector2(p[0] * k, p[1] * k), o + Vector2((p[0] + 16.0) * k, p[1] * k), KIND_COLORS[p[2]], k * 1.3)
	_draw_hopper(c, o + Vector2(14 * k, -2 * k), k, 0.0, -1.0)
	for i in 3:
		c.draw_circle(o + Vector2((10 - i * 4) * k, (4 + i * 3) * k), k * 0.6, Color(HOPPER, 0.5 - i * 0.12))

# ---------- pause / save ----------

func _on_pause() -> void:
	steer = 0.0
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.over:
		return
	SaveUtil.write(SAVE_PATH, {"px": engine.px, "py": engine.py, "vy": engine.vy, "cam": engine.cam, "best": engine.best,
		"top": engine.top_y, "platforms": engine.platforms})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Height: %d") % int(d.get("best", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	_new_game()
	if d == null or d.get("platforms", []).is_empty():
		return
	engine.px = float(d.px)
	engine.py = float(d.py)
	engine.vy = float(d.vy)
	engine.cam = float(d.cam)
	engine.best = float(d.best)
	engine.top_y = float(d.top)
	engine.platforms = []
	for p in d.platforms:
		engine.platforms.append({"x": float(p.x), "y": float(p.y), "kind": str(p.kind), "dx": float(p.dx), "gone": bool(p.gone)})
	score_label.text = str(engine.score())

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
