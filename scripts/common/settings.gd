extends Node

## Autoload `Settings`: the app-wide options from the hub's ⚙ Options screen,
## saved in `user://settings.json` and applied the moment they change.
##
## - text_size: scales EVERYTHING drawn (text, buttons, boards) through the
##   root window's content_scale_factor -- one setting that reaches every
##   game, including packs that predate it, with no game code involved.
##   Many games have fixed-size parts (keyboards, card rows) laid out for the
##   720-wide design, so each new screen is measured (`_fit_scene`) and the
##   scale backed off just enough for its layout to fit -- never below 1.0,
##   the original look. A game that fits gets the full size.
## - theme: "dark" / "light" for the hub and Options screen (`palette()`).
##   Games keep their own colors.
## - sound: "Mute all" -- mutes the Master bus, so every sound obeys it.
## - volume: overall loudness 0..100 (the Master bus volume).
## - sound groups (SOUND_GROUPS): each kind of sound has its own on/off and
##   volume 0..100 -- `group_on(id)`, `group_volume(id)`; Sfx asks
##   `group_db(id)` before playing (null = that group is off).
## - vibrate: `buzz()` -- every button press gives a short tick (hooked up
##   here, app-wide), and GameInfo buzzes on wins and losses.
## - keep_awake: stops the screen dimming/locking while the app is open.
## - invites (since v0.25): when friends' game invites pop up -- INVITE_MODES
##   "all", "hub" (not while playing a game) or "off". Social asks
##   `invites_allowed()`.
## Skull mode (Voodoo) keeps its own file -- see voodoo.gd.
##
## Also app-wide, with no game code:
## - Safe area: every screen's root Control is inset from the phone's camera
##   cutout (`_apply_safe_area`), so titles aren't hidden under it.
## - Resume: when the app goes to the background inside a game, that game is
##   remembered in `user://resume.json`; if Android then kills the app, the
##   hub reopens the game on the next launch (`take_resume_scene`). Games
##   that save their state (`_save_game`) pick up where they were.
##
## Games must not reference `Settings` directly (packs also run on apps
## without it): `var s = get_node_or_null("/root/Settings")`, then `if s:`.

const PATH := "user://settings.json"

## content_scale_factor per text size. 1.0 is the original look; players
## worldwide found it too small, so new installs start at Large.
const TEXT_SCALES := [1.0, 1.2, 1.4]
const TEXT_SIZE_NAMES := ["Normal", "Large", "Extra large"]
const DEFAULT_TEXT_SIZE := 1

const DEFAULT_VOLUME := 80
## The kinds of sound players can turn on/off and set the volume of, each
## [id, title, hint]. Which sound is in which group is Sfx.GROUP_OF.
const SOUND_GROUPS := [
	["taps", "👆 Taps & keys", "Button taps and keyboard clicks."],
	["game", "🎲 Game sounds", "Cards, dice, pieces, arcade action."],
	["results", "🏆 Wins & losses", "The fanfare at the end of a game."],
	["alerts", "🔔 Notifications", "Your-turn chimes and warning buzzes."],
]

## Friend invite pop-ups (Minigame standard: "block notifications").
const INVITE_MODES := ["all", "hub", "off"]
const INVITE_MODE_NAMES := ["Always", "Not during games", "Off"]

const TAP_BUZZ_MS := 12
const RESULT_BUZZ_MS := 70

const RESUME_PATH := "user://resume.json"
## A game left in the background longer than this opens on the hub instead.
const RESUME_MAX_AGE_SEC := 12 * 3600
const GAMES_DIR := "res://scenes/games/"
## Space kept clear at the top of portrait screens on phones that report no
## cutout, so a title never sits flush against the camera / status area.
const MIN_TOP_INSET := 24.0

signal changed

## Set once the hub has had its chance to reopen a game after a restart.
var resume_checked: bool = false

