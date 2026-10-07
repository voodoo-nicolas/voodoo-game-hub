extends Control

## Star Runner: a neon rail shooter. Drag anywhere to steer; the ship
## fires on its own. Fly through rings, dodge towers and rocks, shoot
## down squadrons and beat the boss at the end of each stage.

const SrEngine = preload("res://scripts/games/star_runner/star_runner_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/star_runner/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/star_runner/star_runner_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://star_runner_save.json"

const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const SHIP := Color("29e6ff")
const ENEMY := Color("ff2bd6")
const ACE := Color("ff4f9a")
const ROCK := Color("3a8cff")
const RING := Color("7dff3a")
const SHOT := Color("ffae2b")
const LOOK_NAMES := {"planet": "Neon planet", "belt": "Rock belt", "space": "Deep space"}
const LOOK_COLORS := {"planet": Color("9b4dff"), "belt": Color("3a8cff"), "space": Color("ff2bd6")}
const Z0 := 2.0
const STEER := 1.25
const V_STRETCH := 1.6
const PAUSE_AFTER := 2.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var keys: Dictionary = {}
var after: float = 0.0
var banner := ""
var banner_t: float = 0.0
var sparks: Array = []        # [screen pos, vel, life, color]
var stars: Array = []         # [x, y, z]
var anim_t: float = 0.0

var field: Control
var score_label: Label
var hud_label: Label
var bomb_btn: Button
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/star_runner/star_runner_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SrEngine.new()
	engine.reset(1)
	for i in 90:
		stars.append([randf_range(-8, 8), randf_range(-6, 6), randf_range(1, 60)])
	_build_ui()

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
	score_label.add_theme_color_override("font_color", SHIP.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(SHIP, 0.5))
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
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	fm.add_child(field)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 26)
	cm.add_theme_constant_override("margin_top", 6)
	cm.add_theme_constant_override("margin_left", 16)
	cm.add_theme_constant_override("margin_right", 16)
	root.add_child(cm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	cm.add_child(row)
	var hint := HomeKit.label(tr("Drag anywhere to steer"), 22, HomeKit.DIM, true, true)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	bomb_btn = HomeKit.neon_button("", SHOT, 28, 88)
	bomb_btn.custom_minimum_size.x = 220
	bomb_btn.focus_mode = Control.FOCUS_NONE
	bomb_btn.set_meta("sfx", "")
	bomb_btn.pressed.connect(_on_bomb)
	row.add_child(bomb_btn)

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
		"accent": SHIP,
		"solo_heading": "Launch",
		"subtitle": "Full throttle through the neon. Steer, shoot, fly through the rings.",
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
	drawer.set("default_frac", 0.05)  # beside the score, above the field
	add_child(drawer)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]:
			if event.pressed:
				keys[event.keycode] = true
			else:
				keys.erase(event.keycode)
		elif event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_B):
			_on_bomb()

func _on_field_input(event: InputEvent) -> void:
	if not started or engine.state != "play":
		return
	var rel := Vector2.ZERO
	if event is InputEventScreenDrag:
		rel = event.relative
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		rel = event.relative
	else:
		return
	# Android also sends the mouse version of a touch drag: use one of them.
	if event is InputEventMouseMotion and DisplayServer.is_touchscreen_available():
		return
	engine.steer(rel / _unit() / Vector2(1.0, V_STRETCH) * STEER)

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
	sparks.clear()
	keys.clear()
	end_dialog.visible = false
	_stage_banner()
	_update_hud()

func _stage_banner() -> void:
	_show_banner(tr("Stage %d") % engine.stage + " · " + tr(LOOK_NAMES[engine.look()]))

func _show_banner(text: String, t: float = 2.2) -> void:
	banner = text
	banner_t = t

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Stage %d") % engine.stage + "\n" + "▲".repeat(maxi(0, engine.ships))
	bomb_btn.text = "💣 " + tr("Bomb") + " ×%d" % engine.bombs
	bomb_btn.disabled = engine.bombs <= 0

func _on_bomb() -> void:
	if started and engine.bomb():
		_sfx("explode")
		for i in 60:
			sparks.append([field.size / 2.0, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(200, 900), randf_range(0.4, 1.0), SHOT if i % 2 else HomeKit.WHITE])
		if info:
			info.add("Bombs used")
		_update_hud()

