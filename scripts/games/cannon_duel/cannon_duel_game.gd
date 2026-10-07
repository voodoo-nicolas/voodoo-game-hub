extends Control

## Cannon Duel: turn-based artillery on hilly ground that blows apart.
## Aim by dragging on the field (or the angle / power buttons), mind the
## wind, fire. Vs the computer (3 levels) or two players on one phone.

const CdEngine = preload("res://scripts/games/cannon_duel/cannon_duel_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/cannon_duel/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/cannon_duel/cannon_duel_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://cannon_duel_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const P_COLORS := [Color("29e6ff"), Color("ff2bd6")]
const GROUND := Color("9b4dff")
const SHELL := Color("ffae2b")
const ANGLE_RATE := 45.0
const POWER_RATE := 32.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var cpu_level: int = 1      # -1 = two players
var started := false
var result_recorded := false
var phase := "aim"          # aim, fly, settle, cpu, over
var phase_t: float = 0.0
var cpu_plan: Dictionary = {}
var held: Dictionary = {}   # "a-", "a+", "p-", "p+", "l", "r" -> true
var booms: Array = []       # [pos, radius, age]
var sparks: Array = []      # [pos, vel, life, color]
var shake: float = 0.0
var banner := ""
var banner_t: float = 0.0
var dragging := false
var stars: Array = []

var field: Control
var title_label: Label
var weapon_btn: Button
var fire_btn: Button
var panel: Control
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/cannon_duel/cannon_duel_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = CdEngine.new()
	engine.reset()
	var r := RandomNumberGenerator.new()
	for i in 70:
		stars.append([Vector2(r.randf() * CdEngine.W, r.randf() * 520.0), r.randf_range(0.6, 1.6)])
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
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
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
	field.resized.connect(field.queue_redraw)
	fm.add_child(field)

	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_bottom", 26)
	cm.add_theme_constant_override("margin_top", 6)
	cm.add_theme_constant_override("margin_left", 12)
	cm.add_theme_constant_override("margin_right", 12)
	root.add_child(cm)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	cm.add_child(panel)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	panel.add_child(row1)
	row1.add_child(_hold_button("◀ ⛽", "l", 130, HomeKit.BLUE))
	weapon_btn = HomeKit.neon_button("", HomeKit.PURPLE, 24, 76)
	weapon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_btn.pressed.connect(_on_weapon)
	row1.add_child(weapon_btn)
	row1.add_child(_hold_button("⛽ ▶", "r", 130, HomeKit.BLUE))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	panel.add_child(row2)
	row2.add_child(_hold_button("∠−", "a-", 96, HomeKit.CYAN))
	row2.add_child(_hold_button("∠+", "a+", 96, HomeKit.CYAN))
	row2.add_child(_hold_button("⚡−", "p-", 96, HomeKit.LIME))
	row2.add_child(_hold_button("⚡+", "p+", 96, HomeKit.LIME))
	fire_btn = HomeKit.neon_button("🔥 " + tr("Fire"), SHELL, 28, 84)
	fire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_btn.set_meta("sfx", "")
	fire_btn.pressed.connect(_on_fire)
	row2.add_child(fire_btn)

	end_dialog = UI.build_dialog("", [
		{"text": tr("Play Again"), "action": _restart},
		{"text": tr("🏠 %s Home") % tr(TITLE_FOR_HOME), "action": _go_home},
	], true)
	add_child(end_dialog)

	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	var modes: Array = []
	for i in LEVELS.size():
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "cpu",
			"color": [HomeKit.LIME, HomeKit.CYAN, HomeKit.PINK][i], "action": _new_game.bind(i)})
	modes.append({"text": "👥 2 Players", "sub": "Take turns on one phone", "multi": true, "action": _new_game.bind(-1)})
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": SHELL,
		"solo_heading": "vs Computer",
		"subtitle": "Angle, power, wind. Blow the hill apart and the other cannon with it.",
		"logo": _draw_home_logo,
		"modes": modes,
		"save_path": SAVE_PATH,
		"resume": _load_saved_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Wins",
		"board_note": "Games won against the computer, at any level.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # right of the title, above the sky
	add_child(drawer)

func _hold_button(text: String, key: String, w: float, col: Color) -> Button:
	var b := HomeKit.neon_button(text, col, 28, 76)
	b.custom_minimum_size.x = w
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(_hold.bind(key, true))
	b.button_up.connect(_hold.bind(key, false))
	return b

