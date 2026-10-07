extends Control

## Pool: 8-ball on a neon table. Drag on the table to aim (the guide shows
## the first ball you'll hit and where it goes), set the power, shoot.
## Vs the computer (3 levels) or two players on one phone.

const PoolEngine = preload("res://scripts/games/pool/pool_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/pool/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/pool/pool_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://pool_save.json"

const LEVELS := ["Easy", "Normal", "Hard"]
const RAIL := 26.0            # cushion width drawn round the playing surface
const FELT := Color(0.02, 0.06, 0.09)
const RAIL_COL := Color("9b4dff")
const P_COLORS := [Color("29e6ff"), Color("ff2bd6")]
const BALL_COLS := {1: Color("ffd23b"), 2: Color("3a8cff"), 3: Color("ff3b4f"), 4: Color("9b4dff"), 5: Color("ff8a2b"),
	6: Color("3bff7d"), 7: Color("c0306a")}

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var cpu_level: int = 1        # -1 = two players
var started := false
var result_recorded := false
var phase := "aim"            # aim, roll, cpu, over
var phase_t: float = 0.0
var aim: float = -PI / 2.0
var power: float = 0.6
var dragging := ""            # "", "aim", "cue"
var cpu_plan: Dictionary = {}
var cpu_task: int = -1        # WorkerThreadPool task thinking up the computer's shot
var cpu_result: Dictionary = {}
var snapshot: Dictionary = {} # the table before the current shot (for saving)
var run: int = 0              # balls potted this visit
var held_turn: int = 0
var banner := ""
var banner_t: float = 0.0

var field: Control
var p_labels: Array = []
var power_bar: Control
var shoot_btn: Button
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/pool/pool_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = PoolEngine.new()
	engine.reset()
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
	for i in 2:
		var l := HomeKit.label("", 22, P_COLORS[i], true, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.add_child(l)
		p_labels.append(l)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(56, 0)
	bar.add_child(spacer)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_left", 8)
	fm.add_theme_constant_override("margin_right", 8)
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
	cm.add_theme_constant_override("margin_left", 14)
	cm.add_theme_constant_override("margin_right", 14)
	root.add_child(cm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	cm.add_child(row)
	row.add_child(_fine_button("⟲", -1))
	power_bar = Control.new()
	power_bar.custom_minimum_size = Vector2(0, 84)
	power_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	power_bar.draw.connect(_draw_power)
	power_bar.gui_input.connect(_on_power_input)
	row.add_child(power_bar)
	row.add_child(_fine_button("⟳", 1))
	shoot_btn = HomeKit.neon_button("🎱 " + tr("Shoot"), HomeKit.LIME, 26, 84)
	shoot_btn.custom_minimum_size.x = 150
	shoot_btn.set_meta("sfx", "")
	shoot_btn.pressed.connect(_on_shoot)
	row.add_child(shoot_btn)

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
		"accent": HomeKit.LIME,
		"solo_heading": "vs Computer",
		"subtitle": "8-ball. Solids or stripes, then the black. Chalk up.",
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
	drawer.set("default_frac", 0.05)  # top right, off the table
	add_child(drawer)

func _fine_button(text: String, dir: int) -> Button:
	var b := HomeKit.neon_button(text, HomeKit.CYAN, 34, 84)
	b.custom_minimum_size.x = 84
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("sfx", "")
	b.button_down.connect(_fine_down.bind(dir))
	b.button_up.connect(_fine_up)
	return b

func _fine_down(dir: int) -> void:
	held_turn = dir
	_turn_aim(dir * 0.004)

func _fine_up() -> void:
	held_turn = 0

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
	end_dialog.visible = false
	run = 0
	_start_turn()

func _human() -> bool:
	return cpu_level < 0 or engine.turn == 0

func _name(i: int) -> String:
	if cpu_level >= 0:
		return tr("You") if i == 0 else tr("Computer")
	return tr("Player %d") % (i + 1)

func _start_turn() -> void:
	snapshot = engine.to_dict()
	if engine.ball_in_hand and not engine.break_shot:
		_show_banner(tr("Ball in hand: %s") % _name(engine.turn))
	if _human():
		phase = "aim"
		# Point at something sensible to start with.
		var t: Array = engine.targets(engine.turn)
		if not t.is_empty() and not engine.break_shot:
			var c: Array = engine.candidates(engine.turn)
			var target: Vector2 = engine.balls[t[0]].p if c.is_empty() else engine.balls[0].p + c[0].dir
			aim = (target - engine.balls[0].p).angle()
		elif engine.break_shot:
			aim = -PI / 2.0
	else:
		phase = "cpu"
		phase_t = 0.0
		cpu_plan = {}
	_update_ui()

func _show_banner(text: String, t: float = 1.8) -> void:
	banner = text
	banner_t = t

func _update_ui() -> void:
	for i in 2:
		var g: int = engine.groups[i]
		var what := ""
		if g >= 0:
			what = "\n" + (tr("Solids") if g == 0 else tr("Stripes")) + " · %d" % engine.remaining(g)
			if engine.remaining(g) == 0:
				what = "\n" + tr("On the 8")
		var mark := "▶ " if engine.turn == i and phase != "over" else ""
		p_labels[i].text = mark + _name(i) + what
		p_labels[i].modulate.a = 1.0 if engine.turn == i else 0.5
	var mine := phase == "aim" and _human()
	shoot_btn.disabled = not mine
	power_bar.modulate.a = 1.0 if mine else 0.4
	field.queue_redraw()
	power_bar.queue_redraw()

func _turn_aim(d: float) -> void:
	if phase == "aim" and _human():
		aim = wrapf(aim + d, -PI, PI)
		field.queue_redraw()

func _on_shoot() -> void:
	if phase != "aim" or not _human() or not started:
		return
	_shoot(Vector2.RIGHT.rotated(aim), power)

func _shoot(dir: Vector2, p: float) -> void:
	snapshot = engine.to_dict()
	engine.shoot(dir, p)
	_sfx("hit")
	phase = "roll"
	_update_ui()

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	banner_t = maxf(0.0, banner_t - delta)
	if held_turn != 0:
		_turn_aim(held_turn * 0.12 * delta)
	match phase:
		"roll":
			for e in engine.step(delta):
				match e:
					"click":
						_sfx("tick")
					"rail":
						_sfx("tap")
					"pot":
						_sfx("pickup")
			if not engine.moving:
				_after_shot()
		"cpu":
			_cpu_step(delta)
	field.queue_redraw()

func _after_shot() -> void:
	var shooter: int = engine.turn
	var res: Dictionary = engine.resolve()
	var own := 0
	for n in res.potted:
		if n != 0 and n != 8 and (engine.groups[shooter] < 0 or PoolEngine.group_of(n) == engine.groups[shooter]):
			own += 1
	if res.winner >= 0:
		_game_over(res)
		return
	if own > 0 and not res.foul:
		run += own
		if info and _is_me(shooter):
			info.add("Balls potted", own)
			info.high("Longest run", run)
	if res.foul:
		_sfx("invalid")
		_show_banner(tr("Foul: %s") % tr(res.reason) + "\n" + tr("Ball in hand: %s") % _name(engine.turn), 2.4)
	elif res.assigned:
		var g: int = engine.groups[shooter]
		_show_banner(_name(shooter) + ": " + (tr("Solids") if g == 0 else tr("Stripes")), 2.0)
	if not res.again:
		run = 0
	_start_turn()

## The phone's owner: player 1 vs the computer (stats count only them).
func _is_me(p: int) -> bool:
	return cpu_level >= 0 and p == 0

## The computer thinks on a worker thread (Hard tries shots for real), so
## the screen keeps moving.
func _cpu_think() -> void:
	cpu_result = engine.cpu_shot(cpu_level)

func _exit_tree() -> void:
	if cpu_task >= 0:
		WorkerThreadPool.wait_for_task_completion(cpu_task)
		cpu_task = -1

func _cpu_step(delta: float) -> void:
	phase_t += delta
	if cpu_plan.is_empty() and cpu_task < 0 and phase_t > 0.6:
		cpu_result = {}
		cpu_task = WorkerThreadPool.add_task(_cpu_think)
	if cpu_task >= 0:
		if not WorkerThreadPool.is_task_completed(cpu_task):
			return
		WorkerThreadPool.wait_for_task_completion(cpu_task)
		cpu_task = -1
		cpu_plan = cpu_result
		var from: Vector2 = engine.balls[0].p
		var target: Vector2 = from + cpu_plan.dir
		phase_t = 0.6
		cpu_plan["angle"] = (target - from).angle()
	if cpu_plan.is_empty():
		return
	var da := wrapf(cpu_plan.angle - aim, -PI, PI)
	aim = wrapf(aim + clampf(da, -2.5 * delta, 2.5 * delta), -PI, PI)
	power = move_toward(power, cpu_plan.power, delta * 1.5)
	power_bar.queue_redraw()
	if absf(da) < 0.002 and absf(power - cpu_plan.power) < 0.01 and phase_t > 1.4:
		_shoot(cpu_plan.dir, cpu_plan.power)

func _game_over(res: Dictionary) -> void:
	phase = "over"
	started = false
	SaveUtil.delete(SAVE_PATH)
	_update_ui()
	if result_recorded:
		return
	result_recorded = true
	var w: int = res.winner
	var msg: String
	var how := tr("Sank the 8!") if not res.foul else tr("The 8 went down early — or with a foul.")
	if cpu_level >= 0:
		msg = tr("You win!") if w == 0 else tr("The computer wins!")
	else:
		msg = tr("%s wins!") % _name(w)
	msg = how + "\n" + msg
	if info:
		if cpu_level >= 0:
			info.result("win" if w == 0 else "loss")
			if w == 0:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
		else:
			info.add("2-player games")
			info.celebrate(msg)
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- input ----------

func _on_field_input(event: InputEvent) -> void:
	if phase != "aim" or not _human() or not started:
		return
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging = ""
			return
		pos = event.position
		var w := _to_world(pos)
		if engine.ball_in_hand and w.distance_to(engine.balls[0].p) < PoolEngine.R * 3.5:
			dragging = "cue"
		else:
			dragging = "aim"
	elif event is InputEventMouseMotion and dragging != "":
		pos = event.position
	else:
		return
	var w := _to_world(pos)
	if dragging == "cue":
		var p := Vector2(clampf(w.x, PoolEngine.R, PoolEngine.W - PoolEngine.R), clampf(w.y, PoolEngine.R, PoolEngine.H - PoolEngine.R))
		if engine.break_shot:
			p.y = maxf(p.y, PoolEngine.KITCHEN_Y)
		engine.place_cue(p)
	elif dragging == "aim":
		var d: Vector2 = w - engine.balls[0].p
		if d.length() > PoolEngine.R:
			aim = d.angle()
	field.queue_redraw()

func _on_power_input(event: InputEvent) -> void:
	if phase != "aim" or not _human():
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		power = clampf((event.position.x - 10.0) / (power_bar.size.x - 20.0), 0.05, 1.0)
		power_bar.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var tw := PoolEngine.W + RAIL * 2.0
	var th := PoolEngine.H + RAIL * 2.0
	var k: float = minf(field.size.x / tw, field.size.y / th)
	var o := (field.size - Vector2(tw, th) * k) / 2.0 + Vector2(RAIL, RAIL) * k
	return {"k": k, "o": o}

func _to_world(p: Vector2) -> Vector2:
	var g := _geom()
	return (p - g.o) / g.k

func _draw_field() -> void:
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var c := field
	var surf := Rect2(o, Vector2(PoolEngine.W, PoolEngine.H) * k)
	var outer := surf.grow(RAIL * k)
	c.draw_rect(outer, Color(0.05, 0.02, 0.09))
	HomeKit.glow_rect(c, outer, RAIL_COL, 2.0)
	c.draw_rect(surf, FELT)
	HomeKit.glow_rect(c, surf, Color(HomeKit.CYAN, 0.6), 1.2)
	# Diamonds on the rails, the head string and the foot spot.
	for i in range(1, 4):
		for sd in [-1.0, 1.0]:
			var x := surf.position.x + surf.size.x * i / 4.0
			c.draw_circle(Vector2(x, surf.get_center().y + sd * (surf.size.y / 2.0 + RAIL * k * 0.5)), 2.5, Color(1, 1, 1, 0.6))
	for i in range(1, 8):
		if i == 4:
			continue
		for sd in [-1.0, 1.0]:
			var y := surf.position.y + surf.size.y * i / 8.0
			c.draw_circle(Vector2(surf.get_center().x + sd * (surf.size.x / 2.0 + RAIL * k * 0.5), y), 2.5, Color(1, 1, 1, 0.6))
	var ky := o.y + PoolEngine.KITCHEN_Y * k
	c.draw_line(Vector2(surf.position.x, ky), Vector2(surf.end.x, ky), Color(1, 1, 1, 0.12 if not engine.break_shot else 0.3), 1.0)
	c.draw_circle(o + PoolEngine.FOOT * k, 2.5, Color(1, 1, 1, 0.3))
	for i in PoolEngine.POCKETS.size():
		var pr: float = (PoolEngine.CORNER_R if i != 2 and i != 3 else PoolEngine.SIDE_R) * k
		var pp: Vector2 = o + PoolEngine.POCKETS[i] * k
		c.draw_circle(pp, pr, Color.BLACK)
		HomeKit.glow_circle(c, pp, pr, RAIL_COL, 1.5)
	# Guide line.
	if phase == "aim" or phase == "cpu":
		_draw_guide(c, o, k)
	for b in engine.balls:
		if b.in:
			_draw_ball(c, o + b.p * k, PoolEngine.R * k, b.n)
	if engine.ball_in_hand and phase == "aim" and _human():
		var cp: Vector2 = o + engine.balls[0].p * k
		var r := PoolEngine.R * k * 2.2 + sin(Time.get_ticks_msec() / 200.0) * 2.0
		c.draw_arc(cp, r, 0, TAU, 32, Color(HomeKit.LIME, 0.8), 2.0, true)
	if banner_t > 0.0:
		var lines := banner.split("\n")
		for i in lines.size():
			HomeKit.glow_text(c, Vector2(field.size.x / 2.0, field.size.y * 0.45 + i * 40.0), lines[i], int(clampf(field.size.x / 18.0, 20, 36)), HomeKit.WHITE)

func _draw_guide(c: CanvasItem, o: Vector2, k: float) -> void:
	var cue: Vector2 = engine.balls[0].p
	var dir := Vector2.RIGHT.rotated(aim)
	var hit: Dictionary = engine.first_contact(cue, dir)
	var col := Color(1, 1, 1, 0.7)
	if hit.is_empty():
		var end := cue + dir * 1400.0
		c.draw_line(o + cue * k, o + end * k, Color(1, 1, 1, 0.35), 1.5, true)
		return
	var ghost: Vector2 = hit.ghost
	var obj: Vector2 = engine.balls[hit.n].p
	var legal: bool = engine.break_shot or engine.targets(engine.turn).has(hit.n)
	if not legal:
		col = Color(HomeKit.PINK, 0.8)
	c.draw_line(o + cue * k, o + ghost * k, col, 1.5, true)
	c.draw_arc(o + ghost * k, PoolEngine.R * k, 0, TAU, 24, col, 1.5, true)
	var od := (obj - ghost).normalized()
	c.draw_line(o + obj * k, o + (obj + od * 140.0) * k, Color(col, 0.6), 2.0, true)
	# Where the cue ball heads after the hit (90° to the object ball's path).
	var tang := dir - od * dir.dot(od)
	if tang.length() > 0.05:
		c.draw_line(o + ghost * k, o + (ghost + tang.normalized() * 70.0 * tang.length()) * k, Color(1, 1, 1, 0.25), 1.5, true)
	# The cue stick, pulled back by the power.
	var back := cue - dir * (PoolEngine.R + 10.0 + power * 60.0)
	var butt := back - dir * 300.0
	HomeKit.glow_line(c, o + back * k, o + butt * k, HomeKit.GOLD, 3.0)
	c.draw_line(o + back * k, o + (back - dir * 8.0) * k, HomeKit.WHITE, 4.0)

func _draw_ball(c: CanvasItem, p: Vector2, r: float, n: int) -> void:
	if n == 0:
		c.draw_circle(p, r, Color(0.92, 0.95, 1.0))
		HomeKit.glow_circle(c, p, r, HomeKit.WHITE, 1.2)
		return
	if n == 8:
		c.draw_circle(p, r, Color(0.06, 0.06, 0.08))
		HomeKit.glow_circle(c, p, r, Color(0.8, 0.8, 0.9), 1.2)
	else:
		var col: Color = BALL_COLS[n if n < 8 else n - 8]
		if n < 8:
			c.draw_circle(p, r, col.darkened(0.15))
		else:
			c.draw_circle(p, r, Color(0.9, 0.92, 0.96))
			var band := PackedVector2Array()
			for i in 25:
				var a := TAU * i / 24.0
				band.append(p + Vector2(cos(a), clampf(sin(a), -0.55, 0.55)) * r)
			c.draw_colored_polygon(band, col.darkened(0.15))
		HomeKit.glow_circle(c, p, r, col, 1.2)
	if r >= 11.0:
		c.draw_circle(p, r * 0.45, Color(1, 1, 1, 0.9))
		var font := ThemeDB.fallback_font
		var fs := int(r * 0.75)
		c.draw_string(font, p + Vector2(-r, fs * 0.36), str(n), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(0.05, 0.05, 0.08))
	c.draw_circle(p + Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.5))

func _draw_power() -> void:
	var c := power_bar
	var s := power_bar.size
	var r := Rect2(Vector2(10, s.y * 0.3), Vector2(s.x - 20, s.y * 0.4))
	c.draw_rect(r, Color(1, 1, 1, 0.08))
	var col := HomeKit.LIME.lerp(HomeKit.PINK, power)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * power, r.size.y)), Color(col, 0.7))
	HomeKit.glow_rect(c, r, col, 1.5)
	c.draw_string(ThemeDB.fallback_font, Vector2(10, s.y * 0.26), tr("Power %d%%") % int(power * 100), HORIZONTAL_ALIGNMENT_CENTER, s.x - 20, 18, HomeKit.DIM)

