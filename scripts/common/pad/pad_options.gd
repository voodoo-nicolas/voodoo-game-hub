extends VBoxContainer

## The controller settings panel (Pad), built once for two places: the Pad Lab and, later, the
## in-game ⚙ Options. Changes apply live to `target` (a PadController) and are saved once for
## every game (user://pad.json).
##
##   Layout   cards that preview each layout in the chosen look; tap one to pick it
##   Look     Neon / Mono / Outline
##   Size, Opacity (0 = invisible, buttons still work), Dead zone
##   Right-handed, Floating sticks, 8-way D-pad, Show button map
##
##   var opts = PadOptions.new(Settings.palette(), pad)
##   box.add_child(opts)

const Layouts = preload("res://scripts/common/pad/pad_layouts.gd")
const Draw = preload("res://scripts/common/pad/pad_draw.gd")
const Prefs = preload("res://scripts/common/pad/pad_prefs.gd")
const Controller = preload("res://scripts/common/pad/pad_controller.gd")
const SoundOptions = preload("res://scripts/common/sound_options.gd")

signal changed(prefs: Dictionary)

var pal: Dictionary
var target: Control = null
var prefs: Dictionary
## Set to a DragScroll when this sits in a scrolling list.
var drag: Node = null
## Layout cards per row: 2 in a wide panel, 1 in a narrow one.
var columns := 2

var _cards := {}        # layout id -> Button
var _previews: Array = []
var _skin_buttons := {}
var _toggles := {}      # pref key -> Button
var _sliders := {}      # pref key -> [HSlider, Label]

func _init(palette: Dictionary, p_target: Control = null) -> void:
	pal = palette
	target = p_target

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	prefs = target.prefs.duplicate() if target != null and not target.prefs.is_empty() else Prefs.load_prefs()
	if target != null and target.has_method("layout_id") and not target.allowed_layouts.is_empty() and not target.allowed_layouts.has(str(prefs["layout"])):
		prefs["layout"] = target.layout_id()   # the layout actually shown, not a saved one this game can't use
	add_child(_label(tr("Layout"), 28, pal.text))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	var allowed: Array = target.allowed_layouts if target != null else []
	for l in Layouts.LAYOUTS:
		if allowed.is_empty() or allowed.has(l["id"]):
			grid.add_child(_card(l))
	add_child(_label(tr("Look"), 28, pal.text))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for sid in Draw.skin_ids():
		var b := Button.new()
		b.text = tr(Draw.skin(sid)["name"])
		b.custom_minimum_size = Vector2(150, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_skin.bind(sid))
		row.add_child(b)
		_skin_buttons[sid] = b
	_slider(tr("Size"), "size", 0.6, 1.4, 0.05)
	_slider(tr("Opacity (0 = invisible, still works)"), "opacity", 0.0, 1.0, 0.05)
	_slider(tr("Dead zone"), "deadzone", 0.05, 0.4, 0.01)
	_toggle(tr("Right-handed"), "right_handed")
	_toggle(tr("Floating sticks"), "floating")
	_toggle(tr("8-way D-pad"), "dpad8")
	_toggle(tr("Show button map"), "show_map")
	var reset := Button.new()
	reset.text = tr("Reset controls")
	reset.custom_minimum_size = Vector2(0, 60)
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_font_size_override("font_size", 24)
	reset.pressed.connect(_on_reset)
	add_child(reset)
	_refresh()

