extends SceneTree
## Beached's guided opening on the real scene: the HUD parts appear one at a time. Run:
## godot --headless --path . --script res://tools/test_wilson_opening.gd  (backs up the desktop save)
var fails := 0
var checks := 0
func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL: ", what)

func _init() -> void:
	var save := OS.get_user_data_dir() + "/wilson_save.json"
	var backup := ""
	if FileAccess.file_exists(save):
		backup = FileAccess.get_file_as_string(save)
	var g = load("res://scenes/games/wilson/wilson.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.4).timeout
	g.auto_pause = false
	g.home.start_mode(g.home.cfg["modes"][0])
	await create_timer(0.3).timeout
	var np = g.get_node_or_null("LookPicker")
	if np:
		np.queue_free()
	g.engine = load("res://scripts/games/wilson/wilson_engine.gd").new()
	g.engine.reset(g.now(), 0, "south", 7, "female3")
	g.engine.tut = 0
	g.started = true
	g._start_play()
	await create_timer(0.8).timeout
	ok(g.pad != null, "Pad exists")
	ok(not g._bars_panel.visible, "step 1: no bars")
	ok(not g._clock.visible, "step 1: no clock")
	for k in g._hud_btns:
		ok(not g._hud_btns[k].visible, "step 1: no %s button" % k)
	ok(g.pad.visibility_of("move") == 1.0, "step 1: the stick shows")
	ok(g.pad.visibility_of("a") == 0.0 and g.pad.visibility_of("b") == 0.0, "step 1: A and B hidden")
	ok(g._quest.text.contains("walk") or g._quest.text.contains("caminar"), "quest line is short: " + g._quest.text)
	Input.action_press("pad_move_right", 1.0)
	await create_timer(1.2).timeout
	Input.action_release("pad_move_right")
	await create_timer(0.8).timeout
	ok(g.engine.tut >= 1, "walking with the stick finishes step 1 (tut %d)" % g.engine.tut)
	ok(g.pad.visibility_of("a") > 0.0 or g.pad._rv.has("a"), "A is revealed")
	ok(not g._hud_btns.bag.visible, "bag still hidden")
	g.engine.tut = 8
	g.engine.stats["ev:structure_built:campfire"] = 1
	g._refresh_hud()
	ok(g._hud_btns.bag.visible and g._hud_btns.craft.visible, "bag + craft shown after the fire")
	ok(g._bars_panel.visible and g._bar_rows.hp.visible and not g._bar_rows.food.visible, "only health in the panel")
	ok(g._tut_card.visible, "the explanation card is up")
	g._on_tut_ack()
	ok(g._bar_rows.food.visible, "Got it reveals the next bar")
	g.engine.tut = -1
	g._refresh_hud()
	ok(g._clock.visible and g._bar_rows.water.visible and g._hud_btns.journal.visible, "all visible once the opening is over")
	# dawn start
	g._set_clock_to_dawn()
	var e2 = load("res://scripts/games/wilson/wilson_engine.gd").new()
	e2.reset(g.now(), g._tz(), g._default_hemisphere(), 0, "male1")
	var h: float = e2.hour()
	ok(h > e2.sunrise_h() and h < e2.sunrise_h() + 1.0, "a new island starts right after sunrise (%.2f vs %.2f)" % [h, e2.sunrise_h()])
	g.clock_offset = 0.0
	g.save_debug()
	if backup != "":
		var f := FileAccess.open(save, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	elif FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	print("wilson opening: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
