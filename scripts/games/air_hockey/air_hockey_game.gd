extends Control

## Air Hockey: drag your mallet in your half and knock the puck into the
## other goal. Vs the computer (you're at the bottom) or two players on one
## phone, one at each end (multi-touch).

const AhEngine = preload("res://scripts/games/air_hockey/air_hockey_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/air_hockey/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/air_hockey/air_hockey_help.gd")
const TITLE_FOR_HOME := HELP.TITLE

const LEVELS := ["Easy", "Normal", "Hard"]
const P_COLORS := [Color("29e6ff"), Color("ff2bd6")]
const PUCK := Color("ffae2b")

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var cpu_level: int = 1   # -1 = two players
var started := false
var result_recorded := false
var touches: Dictionary = {}  # touch index -> player
var touch_seen := false
var flash_t: float = 0.0
var flash_col := Color.WHITE

var field: Control
var score_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/air_hockey/air_hockey_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = AhEngine.new()
	_build_ui()
	engine.reset()

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
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76, 0)
	bar.add_child(spacer)

	var fm := MarginContainer.new()
	fm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fm.add_theme_constant_override("margin_left", 10)
	fm.add_theme_constant_override("margin_right", 10)
	fm.add_theme_constant_override("margin_bottom", 22)
	root.add_child(fm)
	field = Control.new()
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	field.resized.connect(field.queue_redraw)
	fm.add_child(field)

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
	modes.append({"text": "👥 2 Players", "sub": "One at each end of the phone", "multi": true, "action": _new_game.bind(-1)})
	home = HomeKit.new({
		"retro": true,
		"help": HELP,
		"info": info,
		"accent": P_COLORS[0],
		"solo_heading": "vs Computer",
		"subtitle": "Drag your mallet, smash the puck, first to 7.",
		"logo": _draw_home_logo,
		"modes": modes,
		"restart": _restart,
		"board": "Wins",
		"board_note": "Games won against the computer, at any level.",
	})
	add_child(home)
	if info:
		add_child(info)
	var drawer := SettingsDrawer.new()
	drawer.set("default_frac", 0.05)  # right of the score, off the table
	add_child(drawer)

# ---------- flow ----------

func _new_game(level: int) -> void:
	cpu_level = level
	_restart()

func _restart() -> void:
	engine.reset()
	started = true
	result_recorded = false
	touches.clear()
	end_dialog.visible = false
	_update_score()

func _update_score() -> void:
	score_label.text = "%d  :  %d" % [engine.score[0], engine.score[1]]
	score_label.add_theme_color_override("font_color", Color(1, 1, 1))

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	if cpu_level >= 0:
		engine.aim(1, engine.cpu_target(cpu_level))
	var ev: Array = engine.step(delta)
	for e in ev:
		match e:
			"hit":
				_sfx("hit")
			"wall":
				_sfx("tick")
			"goal1", "goal2":
				_sfx("explode")
				flash_t = 0.6
				flash_col = P_COLORS[0] if e == "goal1" else P_COLORS[1]
				_update_score()
	flash_t = maxf(0.0, flash_t - delta)
	if engine.winner != 0 and not result_recorded:
		_game_over()
	field.queue_redraw()

func _game_over() -> void:
	result_recorded = true
	started = false
	var w: int = engine.winner
	var msg: String
	if cpu_level >= 0:
		msg = tr("You win!") if w == 1 else tr("The computer wins!")
		if info:
			info.result("win" if w == 1 else "loss")
			if w == 1:
				info.add("Wins (%s)" % LEVELS[cpu_level])
			msg += "\n" + info.summary(["Wins", "Losses", "Best streak"])
	else:
		msg = tr("Bottom player wins!") if w == 1 else tr("Top player wins!")
		if info:
			info.add("2-player games")
			info.celebrate(msg)
	msg = "%d : %d\n" % [engine.score[0], engine.score[1]] + msg
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- input ----------

func _to_world(p: Vector2) -> Vector2:
	var g := _geom()
	return (p - g.o) / g.k

func _player_for(p: Vector2) -> int:
	var w := _to_world(p)
	var who := 0 if w.y > AhEngine.H / 2.0 else 1
	if cpu_level >= 0:
		who = 0
	return who

