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
## - sound: mutes the Master bus, so any sound added later obeys it for free.
## - vibrate: `buzz()` -- every button press gives a short tick (hooked up
##   here, app-wide), and GameInfo buzzes on wins and losses.
## - keep_awake: stops the screen dimming/locking while the app is open.
## Skull mode (Voodoo) keeps its own file -- see voodoo.gd.
##
## Games must not reference `Settings` directly (packs also run on apps
## without it): `var s = get_node_or_null("/root/Settings")`, then `if s:`.

const PATH := "user://settings.json"

## content_scale_factor per text size. 1.0 is the original look; players
## worldwide found it too small, so new installs start at Large.
const TEXT_SCALES := [1.0, 1.2, 1.4]
const TEXT_SIZE_NAMES := ["Normal", "Large", "Extra large"]
const DEFAULT_TEXT_SIZE := 1

const TAP_BUZZ_MS := 12
const RESULT_BUZZ_MS := 70

signal changed

var text_size: int = DEFAULT_TEXT_SIZE
var theme: String = "dark"
var sound: bool = true
var vibrate: bool = true
var keep_awake: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply()
	# Every button, in every scene (packs included), ticks when pressed.
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_fit_scene)

func set_text_size(i: int) -> void:
	text_size = clampi(i, 0, TEXT_SCALES.size() - 1)
	_commit()

func set_theme(t: String) -> void:
	theme = "light" if t == "light" else "dark"
	_commit()

func set_sound(on: bool) -> void:
	sound = on
	_commit()

func set_vibrate(on: bool) -> void:
	vibrate = on
	_commit()
	buzz(RESULT_BUZZ_MS)  # so turning it on shows what it does

func set_keep_awake(on: bool) -> void:
	keep_awake = on
	_commit()

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
	"download": Color(1.0, 0.3, 0.45),
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
	"download": Color(0.8, 0.12, 0.18),
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
	get_tree().root.content_scale_factor = TEXT_SCALES[text_size]
	_fit_scene()
	AudioServer.set_bus_mute(0, not sound)
	DisplayServer.screen_set_keep_on(keep_awake)

## Starts each screen at the chosen size, then -- once its layout has
## settled -- shrinks the scale just enough that the screen's content fits
## the window, if it doesn't already.
func _fit_scene() -> void:
	if not is_inside_tree():
		return
	var root := get_tree().root
	var wanted: float = TEXT_SCALES[text_size]
	root.content_scale_factor = wanted
	if wanted <= 1.0:
		return
	var scene := get_tree().current_scene
	for i in 2:
		await get_tree().process_frame
	if not is_instance_valid(scene) or scene != get_tree().current_scene:
		return
	var view: Vector2 = root.get_visible_rect().size
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

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		# A method Callable, not a lambda: freed with the button automatically.
		node.pressed.connect(buzz.bind(TAP_BUZZ_MS))

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	text_size = clampi(int(data.get("text_size", DEFAULT_TEXT_SIZE)), 0, TEXT_SCALES.size() - 1)
	theme = "light" if str(data.get("theme", "dark")) == "light" else "dark"
	sound = bool(data.get("sound", true))
	vibrate = bool(data.get("vibrate", true))
	keep_awake = bool(data.get("keep_awake", false))

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"text_size": text_size, "theme": theme, "sound": sound,
			"vibrate": vibrate, "keep_awake": keep_awake,
		}))
