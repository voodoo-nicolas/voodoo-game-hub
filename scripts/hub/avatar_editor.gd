extends Control

## Avatar editor (Profile -> Upload a photo): pan (drag), zoom (slider, wheel,
## pinch), rotate, brightness / contrast / saturation, a circular preview, Reset,
## Save and Cancel. The picture is drawn into a 512x512 SubViewport so what you
## see is exactly what's saved; Avatar.encode() then shrinks it to the stored
## size and drops any EXIF. Built in code like the other hub screens; `screen`
## is the hub_screen that opened it (for its pill/label/palette helpers).

const Avatar = preload("res://scripts/common/avatar.gd")
const CANVAS := 512
const ADJUST_SHADER := """
shader_type canvas_item;
uniform float brightness = 0.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(vec3(luma), c.rgb, saturation);
	rgb = (rgb - 0.5) * contrast + 0.5 + brightness;
	COLOR = vec4(clamp(rgb, 0.0, 1.0), c.a);
}
"""

signal saved(avatar: String)
signal cancelled()

var screen: Control
var _tex: ImageTexture
var _sprite: Sprite2D
var _mat: ShaderMaterial
var _viewport: SubViewport
var _preview: TextureRect
var _base_scale := 1.0
var _zoom := 1.0
var _angle := 0.0
var _pan := Vector2.ZERO
var _sliders: Dictionary = {}
var _dragging := false

## `image` is the picked photo, already validated by the caller.
func setup(host_screen: Control, image: Image) -> void:
	screen = host_screen
	_tex = ImageTexture.create_from_image(image)
	_base_scale = float(CANVAS) / float(mini(image.get_width(), image.get_height()))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_apply()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = screen.pal.bg if Settings.is_light() else Color(0.02, 0.03, 0.06, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 28)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	col.add_child(screen.label(tr("Adjust your photo"), 32, screen.pal.accent, true, true))
	col.add_child(screen.dim(tr("Drag to move, pinch or use the slider to zoom."), 21))

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CANVAS, CANVAS)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.size = Vector2(CANVAS, CANVAS)
	_viewport.add_child(back)
	_sprite = Sprite2D.new()
	_sprite.texture = _tex
	_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ADJUST_SHADER
	_mat.shader = shader
	_sprite.material = _mat
	_viewport.add_child(_sprite)
	add_child(_viewport)

	var side_len: float = minf(get_viewport_rect().size.x - 32.0, 460.0)
	var center := CenterContainer.new()
	col.add_child(center)
	_preview = TextureRect.new()
	_preview.texture = _viewport.get_texture()
	_preview.custom_minimum_size = Vector2(side_len, side_len)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.material = Avatar.circle_material()  # the circle players will see
	_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview.gui_input.connect(_on_preview_input)
	center.add_child(_preview)

	_slider(col, "zoom", tr("Zoom"), 1.0, 4.0, 1.0, 0.01)
	_slider(col, "angle", tr("Rotate"), -180.0, 180.0, 0.0, 1.0)
	var turn := HBoxContainer.new()
	turn.add_theme_constant_override("separation", 10)
	col.add_child(turn)
	var left: Button = screen.pill("⟲ 90°", false, 24)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.pressed.connect(_turn.bind(-90.0))
	turn.add_child(left)
	var right: Button = screen.pill("⟳ 90°", false, 24)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.pressed.connect(_turn.bind(90.0))
	turn.add_child(right)
	_slider(col, "brightness", tr("Brightness"), -0.5, 0.5, 0.0, 0.01)
	_slider(col, "contrast", tr("Contrast"), 0.5, 1.8, 1.0, 0.01)
	_slider(col, "saturation", tr("Saturation"), 0.0, 2.0, 1.0, 0.01)

	var reset: Button = screen.pill(tr("Reset"), false, 24)
	reset.pressed.connect(_reset)
	col.add_child(reset)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var cancel: Button = screen.pill(tr("Cancel"), false, 26)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_on_cancel)
	row.add_child(cancel)
	var save: Button = screen.pill(tr("Save"), true, 26)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_on_save)
	row.add_child(save)

func _slider(parent: Control, key: String, title: String, lo: float, hi: float, start: float, step: float) -> void:
	parent.add_child(screen.dim(title, 20))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = start
	s.custom_minimum_size = Vector2(0, 44)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(_on_slider.bind(key))
	parent.add_child(s)
	_sliders[key] = s

func _on_slider(v: float, key: String) -> void:
	match key:
		"zoom": _zoom = v
		"angle": _angle = v
		_: _mat.set_shader_parameter(key, v)
	_apply()

func _turn(deg: float) -> void:
	var a := wrapf(_angle + deg + 180.0, 0.0, 360.0) - 180.0
	_sliders["angle"].value = a  # fires _on_slider

func _reset() -> void:
	_pan = Vector2.ZERO
	for key in _sliders:
		var s: HSlider = _sliders[key]
		s.value = 1.0 if key in ["zoom", "contrast", "saturation"] else 0.0
	_zoom = 1.0
	_angle = 0.0
	_apply()

func _apply() -> void:
	if _sprite == null:
		return
	_sprite.position = Vector2(CANVAS, CANVAS) / 2.0 + _pan
	_sprite.scale = Vector2.ONE * _base_scale * _zoom
	_sprite.rotation_degrees = _angle

func _set_zoom(z: float) -> void:
	_sliders["zoom"].value = clampf(z, 1.0, 4.0)  # fires _on_slider

func _on_preview_input(e: InputEvent) -> void:
	var k: float = float(CANVAS) / maxf(_preview.size.x, 1.0)  # screen px -> canvas px
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_dragging = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom * 1.08)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom / 1.08)
	elif e is InputEventMouseMotion and _dragging:
		_pan += e.relative * k
		_apply()
	elif e is InputEventMagnifyGesture:
		_set_zoom(_zoom * e.factor)

func _on_cancel() -> void:
	cancelled.emit()
	queue_free()

func _on_save() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = _viewport.get_texture().get_image()
	var avatar := Avatar.encode(img)
	if avatar == "":
		screen.message(tr("Your photo"), tr("Couldn't make that photo small enough. Try another one."))
		return
	saved.emit(avatar)
	queue_free()
