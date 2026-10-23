extends RefCounted

## Every tuning number lives in turned_tuning.json (next to this file; it ships in the pack).
## `f("sun.regen_per_s")` reads a dotted path; a missing key logs an error and returns 0
## (tools/test_turned.gd checks that every key the code asks for exists).

const PATH := "res://scripts/games/turned/turned_tuning.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		reload()
	return _data

static func reload() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed
	else:
		push_error("Turned: %s is missing or not valid JSON" % PATH)
		_data = {"_broken": true}

## The raw value at a dotted path (null if missing).
static func v(path: String) -> Variant:
	var cur: Variant = data()
	for part in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(part):
			push_error("Turned: no tuning value '%s'" % path)
			return null
		cur = (cur as Dictionary)[part]
	return cur

static func f(path: String) -> float:
	var x: Variant = v(path)
	return float(x) if (typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT) else 0.0

static func b(path: String) -> bool:
	return bool(v(path))

static func color(path: String) -> Color:
	return Color(str(v(path)))

static func arr(path: String) -> Array:
	var x: Variant = v(path)
	return x if typeof(x) == TYPE_ARRAY else []

## Metres to pixels (1 m = pixels_per_meter px).
static func m(meters: float) -> float:
	return meters * f("world.pixels_per_meter")
