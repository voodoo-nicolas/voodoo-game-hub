extends RefCounted
## Pure (de)serialisation of the world state so it can be round-trip tested headless.
const VERSION := 1

static func pack(d: Dictionary) -> String:
	var out := d.duplicate(true)
	out["version"] = VERSION
	return JSON.stringify(out)

## Returns {} on failure.
static func unpack(txt: String) -> Dictionary:
	var j = JSON.parse_string(txt)
	if typeof(j) != TYPE_DICTIONARY or int(j.get("version", 0)) != VERSION:
		return {}
	return j
