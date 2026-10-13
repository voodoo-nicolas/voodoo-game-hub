extends Control

## The Game Browser (the only one since v0.37; the old accordion list is retired).
## Two looks, Options > "Games menu look" (Settings.hub_layout):
##
##  "strip" (default): full-screen artwork, and two bars at the bottom: a category bar
##   (★ Favoritos, 🔍, Continue playing, every category, Filtros) and ONE strip of tiles
##   (‹ › arrows in landscape, drag + momentum + snap, wheel, edge fades).
##   - Opening Games shows the hub's landing art. Choosing a category crossfades the
##     background to that category's art (media/hub/categories); a game never changes it.
##   - Tapping a tile shows its detail just above the bars: title + ★ (favourite),
##     category · age, description, mode badges, ✕ Back / ▶ Play, and the game's picture
##     to the right. Tapping another tile swaps it; ✕ Back or Android back closes it.
##
##  "grid": every game in a grid, divided by category (Favoritos and Continue first),
##   scrolling up/down. Tapping a tile opens the same detail as a card over the grid.
##
## Both: tap the open tile again or ▶ Play = open the game (Hub._on_tile_pressed);
## long-press = toggle favourite; search / Filtros / sorting show their results under a
## "Results" tab (strip) or heading (grid). The hub owns that state (chips, sort_mode,
## search_box, _filtered_games()). One scene set serves both orientations: _layout()
## reads the size on every resize. This view only draws; `hub` is the Hub node.

const HubLook = preload("res://scripts/hub/hub_look.gd")
const HubArt = preload("res://scripts/hub/hub_art.gd")
const Brand = preload("res://scripts/common/brand.gd")
const CategoryBar = preload("res://scripts/hub/category_bar.gd")
const GameTile = preload("res://scripts/hub/game_tile.gd")
const GameStrip = preload("res://scripts/hub/game_strip.gd")
const GameDetail = preload("res://scripts/hub/game_detail.gd")
const TouchScroll = preload("res://scripts/hub/touch_scroll.gd")
const HubData = preload("res://scripts/common/hub_data.gd")

const BAR_H := 64.0
const TOP_H := 84.0
const RECENT_MAX := 12
const ART_FADE := 0.3
const GRID_GAP := 12
const MODE_WORDS := {"cpu": "vs. computer", "local": "same phone", "online": "online", "party": "group"}

var hub: Node
var scroller: Node
var grid_mode := false
var bar: HBoxContainer
var strip: Control
var detail: VBoxContainer
var selected_id := ""
## strip look: "results" / "favs" / "recent" / "cat:<index>"
var tab := ""
var landscape := false
var tiles: Array:
	get: return _all_tiles()
var _cat_of: Dictionary = {}     # id -> {"en", "loc", "index"}
var _prev_tab := ""
var _tab_picked := false         # the background follows the category only after the player picks one
var _art_clip: Control
var _art_layer: Control
var _art_key := "-"
var _art_fade: Tween
var _scrim_left: TextureRect
var _scrim_bottom: TextureRect
var _detail_holder: Control
var _preview: Control
var _preview_art: TextureRect
var _preview_emoji: Label
var _preview_back: TextureRect
var _bottom: VBoxContainer
var _topbar: Control
var _back_btn: Button
var _search_field: LineEdit
var _search_btn: Button
var _filter_wrap: Control
var _dim: Button
var _card: Panel
var _grid_scroll: ScrollContainer
var _grid_box: VBoxContainer
var _grid_tiles: Array = []
var _lazy_dirty := true
var _search_open := false
var _tile_size := Vector2.ZERO
var _grid_cols := 0

func setup(hub_node: Node) -> void:
	hub = hub_node
	grid_mode = Settings.hub_layout == "grid"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = HubLook.pal().bg
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_art_clip = Control.new()
	_art_clip.clip_contents = true
	_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_clip)
	_art_layer = Control.new()
	_art_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.add_child(_art_layer)
	_scrim_left = _scrim(HubArt.scrim_left())
	_scrim_bottom = _scrim(HubArt.scrim_bottom())

	scroller = TouchScroll.new()
	scroller.bounds = self
	add_child(scroller)

	if grid_mode:
		_build_grid_scroll()
	else:
		_build_bottom_bars()
	_build_detail()
	_build_topbar()
	_set_art("hub", null)
	resized.connect(_layout)
	_layout()
	rebuild()

