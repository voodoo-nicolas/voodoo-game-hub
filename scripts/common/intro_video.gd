class_name IntroVideo
extends CanvasLayer

## The short Viral brand video shown when a game is opened from the hub
## (`hub.gd` `_launch`). APK-side only: games never reference it and their packs
## carry no video. Plays over the game's scene while it loads, so it adds no wait;
## the game's Landing is underneath when it ends.
## - Two Theora files in `res://media/hub/intro/`: portrait (9:16) and landscape
##   (16:9); picked from the window shape (re-picked in the first moments, since a
##   game locks its own orientation just after it opens). No audio track.
## - Tap anywhere to skip. Off with Options > "🎬 Intro video" (`Settings.intro_video`),
##   and never shown under "Reduce motion" or in the web build (single thread).
## - Source clips: media/CREDITS.json ("Viral intro video").
## Use: `IntroVideo.play(get_tree())` right after changing scene; it adds itself
## to the root, so it survives the scene change.

const PORTRAIT := "res://media/hub/intro/intro_portrait.ogv"
const LANDSCAPE := "res://media/hub/intro/intro_landscape.ogv"
const PORTRAIT_ASPECT := 540.0 / 960.0
const LANDSCAPE_ASPECT := 960.0 / 540.0
const BG := Color(0.02, 0.01, 0.05)
const MAX_SECONDS := 6.0     # safety net: never leave the overlay up
const REPICK_SECONDS := 0.8  # window may still be rotating to the game's orientation

var _player: VideoStreamPlayer
var _portrait: bool
var _elapsed := 0.0
var _done := false

## Returns true when it started playing.
static func play(tree: SceneTree) -> bool:
	if tree == null or OS.has_feature("web") or _is_off(tree):
		return false
	if not (ResourceLoader.exists(PORTRAIT) and ResourceLoader.exists(LANDSCAPE)):
		return false
	var overlay := IntroVideo.new()
	tree.root.add_child(overlay)
	return true

static func _is_off(tree: SceneTree) -> bool:
	var settings := tree.root.get_node_or_null("Settings")
	if settings == null:
		return false
	return not bool(settings.get("intro_video")) or bool(settings.get("reduce_motion"))

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # the Landing pauses the tree
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_input)
	add_child(bg)
	_player = VideoStreamPlayer.new()
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_finish)
	add_child(_player)
	_start(_window_is_portrait())

func _window_is_portrait() -> bool:
	var size := get_viewport().get_visible_rect().size
	return size.y >= size.x

func _start(portrait: bool) -> void:
	_portrait = portrait
	_player.stream = load(PORTRAIT if portrait else LANDSCAPE)
	_layout()
	_player.play()

## Fit the video inside the window, keeping its shape (bars are the same dark as the clip).
func _layout() -> void:
	var win := get_viewport().get_visible_rect().size
	var aspect := PORTRAIT_ASPECT if _portrait else LANDSCAPE_ASPECT
	var size := Vector2(win.x, win.x / aspect)
	if size.y > win.y:
		size = Vector2(win.y * aspect, win.y)
	_player.size = size
	_player.position = (win - size) / 2.0

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < REPICK_SECONDS and _window_is_portrait() != _portrait:
		_start(not _portrait)
	else:
		_layout()
	if _elapsed > MAX_SECONDS:
		_finish()

func _on_input(event: InputEvent) -> void:
	# Phones send a tap as touch + emulated mouse (mouse first): MouseButton only.
	if event is InputEventMouseButton and event.pressed:
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	_player.stop()
	queue_free()
