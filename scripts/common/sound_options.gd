extends VBoxContainer

## The sound controls, built once and used in two places: the hub's ⚙ Options
## screen (Sound section) and the in-game ⚙ drawer's "🔊 Sound" panel.
##
##   🔊 Sound           [On]   <- Off = mute all
##   Volume      ━━━━●━━  80%
##   👆 Taps & keys     [On]     (one block per Settings.SOUND_GROUPS)
##               ━━━━━━●  100%
##
## Values live in the Settings autoload. Every change plays a sample of what
## it changed, so the player hears the new level right away.
##
##   var opts = SoundOptions.new(Settings.palette())   # colors: bg-independent keys
##   opts.drag = drag   # optional DragScroll: ignore taps that end a scroll
##   box.add_child(opts)

## A sound to preview each group with (Sfx library names).
const SAMPLE := {"taps": "tap", "game": "card_deal", "results": "win", "alerts": "notify"}

var pal: Dictionary
var compact: bool
## Set to a DragScroll when this sits in a scrolling list.
var drag: Node = null

var _sliders: Array = []  # every slider, greyed out while sound is muted
var _group_toggles: Dictionary = {}  # group id -> Button

## `compact` makes everything smaller, for the in-game drawer.
func _init(palette: Dictionary, p_compact: bool = false) -> void:
	pal = palette
	compact = p_compact

func _ready() -> void:
	add_theme_constant_override("separation", 10 if compact else 16)
	var s = get_node_or_null("/root/Settings")
	if s == null:
		return
	_toggle_row(tr("🔊 Sound"), tr("Off mutes everything.") if not compact else "", s.sound, _on_sound)
	_slider_row(tr("Volume"), s.volume, _on_volume, "")
	add_child(HSeparator.new())
	for g in s.SOUND_GROUPS:
		var id: String = g[0]
		_group_toggles[id] = _toggle_row(tr(g[1]), "" if compact else tr(g[2]), s.group_on(id), _on_group.bind(id))
		_slider_row("", s.group_volume(id), _on_group_volume.bind(id), id)
	_refresh_enabled()

# ---------- rows ----------

func _font(big: int) -> int:
	return int(big * 0.7) if compact else big

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _font(size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Title (+ hint) on the left, an On/Off pill on the right. Returns the pill.
func _toggle_row(title: String, hint: String, on: bool, on_change: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_label(title, 28, pal.text))
	if hint != "":
		col.add_child(_label(hint, 21, pal.text_dim))
	var b := Button.new()
	b.custom_minimum_size = Vector2(_font(118), _font(60))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", _font(26))
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("on", on)
	b.set_meta("sfx", "")  # the change itself plays a sample
	_style_toggle(b)
	b.pressed.connect(_on_toggle_pressed.bind(b, on_change))
	row.add_child(b)
	return b

## An optional title, then a slider and its percentage.
func _slider_row(title: String, value: int, on_change: Callable, group: String) -> void:
	if title != "":
		add_child(_label(title, 28, pal.text))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, _font(56))
	slider.focus_mode = Control.FOCUS_NONE
	slider.scrollable = false  # the mouse wheel scrolls the list, not the volume
	_style_slider(slider)
	row.add_child(slider)
	var pct := _label("%d%%" % value, 24, pal.text_dim)
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	pct.custom_minimum_size = Vector2(_font(76), 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	slider.set_meta("group", group)
	# Live while dragging; saved (and previewed) once, on release.
	slider.value_changed.connect(_on_slider_moved.bind(slider, pct, on_change))
	slider.drag_ended.connect(_on_slider_released.bind(slider, on_change))
	_sliders.append(slider)

func _style_toggle(b: Button) -> void:
	var on: bool = b.get_meta("on")
	b.text = tr("On") if on else tr("Off")
	var sb := _box(pal.accent_fill if on else pal.off_fill, pal.accent if on else pal.off_border)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, sb)
	var fc: Color = pal.text if on else pal.text_dim
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, fc)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(14 if not compact else 10)
	sb.set_border_width_all(2)
	sb.border_color = border
	return sb

## A thick track, filled with the accent up to the knob, and a big round
## knob a finger can find (Godot's default slider is tiny on a phone).
func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = pal.off_fill
	track.border_color = pal.off_border
	track.set_border_width_all(1)
	track.set_corner_radius_all(8)
	track.content_margin_top = _font(8)
	track.content_margin_bottom = _font(8)
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = pal.accent
	fill.set_corner_radius_all(8)
	fill.content_margin_top = _font(8)
	fill.content_margin_bottom = _font(8)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob(_font(40), pal.accent)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.add_theme_icon_override("grabber_disabled", _knob(_font(40), pal.off_border))

static func _knob(d: int, color: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)  # soft 1px edge
			var c := Color(1, 1, 1) if dist < r * 0.45 else color
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)

# ---------- actions ----------

func _settings() -> Node:
	return get_node_or_null("/root/Settings")

func _sample(group: String) -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(SAMPLE.get(group, "tap"))

func _on_toggle_pressed(b: Button, on_change: Callable) -> void:
	if drag and drag.moved:
		return
	var on: bool = not b.get_meta("on")
	b.set_meta("on", on)
	_style_toggle(b)
	on_change.call(on)

func _on_sound(on: bool) -> void:
	_settings().set_sound(on)
	_refresh_enabled()
	if on:
		_sample("taps")

func _on_group(on: bool, id: String) -> void:
	_settings().set_group_on(id, on)
	_refresh_enabled()
	if on:
		_sample(id)

func _on_volume(v: int, save: bool) -> void:
	_settings().set_volume(v, save)

func _on_group_volume(v: int, save: bool, id: String) -> void:
	_settings().set_group_volume(id, v, save)

func _on_slider_moved(value: float, slider: HSlider, pct: Label, on_change: Callable) -> void:
	pct.text = "%d%%" % int(value)
	on_change.call(int(value), false)

func _on_slider_released(_changed: bool, slider: HSlider, on_change: Callable) -> void:
	on_change.call(int(slider.value), true)
	var g: String = slider.get_meta("group")
	_sample(g if g != "" else "taps")

## Sliders that can't be heard grey out: all of them while muted, and a
## group's own slider while that group is off.
func _refresh_enabled() -> void:
	var s = _settings()
	for slider in _sliders:
		var g: String = slider.get_meta("group")
		var live: bool = s.sound and (g == "" or s.group_on(g))
		slider.editable = live
		slider.modulate.a = 1.0 if live else 0.4
