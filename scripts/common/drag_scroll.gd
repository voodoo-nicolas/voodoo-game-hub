extends Node

## Drag-anywhere scrolling for a ScrollContainer full of buttons.
##
## Buttons swallow the press, so on its own a ScrollContainer of full-size
## buttons only scrolls from its thin scrollbar. Add one of these as a child
## of the ScrollContainer (`scroll.add_child(DragScroll.new())`) and the list
## follows the finger (or mouse -- Android emulates mouse from touch).
##
## `moved` turns true once a press travels past THRESHOLD and stays true
## until the next press: button handlers check it and ignore the release
## that ends a drag, so dragging never opens what it started on.
## Dialogs drawn over the list join the "modal_overlay" group to block it.

const THRESHOLD := 14.0

var moved: bool = false
var _tracking: bool = false
var _start := Vector2.ZERO
var _start_scroll: int = 0

func _input(event: InputEvent) -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll == null or not scroll.is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			moved = false
			_tracking = not _overlay_open() and scroll.get_global_rect().has_point(event.position) \
					and not get_viewport().gui_get_hovered_control() is Slider  # sliding a volume isn't scrolling
			_start = event.position
			_start_scroll = scroll.scroll_vertical
		else:
			_tracking = false
	elif event is InputEventMouseMotion and _tracking and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var dy: float = event.position.y - _start.y
		if not moved and absf(dy) > THRESHOLD:
			moved = true
		if moved:
			scroll.scroll_vertical = _start_scroll - int(dy)

func _overlay_open() -> bool:
	for n in get_tree().get_nodes_in_group("modal_overlay"):
		if not n.is_queued_for_deletion() and n.is_visible_in_tree():
			return true
	return false
