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
const SoundLib = preload("res://scripts/games/barrel_climb/sound_lib.gd")
const SAVE_PATH := "user://barrel_climb_save.json"

const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const HERO := Color("29e6ff")
const GIRDER := Color("ff2bd6")
const LADDER := Color("3a8cff")
const BARREL := Color("ffae2b")
const KING := Color("9b4dff")
const DOLL := Color("ff4f9a")
const PAUSE_AFTER := 1.6
## The Landing picture's night scaffold: wood, rope, torchlight, a purple ogre.
const WOOD := Color("6b4426")
const WOOD_LIGHT := Color("a8743a")
const WOOD_DARK := Color("3a2414")
const ROPE := Color("c9a46a")
const FLAME := Color("ffb23a")
const OGRE := Color("7a34b8")
const HELMET := Color("3aa0ff")
const SHIRT := Color("e03a3a")
const PANTS := Color("2a56c8")
const SKIN := Color("f0b890")

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
var stars: Array = []
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
	_music("lively")

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

	if ResourceLoader.exists(PAD_PATH):
		controls.visible = false                    # the shared Pad draws the stick and the button
		cm.custom_minimum_size = Vector2(0, PAD_ROOM)
	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)
	if ResourceLoader.exists(PAD_PATH):
		_add_pad()

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
		"art": "res://games/barrel_climb/landing_bg.jpg",
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

## The shared Pad (scripts/common/pad/, docs/claude/pad.md). Older apps do not have it and keep the
## on-screen buttons below.
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"
const PAD_ROOM := 285.0        # height kept free under the playfield for the Pad's stick + button
var touch_pad: Control = null
var _pad_dirs := {"l": false, "r": false, "u": false, "d": false}

func _add_pad() -> void:
	touch_pad = load(PAD_PATH).new()
	touch_pad.layout_override = "stick_4"
	touch_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_pad)
	for part in ["b", "x", "y", "pause", "info"]:
		touch_pad.set_hidden(part, true)   # run, climb and jump
	touch_pad.set_state("a", {"glyph": "jump", "sub": tr("Jump")})
	touch_pad.button_pressed.connect(_on_pad_button)

func _on_pad_button(id: String) -> void:
	if id == "a":
		jump_queued = true

## The stick presses left / right / up / down like the keys do (written only when it changes, so the
## keyboard still works); the Pad shows only while a round is on.
func _pad_tick() -> void:
	if touch_pad == null:
		return
	touch_pad.visible = started and not end_dialog.visible
	var v: Vector2 = touch_pad.get_vector("move")
	var now := {"l": v.x < -0.35, "r": v.x > 0.35, "u": v.y < -0.45, "d": v.y > 0.45}
	if now.l != _pad_dirs.l:
		move_l = now.l
	if now.r != _pad_dirs.r:
		move_r = now.r
	if now.u != _pad_dirs.u:
		up = now.u
	if now.d != _pad_dirs.d:
		down = now.d
	_pad_dirs = now

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
	_pad_tick()
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
			"combo":
				_sfx("powerup")
			"over":
				_sfx("pickup")
				if info:
					info.add("Barrels jumped")
			"throw":
				SoundLib.play(self, "impact/wood_heavy", -8.0)
			"land":
				SoundLib.play(self, "impact/wood_light", -12.0)
			"smash":
				SoundLib.play(self, "impact/wood_heavy")
				_burst(Vector2(engine.px + engine.facing * 24.0, engine.py - 30.0), BARREL)
				if info:
					info.add("Barrels smashed")
			"hammer":
				_sfx("powerup")
			"hit", "timeout":
				SoundLib.play(self, "impact/punch_heavy")
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
	_draw_backdrop(c, o, k)
	# Girders: a top and bottom rail with zig-zag bracing.
	for i in BcEngine.FLOORS + 1:
		_draw_girder(c, o, k, i)
	for l in engine.ladders:
		_draw_ladder(c, o, k, l)
	_draw_torches(c, o, k)
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
		_draw_barrel(c, o + Vector2(b.x, b.y - BcEngine.BARREL_R) * k, k, b.spin, b.mode == "ladder", b.get("fast", false))
	for fb in engine.fireballs:
		_draw_fireball(c, o + Vector2(fb.x, fb.y) * k, k)
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