# ---------------------------------------------------------------- building
func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _box(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(width)
	sb.border_color = border
	return sb

func _card(l: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.pressed.connect(_on_layout.bind(str(l["id"])))
	var pad: Control = Controller.new()
	pad.preview = true
	pad.layout_override = str(l["id"])
	pad.prefs = prefs.duplicate()
	pad.prefs["show_map"] = false
	pad.prefs["opacity"] = 1.0
	pad.prefs["floating"] = false
	# A phone-landscape sized preview in the middle of the card, whatever the card's width.
	pad.anchor_left = 0.5
	pad.anchor_right = 0.5
	pad.anchor_top = 0.0
	pad.anchor_bottom = 0.0
	pad.offset_left = -200.0
	pad.offset_right = 200.0
	pad.offset_top = 6.0
	pad.offset_bottom = 196.0
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pad)
	_previews.append(pad)
	var title := _label(tr(str(l["name"])), 22, pal.text)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_top = -38
	title.offset_bottom = -6
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(title)
	_cards[str(l["id"])] = b
	return b

func _slider(title: String, key: String, lo: float, hi: float, step: float) -> void:
	add_child(_label(title, 26, pal.text))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(prefs[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 56)
	s.focus_mode = Control.FOCUS_NONE
	s.scrollable = false
	_style_slider(s)
	row.add_child(s)
	var v := _label("", 24, pal.text_dim)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.custom_minimum_size = Vector2(76, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	s.value_changed.connect(_on_slider.bind(key))
	_sliders[key] = [s, v]

func _style_slider(s: HSlider) -> void:
	var track := _box(pal.off_fill, pal.off_border, 1)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	var fill := _box(pal.accent, pal.accent, 0)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob: ImageTexture = SoundOptions._knob(40, pal.accent)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)

func _toggle(title: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var l := _label(title, 26, pal.text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(_on_toggle.bind(key))
	row.add_child(b)
	_toggles[key] = b

# ---------------------------------------------------------------- state -> widgets
func _refresh() -> void:
	for id in _cards:
		var on: bool = id == str(prefs["layout"])
		var sb := _box(pal.accent_fill if on else pal.off_fill, pal.accent if on else pal.off_border, 3 if on else 2)
		for state in ["normal", "hover", "pressed", "focus"]:
			_cards[id].add_theme_stylebox_override(state, sb)
	for p in _previews:
		p.prefs["skin"] = prefs["skin"]
		p.prefs["right_handed"] = prefs["right_handed"]
		p.queue_redraw()
	for sid in _skin_buttons:
		var on2: bool = sid == str(prefs["skin"])
		var sb2 := _box(pal.accent_fill if on2 else pal.off_fill, pal.accent if on2 else pal.off_border)
		for state in ["normal", "hover", "pressed", "focus"]:
			_skin_buttons[sid].add_theme_stylebox_override(state, sb2)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_skin_buttons[sid].add_theme_color_override(key, pal.text if on2 else pal.text_dim)
	for key in _toggles:
		var on3: bool = bool(prefs[key])
		var b: Button = _toggles[key]
		b.text = tr("On") if on3 else tr("Off")
		var sb3 := _box(pal.accent_fill if on3 else pal.off_fill, pal.accent if on3 else pal.off_border)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb3)
		for fk in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(fk, pal.text if on3 else pal.text_dim)
	for key in _sliders:
		var pair: Array = _sliders[key]
		(pair[0] as HSlider).set_value_no_signal(float(prefs[key]))
		(pair[1] as Label).text = "%d%%" % int(round(float(prefs[key]) * 100.0))

# ---------------------------------------------------------------- changes
func _commit() -> void:
	prefs = Prefs.clean(prefs)
	if target != null:
		target.apply_prefs(prefs)
	else:
		Prefs.save_prefs(prefs)
	_refresh()
	changed.emit(prefs)

func _tapped() -> bool:
	return drag == null or not drag.moved

func _on_layout(id: String) -> void:
	if _tapped():
		prefs["layout"] = id
		_commit()

func _on_skin(id: String) -> void:
	if _tapped():
		prefs["skin"] = id
		_commit()

func _on_toggle(key: String) -> void:
	if _tapped():
		prefs[key] = not bool(prefs[key])
		_commit()

func _on_slider(value: float, key: String) -> void:
	prefs[key] = value
	_commit()

func _on_reset() -> void:
	if _tapped():
		prefs = Prefs.DEFAULTS.duplicate()
		_commit()
