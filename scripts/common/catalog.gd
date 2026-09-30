extends Node

## Autoload `Catalog`: the game list plus everything about getting a game's
## .pck onto the device and mounted. The hub is only UI on top of this.
##
## Why an autoload rather than hub.gd state: the hub scene is freed every time
## a game starts, but "which packs are mounted in this process" and "did we
## already fetch the manifest / check for an app update" must survive that.
##
## Catalog source, best first:
##   1. the live manifest.json from GitHub (fetched in the background),
##   2. user://manifest_cache.json (the last live copy that parsed cleanly),
##   3. res://manifest.json bundled into the APK (so a first launch offline
##      still shows every game).
## Adding a game to manifest.json therefore shows it in already-installed apps
## without an APK update -- see "min_build" below for when that's unsafe.

const Config = preload("res://scripts/common/config.gd")
const Version = preload("res://scripts/common/version.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const BUNDLED_MANIFEST := "res://manifest.json"
const CACHED_MANIFEST := "user://manifest_cache.json"
const PACK_VERSIONS_PATH := "user://pack_versions.json"
const PACKS_DIR := "user://packs"
const PACK_MAGIC := "GDPC"

## Tile states, see state_of().
const STATE_SOON := "soon"
const STATE_READY := "ready"
const STATE_DOWNLOAD := "download"
const STATE_NEEDS_APP_UPDATE := "needs_app_update"

## Emitted when `categories` changed (a newer live manifest arrived).
signal catalog_changed

## [{name, icon, games: [game]}]. A game is {title, icon} for a "coming soon"
## placeholder, or {id, title, icon, scene, version, url, min_build}.
var categories: Array = []
var _games_by_id: Dictionary = {}

## Games whose scene already existed before this process mounted anything --
## i.e. running from the editor or a full desktop build. Those launch straight
## from local source instead of downloading the published pack over it.
var _bundled: Dictionary = {}
## Packs mounted in this process. A mounted pack is never re-downloaded until
## the next app start: Godot reads a mounted .pck lazily by file offset, so
## overwriting it underneath would feed the game corrupt data.
var _mounted: Dictionary = {}
var _downloads: Dictionary = {}  # pack id -> HTTPRequest in flight

var _fetch_in_flight := false
var _last_fetch_ok_msec := -1
var _manifest_waiters: Array[Callable] = []

## Set once the hub has checked GitHub for a newer APK this session, so
## returning to the hub doesn't re-hit the rate-limited API or re-nag.
var app_update_checked := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PACKS_DIR)
	_remove_partial_downloads()

	# A cache written by an older APK is ignored: the newer bundled manifest
	# that shipped with this build is at least as fresh.
	var cached = SaveUtil.read(CACHED_MANIFEST)
	var cache_usable: bool = cached != null and int(cached.get("_cached_by_build", 0)) >= Version.BUILD_NUMBER
	if not (cache_usable and _apply_manifest(cached)):
		if not _apply_manifest(_read_json_file(BUNDLED_MANIFEST)):
			push_error("Catalog: bundled manifest.json is missing or malformed")

	for id in _games_by_id:
		if ResourceLoader.exists(_games_by_id[id].scene):
			_bundled[id] = true

	refresh_manifest()

# ---------- queries ----------

func get_game(id: String) -> Dictionary:
	return _games_by_id.get(id, {})

func state_of(game: Dictionary) -> String:
	if not game.has("id"):
		return STATE_SOON
	if int(game.get("min_build", 0)) > Version.BUILD_NUMBER:
		return STATE_NEEDS_APP_UPDATE
	if _bundled.has(game.id) or _mounted.has(game.id) or is_downloaded(game.id):
		return STATE_READY
	return STATE_DOWNLOAD

func is_downloaded(id: String) -> bool:
	return FileAccess.file_exists(_pack_path(id))

func local_version(id: String) -> int:
	var data = SaveUtil.read(PACK_VERSIONS_PATH)
	return 0 if data == null else int(data.get(id, 0))

## True if tapping this game must download before it can launch: never
## downloaded, or a newer version is published and it isn't mounted yet.
func needs_download(id: String) -> bool:
	if _bundled.has(id) or _mounted.has(id):
		return false
	if not is_downloaded(id):
		return true
	return int(get_game(id).get("version", 0)) > local_version(id)

func is_downloading(id: String) -> bool:
	return _downloads.has(id)

func manifest_is_fresh(max_age_sec: int = Config.MANIFEST_MAX_AGE_SEC) -> bool:
	return _last_fetch_ok_msec >= 0 and Time.get_ticks_msec() - _last_fetch_ok_msec < max_age_sec * 1000

# ---------- manifest ----------