func _draw_backdrop(c: CanvasItem, o: Vector2, k: float) -> void:
	var sz := Vector2(BcEngine.W, BcEngine.H) * k
	var bands := 14
	for i in bands:
		var t := float(i) / (bands - 1)
		c.draw_rect(Rect2(o + Vector2(0, sz.y * i / bands), Vector2(sz.x, sz.y / bands + 1.0)), Color("0a1030").lerp(Color("1c2a5a"), t))
	if stars.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 9
		for i in 40:
			stars.append([r.randf(), r.randf() * 0.55, r.randf() * TAU])
	for st in stars:
		var tw := 0.4 + 0.6 * absf(sin(anim_t * 1.5 + st[2]))
		c.draw_rect(Rect2(o + Vector2(st[0] * sz.x, st[1] * sz.y), Vector2(2, 2) * maxf(k, 1.0)), Color(0.85, 0.92, 1.0, 0.3 + 0.5 * tw))
	# A crescent moon.
	var mp := o + Vector2(sz.x * 0.82, sz.y * 0.1)
	c.draw_circle(mp, 30.0 * k, Color("cfe8ff"))
	c.draw_circle(mp + Vector2(12, -6) * k, 27.0 * k, Color("0e1640"))
	# Mountains and a far town with lit windows.
	var ridge := PackedVector2Array([o + Vector2(0, 800) * k, o + Vector2(120, 700) * k, o + Vector2(260, 770) * k, o + Vector2(400, 690) * k,
			o + Vector2(560, 760) * k, o + Vector2(720, 710) * k, o + Vector2(720, 1040) * k, o + Vector2(0, 1040) * k])
	c.draw_colored_polygon(ridge, Color("0b1233"))
	for i in 26:
		var tx := 30.0 + i * 26.0
		var ty := 900.0 + sin(i * 12.9) * 40.0
		c.draw_rect(Rect2(o + Vector2(tx, ty) * k, Vector2(3, 3) * k), Color(FLAME, 0.5 + 0.3 * sin(anim_t * 2.0 + i)))

func _draw_torches(c: CanvasItem, o: Vector2, k: float) -> void:
	for tp in [[24.0, 1], [696.0, 2], [24.0, 3], [696.0, 4]]:
		var base: Vector2 = o + Vector2(tp[0], BcEngine.y_at(tp[1], tp[0]) - 6) * k
		c.draw_line(base, base + Vector2(0, -44) * k, WOOD_LIGHT, 4.0 * k)
		var fl := 1.0 + 0.25 * sin(anim_t * 14.0 + tp[0] + tp[1] * 3.0)
		var tip := base + Vector2(0, -46) * k
		c.draw_circle(tip, 46.0 * k * fl, Color(FLAME, 0.1))
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-8, 0) * k, tip + Vector2(0, -26 * fl) * k, tip + Vector2(8, 0) * k]), FLAME)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, 0) * k, tip + Vector2(0, -14 * fl) * k, tip + Vector2(4, 0) * k]), Color("fff0a0"))

func _draw_girder(c: CanvasItem, o: Vector2, k: float, i: int) -> void:
	var x0 := BcEngine.floor_x0(i)
	var x1 := BcEngine.floor_x1(i)
	var a := o + Vector2(x0, BcEngine.y_at(i, x0)) * k
	var b := o + Vector2(x1, BcEngine.y_at(i, x1)) * k
	var t := Vector2(0, 14) * k
	# Supports first (behind the planks): posts every ~140 units and a cross brace.
	var n := maxi(1, int((x1 - x0) / 140.0))
	for j in n + 1:
		var f := float(j) / n
		var top := a.lerp(b, f) + t
		c.draw_line(top, top + Vector2(0, 90) * k, WOOD_DARK, 6.0 * k)
		if j < n:
			var nxt := a.lerp(b, float(j + 1) / n) + t
			c.draw_line(top, nxt + Vector2(0, 70) * k, Color(WOOD_DARK, 0.8), 3.0 * k)
	c.draw_colored_polygon(PackedVector2Array([a, b, b + t, a + t]), WOOD)
	c.draw_line(a, b, WOOD_LIGHT, 3.0 * k)
	c.draw_line(a + t, b + t, WOOD_DARK, 2.0 * k)
	var np := int((x1 - x0) / 30.0)
	for j in np + 1:
		var p := a.lerp(b, float(j) / np)
		c.draw_line(p, p + t, Color(WOOD_DARK, 0.7), 1.5 * k)

