extends RefCounted

## Turned's dialogue runner: story scenes are DATA (turned_dialogues.json), the words are in
## turned_text.gd (Text.DIALOGUE, by id, so they go through es.json). No Nodes: the world feeds
## it the engine (flags, items, Journal, mission) and the clock, and the HUD draws `view()`.
##
## A scene: {"start": "n1", "nodes": {"n1": {...}, ...}}. Node types (default "line"):
##   line    {"speaker": "tavernkeep" | "" (a thought), "text": "id", "next": "n2", "if": [...], "else": "n9", "effects": [...]}
##           (a line whose "if" fails is skipped: it goes to "else", or to "next" when there is no "else")
##   choice  {"speaker": "", "text": "id" (optional prompt), "options": [{"text": "id", "if": [...], "effects": [...], "next": "n3"}]}
##   branch  {"if": [...], "then": "n4", "else": "n5"}      (no screen: picks a path)
##   do      {"effects": [...], "next": "n6"}               (no screen: changes the state)
##   end     {"effects": [...]}                             (the scene is over)
## A node with no "next" ends the scene. "if" is a list, all must hold:
##   flag:x  !flag:x  item:x  !item:x  journal:x  !journal:x  mission:x  hour>=19.5  hour<6  day>=2
## "effects" are applied when the node is shown (an option's when it is chosen):
##   flag:x  unflag:x  item:+x  item:-x  journal:x  mission:x
## Anything else ("hour:21.5" = clock.skip_to, "area:street:spawn", "sfx:name", "scene:<id>" = a painting of
## turned_scenes.json once the scene is over, "card:<id>" = a zoom card of turned_cards.json now) is left in
## `events` for the world. A line may have "mood": "neutral" | "afraid" | "angry" | "tired" (which of the speaker's
## busts the box shows in Scene mode).
## Text ids missing from Text.DIALOGUE show as "TODO <id>" (the owner's rule: mark missing text).

const Text = preload("res://scripts/games/turned/turned_text.gd")

const PATH := "res://scripts/games/turned/turned_dialogues.json"
const MAX_STEPS := 200

static var _shared: Dictionary = {}

## The shipped scenes (cached); a test can pass its own Dictionary to `new`.
static func shipped() -> Dictionary:
	if _shared.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_shared = parsed if typeof(parsed) == TYPE_DICTIONARY else {"_broken": true}
	return _shared

var engine: RefCounted = null
var clock: RefCounted = null
var scenes: Dictionary = {}
var scene_id := ""
var node_id := ""
var active := false
var selected := 0                   # the highlighted option of a choice
var events: Array = []              # effects for the world, in order; the world empties it

func _init(data: Dictionary = {}) -> void:
	scenes = data if not data.is_empty() else shipped()

## Starts a scene; false if there is no such scene.
func start(id: String) -> bool:
	if not scenes.has(id) or not (scenes[id] as Dictionary).has("start"):
		return false
	scene_id = id
	active = true
	selected = 0
	_enter(str(scenes[id]["start"]))
	return true

func stop() -> void:
	active = false
	scene_id = ""
	node_id = ""

func _node(id: String) -> Dictionary:
	var nodes: Dictionary = (scenes.get(scene_id, {}) as Dictionary).get("nodes", {})
	return nodes.get(id, {})

## Moves to a node, running the silent ones (do, branch, end) and any whose condition fails.
func _enter(id: String) -> void:
	var steps := 0
	while active and steps < MAX_STEPS:
		steps += 1
		if id == "" or not (((scenes[scene_id] as Dictionary).get("nodes", {}) as Dictionary).has(id)):
			stop()
			return
		var n := _node(id)
		match str(n.get("type", "line")):
			"do":
				apply(n.get("effects", []))
				id = str(n.get("next", ""))
			"branch":
				id = str(n.get("then", "")) if holds(n.get("if", [])) else str(n.get("else", ""))
			"end":
				apply(n.get("effects", []))
				stop()
				return
			"choice":
				node_id = id
				selected = 0
				apply(n.get("effects", []))
				if visible_options().is_empty():
					stop()
				return
			_:
				if not holds(n.get("if", [])):
					id = str(n.get("else", n.get("next", "")))      # the line is skipped
					continue
				node_id = id
				apply(n.get("effects", []))
				return
	stop()

