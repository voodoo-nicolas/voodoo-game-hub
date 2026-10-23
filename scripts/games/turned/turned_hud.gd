extends Control

## Turned's on-screen controls and HUD (Turned CLAUDE.md section 3), drawn in code over the world.
##   top-left  : Health (red), Blood (blue), XP (yellow) bars + the sun-tolerance icon
##   top-right : Missions box (one line; tap opens the quest log)
##   bottom-left : D-pad, four arrows, 8-way by pressing two (or sliding the thumb into a corner)
##   bottom-right: face buttons in a diamond: A bottom, B right, X left, Y top. Only A and B exist
##                 so far; a locked button is not shown at all and pops in when it unlocks.
##   bottom-centre: small Pause and Menu buttons.
## Progressive rule: a control or system is only shown after the story introduces it (`reveal`).
## Since the shared Pad (scripts/common/pad/, docs/claude/pad.md): when the app has it, the game
## gives the HUD a PadController (`use_pad`) that draws and reads the d-pad / A / B / Pause / Menu, so
## the player's layout, look, size and opacity apply. The code below for those controls stays as the
## fallback for apps without the Pad (older apps keep working). Bars, Missions, captions, close-up
## and fades are always this HUD's.
## Touch: every finger is tracked by index; phones also send emulated mouse events for each touch,
## so once a real touch is seen mouse events are ignored (they would count every tap twice).
## The keyboard is read by the world (turned_world.gd); touch presses the same tn_* actions.
## Also here: inner-text captions and spoken lines, the "Something new is awake." banner, the
## fade to black, the screen throb, the sun-burn glow, the neck close-up and the Menu stub
## (Journal, Quest log). The world sets `fade`, `throb`, `burn` every frame.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const Art = preload("res://scripts/games/turned/turned_art.gd")
const Text = preload("res://scripts/games/turned/turned_text.gd")
const EngineScript = preload("res://scripts/games/turned/turned_engine.gd")

signal a_pressed
signal b_pressed
signal pause_pressed
signal menu_toggled(open: bool)

const TOUCH_ACTIONS := {"left": "tn_left", "right": "tn_right", "up": "tn_up", "down": "tn_down"}
const BAR_RED := Color("d24b4b")
const BAR_BLUE := Color("4a82e0")
const BAR_YELLOW := Color("e3c24a")
const PLATE := Color(0.04, 0.05, 0.09, 0.62)
const TEXT_LIGHT := Color("e8ecf6")
const TEXT_INNER := Color("c9d4f2")

## The game state the bars show (a turned_engine.gd instance); set by the world.
var engine: EngineScript = null
## What A does now (English key into Text.VERBS, "" = nothing to do) and whether it works.
var a_label := ""
var a_active := true
## Screen effects, set by the world every frame.
var fade := 0.0          # 0 clear ... 1 black
var throb := 0.0         # 0..1 dark-red heartbeat vignette
var clock_text := ""   # the game time (the world sets it each frame)
var clock_sun := 1.0    # sun strength 0..1
var clock_moon := 0.0   # moon height 0..1
var burn := 0.0          # 0..1 white-hot sun vignette
var closeup := 0.0       # 0..1 neck close-up
var menu_open := false

var _rv := {"dpad": 0.0, "a": 0.0, "b": 0.0, "bars": 0.0, "mission": 0.0, "menu": 0.0, "pause": 1.0}
var _rv_target := {"dpad": false, "a": false, "b": false, "bars": false, "mission": false, "menu": false, "pause": true}
var _pulse := {}         # name -> 0..1 glow ring after a reveal

var _pointers := {}      # finger index -> role
var _dpad_dirs := {}     # finger index -> Vector2 (that finger's direction)
var _touch_seen := false
var _down := {"a": false, "b": false, "pause": false, "menu": false}

## The shared on-screen controller, or null (then this HUD draws and reads its own controls).
var pad: Control = null
const PAD_PARTS := {"dpad": "move", "a": "a", "b": "b", "menu": "info"}   # HUD name -> Pad part id

var _hp_disp := 0.0
var _blood_disp := 0.0
var _xp_disp := 0.0

var _cap_text := ""
var _cap_kind := "inner"
var _cap_speaker := ""
var _cap_t := 0.0
var _cap_total := 0.0
var _banner_text := ""
var _banner_t := 0.0
var _vignette: GradientTexture2D = null
var _clock := 0.0