## Fetches the live manifest unless one fetched within max_age_sec is already
## in hand. on_done(ok: bool) always fires exactly once (deferred when there's
## nothing to fetch), even offline -- callers then just use what they have.
func refresh_manifest(max_age_sec: int = 0, on_done: Callable = Callable()) -> void:
	if max_age_sec > 0 and manifest_is_fresh(max_age_sec):
		if on_done.is_valid():
			_safe_call.call_deferred(on_done, [true])
		return
	if on_done.is_valid():
		_manifest_waiters.append(on_done)
	if _fetch_in_flight:
		return
	_fetch_in_flight = true
	_get_json(Config.MANIFEST_URL, _on_manifest_fetched)

func _on_manifest_fetched(parsed: Variant) -> void:
	_fetch_in_flight = false
	var ok := false
	if typeof(parsed) == TYPE_DICTIONARY:
		var before := JSON.stringify(categories)
		ok = _apply_manifest(parsed)
		if ok:
			_last_fetch_ok_msec = Time.get_ticks_msec()
			var to_cache: Dictionary = parsed.duplicate()
			to_cache["_cached_by_build"] = Version.BUILD_NUMBER
			SaveUtil.write(CACHED_MANIFEST, to_cache)
			if JSON.stringify(categories) != before:
				catalog_changed.emit()
	var waiters := _manifest_waiters
	_manifest_waiters = []
	for cb in waiters:
		_safe_call(cb, [ok])

## Validates and adopts a manifest. Returns false (and changes nothing) if it
## doesn't look right, so one bad push to manifest.json can't blank the hub.
func _apply_manifest(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var raw_games = data.get("games")
	var raw_categories = data.get("categories")
	if typeof(raw_games) != TYPE_DICTIONARY or typeof(raw_categories) != TYPE_ARRAY or raw_categories.is_empty():
		return false

	var games_by_id := {}
	for id in raw_games:
		var entry = raw_games[id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		games_by_id[str(id)] = {
			"id": str(id),
			"version": int(entry.get("version", 1)),
			"url": str(entry.get("url", Config.PACK_BASE_URL + str(id) + ".pck")),
			"scene": str(entry.get("scene", "res://scenes/games/%s/%s.tscn" % [id, id])),
			"min_build": int(entry.get("min_build", 0)),
		}

	var new_categories := []
	for raw_cat in raw_categories:
		if typeof(raw_cat) != TYPE_DICTIONARY or typeof(raw_cat.get("games")) != TYPE_ARRAY:
			continue
		var cat_games := []
		for raw_game in raw_cat.games:
			if typeof(raw_game) != TYPE_DICTIONARY:
				continue
			var title := str(raw_game.get("title", "?"))
			var icon := str(raw_game.get("icon", "🎮"))
			var id := str(raw_game.get("id", ""))
			var game: Dictionary = games_by_id[id] if id != "" and games_by_id.has(id) else {}
			game["title"] = title
			game["icon"] = icon
			_copy_localized(raw_game, game, "title")
			cat_games.append(game)
		var category := {
			"name": str(raw_cat.get("name", "")),
			"icon": str(raw_cat.get("icon", "")),
			"games": cat_games,
		}
		_copy_localized(raw_cat, category, "name")
		new_categories.append(category)
	if new_categories.is_empty():
		return false

	categories = new_categories
	_games_by_id = games_by_id
	return true

## Carries "<field>_<lang>" translations (e.g. "title_es") from the manifest
## into the entry; Lang.pick() chooses between them at display time.
func _copy_localized(from: Dictionary, to: Dictionary, field: String) -> void:
	for key in from:
		if str(key).begins_with(field + "_"):
			to[str(key)] = str(from[key])

# ---------- download + mount ----------

## Downloads a game's pack to a temp file, checks it really is a .pck, then
## swaps it in. on_done(error: String) -- "" on success. Returns the
## HTTPRequest so the caller can poll progress; null if it couldn't start.
func download(id: String, on_done: Callable) -> HTTPRequest:
	var game := get_game(id)
	if game.is_empty():
		_safe_call.call_deferred(on_done, [tr("This game isn't in the catalog.")])
		return null
	if _downloads.has(id):
		return _downloads[id]

	var part_path := _pack_path(id) + ".part"
	var http := HTTPRequest.new()
	http.download_file = part_path
	http.timeout = Config.DOWNLOAD_TIMEOUT
	add_child(http)
	_downloads[id] = http
	http.request_completed.connect(_on_download_completed.bind(id, int(game.version), part_path, http, on_done))
	if http.request(game.url) != OK:
		_on_download_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), id, int(game.version), part_path, http, on_done)
		return null
	return http

func cancel_download(id: String) -> void:
	var http: HTTPRequest = _downloads.get(id)
	if http == null:
		return
	http.cancel_request()
	_downloads.erase(id)
	http.queue_free()
	DirAccess.remove_absolute(_pack_path(id) + ".part")

