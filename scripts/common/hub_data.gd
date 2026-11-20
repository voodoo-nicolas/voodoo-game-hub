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
	# _write(FAVORITES_PATH, {"ids": ids})
	# Owner 2026-11-20: favorites follow the account to every device. The file keeps when it
	# changed ("at") and whose list it is ("uid", "" = a guest's); signed in, it goes up too.
	var a := _auth()
	var uid: String = str(a.user_id) if a != null and a.is_logged_in() else str(_read(FAVORITES_PATH).get("uid", ""))
	var at := int(Time.get_unix_time_from_system())
	_write(FAVORITES_PATH, {"ids": ids, "at": at, "uid": uid})
	if a != null and a.is_logged_in():
		a.db_call("save_favorites", {"p_ids": ids, "p_changed_at": at}, _ignore)
	return ids.has(id)

# ---------- favourites across devices (needs supabase/migrations/20261120000000_favorites.sql) ----------

## Called on sign-in and when the hub opens. The newest change wins; a guest's favorites
## join the account the first time someone signs in on this device. Without the SQL (or
## offline) nothing happens and favorites stay on the device as before.
static func sync_favorites() -> void:
	var a := _auth()
	if a == null or not a.is_logged_in() or not a.has_method("db_call"):
		return
	a.db_call("load_favorites", {}, _on_cloud_favorites.bind(str(a.user_id)))

static func _on_cloud_favorites(ok: bool, parsed: Variant, uid: String) -> void:
	var a := _auth()
	if not ok or a == null or str(a.user_id) != uid:
		return   # no table yet, offline, or someone else signed in meanwhile
	var cloud: Dictionary = parsed if parsed is Dictionary else {}
	var cloud_ids: Array = cloud.get("ids", []) if cloud.get("ids") is Array else []
	var cloud_at := int(cloud.get("at", 0))
	var local := _read(FAVORITES_PATH)
	var local_ids: Array = local.get("ids", [])
	var local_at := int(local.get("at", 0))
	var local_uid := str(local.get("uid", ""))
	var ids: Array
	var push := false
	if local_uid == "":
		ids = cloud_ids.duplicate()   # a guest's favorites: add them to the account
		for id in local_ids:
			if not ids.has(id):
				ids.append(id)
		push = ids.size() != cloud_ids.size() or cloud.is_empty()
	elif local_uid != uid:
		ids = cloud_ids   # another account's list on this device: show this account's own
	elif cloud.is_empty() or local_at > cloud_at:
		ids = local_ids
		push = true
	else:
		ids = cloud_ids
	var at: int = maxi(local_at, cloud_at) if not push else int(Time.get_unix_time_from_system())
	var changed: bool = ids != local_ids or local_uid != uid
	_write(FAVORITES_PATH, {"ids": ids, "at": at, "uid": uid})
	if push:
		a.db_call("save_favorites", {"p_ids": ids, "p_changed_at": at}, _ignore)
	if changed:
		var tree := Engine.get_main_loop() as SceneTree
		var scene: Node = tree.current_scene if tree else null
		if scene != null and scene.has_method("favorites_synced"):
			scene.favorites_synced()   # the hub redraws its ★ rows

static func _auth() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Auth") if tree else null

static func _ignore(_ok: bool, _parsed: Variant) -> void:
	pass

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
