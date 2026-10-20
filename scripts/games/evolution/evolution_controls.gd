extends Control

## Evolution's on-screen controls, laid out like Last Shift's (landscape phones):
##   left thumb  : a fixed joystick (analog: the cell swims where you push)
##   right thumb : at most 4 round buttons, none at the start. 1 = an offensive ability, 2 = a defensive
##                 one (the player picks which on the creature screen), 3 and 4 arrive later. Each fills
##                 with power from the blue bar and lights up when it can be used
##   bottom      : pause and the creature screen sit in the middle (real buttons, added by the game)
## Every finger is tracked by its own index so you can steer and boost together. A mouse works
## too (index -1); phones also send emulated mouse events for each touch, so once a real touch has
## been seen the mouse is ignored (otherwise every tap would count twice).

signal ability_pressed(index: int)

const STICK_R := 130.0
const DEADZONE := 0.12
const BTN_R := 44.0

var dir := Vector2.ZERO          # joystick deflection, length 0..1
var slots: Array = ["", "", "", ""]   # ability id on each of the 4 buttons ("" = button not shown)
var fill: Array = []             # per slot 0..1: power / cost, 1 = ready
var accent := Color("29e6ff")
var _pointers := {}              # pointer id -> "stick" / "dash"
var _touch_seen := false
var _stick_pos := Vector2.ZERO   # finger position relative to the stick centre

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func stick_center() -> Vector2:
	return Vector2(190.0, size.y - 190.0)

## The four buttons in an arc around the right thumb: 0 in the corner, 1 up-left, 2 left, 3 above.
func slot_center(i: int) -> Vector2:
	var offs := [Vector2(110, 120), Vector2(230, 230), Vector2(250, 100), Vector2(120, 250)]
	return Vector2(size.x, size.y) - offs[clampi(i, 0, 3)]

func set_slots(ids: Array, fills: Array) -> void:
	if ids != slots or fills != fill:
		slots = ids.duplicate()
		fill = fills.duplicate()
		queue_redraw()