var _menu_panel: PanelContainer = null
var _menu_body: VBoxContainer = null
var _menu_tab := "journal"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Frozen while the kit's pause menu is up; the world releases held keys then.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 0.5)
	_vignette.width = 256
	_vignette.height = 256
	resized.connect(queue_redraw)

func _exit_tree() -> void:
	release_inputs()

# ---------------------------------------------------------------- the shared Pad

## Hands the controls to the shared Pad (a PadController already in the tree, under this HUD).
func use_pad(p: Control) -> void:
	pad = p
	pad.set_map({
		"move": ["tn_left", "tn_right", "tn_up", "tn_down"],
		"a": ["tn_a"], "b": ["tn_b"], "pause": ["tn_pause"], "info": ["tn_menu"],
	})
	pad.set_state("info", {"icon": "menu"})
	for part in ["x", "y", "aim"]:
		pad.set_hidden(part, true)           # Turned has no X, Y or aim stick (yet)
	for name in PAD_PARTS:
		pad.set_hidden(PAD_PARTS[name], not _rv_target.get(name, false))
	pad.button_pressed.connect(_on_pad_button)

func _on_pad_button(id: String) -> void:
	match id:
		"a":
			a_pressed.emit()
		"b":
			b_pressed.emit()
		"pause":
			pause_pressed.emit()
		"info":
			open_menu("journal")

# ---------------------------------------------------------------- reveal / captions API

## Shows a control for the first time (popping in); name: dpad, a, b, bars, mission, menu.
func reveal(name: String, animate: bool = true) -> void:
	if _rv_target.get(name, false):
		return
	_rv_target[name] = true
	if pad != null and PAD_PARTS.has(name):
		pad.reveal(PAD_PARTS[name], animate)
	if not animate:
		_rv[name] = 1.0
	elif pad == null or not PAD_PARTS.has(name):
		_pulse[name] = 1.0

## Instant state for Resume (no animation).
func set_revealed(name: String, on: bool) -> void:
	_rv_target[name] = on
	_rv[name] = 1.0 if on else 0.0
	if pad != null and PAD_PARTS.has(name):
		pad.set_hidden(PAD_PARTS[name], not on)

func is_revealed(name: String) -> bool:
	return bool(_rv_target.get(name, false))

## Inner text (thoughts) or a spoken line; returns how long it stays on screen.
func say(text: String, kind: String = "inner", speaker: String = "", seconds: float = -1.0) -> float:
	_cap_text = tr(text)
	_cap_kind = kind
	_cap_speaker = tr(speaker) if speaker != "" else ""
	if seconds < 0.0:
		seconds = maxf(T.f("text.min_seconds"), _cap_text.length() * T.f("text.seconds_per_char"))
	_cap_t = seconds
	_cap_total = seconds
	queue_redraw()
	return seconds

func clear_caption() -> void:
	_cap_t = 0.0
	queue_redraw()

func caption_busy() -> bool:
	return _cap_t > 0.0

func caption_text() -> String:
	return _cap_text if _cap_t > 0.0 else ""

func banner(text: String) -> void:
	_banner_text = tr(text)
	_banner_t = T.f("ui.banner_s")

func banner_active() -> bool:
	return _banner_t > 0.0

# ---------------------------------------------------------------- layout

## Landscape (about 1280 units wide) uses the tuned sizes as they are; a narrow screen (the player
## rotated to portrait) shrinks the d-pad, buttons and bars, never below 0.6 (still about 48 dp there).
func _k() -> float:
	return clampf(size.x / 900.0, 0.6, 1.0)

func _ui(key: String) -> float:
	return T.f("ui." + key) * _k()

func _margin() -> float:
	return 20.0 * _k()

func _dpad_center() -> Vector2:
	var r := _ui("dpad_radius")
	return Vector2(_margin() + r + 14.0, size.y - _margin() - r - 8.0)

func _face_center() -> Vector2:
	var off := _ui("button_offset")
	var r := _ui("button_radius")
	return Vector2(size.x - _margin() - off - r - 8.0, size.y - _margin() - off - r - 14.0)

func _button_center(b: String) -> Vector2:
	var off := _ui("button_offset")
	var c := _face_center()
	match b:
		"a": return c + Vector2(0, off)
		"b": return c + Vector2(off, 0)
		"x": return c + Vector2(-off, 0)
		"y": return c + Vector2(0, -off)
	return c

func _small_size() -> Vector2:
	var a := T.arr("ui.small_button")
	return Vector2(float(a[0]), float(a[1])) * _k()

