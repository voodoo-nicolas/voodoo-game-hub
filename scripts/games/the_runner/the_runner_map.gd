extends Control

## The system map: the owner's picture (system_1.webp) with the ship flying over it from one world
## to the next. Tap a world = select it (the game shows a course card); "Set course" = autopilot.
## The Pad's stick flies the ship by hand anywhere; near a world, A docks. Every pixel flown goes
## through engine.fly() (fuel, mid-flight events, the Sun and the Maw).
## Positions are in the picture's pixels (data MAP_SIZE); the picture is fitted whole, centred.

signal world_tapped(w: String)
signal arrived(w: String)
signal encounter_opened
signal near_changed(w: String)   # a world in docking range while flying by hand ("" = none)

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")
const SpriteLib = preload("res://scripts/games/the_runner/sprite_lib.gd")

const AUTO_SPEED := 170.0     # map px per second
const HAND_SPEED := 190.0
const DOCK_RANGE := 26.0      # extra px around a world's radius

var engine: RefCounted
var pad: Control = null
var selected := ""
var target := ""              # autopilot destination ("" = none)
var near := ""
var hold := false             # an encounter / card is open: the ship waits
var _tex: Texture2D
var _ship_tex := {}
var _heading := 0.0
var _clock := 0.0
var _moving := false
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex = UI.art(D.MAP_ART)
	_ship_tex = {"moth": SpriteLib.texture("space/player_ship1_green"), "runner": SpriteLib.texture("space/player_ship2_blue")}
	_font = get_theme_default_font()
	if engine.loc != "":
		engine.ship_pos = engine.pos_of(engine.loc)

# ---------------------------------------------------------------- geometry

func _k() -> float:
	return minf(size.x / D.MAP_SIZE.x, size.y / D.MAP_SIZE.y)

func _off() -> Vector2:
	return (size - D.MAP_SIZE * _k()) / 2.0

func to_screen(p: Vector2) -> Vector2:
	return _off() + p * _k()

func to_map(s: Vector2) -> Vector2:
	return (s - _off()) / _k()

func _world_at(screen_pos: Vector2) -> String:
	var m := to_map(screen_pos)
	var best := ""
	var best_d := INF
	for w in D.WORLD_ORDER:
		var d := m.distance_to(engine.pos_of(w))
		var reach := maxf(float(D.WORLDS[w].r) + 10.0, 34.0 / _k())   # at least ~34 screen px to tap
		if d < reach and d < best_d:
			best_d = d
			best = w
	return best

# ---------------------------------------------------------------- flying

func set_course(w: String) -> void:
	if w == "" or w == engine.loc:
		return
	target = w
	selected = w
	if engine.loc != "":
		engine.launch()

func stop() -> void:
	target = ""

func dock_here() -> void:
	if near != "" and engine.loc == "":
		_arrive(near)

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if hold or not is_visible_in_tree() or engine == null:
		return
	if not engine.encounter.is_empty():
		return
	var move := Vector2.ZERO
	if pad != null and is_instance_valid(pad) and pad.visible:
		move = pad.get_vector("move")
	elif InputMap.has_action("pad_move_left"):
		move = Input.get_vector("pad_move_left", "pad_move_right", "pad_move_up", "pad_move_down")
	var step := Vector2.ZERO
	if move.length() > 0.15:
		target = ""
		step = move.limit_length(1.0) * HAND_SPEED * delta
	elif target != "":
		var goal: Vector2 = engine.pos_of(target)
		var to: Vector2 = goal - engine.ship_pos
		var stop_at := float(D.WORLDS[target].r) * 0.6
		if to.length() <= stop_at + AUTO_SPEED * delta:
			_fly(to)
			_arrive(target)
			return
		step = to.normalized() * AUTO_SPEED * delta
	_moving = step.length() > 0.01
	if not _moving:
		_update_near()
		return
	if engine.loc != "":
		engine.launch()
	_fly(step)
	_update_near()

func _fly(step: Vector2) -> void:
	var next: Vector2 = engine.ship_pos + step
	next.x = clampf(next.x, 10.0, D.MAP_SIZE.x - 10.0)
	next.y = clampf(next.y, 10.0, D.MAP_SIZE.y - 10.0)
	var real: Vector2 = next - engine.ship_pos
	if real.length() < 0.001:
		return
	_heading = real.angle()
	engine.ship_pos = next
	if engine.fly(real.length(), next):
		encounter_opened.emit()