func _process(delta: float) -> void:
	anim_t += delta
	if not started:
		return
	delta = minf(delta, 0.05)
	banner_t = maxf(0.0, banner_t - delta)
	for s in sparks:
		s[0] += s[1] * delta
		s[1] *= 0.94
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	for st in stars:
		st[2] -= engine.speed * delta * (1.6 if engine.look() == "space" else 0.25)
		if st[2] < 0.5:
			st[2] += 60.0
	if after > 0.0:
		after -= delta
		if after <= 0.0:
			engine.next()
			if engine.state == "over":
				_game_over()
				return
			if engine.state == "play" and engine.stage_t == 0.0:
				_stage_banner()
			_update_hud()
		field.queue_redraw()
		return
	var kx := (1.0 if keys.has(KEY_RIGHT) or keys.has(KEY_D) else 0.0) - (1.0 if keys.has(KEY_LEFT) or keys.has(KEY_A) else 0.0)
	var ky := (1.0 if keys.has(KEY_DOWN) or keys.has(KEY_S) else 0.0) - (1.0 if keys.has(KEY_UP) or keys.has(KEY_W) else 0.0)
	if kx != 0.0 or ky != 0.0:
		engine.steer(Vector2(kx, ky) * 2.4 * delta)
	var before: int = engine.score
	var boss_before: Dictionary = engine.boss.duplicate()
	var objs_before: Array = engine.objects.duplicate()
	var ev: Array = engine.step(delta)
	for e in ev:
		match e:
			"kill":
				_sfx("explode")
				if info:
					info.add("Enemies shot down")
			"hit", "boss_hit":
				_sfx("hit")
			"hurt":
				_sfx("hit")
				_buzz()
			"ring":
				_sfx("pickup")
				if info:
					info.add("Rings flown through")
			"boss":
				_sfx("buzzer")
				_show_banner(tr("Warning: boss!"))
			"boss_down":
				_sfx("win")
				_burst(_proj(Vector3(boss_before.get("x", 0.0), boss_before.get("y", 0.0), boss_before.get("z", 22.0))), ENEMY, 80)
				if info:
					info.add("Bosses beaten")
					info.high("Highest stage", engine.stage + 1)
			"clear":
				_show_banner(tr("Stage clear!"), PAUSE_AFTER)
				after = PAUSE_AFTER
			"dead":
				_sfx("lose")
				_burst(_proj(Vector3(engine.ship.x, engine.ship.y, 0.0)), SHIP, 50)
				_show_banner(tr("Ship lost!") if engine.ships > 0 else tr("Game over!"), PAUSE_AFTER)
				after = PAUSE_AFTER
	# Explosions where things vanished.
	if "kill" in ev:
		for o in objs_before:
			if not engine.objects.has(o) and o.z > 0.0:
				_burst(_proj(Vector3(o.x, o.y, o.z)), ENEMY if o.kind != "rock" else ROCK, 22)
	if engine.score != before or not ev.is_empty():
		_update_hud()
	field.queue_redraw()

func _burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		sparks.append([p, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80, 420), randf_range(0.3, 0.9), col])

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Game over!") + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Stage %d") % engine.stage
	if info:
		info.add("Games played")
		info.high("Highest stage", engine.stage)
		info.high("Best score (%s)" % DIFF_NAMES[engine.diff], engine.score)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- projection + drawing ----------

## Screen pixels per view unit at the ship's depth.
func _unit() -> float:
	return field.size.x * 0.5625 / Z0

func _cam() -> Vector2:
	return engine.ship * Vector2(0.55, 0.25) + Vector2(0.0, -0.6)  # the camera rides a little above the ship

func _center() -> Vector2:
	return Vector2(field.size.x / 2.0, field.size.y * 0.3)

## Tall phone screens: the view is stretched upright so the ship has room to climb and dive.
func _proj(p: Vector3) -> Vector2:
	var f := field.size.x * 0.5625
	return _center() + (Vector2(p.x, p.y) - _cam()) * Vector2(1.0, V_STRETCH) * f / maxf(0.05, p.z + Z0)

func _scale(z: float) -> float:
	return field.size.x * 0.5625 / maxf(0.05, z + Z0)

func _fog(z: float) -> float:
	return clampf(1.2 - z / SrEngine.FAR, 0.12, 1.0)