func _pause_rect() -> Rect2:
	var s := _small_size()
	return Rect2(Vector2(size.x * 0.5 - s.x - 8.0, size.y - s.y - _margin() * 0.7), s)

func _menu_rect() -> Rect2:
	var s := _small_size()
	return Rect2(Vector2(size.x * 0.5 + 8.0, size.y - s.y - _margin() * 0.7), s)

func _mission_rect() -> Rect2:
	var w := clampf(size.x * 0.34, 170.0, 310.0)
	return Rect2(Vector2(size.x - w - 16.0, 14.0), Vector2(w, 66.0))

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or menu_open:
		return
	if event is InputEventScreenTouch:
		_touch_seen = true
		_on_press(event.index, event.position - global_position, event.pressed)
	elif event is InputEventScreenDrag:
		_touch_seen = true
		_on_move(event.index, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not _touch_seen:
		_on_press(-1, event.position - global_position, event.pressed)
	elif event is InputEventMouseMotion and not _touch_seen and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_on_move(-1, event.position - global_position)

func _role_at(p: Vector2) -> String:
	if closeup > 0.4:
		return "a"                  # any tap dismisses the close-up
	if pad != null:
		if _rv["mission"] > 0.5 and _mission_rect().has_point(p):
			return "mission"
		return ""
	if _rv["dpad"] > 0.5 and p.distance_to(_dpad_center()) <= _ui("dpad_radius") * 1.25:
		return "dpad"
	var br := _ui("button_radius") * 1.2
	if _rv["a"] > 0.5 and p.distance_to(_button_center("a")) <= br:
		return "a"
	if _rv["b"] > 0.5 and p.distance_to(_button_center("b")) <= br:
		return "b"
	if _pause_rect().grow(8.0).has_point(p):
		return "pause"
	if _rv["menu"] > 0.5 and _menu_rect().grow(8.0).has_point(p):
		return "menu"
	if _rv["mission"] > 0.5 and _mission_rect().has_point(p):
		return "mission"
	return ""

func _on_press(id: int, p: Vector2, pressed: bool) -> void:
	if pressed:
		if _pointers.has(id):
			return
		var role := _role_at(p)
		if role == "":
			return
		_pointers[id] = role
		match role:
			"dpad":
				_set_dpad(id, p)
			"a":
				_down["a"] = true
				a_pressed.emit()
			"b":
				_down["b"] = true
				b_pressed.emit()
			"pause":
				_down["pause"] = true
				pause_pressed.emit()
			"menu":
				_down["menu"] = true
				open_menu("journal")
			"mission":
				open_menu("quest")
	else:
		if not _pointers.has(id):
			return
		var role: String = _pointers[id]
		if role == "dpad":
			_dpad_dirs.erase(id)
			_apply_dpad()
		elif _down.has(role):
			_down[role] = false
		_pointers.erase(id)
	queue_redraw()

func _on_move(id: int, p: Vector2) -> void:
	if _pointers.get(id, "") == "dpad":
		_set_dpad(id, p)
		queue_redraw()

## 8-way: a thumb on an axis presses one arrow, in a corner two (the axis must win 2:1).
func _set_dpad(id: int, p: Vector2) -> void:
	var d := p - _dpad_center()
	var dir := Vector2.ZERO
	if d.length() >= _ui("dpad_deadzone"):
		var ax := absf(d.x)
		var ay := absf(d.y)
		if ax > ay * 2.0:
			dir = Vector2(signf(d.x), 0)
		elif ay > ax * 2.0:
			dir = Vector2(0, signf(d.y))
		else:
			dir = Vector2(signf(d.x), signf(d.y))
	_dpad_dirs[id] = dir
	_apply_dpad()

func _apply_dpad() -> void:
	var sum := Vector2.ZERO
	for id in _dpad_dirs:
		var v: Vector2 = _dpad_dirs[id]
		sum += v
	sum = Vector2(clampf(sum.x, -1, 1), clampf(sum.y, -1, 1))
	_set_action(TOUCH_ACTIONS.left, sum.x < 0.0)
	_set_action(TOUCH_ACTIONS.right, sum.x > 0.0)
	_set_action(TOUCH_ACTIONS.up, sum.y < 0.0)
	_set_action(TOUCH_ACTIONS.down, sum.y > 0.0)

func _set_action(action: String, down: bool) -> void:
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)

