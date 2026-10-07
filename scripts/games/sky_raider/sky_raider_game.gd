extends Control

## Sky Raider: a vertical-scrolling neon shooter. Slide your fighter with
## a finger anywhere on the screen; it fires on its own. Grab P to power up
## the guns, B for bombs, and take down each stage's battleship.

const SrEngine = preload("res://scripts/games/sky_raider/sky_raider_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/sky_raider/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/sky_raider/sky_raider_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://sky_raider_save.json"

const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const PLAYER := Color("29e6ff")
const DART := Color("ff2bd6")
const GUNSHIP := Color("ff4f9a")
const TURRET := Color("9b4dff")
const BOMBER := Color("ffae2b")
const SHOT := Color("7dff3a")
const BULLET := Color("ff4f9a")
const LAND := Color("3a8cff")
## Each stage's battleship has its own colour (it gets tougher every time).
const BOSS_COLORS := [Color("ffae2b"), Color("ff2bd6"), Color("9b4dff"), Color("ff3b3b"), Color("29e6ff"), Color("7dff3a")]
const STEER := 1.3
const PAUSE_AFTER := 2.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var keys: Dictionary = {}
var after: float = 0.0
var banner := ""
var banner_t: float = 0.0
var sparks: Array = []   # [world pos, vel, life, color]
var flash_t: float = 0.0
var anim_t: float = 0.0

var field: Control
var score_label: Label
var hud_label: Label
var power_label: Label
var bomb_btn: Button
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/sky_raider/sky_raider_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = SrEngine.new()
	engine.reset(1)
	_build_ui()
	# Get the first stage's and the battleship's music ready while Home shows.
	_music("prepare", "lively", 0)
	_music("prepare", "techno", 0)

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
	score_label.add_theme_color_override("font_color", PLAYER.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(PLAYER, 0.5))
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
	power_label = HomeKit.label("", 24, SHOT, false, false)
	power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(power_label)
	bomb_btn = HomeKit.neon_button("", BOMBER, 28, 88)
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
		"accent": PLAYER,
		"solo_heading": "Take off",
		"subtitle": "Slide to dodge, the guns fire themselves. Power up and sink the battleship.",
		"logo": _draw_home_logo,
		"art": "res://games/sky_raider/landing_bg.jpg",
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

## The fighter follows the finger's movement (not its position), so the
## finger never hides it.
func _on_field_input(event: InputEvent) -> void:
	if not started or engine.state != "play":
		return
	var rel := Vector2.ZERO
	if event is InputEventScreenDrag:
		rel = event.relative
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if DisplayServer.is_touchscreen_available():
			return
		rel = event.relative
	else:
		return
	engine.move(rel / _geom().k * STEER)

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
	_show_banner(tr("Stage %d") % engine.stage)
	_update_hud()
	_stage_music()

## Each stage has its own lively track, each battleship a techno one.
func _stage_music() -> void:
	_music("play", "lively", engine.stage - 1)
	_music("prepare", "techno", engine.stage - 1)

func _show_banner(text: String, t: float = 2.0) -> void:
	banner = text
	banner_t = t

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Stage %d") % engine.stage + "\n" + "▲".repeat(maxi(0, engine.lives))
	power_label.text = tr("Guns") + " " + "■".repeat(engine.power) + "□".repeat(SrEngine.MAX_POWER - engine.power)
	bomb_btn.text = "💣 " + tr("Bomb") + " ×%d" % engine.bombs
	bomb_btn.disabled = engine.bombs <= 0

func _on_bomb() -> void:
	if started and engine.bomb():
		_sfx("explode")
		flash_t = 0.4
		for i in 70:
			sparks.append([engine.pos, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(200, 900), randf_range(0.4, 1.0), BOMBER if i % 2 else HomeKit.WHITE])
		if info:
			info.add("Bombs used")
		_update_hud()

func _process(delta: float) -> void:
	anim_t += delta
	if not started:
		return
	delta = minf(delta, 0.05)
	banner_t = maxf(0.0, banner_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	for s in sparks:
		s[0] += s[1] * delta
		s[1] *= 0.93
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	if after > 0.0:
		after -= delta
		if after <= 0.0:
			engine.next()
			if engine.state == "over":
				_game_over()
				return
			_show_banner(tr("Stage %d") % engine.stage)
			_update_hud()
			_stage_music()
		field.queue_redraw()
		return
	var kx := (1.0 if keys.has(KEY_RIGHT) or keys.has(KEY_D) else 0.0) - (1.0 if keys.has(KEY_LEFT) or keys.has(KEY_A) else 0.0)
	var ky := (1.0 if keys.has(KEY_DOWN) or keys.has(KEY_S) else 0.0) - (1.0 if keys.has(KEY_UP) or keys.has(KEY_W) else 0.0)
	if kx != 0.0 or ky != 0.0:
		engine.move(Vector2(kx, ky).normalized() * 480.0 * delta)
	var before: Array = engine.enemies.duplicate()
	var boss_p: Vector2 = engine.boss.get("p", Vector2.ZERO)
	var ev: Array = engine.step(delta)
	for e in ev:
		match e:
			"kill", "big_kill":
				_sfx("explode")
				if info:
					info.add("Planes shot down")
			"hit":
				_sfx("hit")
			"hurt":
				_sfx("lose")
				_buzz()
				_burst(engine.pos, PLAYER, 40)
				flash_t = 0.25
			"crash":
				_sfx("explode")
				_burst(engine.pos, LAND, 30)
			"power":
				_sfx("powerup")
			"bomb_item", "life":
				_sfx("pickup")
			"boss":
				_sfx("buzzer")
				_show_banner(tr("Warning: battleship!"))
				_music("play", "techno", engine.stage - 1, 1.0)
			"boss_phase":
				_sfx("buzzer")
				flash_t = 0.2
				_burst(boss_p, _boss_color(), 50)
			"laser":
				_sfx("shoot")
			"boss_down":
				_sfx("win")
				_burst(boss_p, _boss_color(), 120)
				_music("play", "lively", engine.stage, 2.0)  # the next stage's track
				if info:
					info.add("Battleships sunk")
					info.high("Highest stage", engine.stage + 1)
			"clear":
				_show_banner(tr("Stage clear!"), PAUSE_AFTER)
				after = PAUSE_AFTER
			"dead":
				_show_banner(tr("Game over!"), PAUSE_AFTER)
				after = PAUSE_AFTER
				_music("stop", "", 0, 2.5)
	if "kill" in ev or "big_kill" in ev:
		for o in before:
			if not engine.enemies.has(o):
				_burst(o.p, _enemy_color(o.kind), 30 if o.kind == "bomber" else 16)
	if not ev.is_empty():
		_update_hud()
	field.queue_redraw()

func _burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		sparks.append([p, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 420), randf_range(0.3, 0.8), col])

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

# ---------- drawing ----------

func _geom() -> Dictionary:
	var k: float = minf(field.size.x / SrEngine.W, field.size.y / SrEngine.H)
	var o := (field.size - Vector2(SrEngine.W, SrEngine.H) * k) / 2.0
	return {"k": k, "o": o}

func _enemy_color(kind: String) -> Color:
	return {"dart": DART, "gunship": GUNSHIP, "turret": TURRET, "bomber": BOMBER}.get(kind, DART)

func _draw_field() -> void:
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var c := field
	var s := field.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.02, 0.05))
	# Sea grid scrolling down, islands drifting with it.
	var step := 80.0 * k
	var off := fmod(engine.scrolled * k, step)
	var y := off - step
	while y < s.y:
		c.draw_line(Vector2(0, y), Vector2(s.x, y), Color(LAND, 0.09), 1.0)
		y += step
	var x := fmod(o.x, step)
	while x < s.x:
		c.draw_line(Vector2(x, 0), Vector2(x, s.y), Color(LAND, 0.07), 1.0)
		x += step
	# Islands are solid (since v8): a bright rim and contour lines, like a
	# mountain seen from above. One you crashed into goes dark (harmless).
	for isl in engine.islands:
		var crashed: bool = isl.get("hit", false)
		var pts := PackedVector2Array()
		for p in isl.pts:
			pts.append(o + (isl.p + p) * k)
		c.draw_colored_polygon(pts, Color(0.02, 0.04, 0.07) if crashed else Color(0.04, 0.1, 0.18))
		HomeKit.glow_polyline(c, pts, Color(LAND, 0.25 if crashed else 0.9), 2.0, true)
		for ring in [0.66, 0.33]:
			var inner := PackedVector2Array()
			for p in isl.pts:
				inner.append(o + (isl.p + p * ring) * k)
			inner.append(inner[0])
			c.draw_polyline(inner, Color(LAND, 0.1 if crashed else 0.3), 1.0, true)
	for it in engine.items:
		var p: Vector2 = o + it.p * k
		var col: Color = SHOT if it.kind == "P" else (BOMBER if it.kind == "B" else PLAYER)
		HomeKit.glow_circle(c, p, 18.0 * k, col, 2.0, 0.25 + 0.1 * sin(anim_t * 8.0))
		var label: String = {"P": "P", "B": "B", "1": "1UP"}[it.kind]
		HomeKit.glow_text(c, p, label, int((22 if label.length() == 1 else 15) * k), col)
	for e in engine.enemies:
		_draw_enemy(c, o + e.p * k, k, e)
	if not engine.boss.is_empty():
		_draw_boss(c, o + engine.boss.p * k, k, engine.boss)
	for sh in engine.shots:
		var p: Vector2 = o + sh.p * k
		HomeKit.glow_line(c, p, p - (sh.v as Vector2).normalized() * 18.0 * k, SHOT, 2.0)
	if engine.state != "dead" and (engine.invuln <= 0.0 or fmod(anim_t, 0.16) < 0.09):
		_draw_player(c, o + engine.pos * k, k)
	for b in engine.bullets:
		var p: Vector2 = o + b.p * k
		c.draw_circle(p, 7.0 * k, Color(BULLET, 0.35))
		c.draw_circle(p, 4.5 * k, BULLET)
		c.draw_circle(p, 2.2 * k, HomeKit.WHITE)
	for sp in sparks:
		var p: Vector2 = o + sp[0] * k
		c.draw_line(p, p - sp[1] * 0.03 * k, Color(sp[3], clampf(sp[2] * 2.0, 0.0, 1.0)), 2.0)
	if flash_t > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash_t * 0.35))
	if not engine.boss.is_empty():
		var bb := Rect2(Vector2(s.x * 0.15, 12), Vector2(s.x * 0.7, 12))
		c.draw_rect(bb, Color(1, 1, 1, 0.1))
		c.draw_rect(Rect2(bb.position, Vector2(bb.size.x * maxf(0.0, float(engine.boss.hp) / engine.boss.max), bb.size.y)), _boss_color())
		# A mark where each new phase starts.
		var phases: int = engine.boss.get("phases", 2)
		for i in range(1, phases):
			var tx := bb.position.x + bb.size.x * (1.0 - float(i) / phases)
			c.draw_line(Vector2(tx, bb.position.y - 3), Vector2(tx, bb.end.y + 3), HomeKit.WHITE, 2.0)
	if banner_t > 0.0:
		HomeKit.glow_text(c, Vector2(s.x / 2.0, s.y * 0.4), banner, int(clampf(s.x / 15.0, 24, 46)), HomeKit.WHITE)