func _hold(key: String, on: bool) -> void:
	if on:
		held[key] = true
		_nudge(key, 1.0)  # a tap moves one step
	else:
		held.erase(key)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var map := {KEY_LEFT: "a+", KEY_RIGHT: "a-", KEY_UP: "p+", KEY_DOWN: "p-", KEY_A: "l", KEY_D: "r"}
		if map.has(event.keycode):
			if event.pressed:
				held[map[event.keycode]] = true
			else:
				held.erase(map[event.keycode])
		elif event.keycode == KEY_SPACE and event.pressed and not event.echo:
			_on_fire()

# ---------- flow ----------

func _new_game(level: int) -> void:
	cpu_level = level
	_restart()

func _restart() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset()
	_begin()

func _begin() -> void:
	started = true
	result_recorded = false
	booms.clear()
	sparks.clear()
	held.clear()
	end_dialog.visible = false
	_start_turn()

func _human_turn() -> bool:
	return cpu_level < 0 or engine.turn == 0

func _name(i: int) -> String:
	if cpu_level >= 0:
		return tr("You") if i == 0 else tr("Computer")
	return tr("Player %d") % (i + 1)

func _start_turn() -> void:
	if _human_turn():
		phase = "aim"
		if cpu_level < 0:
			_show_banner(tr("%s's turn") % _name(engine.turn))
	else:
		phase = "cpu"
		phase_t = 0.0
		cpu_plan = {}
	_update_ui()

func _show_banner(text: String) -> void:
	banner = text
	banner_t = 1.6

func _update_ui() -> void:
	var t: Dictionary = engine.tanks[engine.turn]
	title_label.text = _name(engine.turn) if not engine.is_over() else tr(TITLE_FOR_HOME)
	title_label.add_theme_color_override("font_color", P_COLORS[engine.turn].lerp(Color.WHITE, 0.4))
	var w: int = t.weapon
	var ammo: int = t.ammo[w]
	weapon_btn.text = tr(CdEngine.WEAPONS[w].name) + "  " + ("∞" if ammo < 0 else "×%d" % ammo)
	var mine := phase == "aim" and _human_turn()
	for b in [weapon_btn, fire_btn]:
		b.disabled = not mine
	panel.modulate.a = 1.0 if mine else 0.45
	field.queue_redraw()

func _nudge(key: String, k: float) -> void:
	if phase != "aim" or not _human_turn():
		return
	var i: int = engine.turn
	var t: Dictionary = engine.tanks[i]
	match key:
		"a-":
			engine.set_aim(i, t.angle - k, t.power)
		"a+":
			engine.set_aim(i, t.angle + k, t.power)
		"p-":
			engine.set_aim(i, t.angle, t.power - k)
		"p+":
			engine.set_aim(i, t.angle, t.power + k)
	field.queue_redraw()

func _on_weapon() -> void:
	if phase != "aim":
		return
	engine.cycle_weapon(engine.turn)
	_update_ui()

func _on_fire() -> void:
	if phase != "aim" or not _human_turn() or not started:
		return
	_fire()

func _fire() -> void:
	held.clear()
	engine.fire()
	_sfx("shoot")
	phase = "fly"
	_update_ui()

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	banner_t = maxf(0.0, banner_t - delta)
	shake = maxf(0.0, shake - delta * 2.0)
	for b in booms:
		b[2] += delta
	booms = booms.filter(func(b): return b[2] < 0.7)
	for s in sparks:
		s[0] += s[1] * delta
		s[1].y += 400.0 * delta
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	match phase:
		"aim":
			for key in held:
				if key == "l" or key == "r":
					engine.drive(engine.turn, -1 if key == "l" else 1, delta)
				else:
					_nudge(key, (ANGLE_RATE if key.begins_with("a") else POWER_RATE) * delta)
		"cpu":
			_cpu_step(delta)
		"fly":
			for b in engine.step(delta):
				booms.append([b.p, b.r, 0.0])
				shake = minf(1.0, shake + b.r / 80.0)
				_sfx("explode")
				for n in int(b.r / 2.0):
					sparks.append([b.p, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 340), randf_range(0.3, 0.9), SHELL if n % 2 else HomeKit.PINK])
			if engine.shots.is_empty():
				phase = "settle"
				phase_t = 0.7
		"settle":
			phase_t -= delta
			if phase_t <= 0.0:
				_after_volley()
	field.queue_redraw()

