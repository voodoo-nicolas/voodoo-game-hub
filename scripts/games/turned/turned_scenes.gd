extends RefCounted

## Scene mode data (docs/turned/SCENE_MODE_PLAN.md): a scene is a painting plus hotspots, as DATA
## in turned_scenes.json. Words by id in turned_scene_text.gd (+ es.json). No Nodes here: the
## world and turned_scene_view.gd use it, tools/test_turned.gd checks it.
##
## A scene: {"art": "SC-01", "variants": [{"when": [...], "art": "SC-02"}],
##           "hotspots": [{"id": "coat", "label": "hs_coat", "pos": [0.62, 0.55],
##                         "kind": "look" | "exit", "dir": "right" | "left" | "up" | "down" (an exit's arrow),
##                         "when": [...], "once": false, "do": [...]}],
##           "walk_zone": {"area": "house", "rect": [x, y, w, h], "when": [...]}}
## `walk_zone` (optional): walking into that rectangle of a Walk map opens the scene, once its painting
## file exists and its `when` holds; until then the Walk room is used (SCENE_MODE_PLAN.md, "walk_area").
## `pos` is a fraction of the painting, so one file fits every screen. `when` is a list of the
## dialogue runner's conditions (flag: item: journal: mission: hour>= hour< day>=), all must hold.
## `do` actions, in order:
##   look:<id>        a thought (Text LOOKS)          dialogue:<id>   a scene of turned_dialogues.json
##   interact:<id>    what A does on that thing in Walk mode (the coat, the matches, a clue, a Text.LOOKS line)
##   card:<id>        a zoom card (turned_cards.json)
##   scene:<id>       go to another scene             leave           back to walking
##   area:<a>:<spawn> leave Scene mode into a Walk map
##   flag: unflag: item:+ item:- journal: mission:    the dialogue runner's effects
##   hour:<h>  sfx:<name>                             as in the dialogue runner
## Painting files: res://games/turned/art/scenes/<art>.webp|jpg|png; none = a drawn placeholder.

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const SceneText = preload("res://scripts/games/turned/turned_scene_text.gd")
const Cards = preload("res://scripts/games/turned/turned_cards.gd")
const DialogueScript = preload("res://scripts/games/turned/turned_dialogue.gd")
const Text = preload("res://scripts/games/turned/turned_text.gd")

const PATH := "res://scripts/games/turned/turned_scenes.json"
const ART_DIR := "res://games/turned/art/scenes/"
const ART_EXT := ["webp", "jpg", "png"]
const PAINTING_ASPECT := 1536.0 / 1024.0
const _ACTIONS := ["look:", "interact:", "dialogue:", "scene:", "card:", "leave", "area:", "flag:", "unflag:", "item:+", "item:-", "journal:", "mission:", "hour:", "sfx:"]

## Walk-mode things with their own code in turned_world.gd `_interact` (the rest are Text.CLUES / Text.LOOKS).
const WORLD_INTERACTS := ["coat", "matches", "mirror", "scarf", "cellar_door"]

static var _shared: Dictionary = {}

static func shipped() -> Dictionary:
	if _shared.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_shared = parsed if typeof(parsed) == TYPE_DICTIONARY else {"_broken": true}
	return _shared

## The flag that remembers a hotspot was used.
static func seen_flag(scene_id: String, hotspot_id: String) -> String:
	return "seen:%s:%s" % [scene_id, hotspot_id]

## The painting to show now: the first variant whose `when` holds, else the scene's own.
## `holds` is a Callable(conditions: Array) -> bool.
static func pick_art(scene: Dictionary, holds: Callable) -> String:
	for v in (scene.get("variants", []) as Array):
		if holds.call((v as Dictionary).get("when", [])):
			return str((v as Dictionary).get("art", ""))
	return str(scene.get("art", ""))

## The hotspots to show: their `when` holds and, for "once" ones, they were not used yet.
## `seen` is a Callable(flag) -> bool.
static func visible_hotspots(scene_id: String, scene: Dictionary, holds: Callable, seen: Callable) -> Array:
	var out: Array = []
	for h in (scene.get("hotspots", []) as Array):
		var hs: Dictionary = h
		if not holds.call(hs.get("when", [])):
			continue
		if bool(hs.get("once", false)) and seen.call(seen_flag(scene_id, str(hs.get("id", "")))):
			continue
		out.append(hs)
	return out

