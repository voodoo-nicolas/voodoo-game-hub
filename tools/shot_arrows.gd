extends SceneTree
## Arrows screenshots: godot --path . --resolution 540x1170 --script res://tools/shot_arrows.gd -- <out_dir>
func _wait(n: int) -> void:
	for i in n:
		await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	change_scene_to_file("res://scenes/games/arrows/arrows.tscn")
	await _wait(25)
	var g = current_scene
	root.get_texture().get_image().save_png(out.path_join("landing.png"))
	for n in [1, 45, 101, 250]:
		g._start_level(n)
		g.home.visible = false
		await _wait(10)
		root.get_texture().get_image().save_png(out.path_join("lv%d.png" % n))
	# A wrong tap on a blocked arrow, rainbow colours, zoomed in.
	g._pick_colors(1)
	for i in g.engine.arrows.size():
		if not g.engine.can_remove(i):
			g.engine.tap(i)
			break
	g._zoom_at(g.board.size / 2.0, 2.5)
	g._update_hud()
	await _wait(10)
	root.get_texture().get_image().save_png(out.path_join("zoom_red.png"))
	g._pick_colors(0)
	g._set_skin("voodoo")
	g._zoom_reset()
	await _wait(10)
	root.get_texture().get_image().save_png(out.path_join("voodoo.png"))
	quit()
