extends SceneTree

## Ink Ninja cutscenes in a real window: frames of each built scene at chosen times, plus
## the slowest frame time (draw cost) over a full play-through.
##   godot --path . --resolution 1280x720 --script res://tools/shot_ink_cutscenes.gd -- <out_dir>

const Cut = preload("res://scripts/games/ink_ninja/cutscene.gd")
const SHOTS := {"intro": [6.0, 13.0, 24.5], "drip": [4.0, 7.5, 11.0], "after-1B": [3.0, 11.0], "after-2B": [3.0, 5.6, 11.0],
	"after-3B": [5.0, 10.5, 11.3, 13.0, 19.0], "act4": [5.0, 9.5], "after-4B": [3.0, 9.0, 14.0], "act5": [2.05, 5.0, 10.2],
	"after-5B": [4.0, 11.0], "seal": [1.0, 3.0, 6.5, 10.0, 12.5, 14.2], "ending-a": [5.0, 15.0, 22.0, 27.0], "ending-b": [4.0, 10.9, 13.0, 18.0]}

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
	var only := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
	for scene in SHOTS:
		if only != "" and scene != only:
			continue
		c.play(scene)
		for at in SHOTS[scene]:
			c.t = at
			c.last = at
			c.wait_done = at > 12.6 or (scene == "ending-b" and at > 10.75)   # past a Slash wait: as if slashed
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
			c.wait_done = true
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
