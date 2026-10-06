extends RefCounted

## The hub's own small records (since v0.30, STANDARDS §2): ★ favourites,
## when each game was last opened (the Continue card, "Recently played",
## "Never played") and the total time spent in games (Profile).
## Static helpers over three JSON files; nothing here touches a game's saves.

const FAVORITES_PATH := "user://favorites.json"
const RECENT_PATH := "user://recent_games.json"
const PLAYTIME_PATH := "user://play_time.json"

static func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text) if text != "" else null
	return data if data is Dictionary else {}

static func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

# ---------- favourites ----------

static func favorites() -> Array:
	return _read(FAVORITES_PATH).get("ids", [])

static func is_favorite(id: String) -> bool:
	return favorites().has(id)

static func toggle_favorite(id: String) -> bool:
	var ids: Array = favorites()
	if ids.has(id):
		ids.erase(id)
	else:
		ids.append(id)
	_write(FAVORITES_PATH, {"ids": ids})
	return ids.has(id)

# ---------- recently played ----------

## {id: unix time it was last opened}.
static func recent() -> Dictionary:
	return _read(RECENT_PATH)

static func record_play(id: String) -> void:
	var data := recent()
	data[id] = int(Time.get_unix_time_from_system())
	_write(RECENT_PATH, data)

## The game opened most recently, or "".
static func last_played() -> String:
	var data := recent()
	var best := ""
	for id in data:
		if best == "" or float(data[id]) > float(data[best]):
			best = str(id)
	return best

# ---------- play time ----------

static func play_seconds() -> int:
	return int(_read(PLAYTIME_PATH).get("total", 0))

static func add_play_seconds(s: float) -> void:
	if s <= 0.0 or s > 6 * 3600.0:  # a clock jump, not a session
		return
	var data := _read(PLAYTIME_PATH)
	data["total"] = int(data.get("total", 0)) + int(s)
	_write(PLAYTIME_PATH, data)
