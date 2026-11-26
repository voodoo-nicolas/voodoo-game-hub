extends RefCounted

## [Phase B 2026-11-25] ♟ Ongoing Games: up to MAX games against the computer
## or on one phone kept at once, in user://chess_slots.json. Each slot is
## {id, updated (unix secs), data (the same dictionary chess_save.json holds)}.
## chess_save.json stays "the game ▶ Resume opens" (the kit reads it).

const PATH := "user://chess_slots.json"
const MAX := 6

static func load_all(path: String = PATH) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text) if text != "" else null
	var out: Array = []
	if parsed is Array:
		for s in parsed:
			if s is Dictionary and s.get("data") is Dictionary and str(s.get("id", "")) != "":
				out.append(s)
	return out

static func exists(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)

static func _write(all: Array, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all))

## Newest first.
static func sorted(path: String = PATH) -> Array:
	var all := load_all(path)
	all.sort_custom(func(a, b): return float(a.get("updated", 0)) > float(b.get("updated", 0)))
	return all

static func find(id: String, path: String = PATH) -> Dictionary:
	for s in load_all(path):
		if str(s.id) == id:
			return s
	return {}

static func upsert(id: String, data: Dictionary, path: String = PATH) -> void:
	if id == "":
		return
	var all := load_all(path)
	var entry := {"id": id, "updated": Time.get_unix_time_from_system(), "data": data}
	for i in all.size():
		if str(all[i].id) == id:
			all[i] = entry
			_write(all, path)
			return
	all.append(entry)
	_write(all, path)

static func remove(id: String, path: String = PATH) -> void:
	var all := load_all(path)
	var kept: Array = []
	for s in all:
		if str(s.id) != id:
			kept.append(s)
	_write(kept, path)

static func is_full(path: String = PATH) -> bool:
	return load_all(path).size() >= MAX

static func new_id() -> String:
	return "%d%04d" % [int(Time.get_unix_time_from_system()), randi() % 10000]
