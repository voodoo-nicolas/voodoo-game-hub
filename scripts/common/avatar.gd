extends RefCounted

## Player avatars (Profile, Friends, Player page). An avatar is a short string:
##   "p<n>"          one of PRESETS (an emoji on a colour, drawn in code)
##   "img:<base64>"  a small JPEG (STORE_SIZE px square) the player made in the
##                   avatar editor; the circle is cut at draw time
##   ""              none yet: a neutral silhouette
## Mine is kept in user://avatar.json and, when signed in, sent to friends via
## Social.push_avatar. Only APK-side hub screens use this.

const PATH := "user://avatar.json"
const STORE_SIZE := 256
## Server column limit is 40000 chars of base64: keep the JPEG under this.
const MAX_BYTES := 28000
const PRESETS := [
	["🦊", "#E8742B"], ["🐼", "#4A5A6A"], ["🐸", "#3E9B4F"], ["🦉", "#7A5A3A"],
	["🐙", "#2E7DD1"], ["🦄", "#C65BA0"], ["🐲", "#2FA38A"], ["🚀", "#4B6BDB"],
	["⚽", "#2C8A55"], ["🎮", "#2B3A55"], ["⭐", "#D1A22E"], ["💀", "#3A3A44"],
]

const CIRCLE_SHADER := """
shader_type canvas_item;
void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(0.485, 0.5, length(UV - vec2(0.5)));
}
"""

static var _shader: Shader

static func circle_material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CIRCLE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m

## A round avatar `size` px wide.
static func make(avatar: String, size: float = 64.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if avatar.begins_with("img:"):
		var tex := texture_from(avatar)
		if tex != null:
			var pic := TextureRect.new()
			pic.texture = tex
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_SCALE
			pic.material = circle_material()
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pic.set_anchors_preset(Control.PRESET_FULL_RECT)
			holder.add_child(pic)
			return holder
	var emoji := "👤"
	var color := Color("#3A4A66")
	if avatar.length() > 1 and avatar.begins_with("p") and avatar.substr(1).is_valid_int():
		var i := int(avatar.substr(1))
		if i >= 0 and i < PRESETS.size():
			emoji = PRESETS[i][0]
			color = Color(PRESETS[i][1])
	var disc := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size / 2.0))
	sb.set_border_width_all(2)
	sb.border_color = color.lightened(0.35)
	disc.add_theme_stylebox_override("panel", sb)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(disc)
	var l := Label.new()
	l.text = emoji
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", int(size * 0.55))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(l)
	return holder

static func texture_from(avatar: String) -> ImageTexture:
	if not avatar.begins_with("img:"):
		return null
	var bytes := Marshalls.base64_to_raw(avatar.substr(4))
	var img := Image.new()
	if bytes.is_empty() or img.load_jpg_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(img)

## Encodes a square image as an "img:" avatar under MAX_BYTES, or "" if it
## can't be made small enough. Re-encoding drops any EXIF/metadata.
static func encode(image: Image) -> String:
	var img := image.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() != STORE_SIZE or img.get_height() != STORE_SIZE:
		img.resize(STORE_SIZE, STORE_SIZE, Image.INTERPOLATE_LANCZOS)
	for q in [0.85, 0.75, 0.65, 0.5]:
		var bytes := img.save_jpg_to_buffer(q)
		if bytes.size() <= MAX_BYTES:
			return "img:" + Marshalls.raw_to_base64(bytes)
	return ""

# ---------- my avatar ----------

static func mine() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return str(data.get("avatar", "")) if data is Dictionary else ""

static func save_mine(avatar: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"avatar": avatar}))
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var social = (loop as SceneTree).root.get_node_or_null("Social")
		if social != null:
			social.push_avatar(avatar)
