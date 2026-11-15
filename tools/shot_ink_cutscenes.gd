extends SceneTree

## Ink Ninja cutscenes in a real window: frames of each built scene at chosen times, plus
## the slowest frame time (draw cost) over a full play-through.
##   godot --path . --resolution 1280x720 --script res://tools/shot_ink_cutscenes.gd -- <out_dir>

const Cut = preload("res://scripts/games/ink_ninja/cutscene.gd")
const SHOTS := {"intro": [2.0, 6.0, 10.5, 13.0, 17.5, 22.0, 24.5, 27.0], "after-1B": [1.0, 3.0, 5.5, 7.6, 9.0, 11.0]}

func _initialize() -> void:
	_run()

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://cut_shots"
	DirAccess.make_dir_recursive_absolute(out)
	# The cutscene remembers what was seen in the player's real save: put it back afterwards.
	var seen_before := FileAccess.get_file_as_string(Cut.SEEN_PATH) if FileAccess.file_exists(Cut.SEEN_PATH) else ""
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var c = Cut.new()
	host.add_child(c)
	await process_frame
	for scene in SHOTS:
		c.play(scene)
		for at in SHOTS[scene]:
			c.t = at
			c.last = at
			for i in 3:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s_%04.1f.png" % [scene, at]))
			print("SHOT ", scene, " ", at)
		# Cost: play it at 60 fps and time _draw itself.
		var worst := 0.0
		var total := 0.0
		var n := 0
		var tt := 0.0
		while tt < float(Cut.SCENES[scene].dur):
			c.t = tt
			c.last = tt
			c.queue_redraw()
			await process_frame
			worst = maxf(worst, c.draw_ms)
			total += c.draw_ms
			n += 1
			tt += 1.0 / 60.0
		print("DRAW ", scene, ": avg %.1f ms, worst %.1f ms over %d frames" % [total / n, worst, n])
		c._end()
	if seen_before == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Cut.SEEN_PATH))
	else:
		var f := FileAccess.open(Cut.SEEN_PATH, FileAccess.WRITE)
		f.store_string(seen_before)
	quit()
