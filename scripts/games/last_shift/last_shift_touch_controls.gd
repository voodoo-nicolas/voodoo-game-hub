extends Control

## On-screen controls for landscape phones:
##   left thumb  : fixed D-pad (4 arrows), slide the thumb to change direction
##   right thumb : A (lower, says what it does: USE / SEARCH / HIDE / OPEN ...) and
##                 B (upper, shows the weapon: fist / knife / wrench / pistol + bullets left)
##                 + the weapon-wheel button once Nash has two weapons
##   bottom      : pause (II) and, right of it, the bag (inventory); left of it the map (v0.5)
##   weapon wheel: a ring of the weapons (six since v0.5) in the middle of the screen; tap one to
##                 equip it, tap anywhere else (or the wheel button) to close it
## Extra tap areas from the world (`tap_regions`): the mission log and the health bar.
## They press the same ls_* actions as the keyboard.
##
## Since the shared Pad (scripts/common/pad/, docs/claude/pad.md): when the app has it, the stick, A, B,
## pause, bag, map and the weapon-wheel button are the Pad's (stick + 4 buttons: A bottom = action, B right
## = weapon, X left = wheel button, Y top = bag; pause and map in the middle; the stick replaces the
## D-pad). This script then only keeps the weapon wheel itself and the world's tap areas. Without the Pad
## (older apps) everything below works as it always did.
##
## Multi-touch: every finger is tracked by its own index, so you can hold the
## D-pad and tap A/B at the same time. A mouse works too (index -1) for editor tests.
## Phones also send emulated mouse events for each touch, so once a real touch
## has been seen all mouse events are ignored (otherwise every tap would count twice).

const Icons = preload("res://scripts/games/last_shift/last_shift_icons.gd")
const A = preload("res://scripts/games/last_shift/last_shift_art.gd")

signal pause_pressed
signal bag_pressed
## v0.5: the map button.
signal map_pressed
## The weapon-wheel button was tapped (the world opens / closes the wheel).
signal wheel_pressed
## A weapon was picked on the open wheel ("" = closed without picking).
signal weapon_chosen(weapon: String)
## A world-provided tap area was tapped ("log", "heal").
signal region_tapped(name: String)

const DPAD_RADIUS := 130.0     # touch area of the D-pad
const DPAD_DEADZONE := 28.0    # thumb must leave the centre by this much
const DPAD_HYSTERESIS := 1.3   # the other axis must be this much stronger to switch (no flicker on diagonals)
const BUTTON_RADIUS := 62.0
const SWAP_RADIUS := 40.0      # weapon-wheel button (only shown with 2+ weapons)
const PAUSE_SIZE := Vector2(96, 48)
const WHEEL_OUTER := 150.0
const WHEEL_INNER := 58.0
## Wheel segments, clockwise from the top (v0.5: + the severed arm and the coolant can).
const WHEEL_ORDER := ["fist", "knife", "arm", "wrench", "pistol", "coolant"]

const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"

const MOVE_ACTIONS := {
	"left": "ls_move_left", "right": "ls_move_right",
	"up": "ls_move_up", "down": "ls_move_down",
}

var _pointers := {}            # pointer id -> role ("dpad", "a", "b", "swap", "pause", "bag", ...)
var _dpad_dir := Vector2.ZERO  # current D-pad direction (one axis only)
var _a_down := false
var _b_down := false
var _pause_down := false
var _bag_down := false
var _map_down := false
var _swap_down := false
var _touch_seen := false       # true after the first real touch event
var _pad: Control = null       # the shared Pad (null on apps without it: the old controls run)

## Set by the world once Nash owns two weapons; until then the wheel button is hidden and inactive.
var show_swap := false:
	set(v):
		show_swap = v
		queue_redraw()
## What A does right now (already translated), and whether there is anything to do.
var a_label := "":
	set(v):
		if v != a_label:
			a_label = v
			queue_redraw()
var a_active := false:
	set(v):
		if v != a_active:
			a_active = v
			queue_redraw()
