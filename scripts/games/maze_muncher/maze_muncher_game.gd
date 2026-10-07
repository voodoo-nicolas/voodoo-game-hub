extends Control

## Maze Muncher: swipe to steer through the maze, eat every dot, and turn
## the tables on the spirits with a power dot. The look is our own, not the
## famous maze game's (yellow chomper, skirted ghosts in red / pink / cyan /
## orange that turn blue): a cyan muncher and four skull spirits that go pale
## when scared (docs/ip-audit-2026-10-06.md). Code ids still say "ghost".

const MmEngine = preload("res://scripts/games/maze_muncher/maze_muncher_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
const UI = preload("res://scripts/common/ui.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/maze_muncher/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/maze_muncher/maze_muncher_help.gd")
const TITLE_FOR_HOME := HELP.TITLE
const SAVE_PATH := "user://maze_muncher_save.json"

const WALL := Color("3a8cff")
const DOT := Color(1.0, 0.85, 0.7)
const PLAYER := Color("29e6ff")
const GHOSTS := [Color("7dff3a"), Color("9b4dff"), Color("3a8cff"), Color("f2e6b8")]
const SCARED := Color("4a4658")
const READY_TIME := 1.6
const SWIPE := 22.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var ready_t: float = 0.0
var ready_text := ""
var anim: float = 0.0
var drag_from := Vector2.ZERO
var dragging := false
var popups: Array = []  # [pos, text, life]

var field: Control
var score_label: Label
var hud_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/maze_muncher/maze_muncher_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = MmEngine.new()
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
	hud_label = Label.new()
	hud_label.custom_minimum_size = Vector2(150, 64)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hud_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", PLAYER.lerp(Color.WHITE, 0.6))
	score_label.add_theme_color_override("font_outline_color", Color(PLAYER, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(score_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	bar.add_child(spacer)

	field = Control.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	field.resized.connect(field.queue_redraw)
	root.add_child(field)

	var hint := Label.new()
	hint.text = tr("Swipe anywhere to steer.")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", HomeKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_bottom", 26)
	hm.add_child(hint)
	root.add_child(hm)

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
		"accent": PLAYER,
		"subtitle": "Eat every dot. Power dots scare the spirits.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "3 lives · faster every level", "action": _new_game}],
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
	drawer.set("default_frac", 0.975)  # by the hint line, under the maze
	add_child(drawer)

# ---------- game flow ----------

func _new_game() -> void:
	SaveUtil.delete(SAVE_PATH)
	engine.reset()
	started = true
	ready_t = READY_TIME
	ready_text = tr("Ready!")
	popups.clear()
	end_dialog.visible = false
	_update_hud()

func _update_hud() -> void:
	score_label.text = str(engine.score)
	hud_label.text = tr("Level %d") % engine.level + "\n" + "●".repeat(maxi(0, engine.lives))

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_from = event.position
	elif event is InputEventMouseMotion and dragging:
		var d: Vector2 = event.position - drag_from
		if d.length() >= SWIPE:
			_steer(Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(int(d.y))))
			drag_from = event.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				_steer(Vector2i(0, -1))
			KEY_DOWN, KEY_S:
				_steer(Vector2i(0, 1))
			KEY_LEFT, KEY_A:
				_steer(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				_steer(Vector2i(1, 0))

func _steer(d: Vector2i) -> void:
	if started:
		engine.want = d

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	anim += delta
	for p in popups:
		p[2] -= delta
	popups = popups.filter(func(p): return p[2] > 0.0)
	if ready_t > 0.0:
		ready_t -= delta
		field.queue_redraw()
		return
	var level_before: int = engine.level
	var dying_before: float = engine.dying
	var ev: Array = engine.step(delta)
	if dying_before > 0.0 and engine.dying <= 0.0 and not engine.over:
		ready_t = READY_TIME
		ready_text = tr("Ready!")
	for e in ev:
		match e[0]:
			"dot":
				if int(anim * 10.0) % 2 == 0:
					_sfx("tick")
			"power":
				_sfx("powerup")
			"ghost":
				_sfx("pickup")
				popups.append([engine.player.p, str(e[1]), 1.0])
			"die":
				_sfx("lose")
			"level":
				_sfx("win")
				ready_t = READY_TIME
				ready_text = tr("Level %d") % engine.level
				if info:
					info.high("Highest level", engine.level)
			"over":
				_game_over()
	if not ev.is_empty() or engine.level != level_before:
		_update_hud()
	field.queue_redraw()

func _game_over() -> void:
	started = false
	SaveUtil.delete(SAVE_PATH)
	var msg := tr("Game over!") + "\n" + tr("Score: %d") % engine.score + "   ·   " + tr("Level %d") % engine.level
	if info:
		info.add("Games played")
		info.high("Highest level", engine.level)
		if info.high("Best score", engine.score):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true
	field.queue_redraw()

# ---------- drawing ----------

func _geom() -> Dictionary:
	var ts: float = floor(minf(field.size.x / MmEngine.W, field.size.y / MmEngine.H))
	var o := Vector2((field.size.x - ts * MmEngine.W) / 2.0, (field.size.y - ts * MmEngine.H) / 2.0)
	return {"ts": ts, "o": o}

func _center(p: Vector2, g: Dictionary) -> Vector2:
	return g.o + (p + Vector2(0.5, 0.5)) * g.ts

func _draw_field() -> void:
	var g := _geom()
	var ts: float = g.ts
	var o: Vector2 = g.o
	field.draw_rect(Rect2(o, Vector2(MmEngine.W, MmEngine.H) * ts), Color(0.01, 0.01, 0.04))
	# Walls: an outline wherever a wall tile meets an open one.
	for y in MmEngine.H:
		for x in MmEngine.W:
			if MmEngine.MAZE[y][x] != "#":
				continue
			var r := Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts))
			field.draw_rect(r, Color(WALL, 0.08))
			for d in MmEngine.DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				var open_side: bool = nx >= 0 and ny >= 0 and nx < MmEngine.W and ny < MmEngine.H and MmEngine.MAZE[ny][nx] != "#"
				if not open_side:
					continue
				var a: Vector2 = r.position + Vector2(ts, 0)
				var b: Vector2 = r.end
				if d.y == -1:
					a = r.position
					b = r.position + Vector2(ts, 0)
				elif d.y == 1:
					a = r.position + Vector2(0, ts)
				elif d.x == -1:
					a = r.position
					b = r.position + Vector2(0, ts)
				field.draw_line(a, b, Color(WALL, 0.25), 6.0)
				field.draw_line(a, b, WALL, 2.0)
	var door := o + Vector2(MmEngine.DOOR) * ts
	field.draw_line(door + Vector2(0, ts * 0.5), door + Vector2(ts, ts * 0.5), Color("ff7ad9"), 3.0)
	for t in engine.dots:
		var c := _center(Vector2(t), g)
		if engine.dots[t] == 2:
			var pulse := 0.75 + 0.25 * sin(anim * 8.0)
			field.draw_circle(c, ts * 0.3 * pulse, Color(DOT, 0.3))
			field.draw_circle(c, ts * 0.2 * pulse, DOT)
		else:
			field.draw_circle(c, ts * 0.09, DOT)
	if not started and engine.player.is_empty():
		return
	if engine.player.is_empty():
		return
	# Player: a munching circle facing its way.
	var pc := _center(engine.player.p, g)
	var mouth: float = (0.12 + 0.28 * absf(sin(anim * 14.0))) * PI if engine.dying <= 0.0 else PI * (1.0 - engine.dying / 1.6) * 0.98
	var facing: float = Vector2(engine.player.d).angle() if engine.player.d != Vector2i.ZERO else 0.0
	var pts := PackedVector2Array([pc])
	for k in 25:
		var a: float = facing + mouth + (TAU - mouth * 2.0) * k / 24.0
		pts.append(pc + Vector2.RIGHT.rotated(a) * ts * 0.45)
	field.draw_colored_polygon(pts, PLAYER)
	field.draw_arc(pc, ts * 0.5, 0, TAU, 24, Color(PLAYER, 0.2), 3.0, true)
	if engine.dying <= 0.0:
		for gh in engine.ghosts:
			_draw_ghost(field, _center(gh.p, g), ts, gh)
	for p in popups:
		HomeKit.glow_text(field, _center(p[0], g) - Vector2(0, (1.0 - p[2]) * 30.0), p[1], int(ts * 0.8), HomeKit.CYAN)
	if ready_t > 0.0 and started:
		HomeKit.glow_text(field, _center(Vector2(9, 11), g), ready_text, int(ts * 1.1), PLAYER)

func _draw_ghost(c: CanvasItem, at: Vector2, ts: float, gh: Dictionary) -> void:
	var r := ts * 0.46
	var scared: bool = engine.fright > 0.0 and not gh.eaten and not gh.home
	var col: Color = GHOSTS[gh.id]
	if scared:
		col = Color.WHITE if engine.fright < 1.5 and int(anim * 6.0) % 2 == 0 else SCARED
	if not gh.eaten:
		# A skull spirit: round cranium, narrower jaw, two teeth gaps.
		var head := at + Vector2(0, -r * 0.12)
		c.draw_circle(head, r * 0.82, Color(col, 0.85))
		var jaw := Rect2(at + Vector2(-r * 0.48, r * 0.3), Vector2(r * 0.96, r * 0.55))
		c.draw_rect(jaw, Color(col, 0.85))
		c.draw_arc(head, r * 0.82, 0, TAU, 24, col.lightened(0.3), 1.5, true)
		for tx in [-0.16, 0.16]:
			c.draw_line(at + Vector2(r * tx, r * 0.55), at + Vector2(r * tx, r * 0.85), Color(0, 0, 0, 0.6), 1.5)
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, r * 0.08), at + Vector2(-r * 0.1, r * 0.28),
				at + Vector2(r * 0.1, r * 0.28)]), Color(0, 0, 0, 0.7))
	if scared:
		# Pale and hollow-eyed: X eyes.
		for sx in [-0.33, 0.33]:
			var e := at + Vector2(r * sx, -r * 0.2)
			c.draw_line(e - Vector2(r * 0.13, r * 0.13), e + Vector2(r * 0.13, r * 0.13), Color.WHITE, 2.0)
			c.draw_line(e + Vector2(-r * 0.13, r * 0.13), e + Vector2(r * 0.13, -r * 0.13), Color.WHITE, 2.0)
		return
	# Dark sockets with a glowing pupil that looks where the spirit heads
	# (an eaten one is only its eyes, flying home).
	var look := Vector2(gh.d) * r * 0.1
	for sx in [-0.33, 0.33]:
		var e := at + Vector2(r * sx, -r * 0.2)
		c.draw_circle(e, r * 0.24, Color(0.02, 0.02, 0.05))
		c.draw_circle(e + look, r * 0.11, col.lightened(0.5))