func _draw_player(c: CanvasItem, p: Vector2, k: float) -> void:
	var pts := PackedVector2Array()
	for v in [Vector2(0, -30), Vector2(7, -10), Vector2(28, 8), Vector2(28, 14), Vector2(8, 10), Vector2(10, 24), Vector2(0, 20),
			Vector2(-10, 24), Vector2(-8, 10), Vector2(-28, 14), Vector2(-28, 8), Vector2(-7, -10)]:
		pts.append(p + v * k)
	c.draw_colored_polygon(pts, Color(PLAYER.darkened(0.6), 0.7))
	HomeKit.glow_polyline(c, pts, PLAYER, 2.0, true)
	for sd in [-1.0, 1.0]:
		HomeKit.glow_line(c, p + Vector2(sd * 5, 22) * k, p + Vector2(sd * 5, 22 + randf_range(8, 18)) * k, BOMBER, 2.0)
	# The hitbox: only this dot counts for bullets.
	c.draw_circle(p, 4.0 * k, HomeKit.WHITE)
	c.draw_arc(p, SrEngine.PLAYER_HIT * k, 0, TAU, 20, Color(1, 1, 1, 0.35), 1.0)

func _draw_enemy(c: CanvasItem, p: Vector2, k: float, e: Dictionary) -> void:
	var col: Color = _enemy_color(e.kind) if e.hit <= 0.0 else HomeKit.WHITE
	var pts := PackedVector2Array()
	match e.kind:
		"dart":
			for v in [Vector2(0, 20), Vector2(-18, -14), Vector2(0, -6), Vector2(18, -14)]:
				pts.append(p + v * k)
		"gunship":
			for v in [Vector2(0, 30), Vector2(-10, 12), Vector2(-34, 4), Vector2(-34, -6), Vector2(-10, -10), Vector2(-6, -26),
					Vector2(6, -26), Vector2(10, -10), Vector2(34, -6), Vector2(34, 4), Vector2(10, 12)]:
				pts.append(p + v * k)
		"turret":
			for i in 8:
				var a := TAU * i / 8.0 + PI / 8.0
				pts.append(p + Vector2(cos(a), sin(a)) * 22.0 * k)
			var aim: Vector2 = (engine.pos - e.p).normalized()
			HomeKit.glow_line(c, p, p + aim * 30.0 * k, col, 3.0)
		"bomber":
			for v in [Vector2(0, 46), Vector2(-16, 26), Vector2(-70, 14), Vector2(-74, -4), Vector2(-18, -6), Vector2(-12, -40),
					Vector2(12, -40), Vector2(18, -6), Vector2(74, -4), Vector2(70, 14), Vector2(16, 26)]:
				pts.append(p + v * k)
	c.draw_colored_polygon(pts, Color(col.darkened(0.7), 0.7))
	HomeKit.glow_polyline(c, pts, col, 2.0, true)
	if e.kind == "turret":
		HomeKit.glow_circle(c, p, 9.0 * k, col, 1.5)
	elif e.kind == "bomber":
		for sd in [-1.0, 1.0]:
			c.draw_circle(p + Vector2(sd * 40, 4) * k, 5 * k, Color(BULLET, 0.8))