## Lets go of everything (the game calls this when a menu opens).
func release() -> void:
	_pointers.clear()
	dir = Vector2.ZERO
	_stick_pos = Vector2.ZERO
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_touch_seen = true
		_press(event.index, event.position - global_position, event.pressed)
	elif event is InputEventScreenDrag:
		_touch_seen = true
		_move(event.index, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not _touch_seen:
		_press(-1, event.position - global_position, event.pressed)
	elif event is InputEventMouseMotion and not _touch_seen:
		_move(-1, event.position - global_position)

func _press(id: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _pointers.has(id):
			return
		if pos.distance_to(stick_center()) <= STICK_R * 1.5:
			_pointers[id] = "stick"
			_move(id, pos)
		else:
			for i in slots.size():
				if str(slots[i]) != "" and pos.distance_to(slot_center(i)) <= BTN_R * 1.35:
					_pointers[id] = "slot%d" % i
					ability_pressed.emit(i)
					break
	else:
		if _pointers.get(id, "") == "stick":
			dir = Vector2.ZERO
			_stick_pos = Vector2.ZERO
		_pointers.erase(id)
	queue_redraw()

func _move(id: int, pos: Vector2) -> void:
	if _pointers.get(id, "") != "stick":
		return
	_stick_pos = (pos - stick_center()).limit_length(STICK_R)
	var d := _stick_pos / STICK_R
	dir = d if d.length() > DEADZONE else Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var c := stick_center()
	draw_circle(c, STICK_R, Color(1, 1, 1, 0.10))
	draw_arc(c, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
	draw_arc(c, STICK_R * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.14), 2.0, true)
	var held := _pointers.values().has("stick")
	draw_circle(c + _stick_pos, 50.0, Color(accent, 0.5 if held else 0.25))
	draw_arc(c + _stick_pos, 50.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0, true)
	for i in slots.size():
		if str(slots[i]) == "":
			continue
		var d := slot_center(i)
		var down := _pointers.values().has("slot%d" % i)
		var f: float = float(fill[i]) if i < fill.size() else 1.0
		draw_circle(d, BTN_R, Color(1, 1, 1, 0.5 if down else (0.18 if f >= 1.0 else 0.08)))
		draw_arc(d, BTN_R, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0, true)
		if f < 1.0:
			draw_arc(d, BTN_R - 5.0, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Color("3ac7ff"), 6.0, true)
		_icon(str(slots[i]), d, 1.0 if f >= 1.0 else 0.4)

## Little vector icons, one per ability.
func _icon(id: String, c: Vector2, a: float) -> void:
	var gold := Color(1, 0.9, 0.4, a)
	var white := Color(1, 1, 1, a)
	match id:
		"burst":
			draw_colored_polygon(PackedVector2Array([c + Vector2(6, -22), c + Vector2(-10, 3), c + Vector2(-1, 3), c + Vector2(-6, 22), c + Vector2(11, -5), c + Vector2(2, -5)]), gold)
		"spit":
			draw_circle(c + Vector2(-8, 0), 8.0, Color("9bff5a", a))
			draw_circle(c + Vector2(6, -6), 4.0, Color("9bff5a", a))
			draw_circle(c + Vector2(12, 4), 3.0, Color("9bff5a", a))
			draw_circle(c + Vector2(18, -2), 2.0, Color("9bff5a", a))
		"shock":
			draw_polyline(PackedVector2Array([c + Vector2(-16, -14), c + Vector2(-2, -2), c + Vector2(-8, 2), c + Vector2(8, 14), c + Vector2(2, 2), c + Vector2(10, -2), c + Vector2(16, -14)]), Color("7be0ff", a), 4.0, true)
		"spine":
			for k in 8:
				var d := Vector2.RIGHT.rotated(TAU * float(k) / 8.0)
				draw_line(c + d * 8.0, c + d * 20.0, white, 3.0, true)
			draw_circle(c, 7.0, white)
		"lure":
			draw_line(c + Vector2(-14, 16), c + Vector2(4, -6), white, 3.0, true)
			draw_circle(c + Vector2(8, -10), 8.0, Color(1, 0.95, 0.5, a))
			draw_arc(c + Vector2(8, -10), 14.0, 0.0, TAU, 20, Color(1, 0.95, 0.5, a * 0.6), 2.0, true)
		"ink":
			for o in [Vector2(-9, 4), Vector2(0, -6), Vector2(10, 3), Vector2(2, 10)]:
				draw_circle(c + o, 9.0, Color(0.55, 0.45, 0.9, a))
		"harpoon":
			draw_line(c + Vector2(-18, 14), c + Vector2(14, -14), Color("d58bff", a), 4.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(20, -20), c + Vector2(6, -14), c + Vector2(14, -6)]), Color("f0c8ff", a))
		"decoy":
			draw_arc(c + Vector2(-8, 0), 11.0, 0.0, TAU, 20, white, 3.0, true)
			draw_arc(c + Vector2(9, 0), 11.0, 0.0, TAU, 20, Color(1, 1, 1, a * 0.5), 3.0, true)
		"limb":
			draw_circle(c + Vector2(-8, 4), 10.0, white)
			draw_line(c + Vector2(2, -2), c + Vector2(18, -14), Color(1, 0.4, 0.4, a), 4.0, true)
			draw_line(c + Vector2(10, -16), c + Vector2(20, -6), Color(1, 0.4, 0.4, a), 3.0, true)
		"suction":
			for k in 6:
				var d2 := Vector2.RIGHT.rotated(TAU * float(k) / 6.0)
				draw_line(c + d2 * 20.0, c + d2 * 9.0, white, 3.0, true)
			draw_circle(c, 5.0, white)
		"grab":
			draw_arc(c + Vector2(-6, 6), 14.0, PI, TAU * 0.9, 16, white, 4.0, true)
			draw_arc(c + Vector2(8, -4), 11.0, 0.0, PI * 1.4, 16, white, 4.0, true)
		"sonar":
			for k in 3:
				draw_arc(c + Vector2(-12, 0), 8.0 + 8.0 * float(k), -0.9, 0.9, 10, Color(0.48, 0.88, 1.0, a), 3.0, true)
			draw_circle(c + Vector2(-12, 0), 4.0, Color(0.48, 0.88, 1.0, a))
		"camo":
			draw_arc(c, 16.0, PI, TAU, 16, white, 3.0, true)
			draw_arc(c, 16.0, 0.0, PI, 16, white, 3.0, true)
			draw_circle(c, 5.0, white)
			draw_line(c + Vector2(-16, 14), c + Vector2(16, -14), Color(1, 0.4, 0.4, a), 3.0, true)
