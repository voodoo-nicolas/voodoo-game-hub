extends Control

## Turned in the hub: the game's Landing (Landing kit) and the world underneath it.
## Story: docs/turned/story_bible.md, brief: docs/turned/CLAUDE.md, choices: docs/turned/DECISIONS.md.
##
## Same structure as Last Shift: the world (turned_world.gd, a Node2D) runs in its own
## SubViewport under the kit, so its camera and darkness (CanvasModulate) do not tint the Landing
## or the pause menu; the HUD (turned_hud.gd) is a Control over it, inside the safe area. Neither
## is created in _ready(): a world starting underneath the Landing would autosave over the player's
## game. They are made when a mode (or ▶ Resume) is picked.
## Landing -> play: 1 tap (STANDARDS N6). Pause button / Esc / Android back / the app losing focus
## -> the kit's pause menu, which saves (N5).

const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## Home screen + pause menu + look, copied into this game's folder by `hub.py sync`.
const HomeKit = preload("res://scripts/games/turned/home_kit.gd")
const HELP = preload("res://scripts/games/turned/turned_help.gd")
const Save = preload("res://scripts/games/turned/turned_save.gd")
const InputMapper = preload("res://scripts/games/turned/turned_input.gd")
const WorldScript = preload("res://scripts/games/turned/turned_world.gd")
const HudScript = preload("res://scripts/games/turned/turned_hud.gd")
const SceneViewScript = preload("res://scripts/games/turned/turned_scene_view.gd")
const SceneHudScript = preload("res://scripts/games/turned/turned_scene_hud.gd")
## The app's shared on-screen controller; older apps don't have it and Turned keeps its own controls.
const PAD_PATH := "res://scripts/common/pad/pad_controller.gd"
## Layouts that have A, B, a Pause and a Menu button (Turned needs all four).
const PAD_LAYOUTS := ["dpad_4", "stick_4", "dpad_2", "stick_2", "stick_arc"]
## How to Play + stats. Not preloaded: apps before v0.20 don't have it.
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const ACCENT := Color("d9a441")
## Landing background: the mirror moment (the neck), cropped to landscape and mirrored so the marks sit
## right of the kit's text column. The portrait original is `reference/art/games/turned_landing_src.webp`.
const ART := "res://games/turned/landing_bg.jpg"

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var world: Node2D = null
var hud: Control = null
var pad: Control = null
var scene_view: Control = null     # Scene mode: a painting with hotspots (docs/turned/SCENE_MODE_PLAN.md)
var scene_hud: Control = null      # Scene mode's interface (portrait, bars, objectives, day chip, nav strip)
var _holder: Control = null
var _view_box: SubViewportContainer = null
var _view: SubViewport = null
var _kit_was_up := true

func _ready() -> void:
	Orientation.lock_landscape()
	preload("res://scripts/games/turned/turned_i18n.gd").install(self)
	InputMapper.ensure_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS   # _process tells the world when the kit is up
	_build_ui()
	resized.connect(_fit_world)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme(ACCENT)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": ACCENT,
		"subtitle": "A gothic story. 1900.",
		"logo": _draw_home_logo,
		"art": ART,
		"solo_heading": "🦇 Story",
		"modes": [{"text": "🦇 Begin the story", "sub": "Prologue and Day 1", "action": _new_game}],
		"save_path": Save.PATH,
		"resume": _continue_game,
		"restart": _new_game,
		"board": "none",
		# Beginning again deletes the autosave: no ⚡ Quick Play next to ▶ Resume.
		"quick_with_save": false,
	})
	add_child(home)
	if info:
		add_child(info)
	# Must stay the last child so its tab sits above any dialog (the kit frees it).
	add_child(SettingsDrawer.new())

## A moon and a bat in the kit's glow style.
func _draw_home_logo(c: Control) -> void:
	var mid := c.size / 2.0
	var u := minf(c.size.x, c.size.y * 1.6) / 220.0
	HomeKit.glow_circle(c, mid + Vector2(0, -2) * u, 46.0 * u, Color("e8dcc0"), 3.0, 0.1)
	var wing := PackedVector2Array([
		Vector2(0, -8), Vector2(18, -26), Vector2(52, -22), Vector2(44, -10), Vector2(54, 4), Vector2(34, 2),
		Vector2(24, 18), Vector2(12, 4), Vector2(0, 12),
		Vector2(-12, 4), Vector2(-24, 18), Vector2(-34, 2), Vector2(-54, 4), Vector2(-44, -10), Vector2(-52, -22), Vector2(-18, -26)])
	var pts := PackedVector2Array()
	for p in wing:
		pts.append(mid + Vector2(0, 6) * u + p * u * 0.9)
	HomeKit.glow_polyline(c, pts, ACCENT, 3.0, true)

# ---------------------------------------------------------------- starting the world

