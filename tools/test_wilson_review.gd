extends SceneTree
## Beached, the 2026-11-09 review round on the real scene: the garden, the spear, the new menus, reasons
## in Spanish, the action list that keeps its buttons, the rain loop.
## Run: godot --headless --path . --script res://tools/test_wilson_review.gd  (touches the desktop save: backs it up)
const D = preload("res://scripts/games/wilson/wilson_data.gd")
var fails := 0
var checks := 0
func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL: ", what)

func _popup_texts(g) -> String:
	var out := ""
	if g._popup == null:
		return out
	for b in g._popup.find_children("*", "Button", true, false):
		out += b.text + "\n"
	return out

func _panel_texts(g) -> String:
	var out := ""
	if g._panel == null:
		return out
	for n in g._panel.find_children("*", "Label", true, false):
		out += n.text + "\n"
	for n in g._panel.find_children("*", "Button", true, false):
		out += n.text + "\n"
	return out

func _init() -> void:
	var dir := OS.get_user_data_dir()
	var backups := {}
	for f in ["wilson_save.json", "wilson_debug.json"]:
		if FileAccess.file_exists(dir + "/" + f):
			backups[f] = FileAccess.get_file_as_string(dir + "/" + f)
	TranslationServer.set_locale("en")
	var g = load("res://scenes/games/wilson/wilson.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.4).timeout
	g.home.start_mode(g.home.cfg["modes"][0])
	await create_timer(0.3).timeout
	var np = g.get_node_or_null("LookPicker")
	if np:
		np.queue_free()
	g.engine = load("res://scripts/games/wilson/wilson_engine.gd").new()
	g.engine.reset(g.now(), 0, "south", 7, "female3")
	g.started = true
	g._start_play()
	await create_timer(0.3).timeout
	var e = g.engine
	var at := Vector2(400, 300)

	# ---- the garden: plant, sprouts, harvest
	e.structures["garden_plot"] = {"built": e.t}
	g.world.sync()
	g._structure_menu("garden_plot", at)
	ok(_popup_texts(g).contains("Plant seeds") and _popup_texts(g).contains("No seeds"), "garden menu: plant, greyed out without seeds (%s)" % _popup_texts(g).strip_edges())
	e.add("seeds", 1)
	g._try("plant", "")
	ok(e.busy() and g._stand_spot("plant", "") == D.CAMP.garden_plot.stand, "planting queued at the plot")
	g.hurry()
	g.world.sync()
	ok(e.garden_state() == "growing", "growing")
	var gp = g.world._props.garden_plot
	ok(gp.tex != null and str(gp.tex.resource_path).ends_with("garden_sprouts.webp"), "the plot shows sprouts")
	g._structure_menu("garden_plot", at)
	ok(g._popup == null and g._toast.visible and g._toast.text.contains("Ready in"), "growing: a toast says how long (%s)" % g._toast.text)
	e.structures.garden_plot.ready = e.t - 1.0
	g._structure_menu("garden_plot", at)
	ok(_popup_texts(g).contains("Harvest the garden"), "ready: harvest")
	g._try("harvest", "")
	g.hurry()
	g.world.sync()
	ok(e.count("sweet_potato") == D.GARDEN_YIELD and str(gp.tex.resource_path).ends_with("garden_plot.webp"), "harvested, bare plot again")

	# ---- menus with the new things
	e.add("spear", 1)
	g._shallows_menu(at)
	ok(_popup_texts(g).contains("Spear fish"), "shallows: the spear is offered once he has one")
	e.structures["campfire"] = {"built": e.t, "fuel_until": e.t + 9999.0}
	e.structures["drying_rack"] = {"built": e.t}
	e.stats["made:spark_kit"] = 1
	e.stats["made:rope_fiber"] = 1
	g.world.sync()
	e.add("crab", 1)
	g._structure_menu("campfire", at)
	var cf := _popup_texts(g)
	ok(cf.contains(D.item_name("crab_cooked")) and cf.contains(D.item_name("fish_cooked")) and not cf.contains(D.item_name("fish_stew")), "campfire: the basics + what he holds something for (crab), not the stew")
	g._structure_menu("drying_rack", at)
	ok(_popup_texts(g).contains(D.item_name("seaweed_crisps")) and _popup_texts(g).contains(D.item_name("fish_dried")), "drying rack: dried fish and seaweed crisps")
	g._close_popup()
	e.add("bandage", 1)
	g._item_menu("bandage")
	ok(_panel_texts(g).contains("Use"), "bandage card has a Use button")
	g._use_item("bandage")
	ok(e.count("bandage") == 1 and g._toast.text.contains("Nothing to patch up"), "full health: kept, and it says why")
	g._open_craft()
	ok(g._panel != null, "craft panel opens")
	g._open_journal()
	var j := _panel_texts(g)
	ok(j.contains("Side quests") and j.contains("Lately") and not j.contains("Quests done:"), "journal: side quests, the 'Lately' heading, no raw id list")
	g._close_panel()

	# ---- reasons in Spanish
	TranslationServer.set_locale("es")
	var why: String = g._why(e.action_block("fish", ""))
	ok(why == "Necesita: %s." % D.item_name("fishing_pole") and why.contains("Caña"), "'Needs a fishing pole' is all Spanish (%s)" % why)
	ok(g._why("Needs the Windmill first.") == "Primero hace falta: Molino de viento.", "project reason in Spanish (%s)" % g._why("Needs the Windmill first."))
	ok(g._why("Missing materials.") != "Missing materials.", "plain reasons still translate")
	TranslationServer.set_locale("en")

	# ---- the action list keeps its buttons between refreshes (taps on ✕ were lost)
	e.bars.energy = 100.0
	e.queue.clear()
	e.enqueue("gather", "sticks")
	e.enqueue("gather", "stones")
	g._refresh_queue()
	await create_timer(0.1).timeout
	var first: Array = g._queue_box.get_children()
	g._refresh_queue()
	g._refresh_queue()
	var again: Array = g._queue_box.get_children()
	ok(first.size() == 2 and again.size() == 2 and first[0] == again[0] and first[1] == again[1], "same two buttons after refreshing")
	g._cancel(1)
	await create_timer(0.1).timeout
	ok(g._queue_box.get_child_count() == 1 and e.queue.size() == 1, "cancelling the second rebuilds the list (%d)" % g._queue_box.get_child_count())
	g._cancel(0)

	# ---- rain: a loop while it rains, gone when it stops
	e.weather_auto = false
	e.weather = "rain"
	g._update_sky()
	ok(g._rain != null and is_instance_valid(g._rain), "rain starts the loop")
	e.weather = "clear"
	g._update_sky()
	ok(g._rain == null, "clear sky stops it")

	# ---- story objectives point somewhere real
	for qid in ["T13", "T15", "T18", "T19"]:
		e.quest = qid
		e.flags["intro_all"] = true
		for k in ["got:stone", "got:stick", "got:frond", "made:frond_bed", "slept"]:
			e.stats[k] = 99
		ok(g._objective_ids().size() > 0, "%s has an objective mark" % qid)
	g._refresh_hud()
	ok(g._quest.text.contains("Harvest the garden"), "HUD line for T19 (%s)" % g._quest.text)

	for f in backups:
		var fa := FileAccess.open(dir + "/" + f, FileAccess.WRITE)
		fa.store_string(backups[f])
		fa.close()
	print("wilson review: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
