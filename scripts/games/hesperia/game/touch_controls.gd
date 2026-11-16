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
			if p.distance_to(BTN[a]["c"]) < float(BTN[a]["r"]) + 6.0:
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
		Input.action_press(a)
	else:
		Input.action_release(a)
	queue_redraw()

func _draw() -> void:
	if not enabled:
		return
	var alpha := 0.35
	draw_circle(PAD_C, PAD_R, Color(1, 1, 1, 0.08))
	draw_circle(PAD_C + pad_vec * PAD_R * 0.6, 14.0, Color(1, 1, 1, alpha))
	for a in BTN.keys():
		var c: Vector2 = BTN[a]["c"]
		draw_circle(c, float(BTN[a]["r"]), Color(1, 1, 1, 0.5 if held[a] else 0.18))
		draw_string(ThemeDB.fallback_font, c + Vector2(-4, 4), BTN[a]["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
