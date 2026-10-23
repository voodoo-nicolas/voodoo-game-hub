extends Control

## Pad Lab: a dev-only test bed for the shared on-screen controller (scripts/common/pad/).
## NOT in the catalog or the manifest; it runs from the PadLabDev app or the editor.
## A ship to steer, targets to shoot, and a live readout of every input, so you can feel each layout:
##   move stick / D-pad  steer          aim stick (twin-stick layout)  aim + fire
##   A  fire (when there is no aim stick)    B  dash    X  ping ring    Y  spawn a target
##   pause button  opens / closes the settings panel      info button  toggles the button map
## The top bar cycles layouts and looks. Keyboard on PC: WASD move, arrows aim, K L J I = A B X Y.

const Pad = preload("res://scripts/common/pad/pad_controller.gd")
const Options = preload("res://scripts/common/pad/pad_options.gd")
const Orientation = preload("res://scripts/common/orientation.gd")

const SHIP_SPEED := 460.0
const BULLET_SPEED := 900.0
const FIRE_GAP := 0.14
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.7
const MAX_TARGETS := 9

var pad: Control
var _opts_panel: PanelContainer
var _readout: Label
var _layout_label: Label
var _skin_button: Button

var _ship := Vector2.ZERO
var _vel := Vector2.ZERO
var _angle := -PI * 0.5
var _bullets: Array = []
var _targets: Array = []
var _rings: Array = []
var _fire_t := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _score := 0
var _shots := 0
var _readout_t := 0.0
var _seed_done := false

func _ready() -> void:
	Orientation.lock_landscape()
	pad = Pad.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pad)
	pad.button_pressed.connect(_on_pad_button)
	pad.layout_changed.connect(_on_layout_changed)
	_build_ui()
	resized.connect(_on_resized)
	_on_resized()
	_on_layout_changed()

func _pal() -> Dictionary:
	var s := get_node_or_null("/root/Settings")
	return s.palette() if s != null else {
		"text": Color.WHITE, "text_dim": Color(0.7, 0.8, 0.9), "accent": Color(1.0, 0.6, 0.22),
		"accent_fill": Color(0.5, 0.2, 0.06, 0.85), "off_fill": Color(0.09, 0.12, 0.18, 0.9),
		"off_border": Color(0.3, 0.38, 0.48), "card_fill": Color(0.03, 0.06, 0.13, 0.92),
	}

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	var pal := _pal()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_top = 10
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(bar)
	bar.add_child(_bar_button("‹", _on_prev))
	_layout_label = Label.new()
	_layout_label.custom_minimum_size = Vector2(300, 0)
	_layout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layout_label.add_theme_font_size_override("font_size", 22)
	bar.add_child(_layout_label)
	bar.add_child(_bar_button("›", _on_next))
	_skin_button = _bar_button("Look", _on_skin)
	bar.add_child(_skin_button)
	bar.add_child(_bar_button("Settings", _toggle_options))
	bar.add_child(_bar_button("Map", _toggle_map))
	_readout = Label.new()
	_readout.position = Vector2(14, 66)
	_readout.add_theme_font_size_override("font_size", 16)
	_readout.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_readout)
	# Settings drawer: between the two thumbs so the controller stays usable (and visible) while tuning.
	_opts_panel = PanelContainer.new()
	_opts_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(pal.card_fill, 0.94)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = pal.off_border
	sb.set_content_margin_all(12)
	_opts_panel.add_theme_stylebox_override("panel", sb)
	add_child(_opts_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_opts_panel.add_child(scroll)
	var opts: VBoxContainer = Options.new(pal, pad)
	opts.columns = 1
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(opts)

func _bar_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(70, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b

func _on_resized() -> void:
	if _opts_panel == null:
		return
	_opts_panel.position = Vector2(size.x * 0.27, 70.0)
	_opts_panel.size = Vector2(size.x * 0.46, maxf(160.0, size.y - 70.0 - 150.0))
	if not _seed_done and size.x > 100.0:
		_seed_done = true
		_ship = size * 0.5
		for i in 5:
			_spawn_target()

func _on_layout_changed() -> void:
	if _layout_label != null:
		_layout_label.text = pad.layout_name()
		_skin_button.text = str(pad.prefs.get("skin", "")).capitalize()

func _on_prev() -> void:
	pad.step_layout(-1)

func _on_next() -> void:
	pad.step_layout(1)

func _on_skin() -> void:
	pad.step_skin(1)

func _toggle_options() -> void:
	_opts_panel.visible = not _opts_panel.visible

func _toggle_map() -> void:
	pad.set_pref("show_map", not bool(pad.prefs.get("show_map", false)))

func _on_pad_button(id: String) -> void:
	match id:
		"pause":
			_toggle_options()
		"info":
			_toggle_map()
		"b":
			if _dash_cd <= 0.0:
				_dash_t = DASH_TIME
				_dash_cd = DASH_COOLDOWN
		"x":
			_rings.append({"p": _ship, "r": 20.0})
		"y":
			_spawn_target()

# ---------------------------------------------------------------- the toy
func _spawn_target() -> void:
	if _targets.size() >= MAX_TARGETS + 6:
		return
	var r := randf_range(22.0, 40.0)
	var side := randi() % 4
	var p := Vector2(randf_range(0.0, size.x), randf_range(0.0, size.y))
	match side:
		0: p.y = -r
		1: p.y = size.y + r
		2: p.x = -r
		_: p.x = size.x + r
	var toward := (size * Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8)) - p).normalized()
	_targets.append({"p": p, "v": toward * randf_range(40.0, 110.0), "r": r})

