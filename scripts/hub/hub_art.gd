extends RefCounted

## Art for the Netflix-style Game Browser (Settings.hub_layout == "new").
## Lives in the hub (APK), not in a game's pack: media/hub/game_art/<id>/tile.webp
## (16:9, 320x180) and hero.webp (1080x1200, focal point in the upper half), or the
## manifest game's optional "tile_art" / "hero_art" (res:// paths). A game with
## neither gets a fallback: its emoji over a gradient of its category colour.
## Make art: tools/make_hub_art.py.

const DIR := "res://media/hub/game_art/"

## Fallback gradient per category (English name). Blue/teal/amber, no purple.
const CATEGORY_COLORS := {
	"Puzzle & Board": Color("3a8cff"), "Intelligence": Color("29e6c8"), "Cards": Color("3ddc84"),
	"Word": Color("ffc83a"), "Arcade": Color("ff4f9a"), "Adventure": Color("ff8a2b"),
	"Dice": Color("ff6a3a"), "Party": Color("ff4fd0"),
}
const DEFAULT_COLOR := Color("3a8cff")

static var _gradients: Dictionary = {}

static func category_color(category_name: String) -> Color:
	return CATEGORY_COLORS.get(category_name, DEFAULT_COLOR)

static func tile_path(game: Dictionary) -> String:
	return _path(game, "tile_art", "tile.webp")

static func hero_path(game: Dictionary) -> String:
	return _path(game, "hero_art", "hero.webp")

static func _path(game: Dictionary, field: String, file: String) -> String:
	var custom := str(game.get(field, ""))
	if custom != "" and ResourceLoader.exists(custom):
		return custom
	var id := str(game.get("id", ""))
	if id == "":
		return ""
	var p := DIR + id + "/" + file
	return p if ResourceLoader.exists(p) else ""

## The picture, or null (use fallback_gradient + the emoji).
static func tile(game: Dictionary) -> Texture2D:
	return _load(tile_path(game))

static func hero(game: Dictionary) -> Texture2D:
	return _load(hero_path(game))

static func has_art(game: Dictionary) -> bool:
	return tile_path(game) != "" and hero_path(game) != ""

static func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if path != "" else null

## Vertical gradient, bright at the top to dark at the bottom, cached per colour.
static func fallback_gradient(color: Color) -> Texture2D:
	var key := color.to_html()
	if not _gradients.has(key):
		var g := Gradient.new()
		g.set_color(0, color.darkened(0.15))
		g.set_color(1, color.darkened(0.8))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 8
		t.height = 64
		_gradients[key] = t
	return _gradients[key]

## Transparent at the top to near-black at the bottom: the hero's text scrim.
static func scrim() -> Texture2D:
	if not _gradients.has("scrim"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.88)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 8
		t.height = 128
		_gradients["scrim"] = t
	return _gradients["scrim"]

## Left-to-right fade (opaque to transparent) for the row edges.
static func edge_fade(color: Color, from_left: bool) -> Texture2D:
	var key := "edge%s%s" % [color.to_html(), from_left]
	if not _gradients.has(key):
		var g := Gradient.new()
		g.set_color(0, Color(color, color.a if from_left else 0.0))
		g.set_color(1, Color(color, 0.0 if from_left else color.a))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.0, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 8
		_gradients[key] = t
	return _gradients[key]

## Dark on the left, fading to nothing at 45% of the width: the detail text's backdrop.
static func scrim_left() -> Texture2D:
	if not _gradients.has("scrim_left"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.0, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 8
		_gradients["scrim_left"] = t
	return _gradients["scrim_left"]

## Transparent at the top to ~75% black at the bottom: behind the bar + strip only.
static func scrim_bottom() -> Texture2D:
	if not _gradients.has("scrim_bottom"):
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 0.75))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 8
		t.height = 128
		_gradients["scrim_bottom"] = t
	return _gradients["scrim_bottom"]