func _scrim(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _build_bottom_bars() -> void:
	_bottom = VBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 4)
	add_child(_bottom)
	bar = CategoryBar.new()
	bar.custom_minimum_size.y = BAR_H
	bar.build(scroller)
	bar.tab_selected.connect(_on_tab)
	bar.search_pressed.connect(_toggle_search)
	bar.filters_pressed.connect(hub._on_filters_toggled)
	hub.filters_btn = bar.filters_button
	_bottom.add_child(bar)
	strip = GameStrip.new()
	strip.scrolled.connect(_mark_lazy)
	_bottom.add_child(strip)

func _build_grid_scroll() -> void:
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_grid_scroll)
	scroller.vertical = _grid_scroll
	scroller.vertical_scrolled.connect(_mark_lazy)
	_grid_scroll.get_v_scroll_bar().value_changed.connect(_mark_lazy.unbind(1))
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", HubLook.SIDE)
	margin.add_theme_constant_override("margin_right", HubLook.SIDE)
	margin.add_theme_constant_override("margin_bottom", 48)
	_grid_scroll.add_child(margin)
	_grid_box = VBoxContainer.new()
	_grid_box.add_theme_constant_override("separation", 10)
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_grid_box)

## Text block of the selected game + its picture; in the grid look they sit on a card.
func _build_detail() -> void:
	_dim = Button.new()
	_dim.flat = true
	_dim.focus_mode = Control.FOCUS_NONE
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0, 0, 0, 0.62)
	for s in ["normal", "hover", "pressed", "focus"]:
		_dim.add_theme_stylebox_override(s, dsb)
	_dim.pressed.connect(_close_detail)
	_dim.visible = false
	add_child(_dim)
	_card = Panel.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.01, 0.03, 0.08, 0.96)
	csb.border_color = HubLook.pal().link
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(16)
	_card.add_theme_stylebox_override("panel", csb)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)

	_detail_holder = Control.new()
	_detail_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_holder)
	detail = GameDetail.new()
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail.alignment = BoxContainer.ALIGNMENT_END
	detail.play_pressed.connect(_on_play)
	detail.favorite_pressed.connect(_toggle_favorite)
	detail.close_pressed.connect(_close_detail)
	_detail_holder.add_child(detail)
	_detail_holder.visible = false

	_preview = Panel.new()
	_preview.add_theme_stylebox_override("panel", HubLook.clip_style())
	_preview.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	add_child(_preview)
	_preview_back = TextureRect.new()
	_preview_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_back.stretch_mode = TextureRect.STRETCH_SCALE
	_preview_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_preview_back)
	_preview_emoji = Label.new()
	_preview_emoji.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_preview_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_emoji.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_preview_emoji)
	_preview_art = TextureRect.new()
	_preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_preview_art)

func _all_tiles() -> Array:
	return _grid_tiles if grid_mode else (strip.tiles if strip else [])

# ---------- top bar: ← Inicio, search field, Filtros panel ----------

func _build_topbar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", HubLook.SIDE - 4)
	margin.add_theme_constant_override("margin_right", HubLook.SIDE)
	margin.add_theme_constant_override("margin_top", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)
	_topbar = margin
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	_back_btn = HubLook.ghost_button(tr("← Hub"), 28)
	_back_btn.custom_minimum_size = Vector2(120, 56)
	_back_btn.pressed.connect(hub._show_home)
	row.add_child(_back_btn)
	_search_field = LineEdit.new()
	_search_field.placeholder_text = tr("🔍 Search games")
	_search_field.clear_button_enabled = true
	_search_field.custom_minimum_size = Vector2(0, 56)
	_search_field.add_theme_font_size_override("font_size", 26)
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0.6)
	fsb.border_color = Color(1, 1, 1, 0.3)
	fsb.set_border_width_all(1)
	fsb.set_corner_radius_all(12)
	fsb.content_margin_left = 14
	for s in ["normal", "focus"]:
		_search_field.add_theme_stylebox_override(s, fsb)
	_search_field.text_changed.connect(hub._on_search_changed)
	_search_field.visible = false
	row.add_child(_search_field)
	hub.search_box = _search_field
	if grid_mode:
		# No category bar here, so 🔍 and Filtros live in the top bar.
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.name = "Spacer"
		row.add_child(spacer)
		_search_btn = HubLook.ghost_button("🔍", 28)
		_search_btn.custom_minimum_size = Vector2(64, 56)
		_search_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_search_btn.pressed.connect(_toggle_search)
		row.add_child(_search_btn)
		var filters := CategoryBar.make_filters_button()
		filters.pressed.connect(hub._on_filters_toggled)
		row.add_child(filters)
		hub.filters_btn = filters

	# The chips and sort buttons drop down under the top bar.
	var wrap := PanelContainer.new()
	var p := HubLook.pal()
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color(0.01, 0.03, 0.08, 0.95)
	wsb.border_color = p.link_dim
	wsb.set_border_width_all(1)
	wsb.set_corner_radius_all(14)
	wsb.content_margin_left = 14
	wsb.content_margin_right = 14
	wsb.content_margin_top = 12
	wsb.content_margin_bottom = 12
	wrap.add_theme_stylebox_override("panel", wsb)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wrap.offset_left = HubLook.SIDE
	wrap.offset_right = -HubLook.SIDE
	wrap.offset_top = TOP_H
	wrap.visible = false
	add_child(wrap)
	_filter_wrap = wrap
	hub._build_filter_panel(wrap)
	hub.filter_panel.visibility_changed.connect(_sync_filter_wrap)
	hub._sync_chip_buttons()

