extends Control

## The shared on-screen controller (Pad). Add one to a landscape game's scene and it draws the
## player's chosen layout and look (`PadPrefs`, saved once for all games) and turns touches into
## Godot actions, the same actions a keyboard would press:
##   sticks   pad_move_left/right/up/down (+ pad_aim_* for a second stick), pressed with their
##            real strength, so `Input.get_vector("pad_move_left", ...)` is analog
##   buttons  pad_a pad_b pad_x pad_y, pad_pause pad_info; a stick marked `fires` also holds pad_fire
##   a game with its own action names calls `set_map({"a": ["tn_a"], "move": ["tn_left", ...]})`
## Keyboard defaults for every pad_* action are registered in code (`ensure_actions`), so a game
## built on the pad also plays on a PC. Layouts are data (pad_layouts.gd), the look is pad_draw.gd.
##
## Opacity 0 hides the controller completely; the buttons still work and a touched part lights up
## faintly. The Options panel (pad_options.gd) changes everything below at runtime.
## A game reveals parts as its story or levels unlock them (`reveal("a")` pops the button in with a
## pulse ring; `set_hidden` is the instant version), puts a word under a button (`set_state("a",
## {"sub": "USE", "enabled": true, "ring": false, "icon": ""})`) and picks a layout the player has
## not chosen yet (`default_layout`). The pad pauses with the game (the kit's pause menu is never
## pressed through); `works_while_paused = true` opts out.
## Every finger is tracked by its own index (stick + buttons at once). Phones send emulated mouse
## events for each touch, so once a real touch is seen the mouse is ignored.
##
## Packs must work on older apps: load this with load(), guard with ResourceLoader.exists().

signal button_pressed(id: String)
signal button_released(id: String)
signal layout_changed

const Layouts = preload("res://scripts/common/pad/pad_layouts.gd")
const Draw = preload("res://scripts/common/pad/pad_draw.gd")
const Prefs = preload("res://scripts/common/pad/pad_prefs.gd")

const FIRE_AT := 0.35         # an aim stick fires beyond this deflection
const TOUCH_ALPHA := 0.6      # a touched part never draws fainter than this
const MAP_COLOR := Color(1.0, 0.85, 0.2, 0.95)
const REVEAL_S := 0.35
const PULSE_S := 1.1

const KEYS := {
	"pad_move_left": [KEY_A], "pad_move_right": [KEY_D], "pad_move_up": [KEY_W], "pad_move_down": [KEY_S],
	"pad_aim_left": [KEY_LEFT], "pad_aim_right": [KEY_RIGHT], "pad_aim_up": [KEY_UP], "pad_aim_down": [KEY_DOWN],
	"pad_a": [KEY_K], "pad_b": [KEY_L], "pad_x": [KEY_J], "pad_y": [KEY_I],
	"pad_fire": [KEY_SPACE], "pad_pause": [KEY_ESCAPE], "pad_info": [KEY_TAB],
}

var prefs: Dictionary = {}
## A game that needs one particular layout sets this (the player's skin / size still apply).
var layout_override := ""
## Draw-only mode for the layout cards in the Options panel: no input, no saving.
var preview := false
## A layout of this game's own (see Layouts.variant), used instead of the catalogue. No Options.
var custom_layout: Dictionary = {}
## Prefs this game fixes whatever the player saved, e.g. {"floating": true} for a twin-stick shooter
## ("wide_zone": true lets a single floating stick start anywhere in the lower part of the screen).
var prefs_override: Dictionary = {}
## Used until the player has picked a layout of their own in Options.
var default_layout := ""
## The layouts this game can work with (a game that needs A, B and a menu button can't use the
## one-button layout). Empty = all. Options only offers these, and a saved layout outside it is ignored.
var allowed_layouts: Array = []
## By default the pad stops with the game's pause (the kit's pause menu is drawn over the game).
var works_while_paused := false

