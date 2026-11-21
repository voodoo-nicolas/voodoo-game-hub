extends RefCounted

## The hub's game categories (Layout D, owner 2026-11-20): ids, order, labels, rail icons.
## THE one place they are listed: the rail, the Home rows, search and `hub.py check` read
## this file. A game names its category in manifest.json ("category": "<id>") and may add
## lowercase "tags" (["multiplayer", "space", ...]).
##
## Older apps (before 0.43) still read the manifest's old "categories" groups; those stay
## as they are, so the two can differ until every phone updates.

const MIN_GAMES_TO_SHOW := 6   # a category with fewer live games is hidden (Sports at launch: intended)
const ICON_DIR := "res://media/hub/icons/"   # Tabler Icons (MIT), media/CREDITS.json

## id, EN label, ES label, ES short label for the narrow rail (or ""), Tabler icon.
const LIST := [
	{"id": "puzzle", "en": "Puzzle", "es": "Puzles", "es_short": "", "icon": "puzzle"},
	{"id": "board", "en": "Board", "es": "Tablero", "es_short": "", "icon": "chess"},
	{"id": "brain", "en": "Brain training", "es": "Entrenamiento mental", "es_short": "Mente", "icon": "brain"},
	{"id": "cards", "en": "Cards", "es": "Cartas", "es_short": "", "icon": "cards"},
	{"id": "word", "en": "Word", "es": "Palabras", "es_short": "", "icon": "abc"},
	{"id": "dice", "en": "Dice", "es": "Dados", "es_short": "", "icon": "dice-5"},
	{"id": "arcade", "en": "Arcade", "es": "Arcade", "es_short": "", "icon": "device-gamepad-2"},
	{"id": "action", "en": "Action", "es": "Acción", "es_short": "", "icon": "sword"},
	{"id": "adventure", "en": "Adventure", "es": "Aventura", "es_short": "", "icon": "map"},
	{"id": "party", "en": "Party", "es": "Fiesta", "es_short": "", "icon": "confetti"},
	{"id": "sports", "en": "Sports", "es": "Deportes", "es_short": "", "icon": "ball-football"},
]

## A game with no (or an unknown) "category" lands here; `hub.py check` warns.
const FALLBACK := "arcade"

## The manifest's old group names (apps before 0.43) -> the new ids. "Puzzle & Board"
## defaults to board; the owner moves the puzzles by hand.
const FROM_OLD := {
	"Puzzle & Board": "board", "Intelligence": "brain", "Cards": "cards", "Word": "word",
	"Arcade": "arcade", "Adventure": "adventure", "Dice": "dice", "Party": "party",
}

## Which of the hub's existing category pictures / tile colours (HubArt, hub.gd CATEGORY_ART,
## keyed by the old group names) each id borrows until it gets its own.
const ART_GROUP := {
	"puzzle": "Puzzle & Board", "board": "Puzzle & Board", "brain": "Intelligence", "cards": "Cards",
	"word": "Word", "dice": "Dice", "arcade": "Arcade", "action": "Arcade", "adventure": "Adventure",
	"party": "Party", "sports": "Party",
}

static func art_group(id: String) -> String:
	return str(ART_GROUP.get(id, ""))

static func ids() -> Array:
	return LIST.map(func(c): return c.id)

static func is_valid(id: String) -> bool:
	return ids().has(id)

static func info(id: String) -> Dictionary:
	for c in LIST:
		if c.id == id:
			return c
	return {}

## The label in the current language; `short` = the narrow rail's version where one exists.
static func label(id: String, short: bool = false) -> String:
	var c := info(id)
	if c.is_empty():
		return id
	var es := TranslationServer.get_locale().begins_with("es")
	if es and short and str(c.es_short) != "":
		return str(c.es_short)
	return str(c.es) if es else str(c.en)

static func icon_path(name: String) -> String:
	return ICON_DIR + name + ".svg"

static func icon(name: String) -> Texture2D:
	var p := icon_path(name)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
