extends SceneTree

## Drives the Creation scene with real mouse events: tap-to-add, drag to
## combine, drag to trash, double-tap duplicate, tap-two-items, shelf drag,
## hints, search/filter, save/resume, settings. Needs a window for screenshots
## (pass an out dir) but also runs --headless without one.
##   godot --headless --path . --script res://tools/test_creation_game.gd [-- <out_dir>]
## WRITES user://creation_save.json (and stats): back up user data first.

var fails := 0
var game
var out_dir := ""

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await process_frame

## Real time (tweens run on the clock, headless frames run much faster).
func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func shot(name: String) -> void:
	if out_dir == "":
		return
	await frames(2)
	root.get_texture().get_image().save_png(out_dir + "/" + name + ".png")

func mouse(pos: Vector2, pressed: bool, button := true) -> void:
	var e: InputEvent
	if button:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.position = pos
		b.global_position = pos
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e = b
	else:
		var m := InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		e = m
	root.push_input(e, true)

func drag(from: Vector2, to: Vector2) -> void:
	mouse(from, true)
	await frames(1)
	var steps := 6
	for i in range(1, steps + 1):
		mouse(from.lerp(to, float(i) / steps), false, false)
		await frames(1)
	mouse(to, false)
	await frames(2)

func tap(pos: Vector2) -> void:
	mouse(pos, true)
	await frames(1)
	mouse(pos, false)
	await frames(2)

func center_of(chip: Control) -> Vector2:
	return chip.get_global_rect().get_center()

func chip_ids() -> Array:
	var out: Array = []
	for c in game.table.chips():
		out.append(c.item_id)
	out.sort()
	return out

func clear_table() -> void:
	for c in game.table.chips():
		game._remove_chip(c, false)
	await frames(2)

func shelf_chip(id: String):
	for c in game.shelf_flow.get_children():
		if c is Control and "item_id" in c and c.item_id == id:
			return c
	return null