func release_inputs() -> void:
	if pad != null and is_instance_valid(pad):
		pad.release_all()
	_pointers.clear()
	_dpad_dirs.clear()
	for a in TOUCH_ACTIONS.values():
		Input.action_release(a)
	for k in _down:
		_down[k] = false

## The d-pad direction currently pressed on the touch overlay (for lit arrows).
func _lit_dir() -> Vector2:
	var sum := Vector2.ZERO
	for id in _dpad_dirs:
		sum += _dpad_dirs[id] as Vector2
	return Vector2(clampf(sum.x, -1, 1), clampf(sum.y, -1, 1))

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_clock += delta
	var step := delta / maxf(T.f("ui.reveal_s"), 0.05)
	for k in _rv:
		var to := 1.0 if _rv_target[k] else 0.0
		_rv[k] = move_toward(_rv[k], to, step)
	for k in _pulse.keys():
		_pulse[k] = maxf(0.0, float(_pulse[k]) - delta / 1.1)
		if _pulse[k] <= 0.0:
			_pulse.erase(k)
	if _cap_t > 0.0:
		_cap_t -= delta
	if _banner_t > 0.0:
		_banner_t -= delta
	if pad != null:
		var sub := tr(Text.VERBS.get(a_label, a_label)) if a_label != "" else ""
		pad.set_state("a", {"sub": sub, "enabled": a_active and a_label != ""})
		pad.set_state("b", {"ring": engine != null and engine.sneaking})
		pad.visible = closeup <= 0.4 and not menu_open
	if engine != null:
		_hp_disp = move_toward(_hp_disp, engine.hp, maxf(20.0 * delta, absf(engine.hp - _hp_disp) * 8.0 * delta))
		_blood_disp = move_toward(_blood_disp, engine.blood, 40.0 * delta)
		_xp_disp = move_toward(_xp_disp, fmod(engine.xp, T.f("stats.xp_per_level")), 40.0 * delta)
	queue_redraw()

# ---------------------------------------------------------------- drawing

func _font() -> Font:
	return ThemeDB.fallback_font

func _text(pos: Vector2, s: String, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: bool = true) -> void:
	if outline:
		draw_string_outline(_font(), pos, s, align, width, fs, 4, Color(0, 0, 0, col.a * 0.65))
	draw_string(_font(), pos, s, align, width, fs, col)

func _pop(k: float) -> float:
	# 0..1 -> scale with a little overshoot
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var t := clampf(k, 0.0, 1.0) - 1.0
	return clampf(1.0 + c3 * pow(t, 3.0) + c1 * pow(t, 2.0), 0.0, 1.3)

func _draw() -> void:
	if size.x < 10.0:
		return
	if _rv["bars"] > 0.01:
		_draw_bars()
	if _rv["mission"] > 0.01:
		_draw_mission()
	if pad == null:
		if _rv["dpad"] > 0.01:
			_draw_dpad()
		_draw_faces()
		_draw_small_buttons()
	if burn > 0.01:
		draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(1.0, 0.93, 0.78, minf(1.0, burn * 0.8)))
	if throb > 0.01:
		draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(0.35, 0.02, 0.06, minf(1.0, throb * 0.95)))
	if closeup > 0.01:
		_draw_closeup()
	if fade > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))
	_draw_caption()
	_draw_banner()

func _bar(pos: Vector2, w: float, h: float, frac: float, col: Color, label: String, value: String) -> void:
	var r := Rect2(pos, Vector2(w, h))
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h)), col)
	draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h * 0.4)), Color(1, 1, 1, 0.16))
	draw_rect(r, Color(1, 1, 1, 0.5), false, 1.5)
	_text(pos + Vector2(6, h - 3), label, int(h * 0.82), TEXT_LIGHT)
	if value != "":
		_text(pos + Vector2(0, h - 3), value, int(h * 0.82), TEXT_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT, w - 6.0)