func _after_volley() -> void:
	var shooter: int = engine.turn
	engine.settle()
	var dealt: int = engine.last_hits[1 - shooter]
	if dealt >= 30 and info and _human_turn() and cpu_level >= 0:
		info.add("Direct hits")
	if dealt > 0:
		_show_banner("−%d" % dealt)
	if engine.is_over():
		_game_over()
		return
	_start_turn()

func _cpu_step(delta: float) -> void:
	phase_t += delta
	var i: int = engine.turn
	if cpu_plan.is_empty() and phase_t > 0.5:
		cpu_plan = engine.cpu_aim(i, cpu_level)
		engine.tanks[i].weapon = cpu_plan.weapon
		_update_ui()
	if cpu_plan.is_empty():
		return
	# Swing the barrel towards the plan, then fire.
	var t: Dictionary = engine.tanks[i]
	var da: float = cpu_plan.angle - t.angle
	var dp: float = cpu_plan.power - t.power
	var na: float = t.angle + clampf(da, -90.0 * delta, 90.0 * delta)
	var np: float = t.power + clampf(dp, -70.0 * delta, 70.0 * delta)
	engine.set_aim(i, na, np)
	if absf(da) < 0.5 and absf(dp) < 0.5 and phase_t > 1.2:
		_fire()

func _game_over() -> void:
	phase = "over"
	started = false
	SaveUtil.delete(SAVE_PATH)
	if result_recorded:
		return
	result_recorded = true
	var w: int = engine.winner
	var msg: String
	if w == 2:
		msg = tr("Both cannons destroyed — a draw!")
	elif cpu_level >= 0:
		msg = tr("You win!") if w == 0 else tr("The computer wins!")
	else:
		msg = tr("%s wins!") % _name(w)
	if info:
		if cpu_level >= 0:
			info.result("draw" if w == 2 else ("win" if w == 0 else "loss"))
			if w == 0:
				info.add("Wins (%s)" % LEVELS[cpu_level])
				info.low("Fewest shots to win", ceili(engine.shots_fired / 2.0))
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		else:
			info.add("2-player games")
			info.celebrate(msg)
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	_update_ui()

# ---------- input: drag on the field to aim ----------

func _on_field_input(event: InputEvent) -> void:
	if phase != "aim" or not _human_turn() or not started:
		return
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		pos = event.position
	elif event is InputEventMouseMotion and dragging:
		pos = event.position
	elif event is InputEventScreenDrag:
		pos = event.position
		dragging = true
	else:
		return
	if not dragging and not (event is InputEventMouseButton):
		return
	var g := _geom()
	var w: Vector2 = (pos - g.o) / g.k
	var i: int = engine.turn
	var base := Vector2(engine.tanks[i].x, engine.tanks[i].y - 14.0)
	var d := w - base
	if d.length() < 12.0:
		return
	engine.set_aim(i, rad_to_deg(atan2(-d.y, d.x)), d.length() / 3.0)
	field.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var k: float = minf(field.size.x / CdEngine.W, field.size.y / CdEngine.H)
	var o := Vector2((field.size.x - CdEngine.W * k) / 2.0, field.size.y - CdEngine.H * k)
	if shake > 0.0:
		o += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 8.0
	return {"k": k, "o": o}

