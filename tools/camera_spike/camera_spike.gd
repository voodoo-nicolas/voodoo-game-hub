extends Control
# Step 0 risk spike for "Trace It" / "Calcá" (camera tracing game).
# Throwaway: answers "can Godot 4.7.2's own CameraServer carry this game on a
# real Android phone?" before any game code is written. See README.md.
#
# Measures: camera fps, render fps, frame-gap jitter, CPU readback of a frame,
# the accuracy check's distance transform in GDScript, and latency (flash
# test + an on-screen clock). Also tries the risky platform bits: permission
# flow, opening app settings, picking a gallery image, saving to the gallery,
# pause/resume, the line-art overlay shader.

const TARGET := Vector2i(1280, 720)   # preferred camera format
const ACC_W := 320                    # accuracy check works at this width

var feed: CameraFeed = null
var feeds: Array = []                 # CameraFeed, back cameras first
var feed_cursor := 0
var fmt_list: Array = []              # [{i, w, h, f}] usable formats of the feed
var fmt_cursor := 0
var y_tex := CameraTexture.new()
var c_tex := CameraTexture.new()

var view: ColorRect
var view_mat: ShaderMaterial
var overlay: TextureRect
var overlay_mat: ShaderMaterial
var hud: Label
var clock: Label
var thumb: TextureRect
var flash: ColorRect
var ui: Control

var extra_rot := 0                    # manual 90-degree steps on top of feed_transform
var mirror := false
var swap_uv := false
var overlay_style := 2                # 0 original, 1 gray, 2 line art, 3 inverted
var overlay_opacity := 0.5
var frame_times: Array = []           # usec of recent frames
var frames_total := 0
var hud_t := 0.0
var resume_us := 0
var results := {}                     # name -> text, for the report

# latency test
var lat_phase := ""                   # "", "dark", "lit"
var lat_t0 := 0
var lat_dark: Array = []
var lat_samples: Array = []
var lat_reps := 0
var lat_threshold := 0.0

