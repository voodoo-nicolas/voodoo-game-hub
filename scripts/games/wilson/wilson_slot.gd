extends Button

## Beached: one bag slot. Tap = the item's card; drag it onto another slot = combine the two
## (GDD §10 / CRAFTING.md "combine by dragging item A onto item B", Little-Alchemy style).
## Touch drags work through Godot's mouse emulation.

signal combined(a: String, b: String)

const ICONS := "res://games/wilson/art/icons/"

var item_id := ""

## The item's icon (owner art) or null.
static func icon_of(id: String) -> Texture2D:
	var p := ICONS + id + ".webp"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

func setup(id: String, text_: String) -> void:
	item_id = id
	text = text_
	icon = icon_of(id)
	expand_icon = false
	add_theme_constant_override("icon_max_width", 44)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = false
	add_theme_font_size_override("font_size", 18)

func _get_drag_data(_at: Vector2) -> Variant:
	var prev := TextureRect.new()
	prev.texture = icon
	prev.custom_minimum_size = Vector2(64, 64)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(prev)
	return {"wilson_item": item_id}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("wilson_item")

func _drop_data(_at: Vector2, data: Variant) -> void:
	combined.emit(str(data.wilson_item), item_id)
