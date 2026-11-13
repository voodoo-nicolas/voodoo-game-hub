extends CanvasLayer

## A short cover over the hub while the app starts. Some phones hand the hub a
## window of the wrong shape for the first frames (it starts portrait, then
## unlocks rotation), so the home screen showed up squashed. The cover hides
## that: it stays until the hub's size has stopped changing for SETTLE_SEC and
## the layout was recomputed, then fades out onto the hub. Shown once per app
## start, not on every return from a game.
##
## 2026-11 (hub fixes): the cover now lives on its own CanvasLayer under the
## tree root, so it survives a scene change. That lets it also cover opening a
## game (the game's orientation switch) and coming back to the hub, which the
## old child-of-the-hub cover couldn't: it was freed with the hub and stretched
## with it. It waits for the WINDOW to stop changing (not the hub node), at
## least MIN_SEC, and shows the Viral wordmark breathing over an orbiting ring.

const BrandInfo = preload("res://scripts/common/brand.gd")
const BOOT_META := "viral_hub_booted"
const NODE_NAME := "ViralLoadingCover"
## Set by the hub when it opens a game; the next hub _ready() covers the return.
const FROM_GAME_META := "viral_hub_from_game"
const SETTLE_SEC := 0.45
const MIN_SEC := 0.7
const MAX_SEC := 4.0
const FADE_SEC := 0.3
## Below IntroVideo (layer 100), so the logo video still plays on top when on.
const LAYER := 99

var min_sec := MIN_SEC
var _bg: ColorRect
var _logo: TextureRect
var _ring: Control
var _last_size := Vector2i.ZERO
var _stable := 0.0
var _total := 0.0
var _fading := false

## Adds the cover the first time only (app start). Safe to call from any hub _ready().
static func show_once(hub: Node) -> void:
	if Engine.has_meta(BOOT_META):
		return
	Engine.set_meta(BOOT_META, true)
	cover(hub.get_tree(), MIN_SEC)

## Covers the screen now (game launch, return to the hub). If a cover is already
## up it is kept and restarted, so a launch right after boot doesn't flash.
static func cover(tree: SceneTree, min_seconds: float = MIN_SEC) -> void:
	if tree == null or tree.root == null:
		return
	var old := tree.root.get_node_or_null(NODE_NAME)
	if old != null and not old.is_queued_for_deletion():
		old.call("restart", min_seconds)
		return
	var c = load("res://scripts/hub/boot_cover.gd").new()
	c.min_sec = min_seconds
	c.name = NODE_NAME
	tree.root.add_child.call_deferred(c)

func restart(min_seconds: float) -> void:
	min_sec = maxf(min_seconds, min_sec - _total)
	_total = 0.0
	_stable = 0.0
	_fading = false
	if _bg != null:
		_bg.modulate.a = 1.0

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS  # also covers a paused tree
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.01, 0.03, 1.0)  # the boot splash's colour (project.godot)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	var mist_path: String = BrandInfo.MIST
	if ResourceLoader.exists(mist_path):
		var m = load(mist_path).new()
		if m is Control:
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bg.add_child(m)
			m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	_bg.add_child(_ring)
	var wm: String = BrandInfo.WORDMARK
	if ResourceLoader.exists(wm):
		_logo = TextureRect.new()
		_logo.texture = load(wm)
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg.add_child(_logo)
	_place()

## Logo box: 70% of the short side, centred; recomputed every time the window changes.
func _place() -> void:
	if _logo == null:
		return
	var vs := _bg.size
	var side := minf(vs.x, vs.y) * 0.7
	_logo.size = Vector2(side, side * 0.6)
	_logo.position = (vs - _logo.size) * 0.5
	_logo.pivot_offset = _logo.size * 0.5

## Three neon dots orbiting the logo (green, blue, violet) -- cheap: 3 rects a frame.
func _draw_ring() -> void:
	var vs := _ring.size
	var c := vs * 0.5
	var r := minf(vs.x, vs.y) * 0.38
	var t := Time.get_ticks_msec() / 1000.0
	var cols := [Color(0.25, 1.0, 0.45), Color(0.25, 0.6, 1.0), Color(0.7, 0.35, 1.0)]
	for i in 3:
		for k in 6:  # a short fading tail behind each dot
			var a := t * 2.2 + i * TAU / 3.0 - k * 0.09
			var p := c + Vector2(cos(a), sin(a)) * r
			var s := 16.0 - k * 2.0
			var col: Color = cols[i]
			col.a = 1.0 - k * 0.16
			_ring.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), col)

func _process(delta: float) -> void:
	_ring.queue_redraw()
	if _logo != null:
		var t := Time.get_ticks_msec() / 1000.0
		_logo.scale = Vector2.ONE * (1.0 + 0.03 * sin(t * 2.4))
	if _fading:
		return
	_total += delta
	var s: Vector2i = get_window().size
	if s != _last_size:
		_last_size = s
		_stable = 0.0
		_place()
		var scene := get_tree().current_scene
		# the hub also relayouts on `resized`; this is just a belt-and-braces nudge
		if scene != null and scene.has_method("_apply_home_orientation"):
			scene.call("_apply_home_orientation")
	else:
		_stable += delta
	if (_stable >= SETTLE_SEC and _total >= min_sec) or _total >= MAX_SEC:
		_fading = true
		var tw := create_tween()
		tw.tween_property(_bg, "modulate:a", 0.0, FADE_SEC)
		tw.tween_callback(queue_free)