func _sync_filter_wrap() -> void:
	_filter_wrap.visible = hub.filter_panel.visible

func _toggle_search() -> void:
	_search_open = not _search_open
	_search_field.visible = _search_open
	if grid_mode:
		_back_btn.visible = not _search_open
		_topbar.get_child(0).get_node("Spacer").visible = not _search_open
		_search_btn.text = "✕" if _search_open else "🔍"
	else:
		bar.set_search_open(_search_open)
	if _search_open:
		_search_field.grab_focus()
	elif _search_field.text != "":
		_search_field.text = ""
		hub._on_search_changed("")

# ---------- layout (both orientations) ----------

func _layout() -> void:
	var W := size.x
	var H := size.y
	if W <= 0.0 or H <= 0.0 or (strip == null and _grid_scroll == null):
		return
	landscape = W > H * 1.05
	var side := float(HubLook.SIDE)
	_art_clip.position = Vector2.ZERO
	_art_clip.size = Vector2(W, H)
	var open := selected_id != ""
	var bottom_h := 0.0
	if grid_mode:
		_layout_grid(W, H)
	else:
		bottom_h = _layout_strip(W, H)

	# the detail text sits just above the bars (strip) or on a card (grid)
	var text_w := W * 0.46 if landscape else W * 0.6 - side
	var pw := minf(W * 0.28, 440.0) if landscape else W * 0.34
	var area := Rect2(side, TOP_H, W - side * 2.0, maxf(80.0, H - bottom_h - TOP_H - 12.0))
	if grid_mode:
		var cw := minf(W - side * 2.0, 1000.0 if landscape else W)
		var ch := minf(H - TOP_H - 24.0, 380.0 if landscape else 420.0)
		var card := Rect2((W - cw) / 2.0, (H - ch) / 2.0 + 20.0, cw, ch)
		_card.position = card.position
		_card.size = card.size
		area = card.grow(-22.0)
		text_w = area.size.x * (0.58 if landscape else 0.6)
		pw = minf(area.size.x * 0.36, 380.0)
	_detail_holder.position = area.position
	_detail_holder.size = Vector2(text_w, area.size.y)
	detail.alignment = BoxContainer.ALIGNMENT_CENTER if grid_mode else BoxContainer.ALIGNMENT_END
	detail.set_compact(area.size.y < (270.0 if landscape else 330.0), 56 if landscape else 46)
	var ph := roundf(pw * 9.0 / 16.0)
	_preview.size = Vector2(roundf(pw), ph)
	_preview.position = Vector2(area.end.x - pw, (area.get_center().y - ph / 2.0) if grid_mode else (area.end.y - ph))
	_preview_emoji.add_theme_font_size_override("font_size", int(ph * 0.5))

	_scrim_left.visible = open and landscape and not grid_mode
	_scrim_left.position = Vector2.ZERO
	_scrim_left.size = Vector2(W, H)
	var g := bottom_h * 1.8
	if open and not landscape and not grid_mode:
		g = bottom_h + area.size.y + 120.0
	g = minf(H, g)
	_scrim_bottom.visible = not grid_mode
	_scrim_bottom.position = Vector2(0, H - g)
	_scrim_bottom.size = Vector2(W, g)
	_dim.position = Vector2.ZERO
	_dim.size = Vector2(W, H)
	_lazy_dirty = true

