extends Control

## The new Game Browser (Settings.hub_layout == "new"; the Classic list stays in
## hub.gd). Full-screen artwork with two bars at the bottom: a category bar
## (★ Favoritos, 🔍, Continue playing, every category, Filtros) and a strip of tiles.
##
## Tapping a tile opens its detail: the background crossfades (0.3 s) from the hub art
## to the game's hero art and the title, description, mode badges and ▶ Play /
## ☆ Favorite / ✕ Back appear (left side in landscape, under the art in portrait). The
## bars stay; tapping another tile swaps the detail; tapping the open tile again, or
## ▶ Play, opens the game (Hub._on_tile_pressed, as in the Classic list). ✕ Back or the
## Android back button closes it. Long-press on a tile = toggle favourite.
## Search / Filtros / sorting show their results in the strip under a "Results" tab
## (the hub owns that state: chips, sort_mode, search_box, _filtered_games()).
## One scene set serves both orientations: _layout() reads the size on every resize.
## This view only draws; `hub` is the Hub node.

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
const MODE_WORDS := {"cpu": "vs. computer", "local": "same phone", "online": "online", "party": "group"}

var hub: Node
var scroller: Node
var bar: HBoxContainer
var strip: Control
var detail: VBoxContainer
var selected_id := ""
## "results" / "favs" / "recent" / "cat:<index>"
var tab := ""
var landscape := false
var tiles: Array:
	get: return strip.tiles if strip else []
var _cat_of: Dictionary = {}     # id -> {"en", "loc", "index"}
var _prev_tab := ""
var _art_clip: Control
var _art_layer: Control
var _art_key := "-"
var _art_fade: Tween
var _scrim_left: TextureRect
var _scrim_bottom: TextureRect
var _detail_holder: Control
var _bottom: VBoxContainer
var _topbar: Control
var _back_btn: Button
var _search_field: LineEdit
var _filter_wrap: Control
var _lazy_dirty := true
var _search_open := false
var _tile_size := Vector2.ZERO

func setup(hub_node: Node) -> void:
	hub = hub_node
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

	_build_topbar()
	_set_art("hub", null, Color.TRANSPARENT, "")
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
	if W <= 0.0 or H <= 0.0 or strip == null:
		return
	landscape = W > H * 1.05
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
		if not tiles.is_empty() or tab != "":
			_show_tab()
	strip.set_arrows_enabled(landscape)
	var bottom_h: float = BAR_H + 4.0 + strip.min_height() + 8.0
	_bottom.position = Vector2(0, H - bottom_h)
	_bottom.size = Vector2(W, bottom_h)

	var open := selected_id != ""
	var art_h := H
	if open and not landscape:
		art_h = clampf(H - bottom_h - 360.0, H * 0.28, H * 0.6)
	_art_clip.position = Vector2.ZERO
	_art_clip.size = Vector2(W, art_h)
	_scrim_left.visible = open and landscape
	_scrim_left.position = Vector2.ZERO
	_scrim_left.size = Vector2(W, art_h)
	if open and not landscape:   # the art melts into the dark under it
		_scrim_bottom.position = Vector2(0, art_h * 0.6)
		_scrim_bottom.size = Vector2(W, art_h * 0.4)
	else:                        # behind the bars only
		var g := minf(H, bottom_h * 1.8)
		_scrim_bottom.position = Vector2(0, H - g)
		_scrim_bottom.size = Vector2(W, g)

	if landscape:
		var top := TOP_H
		_detail_holder.position = Vector2(side * 2.0, top)
		_detail_holder.size = Vector2(W * 0.46, maxf(80.0, H - bottom_h - top - 12.0))
		detail.alignment = BoxContainer.ALIGNMENT_END
	else:
		_detail_holder.position = Vector2(side, art_h + 4.0)
		_detail_holder.size = Vector2(W - side * 2.0, maxf(80.0, H - bottom_h - art_h - 12.0))
		detail.alignment = BoxContainer.ALIGNMENT_BEGIN
	var avail := _detail_holder.size.y
	detail.set_compact(avail < (270.0 if landscape else 330.0), 56 if landscape else 46)
	_lazy_dirty = true

