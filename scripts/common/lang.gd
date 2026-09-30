extends Node

## Autoload `Lang`: the app's language (English / Spanish so far).
##
## Translation uses Godot's own system: every Label/Button translates its text
## automatically when a translation for that exact English string exists, so
## plain `label.text = "Play Again"` just works. Text built with `%` or `+`
## must go through tr() first -- `tr("Score: %d") % score` -- because
## "Score: 42" is not a key anyone could have translated.
##
## Where strings live:
##   - hub / shared screens: scripts/common/strings_es.gd (ships in the APK)
##   - each game: scripts/games/<id>/<id>_i18n.gd (ships in the game's pack,
##     so a new game brings its own translations without an app update)
##   - game and category names: "title_es" / "name_es" in manifest.json
##
## Games never reference Lang directly (packs also run on apps without it);
## their _i18n.gd registers straight with TranslationServer.

const CommonStrings = preload("res://scripts/common/strings_es.gd")

const SETTINGS_PATH := "user://language.json"
const SUPPORTED := ["en", "es"]
const NAMES := {"en": "English", "es": "Español"}

signal changed(code: String)

var current: String = "en"

func _ready() -> void:
	var t := Translation.new()
	t.locale = "es"
	for key in CommonStrings.ES:
		t.add_message(key, CommonStrings.ES[key])
	TranslationServer.add_translation(t)

	var saved := ""
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			saved = str(data.get("language", ""))
	# First launch: follow the phone's language.
	_apply(saved if saved in SUPPORTED else _device_language())

func _device_language() -> String:
	return "es" if OS.get_locale_language() == "es" else "en"

func set_language(code: String) -> void:
	if not code in SUPPORTED or code == current:
		return
	_apply(code)
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"language": code}))
	changed.emit(code)

func toggle() -> void:
	set_language("en" if current == "es" else "es")

func _apply(code: String) -> void:
	current = code
	TranslationServer.set_locale(code)

## Picks the localized field from a manifest entry: `field_es` when Spanish
## and present, else the plain (English) field.
func pick(entry: Dictionary, field: String) -> String:
	if current != "en":
		var localized = entry.get("%s_%s" % [field, current], "")
		if str(localized) != "":
			return str(localized)
	return str(entry.get(field, ""))
