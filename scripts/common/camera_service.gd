extends Control
class_name CameraService

## Shared live camera for any game pack (first user: Hue Hunt, display name
## "Camera Hunter"). Lives in the APK since app build 65; packs must load it
## guarded:
##     if ResourceLoader.exists("res://scripts/common/camera_service.gd"):
##         cam = load("res://scripts/common/camera_service.gd").new()
## and show "Update app" when it's missing (manifest "min_build": 65).
##
## Godot's own CameraServer (Android Camera2), no native plugin: measured on a
## Galaxy A52 in tools/camera_spike/README.md and live in Trace It. This is a
## copy of trace_it_camera.gd made shared (Trace It keeps its own copy until
## its next update; games never load each other's files).
##
## Lessons from the spike, kept here:
## - Bind the CameraTextures to the material AFTER setting camera_feed_id:
##   a ShaderMaterial stores a texture's RID when the parameter is set, and a
##   CameraTexture without a live feed hands out a placeholder.
## - Upright = the inverse of `feed_transform`'s rotation (+ a mirror for the
##   front camera).
## - Use the first back camera (lowest id); 1280x720 is plenty.
## - In a dark room every camera drops to ~10 fps: `light_changed` tells the
##   game to ask for more light.
## - No focus / white-balance / exposure lock in Godot: colours drift with the
##   light and between phones (a colour game must allow for it).
## - Android pauses and resumes the camera with the app by itself.
##
## API (bump API_VERSION when it grows; packs can check it):
##   start() / stop() / request_permission() / next_camera()
##   state + state_changed: starting, running, stopped, no_camera, need_permission, denied
##   snapshot() -> Image (await it): upright RGB frame, for a frozen photo
##   static patch(img, at, half) -> Array[Color] around a pixel
##   static thumbnail_jpg(img, max_side, quality) -> PackedByteArray
##   static open_app_settings()

signal state_changed(state: String)
signal light_changed(dark: bool)

const API_VERSION := 1
const TARGET := Vector2i(1280, 720)
const PERMISSION := "android.permission.CAMERA"
const DARK_LUMA := 55.0
const SLOW_FPS := 14.0

## YUV (BT.601 full range) or RGB feed -> upright RGB, with a basis for the
## feed rotation. Same as Trace It's FX.CAMERA.
const SHADER := """
shader_type canvas_item;
uniform sampler2D y_tex : filter_linear;
uniform sampler2D c_tex : filter_linear;
uniform bool rgb_mode = false;
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
		COLOR = vec4(y + 1.402 * c.y, y - 0.344136 * c.x - 0.714136 * c.y, y + 1.772 * c.x, 1.0);
	}
}
"""

var choice := 0   # index into cameras() (backs by id, then fronts)
var state := ""
var dark := false
var feed: CameraFeed = null
var fmt := Vector2i.ZERO
var _y := CameraTexture.new()
var _c := CameraTexture.new()
var _view: ColorRect
var _mat: ShaderMaterial
var _frames: Array = []   # usec of recent frames
var _running_since := 0
var _check_t := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = ColorRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_view.material = _mat
	_view.visible = false
	add_child(_view)
	resized.connect(_layout)


func _exit_tree() -> void:
	stop()


func _notification(what: int) -> void:
	# Back from the system settings with the permission now on.
	if what == NOTIFICATION_APPLICATION_RESUMED and state in ["need_permission", "denied"] and granted():
		start()


static func granted() -> bool:
	return OS.get_name() != "Android" or OS.get_granted_permissions().has(PERMISSION)


func start() -> void:
	if not granted():
		_set_state("need_permission")
		return
	_set_state("starting")
	if not CameraServer.camera_feeds_updated.is_connected(_pick_feed):
		CameraServer.camera_feeds_updated.connect(_pick_feed)
	if not CameraServer.monitoring_feeds:
		CameraServer.monitoring_feeds = true   # Android lists the feeds right away
	_pick_feed()


func stop() -> void:
	if feed:
		if feed.frame_changed.is_connected(_on_frame):
			feed.frame_changed.disconnect(_on_frame)
			feed.format_changed.disconnect(_on_format_changed)
		feed.feed_is_active = false
		feed = null
	if CameraServer.camera_feeds_updated.is_connected(_pick_feed):
		CameraServer.camera_feeds_updated.disconnect(_pick_feed)
	if CameraServer.monitoring_feeds:
		CameraServer.monitoring_feeds = false
	if _view:
		_view.visible = false
	# Not "running" any more: callers that check state restart the camera
	# (0.45.0 left it "running" and the next snapshot came from a dead feed).
	_set_state("stopped")