# ---------------------------------------------------------------- what the screen shows

## {"kind": "line" | "choice", "speaker": id or "", "speaker_name": English, "text": English,
##  "options": [English], "selected": index}. Empty when no scene runs.
func view() -> Dictionary:
	if not active:
		return {}
	var n := _node(node_id)
	var is_choice := str(n.get("type", "line")) == "choice"
	var opts: Array = []
	if is_choice:
		for o in visible_options():
			opts.append(line_text(str(o.get("text", ""))))
	var spk := str(n.get("speaker", ""))
	return {
		"kind": "choice" if is_choice else "line",
		"speaker": spk,
		"speaker_name": str(Text.SPEAKERS.get(spk, spk.capitalize())) if spk != "" else "",
		"text": line_text(str(n.get("text", ""))) if n.has("text") else "",
		"mood": str(n.get("mood", "neutral")),
		"options": opts,
		"selected": selected,
	}

static func line_text(id: String) -> String:
	return str(Text.DIALOGUE.get(id, "TODO " + id))

## The options whose condition holds, in order.
func visible_options() -> Array:
	var out: Array = []
	for o in (_node(node_id).get("options", []) as Array):
		if holds((o as Dictionary).get("if", [])):
			out.append(o)
	return out

# ---------------------------------------------------------------- input

## A on a line: go on. A on a choice: take the highlighted option.
func advance() -> void:
	if not active:
		return
	var n := _node(node_id)
	if str(n.get("type", "line")) == "choice":
		choose(selected)
	else:
		_enter(str(n.get("next", "")))

## Up/down on a choice (-1 / +1), wrapping.
func move(step: int) -> void:
	var count := visible_options().size()
	if active and count > 1:
		selected = posmod(selected + step, count)

func choose(i: int) -> void:
	var opts := visible_options()
	if not active or i < 0 or i >= opts.size():
		return
	var o: Dictionary = opts[i]
	apply(o.get("effects", []))
	_enter(str(o.get("next", "")))

# ---------------------------------------------------------------- conditions and effects

func holds(conds: Variant) -> bool:
	for c in (conds as Array if typeof(conds) == TYPE_ARRAY else []):
		if not _holds_one(str(c)):
			return false
	return true

func _holds_one(c: String) -> bool:
	var neg := c.begins_with("!")
	if neg:
		c = c.substr(1)
	var r := false
	if c.begins_with("flag:"):
		r = engine != null and engine.has_flag(c.substr(5))
	elif c.begins_with("item:"):
		r = engine != null and engine.has_item(c.substr(5))
	elif c.begins_with("journal:"):
		r = engine != null and (c.substr(8) in engine.journal)
	elif c.begins_with("mission:"):
		r = engine != null and engine.mission == c.substr(8)
	elif c.begins_with("hour>=") or c.begins_with("hour<") or c.begins_with("day>="):
		r = _clock_holds(c)
	return r != neg

func _clock_holds(c: String) -> bool:
	if clock == null:
		return false
	if c.begins_with("hour>="):
		return float(clock.hour) >= c.substr(6).to_float()
	if c.begins_with("hour<"):
		return float(clock.hour) < c.substr(5).to_float()
	return int(clock.day) >= int(c.substr(5).to_int())

func apply(effects: Variant) -> void:
	for e in (effects as Array if typeof(effects) == TYPE_ARRAY else []):
		var s := str(e)
		if s.begins_with("flag:"):
			if engine != null:
				engine.set_flag(s.substr(5))
		elif s.begins_with("unflag:"):
			if engine != null:
				engine.clear_flag(s.substr(7))
		elif s.begins_with("item:+"):
			if engine != null:
				engine.add_item(s.substr(6))
		elif s.begins_with("item:-"):
			if engine != null:
				engine.remove_item(s.substr(6))
		elif s.begins_with("journal:"):
			if engine != null:
				engine.add_journal(s.substr(8))
		elif s.begins_with("mission:"):
			if engine != null:
				engine.set_mission(s.substr(8))
		else:
			events.append(s)