## 0..1 while a search runs (a ring fills around A), -1 otherwise.
var a_progress := -1.0:
	set(v):
		a_progress = v
		queue_redraw()
## The icon on B (the equipped weapon) and the number under it ("" = none, e.g. bullets left).
var b_icon := "fist":
	set(v):
		if v != b_icon:
			b_icon = v
			queue_redraw()
var b_count := "":
	set(v):
		if v != b_count:
			b_count = v
			queue_redraw()
## The weapon wheel: open or not, and what is on it: {weapon: {"owned": bool, "count": String}}.
var wheel_open := false:
	set(v):
		wheel_open = v
		queue_redraw()
var wheel_items := {}
var wheel_equipped := "fist"
var wheel_names := {}          # weapon -> translated name
## Extra tap areas (screen rects) set by the world: name -> Rect2.
var tap_regions := {}

func _ready() -> void:
	# A Control under a CanvasLayer gets no size from anchors, so follow the viewport by hand.
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # we read raw input below
	process_mode = Node.PROCESS_MODE_ALWAYS      # still works while the game is paused
	_add_pad()

func _exit_tree() -> void:
	_release_all()

# ---------------------------------------------------------------- the shared Pad
func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	_pad = load(PAD_PATH).new()
	_pad.layout_override = "stick_4"
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pad)
	_pad.set_map({
		"move": [MOVE_ACTIONS.left, MOVE_ACTIONS.right, MOVE_ACTIONS.up, MOVE_ACTIONS.down],
		"a": ["ls_action_a"], "b": ["ls_action_b"],
	})
	_pad.set_state("x", {"draw": _draw_wheel_icon})
	_pad.set_state("y", {"draw": _draw_bag_icon})
	_pad.set_state("info", {"draw": _draw_map_icon})
	_pad.button_pressed.connect(_on_pad_button)
	set_process(true)

func _on_pad_button(id: String) -> void:
	match id:
		"pause":
			pause_pressed.emit()
		"x":
			wheel_pressed.emit()
		"y":
			bag_pressed.emit()
		"info":
			map_pressed.emit()

func _draw_wheel_icon(ci: CanvasItem, c: Vector2, r: float, a: float) -> void:
	Icons.draw(ci, "wheel", c, r * 1.1, a)

func _draw_bag_icon(ci: CanvasItem, c: Vector2, r: float, a: float) -> void:
	Icons.draw(ci, "bag", c, r * 1.1, a)

func _draw_map_icon(ci: CanvasItem, c: Vector2, r: float, a: float) -> void:
	Icons.draw(ci, "map", c, r * 1.3, a)

func _draw_weapon_icon(ci: CanvasItem, c: Vector2, r: float, a: float) -> void:
	Icons.draw(ci, b_icon, c + Vector2(0, -r * 0.12 if b_count != "" else 0.0), r * 1.35, a)

## Pad mode only: the words, the icons and what is usable, pushed to the Pad every frame.
func _process(_delta: float) -> void:
	if _pad == null:
		return
	_pad.set_state("a", {"sub": a_label, "enabled": a_active, "fill": a_progress if a_progress >= 0.0 else -1.0})
	_pad.set_state("b", {"draw": _draw_weapon_icon, "sub": b_count})
	_pad.set_hidden("x", not show_swap)
	_pad.visible = not wheel_open   # the weapon wheel takes every tap while it is open

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()

# ---------------------------------------------------------------- layout
# Positions are computed from the current size so the layout follows the screen.
func _dpad_center() -> Vector2:
	return Vector2(190.0, size.y - 190.0)

func _a_center() -> Vector2:
	return Vector2(size.x - 260.0, size.y - 120.0)

func _b_center() -> Vector2:
	return Vector2(size.x - 130.0, size.y - 240.0)

func _swap_center() -> Vector2:
	return Vector2(size.x - 385.0, size.y - 120.0)

