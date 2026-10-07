extends Node

## The downloaded half of the Music autoload: music.gd adds this as a child
## and asks it for real tracks before falling back to its synthesized ones.
## The owner fills the library from their PC with Viral Music Drop
## (tools/music_drop/) -- no APK, pack or code change per track.
##
## - The list: media/music/music.json on GitHub (Config.MUSIC_LIST_URL),
##   fetched once per app start and cached in user://music/music.json, so a
##   track the owner adds reaches installed apps on their next launch. Each
##   track: {id, title, genre, pace, file, size, sha256, duration,
##   loop_start, credit{author, licence_name, url, text...}}; pace slow /
##   moderate / fast = Music's styles calm / lively / techno (PACE_OF). The
##   files are on the GitHub release in the list's base_url.
## - A track is downloaded only when a game wants its pace (and genre):
##   to user://music/<file>.part, checked (size + sha256), then renamed. It
##   plays straight from that file with AudioStreamOggVorbis.load_from_file,
##   so nothing is imported or bundled.
## - "play" (the tool's "Where it plays" tab) says where music plays:
##   "hub", "category:<English name>", "game:<id>" -> {style, genres}.
##   style: "" (the game decides) | calm | lively | techno (plays by itself)
##   | off (no music at all); genres: [] = any. Field by field, a game's own
##   entry wins over its category's. setting_for(scene) answers it.
## - Downloads are capped at MAX_CACHE_BYTES: the tracks played longest ago
##   go first. Options → Storage shows the total and can clear it.
## - The browser build reads the list (raw.githubusercontent.com allows
##   browsers), so "Where it plays" works there with the synthesized music,
##   but downloads nothing: GitHub release downloads send no CORS headers.
##   `enabled` (= downloads on) is false there.

signal track_ready(id: String)
signal list_changed

const Config = preload("res://scripts/common/config.gd")
const DIR := "user://music/"
const LIST_CACHE := "user://music/music.json"
const PLAYED_PATH := "user://music/played.json"
const MAX_CACHE_BYTES := 150 * 1024 * 1024
## Loaded tracks kept in memory (each about the size of its file).
const MAX_STREAMS := 6
const PACE_OF := {"calm": "slow", "lively": "moderate", "techno": "fast"}
const GAMES_DIR := "res://scenes/games/"
const SAFE_FILE := "^[a-z0-9][a-z0-9-]*\\.ogg$"

var enabled := true
var tracks: Array = []
var play_map: Dictionary = {}
var base_url := ""
var _by_id := {}
var _ok := {}           # id -> true once its file was checked this session
var _streams := {}      # id -> AudioStream, most recent last
var _queue: Array = []  # ids waiting to download
var _failed := {}       # ids whose download failed this session
var _http: HTTPRequest = null
var _downloading := ""
var _played := {}       # id -> unix time it last started playing
var _file_re := RegEx.create_from_string(SAFE_FILE)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not OS.has_feature("web")
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".part"):
			DirAccess.remove_absolute(DIR + f)
	var p = _read_json(PLAYED_PATH)
	_played = p if p is Dictionary else {}
	_apply(_read_json(LIST_CACHE))
	_fetch_list()

# ---------- the list ----------

func _fetch_list() -> void:
	var http := HTTPRequest.new()
	http.timeout = Config.HTTP_TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_list_fetched.bind(http))
	if http.request(Config.MUSIC_LIST_URL, ["User-Agent: Voodoo-App"]) != OK:
		http.queue_free()

func _on_list_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # offline or no list yet: keep the cached one
	var text := body.get_string_from_utf8()
	if _apply(JSON.parse_string(text)):
		var f := FileAccess.open(LIST_CACHE, FileAccess.WRITE)
		if f:
			f.store_string(text)
		_forget_removed()
		list_changed.emit()

