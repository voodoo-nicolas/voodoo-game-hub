extends Control

## The mission log, top-right of the screen. Tap it (or press L) to open the list: open steps first
## (newest at the top), then the finished ones, ticked and struck through. Tap again to close.
## `entries` = [{"text": English text, "done": bool, "main": bool, "side": bool}] in the order they
## appeared; the texts are translated here.
## v0.5 (playtest: "the game shouldn't start with the mission to escape"): the night starts as a
## normal shift: the header says NIGHT SHIFT. After the first attack ESCAPE! is a quest of its own
## ("main"): it is always listed first, in red, and the header says ESCAPE!. Closed, the header shows
## the newest main-route step still to do (a side quest only when no main-route step is open).

const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")

const WIDTH := 470.0
const PAD := 12.0
const HEAD_FS := 20
const LINE_FS := 17
const LINE_H := 27.0
const MAX_LINES := 10
const AMBER := Color("ffd479")
const RED := Color("ff6a4a")

var entries: Array = []
var expanded := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # taps come through the touch controls
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_entries(list: Array) -> void:
	entries = list.duplicate(true)
	queue_redraw()

func toggle() -> void:
	expanded = not expanded
	queue_redraw()

## The tappable header, in screen pixels.
func header_rect() -> Rect2:
	return Rect2(position, Vector2(WIDTH, _head_h()))

func _head_h() -> float:
	return 42.0

func _font() -> Font:
	return ThemeDB.fallback_font

func _box(r: Rect2) -> void:
	draw_rect(r, Color(0.055, 0.055, 0.07, 0.84))
	draw_rect(r, Color("0e0e12"), false, 2.0)

## Open steps: the main quest first, then the others, newest first.
func _open() -> Array:
	var out: Array = []
	var main: Array = []
	for e in entries:
		if e.done:
			continue
		if e.get("main", false):
			main.append(e)
		else:
			out.push_front(e)
	return main + out

## The step shown in the closed header: the newest open main-route step, else the newest side quest.
func _header_step() -> Dictionary:
	var side: Dictionary = {}
	for e in _open():
		if e.get("main", false):
			continue
		if not e.get("side", false):
			return e
		if side.is_empty():
			side = e
	return side

func _escaping() -> bool:
	for e in entries:
		if e.get("main", false) and not e.done:
			return true
	return false

## Finished steps, most recent first.
func _done() -> Array:
	var out: Array = []
	for e in entries:
		if e.done:
			out.push_front(e)
	return out

func _fit(text: String, fs: int, max_w: float) -> int:
	var f := _font()
	while f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and fs > 11:
		fs -= 1
	return fs

func _draw() -> void:
	if entries.is_empty():
		return
	var f := _font()
	var open := _open()
	var head := Rect2(Vector2.ZERO, Vector2(WIDTH, _head_h()))
	_box(head)
	draw_rect(Rect2(0, 0, 4, head.size.y), RED)
	# chevron: points down when closed (there is a list to open), up when open
	var cx := WIDTH - 22.0
	var cy := head.size.y * 0.5
	var pts := PackedVector2Array([Vector2(cx - 7, cy - 3), Vector2(cx + 7, cy - 3), Vector2(cx, cy + 5)]) if not expanded \
		else PackedVector2Array([Vector2(cx - 7, cy + 3), Vector2(cx + 7, cy + 3), Vector2(cx, cy - 5)])
	draw_colored_polygon(pts, AMBER)
	# ESCAPE! (or NIGHT SHIFT before the first attack) + the newest open step
	var main := tr(LsText.UI.escape) if _escaping() else tr(LsText.UI.night_shift)
	var mfs := HEAD_FS + 2
	var base_y := cy + f.get_ascent(mfs) * 0.5 - 2
	draw_string_outline(f, Vector2(PAD, base_y), main, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, 4, Color.BLACK)
	draw_string(f, Vector2(PAD, base_y), main, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, RED if _escaping() else AMBER)
	var mw := f.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x + PAD + 10
	var head_step := _header_step()
	if not head_step.is_empty():
		var step := tr(head_step.text)
		var sfs := _fit(step, HEAD_FS - 2, WIDTH - mw - 40.0)
		var sy := cy + f.get_ascent(sfs) * 0.5 - 2
		draw_string_outline(f, Vector2(mw, sy), step, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, 4, Color.BLACK)
		draw_string(f, Vector2(mw, sy), step, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, AMBER)
	if not expanded:
		return
	var shown: Array = (open + _done()).slice(0, MAX_LINES)
	var list := Rect2(0, head.size.y + 4, WIDTH, PAD + 14 + shown.size() * LINE_H + 4)
	_box(list)
	draw_string(f, Vector2(PAD, list.position.y + 4 + f.get_ascent(14)), tr(LsText.UI.mission_log), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.45))
	for i in shown.size():
		var y := list.position.y + PAD + 18 + i * LINE_H
		var done: bool = shown[i].done
		var is_main: bool = shown[i].get("main", false)
		var text: String = tr(shown[i].text)
		var lfs := _fit(text, LINE_FS + (2 if is_main else 0), WIDTH - 60.0)
		var base := Vector2(40, y + f.get_ascent(lfs))
		var col := RED if is_main else AMBER
		if not done:
			draw_colored_polygon(PackedVector2Array([Vector2(16, y + 6), Vector2(27, y + 12), Vector2(16, y + 18)]), col)
		else:
			# a tick, and the line struck through
			draw_polyline(PackedVector2Array([Vector2(14, y + 12), Vector2(19, y + 17), Vector2(29, y + 6)]), Color("6fbf5a"), 3.0)
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
			draw_line(base + Vector2(0, -lfs * 0.32), base + Vector2(tw, -lfs * 0.32), Color(1, 1, 1, 0.4), 1.5)
		draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, col if not done else Color(1, 1, 1, 0.5))
