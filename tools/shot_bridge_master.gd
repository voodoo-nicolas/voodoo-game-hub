extends SceneTree
## Bridge Master screenshots: godot --path . --resolution 1280x720 --script res://tools/shot_bridge_master.gd -- <out_dir>
func _wait(n: int) -> void:
	for i in n:
		await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	change_scene_to_file("res://scenes/games/bridge_master/bridge_master.tscn")
	await _wait(25)
	var g = current_scene
	for n in [1, 3, 5]:
		g._start_level(n)
		g.home.visible = false
		await _wait(20)
		root.get_texture().get_image().save_png(out.path_join("lv%d.png" % n))
	quit()
