extends SceneTree

## Screenshots of Layout D (needs a window, not --headless). Fake the device with env vars:
##   HUB_DEVICE=phone HUB_DP_SHORT=411 godot --path . --resolution 405x880 \
##       --script res://tools/shot_layout_d.gd -- <out_dir> <name> [all]
## Shoots Home; with "all" also a category grid, search ("a" + the Quick play chip), a game card and
## the rail hidden (edge line + ripples); "edge" shoots only Home and the hidden rail.
## Writes no save data (no tile is opened, nothing is starred).

func _initialize() -> void:
	_run()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var name: String = args[1] if args.size() > 1 else "layout_d"
	var all := args.size() > 2 and args[2] == "all"
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	load("res://scripts/common/consent.gd").prompted = true
	change_scene_to_file("res://scenes/hub/hub.tscn")
	await _wait(60)
	# This checkout's manifest (the Layout D fields), not the live / cached one.
	var cat = root.get_node("Catalog")
	cat._apply_manifest(cat._read_json_file(cat.BUNDLED_MANIFEST))
	cat.catalog_changed.emit()
	await _wait(40)
	var ld = current_scene.layout_d
	_shot("%s/%s.png" % [out, name])
	if all and ld != null:
		ld._show("cat:board", false)
		await _wait(30)
		_shot("%s/%s_category.png" % [out, name])
		ld._search_text = "a"
		ld._chips = {"quick": true}
		ld._show("search", false)
		await _wait(30)
		_shot("%s/%s_search.png" % [out, name])
		ld._search_text = ""
		ld._chips = {}
		ld._show("home", false)
		await _wait(10)
		ld._open_detail("chess")
		await _wait(20)
		_shot("%s/%s_card.png" % [out, name])
		ld._close_detail()
	# The rail away: the glowing edge line + ripples (two moments of the pulse).
	if args.size() > 2 and args[2] in ["all", "edge"] and ld != null:
		ld._rail_idle.stop()
		ld._on_rail_idle()
		await _wait(60)
		print("edge hint still=%s (Reduce motion / Menu animations)" % ld._rail_handle.still)
		_shot("%s/%s_edge.png" % [out, name])
		await _wait(40)
		_shot("%s/%s_edge2.png" % [out, name])
	quit()