func _draw_bars() -> void:
	var k: float = _rv["bars"]
	var w := _ui("bar_width")
	var p := Vector2(16, 14)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(p - Vector2(8, 8), Vector2(w + 62, 94 + 30)), Color(PLATE.r, PLATE.g, PLATE.b, PLATE.a * k))
	var mh := 18.0
	var hp_max := engine.max_hp if engine else 1.0
	var bl_max := engine.max_blood if engine else 1.0
	var lvl := engine.level if engine else 1
	var xp_max := T.f("stats.xp_per_level")
	_bar(p, w, mh, _hp_disp / hp_max, Color(BAR_RED.r, BAR_RED.g, BAR_RED.b, k), tr(Text.UI["health"]), "%d" % int(ceilf(_hp_disp)))
	_bar(p + Vector2(0, mh + 6), w, mh, _blood_disp / bl_max, Color(BAR_BLUE.r, BAR_BLUE.g, BAR_BLUE.b, k), tr(Text.UI["blood"]), "%d" % int(_blood_disp))
	_bar(p + Vector2(0, 2 * (mh + 6)), w, mh - 4, _xp_disp / xp_max, Color(BAR_YELLOW.r, BAR_YELLOW.g, BAR_YELLOW.b, k), tr(Text.UI["xp"]), tr(Text.UI["level"]) % lvl)
	_draw_sun_icon(Vector2(p.x + w + 28, p.y + 40), k)
	_draw_time(Vector2(p.x + 6, p.y + 98), k)

## The time of day: a sun or a crescent moon (never colour alone) and the game clock.
func _draw_time(c: Vector2, k: float) -> void:
	var col := Color(1.0, 0.82, 0.35, k) if clock_sun >= clock_moon else Color(0.78, 0.84, 1.0, k)
	if clock_sun >= clock_moon:
		draw_circle(c + Vector2(9, 0), 7.0, col)
		for i in 8:
			var a := TAU * float(i) / 8.0
			draw_line(c + Vector2(9, 0) + Vector2(cos(a), sin(a)) * 10.0, c + Vector2(9, 0) + Vector2(cos(a), sin(a)) * 13.0, col, 2.0)
	else:
		draw_arc(c + Vector2(11, 0), 6.0, deg_to_rad(105.0), deg_to_rad(255.0), 16, col, 5.0)   # a crescent opening to the right
	_text(c + Vector2(28, 8), clock_text, 20, Color(TEXT_LIGHT.r, TEXT_LIGHT.g, TEXT_LIGHT.b, k))

## The sun-tolerance icon: rays go out as the day's sun gets worse; never colour alone.
func _draw_sun_icon(c: Vector2, k: float) -> void:
	var eff := engine.effective_level() if engine else 0
	var rays := clampi(8 - 2 * eff, 0, 8)
	var col := Color(1.0, 0.82, 0.35, k)
	draw_circle(c, 9.0, col)
	draw_arc(c, 9.0, 0.0, TAU, 20, Color(0, 0, 0, 0.5 * k), 1.5)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var tip := c + Vector2(cos(ang), sin(ang)) * 17.0
		var base := c + Vector2(cos(ang), sin(ang)) * 12.0
		if i < rays:
			draw_line(base, tip, col, 2.5)
		else:
			draw_line(base, base.lerp(tip, 0.3), Color(0.5, 0.45, 0.4, 0.6 * k), 1.5)

func _draw_mission() -> void:
	var k: float = _rv["mission"]
	var r := _mission_rect()
	draw_rect(r, Color(PLATE.r, PLATE.g, PLATE.b, PLATE.a * k))
	draw_rect(r, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.7 * k), false, 1.5)
	_text(r.position + Vector2(10, 20), tr(Text.UI["missions"]).to_upper(), 14, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, k))
	var line := ""
	if engine != null and engine.mission != "":
		line = tr(Text.MISSIONS.get(engine.mission, engine.mission))
	else:
		line = tr(Text.UI["no_mission"])
	var fs := 19
	var f := _font()
	while fs > 12 and f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 20.0:
		fs -= 1
	_text(r.position + Vector2(10, 49), line, fs, Color(TEXT_LIGHT.r, TEXT_LIGHT.g, TEXT_LIGHT.b, k))

func _arrow(c: Vector2, dir: Vector2, lit: bool, k: float) -> void:
	var R := _ui("dpad_radius")
	var side := Vector2(-dir.y, dir.x)
	var tip := c + dir * R * 0.98
	var base := c + dir * R * 0.38
	var pts := PackedVector2Array([tip, base + side * R * 0.36, base - side * R * 0.36])
	draw_colored_polygon(pts, Color(1, 1, 1, (0.5 if lit else 0.17) * k))
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, Color(1, 1, 1, 0.62 * k), 2.5)

