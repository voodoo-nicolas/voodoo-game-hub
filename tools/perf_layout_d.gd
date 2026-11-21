extends SceneTree

## Layout D smoothness + rotation check (needs a window):
##   HUB_DEVICE=phone HUB_DP_SHORT=411 godot --path . --resolution 405x880 --script res://tools/perf_layout_d.gd
## Times rail switches (Home -> category -> search -> favorites -> Home) and a rotation, and
## checks the selected item and the scroll survive the rotation. Exit code = failures.

var fails := 0

func _initialize() -> void:
	_run()

func ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## ms the call itself takes + the worst frame in the 20 after it.
func _time(c: Callable) -> Array:
	var t0 := Time.get_ticks_usec()
	c.call()
	var call_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var worst := 0.0
	var proc := 0.0
	for i in 20:
		var a := Time.get_ticks_usec()
		await process_frame
		var d := (Time.get_ticks_usec() - a) / 1000.0
		if d > worst:
			worst = d
			proc = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	print("   (worst frame: script process %.1f ms of %.1f)" % [proc, worst])
	return [call_ms, worst]

func _run() -> void:
	load("res://scripts/common/consent.gd").prompted = true
	change_scene_to_file("res://scenes/hub/hub.tscn")
	await _frames(60)
	var cat = root.get_node("Catalog")
	cat._apply_manifest(cat._read_json_file(cat.BUNDLED_MANIFEST))
	cat.catalog_changed.emit()
	await _frames(240)   # ~4 s on Home: what a player sees before tapping (background warm-up)
	var ld = current_scene.layout_d
	for key in ["cat:board", "search", "favs", "cat:arcade", "home", "cat:board", "cat:arcade"]:
		var r: Array = await _time(ld._show.bind(key))
		print("SWITCH %-11s build %5.1f ms, worst frame after %5.1f ms" % [key, r[0], r[1]])
		ok(r[0] < 250.0, "%s builds in under 250 ms on this PC" % key)

	# Rotation: same rail item, same scroll.
	ld._show("cat:board", false)
	await _frames(10)
	ld._body_scroll.scroll_vertical = 300
	await _frames(5)
	var before: int = ld._body_scroll.scroll_vertical
	var win := root.get_window()
	var t0 := Time.get_ticks_usec()
	print("PROF_R resize at ", Time.get_ticks_msec())
	win.size = Vector2i(win.size.y, win.size.x)
	print("PROF_R resize returned ", Time.get_ticks_msec())
	await _frames(1)
	var rot_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var rot_worst := 0.0
	for i in 60:
		var a := Time.get_ticks_usec()
		await process_frame
		rot_worst = maxf(rot_worst, (Time.get_ticks_usec() - a) / 1000.0)
	print("ROTATE worst frame in the next second %.1f ms" % rot_worst)
	await _frames(10)
	print("ROTATE re-layout %.0f ms (incl. 1 frame), landscape=%s" % [rot_ms, ld.landscape])
	ok(ld.current == "cat:board", "rotation keeps the selected rail item")
	ok(absi(ld._body_scroll.scroll_vertical - before) <= 2 or ld._body_scroll.get_v_scroll_bar().max_value - ld._body_scroll.size.y < before,
		"rotation keeps the scroll (%d -> %d)" % [before, ld._body_scroll.scroll_vertical])
	ok(ld.landscape, "layout follows the new orientation")
	print("layout d: %d failure(s)" % fails)
	quit(fails)