func take_events() -> Array:
	var e := events
	events = []
	return e

# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {"scene": scene_id, "node": node_id, "sel": selected} if active else {}

## Puts a scene back where it was (without re-running the node's effects: the engine was saved
## with them already applied). A scene that no longer exists is dropped.
func from_dict(d: Dictionary) -> void:
	stop()
	var sid := str(d.get("scene", ""))
	if sid == "" or not scenes.has(sid):
		return
	scene_id = sid
	node_id = str(d.get("node", ""))
	if _node(node_id).is_empty():
		stop()
		return
	active = true
	selected = int(d.get("sel", 0))

# ---------------------------------------------------------------- checking the data (tests)

const _COND_PREFIXES := ["flag:", "item:", "journal:", "mission:", "hour>=", "hour<", "day>="]
const _EFFECT_PREFIXES := ["flag:", "unflag:", "item:+", "item:-", "journal:", "mission:", "hour:", "area:", "sfx:", "scene:", "card:", "hold:", "hurt:", "throb", "hunger:", "to_be_continued"]
const MOODS := ["neutral", "afraid", "angry", "tired"]

## Problems in a set of scenes (empty = fine): unknown targets, text ids without text,
## unknown speakers, malformed conditions and effects, a choice with no options.
static func validate(data: Dictionary) -> Array:
	var errs: Array = []
	for sid in data:
		var sc: Dictionary = data[sid]
		var nodes: Dictionary = sc.get("nodes", {})
		if not nodes.has(str(sc.get("start", ""))):
			errs.append("%s: no start node" % sid)
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			var where := "%s/%s" % [sid, nid]
			var t := str(n.get("type", "line"))
			if not t in ["line", "choice", "branch", "do", "end"]:
				errs.append("%s: unknown type %s" % [where, t])
			for key in ["next", "then", "else"]:
				if n.has(key) and str(n[key]) != "" and not nodes.has(str(n[key])):
					errs.append("%s: %s -> %s does not exist" % [where, key, n[key]])
			_check_node_bits(n, nodes, where, errs)
			if t == "choice":
				var opts: Array = n.get("options", [])
				if opts.is_empty():
					errs.append("%s: a choice with no options" % where)
				for i in opts.size():
					var o: Dictionary = opts[i]
					var ow := "%s option %d" % [where, i]
					if not o.has("text"):
						errs.append("%s: no text" % ow)
					_check_node_bits(o, nodes, ow, errs)
					if o.has("next") and str(o["next"]) != "" and not nodes.has(str(o["next"])):
						errs.append("%s: next -> %s does not exist" % [ow, o["next"]])
			elif t == "line" and not n.has("text"):
				errs.append("%s: a line with no text" % where)
	return errs

static func _check_node_bits(n: Dictionary, _nodes: Dictionary, where: String, errs: Array) -> void:
	if n.has("text") and not Text.DIALOGUE.has(str(n["text"])):
		errs.append("%s: text id '%s' is not in Text.DIALOGUE" % [where, n["text"]])
	if n.has("mood") and not str(n["mood"]) in MOODS:
		errs.append("%s: unknown mood '%s'" % [where, n["mood"]])
	var spk := str(n.get("speaker", ""))
	if spk != "" and not Text.SPEAKERS.has(spk):
		errs.append("%s: speaker '%s' is not in Text.SPEAKERS" % [where, spk])
	for c in (n.get("if", []) as Array):
		var s := str(c).trim_prefix("!")
		if not _starts_with_any(s, _COND_PREFIXES):
			errs.append("%s: bad condition '%s'" % [where, c])
	for e in (n.get("effects", []) as Array):
		if not _starts_with_any(str(e), _EFFECT_PREFIXES):
			errs.append("%s: bad effect '%s'" % [where, e])

static func _starts_with_any(s: String, prefixes: Array) -> bool:
	for p in prefixes:
		if s.begins_with(p):
			return true
	return false
