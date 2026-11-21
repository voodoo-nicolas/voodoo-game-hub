extends SceneTree

## Headless test of Layout D (scripts/hub/layout_d.gd, categories.gd, owner 2026-11-20):
##   godot --headless --path . --script res://tools/test_layout_d.gd
## Uses this checkout's manifest. Categories + the hide rule, counts, archived games, search
## (EN / ES / tags / chips), Home rows, back, keyboard / controller focus. No save data written.

const Categories = preload("res://scripts/hub/categories.gd")
var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _key(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	root.push_input(e)

func _run() -> void:
	load("res://scripts/common/consent.gd").prompted = true
	await process_frame   # autoloads must be in the tree before the catalog filters games
	var cat = root.get_node("Catalog")
	cat._apply_manifest(cat._read_json_file(cat.BUNDLED_MANIFEST))
	change_scene_to_file("res://scenes/hub/hub.tscn")
	await _frames(40)
	# The live manifest fetch would replace this checkout's (it may lack the new fields): wait it out.
	for i in 600:
		if not cat._fetch_in_flight:
			break
		await process_frame
	cat._apply_manifest(cat._read_json_file(cat.BUNDLED_MANIFEST))
	cat.catalog_changed.emit()
	await _frames(10)
	var ld = current_scene.layout_d
	ok(ld != null, "the hub runs Layout D")

	# Categories: 11 in one list, the rail hides those under MIN_GAMES_TO_SHOW.
	ok(Categories.ids().size() == 11, "11 categories in categories.gd")
	var shown: Array = ld._visible_categories()
	for id in Categories.ids():
		var n: int = cat.games_in(id).size()
		ok(shown.has(id) == (n >= Categories.MIN_GAMES_TO_SHOW), "%s: %d games -> %s" % [id, n, "shown" if shown.has(id) else "hidden"])
	ok(not shown.has("sports"), "Sports hidden at launch (intended)")
	var total := 0
	for id in Categories.ids():
		total += cat.games_in(id).size()
	ok(total == cat.all_games().size(), "every game is in exactly one category (%d)" % total)
	ok(Categories.label("brain", true) != "", "short rail labels exist")

	# Header count comes from the list, never typed.
	ld._show("cat:board", false)
	await _frames(3)
	ok(ld._count.text == tr("%d games") % cat.games_in("board").size(), "header counts the games: %s" % ld._count.text)

	# Archived games appear nowhere.
	var archived: Array = cat.archived_ids.keys()
	var ids: Array = cat.all_games().map(func(g): return g.id)
	ok(archived.all(func(a): return not ids.has(a)), "archived games excluded (%d archived)" % archived.size())

	# Search: name EN + ES, tags (EN + ES), chips.
	var r: Array = ld.search("chess", {})
	ok(r.any(func(g): return g.id == "chess"), "finds Chess by its English name")
	r = ld.search("ajedrez", {})
	ok(r.any(func(g): return g.id == "chess"), "finds Chess by its Spanish name")
	r = ld.search("multijugador", {})
	ok(r.size() > 0 and r.all(func(g): return (g.tags as Array).has("multiplayer")), "Spanish tag word finds multiplayer games (%d)" % r.size())
	var m: Array = ld.search("", {"multiplayer": true})
	ok(m.size() > 0 and m.all(func(g): return (g.tags as Array).has("multiplayer")), "Multiplayer chip (%d)" % m.size())
	var q: Array = ld.search("", {"quick": true})
	ok(q.size() > 0 and q.all(func(g): return (g.tags as Array).has("quick") or g.quick), "Quick play chip (%d)" % q.size())
	var off: Array = ld.search("", {"offline": true})
	ok(off.all(func(g): return not cat.needs_download(g.id)), "Offline chip = only downloaded games (%d)" % off.size())
	ok(ld.search("zzzz-no-such-game", {}).is_empty(), "nonsense finds nothing")

	# Home rows: New is newest first; featured skips missing ids.
	var new_row: Array = ld._row_games("new", 10)
	var sorted_ok := true
	for i in new_row.size() - 1:
		if str(new_row[i].added) < str(new_row[i + 1].added):
			sorted_ok = false
	ok(new_row.size() == mini(10, cat.all_games().size()) and sorted_ok, "New: 10 newest first")
	ok(cat.featured.all(func(id): return not cat.get_game(id).is_empty()), "featured lists only live games")

	# Back: grid -> Home; Home -> not handled (the hub leaves the app).
	ld._show("cat:arcade", false)
	ok(ld.handle_back() and ld.current == "home", "back from a category goes Home")
	ok(not ld.handle_back(), "back on Home is the app's to handle")
	ld._open_detail("chess")
	ok(ld.handle_back() and ld._dim == null, "back closes the game card first")

	# Keyboard / controller: an arrow starts on the rail, Enter on a tile opens its card.
	root.gui_release_focus()
	_key("ui_down")
	await _frames(2)
	var f: Control = root.gui_get_focus_owner()
	ok(f != null and f.has_meta("key"), "first arrow press focuses the rail (%s)" % (str(f.get_meta("key")) if f and f.has_meta("key") else (str(f.get_path()) if f else "none")))
	ld._show("cat:board", false)
	await _frames(3)
	var tile: Control = ld._tiles[0]
	tile.grab_focus()
	await _frames(1)
	ok(tile.selected, "a focused tile shows its focus ring")
	_key("ui_accept")
	await _frames(2)
	ok(ld._detail_id == tile.id, "Enter / A on a tile opens its card")
	_key("ui_cancel")
	await _frames(2)
	ok(ld._dim == null, "Esc / B closes it")

	print("layout d logic: %d failure(s)" % fails)
	quit(fails)