func _draw_ladder(c: CanvasItem, o: Vector2, k: float, l: Dictionary) -> void:
	var top := BcEngine.y_at(l.hi, l.x) + 14.0
	var bottom := BcEngine.y_at(l.lo, l.x)
	for side in [-11.0, 11.0]:
		c.draw_line(o + Vector2(l.x + side, top) * k, o + Vector2(l.x + side, bottom) * k, ROPE, 3.0 * k)
	var y := top + 10.0
	while y < bottom - 4.0:
		c.draw_line(o + Vector2(l.x - 11, y) * k, o + Vector2(l.x + 11, y) * k, WOOD_LIGHT, 3.0 * k)
		y += 16.0

func _draw_barrel(c: CanvasItem, p: Vector2, k: float, spin: float, side_on: bool, fast: bool = false) -> void:
	var r := BcEngine.BARREL_R * k
	if side_on:
		# Coming down a ladder: seen from the side, a squat wooden drum.
		var rc := Rect2(p - Vector2(r * 1.2, r * 0.9), Vector2(r * 2.4, r * 1.8))
		c.draw_rect(rc, WOOD_LIGHT)
		c.draw_rect(rc, WOOD_DARK, false, 1.5 * k)
		c.draw_line(p + Vector2(-r * 1.2, -r * 0.45), p + Vector2(r * 1.2, -r * 0.45), Color("8a94a8"), 2.0 * k)
		c.draw_line(p + Vector2(-r * 1.2, r * 0.45), p + Vector2(r * 1.2, r * 0.45), Color("8a94a8"), 2.0 * k)
		return
	c.draw_circle(p, r + 1.5 * k, WOOD_DARK)
	c.draw_circle(p, r, Color("c8402a") if fast else WOOD_LIGHT)   # fast barrels are red
	c.draw_circle(p, r * 0.62, Color("902a1a") if fast else Color("8a5a2b"))
	if fast:
		c.draw_line(p + Vector2(-r * 2.2, 0), p + Vector2(-r * 1.2, 0), Color(FLAME, 0.6), 2.0 * k)
	for j in 2:
		var d := Vector2.RIGHT.rotated(spin + j * PI / 2.0) * r * 0.95
		c.draw_line(p - d, p + d, Color(WOOD_DARK, 0.9), 1.6 * k)
	c.draw_circle(p, r * 0.18, Color("8a94a8"))

func _draw_hero(c: CanvasItem, feet: Vector2, k: float) -> void:
	var f: int = engine.facing
	var legs := sin(engine.walk_t * 14.0) * 7.0
	var hip := feet + Vector2(0, -15) * k
	var neck := feet + Vector2(0, -30) * k
	var head := feet + Vector2(0, -38) * k
	var lw := 4.0 * k
	if engine.mode == "climb":
		c.draw_line(hip, feet + Vector2(-7, legs * 0.3) * k, PANTS, lw)
		c.draw_line(hip, feet + Vector2(7, -legs * 0.3) * k, PANTS, lw)
		c.draw_line(neck, neck + Vector2(-10, -10 + legs) * k, SKIN, 3.0 * k)
		c.draw_line(neck, neck + Vector2(10, -10 - legs) * k, SKIN, 3.0 * k)
	else:
		var air: bool = engine.mode == "air"
		c.draw_line(hip, feet + Vector2(legs if not air else 8, 0) * k, PANTS, lw)
		c.draw_line(hip, feet + Vector2(-legs if not air else -6.0, -6.0 if air else 0.0) * k, PANTS, lw)
		c.draw_line(neck, neck + Vector2(f * 10, 8 - (8 if air else 0)) * k, SKIN, 3.0 * k)
		c.draw_line(neck, neck + Vector2(-f * 8, 10) * k, SKIN, 3.0 * k)
	c.draw_line(hip, neck, SHIRT, 8.0 * k)
	c.draw_circle(head, 7.0 * k, SKIN)
	c.draw_circle(head + Vector2(f * 3, -1) * k, 1.4 * k, Color(0.05, 0.05, 0.1))
	# Blue helmet.
	c.draw_colored_polygon(PackedVector2Array([head + Vector2(-8, -1) * k, head + Vector2(-6, -8) * k, head + Vector2(0, -10) * k, head + Vector2(6, -8) * k, head + Vector2(8, -1) * k]), HELMET)
	c.draw_line(head + Vector2(-8, -1) * k, head + Vector2(8 + f * 3, -1) * k, Color("1a60b0"), 2.0 * k)
	if engine.hammer_t > 0.0:
		var swing := -1.4 + absf(sin(anim_t * 10.0)) * 1.6
		_draw_hammer(c, neck + Vector2(f * 10, -4) * k + Vector2(f * 18, -16).rotated(swing * f) * k, k, swing * f)

