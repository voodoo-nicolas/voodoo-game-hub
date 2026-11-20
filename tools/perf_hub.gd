extends SceneTree

## Frame-time check of a hub screen (needs a window):
##   godot --path . --resolution 1280x566 --script res://tools/perf_hub.gd -- [scene] [frames]
## Prints average / worst process time per frame after the screen settles.

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://scenes/hub/hub.tscn"
	var frames: int = int(args[1]) if args.size() > 1 else 300
	load("res://scripts/common/consent.gd").prompted = true
	change_scene_to_file(scene)
	for i in 60:
		await process_frame
	var total := 0.0
	var worst := 0.0
	var t0 := Time.get_ticks_usec()
	for i in frames:
		var a := Time.get_ticks_usec()
		await process_frame
		var d := (Time.get_ticks_usec() - a) / 1000.0
		total += d
		worst = maxf(worst, d)
	print("PERF %s: avg %.2f ms/frame, worst %.2f ms, cpu process %.2f ms" % [scene, total / frames, worst, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	quit()