func _boss_color() -> Color:
	return BOSS_COLORS[(engine.stage - 1) % BOSS_COLORS.size()]

func _draw_boss(c: CanvasItem, p: Vector2, k: float, b: Dictionary) -> void:
	# The laser: a blinking sight line while it aims, then the beam.
	var lz: Dictionary = b.get("laser", {})
	var bottom := Vector2(p.x, field.size.y)
	if not lz.is_empty():
		if lz.on <= 0.0:
			# Where the beam will come down (the ship slides there first).
			if fmod(anim_t, 0.2) < 0.13:
				var lx: float = p.x + (lz.x - b.p.x) * k
				c.draw_line(Vector2(lx, p.y + 40 * k), Vector2(lx, field.size.y), Color(DART, 0.7), 2.0)
		else:
			var w := SrEngine.LASER_HALF * 2.0 * k
			c.draw_line(p + Vector2(0, 40) * k, bottom, Color(DART, 0.35), w * 1.6)
			c.draw_line(p + Vector2(0, 40) * k, bottom, DART, w)
			c.draw_line(p + Vector2(0, 40) * k, bottom, HomeKit.WHITE, w * 0.35)
	var col: Color = _boss_color() if b.hit <= 0.0 else HomeKit.WHITE
	var hull := PackedVector2Array()
	for v in [Vector2(0, 70), Vector2(-40, 50), Vector2(-130, 30), Vector2(-150, -10), Vector2(-120, -50), Vector2(-50, -60),
			Vector2(0, -80), Vector2(50, -60), Vector2(120, -50), Vector2(150, -10), Vector2(130, 30), Vector2(40, 50)]:
		hull.append(p + v * k)
	c.draw_colored_polygon(hull, Color(0.12, 0.05, 0.02, 0.9))
	HomeKit.glow_polyline(c, hull, col, 2.5, true)
	var deck := PackedVector2Array()
	for v in [Vector2(-90, -20), Vector2(90, -20), Vector2(70, 20), Vector2(-70, 20)]:
		deck.append(p + v * k)
	HomeKit.glow_polyline(c, deck, Color(DART, 0.8), 1.5, true)
	# More guns on the deck as battleships gain phases.
	var guns: Array = [-100.0, -60.0, 60.0, 100.0]
	if int(b.get("phases", 2)) >= 3:
		guns += [-130.0, 130.0]
	if int(b.get("phases", 2)) >= 4:
		guns += [-20.0, 20.0]
	for tx in guns:
		var tp := p + Vector2(tx, 10 if absf(tx) < 120.0 else -18) * k
		HomeKit.glow_circle(c, tp, 12.0 * k, DART, 1.5, 0.3)
		HomeKit.glow_line(c, tp, tp + (engine.pos - (b.p + Vector2(tx, 10))).normalized() * 22.0 * k, DART, 2.0)
	var core := p + Vector2(0, 20) * k
	var pulse := 20.0 + 4.0 * sin(anim_t * (9.0 + 4.0 * int(b.get("phase", 0))))
	c.draw_circle(core, pulse * k, Color(BULLET, 0.35))
	HomeKit.glow_circle(c, core, pulse * k, BULLET, 2.0)