var text_size: int = DEFAULT_TEXT_SIZE
var theme: String = "dark"
var sound: bool = true
var volume: int = DEFAULT_VOLUME
## group id -> {"on": bool, "vol": int}; filled from SOUND_GROUPS by _load().
var sound_groups: Dictionary = {}
var vibrate: bool = true
var keep_awake: bool = false
var invites: String = "all"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The PC window title shows the brand. project.godot's config/name stays
	# "Voodoo": on PC it names the save folder (CLAUDE.md "Rename safety").
	DisplayServer.window_set_title(preload("res://scripts/common/brand.gd").NAME)
	_load()
	_apply()
	# Every button, in every scene (packs included), ticks when pressed.
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_fit_scene)
	get_tree().scene_changed.connect(_on_scene_changed)
	# A rotation changes which way is "landscape": rescale and re-inset.
	get_tree().root.size_changed.connect(_on_root_resized)

## Only a real window change (rotation) refits. The root also reports
## size_changed when _fit_scene itself changes the content scale, and
## refitting on that would loop forever.
var _last_window := Vector2i.ZERO

func _on_root_resized() -> void:
	var win := DisplayServer.window_get_size()
	if win == _last_window:
		return
	_last_window = win
	_fit_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_remember_scene()

func set_text_size(i: int) -> void:
	text_size = clampi(i, 0, TEXT_SCALES.size() - 1)
	_commit()

func set_theme(t: String) -> void:
	theme = "light" if t == "light" else "dark"
	_commit()

func set_sound(on: bool) -> void:
	sound = on
	_commit()

## `save` = false while a slider is being dragged: applied live, written once
## on release.
func set_volume(v: int, save: bool = true) -> void:
	volume = clampi(v, 0, 100)
	_apply_audio()
	if save:
		_save()

func group_on(id: String) -> bool:
	return bool(sound_groups.get(id, {}).get("on", true))

func group_volume(id: String) -> int:
	return int(sound_groups.get(id, {}).get("vol", 100))

func set_group_on(id: String, on: bool) -> void:
	if sound_groups.has(id):
		sound_groups[id]["on"] = on
		_save()

func set_group_volume(id: String, v: int, save: bool = true) -> void:
	if sound_groups.has(id):
		sound_groups[id]["vol"] = clampi(v, 0, 100)
		if save:
			_save()

## Extra volume (dB) for a sound in this group, or null if it shouldn't play.
func group_db(id: String) -> Variant:
	var v := group_volume(id)
	if not group_on(id) or v <= 0:
		return null
	return linear_to_db(v / 100.0)

func set_vibrate(on: bool) -> void:
	vibrate = on
	_commit()
	buzz(RESULT_BUZZ_MS)  # so turning it on shows what it does

func set_keep_awake(on: bool) -> void:
	keep_awake = on
	_commit()

func set_invites(mode: String) -> void:
	invites = mode if INVITE_MODES.has(mode) else "all"
	_commit()

## May a friend's invite pop up right now?
func invites_allowed() -> bool:
	if invites == "off":
		return false
	if invites == "hub" and is_inside_tree() and get_tree().current_scene and _is_game_scene(get_tree().current_scene.scene_file_path):
		return false
	return true

func buzz(ms: int = TAP_BUZZ_MS) -> void:
	if vibrate:
		Input.vibrate_handheld(ms)

func is_light() -> bool:
	return theme == "light"

## Colors for the hub and Options screen in the current theme.
func palette() -> Dictionary:
	return LIGHT if is_light() else DARK

## The dark theme follows the VOODOO banner art: violet and electric-blue
## smoke, fiery orange lettering, near-black. Fills are see-through so the
## hub's drifting mist shows behind the panels.
const DARK := {
	"bg": Color(0.025, 0.008, 0.05),
	"text": Color(1, 1, 1),
	"text_dim": Color(0.78, 0.7, 0.88),
	"accent": Color(1.0, 0.6, 0.22),         # fiery orange: titles, dialogs, "on"
	"accent_fill": Color(0.5, 0.2, 0.06, 0.85),
	"link": Color(0.8, 0.45, 1.0),           # violet neon: headers, links
	"link_dim": Color(0.42, 0.2, 0.62),
	"ready": Color(0.25, 1.0, 0.6),
	"download": Color(0.36, 0.55, 0.9),
	"soon": Color(0.5, 0.46, 0.56),
	"update": Color(1.0, 0.78, 0.25),
	"header_fill": Color(0.07, 0.02, 0.13, 0.78),
	"header_open_text": Color(1, 1, 1),
	"count": Color(0.75, 0.6, 0.95),
	"count_open": Color(1.0, 0.92, 1.0),
	"soon_fill": Color(0.06, 0.04, 0.08, 0.8),
	"soon_border": Color(0.3, 0.26, 0.36),
	"soon_text": Color(0.55, 0.5, 0.6),
	"version": Color(0.7, 0.58, 0.85),
	"account": Color(0.92, 0.8, 1.0),
	"card_fill": Color(0.08, 0.03, 0.14, 0.92),
	"card_message": Color(0.92, 0.88, 0.97),
	"off_fill": Color(0.14, 0.1, 0.19, 0.9),
	"off_border": Color(0.38, 0.3, 0.48),
	"overlay": Color(0, 0, 0, 0.8),
	"glow": 1.0,
}

