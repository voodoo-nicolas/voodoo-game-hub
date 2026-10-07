extends Control

## Barrel Climb: run, jump and climb up six girders while the Bone King
## rolls barrels down at you; free the voodoo doll at the top.

const BcEngine = preload("res://scripts/games/barrel_climb/barrel_climb_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/barrel_climb/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/barrel_climb/barrel_climb_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://barrel_climb_save.json"

const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const HERO := Color("29e6ff")
const GIRDER := Color("ff2bd6")
const LADDER := Color("3a8cff")
const BARREL := Color("ffae2b")
const KING := Color("9b4dff")
const DOLL := Color("ff4f9a")
const PAUSE_AFTER := 1.6

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var move_l := false
var move_r := false
var up := false
var down := false
var jump_queued := false
var after: float = 0.0
var banner := ""
var anim_t: float = 0.0
var sparks: Array = []  # [pos, vel, life, color]

var field: Control
var score_label: Label
var hud_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/barrel_climb/barrel_climb_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = BcEngine.new()
	_build_ui()
	engine.reset(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
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
	hud_label.custom_minimum_size = Vector2(170, 64)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hud_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", HERO.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(HERO, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	bar.add_child(spacer)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_left", 6)
	fm.add_theme_constant_override("margin_right", 6)
	root.add_child(fm)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.draw.connect(_draw_field)
	field.resized.connect(field.queue_redraw)
	fm.add_child(field)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 28)
	cm.add_theme_constant_override("margin_top", 6)
	cm.add_theme_constant_override("margin_left", 10)
	cm.add_theme_constant_override("margin_right", 10)
	root.add_child(cm)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	cm.add_child(controls)
	for spec in [["◀", "left"], ["▶", "right"], ["▲", "up"], ["▼", "down"], ["⤒", "jump"]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(112 if spec[1] != "jump" else 150, 104)
		b.add_theme_font_size_override("font_size", 44)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("sfx", "")
		b.button_down.connect(_hold.bind(spec[1], true))
		b.button_up.connect(_hold.bind(spec[1], false))
		if spec[1] == "jump":
			HomeKit.style_button(b, BARREL)
		controls.add_child(b)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in DIFF_NAMES.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "diff",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": GIRDER,
		"solo_heading": "Play",
		"subtitle": "The Bone King has the doll. Dodge the barrels, climb to the top.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # beside the score, above the King
	add_child(drawer)

func _hold(what: String, on: bool) -> void:
	match what:
		"left":
			move_l = on
		"right":
			move_r = on
		"up":
			up = on
		"down":
			down = on
		"jump":
			if on:
				jump_queued = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				move_l = event.pressed
			KEY_RIGHT, KEY_D:
				move_r = event.pressed
			KEY_UP, KEY_W:
				up = event.pressed
			KEY_DOWN, KEY_S:
				down = event.pressed
			KEY_SPACE:
				if event.pressed:
					jump_queued = true

# ---------- game flow ----------

func _new_game(d: int) -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset(d)
	_begin()

func _restart() -> void:
	_new_game(engine.diff)

func _begin() -> void:
	started = true
	after = 0.0
	banner = ""
	sparks.clear()
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Level %d") % engine.level + "\n" + "♥".repeat(maxi(0, engine.lives))

func _process(delta: float) -> void:
	anim_t += delta
	if not started:
		return
	delta = minf(delta, 0.05)
	for s in sparks:
		s[0] += s[1] * delta
		s[1].y += 500.0 * delta
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
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
	var move := (1 if move_r else 0) - (1 if move_l else 0)
	var vert := (1 if down else 0) - (1 if up else 0)
	var ev: Array = engine.step(delta, move, vert, jump_queued)
	jump_queued = false
	for e in ev:
		match e:
			"jump":
				_sfx("jump")
			"over":
				_sfx("pickup")
				if info:
					info.add("Barrels jumped")
			"smash":
				_sfx("explode")
				_burst(Vector2(engine.px + engine.facing * 24.0, engine.py - 30.0), BARREL)
				if info:
					info.add("Barrels smashed")
			"hammer":
				_sfx("powerup")
			"hit", "timeout":
				_sfx("lose")
				banner = tr("Ouch!") if e == "hit" else tr("Time's up!")
				_burst(Vector2(engine.px, engine.py - 18.0), HERO)
				after = PAUSE_AFTER
			"win":
				_sfx("win")
				banner = tr("Level clear! +%d") % engine.bonus
				after = PAUSE_AFTER + 0.6
				if info:
					info.add("Levels cleared")
					info.high("Highest level", engine.level + 1)
	if not ev.is_empty():
		_update_hud()
	field.queue_redraw()

func _burst(p: Vector2, col: Color) -> void:
	for i in 18:
		sparks.append([p, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 240) + Vector2(0, -120), randf_range(0.4, 0.9), col])

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Game over!") + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Level %d") % engine.level
	if info:
		info.add("Games played")
		info.high("Highest level", engine.level)
		info.high("Best score (%s)" % DIFF_NAMES[engine.diff], engine.score)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _geom() -> Dictionary:
	var k: float = minf(field.size.x / BcEngine.W, field.size.y / BcEngine.H)
	var o := (field.size - Vector2(BcEngine.W, BcEngine.H) * k) / 2.0
	return {"k": k, "o": o}

