extends RefCounted

## Zoom cards (docs/turned/SCENE_MODE_PLAN.md, phase S3): a macro picture of a thing (a note, a
## watch, a pocket) in a gold frame with a title and a caption, like the mockups' "Coat Pocket".
## DATA in turned_cards.json, words by id in turned_scene_text.gd (CARDS) + es.json, drawn by
## turned_card_view.gd. The paintings have no writing: a card's `text` is drawn by the game
## (EN and ES) over the picture, inside `text_rect`.
##
## {"cards": {"note": {"art": "CD-03", "kind": "paper", "ink": "dark", "text_rect": [x, y, w, h]}},
##  "items": {"watch": [{"when": ["flag:watch_broken"], "card": "watch_broken"}, {"card": "watch"}]}}
## `art` names a file res://games/turned/art/cards/<art>.webp|jpg|png (1024 x 1024); none = a drawn
## placeholder. `text_rect` is a fraction of the picture. `items` says which card an item in the
## menu's Items tab opens (a string, or a list whose first entry with a holding `when` wins).

const T = preload("res://scripts/games/turned/turned_tuning.gd")
const SceneText = preload("res://scripts/games/turned/turned_scene_text.gd")
const DialogueScript = preload("res://scripts/games/turned/turned_dialogue.gd")

const PATH := "res://scripts/games/turned/turned_cards.json"
const ART_DIR := "res://games/turned/art/cards/"
const ART_EXT := ["webp", "jpg", "png"]

static var _shared: Dictionary = {}

static func shipped() -> Dictionary:
	if _shared.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_shared = parsed if typeof(parsed) == TYPE_DICTIONARY else {"_broken": true}
	return _shared

static func card(id: String, data: Dictionary = {}) -> Dictionary:
	var d: Dictionary = data if not data.is_empty() else shipped()
	return (d.get("cards", {}) as Dictionary).get(id, {})

## The flag that remembers a card was looked at.
static func seen_flag(id: String) -> String:
	return "card_seen:" + id

## The card an item opens now, or "" (`engine` decides the `when` conditions).
static func for_item(item_id: String, engine: RefCounted, data: Dictionary = {}) -> String:
	var d: Dictionary = data if not data.is_empty() else shipped()
	var entry: Variant = (d.get("items", {}) as Dictionary).get(item_id, null)
	if entry == null:
		return ""
	if typeof(entry) == TYPE_STRING:
		return str(entry)
	var judge := DialogueScript.new()
	judge.engine = engine
	for e in (entry as Array):
		if judge.holds((e as Dictionary).get("when", [])):
			return str((e as Dictionary).get("card", ""))
	return ""

## The picture as a texture, or null when the file is not there (a placeholder is drawn).
static func art(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	for ext in ART_EXT:
		var p: String = ART_DIR + art_id + "." + ext
		if ResourceLoader.exists(p):
			var t = load(p)
			if t is Texture2D:
				return t
	return null

# ---------------------------------------------------------------- checking the data (tests)

## Problems (empty = fine): a card with no art, no title or caption, text without words or a rect,
## a rect outside the picture, an item that points at a missing card.
static func validate(data: Dictionary) -> Array:
	var errs: Array = []
	var cards: Dictionary = data.get("cards", {})
	for id in cards:
		var c: Dictionary = cards[id]
		if str(c.get("art", "")) == "":
			errs.append("%s: no art" % id)
		var words: Dictionary = SceneText.CARDS.get(id, {})
		if str(words.get("title", "")) == "":
			errs.append("%s: no title in SceneText.CARDS" % id)
		if str(words.get("caption", "")) == "":
			errs.append("%s: no caption in SceneText.CARDS" % id)
		if c.has("text_rect") and str(words.get("text", "")) == "":
			errs.append("%s: a text_rect but no text" % id)
		if str(words.get("text", "")) != "" and not c.has("text_rect"):
			errs.append("%s: text but no text_rect" % id)
		if c.has("text_rect"):
			var r: Array = c["text_rect"]
			if r.size() != 4 or float(r[0]) < 0.0 or float(r[1]) < 0.0 or float(r[2]) <= 0.0 or float(r[3]) <= 0.0 or float(r[0]) + float(r[2]) > 1.0 or float(r[1]) + float(r[3]) > 1.0:
				errs.append("%s: text_rect %s is not inside the picture" % [id, r])
		if not str(c.get("ink", "dark")) in ["dark", "light"]:
			errs.append("%s: unknown ink" % id)
	for item in (data.get("items", {}) as Dictionary):
		var entry: Variant = data["items"][item]
		var targets: Array = []
		if typeof(entry) == TYPE_STRING:
			targets.append(str(entry))
		else:
			for e in (entry as Array):
				targets.append(str((e as Dictionary).get("card", "")))
				for cnd in ((e as Dictionary).get("when", []) as Array):
					if not DialogueScript._starts_with_any(str(cnd).trim_prefix("!"), DialogueScript._COND_PREFIXES):
						errs.append("item %s: bad condition '%s'" % [item, cnd])
		for tid in targets:
			if not cards.has(tid):
				errs.append("item %s: card '%s' does not exist" % [item, tid])
	return errs
