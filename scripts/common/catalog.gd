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
##
## Archived games (since v0.29, HUB_V2_PLAN §6): a category or game with
## "archived": true stays in manifest.json -- packs, ids and saves are kept --
## but is dropped here, so the hub never lists, launches, resumes or accepts
## invites for it. Apps before v0.29 ignore the flag and still list it.
##
## Media packs (since v0.31, STANDARDS §10): shared music / sounds / art in
## their own .pck files, downloaded once for every game that uses them.
##   manifest "media_packs": {"media-common": {version, url, size, sha256}}
##   a game's entry: "requires_media": ["media-common>=1"]
## - A media pack lives at user://packs/media/<name>.v<N>.pck -- a NEW file
##   per version, because a mounted pack must never be overwritten. All of
##   them are mounted at launch (newest only; older files are deleted then).
##   One downloaded mid-session is mounted at once, on top of an older one
##   if any (replace_files = false: its new files appear now, changed ones
##   on the next launch).
## - Tapping a game downloads its missing media first, then its own pack
##   (download() runs the chain; download_progress() covers all of it).
## - At launch (and when a live manifest arrives) every downloaded game's
##   media is checked and missing or outdated packs are fetched silently.
## - Storage (storage_items / delete_pack): a media pack is only deleted
##   when no downloaded game needs it (media_users); anything mounted this
##   session is deleted on the next launch instead (pending_delete.json).
## Apps before v0.31 ignore both fields: games guard every media file with
## ResourceLoader.exists(), so they just run without it there.

const Config = preload("res://scripts/common/config.gd")
const Version = preload("res://scripts/common/version.gd")
const SaveUtil = preload("res://scripts/common/save_util.gd")

const BUNDLED_MANIFEST := "res://manifest.json"
const CACHED_MANIFEST := "user://manifest_cache.json"
const PACK_VERSIONS_PATH := "user://pack_versions.json"
const PACKS_DIR := "user://packs"
const PACK_MAGIC := "GDPC"
const MEDIA_DIR := "user://packs/media"
## Packs the player deleted while they were mounted: removed at next launch.
const PENDING_DELETE_PATH := "user://packs/pending_delete.json"

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
## Ids of archived games (see the header), for screens that list games from
## saved stats rather than from `categories`.
var archived_ids: Dictionary = {}

## Games whose scene already existed before this process mounted anything --
## i.e. running from the editor or a full desktop build. Those launch straight
## from local source instead of downloading the published pack over it.
var _bundled: Dictionary = {}
## Packs mounted in this process. A mounted pack is never re-downloaded until
## the next app start: Godot reads a mounted .pck lazily by file offset, so
## overwriting it underneath would feed the game corrupt data.
var _mounted: Dictionary = {}
var _downloads: Dictionary = {}  # pack id -> HTTPRequest in flight (the chain's current step)
## game id -> {steps: ["media:<name>"..., "game"], total, on_done} while download() runs.
var _chains: Dictionary = {}

## name -> {name, version, url, size, sha256} from the manifest's media_packs.
var media_packs: Dictionary = {}
## name -> highest version mounted this session.
var _media_mounted: Dictionary = {}
## Media packs whose files exist in res:// already (editor, PC test build).
var _media_bundled: Dictionary = {}
var _media_downloads: Dictionary = {}  # name -> HTTPRequest
var _media_waiters: Dictionary = {}  # name -> [Callable(error: String)]

var _fetch_in_flight := false
var _last_fetch_ok_msec := -1
var _manifest_waiters: Array[Callable] = []

## Set once the hub has checked GitHub for a newer APK this session, so
## returning to the hub doesn't re-hit the rate-limited API or re-nag.
var app_update_checked := false

func _ready() -> void:
	# Keep working while a game is paused (GameInfo pauses the tree).
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(PACKS_DIR)
	DirAccess.make_dir_recursive_absolute(MEDIA_DIR)
	_run_pending_deletes()
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
	# Before anything is mounted: a media root that already exists is bundled.
	for name in [MEDIA_COMMON] + media_packs.keys():
		if DirAccess.dir_exists_absolute(media_root(name)):
			_media_bundled[name] = true
	_mount_local_media()
	_check_media.call_deferred()

	refresh_manifest()

# ---------- queries ----------

func get_game(id: String) -> Dictionary:
	return _games_by_id.get(id, {})

func is_archived(id: String) -> bool:
	return archived_ids.has(id)

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
## downloaded, a newer version is published and it isn't mounted yet, or
## a media pack it needs is missing.
func needs_download(id: String) -> bool:
	if _bundled.has(id):
		return false
	return not missing_media(id).is_empty() or _pack_needed(id)