func _draw_field() -> void:
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var c := field
	c.draw_rect(Rect2(o, Vector2(BcEngine.W, BcEngine.H) * k), Color(0.02, 0.02, 0.05, 0.85))
	# Girders: a top and bottom rail with zig-zag bracing.
	for i in BcEngine.FLOORS + 1:
		_draw_girder(c, o, k, i)
	for l in engine.ladders:
		_draw_ladder(c, o, k, l)
	# Oil drum, bottom left.
	var drum := o + Vector2(26, BcEngine.y_at(0, 26) - 4) * k
	HomeKit.glow_rect(c, Rect2(drum + Vector2(-20, -50) * k, Vector2(40, 50) * k), LADDER, 2.0, 0.15)
	c.draw_line(drum + Vector2(-20, -34) * k, drum + Vector2(20, -34) * k, Color(LADDER, 0.6), 2.0)
	for f in 3:
		var fx := (f - 1) * 11.0
		var fh := 18.0 + sin(anim_t * 12.0 + f * 2.0) * 7.0
		HomeKit.glow_polyline(c, PackedVector2Array([drum + Vector2(fx - 6, -50) * k, drum + Vector2(fx, -50 - fh) * k, drum + Vector2(fx + 6, -50) * k]), BARREL, 1.6)
	# The doll at the top and the King.
	var dp := o + Vector2(420, BcEngine.y_at(BcEngine.GOAL, 420)) * k
	_draw_doll(c, dp, k)
	if fmod(anim_t, 2.0) < 1.2:
		HomeKit.glow_text(c, dp + Vector2(0, -78) * k, tr("Help!").to_upper(), int(24 * k), DOLL)
	_draw_king(c, o + Vector2(BcEngine.KING_X, BcEngine.y_at(BcEngine.FLOORS - 1, BcEngine.KING_X)) * k, k)
	if not engine.hammer.is_empty():
		var hp: Vector2 = o + Vector2(engine.hammer.x, BcEngine.y_at(engine.hammer.floor, engine.hammer.x) - 22) * k
		_draw_hammer(c, hp, k, -0.6 + sin(anim_t * 3.0) * 0.2)
	for b in engine.barrels:
		_draw_barrel(c, o + Vector2(b.x, b.y - BcEngine.BARREL_R) * k, k, b.spin, b.mode == "ladder")
	if engine.state != "dead" or fmod(anim_t, 0.2) < 0.1:
		_draw_hero(c, o + Vector2(engine.px, engine.py) * k, k)
	for s in sparks:
		var p: Vector2 = o + s[0] * k
		c.draw_line(p, p - s[1] * 0.03 * k, Color(s[3], clampf(s[2] * 2.0, 0.0, 1.0)), 2.0)
	# Bonus counter, top right.
	var font := ThemeDB.fallback_font
	var bx := o + Vector2(BcEngine.W - 150, 40) * k
	HomeKit.glow_rect(c, Rect2(bx, Vector2(136, 54) * k), HomeKit.LIME if engine.bonus > 1000 else HomeKit.PINK, 1.5, 0.08)
	c.draw_string(font, bx + Vector2(0, 20) * k, tr("Bonus").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 136 * k, int(16 * k), HomeKit.DIM)
	c.draw_string(font, bx + Vector2(0, 46) * k, str(engine.bonus), HORIZONTAL_ALIGNMENT_CENTER, 136 * k, int(26 * k), HomeKit.WHITE)
	if engine.hammer_t > 0.0:
		c.draw_string(font, o + Vector2(BcEngine.W - 150, 116) * k, "🔨 %d" % ceili(engine.hammer_t), HORIZONTAL_ALIGNMENT_CENTER, 136 * k, int(22 * k), BARREL)
	if banner != "":
		HomeKit.glow_text(c, o + Vector2(BcEngine.W / 2.0, BcEngine.H * 0.45) * k, banner, int(44 * k), HomeKit.LIME if engine.state == "won" else HomeKit.PINK)

