extends SceneTree
## Screenshots of Beached's guided opening (needs a window): godot --path . --resolution 1280x720 --script res://tools/shot_wilson_opening.gd -- <dir>
func _init() -> void:
	var dir := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var save := OS.get_user_data_dir() + "/wilson_save.json"
	var backup := FileAccess.get_file_as_string(save) if FileAccess.file_exists(save) else ""
	var g = load("res://scenes/games/wilson/wilson.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.5).timeout
	g.auto_pause = false
	g.home.start_mode(g.home.cfg["modes"][0])
	await create_timer(0.3).timeout
	var np = g.get_node_or_null("LookPicker")
	if np:
		np.queue_free()
	g._set_clock_to_dawn()
	g.engine = load("res://scripts/games/wilson/wilson_engine.gd").new()
	g.engine.reset(g.now(), 0, "south", 7, "female3")
	g.engine.tut = 0
	g.started = true
	g._start_play()
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/open_1_walk.png")
	g.engine.tut = 2
	g._refresh_hud()
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/open_2_pebble.png")
	g.engine.tut = 8
	g._refresh_hud()
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/open_3_health.png")
	g.engine.tut = -1
	g.clock_offset = 0.0
	g.save_debug()
	if backup != "":
		var f := FileAccess.open(save, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	quit()