func _pack_needed(id: String) -> bool:
	if _bundled.has(id) or _mounted.has(id):
		return false
	if not is_downloaded(id):
		return true
	return int(get_game(id).get("version", 0)) > local_version(id)

func is_downloading(id: String) -> bool:
	return _downloads.has(id) or _chains.has(id)

## 0..1 over every step of a download() (media first, then the game), or -1
## while the size isn't known yet.
func download_progress(id: String) -> float:
	var chain = _chains.get(id)
	var http: HTTPRequest = _downloads.get(id)
	var part := -1.0
	if http != null and is_instance_valid(http) and http.get_body_size() > 0:
		part = float(http.get_downloaded_bytes()) / float(http.get_body_size())
	if chain == null:
		return part
	var total: int = maxi(int(chain.total), 1)
	var done: int = int(chain.total) - chain.steps.size()
	return (done + maxf(part, 0.0)) / total

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
			_check_media()
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
			"requires_media": _parse_requirements(entry.get("requires_media", [])),
		}

	var packs := {}
	var raw_packs = data.get("media_packs", {})
	if typeof(raw_packs) == TYPE_DICTIONARY:
		for name in raw_packs:
			var e = raw_packs[name]
			if typeof(e) != TYPE_DICTIONARY or int(e.get("version", 0)) < 1:
				continue
			var version := int(e.version)
			packs[str(name)] = {
				"name": str(name),
				"version": version,
				"url": str(e.get("url", Config.PACK_BASE_URL + "%s.v%d.pck" % [name, version])),
				"size": int(e.get("size", 0)),
				"sha256": str(e.get("sha256", "")).to_lower(),
			}

	var archived := {}
	for raw_cat in raw_categories:
		if typeof(raw_cat) != TYPE_DICTIONARY or typeof(raw_cat.get("games")) != TYPE_ARRAY:
			continue
		for raw_game in raw_cat.games:
			if typeof(raw_game) == TYPE_DICTIONARY and raw_game.get("id", "") != "" \
					and (raw_cat.get("archived", false) == true or raw_game.get("archived", false) == true):
				archived[str(raw_game.id)] = true
	for id in archived:
		games_by_id.erase(id)

	var new_categories := []
	for raw_cat in raw_categories:
		if typeof(raw_cat) != TYPE_DICTIONARY or typeof(raw_cat.get("games")) != TYPE_ARRAY:
			continue
		if raw_cat.get("archived", false) == true:
			continue
		var cat_games := []
		for raw_game in raw_cat.games:
			if typeof(raw_game) != TYPE_DICTIONARY:
				continue
			if archived.has(str(raw_game.get("id", ""))):
				continue
			var title := str(raw_game.get("title", "?"))
			var icon := str(raw_game.get("icon", "🎮"))
			var id := str(raw_game.get("id", ""))
			var game: Dictionary = games_by_id[id] if id != "" and games_by_id.has(id) else {}
			game["title"] = title
			game["icon"] = icon
			_copy_localized(raw_game, game, "title")
			# Since v0.25, for the Multiplayer and Leaderboards screens:
			# "modes" ("online,local,cpu,party") and "board" (the stat its
			# leaderboard ranks; "none" = no board).
			game["modes"] = str(raw_game.get("modes", ""))
			game["board"] = str(raw_game.get("board", "Best score"))
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
	archived_ids = archived
	media_packs = packs
	return true

## ["media-common>=2", "media-cat-cards"] -> [{name, min}] (no ">=" = 1).
static func _parse_requirements(raw: Variant) -> Array:
	var out := []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for r in raw:
		var parts := str(r).split(">=")
		var name := parts[0].strip_edges()
		if name != "":
			out.append({"name": name, "min": maxi(1, int(parts[1]) if parts.size() > 1 else 1)})
	return out

## Carries "<field>_<lang>" translations (e.g. "title_es") from the manifest
## into the entry; Lang.pick() chooses between them at display time.
func _copy_localized(from: Dictionary, to: Dictionary, field: String) -> void:
	for key in from:
		if str(key).begins_with(field + "_"):
			to[str(key)] = str(from[key])

# ---------- download + mount ----------