func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray,
		id: String, version: int, part_path: String, http: HTTPRequest, on_done: Callable) -> void:
	if _downloads.get(id) != http:
		return  # cancelled
	_downloads.erase(id)
	http.queue_free()

	var error := ""
	if result == HTTPRequest.RESULT_TIMEOUT:
		error = tr("The download timed out. Check your connection and try again.")
	elif result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN or result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		error = tr("Couldn't save the download. Check your free space.")
	elif result != HTTPRequest.RESULT_SUCCESS or code != 200:
		error = tr("Download failed. Check your connection and try again.")
	elif not _looks_like_pack(part_path):
		error = tr("The download was damaged. Please try again.")

	if error != "":
		DirAccess.remove_absolute(part_path)
		_safe_call(on_done, [error])
		return

	# Only now replace the old copy, so a failed or interrupted download never
	# destroys a working one. Safe: needs_download() never lets a mounted pack
	# get here.
	var final_path := _pack_path(id)
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	if DirAccess.rename_absolute(part_path, final_path) != OK:
		DirAccess.remove_absolute(part_path)
		_safe_call(on_done, [tr("Couldn't save the download. Check your free space.")])
		return
	_set_local_version(id, version)
	_safe_call(on_done, [""])

## Makes the game's scene loadable. Returns "" on success or a message.
## A pack that fails to mount is deleted so the next tap re-downloads it
## instead of failing the same way forever.
func mount(id: String) -> String:
	var game := get_game(id)
	if game.is_empty():
		return tr("This game isn't in the catalog.")
	if _bundled.has(id) or _mounted.has(id):
		return ""
	if not is_downloaded(id):
		return tr("This game hasn't been downloaded yet.")
	# replace_files = false: a pack may only ADD its own files. Older packs
	# carry stray copies of shared scripts (auth.gd, project.binary...) that
	# must never shadow the versions this APK shipped with.
	if ProjectSettings.load_resource_pack(_pack_path(id), false) and ResourceLoader.exists(game.scene):
		_mounted[id] = true
		return ""
	DirAccess.remove_absolute(_pack_path(id))
	_set_local_version(id, 0)
	return tr("This game's files were damaged and have been removed. Tap it again to re-download.")

# ---------- app update ----------

## on_newer(remote_version: String, apk_url: String) fires only if GitHub's
## latest release is newer than this build and has an APK attached.
func check_app_update(on_newer: Callable) -> void:
	app_update_checked = true
	_get_json(Config.LATEST_RELEASE_API, func(parsed):
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("tag_name"):
			return
		var remote_version: String = str(parsed.tag_name).trim_prefix("v")
		if not is_newer_version(remote_version, Version.VERSION):
			return
		for asset in parsed.get("assets", []):
			if typeof(asset) == TYPE_DICTIONARY and str(asset.get("name", "")).ends_with(".apk"):
				_safe_call(on_newer, [remote_version, str(asset.get("browser_download_url", ""))])
				return
	)

## Dotted versions compared numerically segment by segment ("0.10.0" > "0.9.1").
static func is_newer_version(remote: String, local: String) -> bool:
	var r := remote.split(".")
	var l := local.split(".")
	for i in range(max(r.size(), l.size())):
		var rv: int = r[i].to_int() if i < r.size() else 0
		var lv: int = l[i].to_int() if i < l.size() else 0
		if rv != lv:
			return rv > lv
	return false

# ---------- helpers ----------

func _pack_path(id: String) -> String:
	return "%s/%s.pck" % [PACKS_DIR, id]

func _set_local_version(id: String, version: int) -> void:
	var data = SaveUtil.read(PACK_VERSIONS_PATH)
	if data == null:
		data = {}
	if version <= 0:
		data.erase(id)
	else:
		data[id] = version
	SaveUtil.write(PACK_VERSIONS_PATH, data)

func _looks_like_pack(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 4:
		return false
	var magic := f.get_buffer(4).get_string_from_ascii()
	f.close()
	return magic == PACK_MAGIC

## Leftovers from a download the app was killed in the middle of.
func _remove_partial_downloads() -> void:
	for file in DirAccess.get_files_at(PACKS_DIR):
		if file.ends_with(".part"):
			DirAccess.remove_absolute(PACKS_DIR.path_join(file))

func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

## GET a JSON document; on_done(parsed) gets null on any failure. Timeout
## always set: a bare HTTPRequest waits forever on a dead connection.
func _get_json(url: String, on_done: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = Config.HTTP_TIMEOUT
	add_child(http)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var parsed = null
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			parsed = JSON.parse_string(body.get_string_from_utf8())
		_safe_call(on_done, [parsed])
	)
	if http.request(url, ["User-Agent: Voodoo-App"]) != OK:
		http.queue_free()
		_safe_call.call_deferred(on_done, [null])

## Callers are often scenes that may have been freed (player left) by the
## time a network reply lands; calling into them then just logs errors.
static func _safe_call(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)