func _draw_girder(c: CanvasItem, o: Vector2, k: float, i: int) -> void:
	var x0 := BcEngine.floor_x0(i)
	var x1 := BcEngine.floor_x1(i)
	var a := o + Vector2(x0, BcEngine.y_at(i, x0)) * k
	var b := o + Vector2(x1, BcEngine.y_at(i, x1)) * k
	var t := Vector2(0, 14) * k
	c.draw_colored_polygon(PackedVector2Array([a, b, b + t, a + t]), Color(GIRDER, 0.1))
	HomeKit.glow_line(c, a, b, GIRDER, 2.0)
	HomeKit.glow_line(c, a + t, b + t, GIRDER, 1.4)
	var n := int((x1 - x0) / 28.0)
	var zig := PackedVector2Array()
	for j in n + 1:
		var p := a.lerp(b, float(j) / n)
		zig.append(p + (t if j % 2 == 1 else Vector2.ZERO))
	c.draw_polyline(zig, Color(GIRDER, 0.55), 1.5, true)

func _draw_ladder(c: CanvasItem, o: Vector2, k: float, l: Dictionary) -> void:
	var top := BcEngine.y_at(l.hi, l.x) + 14.0
	var bottom := BcEngine.y_at(l.lo, l.x)
	for side in [-11.0, 11.0]:
		HomeKit.glow_line(c, o + Vector2(l.x + side, top) * k, o + Vector2(l.x + side, bottom) * k, LADDER, 1.6)
	var y := top + 10.0
	while y < bottom - 4.0:
		c.draw_line(o + Vector2(l.x - 11, y) * k, o + Vector2(l.x + 11, y) * k, Color(LADDER, 0.8), 2.0)
		y += 16.0

func _draw_barrel(c: CanvasItem, p: Vector2, k: float, spin: float, side_on: bool) -> void:
	var r := BcEngine.BARREL_R * k
	if side_on:
		# Coming down a ladder: seen from the side, a squat drum.
		HomeKit.glow_rect(c, Rect2(p - Vector2(r * 1.2, r * 0.9), Vector2(r * 2.4, r * 1.8)), BARREL, 1.8, 0.25)
		c.draw_line(p + Vector2(-r * 1.2, 0), p + Vector2(r * 1.2, 0), Color(BARREL, 0.8), 1.5)
		return
	c.draw_circle(p, r, Color(BARREL, 0.22))
	HomeKit.glow_circle(c, p, r, BARREL, 1.8)
	for j in 2:
		var d := Vector2.RIGHT.rotated(spin + j * PI / 2.0) * r * 0.8
		c.draw_line(p - d, p + d, Color(BARREL, 0.85), 1.5)

