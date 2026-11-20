extends SceneTree

## Screen-switch smoothness (needs a window):
##   godot --path . --resolution 405x880 --script res://tools/perf_transition.gd -- [rounds]
## Hub -> Options -> Hub, `rounds` times. For each switch: ms from the request to the
## new screen's first drawn frame, and the worst frame in the 30 frames after it.

const HUB := "res://scenes/hub/hub.tscn"
const OPTIONS := "res://scenes/hub/options.tscn"

func _initialize() -> void:
	_run()

func _switch(path: String) -> Array:
	var t0 := Time.get_ticks_usec()
	change_scene_to_file(path)
	while current_scene == null or current_scene.scene_file_path != path:
		await process_frame
	await process_frame   # the first frame that draws it
	var first := (Time.get_ticks_usec() - t0) / 1000.0
	var worst := 0.0
	for i in 30:
		var a := Time.get_ticks_usec()
		await process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - a) / 1000.0)
	return [first, worst]

## The hub's own way in: Options as a layer. Time until it reacts (first frame with it).
func _open_overlay() -> Array:
	var hub = current_scene
	var t0 := Time.get_ticks_usec()
	hub._open_options()
	await process_frame
	var first := (Time.get_ticks_usec() - t0) / 1000.0
	var worst := 0.0
	for i in 30:
		var a := Time.get_ticks_usec()
		await process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - a) / 1000.0)
	return [first, worst]

func _close_overlay() -> Array:
	var hub = current_scene
	var t0 := Time.get_ticks_usec()
	hub._options._go_to_hub()
	await process_frame
	var first := (Time.get_ticks_usec() - t0) / 1000.0
	var worst := 0.0
	for i in 30:
		var a := Time.get_ticks_usec()
		await process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - a) / 1000.0)
	return [first, worst]

func _run() -> void:
	var rounds: int = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 4
	load("res://scripts/common/consent.gd").prompted = true
	change_scene_to_file(HUB)
	for i in 90:
		await process_frame
	var to_opt: Array = []
	var to_hub: Array = []
	for r in rounds:
		to_opt.append(await _open_overlay())
		to_hub.append(await _close_overlay())
	var game_back: Array = []
	for r in 2:
		await _switch(OPTIONS)   # leaving the hub (like opening a game) ...
		game_back.append(await _switch(HUB))   # ... and coming back builds it fresh
	for pair in [["hub->options (layer)", to_opt], ["options->hub (layer)", to_hub], ["fresh hub build (back from a game)", game_back]]:
		var firsts: Array = pair[1].map(func(x): return x[0])
		var worsts: Array = pair[1].map(func(x): return x[1])
		print("TRANSITION %s: first frame %s ms, worst frame after %s ms" % [pair[0],
			", ".join(firsts.map(func(v): return "%.0f" % v)), ", ".join(worsts.map(func(v): return "%.0f" % v))])
	quit()
