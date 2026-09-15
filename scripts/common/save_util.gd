extends RefCounted

## Small JSON-file save/load helper shared by every game.
## Note: JSON has no int type, so everything numeric comes back as float on load --
## callers must cast back to int themselves (see sudoku/solitaire `_load_game`).

static func write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

## Returns the saved Dictionary, or null if there's no save / it's corrupt.
static func read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