func _draw_dpad() -> void:
	var k: float = _rv["dpad"]
	var c := _dpad_center()
	var s := _pop(k)
	var d := _lit_dir()
	if d == Vector2.ZERO:
		d = _key_dir()
	draw_set_transform(c - c * s, 0.0, Vector2(s, s))
	draw_circle(c, _ui("dpad_radius") * 0.3, Color(1, 1, 1, 0.08 * k))
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var lit: bool = (dir.x != 0.0 and signf(d.x) == dir.x) or (dir.y != 0.0 and signf(d.y) == dir.y)
		_arrow(c, dir, lit, k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pulse_ring("dpad", c, _ui("dpad_radius"))

func _key_dir() -> Vector2:
	return Vector2(Input.get_axis("tn_left", "tn_right"), Input.get_axis("tn_up", "tn_down"))

func _pulse_ring(name: String, c: Vector2, r: float) -> void:
	if not _pulse.has(name):
		return
	var p: float = _pulse[name]
	draw_arc(c, r * (1.0 + (1.0 - p) * 0.7), 0.0, TAU, 48, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, p * 0.9), 4.0)

func _round_button(b: String, glyph: String, sub: String, lit: bool, active: bool) -> void:
	var k: float = _rv[b]
	if k <= 0.01:
		return
	var c := _button_center(b)
	var r := _ui("button_radius")
	var s := _pop(k)
	draw_set_transform(c - c * s, 0.0, Vector2(s, s))
	draw_circle(c, r, Color(PLATE.r, PLATE.g, PLATE.b, 0.5 * k) if not lit else Color(1, 1, 1, 0.4 * k))
	draw_circle(c, r, Color(1, 1, 1, 0.12 * k))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.68 * k), 3.0)
	var col := Color(1, 1, 1, (0.96 if active else 0.42) * k)
	if sub == "":
		_text(c + Vector2(-r, 11), glyph, 32, col, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	else:
		_text(c + Vector2(-r, -2), glyph, 30, col, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
		var fs := 16
		var sub_w := _font().get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while sub_w > r * 1.75 and fs > 10:
			fs -= 1
			sub_w = _font().get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(c + Vector2(-r, 22), sub, fs, Color(1, 1, 1, (0.9 if active else 0.4) * k), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pulse_ring(b, c, r)

func _draw_faces() -> void:
	var sub := tr(Text.VERBS.get(a_label, a_label)) if a_label != "" else ""
	_round_button("a", "A", sub, _down["a"] or Input.is_action_pressed("tn_a"), a_active and a_label != "")
	var sneaking := engine != null and engine.sneaking
	_round_button("b", "B", "", _down["b"] or sneaking, true)
	if _rv["b"] > 0.5 and sneaking:
		draw_arc(_button_center("b"), _ui("button_radius") + 6.0, 0.0, TAU, 40, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.9), 3.0)

func _small_button(rect: Rect2, label: String, icon: String, down: bool, k: float) -> void:
	draw_rect(rect, Color(1, 1, 1, (0.4 if down else 0.15) * k))
	draw_rect(rect, Color(PLATE.r, PLATE.g, PLATE.b, 0.5 * k))
	draw_rect(rect, Color(1, 1, 1, 0.6 * k), false, 2.0)
	var c := rect.get_center()
	var col := Color(1, 1, 1, 0.88 * k)
	if icon == "pause":
		draw_rect(Rect2(c + Vector2(-26, -10), Vector2(7, 20)), col)
		draw_rect(Rect2(c + Vector2(-15, -10), Vector2(7, 20)), col)
	else:
		for i in 3:
			draw_rect(Rect2(c + Vector2(-27, -10 + i * 8), Vector2(20, 4)), col)
	var fs := 16
	var avail := rect.size.x * 0.5 + 14.0
	while fs > 9 and _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	_text(c + Vector2(-2, 6), label, fs, col)

func _draw_small_buttons() -> void:
	_small_button(_pause_rect(), tr(Text.UI["pause"]), "pause", _down["pause"] or Input.is_action_pressed("tn_pause"), 1.0)
	if _rv["menu"] > 0.01:
		_small_button(_menu_rect(), tr(Text.UI["menu"]), "menu", _down["menu"], _rv["menu"])
		_pulse_ring("menu", _menu_rect().get_center(), 40.0)

func _draw_caption() -> void:
	if _cap_t <= 0.0 or _cap_text == "":
		return
	var fade_s := T.f("text.fade_s")
	var a := clampf(minf(_cap_total - _cap_t, _cap_t) / fade_s, 0.0, 1.0)
	var w := clampf(size.x - 640.0, 340.0, 760.0)
	var fs := 22
	var inner := _cap_kind == "inner"
	var col := Color(TEXT_INNER.r, TEXT_INNER.g, TEXT_INNER.b, a) if inner else Color(1, 1, 1, a)
	var sz := _font().get_multiline_string_size(_cap_text, HORIZONTAL_ALIGNMENT_CENTER, w - 40.0, fs)
	var head := 24.0 if _cap_speaker != "" else 0.0
	var h := sz.y + 26.0 + head
	var r := Rect2(Vector2((size.x - w) * 0.5, size.y - _small_size().y - 40.0 - h), Vector2(w, h))
	draw_rect(r, Color(0.03, 0.04, 0.08, 0.78 * a))
	var edge: Color = Color("6f86c8") if inner else Art.AMBER
	draw_rect(r, Color(edge.r, edge.g, edge.b, 0.65 * a), false, 1.5)
	var y := r.position.y + 12.0
	if _cap_speaker != "":
		_text(Vector2(r.position.x + 20, y + 14), _cap_speaker, 15, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, a), HORIZONTAL_ALIGNMENT_LEFT, w - 40.0)
		y += head
	draw_multiline_string(_font(), Vector2(r.position.x + 20, y + fs), _cap_text, HORIZONTAL_ALIGNMENT_CENTER, w - 40.0, fs, -1, col)

func _draw_banner() -> void:
	if _banner_t <= 0.0:
		return
	var total := T.f("ui.banner_s")
	var a := clampf(minf(total - _banner_t, _banner_t) / 0.6, 0.0, 1.0)
	var y := size.y * 0.27
	var fs := 34
	var w := _font().get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > size.x - 80.0:
		fs = 24
	var plate := Rect2(Vector2(size.x * 0.5 - w * 0.5 - 28.0, y - 40.0), Vector2(w + 56.0, 64.0))
	draw_rect(plate, Color(0.03, 0.03, 0.06, 0.7 * a))
	draw_line(plate.position + Vector2(0, 0), plate.position + Vector2(plate.size.x, 0), Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.8 * a), 2.0)
	draw_line(plate.position + Vector2(0, plate.size.y), plate.end, Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.8 * a), 2.0)
	_text(Vector2(0, y), _banner_text, fs, Color(1.0, 0.86, 0.55, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)

# ---------------------------------------------------------------- the neck close-up

func _draw_closeup() -> void:
	var k := closeup
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.05, 0.93 * k))
	var u := minf(size.x, size.y * 1.4) / 1000.0
	var c := Vector2(size.x * 0.5, size.y * 0.5 - 10.0 * u)
	# a cold wash behind the neck
	for i in 5:
		draw_circle(c, (520.0 - i * 70.0) * u, Color(0.16, 0.2, 0.34, 0.1 * k))
	var skin := Color(0.80, 0.76, 0.80, k)
	var shade := Color(0.62, 0.58, 0.66, k)
	# neck column (a wide soft shape), jaw above, collar below
	var neck := PackedVector2Array([
		c + Vector2(-120, -330) * u, c + Vector2(120, -330) * u, c + Vector2(132, -80) * u,
		c + Vector2(260, 190) * u, c + Vector2(-260, 190) * u, c + Vector2(-132, -80) * u])
	draw_colored_polygon(neck, skin)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-120, -330) * u, c + Vector2(-30, -330) * u, c + Vector2(-40, -60) * u, c + Vector2(-132, -80) * u]), shade)
	draw_colored_polygon(Art.ellipse_points(c + Vector2(0, -330) * u, 170.0 * u, 70.0 * u), Color(0.74, 0.7, 0.75, k))
	# collarbones and shirt collar
	draw_line(c + Vector2(-230, 150) * u, c + Vector2(-40, 100) * u, shade, 6.0 * u)
	draw_line(c + Vector2(230, 150) * u, c + Vector2(40, 100) * u, shade, 6.0 * u)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-300, 250) * u, c + Vector2(-150, 120) * u, c + Vector2(-60, 200) * u, c + Vector2(-120, 300) * u]), Color(0.18, 0.2, 0.3, k))
	draw_colored_polygon(PackedVector2Array([c + Vector2(300, 250) * u, c + Vector2(150, 120) * u, c + Vector2(60, 200) * u, c + Vector2(120, 300) * u]), Color(0.18, 0.2, 0.3, k))
	# the two marks, side by side, with a slow pulse
	var pulse := 0.5 + 0.5 * sin(_clock * 4.5)
	var m := c + Vector2(72, -110) * u
	draw_circle(m + Vector2(-17, -4) * u, 30.0 * u, Color(0.55, 0.2, 0.32, 0.22 * k))
	draw_circle(m + Vector2(17, 4) * u, 30.0 * u, Color(0.55, 0.2, 0.32, 0.22 * k))
	draw_circle(m + Vector2(-17, -4) * u, (22.0 + pulse * 3.0) * u, Color(0.65, 0.2, 0.3, 0.3 * k))
	draw_circle(m + Vector2(17, 4) * u, (22.0 + pulse * 3.0) * u, Color(0.65, 0.2, 0.3, 0.3 * k))
	draw_circle(m + Vector2(-17, -4) * u, 8.0 * u, Color(0.28, 0.03, 0.07, k))
	draw_circle(m + Vector2(17, 4) * u, 8.0 * u, Color(0.28, 0.03, 0.07, k))
	draw_line(m + Vector2(-17, 4) * u, m + Vector2(-20, 46) * u, Color(0.5, 0.06, 0.12, 0.7 * k), 3.0 * u)
	draw_line(m + Vector2(17, 12) * u, m + Vector2(19, 40) * u, Color(0.5, 0.06, 0.12, 0.6 * k), 2.5 * u)
	if k > 0.9 and _cap_t <= 0.0:
		_text(Vector2(0, size.y - 36.0), tr(Text.UI["tap_a"]), 20, Color(1, 1, 1, 0.55 + 0.35 * sin(_clock * 3.0)), HORIZONTAL_ALIGNMENT_CENTER, size.x)