## Adopts a list; false (changing nothing) if it doesn't look right, so one
## bad push can't break the music.
func _apply(data) -> bool:
	if not data is Dictionary or not data.get("tracks") is Array:
		return false
	var url := str(data.get("base_url", ""))
	if not url.begins_with("https://"):
		return false
	var good: Array = []
	var by_id := {}
	var files := {}
	for t in data.tracks:
		if not t is Dictionary:
			continue
		var id := str(t.get("id", ""))
		var file := str(t.get("file", ""))
		if id == "" or by_id.has(id) or files.has(file) or not PACE_OF.values().has(str(t.get("pace", ""))) \
				or _file_re.search(file) == null or int(t.get("size", 0)) <= 0 \
				or str(t.get("sha256", "")).length() != 64:
			continue
		good.append(t)
		by_id[id] = t
		files[file] = true
	tracks = good
	_by_id = by_id
	base_url = url
	var pm = data.get("play", {})
	play_map = pm if pm is Dictionary else {}
	return true

## Files of tracks the owner took off the list.
func _forget_removed() -> void:
	if not enabled:
		return
	var keep := {}
	for t in tracks:
		keep[str(t.file)] = true
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".ogg") and not keep.has(f):
			DirAccess.remove_absolute(DIR + f)

# ---------- what to play ----------

## {style, genres} for a screen: its game's entry, then its category's
## ("hub" for every screen outside a game).
func setting_for(scene: Node) -> Dictionary:
	var path := scene.scene_file_path if scene else ""
	var entries: Array = []
	if path.begins_with(GAMES_DIR):
		var id := path.trim_prefix(GAMES_DIR).get_slice("/", 0)
		entries.append(play_map.get("game:" + id, {}))
		entries.append(play_map.get("category:" + _category_of(id), {}))
	else:
		entries.append(play_map.get("hub", {}))
	var style := ""
	var genres: Array = []
	for e in entries:
		if not e is Dictionary:
			continue
		if style == "":
			style = str(e.get("style", ""))
		if genres.is_empty() and e.get("genres") is Array:
			genres = e.genres
	return {"style": style, "genres": genres}

func _category_of(id: String) -> String:
	var cat = get_node_or_null("/root/Catalog")
	if cat == null:
		return ""
	for c in cat.categories:
		for g in c.get("games", []):
			if str(g.get("id", "")) == id:
				return str(c.get("name", ""))
	return ""

## The list's tracks for a Music style, in a stable order. With genres, only
## those genres -- unless none of them has that pace yet.
func candidates(style: String, genres: Array = []) -> Array:
	var pace: String = PACE_OF.get(style, "")
	var out: Array = tracks.filter(func(t): return str(t.pace) == pace)
	if not genres.is_empty():
		var picked := out.filter(func(t): return genres.has(str(t.get("genre", ""))))
		if not picked.is_empty():
			out = picked
	out.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return out

## The candidates already on the phone.
func ready_tracks(style: String, genres: Array = []) -> Array:
	return candidates(style, genres).filter(is_cached) if enabled else []

func is_cached(t: Dictionary) -> bool:
	if not enabled:
		return false
	var id := str(t.get("id", ""))
	if _ok.has(id):
		return true
	var path: String = DIR + str(t.get("file", ""))
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() != int(t.size):
		return false
	_ok[id] = true
	return true

## The track as a stream (loaded once, kept while it's among the last few).
## Loops from loop_start; Music turns looping off when it has another track
## to move on to.
func stream_of(t: Dictionary) -> AudioStream:
	var id := str(t.id)
	if _streams.has(id):
		var loaded: AudioStream = _streams[id]
		_streams.erase(id)
		_streams[id] = loaded
		return loaded
	if not is_cached(t):
		return null
	var s := AudioStreamOggVorbis.load_from_file(DIR + str(t.file))
	if s == null:
		_ok.erase(id)
		DirAccess.remove_absolute(DIR + str(t.file))
		return null
	s.loop = true
	s.loop_offset = clampf(float(t.get("loop_start", 0.0)), 0.0, maxf(float(t.get("duration", 0.0)) - 1.0, 0.0))
	_streams[id] = s
	while _streams.size() > MAX_STREAMS:
		_streams.erase(_streams.keys()[0])
	return s