func _draw_field() -> void:
	var c := field
	var s := field.size
	if s.x < 10:
		return
	var lk: String = engine.look()
	var gc: Color = LOOK_COLORS[lk]
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.01, 0.035))
	# Stars.
	for st in stars:
		var p := _proj(Vector3(st[0], st[1] - 3.0, st[2]))
		var a := _fog(st[2]) * 0.8
		if lk == "space":
			var q := _proj(Vector3(st[0], st[1] - 3.0, st[2] + 2.5))
			c.draw_line(q, p, Color(1, 1, 1, a), 1.5)
		else:
			c.draw_circle(p, 1.3, Color(1, 1, 1, a * 0.6))
	# The ground: a grid rushing towards us.
	if lk != "space":
		var gy := SrEngine.GROUND_Y
		var hz := _proj(Vector3(0, gy, SrEngine.FAR)).y
		c.draw_rect(Rect2(Vector2(0, hz), Vector2(s.x, s.y - hz)), Color(gc.darkened(0.85), 0.9))
		HomeKit.glow_line(c, Vector2(0, hz), Vector2(s.x, hz), gc, 1.5)
		var ph := fmod(engine.travelled, 4.0)
		for i in 16:
			var z := i * 4.0 - ph
			if z < -1.6:
				continue
			var y := _proj(Vector3(0, gy, z)).y
			c.draw_line(Vector2(0, y), Vector2(s.x, y), Color(gc, 0.65 * _fog(z)), 1.5)
		for i in 21:
			var x := -12.0 + i * 1.2
			c.draw_line(_proj(Vector3(x, gy, -1.6)), _proj(Vector3(x, gy, SrEngine.FAR)), Color(gc, 0.35), 1.2, true)
	# Everything ahead, far to near.
	var things: Array = []
	for o in engine.objects:
		things.append([o.z, "o", o])
	for b in engine.bolts:
		things.append([b.z, "b", b])
	for l in engine.lasers:
		things.append([l.z, "l", l])
	if not engine.boss.is_empty():
		things.append([engine.boss.z, "boss", engine.boss])
	things.sort_custom(func(a, b): return a[0] > b[0])
	for t in things:
		match t[1]:
			"o":
				_draw_object(c, t[2])
			"b":
				var b: Dictionary = t[2]
				var p := _proj(Vector3(b.x, b.y, b.z))
				var r := maxf(3.0, 0.07 * _scale(b.z))
				c.draw_circle(p, r * 0.6, HomeKit.WHITE)
				HomeKit.glow_circle(c, p, r, SHOT, 2.0, 0.3)
			"l":
				var l: Dictionary = t[2]
				HomeKit.glow_line(c, _proj(Vector3(l.x, l.y, l.z)), _proj(Vector3(l.x, l.y, l.z + 3.0)), Color(RING, _fog(l.z)), 2.0)
			"boss":
				_draw_boss(c, t[2])
	# Reticle straight ahead, then the ship.
	var ret := _proj(Vector3(engine.ship.x, engine.ship.y, 18.0))
	var rr := 0.12 * _scale(18.0)
	c.draw_rect(Rect2(ret - Vector2(rr, rr), Vector2(rr, rr) * 2), Color(RING, 0.6), false, 1.5)
	c.draw_line(ret - Vector2(rr * 1.6, 0), ret - Vector2(rr * 0.6, 0), Color(RING, 0.6), 1.5)
	c.draw_line(ret + Vector2(rr * 1.6, 0), ret + Vector2(rr * 0.6, 0), Color(RING, 0.6), 1.5)
	if engine.state != "dead" and (engine.invuln <= 0.0 or fmod(anim_t, 0.16) < 0.1):
		_draw_ship(c, _proj(Vector3(engine.ship.x, engine.ship.y, 0.0)), _scale(0.0) * 0.26, -engine.ship_vx * 0.12)
	for sp in sparks:
		c.draw_line(sp[0], sp[0] - sp[1] * 0.03, Color(sp[3], clampf(sp[2] * 2.0, 0.0, 1.0)), 2.0)
	# Shield, bottom left; boss armour, top.
	var font := ThemeDB.fallback_font
	var sh: float = float(engine.shield) / SrEngine.MAX_SHIELD
	var bar := Rect2(Vector2(14, s.y - 30), Vector2(minf(260.0, s.x * 0.4), 14))
	c.draw_rect(bar, Color(1, 1, 1, 0.1))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * sh, bar.size.y)), SHIP if sh > 0.3 else ACE)
	c.draw_string(font, bar.position + Vector2(0, -6), tr("Shield"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, HomeKit.DIM)
	if not engine.boss.is_empty():
		var bb := Rect2(Vector2(s.x * 0.2, 14), Vector2(s.x * 0.6, 12))
		c.draw_rect(bb, Color(1, 1, 1, 0.1))
		c.draw_rect(Rect2(bb.position, Vector2(bb.size.x * maxf(0.0, float(engine.boss.hp) / engine.boss.max), bb.size.y)), ENEMY)
	if banner_t > 0.0:
		HomeKit.glow_text(c, Vector2(s.x / 2.0, s.y * 0.22), banner, int(clampf(s.x / 16.0, 24, 44)), HomeKit.WHITE)

func _draw_object(c: CanvasItem, o: Dictionary) -> void:
	var z: float = o.z
	if z < -1.8:
		return
	var p := _proj(Vector3(o.x, o.y, z))
	var k := _scale(z)
	var fog := _fog(z)
	var w := clampf(k * 0.012, 1.2, 3.0)
	match o.kind:
		"fighter", "ace":
			var col: Color = (ENEMY if o.kind == "fighter" else ACE) if o.hit <= 0.0 else HomeKit.WHITE
			col = Color(col, fog)
			var r: float = o.r * k
			var bank := sin(o.t * o.sway) * 0.35
			var pts := PackedVector2Array()
			for v in [Vector2(0, -0.35), Vector2(1, 0.15), Vector2(0.25, 0.05), Vector2(0, 0.45), Vector2(-0.25, 0.05), Vector2(-1, 0.15)]:
				pts.append(p + (v as Vector2).rotated(bank) * r)
			c.draw_colored_polygon(pts, Color(col.darkened(0.7), 0.5 * fog))
			HomeKit.glow_polyline(c, pts, col, w, true)
			if o.kind == "ace":
				HomeKit.glow_circle(c, p, r * 0.3, col, w)
			c.draw_circle(p + Vector2(0, r * 0.05), r * 0.08, Color(1, 1, 1, fog))
		"rock":
			var col: Color = Color(ROCK if o.hit <= 0.0 else HomeKit.WHITE, fog)
			var r: float = o.r * k
			var pts := PackedVector2Array()
			for i in 8:
				var a: float = TAU * i / 8.0 + o.t * 0.8
				pts.append(p + Vector2(cos(a), sin(a)) * r * (0.75 + 0.25 * sin(i * 2.7 + o.x0 * 5.0)))
			c.draw_colored_polygon(pts, Color(col.darkened(0.75), 0.6 * fog))
			HomeKit.glow_polyline(c, pts, col, w, true)
			c.draw_line(pts[1], pts[5], Color(col, 0.4 * fog), 1.0)
		"tower":
			var a := _proj(Vector3(o.x - 0.3, -0.2, z))
			var b := _proj(Vector3(o.x + 0.3, SrEngine.GROUND_Y, z))
			var r := Rect2(a, b - a)
			c.draw_rect(r, Color(ACE.darkened(0.8), 0.7 * fog))
			HomeKit.glow_rect(c, r, Color(ACE, fog), w)
			var top := _proj(Vector3(o.x, -0.2, z))
			c.draw_circle(top, maxf(2.0, k * 0.05), Color(ACE, fog * (0.6 + 0.4 * sin(anim_t * 8.0))))
		"ring":
			var r: float = o.r * k
			HomeKit.glow_circle(c, p, r, Color(RING, fog), w * 1.2)
			HomeKit.glow_circle(c, p, r * (0.8 + 0.06 * sin(anim_t * 6.0)), Color(RING, fog * 0.5), w * 0.8)

func _draw_boss(c: CanvasItem, b: Dictionary) -> void:
	var z: float = b.z
	var p := _proj(Vector3(b.x, b.y, z))
	var k := _scale(z)
	var col: Color = ENEMY if b.hit <= 0.0 else HomeKit.WHITE
	var w := clampf(k * 0.012, 1.5, 3.0)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 6:
		var a: float = TAU * i / 6.0 + b.spin
		outer.append(p + Vector2(cos(a), sin(a)) * 0.95 * k)
		inner.append(p + Vector2(cos(a + PI / 6.0), sin(a + PI / 6.0)) * 0.6 * k)
	c.draw_colored_polygon(outer, Color(col.darkened(0.8), 0.6))
	HomeKit.glow_polyline(c, outer, col, w, true)
	HomeKit.glow_polyline(c, inner, HomeKit.PURPLE, w, true)
	for i in 6:
		c.draw_line(outer[i], inner[i], Color(col, 0.6), 1.5)
	var pulse := 0.3 + 0.05 * sin(anim_t * 10.0)
	c.draw_circle(p, pulse * k, Color(SHOT, 0.35))
	HomeKit.glow_circle(c, p, pulse * k, SHOT, w)
	c.draw_circle(p, 0.1 * k, HomeKit.WHITE)

func _draw_ship(c: CanvasItem, p: Vector2, r: float, bank: float) -> void:
	var body := PackedVector2Array()
	for v in [Vector2(0, -0.9), Vector2(0.3, 0.1), Vector2(1.0, 0.45), Vector2(0.3, 0.35), Vector2(0, 0.55), Vector2(-0.3, 0.35), Vector2(-1.0, 0.45), Vector2(-0.3, 0.1)]:
		body.append(p + (v as Vector2).rotated(bank) * r)
	c.draw_colored_polygon(body, Color(SHIP.darkened(0.6), 0.6))
	HomeKit.glow_polyline(c, body, SHIP, 2.2, true)
	c.draw_line(p + Vector2(0, -0.9).rotated(bank) * r, p + Vector2(0, 0.55).rotated(bank) * r, Color(SHIP, 0.6), 1.5)
	c.draw_circle(p + Vector2(0, -0.2).rotated(bank) * r, r * 0.1, HomeKit.WHITE)
	for sd in [-1.0, 1.0]:
		var e := p + Vector2(sd * 0.22, 0.45).rotated(bank) * r
		var f := randf_range(0.25, 0.5) * r
		HomeKit.glow_line(c, e, e + Vector2(0, f).rotated(bank), SHOT, 2.0)

func _draw_home_logo(c: Control) -> void:
	var s := c.size
	var o := Vector2(s.x / 2.0, s.y * 0.62)
	var k := minf(s.y / 170.0, 1.4)
	var gc: Color = LOOK_COLORS["planet"]
	for i in 6:
		var y := o.y + 10.0 * k + pow(i / 5.0, 2.0) * 60.0 * k
		c.draw_line(Vector2(o.x - 200 * k, y), Vector2(o.x + 200 * k, y), Color(gc, 0.3 + i * 0.1), 1.5)
	for i in 11:
		var x := (i - 5) * 40.0 * k
		c.draw_line(Vector2(o.x + x * 0.15, o.y + 10 * k), Vector2(o.x + x * 1.4, o.y + 70 * k), Color(gc, 0.5), 1.2, true)
	HomeKit.glow_line(c, Vector2(o.x - 200 * k, o.y + 10 * k), Vector2(o.x + 200 * k, o.y + 10 * k), gc, 1.5)
	HomeKit.glow_circle(c, o + Vector2(70, -70) * k, 22 * k, RING, 2.0)
	var fp := o + Vector2(-90, -78) * k
	var pts := PackedVector2Array()
	for v in [Vector2(0, -0.35), Vector2(1, 0.15), Vector2(0.25, 0.05), Vector2(0, 0.45), Vector2(-0.25, 0.05), Vector2(-1, 0.15)]:
		pts.append(fp + v * 30.0 * k)
	HomeKit.glow_polyline(c, pts, ENEMY, 2.0, true)
	_draw_ship(c, o + Vector2(0, -18) * k, 52.0 * k, 0.15)
	HomeKit.glow_line(c, o + Vector2(-12, -60) * k, o + Vector2(-30, -110) * k, RING, 2.0)

# ---------- pause / save ----------

func _on_pause() -> void:
	keys.clear()
	home.pause()

func _go_home() -> void:
	home.go_home()

## Stage, score, ships and bombs; Resume starts that stage over.
func _save_game() -> void:
	if not started or engine.state == "over":
		return
	var st: int = engine.stage + (1 if engine.state == "clear" else 0)
	var ships: int = engine.ships if engine.state != "dead" else maxi(1, engine.ships)
	SaveUtil.write(SAVE_PATH, {"stage": st, "score": engine.score, "ships": ships, "bombs": engine.bombs, "diff": engine.diff})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Stage %d") % int(d.get("stage", 1)) + "   ·   " + tr("Score: %d") % int(d.get("score", 0))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		_new_game(1)
		return
	engine.reset(int(d.get("diff", 1)))
	engine.stage = maxi(1, int(d.get("stage", 1)))
	engine.score = int(d.get("score", 0))
	engine.ships = clampi(int(d.get("ships", 3)), 1, 3)
	engine.bombs = clampi(int(d.get("bombs", 3)), 0, 5)
	engine.start_stage()
	_begin()

func _buzz() -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(40)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
