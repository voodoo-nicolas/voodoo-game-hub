extends SceneTree

## Headless test of Layout D (scripts/hub/layout_d.gd, categories.gd, owner 2026-11-20):
##   godot --headless --path . --script res://tools/test_layout_d.gd
## Uses this checkout's manifest. Categories + the hide rule, counts, archived games, search
## (EN / ES / tags / chips), Home rows, back, keyboard / controller focus. No save data written.

const Categories = preload("res://scripts/hub/categories.gd")
var fails := 0
var _ld: Node

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

func _mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_ld._input(e)   # straight to the layout: headless push_input drops mouse events

func _drag(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_ld._input(e)

func _hover(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	_ld._input(e)

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
	# Home rows after Recently updated: ★ Favorites (when any), then each shown category, in order.
	var cat_rows: Array = ld._visible_categories().filter(func(c): return not ld._row_games("cat:" + c, 1).is_empty())
	ok(cat_rows.size() == ld._visible_categories().size() and ld._row_title("cat:board") == Categories.label("board"), "Home: a row per shown category (%d)" % cat_rows.size())
	ok(ld._row_games("cat:board", 1000).size() == cat.games_in("board").filter(ld._listed).size(), "category row = the category's games")
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

	# Device class on the web (owner 2026-11-21): a browser reports 96 x devicePixelRatio dpi.
	var LD = load("res://scripts/hub/layout_d.gd")
	ok(is_equal_approx(LD.short_side_dp(1179, 288, true, true), 393.0), "iPhone in Safari = 393 dp (a phone, was 655 = tablet)")
	ok(is_equal_approx(LD.short_side_dp(1488, 192, true, true), 744.0), "iPad mini in Safari = 744 dp (a tablet)")
	ok(is_equal_approx(LD.short_side_dp(1080, 420, true, false), 1080.0 * 160.0 / 420.0), "Android APK keeps 160 dpi = 1 dp")
	ok(is_equal_approx(LD.short_side_dp(1440, 144, false, false), 960.0), "Windows keeps 96")
	LD = null   # or the script is still held at quit
	# Rail auto-hide (owner 2026-11-21): idle -> slides away, games take the full width;
	# a drag from the left edge pulls it back over the games.
	_ld = ld
	root.gui_release_focus()
	ok(ld._rail_docked and ld._rail_idle.wait_time == 15.0 and not ld._rail_idle.is_stopped(), "rail idle timer runs (15 s)")
	ld._rail_idle.stop()
	ld._on_rail_idle()
	for i in 60:
		if not ld._rail_docked:
			break
		await process_frame
	await _frames(3)
	ok(not ld._rail_docked and not ld._rail.visible and ld._main.position.x == 0.0, "idle: rail hides, games start at the left edge")
	ok(ld._rail_handle.visible, "edge tab shows while the rail is away")
	var lx: float = ld.get_global_rect().position.x
	var y: float = ld.size.y / 2.0
	_mouse(Vector2(lx + 4, y), true)
	for dx in [20.0, 60.0, ld.rail_w + 20.0]:
		_drag(Vector2(lx + 4 + dx, y))
		await process_frame
	_mouse(Vector2(lx + ld.rail_w + 24, y), false)
	await _frames(30)
	ok(ld._rail_open and ld._rail.visible and ld._rail.position.x == 0.0, "edge drag opens the rail over the games")
	ok(ld._header_margin.get_theme_constant("margin_left") == int(ld.dp(16) + ld.rail_w), "the view's title moves clear of the open rail")
	_hover(Vector2(lx + ld.rail_w / 2.0, y))
	ok(ld._rail_idle.time_left > 14.0, "mouse on the rail: 15 s")
	_hover(Vector2(lx + ld.rail_w + 60, y))
	ok(ld._rail_idle.time_left <= 3.0 and ld._rail_idle.time_left > 2.0, "mouse leaves the rail: hides 3 s later")
	_hover(Vector2(lx + ld.rail_w + 90, y))
	ok(ld._rail_idle.time_left <= 3.0, "moving over the games doesn't restart the 3 s")
	_mouse(Vector2(lx + ld.rail_w / 2.0, y), true)
	_mouse(Vector2(lx + ld.rail_w / 2.0, y), false)
	_mouse(Vector2(lx + ld.rail_w + 60, y + 40), true)
	_mouse(Vector2(lx + ld.rail_w + 60, y + 40), false)
	ok(ld._rail_idle.time_left <= 3.0, "a tap on the games: hides 3 s later")
	ld._on_rail_idle()
	await _frames(30)
	ok(not ld._rail_open and not ld._rail.visible, "idle again: rail slides away")
	ok(ld._header_margin.get_theme_constant("margin_left") == int(ld.dp(16)), "title back at the edge once the rail hides")
	ok(ld._rail_handle.visible and ld._rail_handle.get_script() == preload("res://scripts/hub/edge_hint.gd") and ld._rail_handle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "edge line + ripples show, never take input")
	# Options > Display > Side menu: Always shown (the 0.43.0 rail). Not saved: the var only.
	root.get_node("Settings").rail_fixed = true
	ld._build()
	await _frames(3)
	ld._on_rail_idle()
	await _frames(30)
	ok(ld._rail_docked and ld._rail.visible and ld._rail_idle.is_stopped() and ld._main.position.x == ld.rail_w, "Always shown: rail docked, never hides")
	root.get_node("Settings").rail_fixed = false
	ld._build()   # Options closed after switching back to Auto-hide
	await _frames(3)
	ok(not ld._rail_idle.is_stopped() and ld._rail_idle.time_left <= 3.0, "back to Auto-hide: the rail goes 3 s later, visibly")
	for i in 300:
		if ld._trash.is_empty():
			break
		await process_frame
	for i in 300:   # let the old layout (before the rail hid) finish freeing, a piece per frame
		if ld._trash.is_empty():
			break
		await process_frame

	print("layout d logic: %d failure(s)" % fails)
	quit(fails)