func request_permission() -> void:
	if not get_tree().on_request_permissions_result.is_connected(_on_permission):
		get_tree().on_request_permissions_result.connect(_on_permission)
	OS.request_permission("CAMERA")


func _on_permission(permission: String, ok: bool) -> void:
	if not permission.ends_with("CAMERA"):
		return
	if ok:
		start()
	else:
		_set_state("denied")


## Android's settings page for this app (to switch the camera on after
## "Don't allow"). Needs the AndroidRuntime plugin (Godot 4.4+).
static func open_app_settings() -> bool:
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	var rt = Engine.get_singleton("AndroidRuntime")
	var activity = rt.getActivity()
	var intent = JavaClassWrapper.wrap("android.content.Intent").Intent()
	intent.setAction("android.settings.APPLICATION_DETAILS_SETTINGS")
	intent.setData(JavaClassWrapper.wrap("android.net.Uri").parse("package:" + str(activity.getPackageName())))
	intent.addFlags(0x10000000)   # FLAG_ACTIVITY_NEW_TASK
	activity.startActivity(intent)
	return true


static func _cam_key(f: CameraFeed) -> int:
	var cam_id := str(f.get_name()).get_slice("|", 0).strip_edges()
	var n := int(cam_id) if cam_id.is_valid_int() else 1000 + f.get_id()
	return n + (0 if f.get_position() != CameraFeed.FEED_FRONT else 100000)


static func _cam_less(a: CameraFeed, b: CameraFeed) -> bool:
	return _cam_key(a) < _cam_key(b)


## Every camera, back ones first in id order (Android names feeds
## "<camera id> | BACK"; the lowest id is the main camera), then front ones.
static func cameras() -> Array:
	var list := CameraServer.feeds()
	list.sort_custom(_cam_less)
	return list


func camera_count() -> int:
	return cameras().size()


## The next camera (wraps around); the game remembers `choice`.
func next_camera() -> void:
	var n := camera_count()
	if n < 2:
		return
	choice = (choice + 1) % n
	if state == "running" or state == "starting":
		_pick_feed(true)


func _pick_feed(force: bool = false) -> void:
	var list := cameras()
	if list.is_empty():
		_set_state("no_camera")
		return
	if choice < 0 or choice >= list.size():
		choice = 0
	var best: CameraFeed = list[choice]
	if best == feed and not force:
		return
	_open(best)


func _open(f: CameraFeed) -> void:
	if feed:
		feed.feed_is_active = false
		if feed.frame_changed.is_connected(_on_frame):
			feed.frame_changed.disconnect(_on_frame)
			feed.format_changed.disconnect(_on_format_changed)
	feed = f
	var formats: Array = f.get_formats()
	var pick := -1
	var cost := 1 << 40
	for i in formats.size():
		var d: Dictionary = formats[i]
		if OS.get_name() == "Android" and not str(d.get("format", "")).contains("YUV"):
			continue
		var c: int = absi(int(d.get("width", 0)) - TARGET.x) + absi(int(d.get("height", 0)) - TARGET.y)
		if c < cost:
			cost = c
			pick = i
	if pick >= 0:
		f.set_format(pick, {})
		var d: Dictionary = formats[pick]
		fmt = Vector2i(int(d.get("width", 0)), int(d.get("height", 0)))
	_y.camera_feed_id = f.get_id()
	_y.which_feed = CameraServer.FEED_Y_IMAGE
	_c.camera_feed_id = f.get_id()
	_c.which_feed = CameraServer.FEED_CBCR_IMAGE
	_frames.clear()
	_running_since = 0
	f.frame_changed.connect(_on_frame)
	f.format_changed.connect(_on_format_changed)
	f.feed_is_active = true
	if not f.feed_is_active:
		_set_state("no_camera")
		return
	_bind()
	_layout()
	_set_state("starting")


func _bind() -> void:
	_mat.set_shader_parameter("y_tex", _y)
	_mat.set_shader_parameter("c_tex", _c)


func _on_format_changed() -> void:
	_bind()
	_layout()


func _on_frame() -> void:
	if feed == null:
		return
	var now := Time.get_ticks_usec()
	_frames.append(now)
	while _frames.size() > 2 and now - int(_frames[0]) > 3_000_000:
		_frames.pop_front()
	if state != "running":
		_mat.set_shader_parameter("rgb_mode", feed.get_datatype() == CameraFeed.FEED_RGB)
		if fmt == Vector2i.ZERO:
			fmt = Vector2i(_y.get_size())
			_layout()
		_view.visible = true
		_running_since = now
		_set_state("running")


func _set_state(s: String) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)