func _draw_home_logo(c: Control) -> void:
	var s := c.size
	var k := minf(s.y / 170.0, 1.4)
	var o := s / 2.0
	var r := 14.0 * k
	var tri := [1, 9, 2, 10, 8, 3]
	var idx := 0
	for row in 3:
		for j in row + 1:
			_draw_ball(c, o + Vector2((j - row / 2.0) * r * 2.05 + 40 * k, -row * r * 1.8 - 10 * k), r, tri[idx])
			idx += 1
	HomeKit.glow_rect(c, Rect2(o - Vector2(170, 75) * k, Vector2(340, 150) * k), RAIL_COL, 2.0)
	for p in [Vector2(-170, -75), Vector2(170, -75), Vector2(-170, 75), Vector2(170, 75), Vector2(0, -75), Vector2(0, 75)]:
		c.draw_circle(o + p * k, 9 * k, Color.BLACK)
		HomeKit.glow_circle(c, o + p * k, 9 * k, RAIL_COL, 1.2)
	var cue := o + Vector2(-80, 40) * k
	_draw_ball(c, cue, r, 0)
	HomeKit.glow_line(c, cue + Vector2(-22, 14) * k, cue + Vector2(-150, 90) * k, HomeKit.GOLD, 3.0)
	c.draw_line(cue + Vector2(-20, 4) * k, cue + Vector2(110, -50) * k, Color(1, 1, 1, 0.35), 1.5)

# ---------- pause / save ----------

func _on_pause() -> void:
	dragging = ""
	held_turn = 0
	home.pause()

func _go_home() -> void:
	home.go_home()

## The table as it was before the shot in progress (or now, if still).
func _save_game() -> void:
	if not started or phase == "over" or engine.winner >= 0:
		return
	var d: Dictionary = snapshot if engine.moving or phase == "roll" else engine.to_dict()
	if d.is_empty():
		return
	SaveUtil.write(SAVE_PATH, {"engine": d, "cpu": cpu_level})

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
	started = true
	result_recorded = false
	end_dialog.visible = false
	run = 0
	_start_turn()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