func _physics_process(delta: float) -> void:
	if size.x < 100.0:
		return
	var mv: Vector2 = pad.get_vector("move")
	var has_aim: bool = pad.has_part("aim")
	var speed := SHIP_SPEED
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if _dash_t > 0.0:
		_dash_t -= delta
		speed *= 2.4
	_vel = _vel.lerp(mv * speed, clampf(delta * 14.0, 0.0, 1.0))
	_ship = (_ship + _vel * delta).clamp(Vector2(16, 16), size - Vector2(16, 16))
	var firing := false
	if has_aim:
		var aim: Vector2 = pad.get_vector("aim")
		if aim.length() > 0.2:
			_angle = aim.angle()
		firing = Input.is_action_pressed("pad_fire")
	else:
		if mv.length() > 0.2:
			_angle = mv.angle()
		firing = pad.is_down("a")
	_fire_t -= delta
	if firing and _fire_t <= 0.0:
		_fire_t = FIRE_GAP
		_shots += 1
		_bullets.append({"p": _ship, "v": Vector2.from_angle(_angle) * BULLET_SPEED, "t": 1.2})
	for b in _bullets:
		b["p"] += b["v"] * delta
		b["t"] -= delta
	_bullets = _bullets.filter(func(b): return b["t"] > 0.0)
	for t in _targets:
		t["p"] += t["v"] * delta
	for t in _targets.duplicate():
		for b in _bullets:
			if b["p"].distance_to(t["p"]) < t["r"] + 6.0:
				b["t"] = 0.0
				_targets.erase(t)
				_score += 1
				_rings.append({"p": t["p"], "r": 10.0})
				break
	_targets = _targets.filter(func(t): return t["p"].x > -120.0 and t["p"].x < size.x + 120.0 and t["p"].y > -120.0 and t["p"].y < size.y + 120.0)
	while _targets.size() < 5:
		_spawn_target()
	for r in _rings:
		r["r"] += 380.0 * delta
	_rings = _rings.filter(func(r): return r["r"] < 260.0)
	_readout_t -= delta
	if _readout_t <= 0.0:
		_readout_t = 0.08
		_update_readout()
	queue_redraw()

func _update_readout() -> void:
	var lines: Array = []
	lines.append("%s | %s | size %d%% | opacity %d%%" % [pad.layout_name(), str(pad.prefs["skin"]), int(round(float(pad.prefs["size"]) * 100.0)), int(round(float(pad.prefs["opacity"]) * 100.0))])
	for id in ["move", "aim"]:
		if pad.has_part(id):
			var v: Vector2 = pad.get_vector(id)
			lines.append("%s  (%+.2f, %+.2f)  len %.2f" % [id, v.x, v.y, v.length()])
	var down: Array = []
	for id in ["a", "b", "x", "y", "pause", "info"]:
		if pad.has_part(id) and pad.is_down(id):
			down.append(id.to_upper())
	if Input.is_action_pressed("pad_fire"):
		down.append("FIRE")
	lines.append("down: %s   fingers: %d" % [", ".join(down) if not down.is_empty() else "-", pad.finger_count()])
	lines.append("score %d   shots %d   fps %d" % [_score, _shots, Engine.get_frames_per_second()])
	_readout.text = "\n".join(lines)

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.07))
	var step := 80.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.12, 0.2, 0.34, 0.35), 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.2, 0.34, 0.35), 1.0)
		y += step
	for t in _targets:
		draw_circle(t["p"], t["r"], Color(0.9, 0.25, 0.4, 0.25))
		draw_arc(t["p"], t["r"], 0.0, TAU, 28, Color(1.0, 0.4, 0.55), 3.0, true)
	for r in _rings:
		draw_arc(r["p"], r["r"], 0.0, TAU, 40, Color(0.5, 0.9, 1.0, clampf(1.0 - r["r"] / 260.0, 0.0, 1.0)), 3.0, true)
	for b in _bullets:
		draw_circle(b["p"], 5.0, Color(1.0, 0.9, 0.4))
	var fwd := Vector2.from_angle(_angle)
	var side := Vector2(-fwd.y, fwd.x)
	var col := Color(0.4, 1.0, 0.7) if _dash_t <= 0.0 else Color(1, 1, 1)
	draw_colored_polygon(PackedVector2Array([_ship + fwd * 26.0, _ship - fwd * 16.0 + side * 15.0, _ship - fwd * 8.0, _ship - fwd * 16.0 - side * 15.0]), Color(col, 0.35))
	draw_polyline(PackedVector2Array([_ship + fwd * 26.0, _ship - fwd * 16.0 + side * 15.0, _ship - fwd * 8.0, _ship - fwd * 16.0 - side * 15.0, _ship + fwd * 26.0]), col, 3.0, true)
