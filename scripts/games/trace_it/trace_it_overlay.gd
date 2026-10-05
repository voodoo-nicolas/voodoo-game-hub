extends Control

## The picture laid over the camera. Full-screen; one finger drags it, two
## pinch, turn and move it together (TraceItEngine.pinch), and nothing moves
## it while `engine.locked` -- the drawing hand rests on the screen.
## On PC: left drag moves, wheel zooms, right drag turns.
##
## Shows a source from TraceItArt: one layer with steps off, or one layer
## per teaching step (the current one solid, earlier ones faint).

signal changed   # placement or look changed (the game saves a bit later)

const FX = preload("res://scripts/games/trace_it/trace_it_fx.gd")
const GRID_COLOR := Color(0.16, 0.9, 1.0, 0.75)

var engine   # TraceItEngine, shared with the game
var source: Dictionary = {}
var fit := Vector2.ZERO   # picture size on screen at scale 1

var _holder: Control
var _main: TextureRect
var _steps: Array = []    # TextureRect per step
var _touches := {}        # index -> position
var _mouse_drag := 0      # 0 none, 1 move, 2 turn


func _init(p_engine) -> void:
	engine = p_engine


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.draw.connect(_draw_holder)
	add_child(_holder)
	_main = _layer()
	resized.connect(refresh)


func _layer() -> TextureRect:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = _shader()
	t.material = m
	_holder.add_child(t)
	return t


static var _shared_shader: Shader
static func _shader() -> Shader:
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = FX.OVERLAY
	return _shared_shader


func set_source(s: Dictionary) -> void:
	source = s
	for t in _steps:
		t.queue_free()
	_steps.clear()
	if s.is_empty():
		_main.texture = null
		refresh()
		return
	for st in s.get("steps", []):
		var t := _layer()
		t.texture = ImageTexture.create_from_image(st.image)
		_steps.append(t)
	engine.step_count = maxi(1, _steps.size())
	engine.set_step(engine.step)
	refresh()


## Re-applies placement and look from the engine.
func refresh() -> void:
	if _holder == null:
		return
	visible = not source.is_empty()
	if source.is_empty():
		return
	# Scale 1 fits the part of the screen between the top bar and the
	# bottom bars (stable, so showing the tools doesn't resize the picture).
	fit = engine.fit_size(source.size, size * Vector2(1.0, 0.58))
	_holder.size = fit
	_holder.pivot_offset = fit / 2.0
	_holder.position = size / 2.0 + engine.offset - fit / 2.0
	_holder.rotation = engine.rotation
	_holder.scale = Vector2(-engine.scale if engine.flip_h else engine.scale, -engine.scale if engine.flip_v else engine.scale)
	var color: Color = engine.LINE_COLORS[engine.line_color]
	var drawing: bool = source.kind == "drawing"
	# Steps off: the whole picture in the chosen style.
	_main.visible = not engine.steps_on
	var style: String = engine.style
	if drawing:
		_main.texture = _tex("full")
		_apply(_main, {"mode": "mask"}, engine.opacity, color)
	elif style == "lines":
		_main.texture = _tex("lines")
		_apply(_main, {"mode": "mask"}, engine.opacity, color)
	else:
		_main.texture = _tex("full")
		_apply(_main, {"mode": style}, engine.opacity, color)
	var defs: Array = source.get("steps", [])
	for i in _steps.size():
		var a: float = engine.layer_alpha(i)
		_steps[i].visible = a > 0.0
		_apply(_steps[i], defs[i], engine.opacity * a, color)
	_holder.queue_redraw()


var _tex_cache := {}
func _tex(key: String) -> Texture2D:
	var img: Image = source.get(key)
	if img == null:
		return null
	var cached = _tex_cache.get(key)
	if cached and cached[0] == img:
		return cached[1]
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = [img, t]
	return t


## `look`: {mode, lo?, hi?} -- a step definition, or just a mode.
func _apply(t: TextureRect, look: Dictionary, alpha: float, color: Color) -> void:
	var m: ShaderMaterial = t.material
	m.set_shader_parameter("mode", FX.MODES.get(look.get("mode", "photo"), 0))
	m.set_shader_parameter("lo", float(look.get("lo", 0.0)))
	m.set_shader_parameter("hi", float(look.get("hi", 1.0)))
	m.set_shader_parameter("opacity", alpha)
	m.set_shader_parameter("line_color", color)


func _draw_holder() -> void:
	var r := Rect2(Vector2.ZERO, _holder.size)
	var w := 2.0 / maxf(engine.scale, 0.1)
	if engine.grid > 0:
		for i in range(1, engine.grid):
			var x: float = r.size.x * i / engine.grid
			var y: float = r.size.y * i / engine.grid
			_holder.draw_line(Vector2(x, 0), Vector2(x, r.size.y), GRID_COLOR, w)
			_holder.draw_line(Vector2(0, y), Vector2(r.size.x, y), GRID_COLOR, w)
		_holder.draw_rect(r, GRID_COLOR, false, w)
	elif not engine.locked:
		# A faint frame while placing, so a pale picture can still be found.
		_holder.draw_rect(r, Color(GRID_COLOR, 0.3), false, w)


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if source.is_empty() or engine.locked:
		if event is InputEventScreenTouch and not event.pressed:
			_touches.erase(event.index)
		return
	var touch := DisplayServer.is_touchscreen_available()
	var c := size / 2.0
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			_touches[event.index] = event.position - event.relative
		var prev: Vector2 = _touches[event.index]
		_touches[event.index] = event.position
		if _touches.size() == 1:
			engine.pan(event.relative)
		else:
			var other := Vector2.ZERO
			for k in _touches:
				if k != event.index:
					other = _touches[k]
					break
			engine.pinch(prev - c, other - c, event.position - c, other - c)
		_moved()
		accept_event()
	elif not touch and event is InputEventMouseButton:
		# PC only: a phone also sends emulated mouse events for every touch.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			engine.zoom_at(event.position - c, 1.1)
			_moved()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			engine.zoom_at(event.position - c, 1.0 / 1.1)
			_moved()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_drag = 1 if event.pressed else 0
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_drag = 2 if event.pressed else 0
	elif not touch and event is InputEventMouseMotion and _mouse_drag > 0:
		if _mouse_drag == 1:
			engine.pan(event.relative)
		else:
			engine.turn_by(event.relative.x * 0.01)
		_moved()


func _moved() -> void:
	refresh()
	changed.emit()