func _pause_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5, size.y - 70.0) - PAUSE_SIZE * 0.5, PAUSE_SIZE)

## The bag button sits right of the pause button.
func _bag_rect() -> Rect2:
	return Rect2(_pause_rect().position + Vector2(PAUSE_SIZE.x + 18.0, 0), PAUSE_SIZE)

## v0.5: the map button sits left of the pause button.
func _map_rect() -> Rect2:
	return Rect2(_pause_rect().position - Vector2(PAUSE_SIZE.x + 18.0, 0), PAUSE_SIZE)

func _wheel_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.46)

# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_touch_seen = true
		_on_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_touch_seen = true
		_on_move(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not _touch_seen:
		_on_press(-1, event.position, event.pressed)
	elif event is InputEventMouseMotion and not _touch_seen:
		_on_move(-1, event.position)

func _on_press(id: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _pointers.has(id):
			return
		var role := _role_at(pos)
		if role == "":
			return
		_pointers[id] = role
		match role:
			"dpad":
				_set_dpad(pos)
			"a":
				_a_down = true
				Input.action_press("ls_action_a")
			"b":
				_b_down = true
				Input.action_press("ls_action_b")
			"swap":
				_swap_down = true
				wheel_pressed.emit()
			"pause":
				_pause_down = true
				pause_pressed.emit()
			"bag":
				_bag_down = true
				bag_pressed.emit()
			"map":
				_map_down = true
				map_pressed.emit()
			_:
				if role.begins_with("wheel:"):
					weapon_chosen.emit(role.substr(6))
				elif role.begins_with("region:"):
					region_tapped.emit(role.substr(7))
	else:
		if not _pointers.has(id):
			return
		match _pointers[id]:
			"dpad":
				_dpad_dir = Vector2.ZERO
				_apply_dpad()
			"a":
				_a_down = false
				Input.action_release("ls_action_a")
			"b":
				_b_down = false
				Input.action_release("ls_action_b")
			"swap":
				_swap_down = false
			"pause":
				_pause_down = false
			"bag":
				_bag_down = false
			"map":
				_map_down = false
		_pointers.erase(id)
	queue_redraw()

func _on_move(id: int, pos: Vector2) -> void:
	if _pointers.get(id, "") == "dpad":
		_set_dpad(pos)
		queue_redraw()

func _role_at(pos: Vector2) -> String:
	if _pad != null:
		# The Pad owns the stick and buttons: here only the open wheel and the world's tap areas.
		if wheel_open:
			return "wheel:" + _wheel_segment(pos)
		for n in tap_regions:
			if Rect2(tap_regions[n]).has_point(pos):
				return "region:" + n
		return ""
	if pos.distance_to(_dpad_center()) <= DPAD_RADIUS:
		return "dpad"
	if show_swap and pos.distance_to(_swap_center()) <= SWAP_RADIUS * 1.3:
		return "swap"
	if wheel_open:
		# Any other tap while the wheel is up picks a segment or closes it (not A / B / pause).
		return "wheel:" + _wheel_segment(pos)
	if pos.distance_to(_a_center()) <= BUTTON_RADIUS * 1.2:
		return "a"
	if pos.distance_to(_b_center()) <= BUTTON_RADIUS * 1.2:
		return "b"
	if _pause_rect().grow(12.0).has_point(pos):
		return "pause"
	if _bag_rect().grow(12.0).has_point(pos):
		return "bag"
	if _map_rect().grow(12.0).has_point(pos):
		return "map"
	for n in tap_regions:
		if Rect2(tap_regions[n]).has_point(pos):
			return "region:" + n
	return ""

## The weapon under a tap on the wheel, or "" (outside the ring / the middle).
func _wheel_segment(pos: Vector2) -> String:
	var d := pos - _wheel_center()
	if d.length() < WHEEL_INNER * 0.6 or d.length() > WHEEL_OUTER * 1.2:
		return ""
	# angle measured clockwise from straight up; one segment per weapon, the first one centered on top
	var n := WHEEL_ORDER.size()
	var seg := TAU / n
	var a := fposmod(atan2(d.x, -d.y) + seg * 0.5, TAU)
	return WHEEL_ORDER[int(a / seg) % n]

## True D-pad: only the dominant axis counts, so Nash walks in 4 directions. Near a diagonal the
## current axis is kept (hysteresis), so a thumb resting at 45 degrees doesn't flicker between two
## directions (that read as stuttery, "laggy" movement).
func _set_dpad(pos: Vector2) -> void:
	var d := pos - _dpad_center()
	if d.length() < DPAD_DEADZONE:
		_dpad_dir = Vector2.ZERO
	else:
		var horizontal: bool
		if _dpad_dir.x != 0.0:
			horizontal = absf(d.y) <= absf(d.x) * DPAD_HYSTERESIS
		elif _dpad_dir.y != 0.0:
			horizontal = absf(d.x) > absf(d.y) * DPAD_HYSTERESIS
		else:
			horizontal = absf(d.x) > absf(d.y)
		_dpad_dir = Vector2(signf(d.x), 0.0) if horizontal else Vector2(0.0, signf(d.y))
	_apply_dpad()

func _apply_dpad() -> void:
	_set_action(MOVE_ACTIONS.left, _dpad_dir.x < 0.0)
	_set_action(MOVE_ACTIONS.right, _dpad_dir.x > 0.0)
	_set_action(MOVE_ACTIONS.up, _dpad_dir.y < 0.0)
	_set_action(MOVE_ACTIONS.down, _dpad_dir.y > 0.0)

func _set_action(action: String, down: bool) -> void:
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_all() -> void:
	if _pad != null and is_instance_valid(_pad):
		_pad.release_all()
	for a in MOVE_ACTIONS.values():
		Input.action_release(a)
	Input.action_release("ls_action_a")
	Input.action_release("ls_action_b")

# ---------------------------------------------------------------- drawing (placeholder look)
func _draw() -> void:
	if _pad != null:
		if wheel_open:
			_draw_wheel()
		return
	var c := _dpad_center()
	# One arrow per direction; lit when pressed.
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_draw_arrow(c, dir, _dpad_dir == dir)
	_draw_a()
	_draw_b()
	if show_swap:
		var sc := _swap_center()
		draw_circle(sc, SWAP_RADIUS, Color(1, 1, 1, 0.5 if (_swap_down or wheel_open) else 0.18))
		draw_arc(sc, SWAP_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)
		Icons.draw(self, "wheel", sc, 40.0, 0.9)
	var r := _pause_rect()
	draw_rect(r, Color(1, 1, 1, 0.5 if _pause_down else 0.2), true)
	draw_rect(r, Color(1, 1, 1, 0.6), false, 3.0)
	# Pause icon: two bars.
	draw_rect(Rect2(r.get_center() + Vector2(-12, -10), Vector2(8, 20)), Color(1, 1, 1, 0.7))
	draw_rect(Rect2(r.get_center() + Vector2(4, -10), Vector2(8, 20)), Color(1, 1, 1, 0.7))
	var br := _bag_rect()
	draw_rect(br, Color(1, 1, 1, 0.5 if _bag_down else 0.2), true)
	draw_rect(br, Color(1, 1, 1, 0.6), false, 3.0)
	Icons.draw(self, "bag", br.get_center() + Vector2(0, 1), 34.0, 0.9)
	var mr := _map_rect()
	draw_rect(mr, Color(1, 1, 1, 0.5 if _map_down else 0.2), true)
	draw_rect(mr, Color(1, 1, 1, 0.6), false, 3.0)
	Icons.draw(self, "map", mr.get_center(), 34.0, 0.9)
	if wheel_open:
		_draw_wheel()

func _draw_arrow(center: Vector2, dir: Vector2, lit: bool) -> void:
	var side := Vector2(-dir.y, dir.x)
	var tip := center + dir * 120.0
	var base := center + dir * 50.0
	var pts := PackedVector2Array([tip, base + side * 44.0, base - side * 44.0])
	draw_colored_polygon(pts, Color(1, 1, 1, 0.5 if lit else 0.18))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(1, 1, 1, 0.6), 3.0)

func _button_base(center: Vector2, down: bool) -> void:
	draw_circle(center, BUTTON_RADIUS, Color(1, 1, 1, 0.5 if down else 0.18))
	draw_arc(center, BUTTON_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)

## Text centered on a point, shrunk until it fits `max_w` pixels.
func _centered_text(center: Vector2, text: String, size_px: int, max_w: float, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := size_px
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while w > max_w and fs > 12:
		fs -= 1
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	var pos := center + Vector2(-w * 0.5, asc * 0.5 - 2.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.55))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

## A: the action word ("USE" dimmed when there is nothing to do), and a ring while searching.
func _draw_a() -> void:
	var c := _a_center()
	_button_base(c, _a_down)
	if a_progress >= 0.0:
		draw_arc(c, BUTTON_RADIUS - 7.0, -PI * 0.5, -PI * 0.5 + TAU * a_progress, 40, A.AMBER, 8.0)
	var col := Color(1, 1, 1, 0.95) if a_active else Color(1, 1, 1, 0.4)
	_centered_text(c, a_label, 26, BUTTON_RADIUS * 2.0 - 20.0, col)

## B: the equipped weapon's icon, with the bullets left under the pistol.
func _draw_b() -> void:
	var c := _b_center()
	_button_base(c, _b_down)
	Icons.draw(self, b_icon, c + Vector2(0, -4 if b_count != "" else 0), 64.0, 0.95)
	if b_count != "":
		_centered_text(c + Vector2(0, 34), b_count, 20, 80.0, Color.WHITE)

func _draw_wheel() -> void:
	var wc := _wheel_center()
	draw_circle(wc, WHEEL_OUTER + 10.0, Color(0, 0, 0, 0.45))
	var n := WHEEL_ORDER.size()
	var seg := TAU / n
	for i in n:
		var wid: String = WHEEL_ORDER[i]
		var item: Dictionary = wheel_items.get(wid, {"owned": false, "count": ""})
		var mid := -PI * 0.5 + i * seg
		var owned: bool = item.owned
		var sel := wid == wheel_equipped
		var fill := Color(0.88, 0.6, 0.1, 0.75) if sel else (Color(0.12, 0.12, 0.15, 0.85) if owned else Color(0.08, 0.08, 0.1, 0.6))
		# segment: a thick arc between the inner and outer radius, with gaps between segments
		var r_mid := (WHEEL_OUTER + WHEEL_INNER) * 0.5
		draw_arc(wc, r_mid, mid - seg * 0.5 + 0.05, mid + seg * 0.5 - 0.05, 24, fill, WHEEL_OUTER - WHEEL_INNER)
		draw_arc(wc, WHEEL_OUTER, mid - seg * 0.5 + 0.05, mid + seg * 0.5 - 0.05, 24, Color(1, 1, 1, 0.5), 2.0)
		var ic := wc + Vector2(cos(mid), sin(mid)) * r_mid
		if owned:
			Icons.draw(self, wid, ic + Vector2(0, -6), 50.0)
			if item.count != "":
				_centered_text(ic + Vector2(0, 30), item.count, 18, 70.0, Color.WHITE)
		else:
			_centered_text(ic, "?", 34, 60.0, Color(1, 1, 1, 0.35))
	# the middle: the equipped weapon's name
	draw_circle(wc, WHEEL_INNER - 4.0, Color(0.06, 0.06, 0.08, 0.92))
	draw_arc(wc, WHEEL_INNER - 4.0, 0.0, TAU, 32, A.AMBER, 2.5)
	_centered_text(wc, str(wheel_names.get(wheel_equipped, "")), 18, WHEEL_INNER * 2.0 - 20.0, Color("ffd479"))
