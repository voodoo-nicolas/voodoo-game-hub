extends Control

## Evolution (M1, eat and grow): drag anywhere to steer a glowing cell, eat
## food and smaller cells, run from bigger ones. All rules live in the engine.

const EvEngine = preload("res://scripts/games/evolution/evolution_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const UI = preload("res://scripts/common/ui.gd")
## Home screen + pause menu + neon look (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/evolution/home_kit.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const HELP := preload("res://scripts/games/evolution/evolution_help.gd")
const TITLE_FOR_HOME := HELP.TITLE

const BG := Color(0.012, 0.016, 0.03)
const MINE := Color("29e6ff")
const PREY := Color("7dff3a")
const HUNTER := Color("ff4f9a")
const EQUAL := Color("d8e4ff")
const FOOD := [Color("ffd23f"), Color("ff9f43"), Color("c77dff")]
const GRID := 160.0
const JOY_RADIUS := 110.0
const ZOOM_SMOOTH := 3.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var engine
var started := false
var result_sent := false
var zoom: float = 1.0
var joy_active := false
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var keys := Vector2.ZERO
var voodoo := false
var pulse: float = 0.0

var field: Control
var score_label: Label
var size_label: Label
var end_dialog: Control

func _ready() -> void:
	preload("res://scripts/games/evolution/evolution_i18n.gd").install(self)
	Orientation.lock_portrait()
	engine = EvEngine.new()
	_build_ui()
	engine.reset()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme()
	add_child(HomeKit.backdrop())

	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.gui_input.connect(_on_field_input)
	add_child(field)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := MarginContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("margin_top", 24)
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(76, 64)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_on_pause)
	bar.add_child(pause_btn)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", MINE.lerp(Color.WHITE, 0.7))
	score_label.add_theme_color_override("font_outline_color", Color(MINE, 0.5))
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(score_label)
	size_label = Label.new()
	size_label.custom_minimum_size = Vector2(150, 64)
	size_label.add_theme_font_size_override("font_size", 22)
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(size_label)

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
		"accent": MINE,
		"subtitle": "Eat to grow. Don't get eaten.",
		"logo": _draw_home_logo,
		"modes": [{"text": "▶  " + tr("Play"), "sub": "Start as a tiny cell and eat your way up", "action": _new_game}],
		"restart": _new_game,
		"board": "Best score",
	})
	add_child(home)
	if info:
		add_child(info)

# ---------- input ----------

func _on_field_input(event: InputEvent) -> void:
	# Phones send touch AND emulated mouse; the mouse copy is the one handled.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		joy_active = event.pressed
		joy_origin = event.position
		joy_pos = event.position
	elif event is InputEventMouseMotion and joy_active:
		joy_pos = event.position
		var off := joy_pos - joy_origin
		if off.length() > JOY_RADIUS:
			joy_origin = joy_pos - off.normalized() * JOY_RADIUS  # floating base follows

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				keys.x = -1.0 if event.pressed else (0.0 if keys.x < 0.0 else keys.x)
			KEY_RIGHT, KEY_D:
				keys.x = 1.0 if event.pressed else (0.0 if keys.x > 0.0 else keys.x)
			KEY_UP, KEY_W:
				keys.y = -1.0 if event.pressed else (0.0 if keys.y < 0.0 else keys.y)
			KEY_DOWN, KEY_S:
				keys.y = 1.0 if event.pressed else (0.0 if keys.y > 0.0 else keys.y)

func _direction() -> Vector2:
	if joy_active:
		return ((joy_pos - joy_origin) / JOY_RADIUS).limit_length(1.0)
	return keys.limit_length(1.0)

# ---------- game flow ----------

func _new_game() -> void:
	engine.reset()
	started = true
	result_sent = false
	zoom = EvEngine.zoom_for(engine.player.mass)
	joy_active = false
	end_dialog.visible = false
	_update_hud()

func _process(delta: float) -> void:
	if not started:
		return
	delta = minf(delta, 0.05)
	pulse += delta
	var food_before: int = engine.eaten_food
	var cells_before: int = engine.eaten_cells
	engine.step(delta, _direction())
	if engine.eaten_cells > cells_before:
		_sfx("pickup")
	elif engine.eaten_food > food_before and engine.eaten_food % 3 == 0:
		_sfx("tick")
	zoom = lerpf(zoom, EvEngine.zoom_for(engine.player.mass), clampf(ZOOM_SMOOTH * delta, 0.0, 1.0))
	_update_hud()
	if not engine.alive:
		_game_over()
	field.queue_redraw()

func _update_hud() -> void:
	score_label.text = str(engine.score())
	size_label.text = tr("Size %d") % int(engine.player.mass)

func _game_over() -> void:
	started = false
	joy_active = false
	_sfx("explode")
	var msg := tr("You were eaten!") + "\n" + tr("Score: %d") % engine.score() + "   ·   " + tr("Size %d") % int(engine.peak_mass)
	if info and not result_sent:
		result_sent = true
		info.add("Games played")
		info.add("Cells eaten", engine.eaten_cells)
		info.add("Food eaten", engine.eaten_food)
		info.high("Biggest size", int(engine.peak_mass))
		if info.high("Best score", engine.score()):
			msg += "\n" + tr("New best!")
			info.celebrate(tr("New best!"))
	end_dialog.get_meta("message_label").text = msg
	end_dialog.visible = true

# ---------- drawing ----------

func _w2s(p: Vector2) -> Vector2:
	return (p - engine.player.pos) * zoom + field.size / 2.0

