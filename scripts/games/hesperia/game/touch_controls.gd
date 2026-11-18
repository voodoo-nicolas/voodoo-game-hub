extends Control
## On-screen controls: d-pad left, A (sword) / B (shield, lift) / X / Y right, pause + menu centre.
## Feeds the InputMap actions, so game code only ever reads actions. Multi-touch via ScreenTouch/ScreenDrag on
## touch screens; mouse only on desktop (phones send taps twice, so mouse events are ignored when a touch screen exists).

const PAD_C := Vector2(48, 168)
const PAD_R := 36.0
const BTN := {
	"btn_a": {"c": Vector2(352, 176), "r": 17.0, "t": "A"},
	"btn_b": {"c": Vector2(326, 194), "r": 15.0, "t": "B"},
	"btn_x": {"c": Vector2(326, 158), "r": 15.0, "t": "X"},
	"btn_y": {"c": Vector2(300, 176), "r": 15.0, "t": "Y"},
	"pause": {"c": Vector2(172, 202), "r": 11.0, "t": "||"},
	"menu": {"c": Vector2(212, 202), "r": 11.0, "t": "="},
}
var touches: Dictionary = {}    # finger index -> {"kind": "pad"|action, ...}
var pad_vec: Vector2 = Vector2.ZERO
var held: Dictionary = {}
var enabled: bool = true
const UiTheme := preload("res://scripts/games/hesperia/game/ui_theme.gd")
var press_t: Dictionary = {}    # visual: pop on press

## Button centre in the real viewport: the right cluster sticks to the right edge, the centre pair to the centre.
func _c(a: String) -> Vector2:
	var c: Vector2 = BTN[a]["c"]
	var dx := get_viewport_rect().size.x - 384.0
	if c.x > 250.0:
		return c + Vector2(dx, 0)
	if c.x > 150.0:
		return c + Vector2(dx * 0.5, 0)
	return c

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in BTN.keys():
		held[a] = false

func _input(ev: InputEvent) -> void:
	if not visible or not enabled:
		return
	var ts := DisplayServer.is_touchscreen_available()
	if ev is InputEventScreenTouch:
		_touch(ev.index, ev.position, ev.pressed)
	elif ev is InputEventScreenDrag:
		_drag(ev.index, ev.position)
	elif not ts and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_touch(-1, ev.position, ev.pressed)
	elif not ts and ev is InputEventMouseMotion and touches.has(-1):
		_drag(-1, ev.position)

func _touch(idx: int, p: Vector2, down: bool) -> void:
	if down:
		if p.distance_to(PAD_C) < PAD_R * 1.8:
			touches[idx] = {"kind": "pad"}
			_set_pad(p)
			return
		for a in BTN.keys():
			if p.distance_to(_c(a)) < float(BTN[a]["r"]) + 6.0:
				touches[idx] = {"kind": a}
				_press(a, true)
				return
	elif touches.has(idx):
		var k: String = touches[idx]["kind"]
		touches.erase(idx)
		if k == "pad":
			_set_pad(PAD_C)
		else:
			_press(k, false)

func _drag(idx: int, p: Vector2) -> void:
	if touches.has(idx) and touches[idx]["kind"] == "pad":
		_set_pad(p)

func _set_pad(p: Vector2) -> void:
	var v := (p - PAD_C)
	pad_vec = Vector2.ZERO if v.length() < 8.0 else v.limit_length(PAD_R) / PAD_R
	_axis("mv_left", maxf(0.0, -pad_vec.x))
	_axis("mv_right", maxf(0.0, pad_vec.x))
	_axis("mv_up", maxf(0.0, -pad_vec.y))
	_axis("mv_down", maxf(0.0, pad_vec.y))
	queue_redraw()

func _axis(a: String, s: float) -> void:
	if s > 0.35:
		Input.action_press(a, s)
	else:
		Input.action_release(a)

func _press(a: String, down: bool) -> void:
	held[a] = down
	if down:
		press_t[a] = 0.15
		Input.action_press(a)
	else:
		Input.action_release(a)
	queue_redraw()

func _process(dt: float) -> void:
	if press_t.is_empty():
		return
	for a in press_t.keys():
		press_t[a] -= dt
		if press_t[a] <= 0.0:
			press_t.erase(a)
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	# pad: dark well, bronze ring, 4 chevrons that light toward the stick, knob with highlight
	var bronze := Color(0.85, 0.65, 0.35)
	draw_circle(PAD_C, PAD_R, Color(0.03, 0.02, 0.05, 0.28))
	draw_arc(PAD_C, PAD_R, 0.0, TAU, 40, Color(bronze.r, bronze.g, bronze.b, 0.4), 1.0)
	for dv in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var on := pad_vec.dot(dv) > 0.4
		var tip: Vector2 = PAD_C + dv * (PAD_R - 5.0)
		var side := Vector2(-dv.y, dv.x) * 3.0
		draw_colored_polygon(PackedVector2Array([tip, tip - dv * 4.0 + side, tip - dv * 4.0 - side]), Color(1, 0.9, 0.6, 0.85 if on else 0.3))
	var kc := PAD_C + pad_vec * PAD_R * 0.6
	draw_circle(kc + Vector2(0, 1), 14.0, Color(0, 0, 0, 0.25))
	draw_circle(kc, 14.0, Color(1, 1, 1, 0.22 if pad_vec == Vector2.ZERO else 0.36))
	draw_arc(kc, 14.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 1.0)
	draw_arc(kc, 10.0, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.35), 1.0)
	var tint := {"btn_a": Color(0.95, 0.75, 0.35), "btn_b": Color(0.85, 0.4, 0.35), "btn_x": Color(0.45, 0.7, 0.9), "btn_y": Color(0.55, 0.8, 0.45)}
	for a in BTN.keys():
		var c: Vector2 = _c(a)
		var r := float(BTN[a]["r"]) * (1.0 + 0.12 * float(press_t.get(a, 0.0)) / 0.15)
		var tc: Color = tint.get(a, Color(0.85, 0.85, 0.9))
		draw_circle(c + Vector2(0, 1), r, Color(0, 0, 0, 0.25))
		draw_circle(c, r, Color(0.04, 0.03, 0.06, 0.55 if held[a] else 0.32))
		if held[a]:
			draw_circle(c, r - 1.0, Color(tc.r, tc.g, tc.b, 0.35))
		draw_arc(c, r, 0.0, TAU, 32, Color(tc.r, tc.g, tc.b, 0.85 if held[a] else 0.5), 1.0)
		draw_arc(c, r - 2.0, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.25), 1.0)
		var fs := 10   # Micro 5 native size
		var tw := UiTheme.font().get_string_size(BTN[a]["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(UiTheme.font(), c + Vector2(-tw * 0.5, 4), BTN[a]["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.6))
		draw_string(UiTheme.font(), c + Vector2(-tw * 0.5, 4), BTN[a]["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.97, 0.9, 0.95 if held[a] else 0.8))