var _placed: Array = []
var _layout: Dictionary = {}
var _pointers := {}            # finger index -> part id
var _touch_seen := false
var _down := {}                # button id -> bool
var _vec := {}                 # stick / dpad id -> Vector2 (0..1 length)
var _knob := {}                # stick id -> knob offset in pixels
var _origin := {}              # stick id -> centre while held (floating sticks move it)
var _dpad_cur := {}            # dpad id -> last 4-way direction (hysteresis)
var _map := {}                 # part id -> Array of extra action names
var _hidden := {}              # part id -> true (hidden or still popping in)
var _props := {}               # part id -> {"label", "sub", "enabled", "ring", "icon"}
var _rv := {}                  # part id -> 0..1 reveal progress (missing = fully shown)
var _pulse := {}               # part id -> 1..0 pulse ring after a reveal
var _clock := 0.0
var _layout_chosen := false    # the player picked a layout (a game's default_layout then no longer applies)

static func ensure_actions() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.0)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------- setup
func _ready() -> void:
	ensure_actions()
	if prefs.is_empty():
		prefs = Prefs.load_prefs()
		_layout_chosen = Prefs.has_saved("layout")
		if default_layout != "" and not _layout_chosen:
			prefs["layout"] = default_layout
	for k in prefs_override:
		prefs[k] = prefs_override[k]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS if works_while_paused else Node.PROCESS_MODE_PAUSABLE
	set_process_input(not preview)
	set_process(false)
	if get_parent() is CanvasLayer:
		_fit_to_viewport()
		get_viewport().size_changed.connect(_fit_to_viewport)
	resized.connect(_replace)
	visibility_changed.connect(_on_visibility)
	_replace()

func _exit_tree() -> void:
	release_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		release_all()   # the game paused: no stick or button stays held under the pause menu

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

func _on_visibility() -> void:
	if not is_visible_in_tree():
		release_all()

## Re-places every part for the current size, prefs and layout.
func _replace() -> void:
	var id: String = layout_override if layout_override != "" else str(prefs.get("layout", "stick_4"))
	if not allowed_layouts.is_empty() and not allowed_layouts.has(id):
		id = default_layout if allowed_layouts.has(default_layout) else str(allowed_layouts[0])
	var old := str(_layout.get("id", ""))
	_layout = custom_layout if not custom_layout.is_empty() else Layouts.get_layout(id)
	if old != "" and old != str(_layout["id"]):
		release_all()
	_placed = Layouts.place(_layout, size, float(prefs["size"]), bool(prefs["right_handed"]), bool(prefs["floating"]), bool(prefs.get("wide_zone", false)))
	_origin.clear()
	queue_redraw()
	layout_changed.emit()

## Applies a full prefs dictionary (the Options panel does this live).
func apply_prefs(p: Dictionary, save: bool = true) -> void:
	var clean := Prefs.clean(p)
	if str(clean["layout"]) != str(prefs.get("layout", "")):
		_layout_chosen = true
	prefs = clean
	for k in prefs_override:
		prefs[k] = prefs_override[k]
	if save and not preview:
		var out := prefs.duplicate()
		if default_layout != "" and not _layout_chosen:
			out.erase("layout")   # keep following the game's default until the player picks one
		Prefs.save_prefs(out)
	release_all()
	_replace()

func set_pref(key: String, value: Variant) -> void:
	var p := prefs.duplicate()
	p[key] = value
	apply_prefs(p)

## Cycles to the next / previous layout (the Lab's ‹ › buttons).
func step_layout(dir: int) -> void:
	set_pref("layout", Layouts.step(str(prefs["layout"]), dir))

func step_skin(dir: int) -> void:
	var all := Draw.skin_ids()
	set_pref("skin", all[posmod(all.find(str(prefs["skin"])) + dir, all.size())])

## `map`: part id -> action name (String) or Array of names. Sticks / D-pads take four names in
## the order left, right, up, down. The pad_* actions are always pressed as well.
func set_map(map: Dictionary) -> void:
	_map.clear()
	for k in map:
		_map[k] = map[k] if map[k] is Array else [map[k]]

## Hide or show one part at once (a layout part the game never uses, like X / Y / the aim stick).
func set_hidden(id: String, hide: bool) -> void:
	_pulse.erase(id)
	if hide:
		_hidden[id] = true
		_rv[id] = 0.0
		if _down.get(id, false):
			_set_button(id, false)
	else:
		_hidden.erase(id)
		_rv.erase(id)
	queue_redraw()

