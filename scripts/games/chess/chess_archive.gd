extends RefCounted

## [Phase A 2026-11-25] 📜 My Games: the last finished games (and imported
## PGNs), newest first, kept on this phone in user://chess_games.json (not
## cloud-synced). Each entry: {date, white, black, result ("1-0", "0-1",
## "1/2-1/2"), reason, fen ("" = usual start), ucis, sans, mode}.

const PATH := "user://chess_games.json"
const MAX := 50

static func load_all(path: String = PATH) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Array else []

static func add(entry: Dictionary, path: String = PATH) -> void:
	var all := load_all(path)
	all.push_front(entry)
	while all.size() > MAX:
		all.pop_back()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all))
