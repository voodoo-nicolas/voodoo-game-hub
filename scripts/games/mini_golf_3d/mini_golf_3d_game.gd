extends Control

## Mini Golf 3D: a 9-hole cartoon course floating over a sea of clouds
## (ramps, a windmill tunnel, loop-de-loops, sand, lily ponds). The 3D world
## (mini_golf_3d_world.gd) lives in a SubViewport; this script owns the HUD,
## the Landing kit, saving and stats. Drag down to pull back, sideways to aim,
## let go to putt.
## Landing menu style: S11 Sticker Board (docs/MENU_STYLES.md): playful and
## crafty, matching the candy cartoon course (last two new games used S1).
## Physics: the hub runs Godot Physics at 60 ticks; this game asks for 240
## while it is open (the ball stays on the loop's curve) and restores the
## old rate when it closes.

const Engine3 = preload("res://scripts/games/mini_golf_3d/mini_golf_3d_engine.gd")
const World = preload("res://scripts/games/mini_golf_3d/mini_golf_3d_world.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
const MenuStyles = preload("res://scripts/games/mini_golf_3d/menu_styles.gd")
## Home screen + pause menu, copied into this game's folder by `hub.py sync`.
const HomeKit = preload("res://scripts/games/mini_golf_3d/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/mini_golf_3d/mini_golf_3d_help.gd")
const SAVE_PATH := "user://mini_golf_3d_save.json"
const PHYSICS_TICKS := 240
const PINK := Color("ff6fa8")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var world
var started := false
var round_recorded := false
var old_ticks := 60
var skin := "classic"

var view: SubViewport
var hole_label: Label
var score_label: Label
var msg_label: Label
var power_bar: ProgressBar
var next_btn: Button
var msg_tw: Tween

func _ready() -> void:
	preload("res://scripts/games/mini_golf_3d/mini_golf_3d_i18n.gd").install(self)
	Orientation.lock_portrait()
	old_ticks = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS
	engine = Engine3.new()
	_build_ui()
	world.load_hole(0)
	_music("play", "calm", 1)

func _exit_tree() -> void:
	Engine.physics_ticks_per_second = old_ticks

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()

	# The 3D course fills the screen; the HUD floats on top.
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vc)
	vc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	vc.add_child(view)
	world = World.new()
	view.add_child(world)
	world.changed.connect(_update_hud)
	world.holed.connect(_on_holed)
	world.message.connect(_flash)

	# Touch layer: pull back anywhere to putt.
	var touch := Control.new()
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(world.handle_input)
	add_child(touch)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 24)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mid)
	hole_label = _outlined(30)
	mid.add_child(hole_label)
	score_label = _outlined(24)
	mid.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	var bottom := MarginContainer.new()
	bottom.add_theme_constant_override("margin_bottom", 40)
	bottom.add_theme_constant_override("margin_left", 60)
	bottom.add_theme_constant_override("margin_right", 60)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	power_bar = ProgressBar.new()
	power_bar.show_percentage = false
	power_bar.max_value = 1.0
	power_bar.custom_minimum_size = Vector2(0, 26)
	power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(power_bar)

	msg_label = _outlined(50)
	msg_label.add_theme_color_override("font_color", Color("ffe14f"))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(msg_label)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.offset_left = 24
	msg_label.offset_right = -24

	next_btn = Button.new()
	next_btn.custom_minimum_size = Vector2(360, 96)
	next_btn.add_theme_font_size_override("font_size", 34)
	next_btn.visible = false
	next_btn.pressed.connect(_next_hole)
	add_child(next_btn)
	next_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	next_btn.offset_left = -180
	next_btn.offset_right = 180
	next_btn.offset_top = -260
	next_btn.offset_bottom = -164

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		# Menu style (docs/MENU_STYLES.md): S11 Sticker Board; candy pink/orange/violet.
		"landing": "stickers",
		"landing_style": MenuStyles,
		"title_font": "res://games/mini_golf_3d/title.ttf",
		"title_colors": [Color("ff6fa8"), Color("ffb347"), Color("9b7bff")],
		"landing_colors": [Color("1c1030"), Color("2c1a48")],
		"menu_color": Color("ffb347"),
		# Own skins (_set_skin): the course is lit in 3D, the kit filter would flatten it.
		"help": HELP,
		"info": info,
		"accent": PINK,
		"subtitle": "Ramps, loops and a windmill tunnel, floating over the clouds.",
		"logo": _draw_home_logo,
		"modes": [{"text": "⛳  Play", "sub": "9 holes", "action": _new_game}],
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart_hole,
		"helps": [{"text": "↩ Mulligan", "how": "Takes your last putt back.", "action": _help_mulligan}],
		"board": "Birdies or better",
		"board_note": "Holes you finished under par, in any round.",
	})
	add_child(home)
	if info:
		add_child(info)
	add_child(SettingsDrawer.new())

func _outlined(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("2a1e3a"))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _draw_home_logo(c: Control) -> void:
	var s := c.size
	var k := minf(s.y / 170.0, 1.4)
	var o := s / 2.0
	# a candy loop-de-loop with a ball riding it, and a flag
	for i in 3:
		HomeKit.glow_circle(c, o + Vector2(-40, -5) * k, (52 - i * 2) * k, [PINK, Color("ffb347"), Color("9b7bff")][i], 2.5)
	c.draw_circle(o + Vector2(-40, -57) * k, 10 * k, Color.WHITE)
	var cup := o + Vector2(80, 45) * k
	c.draw_circle(cup, 11 * k, Color.BLACK)
	c.draw_line(cup, cup + Vector2(0, -80) * k, Color.WHITE, 3.0)
	c.draw_colored_polygon(PackedVector2Array([cup + Vector2(0, -80) * k, cup + Vector2(36, -68) * k, cup + Vector2(0, -56) * k]), Color("ff4f6d"))