## Returns the height of the bar + strip block.
func _layout_strip(W: float, H: float) -> float:
	var side := float(HubLook.SIDE)
	var tile := Vector2.ZERO
	if landscape:
		var h := clampf(H * 0.30 - BAR_H - GameTile.TITLE_H - 2.0 * GameStrip.PAD_V - 8.0, 64.0, 150.0)
		tile = Vector2(roundf(h * 16.0 / 9.0), h)
	else:
		var w := roundf((W - side) / 3.4 - GameStrip.SEPARATION)
		tile = Vector2(w, roundf(w * 9.0 / 16.0))
	if tile != _tile_size:
		_tile_size = tile
		strip.set_tile_size(tile)
		if tab != "":
			_show_tab()
	strip.set_arrows_enabled(landscape)
	var bottom_h: float = BAR_H + 4.0 + strip.min_height() + 8.0
	_bottom.position = Vector2(0, H - bottom_h)
	_bottom.size = Vector2(W, bottom_h)
	return bottom_h

func _layout_grid(W: float, H: float) -> void:
	_grid_scroll.position = Vector2(0, TOP_H)
	_grid_scroll.size = Vector2(W, H - TOP_H)
	var cols := 5 if landscape else 3
	if cols != _grid_cols and not _cat_of.is_empty():
		rebuild.call_deferred()   # a rotation: new column count

# ---------- background art: the hub's landing art, or the open category's ----------

func _update_background() -> void:
	if not grid_mode and _tab_picked and tab.begins_with("cat:"):
		var idx := int(tab.substr(4))
		if idx >= 0 and idx < Catalog.categories.size():
			var path: String = hub.CATEGORY_ART.get(str(Catalog.categories[idx].get("name", "")), "")
			if path != "" and ResourceLoader.exists(path):
				_set_art(path, load(path) as Texture2D)
				return
	_set_art("hub", null)

func _set_art(key: String, tex: Texture2D) -> void:
	if key == _art_key:
		return
	_art_key = key
	var old: Array = _art_layer.get_children()
	var pic := Control.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		var bg := Brand.backdrop()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.add_child(bg)
	else:
		pic.add_child(_cover(tex))
		var dim := ColorRect.new()   # a little darker, like the hub background
		dim.color = Color(0, 0.01, 0.04, 0.35)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.add_child(dim)
	_art_layer.add_child(pic)
	if _art_fade != null and _art_fade.is_valid():
		_art_fade.kill()
	var t := Settings.anim_time(ART_FADE)
	if t <= 0.0 or old.is_empty():
		for o in old:
			o.queue_free()
		return
	pic.modulate.a = 0.0
	_art_fade = create_tween()
	_art_fade.tween_property(pic, "modulate:a", 1.0, t)
	_art_fade.tween_callback(_free_nodes.bind(old))