func _draw_home_logo(c: Control) -> void:
	var s := c.size
	var k := minf(s.y / 170.0, 1.5)
	var o := s / 2.0
	for i in 5:
		var y := o.y - 80 * k + i * 40 * k
		c.draw_line(Vector2(o.x - 180 * k, y), Vector2(o.x + 180 * k, y), Color(LAND, 0.15), 1.0)
	var isl := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		isl.append(o + Vector2(-110, 30) * k + Vector2(cos(a) * 60, sin(a) * 34) * k * (0.8 + 0.25 * sin(i * 2.3)))
	HomeKit.glow_polyline(c, isl, Color(LAND, 0.6), 1.4, true)
	_draw_enemy(c, o + Vector2(-50, -55) * k, k, {"kind": "dart", "hit": 0.0, "p": Vector2.ZERO})
	_draw_enemy(c, o + Vector2(70, -60) * k, k * 0.9, {"kind": "gunship", "hit": 0.0, "p": Vector2.ZERO})
	for i in 4:
		HomeKit.glow_line(c, o + Vector2(-8, 20 - i * 30) * k, o + Vector2(-8, 6 - i * 30) * k, SHOT, 2.0)
		HomeKit.glow_line(c, o + Vector2(8, 20 - i * 30) * k, o + Vector2(8, 6 - i * 30) * k, SHOT, 2.0)
	for i in 3:
		c.draw_circle(o + Vector2(100 - i * 22, -20 + i * 26) * k, 5 * k, BULLET)
	_draw_player(c, o + Vector2(0, 60) * k, k * 1.3)

