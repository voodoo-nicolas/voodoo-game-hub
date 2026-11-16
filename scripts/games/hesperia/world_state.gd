extends RefCounted
const QuestEngine = preload("res://scripts/games/hesperia/core/quest_engine.gd")
const SaveEngine = preload("res://scripts/games/hesperia/core/save_engine.gd")
const Data = preload("res://scripts/games/hesperia/data.gd")
## (hub port: static class, no autoload)
## Global game state: flags, inventory, hearts, magic, renown, gilding, active world, position. Save/load.


const SAVE_PATH := "user://hesperia_save.json"
const MAX_HEARTS_START := 3
const MAX_MAGIC_START := 16

static var bus = preload("res://scripts/games/hesperia/ws_bus.gd").new()
static var hero_name: String = "Hero"
static var male: bool = true
static var flags: Dictionary = {}
static var inventory: Dictionary = {}
static var half_hearts: int = 6           # current health in half-hearts
static var max_half_hearts: int = 6       # 3 hearts
static var magic: int = 16
static var max_magic: int = 16
static var renown: int = 0
static var gilding: float = 0.0           # Aurea only
static var world: String = "hesperia"     # hesperia | aurea
static var area: String = "b7"
static var pos: Vector2 = Vector2(256, 400)
static var respawn_area: String = "b7"
static var respawn_pos: Vector2 = Vector2(256, 400)
static var equipped_x: String = ""
static var equipped_y: String = ""
static var play_seconds: float = 0.0
static var quests := QuestEngine.new()

static func _ready() -> void:
	new_state()

static func new_state() -> void:
	hero_name = "Hero"
	male = true
	flags = {}
	inventory = {"obol": 12}
	max_half_hearts = MAX_HEARTS_START * 2
	half_hearts = max_half_hearts
	max_magic = MAX_MAGIC_START
	magic = max_magic
	renown = 0
	gilding = 0.0
	world = "hesperia"
	area = "b7"
	pos = Vector2(256, 400)
	respawn_area = area
	respawn_pos = pos
	equipped_x = ""
	equipped_y = ""
	play_seconds = 0.0
	quests = QuestEngine.new()
	quests.defs = Data.quest_defs
	bus.emit_signal("changed")

# -- flags / items -------------------------------------------------------------------------------
static func has_flag(f: String) -> bool:
	return flags.get(f, false)

static func set_flag(f: String, v: bool = true) -> void:
	if flags.get(f, false) == v:
		return
	flags[f] = v
	if v:
		notify_event("flag:" + f)
	bus.emit_signal("changed")

static func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

static func add_item(id: String, n: int = 1) -> void:
	inventory[id] = item_count(id) + n
	if id != "obol":
		notify_event("item:" + id)
	if is_equippable(id):
		if equipped_x == "":
			equipped_x = id
		elif equipped_y == "" and equipped_x != id:
			equipped_y = id
	bus.emit_signal("changed")

static func remove_item(id: String, n: int = 1) -> bool:
	if item_count(id) < n:
		return false
	inventory[id] = item_count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
		if equipped_x == id:
			equipped_x = ""
		if equipped_y == id:
			equipped_y = ""
	bus.emit_signal("changed")
	return true

static func is_equippable(id: String) -> bool:
	return id in ["torch", "fire_rod", "honey", "nectar"]

static func quest_state(id: String) -> String:
	return quests.state_of(id)

# -- quests --------------------------------------------------------------------------------------
static func start_quest(id: String) -> void:
	if quests.start(id):
		bus.emit_signal("quest_changed", id)
		bus.emit_signal("toast", "%s: %s" % [Data.tr_ui("quest_new"), Data.name_of(id)])
		# latch: flags that are already true complete matching steps immediately
		for f in flags.keys():
			if flags[f]:
				notify_event("flag:" + f)

static func notify_event(ev: String) -> void:
	var ch := quests.notify(ev)
	for id in ch:
		bus.emit_signal("quest_changed", id)
	_pay_rewards()

static func _pay_rewards() -> void:
	while quests.log.size() > 0:
		var q = quests.log.pop_front()
		var r: Dictionary = q["reward"]
		for k in r.get("items", {}).keys():
			add_item(k, int(r["items"][k]))
		for f in r.get("flags", []):
			set_flag(f)
		renown += int(r.get("renown", 0))
		bus.emit_signal("toast", "%s: %s" % [Data.tr_ui("quest_done"), Data.name_of(q["id"])])
		bus.emit_signal("quest_changed", q["id"])
		for n in quests.defs.get(q["id"], {}).get("next", []):
			start_quest(n)

# -- health --------------------------------------------------------------------------------------
static func heal(half: int) -> void:
	half_hearts = min(max_half_hearts, half_hearts + half)
	bus.emit_signal("changed")

static func hurt(half: int) -> bool:   ## returns true if the hero died
	half_hearts = max(0, half_hearts - half)
	bus.emit_signal("changed")
	return half_hearts <= 0

static func use_magic(n: int) -> bool:
	if magic < n:
		return false
	magic -= n
	bus.emit_signal("changed")
	return true

# -- save / load ---------------------------------------------------------------------------------
static func to_dict() -> Dictionary:
	return {
		"hero_name": hero_name, "male": male, "flags": flags, "inventory": inventory,
		"half_hearts": half_hearts, "max_half_hearts": max_half_hearts, "magic": magic, "max_magic": max_magic,
		"renown": renown, "gilding": gilding, "world": world, "area": area,
		"pos": [pos.x, pos.y], "respawn_area": respawn_area, "respawn_pos": [respawn_pos.x, respawn_pos.y],
		"eq_x": equipped_x, "eq_y": equipped_y, "play": play_seconds, "quests": quests.to_dict(),
	}

static func from_dict(d: Dictionary) -> void:
	hero_name = d["hero_name"]
	male = d["male"]
	flags = d["flags"]
	inventory = d["inventory"]
	half_hearts = int(d["half_hearts"])
	max_half_hearts = int(d["max_half_hearts"])
	magic = int(d["magic"])
	max_magic = int(d["max_magic"])
	renown = int(d["renown"])
	gilding = float(d["gilding"])
	world = d["world"]
	area = d["area"]
	pos = Vector2(d["pos"][0], d["pos"][1])
	respawn_area = d["respawn_area"]
	respawn_pos = Vector2(d["respawn_pos"][0], d["respawn_pos"][1])
	equipped_x = d.get("eq_x", "")
	equipped_y = d.get("eq_y", "")
	play_seconds = float(d.get("play", 0.0))
	quests = QuestEngine.new()
	quests.defs = Data.quest_defs
	quests.from_dict(d["quests"])
	for k in inventory.keys():
		inventory[k] = int(inventory[k])   # JSON numbers come back as floats
	bus.emit_signal("changed")

static func save_game() -> bool:
	respawn_area = area
	respawn_pos = pos
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(SaveEngine.pack(to_dict()))
	return true

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func load_game() -> bool:
	if not has_save():
		return false
	var d := SaveEngine.unpack(FileAccess.get_file_as_string(SAVE_PATH))
	if d.is_empty():
		return false
	from_dict(d)
	return true

static func _process(dt: float) -> void:
	play_seconds += dt
