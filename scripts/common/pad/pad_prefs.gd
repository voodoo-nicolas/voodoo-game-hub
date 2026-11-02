extends RefCounted

## The player's controller choices, saved once for every game (`user://pad.json`). A game can ask
## for a layout of its own (`PadController.layout_override`), but size, opacity, handedness and
## the skin stay the player's.

const PATH := "user://pad.json"
## Bump when a default changes so that it reaches phones that saved an older one. Version 2 (2026-11-02):
## the pad is drawn almost transparent over a game (25%), so an opacity saved before then is dropped.
const VERSION := 2

const DEFAULTS := {
	"layout": "stick_4",
	"skin": "neon",
	"size": 1.0,          # 0.6 .. 1.4, 1.0 = the mock-ups
	"opacity": 0.25,      # 0 .. 1. Over a game it is almost transparent (owner, 2026-11-02); 0 = invisible, still works
	"right_handed": true,
	"floating": false,    # sticks appear under the thumb instead of at a fixed spot
	"deadzone": 0.15,
	"dpad8": true,        # D-pad: 8 directions (two arrows at once) instead of 4
	"show_map": false,    # draw the hit areas and action names over the controller
}

static func load_prefs() -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				if int(data.get("version", 1)) < VERSION:
					data.erase("opacity")
				for key in DEFAULTS:
					if data.has(key) and typeof(data[key]) == typeof(DEFAULTS[key]):
						out[key] = data[key]
					elif data.has(key) and DEFAULTS[key] is float and data[key] is int:
						out[key] = float(data[key])
	return clean(out)

## True when the player has saved a value for `key` (so a game's own default must not override it).
static func has_saved(key: String) -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	return data is Dictionary and data.has(key)

static func save_prefs(prefs: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		var out := prefs.duplicate()
		out["version"] = VERSION
		f.store_string(JSON.stringify(out))

## Clamps every value into its range.
static func clean(p: Dictionary) -> Dictionary:
	var out := p.duplicate()
	out["size"] = clampf(float(out["size"]), 0.6, 1.4)
	out["opacity"] = clampf(float(out["opacity"]), 0.0, 1.0)
	out["deadzone"] = clampf(float(out["deadzone"]), 0.05, 0.4)
	return out
