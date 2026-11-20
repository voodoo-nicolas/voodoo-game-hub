extends SceneTree
## Screenshots of Block Escape, Arrow Pop and Arrows (landing + a few levels).
## godot --path . --resolution 540x1170 --script res://tools/shot_puzzles.gd -- <out_dir> [game]
func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(out: String, name: String) -> void:
	await _wait(12)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var only: String = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	for id in ["block_escape", "arrow_pop", "arrows"]:
		if only != "" and only != id:
			continue
		change_scene_to_file("res://scenes/games/%s/%s.tscn" % [id, id])
		await _wait(25)
		var g = current_scene
		await _shot(out, id + "_landing")
		for n in [2, 4, 40]:
			match id:
				"block_escape": g._start_level(n)
				"arrow_pop": g._deal(n)
				"arrows": g._start_level(n)
			g.home.visible = false
			await _shot(out, "%s_lv%d" % [id, n])
	quit()