func _update_near() -> void:
	var n := ""
	if engine.loc == "":
		for w in D.WORLD_ORDER:
			if engine.ship_pos.distance_to(engine.pos_of(w)) < float(D.WORLDS[w].r) + DOCK_RANGE:
				n = w
	if n != near:
		near = n
		near_changed.emit(near)

func _arrive(w: String) -> void:
	target = ""
	near = ""
	engine.ship_pos = engine.pos_of(w)
	arrived.emit(w)

## A tow or a capture moved the ship: put it on its new world.
func place_at(w: String) -> void:
	target = ""
	engine.ship_pos = engine.pos_of(w)

# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var w := _world_at(event.position)
		selected = w
		world_tapped.emit(w)   # "" = empty space: the game closes the card
		accept_event()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.03))
	if _tex:
		draw_texture_rect(_tex, Rect2(_off(), D.MAP_SIZE * _k()), false)
	var k := _k()
	var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
	# the planned course
	if target != "":
		var a := to_screen(engine.ship_pos)
		var b := to_screen(engine.pos_of(target))
		var segs := int(a.distance_to(b) / 14.0)
		for i in range(0, segs, 2):
			draw_line(a.lerp(b, float(i) / segs), a.lerp(b, float(i + 1) / segs), Color(UI.c("accent"), 0.8), 2.0)
	elif selected != "" and engine.loc != "" and selected != engine.loc:
		var a2 := to_screen(engine.ship_pos)
		var b2 := to_screen(engine.pos_of(selected))
		var col := UI.c("go") if engine.can_reach(selected) else UI.c("bad")
		var segs2 := int(a2.distance_to(b2) / 14.0)
		for i in range(0, segs2, 2):
			draw_line(a2.lerp(b2, float(i) / segs2), a2.lerp(b2, float(i + 1) / segs2), Color(col, 0.55), 2.0)
	# worlds
	var goals := _mission_worlds()
	for w in D.WORLD_ORDER:
		var wd: Dictionary = D.WORLDS[w]
		var p := to_screen(engine.pos_of(w))
		var r := maxf(float(wd.r) * k + 6.0, 14.0)
		var col: Color = UI.c("accent")
		if w == engine.loc:
			col = UI.c("go")
		elif engine.loc != "" and not engine.can_reach(w):
			col = Color(UI.c("dim"), 0.6)
		var width := 2.0
		if w == selected or w == near:
			width = 3.0
			r += 3.0 + pulse * 4.0
		draw_arc(p, r, 0, TAU, 40, Color(col, 0.85), width, true)
		if goals.has(w):
			_star(p + Vector2(r * 0.75, -r * 0.75), 8.0, UI.c("warn"))
		var name_s := UI.world_name(w)
		var fs := 15
		var tw := _font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lp := p + Vector2(-tw / 2.0, r + 16.0)
		draw_string_outline(_font, lp, name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(_font, lp, name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.c("text"), 0.95))
		if engine.can_sniff() and engine.has_service("market", w):
			var risk := "▲".repeat(engine.law_at(w))
			if risk != "":
				var rp := lp + Vector2(0, 14)
				draw_string(_font, rp, risk, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UI.c("warn"), 0.9))
	# the ship
	var sp := to_screen(engine.ship_pos)
	var tex: Texture2D = _ship_tex.get(engine.ship)
	if engine.loc != "":
		sp += Vector2(0, -maxf(float(D.WORLDS[engine.loc].r) * k, 10.0) - 16.0)
	var ship_w := 34.0 if engine.ship == "moth" else 40.0
	if _moving:
		var back := Vector2.from_angle(_heading + PI)
		for i in 3:
			var fl := sp + back * (ship_w * 0.45 + i * 6.0 + pulse * 3.0)
			draw_circle(fl, 5.0 - i * 1.4, Color(1.0, 0.6 - i * 0.15, 0.2, 0.75 - i * 0.2))
	if tex:
		var sz := Vector2(ship_w, ship_w * tex.get_height() / float(tex.get_width()))
		draw_set_transform(sp, (_heading + PI / 2.0) if engine.loc == "" else 0.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(sp, 8.0, UI.c("go"))

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)

## Worlds an active mission or contract points at (marked with a star).
func _mission_worlds() -> Array:
	var out := []
	for id in engine.active_missions():
		var st: Dictionary = D.MISSIONS[id].steps[0]
		if st.has("to"):
			out.append(st.to)
		elif st.type == "pay":
			out.append("luna")
	for c in engine.contracts:
		out.append(c.to)
	return out