const LIGHT := {
	"bg": Color(0.94, 0.95, 0.94),
	"text": Color(0.08, 0.1, 0.12),
	"text_dim": Color(0.35, 0.4, 0.42),
	"accent": Color(0.0, 0.5, 0.27),
	"accent_fill": Color(0.75, 0.93, 0.83),
	"link": Color(0.03, 0.36, 0.75),
	"link_dim": Color(0.62, 0.74, 0.86),
	"ready": Color(0.0, 0.55, 0.3),
	"download": Color(0.25, 0.42, 0.7),
	"soon": Color(0.55, 0.58, 0.6),
	"update": Color(0.72, 0.45, 0.0),
	"header_fill": Color(1, 1, 1),
	"header_open_text": Color(0.02, 0.15, 0.35),
	"count": Color(0.3, 0.45, 0.6),
	"count_open": Color(0.05, 0.2, 0.4),
	"soon_fill": Color(0.9, 0.9, 0.9),
	"soon_border": Color(0.75, 0.77, 0.78),
	"soon_text": Color(0.5, 0.52, 0.53),
	"version": Color(0.3, 0.45, 0.38),
	"account": Color(0.1, 0.4, 0.25),
	"card_fill": Color(1, 1, 1),
	"card_message": Color(0.2, 0.25, 0.22),
	"off_fill": Color(0.88, 0.89, 0.9),
	"off_border": Color(0.65, 0.67, 0.7),
	"overlay": Color(0, 0, 0, 0.45),
	"glow": 0.35,
}

# ---------- internals ----------

func _commit() -> void:
	_save()
	_apply()
	changed.emit()

func _apply() -> void:
	_fit_scene()
	_apply_audio()
	DisplayServer.screen_set_keep_on(keep_awake)

func _apply_audio() -> void:
	AudioServer.set_bus_mute(0, not sound or volume <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 1) / 100.0))

## Starts each screen at the chosen size, then -- once its layout has
## settled -- shrinks the scale just enough that the screen's content fits
## the window, if it doesn't already.
func _fit_scene() -> void:
	if not is_inside_tree():
		return
	var root := get_tree().root
	var wanted: float = TEXT_SCALES[text_size] * _landscape_boost()
	root.content_scale_factor = wanted
	_apply_safe_area()
	if wanted <= 1.0:
		return
	var scene := get_tree().current_scene
	for i in 2:
		await get_tree().process_frame
	if not is_instance_valid(scene) or scene != get_tree().current_scene:
		return
	var m := safe_margins()
	var view: Vector2 = root.get_visible_rect().size - Vector2(m[0] + m[2], m[1] + m[3])
	var need := Vector2.ZERO
	for c in scene.get_children():
		if c is Control and c.visible:
			need = need.max(c.get_combined_minimum_size())
	var fit := 1.0
	if need.x > view.x:
		fit = minf(fit, view.x / need.x)
	if need.y > view.y:
		fit = minf(fit, view.y / need.y)
	if fit < 1.0:
		root.content_scale_factor = maxf(1.0, wanted * fit * 0.99)
		_apply_safe_area()  # margins are in canvas units, which just changed

## The design is 720 wide x 1280 tall, and "expand" stretch keeps the 1280
## when the phone turns sideways -- so a landscape screen got a 1280-tall
## canvas and everything drawn on it shrank to ~56% (Geometry Wars' Pause
## button was barely visible). Turned sideways, scale up by 1280/720 so the
## short side is 720 units again, like portrait.
func _landscape_boost() -> float:
	var win := Vector2(DisplayServer.window_get_size())
	if win.y <= 0.0 or win.x <= win.y:
		return 1.0
	var w := float(ProjectSettings.get_setting("display/window/size/viewport_width", 720))
	var h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1280))
	return maxf(1.0, h / w)

