extends Control

## The horizontal strip of GameTiles at the bottom of the new Game Browser:
##  - ‹ › arrows move one page (the tiles fully in view), animated; ‹ hides at the
##    start and › at the end (and both while `arrows_enabled` is false: portrait)
##  - drag / swipe with momentum, snapping to a tile, via the browser's TouchScroll
##    (this ScrollContainer is in group "nx_row_scroll" and carries `snap_step`);
##    the mouse wheel scrolls sideways too
##  - the next tile peeks in at the edge, and both edges fade out
##  - a new set of tiles slides + fades in (0.2 s) and the strip starts from the left

const HubLook = preload("res://scripts/hub/hub_look.gd")
const HubArt = preload("res://scripts/hub/hub_art.gd")
const GameTile = preload("res://scripts/hub/game_tile.gd")

const SEPARATION := 14
const PAD_V := 8          # room for the selected tile's 1.05 scale and glow
const ARROW_W := 56.0
const SLIDE_TIME := 0.2
const FADE_W := 48.0

signal scrolled

var tiles: Array = []
var tile_size := Vector2(200, 112)
var arrows_enabled := true
var scroll: ScrollContainer
var _strip: HBoxContainer
var _pad: MarginContainer
var _left: Button
var _right: Button
var _fade_l: TextureRect
var _fade_r: TextureRect
var _message: Label
var _tween: Tween
var _intro: Tween

func _init() -> void:
	clip_contents = false

func min_height() -> float:
	return tile_size.y + GameTile.TITLE_H + PAD_V * 2

func _ready() -> void:
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_to_group("nx_row_scroll")
	add_child(scroll)
	_pad = MarginContainer.new()
	for side in ["left", "right"]:
		_pad.add_theme_constant_override("margin_" + side, HubLook.SIDE)
	_pad.add_theme_constant_override("margin_top", PAD_V)
	_pad.add_theme_constant_override("margin_bottom", PAD_V)
	scroll.add_child(_pad)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", SEPARATION)
	_pad.add_child(_strip)
	_fade_l = _edge(true)
	_fade_r = _edge(false)
	_left = _arrow("‹", true)
	_right = _arrow("›", false)
	_message = HubLook.label("", 26, HubLook.pal().text_dim)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	add_child(_message)
	var bar := scroll.get_h_scroll_bar()
	bar.value_changed.connect(_on_scrolled.unbind(1))
	bar.changed.connect(_update_arrows)
	resized.connect(_on_resized)

func _edge(left: bool) -> TextureRect:
	var r := TextureRect.new()
	r.texture = HubArt.edge_fade(Color(0, 0, 0, 0.8), left)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE if left else Control.PRESET_RIGHT_WIDE)
	r.offset_left = 0.0 if left else -FADE_W
	r.offset_right = FADE_W if left else 0.0
	add_child(r)
	return r

func _arrow(glyph: String, left: bool) -> Button:
	var b := HubLook.ghost_button(glyph, 52)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size.x = ARROW_W
	b.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE if left else Control.PRESET_RIGHT_WIDE)
	b.offset_left = 0.0 if left else -ARROW_W
	b.offset_right = ARROW_W if left else 0.0
	b.offset_top = PAD_V
	b.offset_bottom = -(PAD_V + GameTile.TITLE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.5)
	sb.set_corner_radius_all(10)
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	b.flat = false
	b.pressed.connect(_page.bind(-1 if left else 1))
	add_child(b)
	return b

## Replaces the tiles (the strip starts from the left). `cat_name_of`: Callable(id) ->
## English category name (fallback colour). Empty list + `empty_text` shows the text.
func set_games(games: Array, cat_name_of: Callable, scroller: Node, empty_text: String = "") -> void:
	for t in tiles:
		if is_instance_valid(t):
			_strip.remove_child(t)
			t.queue_free()
	tiles.clear()
	for g in games:
		var tile := GameTile.new()
		tile.setup(g, str(cat_name_of.call(str(g.id))), tile_size, scroller)
		_strip.add_child(tile)
		tiles.append(tile)
	custom_minimum_size.y = min_height()
	scroll.set_meta("snap_step", tile_size.x + SEPARATION)
	_message.text = empty_text
	_message.visible = games.is_empty() and empty_text != ""
	scroll.scroll_horizontal = 0
	_update_arrows.call_deferred()
	scrolled.emit()
	_play_intro()

func _play_intro() -> void:
	if _intro != null and _intro.is_valid():
		_intro.kill()
	scroll.position.x = 0.0
	var t := Settings.anim_time(SLIDE_TIME)
	if t <= 0.0 or not is_inside_tree():
		scroll.modulate.a = 1.0
		return
	scroll.modulate.a = 0.0
	scroll.position.x = 48.0
	_intro = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(scroll, "modulate:a", 1.0, t)
	_intro.tween_property(scroll, "position:x", 0.0, t)

func set_tile_size(size_in: Vector2) -> void:
	tile_size = size_in
	custom_minimum_size.y = min_height()

func set_arrows_enabled(on: bool) -> void:
	arrows_enabled = on
	_update_arrows()

func scroll_to_tile(id: String) -> void:
	for t in tiles:
		if t.id == id:
			scroll.ensure_control_visible(t)

## Tiles fully visible at once (at least 1).
func page_size() -> int:
	var usable := scroll.size.x - HubLook.SIDE * 2.0
	return maxi(1, int(floor((usable + SEPARATION) / (tile_size.x + SEPARATION))))

func _page(dir: int) -> void:
	var step := tile_size.x + SEPARATION
	var bar := scroll.get_h_scroll_bar()
	var max_scroll := bar.max_value - bar.page
	var current := roundf(scroll.scroll_horizontal / step)
	var target := clampf((current + dir * page_size()) * step, 0.0, max_scroll)
	slide_to(int(target))

func slide_to(target: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if Settings.reduce_motion or not is_inside_tree():
		scroll.scroll_horizontal = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(scroll, "scroll_horizontal", target, 0.28)

func _on_resized() -> void:
	_update_arrows()
	scrolled.emit()

func _on_scrolled() -> void:
	_update_arrows()
	scrolled.emit()

func _update_arrows() -> void:
	if scroll == null:
		return
	var bar := scroll.get_h_scroll_bar()
	var max_scroll := bar.max_value - bar.page
	_left.visible = arrows_enabled and scroll.scroll_horizontal > 2
	_right.visible = arrows_enabled and scroll.scroll_horizontal < max_scroll - 2
	_fade_l.visible = scroll.scroll_horizontal > 2
	_fade_r.visible = scroll.scroll_horizontal < max_scroll - 2