# ---------------------------------------------------------------- the Menu stub (Journal, Quest log)

func open_menu(tab: String) -> void:
	_menu_tab = tab
	if _menu_panel == null:
		_build_menu()
	menu_open = true
	release_inputs()
	_menu_panel.visible = true
	_fill_menu()
	menu_toggled.emit(true)

func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	if _menu_panel != null:
		_menu_panel.visible = false
	menu_toggled.emit(false)

func toggle_menu() -> void:
	if menu_open:
		close_menu()
	elif _rv_target["menu"]:
		open_menu("journal")

func _build_menu() -> void:
	_menu_panel = PanelContainer.new()
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.1, 0.96)
	sb.border_color = Color(Art.AMBER.r, Art.AMBER.g, Art.AMBER.b, 0.7)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	_menu_panel.add_theme_stylebox_override("panel", sb)
	add_child(_menu_panel)
	_menu_body = VBoxContainer.new()
	_menu_body.add_theme_constant_override("separation", 10)
	_menu_panel.add_child(_menu_body)

func _fill_menu() -> void:
	for ch in _menu_body.get_children():
		_menu_body.remove_child(ch)
		ch.queue_free()
	var w := clampf(size.x - 120.0, 320.0, 760.0)
	var h := clampf(size.y - 120.0, 260.0, 520.0)
	_menu_panel.custom_minimum_size = Vector2(w, h)
	_menu_panel.size = Vector2(w, h)
	_menu_panel.position = (size - Vector2(w, h)) * 0.5
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	_menu_body.add_child(tabs)
	for t in [["journal", Text.UI["journal"]], ["quest", Text.UI["quest_log"]]]:
		var b := Button.new()
		b.text = tr(t[1])
		b.toggle_mode = true
		b.button_pressed = _menu_tab == t[0]
		b.custom_minimum_size = Vector2(150, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_tab.bind(t[0]))
		tabs.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var close := Button.new()
	close.text = tr(Text.UI["close"])
	close.custom_minimum_size = Vector2(120, 56)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_menu)
	tabs.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var lines: Array = []
	if _menu_tab == "journal":
		if engine != null:
			for id in engine.journal:
				lines.append(tr(_journal_text(str(id))))
		if lines.is_empty():
			lines.append(tr(Text.UI["journal_empty"]))
	else:
		if engine != null and engine.mission != "":
			lines.append(tr(Text.MISSIONS.get(engine.mission, engine.mission)))
		else:
			lines.append(tr(Text.UI["no_mission"]))
	for s in lines:
		var l := Label.new()
		l.text = s
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", TEXT_LIGHT)
		list.add_child(l)

func _on_tab(tab: String) -> void:
	_menu_tab = tab
	_fill_menu()

## Journal text for an id: a clue object or a story line.
static func _journal_text(id: String) -> String:
	if Text.CLUES.has(id):
		return Text.CLUES[id]["journal"]
	return Text.JOURNAL.get(id, id)
