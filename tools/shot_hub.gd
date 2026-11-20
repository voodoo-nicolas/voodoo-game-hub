extends SceneTree

## Screenshots of the hub home (needs a window, not --headless):
##   godot --path . --resolution 1280x576 --script res://tools/shot_hub.gd -- <out_dir> <name> [options] [wait_frames]
## "options" also opens Options and shoots it. Reads nothing from the server beyond what the hub
## does on its own; writes no save data.

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var name: String = args[1] if args.size() > 1 else "hub"
	var options := args.size() > 2 and args[2] == "options"
	var progress := args.size() > 2 and args[2] == "progress"
	var wait: int = int(args[3]) if args.size() > 3 else 90
	DirAccess.make_dir_recursive_absolute(out)
	for i in 3:
		await process_frame
	load("res://scripts/common/consent.gd").prompted = true   # no consent screen over the hub
	change_scene_to_file("res://scenes/hub/hub.tscn")
	for i in wait:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	if progress:
		root.get_node("Social")._ask_progress("Nico")   # the sign-in question, no account change
		for i in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s_progress.png" % [out, name])
		root.get_node("Social")._on_signed_out_progress()
	if options:
		current_scene._open_options()   # the hub's own way: a layer over itself
		for i in 30:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s_options.png" % [out, name])
		current_scene._options._go_to_hub()
		for i in 30:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s_back.png" % [out, name])
	quit()