func _draw_hammer(c: CanvasItem, p: Vector2, k: float, a: float) -> void:
	var d := Vector2(0, 16).rotated(a) * k
	c.draw_line(p, p + d, WOOD_LIGHT, 3.0 * k)
	var hd := Vector2(10, 0).rotated(a) * k
	c.draw_line(p - hd, p + hd, Color("b8c0d0"), 7.0 * k)

func _draw_king(c: CanvasItem, feet: Vector2, k: float) -> void:
	var bob := sin(anim_t * 4.0) * 3.0 * k
	var body := feet + Vector2(0, -46) * k + Vector2(0, bob)
	var pts := PackedVector2Array()
	for j in 12:
		var a := TAU * j / 12.0
		pts.append(body + Vector2(cos(a) * 36, sin(a) * 32) * k)
	c.draw_colored_polygon(pts, OGRE)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), OGRE.lightened(0.35), 2.0 * k, true)
	var head := body + Vector2(0, -44) * k
	c.draw_circle(head, 22 * k, OGRE.lightened(0.1))
	for s in [-1, 1]:
		var e := head + Vector2(s * 8, -3) * k
		c.draw_circle(e, 4.0 * k, Color("ffe23a"))
		c.draw_circle(e + Vector2(0, 1) * k, 1.6 * k, Color(0.1, 0.0, 0.1))
		# Horns, tusks and arms (raised when a barrel is about to fly).
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(s * 12, -14) * k, head + Vector2(s * 26, -36) * k, head + Vector2(s * 20, -10) * k]), Color("f0e6c8"))
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(s * 8, 8) * k, head + Vector2(s * 11, 18) * k, head + Vector2(s * 4, 10) * k]), Color("f4f0e0"))
		var arm_up: bool = engine.throw_warn() or fmod(anim_t, 1.0) < 0.15   # arms go up just before a throw
		c.draw_line(body + Vector2(s * 30, -12) * k, body + Vector2(s * 46, -40 if arm_up else 12) * k, OGRE.darkened(0.1), 11.0 * k)
	c.draw_line(head + Vector2(-8, 11) * k, head + Vector2(8, 11) * k, Color(0.15, 0.0, 0.15), 3.0 * k)

## A wandering fireball: a flickering flame with a hot white core.
func _draw_fireball(c: CanvasItem, feet: Vector2, k: float) -> void:
	var fl := 1.0 + 0.2 * sin(anim_t * 18.0 + feet.x)
	var ctr := feet + Vector2(0, -12) * k
	c.draw_circle(ctr, 22.0 * k, Color(FLAME, 0.15))
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-11, 4) * k, ctr + Vector2(-6, -8) * k, ctr + Vector2(0, -26 * fl) * k, ctr + Vector2(7, -8) * k, ctr + Vector2(11, 4) * k, ctr + Vector2(0, 12) * k]), Color("ff5a1a"))
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-6, 4) * k, ctr + Vector2(0, -14 * fl) * k, ctr + Vector2(6, 4) * k, ctr + Vector2(0, 9) * k]), FLAME)
	c.draw_circle(ctr + Vector2(0, 2) * k, 3.5 * k, Color("fff0a0"))
	for sd in [-1, 1]:
		c.draw_circle(ctr + Vector2(sd * 4, -1) * k, 1.3 * k, Color(0.15, 0.0, 0.0))

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

## The hub's shared music library (Music autoload, apps from v0.33; older
## ones play no music).
func _music(style: String) -> void:
	var m = get_node_or_null("/root/Music")
	if m:
		m.play(style, self, 0, 1.5)
