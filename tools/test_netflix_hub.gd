extends SceneTree

## Game Browser (strip look + grid look): tabs, favourites tab, select /
## detail / back, results tab, fallback art, both orientations.
##   godot --headless --path . --script res://tools/test_netflix_hub.gd
## Shares the PC build's user data (backs up and restores the layout setting).

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _initialize() -> void:
	var settings = root.get_node("Settings")
	var catalog = root.get_node("Catalog")
	await process_frame   # autoloads load their saved data in _ready
	var was: String = settings.hub_layout
	settings.hub_layout = "strip"
	var hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)
	for i in 5:
		await process_frame
	var nx = hub.netflix
	_check(nx != null, "new browser is built")
	if nx == null:
		quit(1)
		return
	nx.size = Vector2(1280, 720)
	await process_frame
	_check(nx.landscape, "1280x720 is landscape")
	_check(nx.strip.arrows_enabled, "arrows on in landscape")
	nx.size = Vector2(720, 1280)
	await process_frame
	_check(not nx.landscape and not nx.strip.arrows_enabled, "portrait: no arrows")
	nx.size = Vector2(1280, 720)
	await process_frame

	# tabs: every manifest category, never the archived ones
	var cats: Array = catalog.categories
	_check(not cats.is_empty(), "catalog has categories")
	nx._on_tab("cat:0")
	_check(nx.strip.tiles.size() == nx._games_for("cat:0").size() and nx.strip.tiles.size() > 0, "category strip has its games")
	_check(nx.strip.scroll.scroll_horizontal == 0, "strip starts at the left")
	# favourites tab always exists; long-press toggles
	var HubData = load("res://scripts/common/hub_data.gd")
	var favs_before: Array = HubData.favorites().duplicate()
	var id: String = nx.strip.tiles[0].id
	nx.select(id)
	_check(nx.selected_id == id and nx._detail_holder.visible, "tap selects and opens the detail")
	nx.select(nx.strip.tiles[1].id)
	_check(nx.selected_id == nx.strip.tiles[1].id, "another tile swaps the detail")
	nx.handle_back()
	_check(nx.selected_id == "" and not nx._detail_holder.visible, "back closes the detail")
	var was_fav: bool = HubData.is_favorite(id)
	nx._toggle_favorite(id)
	_check(HubData.is_favorite(id) != was_fav, "favourite toggles")
	nx._on_tab("favs")
	_check(nx._games_for("favs").size() == HubData.favorites().size(), "favs tab lists the favourites")
	nx._toggle_favorite(id)
	# restore favourites exactly
	var f := FileAccess.open(HubData.FAVORITES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ids": favs_before}))
	f.close()

	# search -> results tab, clearing restores the previous tab
	nx._on_tab("cat:1")
	hub.search_box.text = "a"
	hub._on_search_changed("a")
	_check(nx.tab == "results", "search shows the Results tab")
	hub.search_box.text = ""
	hub._on_search_changed("")
	_check(nx.tab == "cat:1", "clearing search restores the tab")

	# fallback art for a game with no files
	var HubArt = load("res://scripts/hub/hub_art.gd")
	_check(HubArt.tile_path({"id": "no_such_game"}) == "", "no art -> empty path (fallback)")
	var g: Dictionary = nx.strip.tiles[0].game
	_check(HubArt.tile(g) != null and HubArt.hero(g) != null, "placeholder tile + hero exist for %s" % g.id)
	var missing := []
	for cat in cats:
		for game in cat.games:
			if game.has("id") and not HubArt.has_art(game):
				missing.append(game.id)
	_check(missing.is_empty(), "games using fallback art: %s" % str(missing))

	# ---- grid look ----
	hub.queue_free()
	await process_frame
	settings.hub_layout = "grid"
	hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)
	for i in 5:
		await process_frame
	nx = hub.netflix
	_check(nx != null and nx.grid_mode, "grid look is built")
	nx.size = Vector2(720, 1280)
	await process_frame
	await process_frame
	_check(nx._grid_tiles.size() >= 100, "grid lists every game (%d)" % nx._grid_tiles.size())
	var gid: String = nx._grid_tiles[0].id
	nx.select(gid)
	_check(nx.selected_id == gid and nx._card.visible, "grid: tap opens the detail card")
	nx.handle_back()
	_check(nx.selected_id == "" and not nx._card.visible, "grid: back closes the card")

	settings.hub_layout = was
	print("test_netflix_hub: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