func _draw_field() -> void:
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var c := field
	c.draw_rect(Rect2(Vector2.ZERO, field.size), Color(0.015, 0.015, 0.045))
	for s in stars:
		c.draw_circle(o + s[0] * k, s[1], Color(1, 1, 1, 0.3))
	# Ground: dark fill, glowing outline, faint strata.
	var pts := PackedVector2Array()
	for i in CdEngine.COLS:
		pts.append(o + Vector2(i * CdEngine.STEP, engine.ground[i]) * k)
	var fill := pts.duplicate()
	fill.append(o + Vector2(CdEngine.W, CdEngine.H) * k)
	fill.append(o + Vector2(0, CdEngine.H) * k)
	c.draw_colored_polygon(fill, Color(GROUND, 0.13))
	for layer in [40.0, 90.0]:
		var lp := PackedVector2Array()
		for p in pts:
			lp.append(p + Vector2(0, layer * k))
		c.draw_polyline(lp, Color(GROUND, 0.18), 1.0, true)
	HomeKit.glow_polyline(c, pts, GROUND, 2.0)
	# Cannons.
	for i in 2:
		var t: Dictionary = engine.tanks[i]
		_draw_cannon(c, o + Vector2(t.x, t.y) * k, k, t.angle, P_COLORS[i], t.hp > 0)
		# Armour bar over each cannon.
		var bp := o + Vector2(t.x - 30, t.y - 58) * k
		c.draw_rect(Rect2(bp, Vector2(60, 7) * k), Color(1, 1, 1, 0.12))
		c.draw_rect(Rect2(bp, Vector2(60.0 * t.hp / CdEngine.MAX_HP, 7) * k), P_COLORS[i] if t.hp > 30 else HomeKit.PINK)
	# Aim guide for whoever is aiming.
	if phase == "aim" or phase == "cpu":
		var i: int = engine.turn
		var t: Dictionary = engine.tanks[i]
		var a := deg_to_rad(t.angle)
		var dir := Vector2(cos(a), -sin(a))
		var m: Vector2 = engine.muzzle(i)
		var n := int(t.power / 8.0)
		for j in n:
			var p := o + (m + dir * (14.0 + j * 14.0)) * k
			c.draw_circle(p, 2.6 * k, Color(P_COLORS[i], 1.0 - float(j) / n * 0.8))
	# Shells and their trails; one above the screen shows as a marker.
	for s in engine.shots:
		var tr_pts := PackedVector2Array()
		for p in s.trail:
			tr_pts.append(o + p * k)
		tr_pts.append(o + s.p * k)
		if tr_pts.size() > 1:
			c.draw_polyline(tr_pts, Color(SHELL, 0.35), 2.0, true)
		var sp: Vector2 = o + s.p * k
		if sp.y < 0:
			HomeKit.glow_polyline(c, PackedVector2Array([Vector2(sp.x - 8, 14), Vector2(sp.x, 4), Vector2(sp.x + 8, 14)]), SHELL, 2.0)
		else:
			c.draw_circle(sp, 6.0 * k, HomeKit.WHITE)
			HomeKit.glow_circle(c, sp, 6.0 * k, SHELL, 2.0)
	for b in booms:
		var t: float = b[2] / 0.7
		var col := SHELL.lerp(HomeKit.PINK, t)
		c.draw_circle(o + b[0] * k, b[1] * k * (0.4 + t * 0.7), Color(col, 0.35 * (1.0 - t)))
		HomeKit.glow_circle(c, o + b[0] * k, b[1] * k * (0.4 + t * 0.7), Color(col, 1.0 - t), 2.0)
	for s in sparks:
		var p: Vector2 = o + s[0] * k
		c.draw_line(p, p - s[1] * 0.025 * k, Color(s[3], clampf(s[2] * 2.0, 0.0, 1.0)), 2.0)
	_draw_hud(c, o, k)