func mark_played(id: String) -> void:
	_played[id] = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(PLAYED_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_played))

# ---------- downloading ----------

## Queues a track's download (one at a time); track_ready(id) when it lands.
func want(t: Dictionary) -> void:
	var id := str(t.get("id", ""))
	if not enabled or id == "" or is_cached(t) or _failed.has(id) or id == _downloading or _queue.has(id):
		return
	_queue.append(id)
	_next_download()

func is_downloading() -> bool:
	return _downloading != ""

func _next_download() -> void:
	if _http != null or _queue.is_empty():
		return
	var id: String = _queue.pop_front()
	var t: Dictionary = _by_id.get(id, {})
	if t.is_empty() or is_cached(t):
		_next_download()
		return
	_downloading = id
	_http = HTTPRequest.new()
	_http.download_file = DIR + str(t.file) + ".part"
	_http.timeout = Config.DOWNLOAD_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_downloaded.bind(id))
	if _http.request(base_url + str(t.file), ["User-Agent: Voodoo-App"]) != OK:
		_on_downloaded(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), id)

func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, id: String) -> void:
	if _http:
		_http.queue_free()
	_http = null
	_downloading = ""
	var t: Dictionary = _by_id.get(id, {})
	var part: String = DIR + str(t.get("file", "x.ogg")) + ".part"
	var good := result == HTTPRequest.RESULT_SUCCESS and code == 200 and not t.is_empty() \
			and FileAccess.file_exists(part) and FileAccess.get_sha256(part) == str(t.sha256)
	if good:
		var final: String = DIR + str(t.file)
		if FileAccess.file_exists(final):
			DirAccess.remove_absolute(final)
		good = DirAccess.rename_absolute(part, final) == OK
	if not good:
		DirAccess.remove_absolute(part)
		_failed[id] = true  # try again next app start, not in a loop now
	else:
		_ok[id] = true
		_trim_cache(id)
		track_ready.emit(id)
	_next_download()

## Over the cap: drop the tracks played longest ago (never `keep`, never
## one loaded right now).
func _trim_cache(keep: String) -> void:
	var have: Array = tracks.filter(is_cached)
	var total := 0
	for t in have:
		total += int(t.size)
	have.sort_custom(func(a, b): return int(_played.get(str(a.id), 0)) < int(_played.get(str(b.id), 0)))
	for t in have:
		if total <= MAX_CACHE_BYTES:
			break
		if str(t.id) == keep or _streams.has(str(t.id)):
			continue
		DirAccess.remove_absolute(DIR + str(t.file))
		_ok.erase(str(t.id))
		total -= int(t.size)

# ---------- Options: storage + credits ----------

## {count, bytes} of the music on the phone.
func storage() -> Dictionary:
	var count := 0
	var bytes := 0
	if enabled:
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".ogg"):
				var fa := FileAccess.open(DIR + f, FileAccess.READ)
				count += 1
				bytes += fa.get_length() if fa else 0
	return {"count": count, "bytes": bytes}

## Deletes every downloaded track (they come back when a game wants them).
func clear() -> void:
	if not enabled:
		return
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".ogg"):
			DirAccess.remove_absolute(DIR + f)
	_ok.clear()

## One line per track for Options → Credits: [{title, text, url, licence}].
func credits() -> Array:
	var out: Array = []
	for t in tracks:
		var c = t.get("credit", {})
		if c is Dictionary:
			out.append({"title": str(t.get("title", "")), "text": str(c.get("text", "")),
				"url": str(c.get("url", "")), "licence": str(c.get("licence_name", ""))})
	return out

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
