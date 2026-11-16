extends RefCounted
## Art pipeline hook: if res://games/hesperia/art/<id>.png exists it is used, otherwise a coloured placeholder is drawn.
## Drop real sprites in art/ with the same ids (hero_m, hero_f, npc ids, enemy ids, tile ids) - no code change needed.
## Record every asset licence in CREDITS.json.

static var _cache: Dictionary = {}

static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var p := "res://games/hesperia/art/%s.png" % id
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p)
	_cache[id] = t
	return t

static func color_for(id: String) -> Color:
	var h := id.hash()
	return Color.from_hsv(float(h % 360) / 360.0, 0.45, 0.85)

## Draw an actor centred on `pos` (feet at pos + (0, size/2)).
static func actor(ci: CanvasItem, id: String, pos: Vector2, size: float, col: Color, facing: Vector2i = Vector2i(0, 1)) -> void:
	var t := tex(id)
	if t != null:
		ci.draw_texture(t, pos - t.get_size() * 0.5)
		return
	ci.draw_rect(Rect2(pos - Vector2(size * 0.5, size * 0.5), Vector2(size, size)), col)
	ci.draw_rect(Rect2(pos - Vector2(size * 0.5, size * 0.5), Vector2(size, size)), col.darkened(0.5), false, 1.0)
	var eye := Vector2(facing) * size * 0.28
	ci.draw_circle(pos + eye, 1.5, Color.WHITE)

static var _anims: Dictionary = {}
static var _anims_loaded: bool = false

## Animation strip res://games/hesperia/art/<key>.png + metadata in res://games/hesperia/art/anims.json (written by tools/slice_art.py).
## Draws frame for time `t` with feet at pos + (0, feet). want_dir: "left"/"right"/"" - mirrors if the source faces the other way.
## frame < 0 = animate by time; frame >= 0 = hold that frame. Returns false if the strip doesn't exist (caller falls back).
static func anim(ci: CanvasItem, key: String, pos: Vector2, t: float, want_dir: String = "", frame: int = -1, mod: Color = Color.WHITE, feet: float = 4.0) -> bool:
	if not _anims_loaded:
		_anims_loaded = true
		if FileAccess.file_exists("res://games/hesperia/art/anims.json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://games/hesperia/art/anims.json"))
			if d is Dictionary:
				_anims = d
	if not _anims.has(key):
		return false
	var tx := tex(key)
	if tx == null:
		return false
	var m: Dictionary = _anims[key]
	var n := int(m["n"])
	var fw := float(m["fw"])
	var fh := float(m["fh"])
	var f := frame if frame >= 0 else int(t * float(m["fps"])) % n
	var flip: bool = want_dir != "" and (m["faces"] == "left" or m["faces"] == "right") and want_dir != m["faces"]
	var dst := Rect2(pos + Vector2(-fw * 0.5, feet - fh), Vector2(fw, fh))
	if flip:
		dst = Rect2(dst.position + Vector2(fw, 0), Vector2(-fw, fh))
	ci.draw_texture_rect_region(tx, dst, Rect2(f * fw, 0, fw, fh), mod)
	return true

static func label(ci: CanvasItem, text: String, pos: Vector2, size: int = 8, col: Color = Color.WHITE) -> void:
	ci.draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
