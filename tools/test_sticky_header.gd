extends SceneTree

## The hub's pinned category header: open a category, scroll deep into its
## games, the header must be pinned at the top; tapping it closes the
## category and brings its row back into view. Needs a window (screenshots):
##   godot --path . --resolution 405x720 --script res://tools/test_sticky_header.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	for i in 3:
		await process_frame
	change_scene_to_file("res://scenes/hub/hub.tscn")
	for i in 30:
		await process_frame
	var hub = current_scene
	var fails := 0
	hub._show_browser()
	for i in 5:
		await process_frame
	hub._toggle_category(0)
	for i in 10:
		await process_frame
	if hub._sticky != null:
		print("FAIL: pinned header shown before scrolling")
		fails += 1
	hub.list_scroll.scroll_vertical = 1600
	for i in 10:
		await process_frame
	if hub._sticky == null:
		print("FAIL: no pinned header after scrolling into the games")
		fails += 1
	else:
		var top: float = hub.list_scroll.get_global_rect().position.y
		var got: float = hub._sticky.get_global_rect().position.y
		if absf(got - top) > 1.0:
			print("FAIL: pinned header at y=%s, list top at %s" % [got, top])
			fails += 1
	root.get_texture().get_image().save_png(out.path_join("sticky_open.png"))
	if hub._sticky != null:
		var btn: Button = hub._sticky.get_child(hub._sticky.get_child_count() - 1)
		btn.pressed.emit()
	for i in 10:
		await process_frame
	if hub.expanded_index != -1:
		print("FAIL: tapping the pinned header didn't close the category")
		fails += 1
	if hub._sticky != null:
		print("FAIL: pinned header still there after closing")
		fails += 1
	var row: Control = hub.list_container.get_child(0)
	var view: Rect2 = hub.list_scroll.get_global_rect()
	if not view.encloses(row.get_global_rect()):
		print("FAIL: the closed category's row isn't in view")
		fails += 1
	root.get_texture().get_image().save_png(out.path_join("sticky_closed.png"))
	print("STICKY %s (%d failure(s))" % ["OK" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