func _draw_hud(c: CanvasItem, o: Vector2, k: float) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(clampf(22 * k, 14, 26))
	var top: float = maxf(o.y, 0.0) + 10.0
	# Armour of both sides, in their corners.
	for i in 2:
		var t: Dictionary = engine.tanks[i]
		var x := 12.0 if i == 0 else field.size.x - 200.0
		c.draw_string(font, Vector2(x, top + fs), "%s  %d" % [_name(i), t.hp], HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT, 188, fs, P_COLORS[i])
	# Wind, top middle.
	var mid := field.size.x / 2.0
	c.draw_string(font, Vector2(mid - 100, top + fs), tr("Wind"), HORIZONTAL_ALIGNMENT_CENTER, 200, fs - 4, HomeKit.DIM)
	var wl: float = engine.wind / CdEngine.WIND_MAX * 70.0
	var wy := top + fs + 18.0
	if absf(wl) < 3.0:
		c.draw_string(font, Vector2(mid - 100, wy + 8), tr("calm"), HORIZONTAL_ALIGNMENT_CENTER, 200, fs - 4, HomeKit.LIME)
	else:
		HomeKit.glow_line(c, Vector2(mid - wl, wy), Vector2(mid + wl, wy), HomeKit.LIME, 2.0)
		var tip := Vector2(mid + wl, wy)
		var back := -signf(wl) * 10.0
		HomeKit.glow_polyline(c, PackedVector2Array([tip + Vector2(back, -7), tip, tip + Vector2(back, 7)]), HomeKit.LIME, 2.0)
	# Angle, power and fuel of whoever is playing.
	var t: Dictionary = engine.tanks[engine.turn]
	var col: Color = P_COLORS[engine.turn]
	var y := top + fs * 2.0 + 34.0
	var left := 12.0 if engine.turn == 0 else field.size.x - 200.0
	var al := HORIZONTAL_ALIGNMENT_LEFT if engine.turn == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	c.draw_string(font, Vector2(left, y), tr("Angle %d°") % int(roundf(t.angle)), al, 188, fs, col.lerp(Color.WHITE, 0.3))
	c.draw_string(font, Vector2(left, y + fs + 6), tr("Power %d") % int(roundf(t.power)), al, 188, fs, col.lerp(Color.WHITE, 0.3))
	c.draw_string(font, Vector2(left, y + 2 * fs + 12), tr("Fuel %d") % int(t.fuel), al, 188, fs - 4, HomeKit.DIM)
	if banner_t > 0.0 and banner != "":
		HomeKit.glow_text(c, Vector2(field.size.x / 2.0, field.size.y * 0.3), banner, int(clampf(40 * k, 26, 46)), HomeKit.WHITE)

func _draw_cannon(c: CanvasItem, p: Vector2, k: float, angle: float, col: Color, alive: bool) -> void:
	if not alive:
		col = Color(col, 0.35)
	var a := deg_to_rad(angle)
	var pivot := p + Vector2(0, -14) * k
	HomeKit.glow_line(c, pivot, pivot + Vector2(cos(a), -sin(a)) * 26.0 * k, col, 3.0)
	var body := PackedVector2Array([p + Vector2(-22, 0) * k, p + Vector2(22, 0) * k, p + Vector2(16, -10) * k, p + Vector2(-16, -10) * k])
	c.draw_colored_polygon(body, Color(col, 0.2))
	HomeKit.glow_polyline(c, body, col, 2.0, true)
	c.draw_arc(pivot, 9.0 * k, PI, TAU, 16, col, 2.0, true)
	for wx in [-13.0, 0.0, 13.0]:
		c.draw_circle(p + Vector2(wx, -2) * k, 3.5 * k, Color(col, 0.7))

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 150.0, 1.5)
	var o := c.size / 2.0
	var pts := PackedVector2Array()
	for i in 41:
		var x := -160.0 + i * 8.0
		var y := 50.0 - 46.0 * exp(-pow(x / 60.0, 2.0)) + sin(i * 0.7) * 4.0
		pts.append(o + Vector2(x, y) * k)
	HomeKit.glow_polyline(c, pts, GROUND, 2.0)
	_draw_cannon(c, o + Vector2(-125, 48) * k, k, 55.0, P_COLORS[0], true)
	_draw_cannon(c, o + Vector2(125, 48) * k, k, 128.0, P_COLORS[1], true)
	var arc := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		arc.append(o + Vector2(-105 + t * 190.0, 20 - 150.0 * t + 150.0 * t * t) * k)
	for i in range(0, arc.size() - 1, 2):
		c.draw_line(arc[i], arc[i + 1], Color(SHELL, 0.7), 2.0)
	c.draw_circle(arc[arc.size() - 1], 5 * k, HomeKit.WHITE)
	HomeKit.glow_circle(c, o + Vector2(95, 28) * k, 18 * k, SHELL, 2.0, 0.2)

# ---------- pause / save ----------

func _on_pause() -> void:
	held.clear()
	home.pause()

func _go_home() -> void:
	home.go_home()

func _save_game() -> void:
	if not started or engine.is_over():
		return
	SaveUtil.write(SAVE_PATH, {"engine": engine.to_dict(), "cpu": cpu_level})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null:
		return ""
	var cpu := int(d.get("cpu", 1))
	return tr("2 Players") if cpu < 0 else tr("vs Computer") + " (" + tr(LEVELS[clampi(cpu, 0, 2)]) + ")"

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	if d == null or not d.has("engine"):
		_new_game(1)
		return
	cpu_level = int(d.get("cpu", 1))
	engine.from_dict(d.engine)
	_begin()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
