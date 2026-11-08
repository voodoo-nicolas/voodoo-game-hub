extends Control

## A sector map: the owner's orbit picture for the sector you're in, with the ship flying over it
## (design doc v2 §1.1-1.2: planets far apart on a scrolling map, real flight time, a big ship with its
## parts showing). The camera follows the ship, zoomed in; 🔭 shows the whole sector. Tap a world =
## select it (the game shows a course card); "Set course" = autopilot (20-45 s per trip). The Pad's
## stick flies the ship by hand; near a world A docks, near the gate the game offers a jump.
## Every pixel flown goes through engine.fly() (fuel, hull regen, mid-flight events, hazards).
## Positions are in the sector picture's pixels (data SECTORS.size).

signal world_tapped(w: String)
signal arrived(w: String)
signal encounter_opened
signal near_changed(w: String)   # a world in docking range while flying by hand ("" = none)
signal gate_changed(at: bool)    # the ship reached / left the sector's gate

const D = preload("res://scripts/games/the_runner/the_runner_data.gd")
const UI = preload("res://scripts/games/the_runner/the_runner_ui.gd")
const ShipArt = preload("res://scripts/games/the_runner/the_runner_ship_art.gd")

const ZOOM := 2.3              # follow camera: this many times the fitted picture
const DOCK_RANGE := 26.0       # extra px around a world's radius

var engine: RefCounted
var pad: Control = null
var selected := ""
var target := ""               # autopilot destination ("" = none)
var near := ""
var at_gate := false
var hold := false              # an encounter / card is open: the ship waits
var overview := false          # 🔭 the whole sector
var _tex: Texture2D
var _heading := -PI / 2.0
var _clock := 0.0
var _moving := false
var _auto_speed := 30.0
var _font: Font
var _cam := Vector2.ZERO       # map point at the screen centre (follow mode)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex = UI.art(str(D.SECTORS[engine.sector].map))
	_font = get_theme_default_font()
	if engine.loc != "":
		engine.ship_pos = engine.pos_of(engine.loc)
	_cam = engine.ship_pos

## The sector changed (a jump): new picture.
func reload() -> void:
	_tex = UI.art(str(D.SECTORS[engine.sector].map))
	target = ""
	selected = ""
	_cam = engine.ship_pos
	queue_redraw()

# ---------------------------------------------------------------- geometry

func _msize() -> Vector2:
	return engine.map_size()

func _fit_k() -> float:
	var m := _msize()
	return minf(size.x / m.x, size.y / m.y)

func _k() -> float:
	return _fit_k() if overview else maxf(_fit_k() * ZOOM, size.y / _msize().y)

## Map point at the screen's top-left.
func _origin() -> Vector2:
	var k := _k()
	var m := _msize()
	if overview:
		return -((size - m * k) / 2.0) / k
	var half := size / 2.0 / k
	var c := _cam
	c.x = clampf(c.x, half.x, maxf(half.x, m.x - half.x)) if m.x * k > size.x else m.x / 2.0
	c.y = clampf(c.y, half.y, maxf(half.y, m.y - half.y)) if m.y * k > size.y else m.y / 2.0
	return c - half

func to_screen(p: Vector2) -> Vector2:
	return (p - _origin()) * _k()

func to_map(s: Vector2) -> Vector2:
	return s / _k() + _origin()

func _world_at(screen_pos: Vector2) -> String:
	var m := to_map(screen_pos)
	var best := ""
	var best_d := INF
	for w in engine.worlds_in(engine.sector):
		var d := m.distance_to(engine.pos_of(w))
		var reach := maxf(float(D.WORLDS[w].r) + 10.0, 34.0 / _k())   # at least ~34 screen px to tap
		if d < reach and d < best_d:
			best_d = d
			best = w
	return best

## How wide the ship is drawn (design doc v2: 1/6 to 1/4 of the screen in flight).
func ship_width() -> float:
	return size.x / (14.0 if overview else 6.0)

# ---------------------------------------------------------------- flying

func set_course(w: String) -> void:
	if w == "" or w == engine.loc:
		return
	target = w
	selected = w
	var dist: float = engine.ship_pos.distance_to(engine.pos_of(w))
	_auto_speed = dist / maxf(1.0, engine.flight_seconds(dist))
	if engine.loc != "":
		engine.launch()

## Seconds left on the autopilot (0 = none).
func eta() -> float:
	if target == "":
		return 0.0
	return engine.ship_pos.distance_to(engine.pos_of(target)) / maxf(1.0, _auto_speed)

func stop() -> void:
	target = ""

func dock_here() -> void:
	if near != "" and engine.loc == "":
		_arrive(near)

func toggle_overview() -> void:
	overview = not overview
	queue_redraw()

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
		step = move.limit_length(1.0) * engine.hand_speed() * delta
	elif target != "":
		var goal: Vector2 = engine.pos_of(target)
		var to: Vector2 = goal - engine.ship_pos
		var stop_at := float(D.WORLDS[target].r) * 0.6
		if to.length() <= stop_at + _auto_speed * delta:
			_fly(to, delta)
			_arrive(target)
			return
		step = to.normalized() * _auto_speed * delta
	_moving = step.length() > 0.001
	_cam = _cam.lerp(engine.ship_pos, clampf(delta * 4.0, 0.0, 1.0))
	if not _moving:
		_update_near()
		return
	if engine.loc != "":
		engine.launch()
	_fly(step, delta)
	_update_near()