## Gets everything a game needs onto the device: its missing media packs,
## then its own pack (each to a temp file, checked, then swapped in).
## on_done(error: String) -- "" on success. Returns the first step's
## HTTPRequest (older callers poll it; download_progress() covers the whole
## chain), or null if there was nothing to do / it couldn't start.
func download(id: String, on_done: Callable) -> HTTPRequest:
	var game := get_game(id)
	if game.is_empty():
		_safe_call.call_deferred(on_done, [tr("This game isn't in the catalog.")])
		return null
	if _chains.has(id):
		return _downloads.get(id)
	var steps: Array = []
	for name in missing_media(id):
		steps.append("media:" + name)
	if _pack_needed(id):
		steps.append("game")
	if steps.is_empty():
		_safe_call.call_deferred(on_done, [""])
		return null
	_chains[id] = {"steps": steps, "total": steps.size(), "on_done": on_done}
	_next_step(id)
	return _downloads.get(id)

func _next_step(id: String) -> void:
	var chain = _chains.get(id)
	if chain == null:
		return
	if chain.steps.is_empty():
		_chains.erase(id)
		_safe_call(chain.on_done, [""])
		return
	var step: String = chain.steps[0]
	if step == "game":
		_download_game(id, _on_step_done.bind(id))
	else:
		var http := _download_media(step.trim_prefix("media:"), _on_step_done.bind(id))
		if http != null:
			_downloads[id] = http

func _on_step_done(error: String, id: String) -> void:
	var chain = _chains.get(id)
	if chain == null:
		return  # cancelled
	if not chain.steps.is_empty() and str(chain.steps[0]).begins_with("media:"):
		_downloads.erase(id)
	if error != "":
		_chains.erase(id)
		_safe_call(chain.on_done, [error])
		return
	chain.steps.pop_front()
	_next_step(id)

func _download_game(id: String, on_done: Callable) -> void:
	var game := get_game(id)
	var part_path := _pack_path(id) + ".part"
	var http := HTTPRequest.new()
	http.download_file = part_path
	http.timeout = Config.DOWNLOAD_TIMEOUT
	add_child(http)
	_downloads[id] = http
	http.request_completed.connect(_on_download_completed.bind(id, int(game.version), part_path, http, on_done))
	if http.request(game.url) != OK:
		_on_download_completed.call_deferred(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), id, int(game.version), part_path, http, on_done)

## Stops a download(). A shared media pack already on its way keeps
## downloading in the background (another game may need it, and it's
## mounted for next time); only the game's own pack is aborted.
func cancel_download(id: String) -> void:
	var chain = _chains.get(id)
	_chains.erase(id)
	var http: HTTPRequest = _downloads.get(id)
	if http == null:
		return
	_downloads.erase(id)
	if chain != null and not chain.steps.is_empty() and str(chain.steps[0]).begins_with("media:"):
		return
	http.cancel_request()
	http.queue_free()
	DirAccess.remove_absolute(_pack_path(id) + ".part")

func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray,
		id: String, version: int, part_path: String, http: HTTPRequest, on_done: Callable) -> void:
	if _downloads.get(id) != http:
		return  # cancelled
	_downloads.erase(id)
	http.queue_free()

	var error := _download_error(result, code, part_path)
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
	_mount_media_for(id)
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

# ---------- media packs ----------

const MEDIA_COMMON := "media-common"
const MEDIA_CAT_PREFIX := "media-cat-"

## Where a media pack's files appear in res:// once mounted.
static func media_root(name: String) -> String:
	if name.begins_with(MEDIA_CAT_PREFIX):
		return "res://media/cat/%s/" % name.trim_prefix(MEDIA_CAT_PREFIX)
	return "res://media/%s/" % name.trim_prefix("media-")

## Names of the media packs this game needs that aren't on the device in a
## version new enough.
func missing_media(id: String) -> Array:
	var out := []
	for req in get_game(id).get("requires_media", []):
		if not _media_bundled.has(req.name) and local_media_version(req.name) < int(req.min):
			out.append(req.name)
	return out

## Highest version of a media pack on disk (0 = none).
func local_media_version(name: String) -> int:
	return int(_local_media().get(name, {}).get("version", 0))

## Downloaded games that need this media pack -- its reference count.
func media_users(name: String) -> Array:
	var out := []
	for id in _games_by_id:
		if not (is_downloaded(id) or _mounted.has(id)):
			continue
		for req in _games_by_id[id].get("requires_media", []):
			if req.name == name:
				out.append(id)
				break
	return out

