extends RefCounted

## Crisis help numbers (compliance pack, Task 5). APK-side.
##
## Data: the bundled copy (scripts/common/crisis_data.gd, generated from
## data/crisis_resources.json) works offline; a newer copy (its "updated" date is
## later) published on GitHub Pages (docs/crisis_resources.json) is fetched in the
## background at most once a day and cached, so numbers can change without an app
## release. Entries under "pending_verification_do_not_ship" are never used.
##
## Region: the country part of the device language (es_AR -> AR). No location,
## nothing collected, nothing logged when the Help screen opens. A country that
## isn't in the data gets the fallback link (findahelpline.com).
##
## The fetch is tied to app start, not to opening the screen, on purpose.

const CrisisData = preload("res://scripts/common/crisis_data.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const CACHE_PATH := "user://crisis_cache.json"
const STAMP_PATH := "user://crisis_checked.json"
const REFRESH_SEC := 86400
const SUPPORTED_SCHEMA := 1

## Tests (and a future country picker) can force a country instead of the device's.
static var forced_country: String = ""

## Quiet JSON parse: anything that isn't valid JSON is just null.
static func _parse(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null

static func _bundled() -> Dictionary:
	var data = _parse(CrisisData.JSON_TEXT)
	return data if typeof(data) == TYPE_DICTIONARY else {}

static func _clean(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY or int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA \
			or typeof(data.get("regions")) != TYPE_DICTIONARY:
		return {}
	for region in data.regions.values():
		if typeof(region) == TYPE_DICTIONARY:
			region.erase("pending_verification_do_not_ship")
	return data

## The data to show: the cached remote copy if it is newer than the bundled one.
static func load_data() -> Dictionary:
	var bundled := _clean(_bundled())
	if FileAccess.file_exists(CACHE_PATH):
		var cached := _clean(_parse(FileAccess.get_file_as_string(CACHE_PATH)))
		if not cached.is_empty() and str(cached.get("updated", "")) > str(bundled.get("updated", "")):
			return cached
	return bundled

## "AR" from "es_AR" / "es-AR"; "" when the language carries no country.
static func country(locale: String = "") -> String:
	if forced_country != "" and locale == "":
		return forced_country
	var loc := locale if locale != "" else OS.get_locale()
	var parts := loc.replace("-", "_").split("_")
	for i in range(1, parts.size()):
		var p := parts[i].strip_edges()
		if p.length() == 2 and p == p.to_upper():
			return p
	return ""

## The resources for a country code, [] when the data has none for it.
static func resources_for(data: Dictionary, country_code: String) -> Array:
	var region = data.get("regions", {}).get(country_code, {})
	return region.get("resources", []) if typeof(region) == TYPE_DICTIONARY else []

## "0800 345 1435" -> "08003451435" for tel: links.
static func dial_digits(dial: String) -> String:
	var out := ""
	for c in dial:
		if c in "0123456789+*#":
			out += c
	return out

static func label(res: Dictionary, lang: String) -> String:
	return str(res.get("label_" + lang, res.get("label_es", "")))

static func note(res: Dictionary, lang: String) -> String:
	return str(res.get("note_" + lang, res.get("note_es", "")))

# ---------- background refresh ----------

## Fetches the published copy if the last check was over a day ago. Call from the hub's
## start. `host` is any node in the tree (the HTTPRequest lives under it).
static func refresh(host: Node, url: String) -> void:
	if host == null or not host.is_inside_tree():
		return
	var now := int(Time.get_unix_time_from_system())
	if FileAccess.file_exists(STAMP_PATH):
		var stamp = _parse(FileAccess.get_file_as_string(STAMP_PATH))
		if typeof(stamp) == TYPE_DICTIONARY and now - int(stamp.get("at", 0)) < REFRESH_SEC:
			return
	var http := HTTPRequest.new()
	http.timeout = 10.0
	host.add_child(http)
	http.request_completed.connect(_on_fetched.bind(http, now))
	if http.request(url) != OK:
		http.queue_free()

static func _on_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, now: int) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # try again next start (no stamp written)
	SaveUtil.write(STAMP_PATH, {"at": now})
	var data := _clean(_parse(body.get_string_from_utf8()))
	if not data.is_empty():
		SaveUtil.write(CACHE_PATH, data)