func _draw_field() -> void:
	var s := field.size
	field.draw_rect(Rect2(Vector2.ZERO, s), BG)
	if engine == null:
		return
	var a: float = EvEngine.TUNING.arena
	# Grid dots give a sense of motion.
	var step := GRID * zoom
	var tl: Vector2 = engine.player.pos - s / (2.0 * zoom)
	var first := Vector2(floorf(tl.x / GRID), floorf(tl.y / GRID)) * GRID
	var gx := first.x
	while _w2s(Vector2(gx, 0)).x < s.x + step:
		var gy := first.y
		while _w2s(Vector2(0, gy)).y < s.y + step:
			if gx >= 0.0 and gy >= 0.0 and gx <= a and gy <= a:
				field.draw_circle(_w2s(Vector2(gx, gy)), 2.0, Color(MINE, 0.14))
			gy += GRID
		gx += GRID
	HomeKit.glow_rect(field, Rect2(_w2s(Vector2.ZERO), Vector2(a, a) * zoom), HUNTER, 3.0)
	# Food
	var margin := 30.0
	var fr: float = maxf(EvEngine.radius_of(EvEngine.TUNING.food_mass) * zoom, 3.0)
	for i in engine.food.size():
		var sp := _w2s(engine.food[i])
		if sp.x < -margin or sp.y < -margin or sp.x > s.x + margin or sp.y > s.y + margin:
			continue
		var col: Color = FOOD[i % FOOD.size()]
		field.draw_circle(sp, fr * 2.2, Color(col, 0.12))
		field.draw_circle(sp, fr, col)
	# Other cells, biggest last-but-one so small ones stay visible
	var pm: float = engine.player.mass
	var list: Array = engine.npcs.duplicate()
	list.sort_custom(func(x, y): return x.mass < y.mass)
	for n in list:
		var sp2 := _w2s(n.pos)
		var r: float = EvEngine.radius_of(n.mass) * zoom
		if sp2.x < -r - margin or sp2.y < -r - margin or sp2.x > s.x + r + margin or sp2.y > s.y + r + margin:
			continue
		var col2: Color = EQUAL
		if EvEngine.can_eat(pm, n.mass):
			col2 = PREY
		elif EvEngine.can_eat(n.mass, pm):
			col2 = HUNTER
		_draw_cell(sp2, r, col2, n.vel, false)
	_draw_cell(field.size / 2.0, EvEngine.radius_of(pm) * zoom, MINE, engine.player.vel, true)
	# Joystick
	if joy_active:
		field.draw_arc(joy_origin, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
		field.draw_circle(joy_origin + (joy_pos - joy_origin).limit_length(JOY_RADIUS), 34.0, Color(MINE, 0.35))

func _draw_cell(c: Vector2, r: float, col: Color, vel: Vector2, is_player: bool) -> void:
	var wob := 1.0 + 0.03 * sin(pulse * 5.0 + c.x * 0.01)
	r *= wob
	if voodoo:
		HomeKit.glow_circle(field, c, r, col, 3.0, 0.18)
		# skull-ish eyes
		var look := vel.limit_length(r * 0.2)
		field.draw_circle(c + Vector2(-r * 0.3, -r * 0.1) + look, r * 0.16, Color.BLACK)
		field.draw_circle(c + Vector2(r * 0.3, -r * 0.1) + look, r * 0.16, Color.BLACK)
		field.draw_line(c + Vector2(-r * 0.25, r * 0.35), c + Vector2(r * 0.25, r * 0.35), col, maxf(r * 0.06, 1.5))
		return
	field.draw_circle(c, r * 1.35, Color(col, 0.10))
	field.draw_circle(c, r, Color(col, 0.30 if not is_player else 0.45))
	HomeKit.glow_circle(field, c, r, col, maxf(r * 0.06, 2.0), 0.0)
	var look2 := vel.limit_length(r * 0.25)
	field.draw_circle(c + look2 + Vector2(-r * 0.28, -r * 0.1), r * 0.15, Color.WHITE)
	field.draw_circle(c + look2 + Vector2(r * 0.28, -r * 0.1), r * 0.15, Color.WHITE)
	field.draw_circle(c + look2 * 1.4 + Vector2(-r * 0.28, -r * 0.1), r * 0.07, Color.BLACK)
	field.draw_circle(c + look2 * 1.4 + Vector2(r * 0.28, -r * 0.1), r * 0.07, Color.BLACK)

func _draw_home_logo(c: Control) -> void:
	var o := c.size / 2.0
	var k := minf(c.size.y / 3.0, 44.0)
	for spec in [[Vector2(-2.6, 0.5), 0.55, PREY], [Vector2(2.4, -0.4), 1.3, HUNTER], [Vector2(-0.4, 0), 1.0, MINE]]:
		var p: Vector2 = o + spec[0] * k
		var r: float = spec[1] * k
		c.draw_circle(p, r, Color(spec[2], 0.28))
		HomeKit.glow_circle(c, p, r, spec[2], 2.5, 0.0)
		c.draw_circle(p + Vector2(-r * 0.28, -r * 0.1), r * 0.14, Color.WHITE)
		c.draw_circle(p + Vector2(r * 0.28, -r * 0.1), r * 0.14, Color.WHITE)

# ---------- pause / skin ----------

func _on_pause() -> void:
	joy_active = false
	home.pause()

func _go_home() -> void:
	home.go_home()

## Called by the Landing kit's skin switch: re-skin in place.
func _set_skin(skin: String) -> void:
	voodoo = skin == "voodoo"
	if field:
		field.queue_redraw()

func _current_skin() -> String:
	return "voodoo" if voodoo else "classic"

func _sfx(sound: String) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s:
		s.play(sound)