## ▶ Begin the story (the only place a save is deleted, with ↺ Restart in the pause menu).
func _new_game() -> void:
	_discard_world()
	Save.clear()
	_spawn_world()
	world.begin_new()

## ▶ Resume: the last autosave (leaving the house, the alley, or the last pause).
func _continue_game() -> void:
	_discard_world()
	_spawn_world()
	if not world.resume():
		world.begin_new()

func _spawn_world() -> void:
	_holder = Control.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_holder)
	move_child(_holder, 0)                        # under the kit and GameInfo
	_view_box = SubViewportContainer.new()
	_view_box.stretch = false                     # sized by _fit_world
	_view_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_holder.add_child(_view_box)
	_view = SubViewport.new()
	_view.size_2d_override_stretch = true
	_view.audio_listener_enable_2d = true
	_view_box.add_child(_view)
	hud = HudScript.new()
	add_child(hud)
	move_child(hud, 1)                            # over the world, under the kit
	world = WorldScript.new()
	world.hosted = true
	world.pause_requested.connect(_on_world_pause)
	world.stat_event.connect(_on_stat)
	_view.add_child(world)
	world.attach_hud(hud)
	scene_view = SceneViewScript.new()
	add_child(scene_view)
	world.attach_scene_view(scene_view)
	scene_hud = SceneHudScript.new()
	add_child(scene_hud)
	world.attach_scene_hud(scene_hud)
	_add_pad()
	move_child(scene_view, 1)                     # over the world, under the pad, the HUD and the kit
	move_child(scene_hud, 2)                      # over the painting
	_fit_world()

## The shared Pad under the HUD (so fades and the close-up draw over it), when the app has it.
func _add_pad() -> void:
	if not ResourceLoader.exists(PAD_PATH):
		return
	pad = load(PAD_PATH).new()
	pad.default_layout = "dpad_4"          # D-pad left, A under B, as Turned always was
	pad.allowed_layouts = PAD_LAYOUTS
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pad)
	move_child(pad, 1)                    # over the world, under the HUD and the kit
	hud.use_pad(pad)

## The kit's Options shows the "Controls" section for this.
func _pad() -> Control:
	return pad

## The world's viewport: as big as this Control (canvas units), rendered at the screen's pixel
## density (k pixels per canvas unit) and shown scaled back by 1/k.
func _fit_world() -> void:
	if _view == null or not is_instance_valid(_view):
		return
	var units := size
	if units.x < 2.0 or units.y < 2.0:
		return
	var k := 1.0
	var vis := get_tree().root.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if vis.y > 0.0 and win.y > 0.0:
		k = clampf(win.y / vis.y, 1.0, 4.0)
	_view.size_2d_override = Vector2i(units.round())
	_view.size = Vector2i((units * k).round())
	_view_box.scale = Vector2(1.0 / k, 1.0 / k)
	_view_box.position = Vector2.ZERO
	_view_box.size = units * k
	if world != null and is_instance_valid(world):
		world.set_view_size(units)

## Drops the running world (if any) without saving it: a new game or Resume replaces it.
func _discard_world() -> void:
	if world != null and is_instance_valid(world):
		world.discard = true
	if hud != null and is_instance_valid(hud):
		hud.release_inputs()
		hud.queue_free()
	if pad != null and is_instance_valid(pad):
		pad.queue_free()
	pad = null
	if _holder != null:
		_holder.queue_free()
	if scene_view != null and is_instance_valid(scene_view):
		scene_view.queue_free()
	if scene_hud != null and is_instance_valid(scene_hud):
		scene_hud.queue_free()
	scene_hud = null
	scene_view = null
	_holder = null
	_view_box = null
	_view = null
	world = null
	hud = null

# ---------------------------------------------------------------- the kit around the world

func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var kit_up: bool = home.is_home_visible() or home.pause_overlay.visible or home._any_overlay_open()
	if info != null and "overlay" in info and info.overlay != null and info.overlay.visible:
		kit_up = true
	world.kit_up = kit_up
	if _view != null:                                 # a painting covers the world: do not draw it
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED if world.in_scene else SubViewport.UPDATE_ALWAYS
	if kit_up and not _kit_was_up and hud != null:
		hud.release_inputs()                      # no arrow stays pressed under the pause menu
	_kit_was_up = kit_up

func _notification(what: int) -> void:
	# The window or app lost focus mid-game: the pause menu (it saves too).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if world != null and is_instance_valid(world) and home != null:
			home.pause()

func _on_world_pause() -> void:
	home.pause()

func _on_stat(kind: String) -> void:
	if info == null:
		return
	if kind == "died":
		info.add("Times died")
	elif kind == "clue":
		info.add("Clues found")

## Called by the kit on pause / 🏠 Home / app suspend (STANDARDS N5).
func _save_game() -> void:
	if world != null and is_instance_valid(world):
		world.save_game()