func _basis() -> Transform2D:
	if feed == null:
		return Transform2D.IDENTITY
	var t: Transform2D = feed.feed_transform
	var b := Transform2D(t.x, t.y, Vector2.ZERO).affine_inverse()
	if feed.get_position() == CameraFeed.FEED_FRONT:
		b = b * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO)
	return b


func _layout() -> void:
	if _view == null or fmt == Vector2i.ZERO:
		return
	var b := _basis()
	_mat.set_shader_parameter("bx", b.x)
	_mat.set_shader_parameter("by", b.y)
	var pic := Vector2(fmt)
	if absf(b.x.y) > 0.5:   # a quarter turn: the picture stands up
		pic = Vector2(pic.y, pic.x)
	var k := maxf(size.x / pic.x, size.y / pic.y)
	_view.size = pic * k
	_view.position = (size - _view.size) / 2.0


## Where the picture sits in this Control (cover fit: it can overflow).
func view_rect() -> Rect2:
	return Rect2(_view.position, _view.size) if _view else Rect2()


## A point in this Control -> pixel in a snapshot() image of size `img_size`.
func to_image_px(local: Vector2, img_size: Vector2i) -> Vector2i:
	var r := view_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return Vector2i(-1, -1)
	var uv := (local - r.position) / r.size
	return Vector2i(int(uv.x * img_size.x), int(uv.y * img_size.y))


func fps() -> float:
	if _frames.size() < 3:
		return 0.0
	return (_frames.size() - 1) / ((int(_frames[-1]) - int(_frames[0])) / 1e6)


func _process(delta: float) -> void:
	if state != "running":
		return
	_check_t += delta
	if _check_t < 1.5:
		return
	_check_t = 0.0
	var luma := mean_luma()
	var f := fps()
	var settled := Time.get_ticks_usec() - _running_since > 3_000_000
	var too_dark := luma >= 0 and luma < DARK_LUMA
	var too_slow := settled and f > 0 and f < SLOW_FPS
	var bright := (luma < 0 or luma > DARK_LUMA + 15) and (f == 0 or f >= SLOW_FPS + 4)
	var now_dark := dark
	if not dark and (too_dark or too_slow):
		now_dark = true
	elif dark and bright:
		now_dark = false
	if now_dark != dark:
		dark = now_dark
		light_changed.emit(dark)


## Average brightness (0-255) of the middle of the picture, from the Y plane.
func mean_luma() -> float:
	if feed == null or not feed.feed_is_active or feed.get_datatype() == CameraFeed.FEED_RGB:
		return -1.0
	var img: Image = _y.get_image()
	if img == null or img.is_empty():
		return -1.0
	var w := img.get_width()
	var h := img.get_height()
	var r := img.get_region(Rect2i(w / 2 - 64, h / 2 - 64, 128, 128))
	var data := r.get_data()
	var sum := 0
	var n := 0
	for i in range(0, data.size(), 8):
		sum += data[i]
		n += 1
	return float(sum) / maxi(n, 1)


## The camera picture as an upright RGB Image (a frozen photo). Renders the
## camera shader into an offscreen viewport for two frames. Await it.
func snapshot() -> Image:
	if state != "running":
		return null
	var b := _basis()
	var s := Vector2(fmt)
	if absf(b.x.y) > 0.5:
		s = Vector2(s.y, s.x)
	var vp := SubViewport.new()
	vp.size = Vector2i(s)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var r := ColorRect.new()
	r.material = _mat
	r.size = s
	vp.add_child(r)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


## The pixels of a (2*half+1)^2 square around `at`, clipped to the image.
static func patch(img: Image, at: Vector2i, half: int = 7) -> Array[Color]:
	var out: Array[Color] = []
	if img == null or img.is_empty():
		return out
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, at.y - half), mini(h, at.y + half + 1)):
		for x in range(maxi(0, at.x - half), mini(w, at.x + half + 1)):
			out.append(img.get_pixel(x, y))
	return out


## A small JPEG (longest side `max_side`) for sending a thumbnail. Never
## written to disk.
static func thumbnail_jpg(img: Image, max_side: int = 128, quality: float = 0.7) -> PackedByteArray:
	if img == null or img.is_empty():
		return PackedByteArray()
	var t := img.duplicate() as Image
	var k := float(max_side) / maxi(t.get_width(), t.get_height())
	if k < 1.0:
		t.resize(maxi(1, int(t.get_width() * k)), maxi(1, int(t.get_height() * k)), Image.INTERPOLATE_BILINEAR)
	if t.get_format() != Image.FORMAT_RGB8:
		t.convert(Image.FORMAT_RGB8)
	return t.save_jpg_to_buffer(quality)