## Shows a hidden part for the first time: it pops in and a ring pulses around it.
func reveal(id: String, animate: bool = true) -> void:
	if not _hidden.has(id) and not _rv.has(id):
		return
	if not animate:
		set_hidden(id, false)
		return
	_hidden.erase(id)
	if not _rv.has(id):
		_rv[id] = 0.0
	_pulse[id] = 1.0
	set_process(true)
	queue_redraw()

## How visible a part is, 0..1 (1 once revealed or never hidden).
func visibility_of(id: String) -> float:
	if _hidden.has(id):
		return 0.0
	return float(_rv.get(id, 1.0))

## Properties of a part: label (replaces the letter), sub (a word under it), enabled (dimmed when
## false, still pressable), ring (an amber ring, e.g. "sneaking"), icon (pills: pause / info / menu),
## fill (0..1: a ring filling clockwise, 1 or -1 = none; power / cooldown), tint (the button's
## colour), glyph (a built-in icon instead of the letter: bomb, flame, jump, bolt), draw (a
## Callable(canvas_item, centre, radius, alpha) that draws the icon yourself).
func set_state(id: String, props: Dictionary) -> void:
	var cur: Dictionary = _props.get(id, {})
	var next := cur.duplicate()
	for k in props:
		next[k] = props[k]
	if next != cur:
		_props[id] = next
		queue_redraw()

## Change a button's letter and whether it is usable (dimmed when not).
func set_button(id: String, label: String = "", enabled: bool = true) -> void:
	set_state(id, {"label": label, "enabled": enabled})

func _process(delta: float) -> void:
	_clock += delta
	var busy := false
	for id in _rv.keys():
		if _hidden.has(id):
			continue
		var v: float = _rv[id]
		if v < 1.0:
			_rv[id] = minf(1.0, v + delta / REVEAL_S)
			busy = true
		else:
			_rv.erase(id)
	for id in _pulse.keys():
		_pulse[id] = float(_pulse[id]) - delta / PULSE_S
		if _pulse[id] <= 0.0:
			_pulse.erase(id)
		else:
			busy = true
	queue_redraw()
	if not busy:
		set_process(false)

# ---------------------------------------------------------------- what the game reads
func get_vector(id: String = "move") -> Vector2:
	return Input.get_vector("pad_%s_left" % id, "pad_%s_right" % id, "pad_%s_up" % id, "pad_%s_down" % id)

func is_down(id: String) -> bool:
	return Input.is_action_pressed("pad_" + id)

func finger_count() -> int:
	return _pointers.size()

func layout_name() -> String:
	return str(_layout.get("name", ""))

func layout_id() -> String:
	return str(_layout.get("id", ""))

## The placed parts (kind, id, pos, r ...), for tests and the Lab's readout.
func parts() -> Array:
	return _placed

func has_part(id: String) -> bool:
	for el in _placed:
		if el["id"] == id and el["kind"] != "plate":
			return true
	return false

## The action names a part presses, own pad_* names first.
func action_names(id: String) -> Array:
	var el := _find(id)
	var out: Array = []
	if el.is_empty():
		return out
	if el["kind"] == "stick" or el["kind"] == "dpad":
		for d in ["left", "right", "up", "down"]:
			out.append("pad_%s_%s" % [id, d])
	else:
		out.append("pad_" + id)
	out.append_array(_map.get(id, []))
	return out

# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var used := false
	if event is InputEventScreenTouch:
		_touch_seen = true
		used = _press(event.index, _local(event.position), event.pressed)
	elif event is InputEventScreenDrag:
		_touch_seen = true
		used = _move(event.index, _local(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not _touch_seen:
		used = _press(-1, _local(event.position), event.pressed)
	elif event is InputEventMouseMotion and not _touch_seen:
		used = _move(-1, _local(event.position))
	if used:
		get_viewport().set_input_as_handled()

func _local(p: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * p

func _press(fid: int, pos: Vector2, pressed: bool) -> bool:
	if pressed:
		if _pointers.has(fid):
			return false
		var el := _hit(pos)
		if el.is_empty():
			return false
		_pointers[fid] = el["id"]
		match el["kind"]:
			"button", "pill":
				_set_button(el["id"], true)
			"stick":
				_origin[el["id"]] = _clamp_origin(el, pos) if el["floating"] else el["pos"]
				_stick_to(el, pos)
			"dpad":
				_dpad_to(el, pos)
		queue_redraw()
		return true
	if not _pointers.has(fid):
		return false
	var id: String = _pointers[fid]
	_pointers.erase(fid)
	var part := _find(id)
	match part.get("kind", ""):
		"button", "pill":
			_set_button(id, false)
		"stick":
			_stick_actions(id, Vector2.ZERO)
			_vec.erase(id)
			_knob.erase(id)
			_origin.erase(id)
			if part.get("fires", false):
				_press_name("pad_fire", 0.0)
		"dpad":
			_stick_actions(id, Vector2.ZERO)
			_vec.erase(id)
			_dpad_cur.erase(id)
	queue_redraw()
	return true

func _move(fid: int, pos: Vector2) -> bool:
	if not _pointers.has(fid):
		return false
	var el := _find(_pointers[fid])
	match el.get("kind", ""):
		"stick":
			_stick_to(el, pos)
		"dpad":
			_dpad_to(el, pos)
		_:
			return true
	queue_redraw()
	return true

## The part under `pos`: small buttons first, then the big stick / D-pad areas.
func _hit(pos: Vector2) -> Dictionary:
	for el in _placed:
		if visibility_of(el["id"]) < 0.5:
			continue
		if el["kind"] == "button" and pos.distance_to(el["pos"]) <= el["r"] * 1.18 and not _down.get(el["id"], false):
			return el
		if el["kind"] == "pill" and Rect2(el["rect"]).grow(10.0).has_point(pos) and not _down.get(el["id"], false):
			return el
	for el in _placed:
		if visibility_of(el["id"]) < 0.5 or _held(el["id"]):
			continue
		if el["kind"] == "dpad" and pos.distance_to(el["pos"]) <= el["r"] * 1.2:
			return el
		if el["kind"] == "stick":
			if el["floating"]:
				if Rect2(el["zone"]).has_point(pos):
					return el
			elif pos.distance_to(el["pos"]) <= el["r"] * 1.4:
				return el
	return {}

func _held(id: String) -> bool:
	return _pointers.values().has(id)

func _find(id: String) -> Dictionary:
	for el in _placed:
		if el["id"] == id:
			return el
	return {}

func _clamp_origin(el: Dictionary, pos: Vector2) -> Vector2:
	var r: float = el["r"]
	return Vector2(clampf(pos.x, r + 8.0, maxf(r + 8.0, size.x - r - 8.0)), clampf(pos.y, r + 8.0, maxf(r + 8.0, size.y - r - 8.0)))

# ---------------------------------------------------------------- sticks, D-pad, buttons
func _stick_to(el: Dictionary, pos: Vector2) -> void:
	var id: String = el["id"]
	var o: Vector2 = _origin.get(id, el["pos"])
	var v: Vector2 = (pos - o).limit_length(el["r"])
	_knob[id] = v
	var n := v / float(el["r"])
	var m := n.length()
	var dz := float(prefs["deadzone"])
	var out := Vector2.ZERO
	if m > dz:
		out = n.normalized() * ((m - dz) / (1.0 - dz))
	_vec[id] = out
	_stick_actions(id, out)
	if el.get("fires", false):
		_press_name("pad_fire", 1.0 if out.length() > FIRE_AT else 0.0)

func _dpad_to(el: Dictionary, pos: Vector2) -> void:
	var id: String = el["id"]
	var d: Vector2 = pos - el["pos"]
	var dir := Vector2.ZERO
	if d.length() >= float(el["r"]) * 0.18:
		if bool(prefs["dpad8"]):
			var n := d.normalized()
			dir = Vector2(signf(n.x) if absf(n.x) > 0.38 else 0.0, signf(n.y) if absf(n.y) > 0.38 else 0.0)
		else:
			# 4 directions: the axis in use is kept until the other is clearly stronger (no flicker).
			var cur: Vector2 = _dpad_cur.get(id, Vector2.ZERO)
			var horizontal: bool
			if cur.x != 0.0:
				horizontal = absf(d.y) <= absf(d.x) * 1.3
			elif cur.y != 0.0:
				horizontal = absf(d.x) > absf(d.y) * 1.3
			else:
				horizontal = absf(d.x) > absf(d.y)
			dir = Vector2(signf(d.x), 0.0) if horizontal else Vector2(0.0, signf(d.y))
	_dpad_cur[id] = dir
	_vec[id] = dir
	_stick_actions(id, dir)

func _stick_actions(id: String, v: Vector2) -> void:
	var names: Array = []
	for d in ["left", "right", "up", "down"]:
		names.append("pad_%s_%s" % [id, d])
	var extra: Array = _map.get(id, [])
	var strengths := [maxf(-v.x, 0.0), maxf(v.x, 0.0), maxf(-v.y, 0.0), maxf(v.y, 0.0)]
	for i in 4:
		_press_name(names[i], strengths[i])
		if extra.size() == 4:
			_press_name(str(extra[i]), strengths[i])

func _set_button(id: String, down: bool) -> void:
	if _down.get(id, false) == down:
		return
	_down[id] = down
	for n in action_names(id):
		_press_name(str(n), 1.0 if down else 0.0)
	if down:
		button_pressed.emit(id)
	else:
		button_released.emit(id)

func _press_name(action: String, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.001:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

## Lets go of everything (menus open, the layout changes, the scene closes).
func release_all() -> void:
	for el in _placed:
		match el["kind"]:
			"stick", "dpad":
				_stick_actions(el["id"], Vector2.ZERO)
			"button", "pill":
				if _down.get(el["id"], false):
					_set_button(el["id"], false)
		if el.get("fires", false):
			_press_name("pad_fire", 0.0)
	_pointers.clear()
	_down.clear()
	_vec.clear()
	_knob.clear()
	_origin.clear()
	_dpad_cur.clear()
	queue_redraw()

# ---------------------------------------------------------------- drawing
## A part pops in with a little overshoot (reveal).
static func _pop(k: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var t := clampf(k, 0.0, 1.0) - 1.0
	return clampf(1.0 + c3 * pow(t, 3.0) + c1 * pow(t, 2.0), 0.0, 1.3)

## Pressed from the screen or from its actions (a keyboard key lights it too).
func _lit(id: String) -> bool:
	if _down.get(id, false):
		return true
	for n in action_names(id):
		if InputMap.has_action(str(n)) and Input.is_action_pressed(str(n)):
			return true
	return false

## The direction the D-pad's actions are held in (touch or keyboard), for the lit arrows.
func _dir_of(id: String) -> Vector2:
	var names := action_names(id)
	var v := Vector2.ZERO
	for i in names.size():
		var n := str(names[i])
		if not InputMap.has_action(n) or not Input.is_action_pressed(n):
			continue
		match i % 4:
			0: v.x = -1.0
			1: v.x = 1.0
			2: v.y = -1.0
			3: v.y = 1.0
	return v

func _draw() -> void:
	if prefs.is_empty() or _placed.is_empty():
		return
	var sk := Draw.skin(str(prefs["skin"]))
	var base := float(prefs["opacity"])
	for el in _placed:
		if el["kind"] != "plate":
			continue
		# The plate shows once two of its buttons do (a lone A sits on its own, no empty plate).
		var vis: Array = []
		for bid in el["ids"]:
			vis.append(visibility_of(str(bid)))
		vis.sort()
		var k: float = vis[vis.size() - 2]
		if k > 0.01:
			_with_pop(el["pos"], k)
			Draw.plate(self, el["pos"], el["r"], sk, base * k)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for el in _placed:
		var id: String = el["id"]
		var k := visibility_of(id)
		if k <= 0.01 or el["kind"] == "plate":
			continue
		var held: bool = _held(id) or _lit(id)
		var a := (maxf(base, TOUCH_ALPHA) if held else base) * k
		var props: Dictionary = _props.get(id, {})
		_with_pop(el["pos"], k)
		match el["kind"]:
			"stick":
				var c: Vector2 = _origin.get(id, el["pos"])
				var idle_a := a if (_held(id) or not el["floating"]) else a * 0.5
				Draw.stick(self, c, el["r"], el["knob"], _knob.get(id, Vector2.ZERO), _held(id), sk, idle_a)
			"dpad":
				var lit_dir: Vector2 = _vec.get(id, Vector2.ZERO)
				if lit_dir == Vector2.ZERO:
					lit_dir = _dir_of(id)
				Draw.dpad(self, el["pos"], el["r"], lit_dir, sk, a)
			"button":
				var text: String = str(props.get("label", ""))
				Draw.button(self, el["pos"], el["r"], id, text if text != "" else str(el["label"]), _lit(id),
					bool(props.get("enabled", true)), sk, a, str(props.get("sub", "")), bool(props.get("ring", false)),
					float(props.get("fill", -1.0)), props.get("draw", Callable()), props.get("tint", Color(0, 0, 0, 0)), str(props.get("glyph", "")))
			"pill":
				Draw.pill(self, el["rect"], str(props.get("icon", el["icon"])), _lit(id), sk, a, props.get("draw", Callable()))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _pulse.has(id):
			var rr: float = el["r"] if el.has("r") else maxf(Rect2(el["rect"]).size.x, Rect2(el["rect"]).size.y) * 0.5
			var p: float = _pulse[id]
			draw_arc(el["pos"], rr * (1.0 + (1.0 - p) * 0.7), 0.0, TAU, 48, Color(1.0, 0.8, 0.35, p * 0.9), 4.0, true)
	if bool(prefs.get("show_map", false)) and not preview:
		_draw_map()

func _with_pop(c: Vector2, k: float) -> void:
	if k >= 0.999:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var sc := _pop(k)
	draw_set_transform(c - c * sc, 0.0, Vector2(sc, sc))

## Map mode: dashed hit areas and the action names on every part, at full strength.
func _draw_map() -> void:
	for el in _placed:
		var id: String = el["id"]
		if el["kind"] == "plate" or visibility_of(id) < 0.5:
			continue
		var names: Array = []
		for n in action_names(id):
			names.append(str(n))
		var lines: Array = [id.to_upper() + "  " + str(el["kind"])]
		lines.append_array(names.slice(0, 5))
		match el["kind"]:
			"stick":
				var c: Vector2 = el["pos"]
				if el["floating"]:
					draw_dashed_line(Vector2(el["zone"].position), Vector2(el["zone"].end.x, el["zone"].position.y), MAP_COLOR, 2.0, 12.0)
					draw_dashed_line(Vector2(el["zone"].end.x, el["zone"].position.y), Vector2(el["zone"].end), MAP_COLOR, 2.0, 12.0)
					draw_dashed_line(Vector2(el["zone"].end), Vector2(el["zone"].position.x, el["zone"].end.y), MAP_COLOR, 2.0, 12.0)
					draw_dashed_line(Vector2(el["zone"].position.x, el["zone"].end.y), Vector2(el["zone"].position), MAP_COLOR, 2.0, 12.0)
				else:
					Draw.map_ring(self, c, el["r"] * 1.4, MAP_COLOR)
				Draw.map_ring(self, c, el["r"] * float(prefs["deadzone"]), MAP_COLOR)
				Draw.map_label(self, c + Vector2(0, el["r"] * 0.45), lines, MAP_COLOR)
			"dpad":
				Draw.map_ring(self, el["pos"], el["r"] * 1.2, MAP_COLOR)
				Draw.map_label(self, el["pos"], lines.slice(0, 3), MAP_COLOR)
			"button":
				Draw.map_ring(self, el["pos"], el["r"] * 1.18, MAP_COLOR)
				# Inside the button, under the letter: the neighbours in a diamond are too close for more.
				Draw.map_label(self, el["pos"] + Vector2(0, el["r"] * 0.6), [names[0]] if names.size() > 0 else [], MAP_COLOR, 13)
				if names.size() > 1:
					Draw.map_label(self, el["pos"] + Vector2(0, el["r"] + 14.0), names.slice(1, 3), MAP_COLOR, 13)
			"pill":
				draw_rect(Rect2(el["rect"]).grow(10.0), MAP_COLOR, false, 2.0)
				Draw.map_label(self, el["pos"] + Vector2(0, el["rect"].size.y * 0.5 + 24.0), lines.slice(0, 3), MAP_COLOR)