func _fly(step: Vector2, secs: float) -> void:
	var m := _msize()
	var next: Vector2 = engine.ship_pos + step
	next.x = clampf(next.x, 10.0, m.x - 10.0)
	next.y = clampf(next.y, 10.0, m.y - 10.0)
	var real: Vector2 = next - engine.ship_pos
	if real.length() < 0.0001:
		return
	_heading = real.angle()
	engine.ship_pos = next
	if engine.fly(real.length(), next, secs):
		encounter_opened.emit()

func _update_near() -> void:
	var n := ""
	if engine.loc == "":
		for w in engine.worlds_in(engine.sector):
			if engine.ship_pos.distance_to(engine.pos_of(w)) < float(D.WORLDS[w].r) + DOCK_RANGE:
				n = w
	if n != near:
		near = n
		near_changed.emit(near)
	var g: bool = engine.at_gate()
	if g != at_gate:
		at_gate = g
		gate_changed.emit(g)

func _arrive(w: String) -> void:
	target = ""
	near = ""
	engine.ship_pos = engine.pos_of(w)
	arrived.emit(w)

## A tow or a capture moved the ship: put it on its new world.
func place_at(w: String) -> void:
	target = ""
	engine.ship_pos = engine.pos_of(w)
	_cam = engine.ship_pos

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
	var k := _k()
	if _tex:
		draw_texture_rect(_tex, Rect2(to_screen(Vector2.ZERO), _msize() * k), false)
	var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
	# the planned course
	if target != "":
		_dash(to_screen(engine.ship_pos), to_screen(engine.pos_of(target)), Color(UI.c("accent"), 0.85))
	elif selected != "" and selected != engine.loc:
		var col := UI.c("go") if engine.can_reach(selected) else UI.c("bad")
		_dash(to_screen(engine.ship_pos), to_screen(engine.pos_of(selected)), Color(col, 0.6))
	# the gate
	var gp := to_screen(engine.gate_pos())
	var gr := maxf(engine.GATE_RANGE * k * 0.6, 18.0)
	for i in 3:
		draw_arc(gp, gr + i * 5.0 + pulse * 3.0, 0, TAU, 48, Color(0.75, 0.5, 1.0, 0.75 - i * 0.2), 2.0, true)
	_label(gp + Vector2(0, gr + 22.0), "⟁ " + UI.tr_s("Gate"), Color(0.85, 0.7, 1.0))
	# worlds
	var goals := _goal_worlds()
	for w in engine.worlds_in(engine.sector):
		var wd: Dictionary = D.WORLDS[w]
		var p := to_screen(engine.pos_of(w))
		var r := maxf(float(wd.r) * k + 6.0, 14.0)
		var col: Color = UI.c("accent")
		if w == engine.loc:
			col = UI.c("go")
		elif engine.port_closed(w):
			col = UI.c("bad")
		elif engine.loc != "" and not engine.can_reach(w):
			col = Color(UI.c("dim"), 0.6)
		var width := 2.0
		if w == selected or w == near:
			width = 3.0
			r += 3.0 + pulse * 4.0
		draw_arc(p, r, 0, TAU, 48, Color(col, 0.85), width, true)
		if goals.has(w):
			_star(p + Vector2(r * 0.75, -r * 0.75), 9.0, UI.c("warn"))
		_label(p + Vector2(0, r + 18.0), UI.world_name(w), Color(UI.c("text"), 0.95))
		if engine.can_sniff() and wd.get("services", []).has("market"):
			var risk := "▲".repeat(engine.law_at(w))
			if risk != "":
				_label(p + Vector2(0, r + 33.0), risk, Color(UI.c("warn"), 0.9), 11)
	# the ship
	var sp := to_screen(engine.ship_pos)
	var sw := ship_width()
	var heading := _heading
	if engine.loc != "":
		sp += Vector2(0, -maxf(float(D.WORLDS[engine.loc].r) * k, 10.0) - sw * 0.45)
		heading = -PI / 2.0
	ShipArt.draw(self, sp, sw, heading, ShipArt.spec_of(engine), _moving, 0.0, _clock)
	if target != "":
		_label(sp + Vector2(0, sw * 0.7), "%d s" % int(ceil(eta())), UI.c("accent"), 16)

func _label(at: Vector2, text: String, col: Color, fs: int = 15) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lp := at - Vector2(tw / 2.0, 0)
	draw_string_outline(_font, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(_font, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _dash(a: Vector2, b: Vector2, col: Color) -> void:
	var segs := int(a.distance_to(b) / 14.0)
	if segs <= 0:
		return
	var pts := PackedVector2Array()
	for i in range(0, segs, 2):
		pts.append(a.lerp(b, float(i) / segs))
		pts.append(a.lerp(b, float(i + 1) / segs))
	draw_multiline(pts, col, 2.0)

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)

## Worlds an active quest or contract points at (marked with a star).
func _goal_worlds() -> Array:
	var out := []
	for id in engine.active_quests():
		var st: Dictionary = engine.S.QUESTS[id].step
		if st.type == "tour":
			var seen: Array = engine.quests[id].get("visited", [])
			for w in st.to:
				if not seen.has(w):
					out.append(w)
		elif st.type == "jump":
			pass   # a sector, not a world: the gate shows the way
		elif st.has("to"):
			out.append(st.to)
		elif st.has("at"):
			out.append(st.at)
		elif st.type == "pay":
			out.append(D.HUB_WORLD)
	for c in engine.contracts:
		out.append(c.from if c.get("done", false) else c.to)
	return out
