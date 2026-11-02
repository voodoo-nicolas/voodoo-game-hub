extends RefCounted

## Shared sprite library (media/common/sprites/; catalog: docs/claude/sprite-library.md,
## pictures: docs/claude/sprite-sheets/<set>.jpg): ready-made art any game can
## draw -- space ships, lasers, meteors, smoke and explosions, isometric dungeon
## and library pieces, gothic / village / forest / dungeon / cyberpunk pixel art,
## anime and RPG character portraits, retro textures.
##
## GENERATED: `python tools/hub.py sync` copies tools/templates/sprite_lib.gd to
## scripts/games/<id>/sprite_lib.gd for every game that uses it. Edit the
## template, never a copy -- `hub.py check` fails if a copy differs.
##
##     const SpriteLib = preload("res://scripts/games/<id>/sprite_lib.gd")
##     ship.texture = SpriteLib.texture("space/player_ship1_blue")
##     rock.texture = SpriteLib.random("space/meteor_grey_big")     # one of its 4 variants
##     laser.texture = SpriteLib.texture("space/laser_red", 3)      # file laser_red_3.png
##     boom.sprite_frames = SpriteLib.sprite_frames("smoke/explosion", 18.0, false)
##     boom.play()                                                  # AnimatedSprite2D
##
## A sprite id is "<set>/<name>": the file <name>.png, or a numbered series
## <name>_0.png / <name>_1.png... (animation frames, or variants). Numbers are
## the file numbers listed in the catalog (some series start at 0, some at 1).
## **Write every id as a full string literal** in the game's scripts
## ("space/ufo_red", not "space/ufo_" + colour; for a choice, a const Array of
## literals): `sync` finds them there and puts exactly those files in the game's
## pack, so they draw on every app version and the APK stays small.
## `hub.py check` fails on an id that isn't in the library.
##
## Pixel-art sets (textures, gothic, village, forest, dungeon, cyberpunk,
## rpg_characters) look right only with `texture_filter = TEXTURE_FILTER_NEAREST`
## on the node that draws them. Iso pieces sit on 256x512 canvases (mostly
## transparent): place them by the canvas, not the visible bounds.

const DIR := "res://media/common/sprites/"

static var _paths: Dictionary = {}  # id -> Array of res:// paths, in frame order
static var _first: Dictionary = {}  # id -> number of the first file (0 or 1; -1 = one image)
## path -> Texture2D. Keeps every texture handed out alive: a texture only drawn in _draw() and
## not kept by the caller would be freed after the call and draw as a white box.
static var _loaded: Dictionary = {}

## True if the library has this id (no warning when it hasn't).
static func has(id: String) -> bool:
	return not _files(id, false).is_empty()

## The image of an id. For a series: frame `n` by its file number (-1 = the
## first). Null (with a warning) if the id or frame isn't there.
static func texture(id: String, n: int = -1) -> Texture2D:
	var paths := _files(id)
	if paths.is_empty():
		return null
	var i := 0
	if n >= 0 and int(_first[id]) >= 0:
		i = n - int(_first[id])
		if i < 0 or i >= paths.size():
			push_warning("SpriteLib: '%s' has no frame %d" % [id, n])
			return null
	return _tex(paths[i])

## How many images an id has (1 for a single image, 0 if unknown).
static func count(id: String) -> int:
	return _files(id).size()

## Every image of an id, in order (a single image gives one).
static func frames(id: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for path in _files(id):
		out.append(_tex(path))
	return out

## One image of a series at random (variants such as meteors).
static func random(id: String) -> Texture2D:
	var paths := _files(id)
	if paths.is_empty():
		return null
	return _tex(paths[randi() % paths.size()])

## A SpriteFrames for AnimatedSprite2D: the id's images as one animation.
## Pass `into` to add more animations to the same SpriteFrames, e.g. run and
## idle of the iso man: sprite_frames("iso_dungeon/male_0_idle", 1.0, true, "idle", sf).
static func sprite_frames(id: String, fps: float = 12.0, loop: bool = true, anim: String = "default",
		into: SpriteFrames = null) -> SpriteFrames:
	var sf := into if into else SpriteFrames.new()
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	sf.clear(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for tex in frames(id):
		sf.add_frame(anim, tex)
	return sf

static func _tex(path: String) -> Texture2D:
	if not _loaded.has(path):
		_loaded[path] = load(path)
	return _loaded[path]

## Every image of an id, as res:// paths in frame order.
static func _files(id: String, warn: bool = true) -> Array:
	if _paths.has(id):
		return _paths[id]
	var found := []
	var first := -1
	var base := DIR + id
	if ResourceLoader.exists(base + ".png"):
		found.append(base + ".png")
	else:
		for start in [0, 1]:
			var n: int = start
			while ResourceLoader.exists("%s_%d.png" % [base, n]):
				found.append("%s_%d.png" % [base, n])
				n += 1
			if not found.is_empty():
				first = start
				break
	if found.is_empty() and warn:
		push_warning("SpriteLib: no sprite '%s'" % id)
	_paths[id] = found
	_first[id] = first
	return found
