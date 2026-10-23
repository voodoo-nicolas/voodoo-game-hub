extends RefCounted

## Save / resume for Turned: user://turned_save.json with a version number. Autosaves when the
## player leaves the house, when they first enter the alley, and when the kit pauses or goes Home
## (STANDARDS N5). Only a "New" start deletes it. A save from another version is ignored.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
## Shared JSON save helper (writes a temp file and renames it: a phone killed mid-write keeps the old save).
const SaveUtil = preload("res://scripts/common/save_util.gd")

const PATH := "user://turned_save.json"

static func has_save() -> bool:
	return not read().is_empty()

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## `engine` is a turned_engine.gd, `clock` a turned_sun_clock.gd.
static func write(engine: RefCounted, clock: RefCounted) -> void:
	var payload := {
		"v": int(T.f("save.version")),
		"state": engine.to_dict(),
		"clock": clock.to_dict(),
	}
	SaveUtil.write(PATH, payload)

## The saved dictionary, or {} if missing, broken or from another version.
static func read() -> Dictionary:
	var parsed = SaveUtil.read(PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("v", 0)) != int(T.f("save.version")) or typeof(d.get("state")) != TYPE_DICTIONARY:
		return {}
	return d