## [left, top, right, bottom] the screen's cutouts cover, in canvas units.
## Zero on desktop. VOODOO_SAFE_INSET="l,t,r,b" fakes it for PC testing.
func safe_margins() -> Array:
	var fake := OS.get_environment("VOODOO_SAFE_INSET")
	if fake != "":
		var p := fake.split(",")
		if p.size() == 4:
			return [float(p[0]), float(p[1]), float(p[2]), float(p[3])]
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return [0.0, 0.0, 0.0, 0.0]
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k: float = get_tree().root.get_visible_rect().size.y / win.y
	var m := [
		maxf(safe.position.x, 0.0) * k,
		maxf(safe.position.y, 0.0) * k,
		maxf(win.x - safe.end.x, 0.0) * k,
		maxf(win.y - safe.end.y, 0.0) * k,
	]
	if win.y > win.x:
		m[1] = maxf(m[1], MIN_TOP_INSET)
	return m

## Insets the current screen's root Control by the safe margins. The band
## left uncovered shows the clear color, so it's black like a status bar.
func _apply_safe_area() -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if not scene is Control:
		return
	var m := safe_margins()
	if m[0] + m[1] + m[2] + m[3] > 0.0:
		RenderingServer.set_default_clear_color(Color.BLACK)
	var c := scene as Control
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = m[0]
	c.offset_top = m[1]
	c.offset_right = -m[2]
	c.offset_bottom = -m[3]

# ---------- resume after the app is killed in the background ----------

func _is_game_scene(path: String) -> bool:
	return path.begins_with(GAMES_DIR)

func _remember_scene() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var path := get_tree().current_scene.scene_file_path
	if not _is_game_scene(path):
		return
	var f := FileAccess.open(RESUME_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"scene": path, "t": int(Time.get_unix_time_from_system())}))

func _forget_scene() -> void:
	if FileAccess.file_exists(RESUME_PATH):
		DirAccess.remove_absolute(RESUME_PATH)

## Leaving a game normally (to the hub, Options...) means there's nothing
## to resume. Not before the hub has checked, or launch would erase it.
func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if resume_checked and scene and not _is_game_scene(scene.scene_file_path):
		_forget_scene()

## The game scene the app was last in when Android killed it, or "". Only
## the first call per app run answers; it also clears the record.
func take_resume_scene() -> String:
	if resume_checked:
		return ""
	resume_checked = true
	if not FileAccess.file_exists(RESUME_PATH):
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(RESUME_PATH))
	_forget_scene()
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var age: float = Time.get_unix_time_from_system() - float(data.get("t", 0))
	if age < 0 or age > RESUME_MAX_AGE_SEC:
		return ""
	return str(data.get("scene", ""))

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		# A method Callable, not a lambda: freed with the button automatically.
		node.pressed.connect(buzz.bind(TAP_BUZZ_MS))

func _load() -> void:
	for g in SOUND_GROUPS:
		sound_groups[g[0]] = {"on": true, "vol": 100}
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	volume = clampi(int(data.get("volume", DEFAULT_VOLUME)), 0, 100)
	var saved = data.get("sound_groups", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for id in sound_groups:
			var g = saved.get(id)
			if typeof(g) == TYPE_DICTIONARY:
				sound_groups[id] = {"on": bool(g.get("on", true)), "vol": clampi(int(g.get("vol", 100)), 0, 100)}
	text_size = clampi(int(data.get("text_size", DEFAULT_TEXT_SIZE)), 0, TEXT_SCALES.size() - 1)
	theme = "light" if str(data.get("theme", "dark")) == "light" else "dark"
	sound = bool(data.get("sound", true))
	vibrate = bool(data.get("vibrate", true))
	keep_awake = bool(data.get("keep_awake", false))
	invites = str(data.get("invites", "all"))
	if not INVITE_MODES.has(invites):
		invites = "all"

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"text_size": text_size, "theme": theme, "sound": sound,
			"volume": volume, "sound_groups": sound_groups,
			"vibrate": vibrate, "keep_awake": keep_awake, "invites": invites,
		}))
