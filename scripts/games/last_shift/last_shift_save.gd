extends RefCounted

## Save / resume for Last Shift. Room-based checkpoints: the game is saved every time Nash
## enters a room (and when the app is paused), and "Continue" restarts that room with the
## same story state, health, armor, bag, weapons and money. A finished game clears the save.
## v3 (0.4): armor, difficulty, quests, bodies; saves from before are ignored.

const PATH := "user://last_shift_save.json"
const VERSION := 3
## Shared JSON save helper (in every app version; 90+ games preload it).
const SaveUtil = preload("res://scripts/common/save_util.gd")

## Set by the menu: the world reads this on start ("Continue" = true).
static var continue_requested := false
## Difficulty for a new game (0 Easy, 1 Normal, 2 Hard), set by the menu.
static var new_difficulty := 1

## True if there is a save this version of the game can continue.
static func has_save() -> bool:
	return not read().is_empty()

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## Writes the save. `world` is the world script (reads its state, Nash and checkpoint).
static func save(world: Node) -> void:
	var st: Dictionary = world.state.duplicate(true)
	# Drops and bodies hold Vector2 / Rect2i: store the position as plain numbers.
	var drops: Array = []
	for d in st.drops:
		var data: Dictionary = d.data.duplicate(true)
		var pos: Vector2 = data.pos
		data.erase("pos")
		data.erase("rect")
		data["x"] = pos.x
		data["y"] = pos.y
		drops.append({"room": d.room, "data": data})
	st.drops = drops
	var payload := {
		"v": VERSION,
		"state": st,
		"nash": {"hp": world.nash.hp, "inv": world.nash.inv.to_dict(), "armor": world.nash.armor,
			"armor_kind": world.nash.armor_kind},
		"room": world.checkpoint.room,
		"spawn": world.checkpoint.spawn,
		"drop_count": world._drop_count,
	}
	# Hub: SaveUtil writes a temp file and renames it, so a phone killed mid-write keeps the last
	# checkpoint (STANDARDS N5). (Prototype: FileAccess.open(PATH, WRITE) + store_string.)
	SaveUtil.write(PATH, payload)

## Reads the save into a dictionary (or {} if missing/broken/old). Converts drops back.
static func read() -> Dictionary:
	var parsed = SaveUtil.read(PATH)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("v", 0)) != VERSION:
		return {}
	var st: Dictionary = parsed.state
	var drops: Array = []
	for d in st.get("drops", []):
		var data: Dictionary = d.data
		data["pos"] = Vector2(float(data.x), float(data.y))
		data["rect"] = Rect2i(0, 0, 1, 1)
		data.erase("x")
		data.erase("y")
		if data.has("amount"):
			data["amount"] = int(data.amount)
		for entry in data.get("loot", []):
			entry["n"] = int(entry.n)
		drops.append({"room": d.room, "data": data})
	st["drops"] = drops
	parsed.state = st
	return parsed