## The painting as a texture, or null when the file is not there (a placeholder is drawn).
static func painting(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	for ext in ART_EXT:
		var p: String = ART_DIR + art_id + "." + ext
		if ResourceLoader.exists(p):
			var t = load(p)
			if t is Texture2D:
				return t
	return null

## True when the painting file exists (without loading it).
static func has_painting(art_id: String) -> bool:
	for ext in ART_EXT:
		if art_id != "" and ResourceLoader.exists(ART_DIR + art_id + "." + ext):
			return true
	return false

## The scene whose `walk_zone` holds the point `pos` of Walk map `area_id`, if its `when` holds and its
## painting exists; "" for none. `holds` is a Callable(conditions: Array) -> bool.
static func zone_at(data: Dictionary, area_id: String, pos: Vector2, holds: Callable) -> String:
	for sid in data:
		var z: Dictionary = (data[sid] as Dictionary).get("walk_zone", {})
		if z.is_empty() or str(z.get("area", "")) != area_id:
			continue
		var r: Array = z.get("rect", [])
		if r.size() != 4 or not Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(pos):
			continue
		if holds.call(z.get("when", [])) and has_painting(str((data[sid] as Dictionary).get("art", ""))):
			return str(sid)
	return ""

# ---------------------------------------------------------------- checking the data (tests)

## Problems in a set of scenes (empty = fine): unknown targets and ids, label and look text,
## bad conditions and actions, hotspots outside the safe zone or too close to each other.
static func validate(data: Dictionary) -> Array:
	var errs: Array = []
	var sx := T.arr("scene.safe_x")
	var sy := T.arr("scene.safe_y")
	var dlgs := DialogueScript.shipped()
	for sid in data:
		var sc: Dictionary = data[sid]
		if str(sc.get("art", "")) == "":
			errs.append("%s: no art" % sid)
		for v in (sc.get("variants", []) as Array):
			if str((v as Dictionary).get("art", "")) == "":
				errs.append("%s: a variant with no art" % sid)
			_check_conds((v as Dictionary).get("when", []), "%s variant" % sid, errs)
		if sc.has("walk_zone"):
			var z: Dictionary = sc["walk_zone"]
			var zr: Array = z.get("rect", [])
			if str(z.get("area", "")) == "" or zr.size() != 4 or float(zr[2]) <= 0.0 or float(zr[3]) <= 0.0:
				errs.append("%s: walk_zone needs an area and a rect [x, y, w, h]" % sid)
			_check_conds(z.get("when", []), "%s walk_zone" % sid, errs)
		var seen_ids := {}
		var spots: Array = sc.get("hotspots", [])
		if spots.is_empty():
			errs.append("%s: no hotspots" % sid)
		for h in spots:
			var hs: Dictionary = h
			var hid := str(hs.get("id", ""))
			var where := "%s/%s" % [sid, hid]
			if hid == "" or seen_ids.has(hid):
				errs.append("%s: missing or repeated id" % where)
			seen_ids[hid] = true
			if not SceneText.HOTSPOTS.has(str(hs.get("label", ""))):
				errs.append("%s: label '%s' is not in SceneText.HOTSPOTS" % [where, hs.get("label", "")])
			if not str(hs.get("kind", "look")) in ["look", "exit"]:
				errs.append("%s: unknown kind" % where)
			if not str(hs.get("dir", "right")) in ["right", "left", "up", "down"]:
				errs.append("%s: unknown dir" % where)
			var pos: Array = hs.get("pos", [])
			if pos.size() != 2 or float(pos[0]) < float(sx[0]) or float(pos[0]) > float(sx[1]) or float(pos[1]) < float(sy[0]) or float(pos[1]) > float(sy[1]):
				errs.append("%s: pos %s is outside the safe zone x %s y %s" % [where, pos, sx, sy])
			_check_conds(hs.get("when", []), where, errs)
			if (hs.get("do", []) as Array).is_empty():
				errs.append("%s: does nothing" % where)
			for a in (hs.get("do", []) as Array):
				var s := str(a)
				if not DialogueScript._starts_with_any(s, _ACTIONS):
					errs.append("%s: bad action '%s'" % [where, s])
				elif s.begins_with("scene:") and not data.has(s.substr(6)):
					errs.append("%s: scene '%s' does not exist" % [where, s.substr(6)])
				elif s.begins_with("dialogue:") and not dlgs.has(s.substr(9)):
					errs.append("%s: dialogue '%s' does not exist" % [where, s.substr(9)])
				elif s.begins_with("card:") and Cards.card(s.substr(5)).is_empty():
					errs.append("%s: card '%s' does not exist" % [where, s.substr(5)])
				elif s.begins_with("interact:") and not (s.substr(9) in WORLD_INTERACTS or Text.CLUES.has(s.substr(9)) or Text.LOOKS.has(s.substr(9))):
					errs.append("%s: '%s' is not something Walk mode can do" % [where, s])
				elif s.begins_with("look:") and not SceneText.LOOKS.has(s.substr(5)):
					errs.append("%s: look text '%s' is not in SceneText.LOOKS" % [where, s.substr(5)])
		var min_d := T.f("scene.min_spacing")
		for i in spots.size():
			for j in range(i + 1, spots.size()):
				var a: Array = (spots[i] as Dictionary).get("pos", [0, 0])
				var b: Array = (spots[j] as Dictionary).get("pos", [0, 0])
				var d := Vector2(float(a[0]) * PAINTING_ASPECT, float(a[1])).distance_to(Vector2(float(b[0]) * PAINTING_ASPECT, float(b[1])))
				if d < min_d:
					errs.append("%s: hotspots %s and %s are too close" % [sid, (spots[i] as Dictionary).get("id", i), (spots[j] as Dictionary).get("id", j)])
	return errs

static func _check_conds(conds: Variant, where: String, errs: Array) -> void:
	for c in (conds as Array if typeof(conds) == TYPE_ARRAY else []):
		if not DialogueScript._starts_with_any(str(c).trim_prefix("!"), DialogueScript._COND_PREFIXES):
			errs.append("%s: bad condition '%s'" % [where, c])