func _run() -> void:
	await frames(3)
	change_scene_to_file("res://scenes/games/creation/creation.tscn")
	await wait(0.5)
	game = current_scene
	check(game != null and game.engine != null, "scene boots")
	if game.info:
		game.info.close()
	# a clean slate (this test owns the save)
	game.engine.reset_progress()
	game.engine.settings = game.engine.DEFAULT_SETTINGS.duplicate()
	game.engine.settings.lang = "en"
	game.hide_spent_box.set_pressed_no_signal(false)
	game.lang = "en"
	game._rename_everything()
	for c in game.table.chips():
		game._remove_chip(c, false)
	game._refresh_all()
	game.home.start_mode(game.home.cfg.modes[0])
	await frames(5)
	paused = false
	check(not game.home.home.visible, "Landing closed by Play")
	check(game.engine.found_count() == 4 and game.shelf_flow.get_child_count() == 4, "starts with the 4 elements on the shelf")
	await shot("01_start")

	# --- tap a shelf item: it lands on the table
	var earth = shelf_chip("earth")
	await tap(center_of(earth))
	check(chip_ids() == ["earth"], "tapping a shelf item adds it to the table")
	var fire = shelf_chip("fire")
	await tap(center_of(fire))
	check(chip_ids() == ["earth", "fire"], "second tap adds fire")
	# --- drag one chip onto the other: lava
	var chips: Array = game.table.chips()
	var a = chips[0]
	var b = chips[1]
	await drag(center_of(a), center_of(b))
	await wait(0.7)
	check(game.engine.is_found("lava"), "drag earth onto fire discovers lava")
	check(chip_ids() == ["lava"], "ingredients are replaced by the result on the table: %s" % str(chip_ids()))
	check(game.count_label.text.contains("5"), "counter updated: %s" % game.count_label.text)
	check(game.toast_panel.visible, "discovery toast shown")
	await shot("02_lava")

	# --- a miss: remembered, nothing lost
	await tap(center_of(shelf_chip("water")))
	await wait(0.5)
	var lava = null
	var water = null
	for c in game.table.chips():
		if c.item_id == "lava":
			lava = c
		elif c.item_id == "water":
			water = c
	check(lava != null and water != null, "lava and water on the table")
	# lava + water = stone (a hit); use wind + earth first for a miss
	await clear_table()
	game._add_to_table("fire", Vector2(40, 40))
	game._add_to_table("lava", Vector2(250, 40))
	await wait(0.5)
	chips = game.table.chips()
	await drag(center_of(chips[0]), center_of(chips[1]))
	await frames(5)
	check(game.engine.is_failed("fire", "lava"), "a miss is remembered")
	check(chip_ids() == ["fire", "lava"], "a miss keeps both chips")
	# hovering the failed pair marks the target as bad (greyed + x)
	chips = game.table.chips()
	var cf = chips[0] if chips[0].item_id == "fire" else chips[1]
	var cl = chips[0] if chips[0].item_id == "lava" else chips[1]
	await wait(0.7)
	mouse(center_of(cf), true)
	await frames(1)
	mouse(center_of(cl) + Vector2(3, 3), false, false)
	await frames(1)
	mouse(center_of(cl), false, false)
	await frames(2)
	check(cl.state == "bad", "hovering an already-failed pair greys the target out (state: %s)" % cl.state)
	await shot("03_failed_hover")
	mouse(center_of(cl), false)
	await wait(0.7)
	check(game.engine.found_count() == 5, "found count unchanged by a miss")

	# --- trash
	await clear_table()
	game._add_to_table("wind", Vector2(100, 100))
	await wait(0.5)
	var w = game.table.chips()[0]
	await drag(center_of(w), game.table.get_global_rect().position + game.table.trash_rect.get_center())
	await wait(0.5)
	check(chip_ids().is_empty(), "dragging to the trash removes the chip")

	# --- double-tap duplicates
	game._add_to_table("wind", Vector2(100, 100))
	await wait(0.5)
	w = game.table.chips()[0]
	for attempt in 3:  # the first tap can hitch (cold sound synth); a double-tap must be < 350 ms apart
		await tap(center_of(w))
		await tap(center_of(w))
		await wait(0.5)
		if game.table.chips().size() == 2:
			break
		game.table.select(null)
		game.table.last_tap_chip = null
	check(chip_ids() == ["wind", "wind"], "double-tap duplicates")

	# --- tap two items to combine (wind + wind = gale)
	var two: Array = game.table.chips()
	two[1].position = Vector2(260, 160)
	two[1].frac = game.table.fraction_of(two[1].position, two[1])
	await frames(2)
	await tap(center_of(two[0]))
	await frames(20)
	check(two[0].state == "selected", "first tap selects")
	await frames(20)
	await tap(center_of(two[1]))
	await wait(0.7)
	check(game.engine.is_found("gale"), "tap-two combines (wind + wind = gale)")

	# --- shelf: drag an item (mouse = immediate drag) onto the table and onto a chip
	await clear_table()
	game._add_to_table("water", Vector2(150, 60))
	await wait(0.5)
	var sw = shelf_chip("earth")
	await drag(center_of(sw), center_of(game.table.chips()[0]))
	await wait(0.7)
	check(game.engine.is_found("mud"), "shelf item dropped on a table chip combines (earth + water = mud)")
	await shot("04_shelf_drag")

	# --- search / sort / filter
	game.search.text = "mud"
	game.search.text_changed.emit("mud")
	await frames(3)
	check(game.shelf_flow.get_child_count() == 1, "search narrows the shelf")
	game.search.text = "agua"
	game.search.text_changed.emit("agua")
	await frames(3)
	check(shelf_chip("water") != null, "search works in Spanish too")
	game.search.text = ""
	game.search.text_changed.emit("")
	game.sort_opt.select(1)
	game.sort_opt.item_selected.emit(1)
	await frames(3)
	var first_az = game.shelf_flow.get_child(0)
	check(first_az.name_label.text == "Earth", "A-Z puts Earth first (got %s)" % first_az.name_label.text)
	game.tier_opt.select(2)
	game.tier_opt.item_selected.emit(2)
	await frames(3)
	check(game.shelf_flow.get_child_count() == 1 and game.shelf_flow.get_child(0) is Label, "tier filter with nothing found shows 'No matches'")
	game.tier_opt.select(0)
	game.sort_opt.select(0)
	game.search.text = ""
	game.hide_spent_box.button_pressed = true
	await frames(3)
	var want: int = game.engine.list_items("", "recent", 0, "en", true).size()
	check(game.engine.settings.hide_spent and game.shelf_flow.get_child_count() == maxi(want, 1), "hide used-up items filters the shelf and is saved")
	game.hide_spent_box.button_pressed = false
	await frames(3)
	check(not game.engine.settings.hide_spent, "hide used-up items turns off")
	game._rebuild_shelf()

	# --- hints
	var before: int = game.engine.hints_available(game._today())
	game._on_hint()
	await frames(5)
	check(game.engine.hints_available(game._today()) == before - 1, "a hint costs one")
	check(not game.engine.hint_view.is_empty(), "a hint highlights an ingredient")
	var any_hinted := false
	for c in game.shelf_flow.get_children():
		if c is Control and "hinted" in c and c.hinted:
			any_hinted = true
	check(any_hinted, "the hinted item glows on the shelf")
	await shot("05_hint")

	# --- Android back with a dialog open closes the dialog, not the game
	game._show_settings()
	await frames(5)
	check(game.modal_open(), "settings opens")
	await shot("06_settings")
	game._on_lang_pick("es")
	await frames(5)
	check(game.lang == "es" and game.engine.name_of("water", "es") == "Agua", "manual language switch")
	check(shelf_chip("water").name_label.text == "Agua", "shelf renamed to Spanish")
	game._on_theme_pick("light")
	await frames(5)
	check(not game._is_dark() and game.pal.bg.v > 0.7, "light theme")
	await shot("07_light_es")
	game._close_modal()
	game._show_collection()
	await frames(5)
	await shot("08_collection")
	game._close_modal()
	game._on_theme_pick("dark")
	game._on_lang_pick("auto")
	game._close_modal()
	await frames(3)

	# --- save -> new scene -> restored
	game._save_game()
	var found: int = game.engine.found_count()
	var n_chips: int = game.table.chips().size()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://creation_save.json"))
	check(typeof(raw) == TYPE_DICTIONARY and raw.found.size() == found, "autosave file written")
	change_scene_to_file("res://scenes/games/creation/creation.tscn")
	await wait(0.5)
	game = current_scene
	if game.info:
		game.info.close()
	check(game.engine.found_count() == found, "progress restored on reload")
	check(game.table.chips().size() == n_chips, "table restored on reload (%d chips)" % n_chips)
	check(game.home.home.visible, "reload opens on the Landing")

	# --- paywall on: paid tier shows as a silhouette (desktop test mode)
	game.engine.paywall_on = true
	game._add_to_table("metal", Vector2(40, 40))
	game.engine._add_found("metal")
	game.engine._add_found("wheel")
	game._add_to_table("metal", Vector2(40, 40))
	game._add_to_table("wheel", Vector2(250, 40))
	await wait(0.5)
	var pair: Array = game.table.chips().slice(-2)
	game._combine(pair[0], pair[1])
	await frames(10)
	check(game.engine.seen_locked.has("gear") and not game.engine.is_found("gear"), "locked result becomes a silhouette")
	game._rebuild_shelf()
	await frames(3)
	var sil = game.shelf_flow.get_child(game.shelf_flow.get_child_count() - 1)
	check(sil.state == "locked" and sil.name_label.text == "???", "silhouette on the shelf")
	await shot("09_silhouette")
	# --- buying (desktop test mode only): silhouettes become discoveries
	OS.set_environment("VOODOO_CREATION_PAYWALL", "1")
	game._show_unlock()
	await frames(3)
	check(game.modal_open(), "unlock dialog opens")
	game._on_buy()
	await frames(5)
	check(game.engine.purchase.full and game.engine.is_found("gear") and game.engine.seen_locked.is_empty(), "buying collects the silhouettes")
	OS.set_environment("VOODOO_CREATION_PAYWALL", "")
	game.engine.paywall_on = false
	game.engine.set_full_purchased(false)

	print("creation game tests: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
