extends SceneTree

## Screenshots of the new Game Browser (needs a window, not --headless):
##   godot --path . --resolution 1280x720 --script res://tools/shot_netflix.gd -- <out_dir> [game_id] [category_index] [strip|grid]
## Uses (and restores) Settings.hub_layout; no data is written.

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var gid: String = args[1] if args.size() > 1 else "chess"
	var cat: int = int(args[2]) if args.size() > 2 else 0
	DirAccess.make_dir_recursive_absolute(out)
	for i in 3:
		await process_frame
	var settings = root.get_node("Settings")
	var was: String = settings.hub_layout
	settings.hub_layout = args[3] if args.size() > 3 else "strip"
	load("res://scripts/common/consent.gd").prompted = true   # no consent screen over the hub
	var hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)
	for i in 10:
		await process_frame
	hub._show_browser()
	hub._slide_done(true)
	for i in 10:
		await process_frame
	var nx = hub.netflix
	root.get_viewport().get_texture().get_image().save_png(out + "/0_open.png")
	if not nx.grid_mode:
		nx._on_tab("cat:%d" % cat)
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/1_browser.png")
	nx.select(gid)
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/2_detail.png")
	settings.hub_layout = was
	quit()