const VIEW_SHADER := """
shader_type canvas_item;
uniform sampler2D y_tex : filter_linear;
uniform sampler2D c_tex : filter_linear;
uniform bool rgb_mode = false;
uniform bool swap_uv = false;
uniform vec2 bx = vec2(1.0, 0.0);
uniform vec2 by = vec2(0.0, 1.0);
void fragment() {
	vec2 p = UV - 0.5;
	vec2 cuv = bx * p.x + by * p.y + 0.5;
	if (rgb_mode) {
		COLOR = vec4(texture(y_tex, cuv).rgb, 1.0);
	} else {
		float y = texture(y_tex, cuv).r;
		vec2 c = texture(c_tex, cuv).rg - 0.5;
		if (swap_uv) { c = c.yx; }
		COLOR = vec4(y + 1.402 * c.y, y - 0.344136 * c.x - 0.714136 * c.y, y + 1.772 * c.x, 1.0);
	}
}
"""

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform int mode = 2;
uniform float opacity = 0.5;
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
// TEXTURE can't be passed to a function, so the taps are spelled out.
#define at(T, P) lum(texture(T, P).rgb)
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	if (mode == 0) {
		COLOR = vec4(c.rgb, c.a * opacity);
	} else if (mode == 1) {
		COLOR = vec4(vec3(lum(c.rgb)), c.a * opacity);
	} else if (mode == 3) {
		COLOR = vec4(1.0 - c.rgb, c.a * opacity);
	} else {
		float tl = at(TEXTURE, UV + px * vec2(-1, -1)), t = at(TEXTURE, UV + px * vec2(0, -1)), tr = at(TEXTURE, UV + px * vec2(1, -1));
		float l = at(TEXTURE, UV + px * vec2(-1, 0)), r = at(TEXTURE, UV + px * vec2(1, 0));
		float bl = at(TEXTURE, UV + px * vec2(-1, 1)), b = at(TEXTURE, UV + px * vec2(0, 1)), br = at(TEXTURE, UV + px * vec2(1, 1));
		float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
		float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
		float e = clamp(length(vec2(gx, gy)) * 3.0 - 0.15, 0.0, 1.0);
		COLOR = vec4(line_color.rgb, e * opacity * c.a);
	}
}
"""


func _ready() -> void:
	DisplayServer.screen_set_keep_on(true)
	clip_contents = true
	_build_ui()
	_log("device", "%s / %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version()])
	_log("gpu", "%s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()])
	_log("screen", "%s px, scale %.2f" % [DisplayServer.screen_get_size(), DisplayServer.screen_get_scale()])
	if _have_permission():
		_start_monitoring()
	else:
		_ask_permission()


# ---------------------------------------------------------------- permission

func _have_permission() -> bool:
	return OS.get_name() != "Android" or OS.get_granted_permissions().has("android.permission.CAMERA")


func _ask_permission() -> void:
	if not get_tree().on_request_permissions_result.is_connected(_on_permission):
		get_tree().on_request_permissions_result.connect(_on_permission)
	_log("permission", "asking...")
	OS.request_permission("CAMERA")


func _on_permission(permission: String, granted: bool) -> void:
	if not permission.ends_with("CAMERA"):
		return
	_log("permission", "granted" if granted else "DENIED (tap App settings, or Camera to ask again)")
	if granted:
		_start_monitoring()


# ---------------------------------------------------------------- feeds

func _start_monitoring() -> void:
	if not CameraServer.camera_feeds_updated.is_connected(_on_feeds_updated):
		CameraServer.camera_feeds_updated.connect(_on_feeds_updated)
	if CameraServer.monitoring_feeds:
		_on_feeds_updated()
	else:
		CameraServer.monitoring_feeds = true
		if CameraServer.get_feed_count() > 0:
			_on_feeds_updated()


func _on_feeds_updated() -> void:
	feeds.clear()
	var names := PackedStringArray()
	for f in CameraServer.feeds():
		names.append("%s[%d fmts]" % [f.get_name(), f.get_formats().size()])
		if f.get_position() == CameraFeed.FEED_BACK:
			feeds.push_front(f)
		else:
			feeds.append(f)
	_log("feeds", ", ".join(names) if names.size() > 0 else "NONE")
	if feeds.size() > 0 and feed == null:
		feed_cursor = 0
		_open_feed(feeds[0])


func _open_feed(f: CameraFeed) -> void:
	if feed != null:
		feed.feed_is_active = false
		if feed.frame_changed.is_connected(_on_frame):
			feed.frame_changed.disconnect(_on_frame)
			feed.format_changed.disconnect(_on_format_changed)
	feed = f
	mirror = f.get_position() == CameraFeed.FEED_FRONT
	fmt_list.clear()
	var all: Array = f.get_formats()
	for i in all.size():
		var d: Dictionary = all[i]
		var fname: String = str(d.get("format", ""))
		# Android: prefer YUV (what the preview pipeline is built for).
		if OS.get_name() == "Android" and not fname.contains("YUV"):
			continue
		fmt_list.append({"i": i, "w": int(d.get("width", 0)), "h": int(d.get("height", 0)), "f": fname})
	if fmt_list.is_empty():
		for i in all.size():
			var d2: Dictionary = all[i]
			fmt_list.append({"i": i, "w": int(d2.get("width", 0)), "h": int(d2.get("height", 0)), "f": str(d2.get("format", ""))})
	fmt_list.sort_custom(func(a, b): return a.w * a.h < b.w * b.h)
	var sizes := PackedStringArray()
	for d in fmt_list:
		sizes.append("%dx%d" % [d.w, d.h])
	_log("formats", " ".join(sizes))
	fmt_cursor = 0
	var best := 1 << 40
	for k in fmt_list.size():
		var d: Dictionary = fmt_list[k]
		var cost: int = absi(d.w - TARGET.x) + absi(d.h - TARGET.y)
		if cost < best:
			best = cost
			fmt_cursor = k
	f.frame_changed.connect(_on_frame)
	f.format_changed.connect(_on_format_changed)
	_activate()


func _activate() -> void:
	if feed == null:
		return
	feed.feed_is_active = false
	if not fmt_list.is_empty():
		var ok: bool = feed.set_format(fmt_list[fmt_cursor].i, {})
		if not ok:
			_log("format", "set_format FAILED")
	y_tex.camera_feed_id = feed.get_id()
	y_tex.which_feed = CameraServer.FEED_Y_IMAGE
	c_tex.camera_feed_id = feed.get_id()
	c_tex.which_feed = CameraServer.FEED_CBCR_IMAGE
	frame_times.clear()
	feed.feed_is_active = true
	_log("active", "%s %s" % [feed.get_name(), _fmt_text()] if feed.feed_is_active else "activation FAILED")
	_layout_view()


func _fmt_text() -> String:
	if fmt_list.is_empty():
		return "(no formats)"
	var d: Dictionary = fmt_list[fmt_cursor]
	return "%dx%d %s (%d/%d)" % [d.w, d.h, d.f, fmt_cursor + 1, fmt_list.size()]


func _on_format_changed() -> void:
	_layout_view()


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	frames_total += 1
	frame_times.append(now)
	while frame_times.size() > 2 and now - int(frame_times[0]) > 5_000_000:
		frame_times.pop_front()
	if resume_us > 0:
		_log("resume", "frames back %d ms after resume" % int((now - resume_us) / 1000))
		resume_us = 0
	view_mat.set_shader_parameter("rgb_mode", feed.get_datatype() == CameraFeed.FEED_RGB)
	if lat_phase != "":
		_latency_frame(now)


# ---------------------------------------------------------------- layout

func _basis() -> Transform2D:
	var t: Transform2D = feed.feed_transform if feed else Transform2D.IDENTITY
	var b := Transform2D(t.x, t.y, Vector2.ZERO)
	b = Transform2D(deg_to_rad(90.0 * extra_rot), Vector2.ZERO) * b
	if mirror:
		b = b * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
	return b


func _layout_view() -> void:
	if feed == null or fmt_list.is_empty():
		return
	var d: Dictionary = fmt_list[fmt_cursor]
	var b := _basis()
	view_mat.set_shader_parameter("bx", b.x)
	view_mat.set_shader_parameter("by", b.y)
	view_mat.set_shader_parameter("swap_uv", swap_uv)
	var w := float(d.w)
	var h := float(d.h)
	if absf(b.x.y) > 0.5:   # quarter turn: shown sideways
		var tmp := w
		w = h
		h = tmp
	var area := size
	var s := maxf(area.x / w, area.y / h)   # cover
	view.size = Vector2(w, h) * s
	view.position = (area - view.size) / 2.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and view:
		_layout_view()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_log("pause", "app paused at %d frames" % frames_total)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		resume_us = Time.get_ticks_usec()
		_log("resume", "resumed, waiting for frames... (feed active=%s)" % [feed.feed_is_active if feed else false])


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	view = ColorRect.new()
	view_mat = ShaderMaterial.new()
	view_mat.shader = Shader.new()
	view_mat.shader.code = VIEW_SHADER
	view_mat.set_shader_parameter("y_tex", y_tex)
	view_mat.set_shader_parameter("c_tex", c_tex)
	view.material = view_mat
	add_child(view)

	overlay = TextureRect.new()
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = Shader.new()
	overlay_mat.shader.code = OVERLAY_SHADER
	overlay.material = overlay_mat
	overlay.texture = ImageTexture.create_from_image(_test_picture())
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_apply_overlay()

	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel_style())
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 40
	ui.add_child(top)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 19)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(hud)

	clock = Label.new()
	clock.add_theme_font_size_override("font_size", 44)
	clock.add_theme_color_override("font_outline_color", Color.BLACK)
	clock.add_theme_constant_override("outline_size", 8)
	clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	clock.offset_left = -300
	clock.offset_right = -16
	ui.add_child(clock)

	thumb = TextureRect.new()
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	thumb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	thumb.offset_left = 16
	thumb.offset_right = 216
	thumb.offset_top = -40
	thumb.offset_bottom = 220
	ui.add_child(thumb)

	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _panel_style())
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(bottom)
	var grid := GridContainer.new()
	grid.columns = 4
	bottom.add_child(grid)
	for spec in [
		["Format ▶", _next_format], ["Camera ⇄", _next_camera], ["Rot +90", _rot], ["Mirror", _toggle_mirror],
		["Swap UV", _toggle_swap], ["Overlay", _next_style], ["Opacity", _next_opacity], ["Hide UI", _hide_ui],
		["Capture ×10", _bench_capture], ["Distance", _bench_distance], ["Latency", _start_latency], ["Pick image", _pick_image],
		["Save image", _save_image], ["App settings", _open_settings], ["Copy report", _copy_report], ["Quit", get_tree().quit],
	]:
		var btn := Button.new()
		btn.text = spec[0]
		btn.custom_minimum_size = Vector2(0, 76)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(spec[1])
		grid.add_child(btn)

	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.BLACK
	flash.visible = false
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _test_picture() -> Image:
	# A stand-in "template": shaded disc, a house, a few strokes.
	var w := 360
	var h := 480
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in h:
		for x in w:
			var r := Vector2(x - 180, y - 150).length()
			if r < 110:
				var k := 0.35 + 0.6 * clampf((x + y) / 600.0, 0, 1)
				img.set_pixel(x, y, Color(k, k * 0.8, 0.3, 1))
	img.fill_rect(Rect2i(90, 300, 180, 140), Color(0.2, 0.5, 0.9, 1))
	img.fill_rect(Rect2i(160, 360, 40, 80), Color(0.95, 0.9, 0.8, 1))
	for i in 160:
		img.fill_rect(Rect2i(90 + i / 2, 300 - i / 2, 3, 3), Color(0.1, 0.1, 0.1, 1))
		img.fill_rect(Rect2i(270 - i / 2, 300 - i / 2, 3, 3), Color(0.1, 0.1, 0.1, 1))
	return img


func _apply_overlay() -> void:
	overlay_mat.set_shader_parameter("mode", overlay_style)
	overlay_mat.set_shader_parameter("opacity", overlay_opacity)


func _process(delta: float) -> void:
	clock.text = "%.3f s" % (Time.get_ticks_msec() / 1000.0)
	if lat_phase != "":
		_latency_tick()
	hud_t += delta
	if hud_t < 0.5:
		return
	hud_t = 0.0
	var cam_fps := 0.0
	var gap := 0.0
	if frame_times.size() > 2:
		cam_fps = (frame_times.size() - 1) / ((int(frame_times[-1]) - int(frame_times[0])) / 1e6)
		for i in range(1, frame_times.size()):
			gap = maxf(gap, (int(frame_times[i]) - int(frame_times[i - 1])) / 1000.0)
	var rot := rad_to_deg(feed.feed_transform.get_rotation()) if feed else 0.0
	results["camera fps"] = "%.1f (5 s avg), worst gap %d ms" % [cam_fps, int(gap)]
	results["render fps"] = "%d, process %.1f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]
	var lines := PackedStringArray()
	lines.append("FEED %s  %s" % [feed.get_name() if feed else "-", _fmt_text()])
	lines.append("feed rot %d°  extra %d°  mirror %s  swapUV %s  type %d" % [int(rot), extra_rot * 90, mirror, swap_uv, feed.get_datatype() if feed else -1])
	lines.append("CAMERA %s" % results["camera fps"])
	lines.append("RENDER %s" % results["render fps"])
	for k in results:
		if k != "camera fps" and k != "render fps" and k != "device" and k != "gpu" and k != "screen":
			lines.append("%s: %s" % [k, results[k]])
	hud.text = "\n".join(lines)


func _log(key: String, text: String) -> void:
	results[key] = text
	print("[spike] %s: %s" % [key, text])


# ---------------------------------------------------------------- buttons

func _next_format() -> void:
	if fmt_list.is_empty():
		return
	fmt_cursor = (fmt_cursor + 1) % fmt_list.size()
	_activate()


func _next_camera() -> void:
	if not _have_permission():
		_ask_permission()
		return
	if feeds.size() < 2:
		return
	feed_cursor = (feed_cursor + 1) % feeds.size()
	_open_feed(feeds[feed_cursor])


func _rot() -> void:
	extra_rot = (extra_rot + 1) % 4
	_layout_view()


func _toggle_mirror() -> void:
	mirror = not mirror
	_layout_view()


func _toggle_swap() -> void:
	swap_uv = not swap_uv
	_layout_view()


func _next_style() -> void:
	overlay_style = (overlay_style + 1) % 4
	_log("overlay", ["original", "grayscale", "line art", "inverted"][overlay_style])
	_apply_overlay()


func _next_opacity() -> void:
	overlay_opacity = fmod(overlay_opacity + 0.25, 1.25)
	_log("opacity", "%d%%" % int(overlay_opacity * 100))
	_apply_overlay()


func _hide_ui() -> void:
	ui.visible = false


func _gui_input(event: InputEvent) -> void:
	if not ui.visible and event is InputEventMouseButton and event.pressed:
		ui.visible = true


# Reads back the Y plane (= grayscale) the way the accuracy check will.
func _bench_capture() -> void:
	if feed == null or not feed.feed_is_active:
		_log("capture", "no active feed")
		return
	var get_ms := 0.0
	var prep_ms := 0.0
	var img: Image = null
	for i in 10:
		var t0 := Time.get_ticks_usec()
		img = y_tex.get_image()
		var t1 := Time.get_ticks_usec()
		if img == null or img.is_empty():
			_log("capture", "get_image() returned nothing")
			return
		if img.get_format() != Image.FORMAT_L8:
			img.convert(Image.FORMAT_L8)
		img.resize(ACC_W, int(ACC_W * float(img.get_height()) / img.get_width()), Image.INTERPOLATE_BILINEAR)
		var t2 := Time.get_ticks_usec()
		get_ms += (t1 - t0) / 1000.0
		prep_ms += (t2 - t1) / 1000.0
	thumb.texture = ImageTexture.create_from_image(img)
	_log("capture", "readback %.1f ms + to %dpx gray %.1f ms (avg of 10), frame %s" % [get_ms / 10, ACC_W, prep_ms / 10, y_tex.get_size()])


# The accuracy check's heavy part, in plain GDScript at the real size.
func _bench_distance() -> void:
	var w := ACC_W
	var h := 427
	var tmask := PackedByteArray()
	var ink := PackedByteArray()
	tmask.resize(w * h)
	ink.resize(w * h)
	for y in h:
		for x in w:
			var dx := float(x - 160)
			var dy := float(y - 213)
			var r := sqrt(dx * dx + dy * dy)
			tmask[y * w + x] = 1 if absf(r - 120.0) < 1.5 else 0
			ink[y * w + x] = 1 if absf(r - 123.0 + 4.0 * sin(atan2(dy, dx) * 5.0)) < 2.0 else 0
	var t0 := Time.get_ticks_usec()
	var d_t := _chamfer(tmask, w, h)
	var d_i := _chamfer(ink, w, h)
	var tol := 4 * 3   # 4 px in chamfer units
	var ink_n := 0
	var ink_ok := 0
	var tpl_n := 0
	var tpl_ok := 0
	for i in w * h:
		if ink[i]:
			ink_n += 1
			if d_t[i] <= tol:
				ink_ok += 1
		if tmask[i]:
			tpl_n += 1
			if d_i[i] <= tol:
				tpl_ok += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var p := float(ink_ok) / maxi(ink_n, 1)
	var rc := float(tpl_ok) / maxi(tpl_n, 1)
	var f1 := 0.0 if p + rc == 0 else 2 * p * rc / (p + rc)
	_log("distance", "%dx%d: %d ms (2 transforms + F1), F1 %.0f%%" % [w, h, int(ms), f1 * 100])


func _chamfer(mask: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var big := 1 << 20
	var d := PackedInt32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0 if mask[i] else big
	for y in h:
		for x in w:
			var i := y * w + x
			var v := d[i]
			if v == 0:
				continue
			if x > 0:
				v = mini(v, d[i - 1] + 3)
			if y > 0:
				v = mini(v, d[i - w] + 3)
				if x > 0:
					v = mini(v, d[i - w - 1] + 4)
				if x < w - 1:
					v = mini(v, d[i - w + 1] + 4)
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if v == 0:
				continue
			if x < w - 1:
				v = mini(v, d[i + 1] + 3)
			if y < h - 1:
				v = mini(v, d[i + w] + 3)
				if x < w - 1:
					v = mini(v, d[i + w + 1] + 4)
				if x > 0:
					v = mini(v, d[i + w - 1] + 4)
			d[i] = v
	return d


# Flash test: the screen goes white; time until the camera sees it brighten.
# Use the FRONT camera with a sheet of white paper ~5 cm over the screen, in a
# dim room. The on-screen clock is the manual check for the back camera.
func _start_latency() -> void:
	if feed == null or not feed.feed_is_active:
		_log("latency", "no active feed")
		return
	lat_samples.clear()
	lat_reps = 0
	_lat_dark()
	_log("latency", "running... hold white paper over the screen (front camera)")


func _lat_dark() -> void:
	lat_phase = "dark"
	lat_t0 = Time.get_ticks_usec()
	lat_dark.clear()
	flash.color = Color.BLACK
	flash.visible = true


func _latency_tick() -> void:
	var now := Time.get_ticks_usec()
	if lat_phase == "dark" and now - lat_t0 > 900_000 and lat_dark.size() >= 3:
		var base := 0.0
		for v in lat_dark:
			base += v
		base /= lat_dark.size()
		lat_threshold = base + 12.0
		lat_phase = "lit"
		flash.color = Color.WHITE
		lat_t0 = Time.get_ticks_usec()
	elif lat_phase == "lit" and now - lat_t0 > 1_500_000:
		lat_samples.append(-1)
		_lat_next()


func _latency_frame(now: int) -> void:
	var m := _frame_mean()
	if m < 0:
		return
	if lat_phase == "dark" and now - lat_t0 > 500_000:
		lat_dark.append(m)
	elif lat_phase == "lit" and m > lat_threshold:
		lat_samples.append((now - lat_t0) / 1000.0)
		_lat_next()


func _lat_next() -> void:
	lat_reps += 1
	if lat_reps < 8:
		_lat_dark()
		return
	lat_phase = ""
	flash.visible = false
	var hits: Array = lat_samples.filter(func(v): return v >= 0)
	hits.sort()
	if hits.is_empty():
		_log("latency", "no flash seen (darker room? paper closer?)")
	else:
		_log("latency", "median %d ms, min %d, max %d (%d/8 seen)" % [int(hits[hits.size() / 2]), int(hits[0]), int(hits[-1]), hits.size()])


func _frame_mean() -> float:
	var img: Image = y_tex.get_image()
	if img == null or img.is_empty():
		return -1.0
	var w := img.get_width()
	var h := img.get_height()
	var r := img.get_region(Rect2i(w / 2 - 64, h / 2 - 64, 128, 128))
	if r.get_format() != Image.FORMAT_L8 and r.get_format() != Image.FORMAT_R8:
		r.convert(Image.FORMAT_L8)
	var data := r.get_data()
	var sum := 0
	var n := 0
	for i in range(0, data.size(), 4):
		sum += data[i]
		n += 1
	return float(sum) / maxi(n, 1)


func _pick_image() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		_log("pick", "no native file dialog on this platform")
		return
	var err := DisplayServer.file_dialog_show("Pick an image", "", "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp;Images;image/*"]), _on_picked)
	if err != OK:
		_log("pick", "file_dialog_show error %d" % err)


func _on_picked(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if not status or paths.is_empty():
		_log("pick", "cancelled")
		return
	var path := paths[0]
	var t0 := Time.get_ticks_msec()
	var img := Image.load_from_file(path)
	var how := "load_from_file"
	if img == null or img.is_empty():
		var buf := FileAccess.get_file_as_bytes(path)
		img = Image.new()
		how = "bytes(%d)" % buf.size()
		if img.load_png_from_buffer(buf) != OK and img.load_jpg_from_buffer(buf) != OK and img.load_webp_from_buffer(buf) != OK:
			_log("pick", "could NOT load %s (%s)" % [path, how])
			return
	var big := img.get_size()
	if maxi(big.x, big.y) > 1600:
		var k := 1600.0 / maxi(big.x, big.y)
		img.resize(int(big.x * k), int(big.y * k), Image.INTERPOLATE_BILINEAR)
	overlay.texture = ImageTexture.create_from_image(img)
	_log("pick", "OK %s via %s, %s -> %s, %d ms" % [path.get_file(), how, big, img.get_size(), Time.get_ticks_msec() - t0])


func _save_image() -> void:
	var img: Image = y_tex.get_image() if feed and feed.feed_is_active else _test_picture()
	if img == null or img.is_empty():
		img = _test_picture()
	if img.get_format() == Image.FORMAT_R8:
		img.convert(Image.FORMAT_L8)
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("TraceIt")
	var mk := DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join("spike_%d.png" % int(Time.get_unix_time_from_system()))
	var err := img.save_png(file)
	var scanned := "no AndroidRuntime"
	var rt: Object = Engine.get_singleton("AndroidRuntime") if Engine.has_singleton("AndroidRuntime") else null
	if err == OK and rt:
		var msc = JavaClassWrapper.wrap("android.media.MediaScannerConnection")
		msc.scanFile(rt.getActivity(), PackedStringArray([file]), PackedStringArray(["image/png"]), null)
		scanned = "media scan requested"
	_log("save", "%s -> %s (mkdir %d), %s" % [file, "OK" if err == OK else "ERROR %d" % err, mk, scanned])


func _open_settings() -> void:
	if not Engine.has_singleton("AndroidRuntime"):
		_log("settings", "no AndroidRuntime (not Android)")
		return
	var rt = Engine.get_singleton("AndroidRuntime")
	var activity = rt.getActivity()
	var intent_class = JavaClassWrapper.wrap("android.content.Intent")
	var uri_class = JavaClassWrapper.wrap("android.net.Uri")
	var intent = intent_class.Intent()
	intent.setAction("android.settings.APPLICATION_DETAILS_SETTINGS")
	intent.setData(uri_class.parse("package:" + str(activity.getPackageName())))
	intent.addFlags(0x10000000)   # FLAG_ACTIVITY_NEW_TASK
	activity.startActivity(intent)
	_log("settings", "opened app settings for %s" % activity.getPackageName())


func _copy_report() -> void:
	var lines := PackedStringArray()
	for k in results:
		lines.append("%s: %s" % [k, results[k]])
	lines.append("feed rot %d°, upright needed extra %d° and mirror=%s" % [
		int(rad_to_deg(feed.feed_transform.get_rotation())) if feed else 0, extra_rot * 90, mirror])
	DisplayServer.clipboard_set("\n".join(lines))
	_log("report", "copied to clipboard (%d lines)" % lines.size())
