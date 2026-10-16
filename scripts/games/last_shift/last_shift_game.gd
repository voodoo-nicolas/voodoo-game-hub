extends Control

## Last Shift in the hub: the game's Landing page (Landing kit), and the world underneath it.
##
## The game itself (last_shift_world.gd, a Node2D with its own HUD on CanvasLayers) was built as a
## standalone prototype (D:\Dev\claudius_prequel, v0.5) with its own start page. In the hub that
## page is the Landing kit (STANDARDS §3): ▶ Resume (room checkpoint), ⚡ Quick Play, Easy / Normal /
## Hard, ❓ How to Play, 🏆, 🏅, 📊, ⚙ Options, ← Hub. The prototype's own Options (language, music
## and sound volume, vibration, screen shake) are the hub's app-wide Settings here (STANDARDS §7):
## screen shake follows the app's "Reduce motion".
##
## The world is only created once a mode (or Resume) is picked, never in _ready(): a world starting
## underneath the Landing would save over the checkpoint (it saves on every room it enters).
##
## The world runs in its own SubViewport, under the kit: its Camera2D (zoom 2.25) and its darkness
## (CanvasModulate) would otherwise move, zoom and tint the Landing and the pause menu too, and its
## HUD CanvasLayers would draw over them. The SubViewport fills this Control (so it sits inside the
## safe area) and renders at the screen's real resolution: its 2D size is the Control's size in
## canvas units (what the prototype's layout expects, ~1280x720 or less), stretched over a texture
## as many pixels wide as the screen (_fit_world).

const LsSave = preload("res://scripts/games/last_shift/last_shift_save.gd")
const LsStats = preload("res://scripts/games/last_shift/last_shift_stats.gd")
const LsSettings = preload("res://scripts/games/last_shift/last_shift_settings.gd")
const LsText = preload("res://scripts/games/last_shift/last_shift_text.gd")
const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")
const Orientation = preload("res://scripts/common/orientation.gd")
const SettingsDrawer = preload("res://scripts/common/settings_drawer.gd")
## Home screen + pause menu + neon look, copied into this game's folder by
## `hub.py sync` (CLAUDE.md "Home screen kit").
const HomeKit = preload("res://scripts/games/last_shift/home_kit.gd")
const HELP = preload("res://scripts/games/last_shift/last_shift_help.gd")
## How to Play + stats. Not preloaded: apps before v0.20 don't have it,
## and the game must still run there (without the ? button).
const GAME_INFO_PATH := "res://scripts/common/game_info.gd"
const WORLD_SCENE := "res://scenes/games/last_shift/world.tscn"
const ART := "res://games/last_shift/landing_bg.jpg"
const DIFF_KEYS := ["diff_easy", "diff_normal", "diff_hard"]

## The prototype's start-page orange (warm, fire-lit): the kit tints the title with it.
const ACCENT := Color("e09a1a")
## The world's HUD was laid out for a 720-unit-high screen. The app's text size shrinks the canvas
## (Large: 600, Extra large: ~514 units high); below 600 the D-pad, the subtitle and the A button
## overlap, so the world's view never gets shorter than this: at Extra large its HUD stays at the
## Large size (the Landing and menus still follow the app's text size).
const MIN_VIEW_HEIGHT := 600.0

var info = null  # GameInfo; null on apps without it, so guard every use
var home  # HomeKit
var world: Node2D = null
var _holder: Control = null                  # plain Control: its children's size never counts
var _view_box: SubViewportContainer = null   # for Settings' fit-to-screen measuring
var _view: SubViewport = null