## name -> {version, path, others: [older paths]} for files in MEDIA_DIR.
func _local_media() -> Dictionary:
	var found := {}
	var pending := _pending_deletes()
	for file in DirAccess.get_files_at(MEDIA_DIR):
		if not file.ends_with(".pck"):
			continue
		var path := MEDIA_DIR.path_join(file)
		if pending.has(path):
			continue
		var stem := file.trim_suffix(".pck")
		var at := stem.rfind(".v")
		if at <= 0 or not stem.substr(at + 2).is_valid_int():
			continue
		var name := stem.substr(0, at)
		var version := stem.substr(at + 2).to_int()
		var cur: Dictionary = found.get(name, {"version": 0, "path": "", "others": []})
		if version > int(cur.version):
			if cur.path != "":
				cur.others.append(cur.path)
			cur.version = version
			cur.path = path
		else:
			cur.others.append(path)
		found[name] = cur
	return found

func _media_path(name: String, version: int) -> String:
	return "%s/%s.v%d.pck" % [MEDIA_DIR, name, version]

## At launch, before anything uses them: drop superseded versions (nothing
## is mounted yet, so deleting is safe), mount the newest of each.
func _mount_local_media() -> void:
	var local := _local_media()
	for name in local:
		for old in local[name].others:
			DirAccess.remove_absolute(old)
		_mount_media_file(name, int(local[name].version), local[name].path)

func _mount_media_file(name: String, version: int, path: String) -> bool:
	if _media_bundled.has(name) or int(_media_mounted.get(name, 0)) >= version:
		return true
	if not _looks_like_pack(path) or not ProjectSettings.load_resource_pack(path, false):
		# Damaged (never the mounted file: that one has a lower version).
		# The next check or tap re-fetches it.
		DirAccess.remove_absolute(path)
		return false
	_media_mounted[name] = version
	return true

## Mounts whatever of this game's media arrived since launch.
func _mount_media_for(id: String) -> void:
	var local := _local_media()
	for req in get_game(id).get("requires_media", []):
		if local.has(req.name):
			_mount_media_file(req.name, int(local[req.name].version), local[req.name].path)

## Silent upkeep: every downloaded game's media present and current.
func _check_media() -> void:
	var wanted := {}
	for id in _games_by_id:
		if not is_downloaded(id) or _bundled.has(id):
			continue
		for req in _games_by_id[id].get("requires_media", []):
			wanted[req.name] = true
	for name in wanted:
		if media_packs.has(name) and not _media_bundled.has(name) \
				and local_media_version(name) < int(media_packs[name].version):
			_download_media(name, Callable())

## Downloads one media pack (shared: callers asking for one already on its
## way just wait for it). on_done(error: String).
func _download_media(name: String, on_done: Callable) -> HTTPRequest:
	var info: Dictionary = media_packs.get(name, {})
	if info.is_empty():
		_safe_call.call_deferred(on_done, [tr("Download failed. Check your connection and try again.")])
		return null
	if not _media_waiters.has(name):
		_media_waiters[name] = []
	_media_waiters[name].append(on_done)
	if _media_downloads.has(name):
		return _media_downloads[name]
	var part := _media_path(name, int(info.version)) + ".part"
	var http := HTTPRequest.new()
	http.download_file = part
	http.timeout = Config.DOWNLOAD_TIMEOUT
	add_child(http)
	_media_downloads[name] = http
	http.request_completed.connect(_on_media_completed.bind(name, int(info.version), str(info.sha256), part, http))
	if http.request(str(info.url)) != OK:
		_on_media_completed.call_deferred(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), name, int(info.version), str(info.sha256), part, http)
	return http

func _on_media_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray,
		name: String, version: int, sha256: String, part: String, http: HTTPRequest) -> void:
	if _media_downloads.get(name) != http:
		return
	_media_downloads.erase(name)
	http.queue_free()
	var error := _download_error(result, code, part)
	if error == "" and sha256 != "" and FileAccess.get_sha256(part) != sha256:
		error = tr("The download was damaged. Please try again.")
	if error == "":
		var final_path := _media_path(name, version)
		if FileAccess.file_exists(final_path):
			DirAccess.remove_absolute(final_path)  # never mounted: an equal version would not be fetched
		if DirAccess.rename_absolute(part, final_path) != OK:
			error = tr("Couldn't save the download. Check your free space.")
		elif not _mount_media_file(name, version, final_path):
			error = tr("The download was damaged. Please try again.")
	if error != "":
		DirAccess.remove_absolute(part)
	var waiters: Array = _media_waiters.get(name, [])
	_media_waiters.erase(name)
	for cb in waiters:
		_safe_call(cb, [error])

# ---------- storage ----------

