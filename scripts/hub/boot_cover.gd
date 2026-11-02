extends ColorRect

## A short cover over the hub while the app starts. Some phones hand the hub a
## window of the wrong shape for the first frames (it starts portrait, then
## unlocks rotation), so the home screen showed up squashed. The cover hides
## that: it stays until the hub's size has stopped changing for SETTLE_SEC and
## the layout was recomputed, then fades out onto the hub. Shown once per app
## start, not on every return from a game.

const BrandInfo = preload("res://scripts/common/brand.gd")
const BOOT_META := "viral_hub_booted"
const SETTLE_SEC := 0.3
const MAX_SEC := 2.5
const FADE_SEC := 0.25

var _last_size := Vector2.ZERO
var _stable := 0.0
var _total := 0.0
var _fading := false

## Adds the cover to `hub` the first time only. Safe to call from any hub _ready().
static func show_once(hub: Control) -> void:
	if Engine.has_meta(BOOT_META):
		return
	Engine.set_meta(BOOT_META, true)
	hub.add_child(load("res://scripts/hub/boot_cover.gd").new())

func _ready() -> void:
	color = Color(0.02, 0.01, 0.03, 1.0)  # the boot splash's colour (project.godot)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 4000
	var wm: String = BrandInfo.WORDMARK
	if ResourceLoader.exists(wm):
		var t := TextureRect.new()
		t.texture = load(wm)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.anchor_left = 0.15
		t.anchor_right = 0.85
		t.anchor_top = 0.25
		t.anchor_bottom = 0.7
		t.offset_left = 0
		t.offset_right = 0
		t.offset_top = 0
		t.offset_bottom = 0
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
	var dots := Label.new()
	dots.text = "..."
	dots.add_theme_font_size_override("font_size", 40)
	dots.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dots.offset_top = -160
	dots.offset_bottom = -100
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots)

func _process(delta: float) -> void:
	if _fading:
		return
	_total += delta
	var hub := get_parent() as Control
	var s: Vector2 = hub.size if hub != null else size
	if s != _last_size:
		_last_size = s
		_stable = 0.0
		# the hub also relayouts on `resized`; this is just a belt-and-braces nudge
		if hub != null and hub.has_method("_apply_home_orientation"):
			hub.call("_apply_home_orientation")
	else:
		_stable += delta
	if _stable >= SETTLE_SEC or _total >= MAX_SEC:
		_fading = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, FADE_SEC)
		tw.tween_callback(queue_free)
