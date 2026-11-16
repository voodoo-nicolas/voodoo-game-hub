extends SceneTree

## Hover Duel: just the Landing screenshot.
##   godot --path . --resolution 1280x720 --script res://tools/shot_hover_duel_landing.gd -- <out_dir> [name]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://hover_duel_shots"
	var nm: String = args[1] if args.size() > 1 else "landing"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_go(out_dir, nm)

func _go(out_dir: String, nm: String) -> void:
	for i in 3:
		await process_frame
	change_scene_to_file("res://scenes/games/hover_duel/hover_duel.tscn")
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(nm + ".png"))
	print("SHOT ", nm)
	quit()