## Everything downloaded, biggest first: [{kind: "game"|"media", id, bytes,
## users (media: games needing it), mounted (in use this session)}].
## Games list archived and unknown ids too (their files still take space).
func storage_items() -> Array:
	var items := []
	var pending := _pending_deletes()
	for file in DirAccess.get_files_at(PACKS_DIR):
		var path := PACKS_DIR.path_join(file)
		if not file.ends_with(".pck") or pending.has(path):
			continue
		var id := file.trim_suffix(".pck")
		items.append({"kind": "game", "id": id, "bytes": _file_size(path), "users": [], "mounted": _mounted.has(id)})
	var local := _local_media()
	for name in local:
		var bytes := 0
		for path in [local[name].path] + local[name].others:
			bytes += _file_size(path)
		items.append({"kind": "media", "id": name, "bytes": bytes, "users": media_users(name),
				"mounted": _media_mounted.has(name)})
	items.sort_custom(func(a, b): return a.bytes > b.bytes)
	return items

## Deletes a downloaded pack. Returns "" (deleted), "later" (in use this
## session: deleted on the next launch) or a reason it can't be deleted.
## Never touches saves or stats.
func delete_pack(kind: String, id: String) -> String:
	if kind == "media":
		if not media_users(id).is_empty():
			return tr("Games you have downloaded still use this.")
		var local := _local_media()
		if not local.has(id):
			return ""
		var paths: Array = [local[id].path] + local[id].others
		if _media_mounted.has(id):
			_defer_delete(paths)
			return "later"
		for path in paths:
			DirAccess.remove_absolute(path)
		return ""
	if _downloads.has(id) or _chains.has(id):
		return tr("This game is downloading.")
	_set_local_version(id, 0)
	if _mounted.has(id):
		_defer_delete([_pack_path(id)])
		return "later"
	DirAccess.remove_absolute(_pack_path(id))
	return ""

func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return 0 if f == null else int(f.get_length())

func _pending_deletes() -> Dictionary:
	var data = SaveUtil.read(PENDING_DELETE_PATH)
	var out := {}
	if data != null and typeof(data.get("paths")) == TYPE_ARRAY:
		for p in data.paths:
			out[str(p)] = true
	return out

func _defer_delete(paths: Array) -> void:
	var all := _pending_deletes()
	for p in paths:
		all[str(p)] = true
	SaveUtil.write(PENDING_DELETE_PATH, {"paths": all.keys()})

## At launch, before anything is mounted.
func _run_pending_deletes() -> void:
	for path in _pending_deletes():
		if path.begins_with(PACKS_DIR):
			DirAccess.remove_absolute(path)
	if FileAccess.file_exists(PENDING_DELETE_PATH):
		DirAccess.remove_absolute(PENDING_DELETE_PATH)

# ---------- app update ----------

## on_newer(remote_version: String, apk_url: String) fires only if GitHub's
## latest release is newer than this build and has an APK attached.
## Otherwise on_none(reached: bool) fires, if given -- reached is false when
## GitHub couldn't be asked (offline). The Options screen's "Check for
## updates" uses it; the hub's silent launch check doesn't.
func check_app_update(on_newer: Callable, on_none: Callable = Callable()) -> void:
	app_update_checked = true
	_get_json(Config.LATEST_RELEASE_API, func(parsed):
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("tag_name"):
			_safe_call(on_none, [false])
			return
		var remote_version: String = str(parsed.tag_name).trim_prefix("v")
		if is_newer_version(remote_version, Version.VERSION):
			for asset in parsed.get("assets", []):
				if typeof(asset) == TYPE_DICTIONARY and str(asset.get("name", "")).ends_with(".apk"):
					_safe_call(on_newer, [remote_version, str(asset.get("browser_download_url", ""))])
					return
		_safe_call(on_none, [true])
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

## "" if a finished download is a good .pck, else what to tell the player.
func _download_error(result: int, code: int, part_path: String) -> String:
	if result == HTTPRequest.RESULT_TIMEOUT:
		return tr("The download timed out. Check your connection and try again.")
	if result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN or result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		return tr("Couldn't save the download. Check your free space.")
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return tr("Download failed. Check your connection and try again.")
	if not _looks_like_pack(part_path):
		return tr("The download was damaged. Please try again.")
	return ""

func _looks_like_pack(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 4:
		return false
	var magic := f.get_buffer(4).get_string_from_ascii()
	f.close()
	return magic == PACK_MAGIC

## Leftovers from a download the app was killed in the middle of.
func _remove_partial_downloads() -> void:
	for dir in [PACKS_DIR, MEDIA_DIR]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".part"):
				DirAccess.remove_absolute(dir.path_join(file))

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
