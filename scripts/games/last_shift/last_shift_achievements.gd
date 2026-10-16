extends RefCounted

## Achievements and XP for Last Shift, kept across runs in user://last_shift_achievements.json.
## The list and the XP of each one are in LsEngine.ACHIEVEMENTS; names and descriptions in
## LsText.ACH. Also remembers which exits were ever used (for "Three ways out").
## In the hub these become the game's badges in last_shift_help.gd. The XP is "Viral XP" (decided
## 2026-10-14); the hub has no XP system yet.

const LsEngine = preload("res://scripts/games/last_shift/last_shift_engine.gd")

## The hub's Brand script (packs never preload it: it may not exist on older apps, or here).
const BRAND_PATH := "res://scripts/common/brand.gd"
## Used when there is no Brand (this standalone prototype).
const BRAND_FALLBACK := "Viral"

## "Viral XP": the XP is named after the hub brand, read from Brand (never hard-coded in the hub).
static func xp_name() -> String:
	var brand := BRAND_FALLBACK
	if ResourceLoader.exists(BRAND_PATH):
		var b = load(BRAND_PATH)
		if b != null and "DEVELOPER" in b:
			brand = str(b.DEVELOPER)
	return brand + " XP"

## Where they are kept (tests point this at a scratch file so they never touch the real one).
static var path := "user://last_shift_achievements.json"

static func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"unlocked": {}, "exits": {}}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"unlocked": {}, "exits": {}}
	if not parsed.has("unlocked"):
		parsed["unlocked"] = {}
	if not parsed.has("exits"):
		parsed["exits"] = {}
	return parsed

static func _write(d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

static func has(id: String) -> bool:
	return _read().unlocked.has(id)

## Unlocks an achievement. Returns true the first time (the caller shows the toast).
static func unlock(id: String) -> bool:
	if not LsEngine.ACHIEVEMENTS.has(id):
		return false
	var d := _read()
	if d.unlocked.has(id):
		return false
	d.unlocked[id] = true
	_write(d)
	return true

## The hub's challenge log (Viral XP, 🏅 on the Landing; docs/ADDING_A_GAME.md §2). The challenge
## ids are these achievement ids (CHALLENGES in last_shift_help.gd). APK-side: never preloaded, and
## apps before report_challenge (v0.38) just skip it. Returns true when the hub paid it out (it
## shows its own toast then, so the world doesn't show a second one).
const HUB_ACH_PATH := "res://scripts/common/achievements.gd"
const GAME_ID := "last_shift"

static func report_hub(id: String) -> bool:
	if not ResourceLoader.exists(HUB_ACH_PATH):
		return false
	var a = load(HUB_ACH_PATH)
	if a == null:
		return false
	for m in a.get_script_method_list():
		if str(m.get("name", "")) == "report_challenge":
			return bool(a.report_challenge(GAME_ID, id))
	return false

## Remembers an exit; returns how many different exits have been used so far.
static func add_exit(exit_id: String) -> int:
	var d := _read()
	d.exits[exit_id] = true
	_write(d)
	return d.exits.size()

static func xp() -> int:
	var total := 0
	for id in _read().unlocked:
		total += int(LsEngine.ACHIEVEMENTS.get(id, 0))
	return total

static func count() -> int:
	return _read().unlocked.size()

static func total() -> int:
	return LsEngine.ACHIEVEMENTS.size()

## Forgets everything (tests only).
static func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