func _draw_home_logo(c: Control) -> void:
	var ts := minf(c.size.y / 2.2, 64.0)
	var y := c.size.y / 2.0
	var x0 := c.size.x / 2.0 - ts * 2.2
	var pts := PackedVector2Array([Vector2(x0, y)])
	for k in 25:
		var a := 0.6 + (TAU - 1.2) * k / 24.0
		pts.append(Vector2(x0, y) + Vector2.RIGHT.rotated(a) * ts * 0.45)
	c.draw_colored_polygon(pts, PLAYER)
	for k in 3:
		c.draw_circle(Vector2(x0 + ts * (0.9 + k * 0.5), y), ts * 0.08, DOT)
	var fake := {"id": 0, "d": Vector2i(-1, 0), "eaten": false, "home": false}
	_draw_ghost(c, Vector2(x0 + ts * 3.0, y), ts, fake)
	fake.id = 2
	_draw_ghost(c, Vector2(x0 + ts * 4.1, y), ts, fake)

# ---------- pause / save ----------

func _on_pause() -> void:
	dragging = false
	home.pause()

func _go_home() -> void:
	home.go_home()

## Score, lives, level and the dots left; the ghosts restart from home.
func _save_game() -> void:
	if not started or engine.over:
		return
	var left: Array = []
	for t in engine.dots:
		left.append([t.x, t.y, engine.dots[t]])
	SaveUtil.write(SAVE_PATH, {"score": engine.score, "lives": engine.lives, "level": engine.level, "dots": left})

func _resume_text() -> String:
	var d = SaveUtil.read(SAVE_PATH)
	return "" if d == null else tr("Score: %d") % int(d.get("score", 0)) + "   ·   " + tr("Level %d") % int(d.get("level", 1))

func _load_saved_game() -> void:
	var d = SaveUtil.read(SAVE_PATH)
	_new_game()
	if d == null:
		return
	engine.score = int(d.get("score", 0))
	engine.lives = maxi(1, int(d.get("lives", 3)))
	engine.level = maxi(1, int(d.get("level", 1)))
	var dots := {}
	for t in d.get("dots", []):
		dots[Vector2i(int(t[0]), int(t[1]))] = int(t[2])
	if not dots.is_empty():
		engine.dots = dots
	_update_hud()

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