func _ready() -> void:
	Orientation.lock_landscape()
	preload("res://scripts/games/last_shift/last_shift_i18n.gd").install(self)
	process_mode = Node.PROCESS_MODE_ALWAYS   # _process tells the world when the kit is up
	_build_ui()
	resized.connect(_fit_world)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HomeKit.neon_theme(ACCENT)
	if ResourceLoader.exists(GAME_INFO_PATH):
		info = load(GAME_INFO_PATH).new(HELP)
	LsStats.info = info
	var modes: Array = []
	for i in 3:
		modes.append({"text": ["🙂 Easy", "😐 Normal", "😈 Hard"][i], "row": "diff", "key": DIFF_KEYS[i],
			"action": _new_game.bind(i)})
	home = HomeKit.new({
		"help": HELP,
		"info": info,
		"accent": ACCENT,
		"solo_heading": "🌙 New night",
		"subtitle": "A night-shift story",
		# No "logo": the kit already prints the title (help TITLE, translated) over the key art.
		"art": ART,
		"modes": modes,
		"save_path": LsSave.PATH,
		"resume": _continue_game,
		"resume_text": _resume_text,
		"restart": _restart,
		"board": "Most infected in one night",
		# The key art stays visible: a small column on the left, More folded behind ☰ (owner,
		# 2026-10-14: "keep those menu options small, or in trees").
		"compact": true,
		# A new night deletes the checkpoint: no ⚡ Quick Play next to ▶ Resume.
		"quick_with_save": false,
	})
	add_child(home)
	if info:
		add_child(info)
	# Must stay the last child so its tab sits above any dialog (the kit frees it).
	add_child(SettingsDrawer.new())

## "Normal · 12:40" under ▶ Resume: the saved night's difficulty and time.
func _resume_text() -> String:
	var d := LsSave.read()
	if d.is_empty():
		return ""
	var st: Dictionary = d.state
	return tr(LsText.UI[DIFF_KEYS[clampi(int(st.get("difficulty", 1)), 0, 2)]]) + "   ·   " \
		+ LsEngine.format_time(float(st.get("play_time", 0.0)))

# ---------------------------------------------------------------- starting the world

## Easy / Normal / Hard on the Landing: a new night (the only place a save is deleted, with ↺ Restart).
func _new_game(difficulty: int) -> void:
	_discard_world()
	LsSave.clear()
	LsSave.continue_requested = false
	LsSave.new_difficulty = difficulty
	LsSettings.set_value("difficulty", difficulty)
	_spawn_world()

## ▶ Resume: the last room checkpoint.
func _continue_game() -> void:
	_discard_world()
	LsSave.continue_requested = true
	_spawn_world()

## ↺ Restart (pause menu): the same difficulty, from the parking lot.
func _restart() -> void:
	var diff := LsSettings.difficulty()
	if world != null and is_instance_valid(world):
		diff = int(world.state.difficulty)
	_new_game(diff)

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
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST  # prototype default
	_view.audio_listener_enable_2d = true
	_view_box.add_child(_view)
	_fit_world()
	world = load(WORLD_SCENE).instantiate()
	world.hosted = true
	world.pause_requested.connect(_on_world_pause)
	world.menu_requested.connect(_on_world_menu)
	_view.add_child(world)

## The world's viewport: as big as this Control (canvas units = its 2D coordinates; at least
## MIN_VIEW_HEIGHT high), rendered at the screen's pixel density (k pixels per canvas unit) and
## shown scaled back by 1/k.
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
	var view := units
	if view.y < MIN_VIEW_HEIGHT:
		view *= MIN_VIEW_HEIGHT / view.y
	_view.size_2d_override = Vector2i(view.round())
	_view.size = Vector2i((units * k).round())
	_view_box.scale = Vector2(1.0 / k, 1.0 / k)
	_view_box.position = Vector2.ZERO
	_view_box.size = units * k

## Drops the running world (if any) without saving it: a new night or Resume replaces it.
func _discard_world() -> void:
	if world != null and is_instance_valid(world):
		world.discard = true      # its _exit_tree / app-suspend must not write the old night back
	if _holder != null:
		_holder.queue_free()
	_holder = null
	_view_box = null
	_view = null
	world = null

# ---------------------------------------------------------------- the kit around the world

func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var kit_up: bool = home.is_home_visible() or home.pause_overlay.visible or home._any_overlay_open()
	if info != null and "overlay" in info and info.overlay != null and info.overlay.visible:
		kit_up = true
	world.kit_up = kit_up

## The world's ⏸ button / Esc: the kit's pause menu (Resume / Restart / How to Play / ... / 🏠 Home).
func _on_world_pause() -> void:
	home.pause()

## The end card's "Back to menu": this game's Landing (STANDARDS N2).
func _on_world_menu() -> void:
	home.go_home()

## Called by the kit on pause / 🏠 Home / app suspend (STANDARDS N5): the room checkpoint.
func _save_game() -> void:
	if world != null and is_instance_valid(world):
		world._save_game()