func _on_field_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventScreenTouch:
		touch_seen = true
		if event.pressed:
			touches[event.index] = _player_for(event.position)
			engine.aim(touches[event.index], _to_world(event.position))
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touch_seen = true
		if touches.has(event.index):
			engine.aim(touches[event.index], _to_world(event.position))
	elif not touch_seen:
		# Mouse on a PC: drag the bottom mallet (or whichever half you click).
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			touches[-1] = _player_for(event.position)
			engine.aim(touches[-1], _to_world(event.position))
		elif event is InputEventMouseButton and not event.pressed:
			touches.erase(-1)
		elif event is InputEventMouseMotion and touches.has(-1):
			engine.aim(touches[-1], _to_world(event.position))

# ---------- drawing ----------

func _geom() -> Dictionary:
	var k: float = minf(field.size.x / AhEngine.W, field.size.y / AhEngine.H)
	var o := (field.size - Vector2(AhEngine.W, AhEngine.H) * k) / 2.0
	return {"k": k, "o": o}

func _draw_field() -> void:
	var g := _geom()
	var k: float = g.k
	var o: Vector2 = g.o
	var rect := Rect2(o, Vector2(AhEngine.W, AhEngine.H) * k)
	field.draw_rect(rect, Color(0.02, 0.03, 0.08))
	if flash_t > 0.0:
		field.draw_rect(rect, Color(flash_col, flash_t * 0.3))
	HomeKit.glow_rect(field, rect, HomeKit.PURPLE, 2.0)
	var mid_y: float = o.y + AhEngine.H / 2.0 * k
	field.draw_line(Vector2(rect.position.x, mid_y), Vector2(rect.end.x, mid_y), Color(HomeKit.PURPLE, 0.5), 2.0)
	field.draw_arc(Vector2(rect.get_center().x, mid_y), 16 * k, 0, TAU, 48, Color(HomeKit.PURPLE, 0.4), 2.0, true)
	var gw := AhEngine.GOAL_W * k
	HomeKit.glow_line(field, Vector2(rect.get_center().x - gw / 2.0, rect.position.y), Vector2(rect.get_center().x + gw / 2.0, rect.position.y), P_COLORS[1], 5.0)
	HomeKit.glow_line(field, Vector2(rect.get_center().x - gw / 2.0, rect.end.y), Vector2(rect.get_center().x + gw / 2.0, rect.end.y), P_COLORS[0], 5.0)
	var font := ThemeDB.fallback_font
	field.draw_string(font, Vector2(rect.position.x, mid_y + 40 * k), str(engine.score[0]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(30 * k), Color(P_COLORS[0], 0.25))
	field.draw_string(font, Vector2(rect.position.x, mid_y - 30 * k), str(engine.score[1]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(30 * k), Color(P_COLORS[1], 0.25))
	for p in 2:
		var c: Vector2 = o + engine.mallets[p] * k
		field.draw_circle(c, AhEngine.MALLET_R * k, Color(P_COLORS[p], 0.3))
		HomeKit.glow_circle(field, c, AhEngine.MALLET_R * k, P_COLORS[p], 2.5)
		HomeKit.glow_circle(field, c, AhEngine.MALLET_R * k * 0.45, P_COLORS[p], 2.0)
	var pc: Vector2 = o + engine.puck * k
	field.draw_circle(pc, AhEngine.PUCK_R * k, Color(PUCK, 0.6))
	HomeKit.glow_circle(field, pc, AhEngine.PUCK_R * k, PUCK, 2.0)

func _draw_home_logo(c: Control) -> void:
	var k := minf(c.size.y / 4.0, 40.0)
	var o := c.size / 2.0
	HomeKit.glow_rect(c, Rect2(o - Vector2(k * 1.6, k * 1.9), Vector2(k * 3.2, k * 3.8)), HomeKit.PURPLE, 2.0, 0.05)
	HomeKit.glow_circle(c, o + Vector2(-k * 0.5, k * 1.0), k * 0.5, P_COLORS[0], 2.5, 0.3)
	HomeKit.glow_circle(c, o + Vector2(k * 0.4, -k * 1.0), k * 0.5, P_COLORS[1], 2.5, 0.3)
	HomeKit.glow_circle(c, o + Vector2(k * 0.2, k * 0.1), k * 0.28, PUCK, 2.0, 0.6)
	for i in 3:
		c.draw_circle(o + Vector2(-k * 0.1 - i * k * 0.15, k * 0.35 + i * k * 0.2), 3.0, Color(PUCK, 0.6 - i * 0.18))

# ---------- pause ----------

func _on_pause() -> void:
	touches.clear()
	home.pause()

func _go_home() -> void:
	home.go_home()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
