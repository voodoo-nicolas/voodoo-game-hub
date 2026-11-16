extends RefCounted
## (hub port: static class, no autoload)
## Loads every design table from res://games/hesperia/data/*.json (source of truth, never hard-coded) + slice content.

static var quests: Dictionary = {}
static var items: Dictionary = {}
static var enemies: Dictionary = {}
static var bosses: Dictionary = {}
static var npcs: Dictionary = {}
static var dungeons: Dictionary = {}
static var towns: Dictionary = {}
static var cells: Dictionary = {}
static var counts: Dictionary = {}
static var maps: Dictionary = {}       # slice_maps.json
static var dialogue: Dictionary = {}   # npc id -> {entries:[{if,node}], nodes:{}}
static var quest_defs: Dictionary = {} # slice_quests.json (steps/rewards)
static var shop: Dictionary = {}
static var ui: Dictionary = {}         # key -> {en, es}
static var lang: String = "en"

static func _ready() -> void:
	load_all()

static func _load(fname: String):
	var path := "res://games/hesperia/data/%s.json" % fname
	if not FileAccess.file_exists(path):
		push_error("missing data file " + path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _by_id(arr) -> Dictionary:
	var d := {}
	if arr == null:
		return d
	for e in arr:
		d[e["id"]] = e
	return d

## (not "reload": in the hub port Data is a static class and Script.reload() would wipe it)
static func load_all() -> void:
	quests = _by_id(_load("quests"))
	items = _by_id(_load("items"))
	enemies = _by_id(_load("enemies"))
	bosses = _by_id(_load("bosses"))
	npcs = _by_id(_load("npcs"))
	dungeons = _by_id(_load("dungeons"))
	towns = _by_id(_load("towns"))
	cells = _by_id(_load("cells"))
	counts = _load("counts")
	maps = _load("slice_maps")
	dialogue = _load("slice_dialogue")
	quest_defs = _load("slice_quests")
	shop = _load("slice_shop")
	ui = _load("i18n_ui")

static func tr_ui(key: String) -> String:
	if not ui.has(key):
		return key
	return ui[key].get(lang, ui[key].get("en", key))

## Pick the localised string out of {en, es}.
static func loc(d) -> String:
	if typeof(d) == TYPE_STRING:
		return d
	return d.get(lang, d.get("en", ""))

## Localised name for an id. Table names are English; Spanish overrides live in i18n_ui as "name.<id>".
static func name_of(id: String) -> String:
	var k := "name." + id
	if ui.has(k):
		return tr_ui(k)
	for t in [items, npcs, enemies, bosses, quests]:
		if t.has(id):
			var e = t[id]
			return e.get("name", e.get("title", id))
	return id
