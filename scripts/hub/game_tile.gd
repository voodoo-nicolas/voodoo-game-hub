extends Control

## One game in the Netflix-style browser: a 16:9 rounded picture (or the category
## gradient + emoji), tiny mode badges bottom-left, the title underneath. Tap =
## `tapped`, long-press = `long_pressed` (the browser toggles the favourite).
## The picture is only loaded while the tile is near the screen (`set_loaded`).

const HubLook = preload("res://scripts/hub/hub_look.gd")
const HubArt = preload("res://scripts/hub/hub_art.gd")
const GameArt = preload("res://scripts/common/game_art.gd")

const MODE_ICONS := {"cpu": "🤖", "local": "👥", "online": "🌐", "party": "🎉"}
const LONG_PRESS := 0.5
const TITLE_H := 30.0
const SELECTED_SCALE := 1.05

signal tapped(id: String)
signal long_pressed(id: String)

var game: Dictionary = {}
var id := ""
var selected := false
var art_size := Vector2(200, 112)
## The browser's touch scroller: `moved` is true while a press became a drag.
var scroller: Node
var _art: TextureRect
var _title: Label
var _border: Panel
var _glow: Panel
var _fav: Label
var _timer: Timer
var _long_fired := false
var _loaded := false
var _has_art := false
var _tween: Tween

func setup(g: Dictionary, category_name: String, tile_size: Vector2, scroller_node: Node) -> void:
	game = g
	id = str(g.get("id", ""))
	art_size = tile_size
	var k := tile_size.x / 140.0   # text grows with the tile
	scroller = scroller_node
	custom_minimum_size = Vector2(tile_size.x, tile_size.y + TITLE_H)
	size = custom_minimum_size
	pivot_offset = tile_size / 2.0
	mouse_filter = Control.MOUSE_FILTER_PASS

	_glow = Panel.new()
	_glow.add_theme_stylebox_override("panel", HubLook.tile_glow(false))
	_glow.size = tile_size
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	var clip := Panel.new()
	clip.add_theme_stylebox_override("panel", HubLook.clip_style())
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	clip.size = tile_size
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)

	var back := TextureRect.new()
	back.texture = HubArt.fallback_gradient(HubArt.category_color(category_name))
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.size = tile_size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(back)

	# Picture order: the manifest's own tile_art (real art) > the game's drawn logo on the
	# category gradient (game_art.gd) > the generated placeholder file > the emoji.
	var drawn_logo := not HubArt.has_custom_tile(g) and GameArt.has_logo(id)
	_has_art = not drawn_logo and HubArt.tile_path(g) != ""
	if drawn_logo:
		var logo := Control.new()
		var ls := tile_size.y * 0.92
		logo.size = Vector2(ls, ls)
		logo.position = Vector2((tile_size.x - ls) / 2.0, (tile_size.y - ls) / 2.0)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.draw.connect(GameArt.draw_logo.bind(logo, id))
		clip.add_child(logo)
	elif not _has_art:
		var emoji := Label.new()
		emoji.text = str(g.get("icon", "🎮"))
		emoji.add_theme_font_size_override("font_size", int(tile_size.y * 0.5))
		emoji.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji.size = tile_size
		emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(emoji)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.size = tile_size
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_art)

	var icons := ""
	for m in str(g.get("modes", "")).split(",", false):
		icons += str(MODE_ICONS.get(m.strip_edges(), ""))
	if icons != "":
		var pill := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.6)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		pill.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = icons
		l.add_theme_font_size_override("font_size", int(12 * k))
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		pill.add_child(l)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(pill)
		pill.position = Vector2(6, tile_size.y - 10 - 18 * k)

	var mark := ""
	if g.get("locked", false) == true:
		mark = "🔒"
	else:
		match Catalog.state_of(g):
			Catalog.STATE_NEEDS_APP_UPDATE: mark = "⬆"
			Catalog.STATE_DOWNLOAD: mark = "⬇"
	if mark != "":
		var m := HubLook.label(mark, int(14 * k))
		m.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		m.position = Vector2(tile_size.x - 22 * k, 3)
		clip.add_child(m)

	_fav = HubLook.label("★", int(16 * k), Settings.DARK.update)
	_fav.position = Vector2(6, 1)
	_fav.visible = false
	clip.add_child(_fav)

	_border = Panel.new()
	_border.add_theme_stylebox_override("panel", HubLook.tile_border(false))
	_border.size = tile_size
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)

	_title = HubLook.label(Lang.pick(g, "title"), int(14 * k), Color(1, 1, 1, 0.82))
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.position = Vector2(2, tile_size.y + 1)
	_title.size = Vector2(tile_size.x - 4, TITLE_H)
	add_child(_title)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.size = custom_minimum_size
	button.button_down.connect(_on_down)
	button.button_up.connect(_on_up)
	button.pressed.connect(_on_pressed)
	add_child(button)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_long)
	add_child(_timer)

## Loads / drops the picture. Called by the browser for tiles near the screen.
func set_loaded(on: bool) -> void:
	if on == _loaded or not _has_art:
		return
	_loaded = on
	_art.texture = HubArt.tile(game) if on else null

func is_loaded() -> bool:
	return _loaded

func set_favorite(on: bool) -> void:
	_fav.visible = on

func set_selected(on: bool, animate: bool = true) -> void:
	if on == selected:
		return
	selected = on
	_border.add_theme_stylebox_override("panel", HubLook.tile_border(on))
	_glow.add_theme_stylebox_override("panel", HubLook.tile_glow(on))
	_title.add_theme_color_override("font_color", Color.WHITE if on else Color(1, 1, 1, 0.82))
	var target := Vector2.ONE * (SELECTED_SCALE if on else 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animate and is_inside_tree() and not Settings.reduce_motion:
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", target, 0.14)
	else:
		scale = target

func _moved() -> bool:
	return scroller != null and bool(scroller.get("moved"))

func _on_down() -> void:
	_long_fired = false
	_timer.start(LONG_PRESS)

func _on_up() -> void:
	_timer.stop()

func _on_long() -> void:
	if _moved():
		return
	_long_fired = true
	Settings.buzz(30)
	long_pressed.emit(id)

func _on_pressed() -> void:
	if _long_fired or _moved():
		return
	tapped.emit(id)
