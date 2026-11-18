extends RefCounted
## User options (not part of the save game): language, text scale 1.0-1.4, touch controls.

const PATH := "user://hesperia_prefs.json"
static var text_scale: float = 1.0
static var touch_mode: String = "auto"     # auto | on | off
static var lang: String = "en"

static func touch_visible() -> bool:
	match touch_mode:
		"on":
			return true
		"off":
			return false
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

static func fs(base: int) -> int:
	# Micro 5 pixel font: 10 px is its native size (crisp); small bases snap up to it, then the user's text scale applies.
	var b: int = 10 if base <= 10 else base
	return int(round(float(b) * text_scale))

static func load_prefs() -> void:
	if not FileAccess.file_exists(PATH):
		lang = "es" if OS.get_locale_language() == "es" else "en"
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) == TYPE_DICTIONARY:
		text_scale = clampf(float(d.get("text_scale", 1.0)), 1.0, 1.4)
		touch_mode = d.get("touch_mode", "auto")
		lang = d.get("lang", "en")

static func save_prefs() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"text_scale": text_scale, "touch_mode": touch_mode, "lang": lang}))