# ---------- background art: crossfade between the hub art and a game's hero ----------

func _set_art(key: String, tex: Texture2D, color: Color, emoji: String) -> void:
	if key == _art_key:
		return
	_art_key = key
	var old: Array = _art_layer.get_children()
	var pic := Control.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key == "hub":
		var bg := Brand.backdrop()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.add_child(bg)
	elif tex != null:
		pic.add_child(_cover(tex))
	else:
		var back := TextureRect.new()
		back.texture = HubArt.fallback_gradient(color)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(back)
		var e := Label.new()
		e.text = emoji
		e.add_theme_font_size_override("font_size", 220)
		e.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		e.anchor_left = 0.5 if landscape else 0.0   # right half in landscape, like the hero art
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(e)
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

## A picture that covers the art area; the focal point is the right half (landscape,
## where the text sits on the left) or the centre (portrait).
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
	var x := holder.size.x - r.size.x if landscape else (holder.size.x - r.size.x) / 2.0
	r.position = Vector2(x, (holder.size.y - r.size.y) * 0.4)

# ---------- category bar + strip ----------

func rebuild() -> void:
	_cat_of.clear()
	for i in Catalog.categories.size():
		var cat: Dictionary = Catalog.categories[i]
		for g in cat.games:
			if g.has("id"):
				_cat_of[str(g.id)] = {"en": str(cat.get("name", "")), "loc": Lang.pick(cat, "name"), "index": i}
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
	if selected_id != "" and not _cat_of.has(selected_id):
		_close_detail()
	_show_tab()

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
	bar.set_active(tab)
	_show_tab()

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
		t.tapped.connect(_on_tile_tapped)
		t.long_pressed.connect(_toggle_favorite)
		t.set_favorite(HubData.is_favorite(t.id))
		t.set_selected(t.id == selected_id, false)
	_lazy_dirty = true

func _category_en(id: String) -> String:
	return str(_cat_of.get(id, {}).get("en", ""))

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
	for t in strip.tiles:
		t.set_selected(t.id == id)
	var info: Dictionary = _cat_of[id]
	var parts: PackedStringArray = [info.loc]
	if bool(g.get("has_content", false)):
		parts.append(tr("Ages %d+") % int(g.get("min_age", 3)))
	detail.show_game(g, " · ".join(parts), _description(g, info.loc), HubData.is_favorite(id))
	_detail_holder.visible = true
	_layout()
	_set_art(id, HubArt.hero(g), HubArt.category_color(info.en), str(g.get("icon", "🎮")))

func _close_detail() -> void:
	if selected_id == "":
		return
	selected_id = ""
	for t in strip.tiles:
		t.set_selected(false)
	_detail_holder.visible = false
	_layout()
	_set_art("hub", null, Color.TRANSPARENT, "")

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
	for t in strip.tiles:
		if t.id == id:
			t.set_favorite(on)
	if tab == "favs":
		_show_tab()   # the tile leaves / joins this strip

# ---------- lazy picture loading ----------

func _mark_lazy() -> void:
	_lazy_dirty = true

## Tiles within a screen of the strip get their picture; far ones drop it.
func _process(_delta: float) -> void:
	if not _lazy_dirty or not visible:
		return
	_lazy_dirty = false
	var view := get_global_rect()
	var near := view.grow_individual(view.size.x, 0, view.size.x, 0)
	var far := view.grow_individual(view.size.x * 2.0, 0, view.size.x * 2.0, 0)
	for t in strip.tiles:
		if not is_instance_valid(t):
			continue
		var r: Rect2 = t.get_global_rect()
		if near.intersects(r):
			t.set_loaded(true)
		elif not far.intersects(r):
			t.set_loaded(false)
