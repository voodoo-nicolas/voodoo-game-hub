extends Node

## Drag + momentum scrolling for the new Game Browser: horizontal ScrollContainers in
## group "nx_row_scroll" (the category bar, the tile strip), optionally one vertical
## ScrollContainer (`vertical`). A press that travels past THRESHOLD locks to one
## axis: sideways over a row scrolls that row. On release the movement coasts.
## `bounds` limits where drags count when there is no `vertical`.
##
## Like DragScroll, `moved` stays true from the first drag until the next press, so
## tile / button handlers ignore the release that ends a drag. Phones send touch as
## emulated mouse, so only the mouse events are read. It never consumes input.

const THRESHOLD := 12.0
const FRICTION := 0.04          # fraction of speed left after one second
const STOP_SPEED := 25.0        # px/s

signal vertical_scrolled

var vertical: ScrollContainer
var bounds: Control
var moved := false
var _tracking := false
var _axis := 0                   # 0 undecided, 1 sideways, 2 vertical
var _row: ScrollContainer
var _start := Vector2.ZERO
var _start_scroll := Vector2.ZERO
var _last := Vector2.ZERO
var _last_msec := 0
var _vel := Vector2.ZERO
var _coast := false
var _fx := 0.0                   # float scroll positions while coasting
var _fy := 0.0

func _input(event: InputEvent) -> void:
	var area: Control = vertical if vertical != null else bounds
	if area == null or not area.is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var wheel_row := _row_under(event.position)
		if wheel_row != null and not _overlay_open():
			var step: float = float(wheel_row.get_meta("snap_step", 120.0))
			var dir := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			wheel_row.scroll_horizontal += int(step * dir)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_coast = false
			moved = false
			_axis = 0
			_vel = Vector2.ZERO
			_tracking = not _overlay_open() and area.get_global_rect().has_point(event.position)
			_row = _row_under(event.position) if _tracking else null
			_start = event.position
			_last = event.position
			_last_msec = Time.get_ticks_msec()
			_start_scroll = Vector2(_row.scroll_horizontal if _row else 0, vertical.scroll_vertical if vertical else 0)
		else:
			if _tracking and moved and _vel.length() > STOP_SPEED * 4.0:
				_coast = true
				_fx = float(_row.scroll_horizontal) if _row else 0.0
				_fy = float(vertical.scroll_vertical) if vertical else 0.0
			elif _tracking and moved and _axis == 1:
				_snap(_row)
			_tracking = false
	elif event is InputEventMouseMotion and _tracking and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var d: Vector2 = event.position - _start
		if _axis == 0 and maxf(absf(d.x), absf(d.y)) > THRESHOLD:
			moved = true
			_axis = 1 if (absf(d.x) > absf(d.y) and _row != null) else (2 if vertical != null else 3)
		if _axis == 0 or _axis == 3:
			return
		var now := Time.get_ticks_msec()
		var dt := maxf(0.001, (now - _last_msec) / 1000.0)
		var inst: Vector2 = (event.position - _last) / dt
		_vel = _vel.lerp(inst, 0.4)
		_last = event.position
		_last_msec = now
		if _axis == 1:
			_row.scroll_horizontal = int(_start_scroll.x - d.x)
		else:
			vertical.scroll_vertical = int(_start_scroll.y - d.y)
			vertical_scrolled.emit()

func _process(delta: float) -> void:
	if not _coast:
		return
	_vel *= pow(FRICTION, delta)
	if _axis == 1 and is_instance_valid(_row):
		_fx -= _vel.x * delta
		var before := _row.scroll_horizontal
		_row.scroll_horizontal = int(_fx)
		if _row.scroll_horizontal == before and absf(_vel.x) > STOP_SPEED:
			_vel.x = 0.0  # hit an end
		if absf(_vel.x) < STOP_SPEED:
			_coast = false
			_snap(_row)
	elif _axis == 2:
		_fy -= _vel.y * delta
		var before := vertical.scroll_vertical
		vertical.scroll_vertical = int(_fy)
		vertical_scrolled.emit()
		if vertical.scroll_vertical == before and absf(_vel.y) > STOP_SPEED:
			_vel.y = 0.0
		if absf(_vel.y) < STOP_SPEED:
			_coast = false
	else:
		_coast = false

func _row_under(pos: Vector2) -> ScrollContainer:
	for n in get_tree().get_nodes_in_group("nx_row_scroll"):
		var s := n as ScrollContainer
		if s != null and s.is_visible_in_tree() and s.get_global_rect().has_point(pos):
			return s
	return null

func _overlay_open() -> bool:
	for n in get_tree().get_nodes_in_group("modal_overlay"):
		if not n.is_queued_for_deletion() and n.is_visible_in_tree():
			return true
	return false

## A row with a "snap_step" meta (the tile strip) settles on a whole tile.
func _snap(row: ScrollContainer) -> void:
	if row == null or not is_instance_valid(row) or not row.has_meta("snap_step"):
		return
	var step: float = float(row.get_meta("snap_step"))
	var bar := row.get_h_scroll_bar()
	var max_scroll := bar.max_value - bar.page
	var target := minf(roundf(row.scroll_horizontal / step) * step, max_scroll)
	var t := Settings.anim_time(0.18)
	if t <= 0.0:
		row.scroll_horizontal = int(target)
		return
	var tw := row.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(row, "scroll_horizontal", int(target), t)