func _draw_hero(c: CanvasItem, feet: Vector2, k: float) -> void:
	var f: int = engine.facing
	var legs := sin(engine.walk_t * 14.0) * 7.0
	var hip := feet + Vector2(0, -15) * k
	var neck := feet + Vector2(0, -30) * k
	var head := feet + Vector2(0, -38) * k
	if engine.mode == "climb":
		HomeKit.glow_line(c, hip, feet + Vector2(-7, legs * 0.3) * k, HERO, 2.0)
		HomeKit.glow_line(c, hip, feet + Vector2(7, -legs * 0.3) * k, HERO, 2.0)
		HomeKit.glow_line(c, neck, neck + Vector2(-10, -10 + legs) * k, HERO, 2.0)
		HomeKit.glow_line(c, neck, neck + Vector2(10, -10 - legs) * k, HERO, 2.0)
	else:
		var air: bool = engine.mode == "air"
		HomeKit.glow_line(c, hip, feet + Vector2(legs if not air else 8, 0) * k, HERO, 2.0)
		HomeKit.glow_line(c, hip, feet + Vector2(-legs if not air else -6.0, -6.0 if air else 0.0) * k, HERO, 2.0)
		HomeKit.glow_line(c, neck, neck + Vector2(f * 10, 8 - (8 if air else 0)) * k, HERO, 2.0)
		HomeKit.glow_line(c, neck, neck + Vector2(-f * 8, 10) * k, HERO, 2.0)
	HomeKit.glow_line(c, hip, neck, HERO, 2.4)
	c.draw_circle(head, 7.0 * k, Color(HERO, 0.3))
	HomeKit.glow_circle(c, head, 7.0 * k, HERO, 1.8)
	c.draw_circle(head + Vector2(f * 3, -1) * k, 1.6 * k, HomeKit.WHITE)
	if engine.hammer_t > 0.0:
		var swing := -1.4 + absf(sin(anim_t * 10.0)) * 1.6
		_draw_hammer(c, neck + Vector2(f * 10, -4) * k + Vector2(f * 18, -16).rotated(swing * f) * k, k, swing * f)

func _draw_hammer(c: CanvasItem, p: Vector2, k: float, a: float) -> void:
	var d := Vector2(0, 16).rotated(a) * k
	HomeKit.glow_line(c, p, p + d, HomeKit.WHITE, 2.0)
	var hd := Vector2(10, 0).rotated(a) * k
	HomeKit.glow_line(c, p - hd, p + hd, BARREL, 5.0)

func _draw_king(c: CanvasItem, feet: Vector2, k: float) -> void:
	var bob := sin(anim_t * 4.0) * 3.0 * k
	var body := feet + Vector2(0, -46) * k + Vector2(0, bob)
	var pts := PackedVector2Array()
	for j in 12:
		var a := TAU * j / 12.0
		pts.append(body + Vector2(cos(a) * 34, sin(a) * 30) * k)
	c.draw_colored_polygon(pts, Color(KING, 0.15))
	HomeKit.glow_polyline(c, pts, KING, 2.2, true)
	var head := body + Vector2(0, -44) * k
	HomeKit.glow_circle(c, head, 22 * k, KING, 2.2, 0.15)
	for s in [-1, 1]:
		var e := head + Vector2(s * 8, -3) * k
		HomeKit.glow_line(c, e - Vector2(5, 5) * k, e + Vector2(5, 5) * k, HomeKit.PINK, 1.6)
		HomeKit.glow_line(c, e - Vector2(-5, 5) * k, e + Vector2(-5, 5) * k, HomeKit.PINK, 1.6)
		# Horns and arms (raised when a barrel is about to fly).
		HomeKit.glow_polyline(c, PackedVector2Array([head + Vector2(s * 14, -14) * k, head + Vector2(s * 26, -34) * k, head + Vector2(s * 20, -12) * k]), KING, 1.6)
		var arm_up := fmod(anim_t, 1.0) < 0.3
		HomeKit.glow_line(c, body + Vector2(s * 30, -12) * k, body + Vector2(s * 46, -40 if arm_up else 12) * k, KING, 2.2)
	for j in 5:
		c.draw_line(head + Vector2(-10 + j * 5, 10) * k, head + Vector2(-10 + j * 5, 15) * k, Color(KING, 0.9), 1.5)

