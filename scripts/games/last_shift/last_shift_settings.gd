extends RefCounted

## Last Shift options (v0.5), kept in user://last_shift_settings.json (the file that already held
## the language): language, difficulty, music and sound volume, vibration, screen shake.
## Everything is static so the menu, the options screen and the world all read the same values.
## In the hub, volume and vibration come from the hub's own Settings (STANDARDS section 7); this
## file is the standalone prototype's version of that.
## Hub port (2026-10-14): language, music, sound and vibration are the app's (the hub's Options);
## sfx_db(), buzz() and shake_on() ask the hub's Settings (guarded: get_node_or_null, never a
## preload). This file only keeps the last difficulty picked.

const PATH := "user://last_shift_settings.json"
## v0.4 kept the difficulty in its own file; it is read once and moved over.
const OLD_PREFS := "user://last_shift_prefs.json"

const DEFAULTS := {"lang": "", "difficulty": 1, "music": 0.8, "sfx": 1.0, "vibrate": true, "shake": true}

static var _data := {}
static var _loaded := false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in parsed:
				_data[k] = parsed[k]
	if FileAccess.file_exists(OLD_PREFS) and not _data.has("moved_prefs"):
		var f2 := FileAccess.open(OLD_PREFS, FileAccess.READ)
		var old = JSON.parse_string(f2.get_as_text()) if f2 != null else null
		if typeof(old) == TYPE_DICTIONARY and old.has("difficulty"):
			_data.difficulty = int(old.difficulty)
		_data["moved_prefs"] = true
		_save()

static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_data))

static func get_value(key: String):
	_load()
	return _data.get(key, DEFAULTS.get(key))

static func set_value(key: String, value) -> void:
	_load()
	_data[key] = value
	_save()
	if key == "music":
		apply_music()

static func difficulty() -> int:
	return clampi(int(get_value("difficulty")), 0, 2)

## The hub's Settings autoload, or null (packs also run on apps without it, and in tests).
static func _hub() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Settings")
	return null

static func vibrate_on() -> bool:
	var s := _hub()
	if s != null and "vibrate" in s:
		return bool(s.vibrate)
	return bool(get_value("vibrate"))

## Hub: no shake when the player turned on the app's "Reduce motion".
static func shake_on() -> bool:
	var s := _hub()
	if s != null and "reduce_motion" in s:
		return not bool(s.reduce_motion)
	return bool(get_value("shake"))

## Sound effects volume as a dB offset for AudioStreamPlayer.volume_db (0 = full).
## Hub: the "🎲 Game sounds" group (on/off + volume); Mute all and the overall volume are the
## Master bus, which these players feed anyway.
static func sfx_db() -> float:
	var s := _hub()
	if s != null and s.has_method("group_db"):
		var db = s.group_db("game")
		return -80.0 if db == null else float(db)
	var v := clampf(float(get_value("sfx")), 0.0, 1.0)
	return -80.0 if v <= 0.001 else linear_to_db(v)

## Music volume goes on the Music library's bus (scripts/common/music.gd). Guarded: the bus only
## exists once the Music autoload is up.
## Hub: the app's 🎵 Music setting owns that bus, so nothing is changed here.
static func apply_music() -> void:
	if _hub() != null:
		return
	var bus := AudioServer.get_bus_index("Music")
	if bus == -1:
		return
	var v := clampf(float(get_value("music")), 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus, -80.0 if v <= 0.001 else linear_to_db(v))

## A short buzz on phones (hits taken, knockdowns), if vibration is on.
static func buzz(ms: int) -> void:
	var s := _hub()
	if s != null and s.has_method("buzz"):
		s.buzz(ms)       # the hub's vibration switch
	elif vibrate_on():
		Input.vibrate_handheld(ms)

## Forgets everything (tests only).
static func reset() -> void:
	_data = DEFAULTS.duplicate()
	_loaded = true