# ---------- pause / save ----------

func _on_pause() -> void:
	keys.clear()
	home.pause()

func _go_home() -> void:
	home.go_home()

## Stage, score, lives, bombs and guns; Resume starts that stage over.
func _save_game() -> void:
	if not started or engine.state == "over" or engine.state == "dead":
		return
	var st: int = engine.stage + (1 if engine.state == "clear" else 0)
	SaveUtil.write(SAVE_PATH, {"stage": st, "score": engine.score, "lives": engine.lives, "bombs": engine.bombs,
		"power": engine.power, "diff": engine.diff})

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
	engine.lives = clampi(int(d.get("lives", 3)), 1, 5)
	engine.bombs = clampi(int(d.get("bombs", 2)), 0, 5)
	engine.power = clampi(int(d.get("power", 1)), 1, SrEngine.MAX_POWER)
	engine.start_stage()
	_begin()

func _buzz() -> void:
	var st = get_node_or_null("/root/Settings")
	if st and st.has_method("buzz"):
		st.buzz(60)

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)

## The hub's shared music library (Music autoload, apps from v0.33; older
## ones play no music). `what`: "play", "prepare" or "stop".
func _music(what: String, style: String, index: int = 0, fade: float = 1.5) -> void:
	var m = get_node_or_null("/root/Music")
	if m == null:
		return
	match what:
		"play":
			m.play(style, self, index, fade)
		"prepare":
			m.prepare(style, index)
		"stop":
			m.stop(fade)