func _draw_doll(c: CanvasItem, feet: Vector2, k: float) -> void:
	var head := feet + Vector2(0, -44) * k
	var body := PackedVector2Array([feet + Vector2(-14, -28) * k, feet + Vector2(14, -28) * k, feet + Vector2(10, -4) * k, feet + Vector2(-10, -4) * k])
	c.draw_colored_polygon(body, Color(DOLL, 0.15))
	HomeKit.glow_polyline(c, body, DOLL, 1.8, true)
	HomeKit.glow_circle(c, head, 13 * k, DOLL, 1.8, 0.15)
	for s in [-1, 1]:
		var e := head + Vector2(s * 5, -2) * k
		c.draw_line(e - Vector2(3, 3) * k, e + Vector2(3, 3) * k, HomeKit.WHITE, 1.4)
		c.draw_line(e - Vector2(-3, 3) * k, e + Vector2(-3, 3) * k, HomeKit.WHITE, 1.4)
		HomeKit.glow_line(c, feet + Vector2(s * 14, -26) * k, feet + Vector2(s * 24, -36 - sin(anim_t * 6.0) * 6) * k, DOLL, 1.6)
	HomeKit.glow_line(c, head + Vector2(6, -6) * k, head + Vector2(20, -22) * k, HomeKit.WHITE, 1.2)
	c.draw_circle(head + Vector2(20, -22) * k, 3 * k, HomeKit.GOLD)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 170.0, 1.3)
	var o := c.size / 2.0
	for i in 3:
		var y := -40.0 + i * 50.0
		var sl := 10.0 if i % 2 == 0 else -10.0
		var a := o + Vector2(-150, y - sl) * k
		var b := o + Vector2(150, y + sl) * k
		HomeKit.glow_line(c, a, b, GIRDER, 2.0)
		HomeKit.glow_line(c, a + Vector2(0, 9) * k, b + Vector2(0, 9) * k, GIRDER, 1.2)
	for x in [-60.0, 80.0]:
		var lx: float = o.x + x * k
		HomeKit.glow_line(c, Vector2(lx - 8 * k, o.y - 30 * k), Vector2(lx - 8 * k, o.y + 60 * k), LADDER, 1.4)
		HomeKit.glow_line(c, Vector2(lx + 8 * k, o.y - 30 * k), Vector2(lx + 8 * k, o.y + 60 * k), LADDER, 1.4)
	_draw_barrel(c, o + Vector2(40, -64) * k, k * 1.2, 0.5, false)
	_draw_barrel(c, o + Vector2(-100, 8) * k, k * 1.2, 1.2, false)
	_draw_king(c, o + Vector2(-110, -50) * k, k * 0.8)

# ---------- pause / save ----------

func _on_pause() -> void:
	move_l = false
	move_r = false
	up = false
	down = false
	home.pause()

func _go_home() -> void:
	home.go_home()

## Score, level and lives; Resume restarts the level from the bottom.
func _save_game() -> void:
	if not started or engine.state == "over":
		return
	var lives: int = engine.lives
	var level: int = engine.level
	if engine.state == "won":
		level += 1
	SaveUtil.write(SAVE_PATH, {"score": engine.score, "level": level, "lives": maxi(1, lives), "diff": engine.diff})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0)) + "   ·   " + tr("Level %d") % int(d.get("level", 1))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game(1)
		return
	engine.reset(int(d.get("diff", 1)))
	engine.score = int(d.get("score", 0))
	engine.level = maxi(1, int(d.get("level", 1)))
	engine.lives = clampi(int(d.get("lives", 3)), 1, 3)
	engine.new_level()
	_begin()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