# ---------- play ----------

func _new_game() -> void:
	engine.reset()
	started = true
	round_recorded = false
	_hide_overlays()
	world.load_hole(0)

func _restart_hole() -> void:
	_hide_overlays()
	world.load_hole(engine.hole() if not engine.done() else 0)
	if engine.done():
		engine.reset()
		round_recorded = false
	started = true

func _hide_overlays() -> void:
	next_btn.visible = false
	msg_label.text = ""

func _on_holed(strokes: int) -> void:
	var par: int = Engine3.HOLES[engine.hole()].par
	engine.record(strokes)
	_sfx("pickup")
	if info:
		if strokes == 1:
			info.add("Holes in one")
		if strokes < par:
			info.add("Birdies or better")
	var txt := tr(Engine3.score_name(strokes, par))
	if engine.done():
		txt += "\n\n" + tr("Course done!") + "\n" + tr("%d strokes (par %d)") % [engine.total(), Engine3.course_par()]
		next_btn.text = tr("Play again")
		_record_round()
		SaveUtil.delete(SAVE_PATH)
	else:
		next_btn.text = tr("Next hole") + "  ▶"
	if msg_tw and msg_tw.is_valid():
		msg_tw.kill()
	msg_label.text = txt
	next_btn.visible = true
	_update_hud()

func _record_round() -> void:
	if round_recorded or not info:
		return
	round_recorded = true
	info.add("Rounds played")
	info.low("Best round", engine.total())
	info.result("win" if engine.total() <= Engine3.course_par() else "loss")

func _next_hole() -> void:
	_hide_overlays()
	if engine.done():
		_new_game()
		return
	world.load_hole(engine.hole())
	_save_game()

func _flash(text: String) -> void:
	_sfx("invalid")
	msg_label.text = tr(text)
	if msg_tw and msg_tw.is_valid():
		msg_tw.kill()
	msg_tw = create_tween()
	msg_tw.tween_interval(1.3)
	msg_tw.tween_callback(_clear_flash)

func _clear_flash() -> void:
	if not next_btn.visible:
		msg_label.text = ""

func _update_hud() -> void:
	var h: int = mini(engine.hole(), Engine3.HOLES.size() - 1)
	if engine.done():
		h = Engine3.HOLES.size() - 1
	var hd: Dictionary = Engine3.HOLES[h]
	hole_label.text = tr("Hole %d/%d") % [h + 1, Engine3.HOLES.size()] + "  " + tr(hd.name)
	var vs: int = engine.total() - engine.par_so_far()
	score_label.text = tr("Par %d") % int(hd.par) + "   " + tr("Strokes %d") % world.strokes + "   " + tr("Total %s") % ("%+d" % vs if vs != 0 else "E")
	power_bar.value = world.power
	power_bar.visible = world.dragging
	if world.strokes >= Engine3.MAX_STROKES and not world.sunk and world.at_rest():
		# picked up: counts as MAX_STROKES + 1
		world.sunk = true
		_on_holed(Engine3.MAX_STROKES + 1)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_LEFT or e.keycode == KEY_A:
			world.turn(-0.1)
		elif e.keycode == KEY_RIGHT or e.keycode == KEY_D:
			world.turn(0.1)

# ---------- pause / save ----------

func _on_pause() -> void:
	world.cancel_drag()
	_save_game()
	home.pause()

## The round so far, and where the ball lies (between holes: the next tee).
func _save_game() -> void:
	if not started or engine.done():
		return
	var d := {"scores": engine.scores, "strokes": world.strokes, "yaw": world.aim_yaw}
	if world.sunk:
		d.strokes = 0
		d.yaw = PI
	else:
		var p: Vector3 = world.last_rest
		d["pos"] = [p.x, p.y, p.z]
	SaveUtil.write(SAVE_PATH, d)

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	return tr("Hole %d/%d") % [int((d.get("scores", []) as Array).size()) + 1, Engine3.HOLES.size()]

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("scores"):
		_new_game()
		return
	engine.reset()
	for s in d.scores:
		engine.record(int(s))
	if engine.done():
		_new_game()
		return
	started = true
	round_recorded = false
	_hide_overlays()
	world.load_hole(engine.hole())
	if d.has("pos"):
		world.place(Vector3(float(d.pos[0]), float(d.pos[1]), float(d.pos[2])), int(d.get("strokes", 0)), float(d.get("yaw", PI)))

# ---------- skins ----------

## Classic: a sunny pastel sky. Voodoo: the same course by moonlight.
func _set_skin(name_: String) -> void:
	skin = name_
	if world:
		world.set_skin(skin)

func _current_skin() -> String:
	return skin

# ---------- helps (STANDARDS §17) ----------

## ↩ help: the last putt never happened.
func _help_mulligan() -> bool:
	if not started or world.sunk:
		return false
	return world.mulligan()

# ---------- shared systems (guarded: APK-side) ----------

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	if what == "play":
		m.play(style, self, index, fade)