func _free_nodes(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()

## Fills the screen, centred: the picture is scaled to cover and the overflow is cropped
## (sides in portrait, top and bottom in a wider-than-picture window).
func _cover(tex: Texture2D) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	holder.add_child(r)
	holder.resized.connect(_fit_cover.bind(holder, r, tex))
	_fit_cover.call_deferred(holder, r, tex)
	return holder

func _fit_cover(holder: Control, r: TextureRect, tex: Texture2D) -> void:
	if not is_instance_valid(holder) or tex == null or holder.size.x <= 0.0:
		return
	var s := maxf(holder.size.x / tex.get_width(), holder.size.y / tex.get_height())
	r.size = Vector2(tex.get_width(), tex.get_height()) * s
	r.position = (holder.size - r.size) / 2.0

# ---------- building the content ----------

func rebuild() -> void:
	_cat_of.clear()
	for i in Catalog.categories.size():
		var cat: Dictionary = Catalog.categories[i]
		for g in cat.games:
			if g.has("id"):
				_cat_of[str(g.id)] = {"en": str(cat.get("name", "")), "loc": Lang.pick(cat, "name"), "index": i}
	if selected_id != "" and not _cat_of.has(selected_id):
		_close_detail()
	if grid_mode:
		_rebuild_grid()
	else:
		_rebuild_strip()

func _rebuild_strip() -> void:
	var filtering: bool = hub._filtering()
	var items: Array = []
	if filtering:
		items.append({"key": "results", "title": _tab_title("results")})
	items.append({"key": "favs", "title": tr("★ Favorites")})
	items.append({"key": "_search", "title": "🔍"})
	if not _games_for("recent").is_empty():
		items.append({"key": "recent", "title": tr("Continue playing")})
	for i in Catalog.categories.size():
		items.append({"key": "cat:%d" % i, "title": _tab_title("cat:%d" % i)})
	if filtering:
		if tab != "results":
			_prev_tab = tab
		tab = "results"
	elif tab == "results":
		tab = _prev_tab
	if tab == "" or not _valid_tab(tab, items):
		tab = "recent" if not _games_for("recent").is_empty() else ("cat:0" if not Catalog.categories.is_empty() else "favs")
	bar.set_tabs(items, tab)
	bar.set_search_open(_search_open)
	_show_tab()
	_update_background()

func _valid_tab(key: String, items: Array) -> bool:
	for it in items:
		if it.key == key:
			return true
	return false

func _games_for(key: String) -> Array:
	var out: Array = []
	if key == "results":
		return hub._filtered_games()
	if key == "recent":
		var recent := HubData.recent()
		var ids: Array = recent.keys().filter(func(id): return _cat_of.has(str(id)))
		ids.sort_custom(func(a, b): return float(recent[a]) > float(recent[b]))
		for id in ids.slice(0, RECENT_MAX):
			out.append(Catalog.get_game(str(id)))
	elif key == "favs":
		for id in HubData.favorites():
			if _cat_of.has(str(id)):
				out.append(Catalog.get_game(str(id)))
	elif key.begins_with("cat:"):
		var idx := int(key.substr(4))
		if idx >= 0 and idx < Catalog.categories.size():
			for g in Catalog.categories[idx].games:
				if g.has("id"):
					out.append(g)
	return out

func _tab_title(key: String) -> String:
	var n := _games_for(key).size()
	if key == "results":
		return tr("Results (%d)") % n
	return "%s (%d)" % [Lang.pick(Catalog.categories[int(key.substr(4))], "name"), n]

func _on_tab(key: String) -> void:
	if key == tab:
		return
	tab = key
	_tab_picked = true
	bar.set_active(tab)
	_show_tab()
	_update_background()

func _show_tab() -> void:
	var games := _games_for(tab)
	var empty := ""
	if games.is_empty() and tab == "favs":
		empty = tr("No favorites yet. Press and hold a game to add it.")
	elif games.is_empty():
		empty = tr("No games match.")
	strip.set_games(games, _category_en, scroller, empty)
	bar.set_active(tab)
	for t in strip.tiles:
		_hook_tile(t)
	_lazy_dirty = true

func _hook_tile(t: Control) -> void:
	t.tapped.connect(_on_tile_tapped)
	t.long_pressed.connect(_toggle_favorite)
	t.set_favorite(HubData.is_favorite(t.id))
	t.set_selected(t.id == selected_id, false)

func _category_en(id: String) -> String:
	return str(_cat_of.get(id, {}).get("en", ""))

# ---------- grid look ----------

func _rebuild_grid() -> void:
	var keep: int = _grid_scroll.scroll_vertical
	for c in _grid_box.get_children():
		_grid_box.remove_child(c)
		c.queue_free()
	_grid_tiles.clear()
	var W := maxf(size.x, 300.0)
	var cols := 5 if landscape else 3
	_grid_cols = cols
	var tw := floorf((W - HubLook.SIDE * 2.0 - GRID_GAP * (cols - 1)) / cols)
	var tile_size := Vector2(tw, floorf(tw * 9.0 / 16.0))
	if hub._filtering():
		var found: Array = hub._filtered_games()
		_add_section(tr("Results (%d)") % found.size(), found, tile_size, tr("No games match."))
	else:
		_add_section(tr("★ Favorites"), _games_for("favs"), tile_size, tr("No favorites yet. Press and hold a game to add it."))
		var recent := _games_for("recent")
		if not recent.is_empty():
			_add_section(tr("Continue playing"), recent, tile_size, "")
		for i in Catalog.categories.size():
			_add_section(_tab_title("cat:%d" % i), _games_for("cat:%d" % i), tile_size, "")
	_update_background()
	_lazy_dirty = true
	_restore_scroll.call_deferred(keep)

func _restore_scroll(y: int) -> void:
	if is_inside_tree() and _grid_scroll != null:
		_grid_scroll.scroll_vertical = y

func _add_section(title: String, games: Array, tile_size: Vector2, empty_text: String) -> void:
	if games.is_empty() and empty_text == "":
		return
	var head := HubLook.label(title, 30)
	head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.custom_minimum_size.y = 52
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_grid_box.add_child(head)
	if games.is_empty():
		var l := HubLook.label(empty_text, 22, HubLook.pal().text_dim)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_grid_box.add_child(l)
		return
	var grid := GridContainer.new()
	grid.columns = _grid_cols
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	_grid_box.add_child(grid)
	for g in games:
		var t := GameTile.new()
		t.setup(g, str(_cat_of.get(str(g.id), {}).get("en", "")), tile_size, scroller)
		grid.add_child(t)
		_grid_tiles.append(t)
		_hook_tile(t)

## Android back: Filtros panel first, then the open detail. True = handled.
func handle_back() -> bool:
	if hub.filter_panel.visible:
		hub._on_filters_toggled()
		return true
	if selected_id != "":
		_close_detail()
		return true
	return false

# ---------- detail, play, favourite ----------

func select(id: String) -> void:
	var g: Dictionary = Catalog.get_game(id)
	if g.is_empty() or not _cat_of.has(id):
		return
	selected_id = id
	for t in _all_tiles():
		t.set_selected(t.id == id)
	var info: Dictionary = _cat_of[id]
	var parts: PackedStringArray = [info.loc]
	if bool(g.get("has_content", false)):
		parts.append(tr("Ages %d+") % int(g.get("min_age", 3)))
	detail.show_game(g, " · ".join(parts), _description(g, info.loc), HubData.is_favorite(id))
	_set_preview(g, info.en)
	_detail_holder.visible = true
	_preview.visible = true
	_dim.visible = grid_mode
	_card.visible = grid_mode
	if grid_mode:
		scroller.vertical = null   # the grid behind the card stays put
	_layout()

func _close_detail() -> void:
	if selected_id == "":
		return
	selected_id = ""
	for t in _all_tiles():
		t.set_selected(false)
	_detail_holder.visible = false
	_preview.visible = false
	_dim.visible = false
	_card.visible = false
	if grid_mode:
		scroller.vertical = _grid_scroll
	_layout()

## The game's own picture (tile art, or its emoji on the category gradient).
func _set_preview(g: Dictionary, category_en: String) -> void:
	var tex := HubArt.tile(g)
	_preview_art.texture = tex
	_preview_back.texture = HubArt.fallback_gradient(HubArt.category_color(category_en))
	_preview_emoji.text = "" if tex != null else str(g.get("icon", "🎮"))

## The manifest's "desc" (ES/EN), or a line built from the category and modes.
func _description(g: Dictionary, category_loc: String) -> String:
	var d := Lang.pick(g, "desc")
	if d != "":
		return d
	var s := tr("A %s game.") % category_loc.to_lower()
	var words := PackedStringArray()
	for m in str(g.get("modes", "")).split(",", false):
		if MODE_WORDS.has(m.strip_edges()):
			words.append(tr(MODE_WORDS[m.strip_edges()]))
	if not words.is_empty():
		s += " " + tr("Play: %s.") % ", ".join(words)
	return s

func _on_tile_tapped(id: String) -> void:
	if id == selected_id:
		hub._on_tile_pressed(id)
	else:
		select(id)

func _on_play(id: String) -> void:
	hub._on_tile_pressed(id)

func _toggle_favorite(id: String) -> void:
	var on: bool = HubData.toggle_favorite(id)
	if id == selected_id:
		detail.set_favorite(on)
	for t in _all_tiles():
		if t.id == id:
			t.set_favorite(on)
	if grid_mode:
		rebuild.call_deferred()   # the Favorites section gains / loses a tile
	elif tab == "favs":
		_show_tab()   # the tile leaves / joins this strip

# ---------- lazy picture loading ----------

func _mark_lazy() -> void:
	_lazy_dirty = true

## Tiles within a screen of the view get their picture; far ones drop it.
func _process(_delta: float) -> void:
	if not _lazy_dirty or not visible:
		return
	_lazy_dirty = false
	var view := get_global_rect()
	var near := view.grow_individual(view.size.x, view.size.y, view.size.x, view.size.y)
	var far := view.grow_individual(view.size.x * 2.0, view.size.y * 2.0, view.size.x * 2.0, view.size.y * 2.0)
	for t in _all_tiles():
		if not is_instance_valid(t):
			continue
		var r: Rect2 = t.get_global_rect()
		if near.intersects(r):
			t.set_loaded(true)
		elif not far.intersects(r):
			t.set_loaded(false)
