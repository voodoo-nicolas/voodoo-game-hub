extends SceneTree

## Ink Ninja: each act's boss in its arena (one shot per act), plus Voodoo for act 6.
##   godot --path . --resolution 1280x720 --script res://tools/shot_ink_bosses.gd -- <out_dir>
## Starts a game, so the save and the cutscene memory are put back afterwards.

func _initialize() -> void:
	_run()

func _keep(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""

func _put(p: String, text: String) -> void:
	if text == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	else:
		FileAccess.open(p, FileAccess.WRITE).store_string(text)

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://boss_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var save0 := _keep("user://ink_ninja_save.json")
	var seen0 := _keep("user://ink_ninja_cutscenes.json")
	change_scene_to_file("res://scenes/games/ink_ninja/ink_ninja.tscn")
	for i in 25:
		await process_frame
	var g = current_scene
	g.home.play_now(g._new_game.bind(1))
	for i in 10:
		await process_frame
	g.cutscene._end()
	for i in 3:
		await process_frame
	for act in range(1, 7):
		g.card_text = []
		g.engine.stage = act * 4
		g.engine.build_stage()
		g.engine.foes.clear()
		g.engine.px = g.engine.arena_x + 200
		g.engine.py = g.engine.ground_y(g.engine.px)
		for i in 50:
			await process_frame
		g.engine.hp = 5
		g.engine.boss.t = 9.0   # hold still for the picture
		g.engine.boss.phase = "idle"
		g.engine.boss.x = g.engine.arena_x + 760
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("boss_act%d.png" % act))
		print("SHOT act ", act)
	g._set_skin("voodoo")
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("boss_act6_voodoo.png"))
	g._set_skin("classic")
	g.started = false
	_put("user://ink_ninja_save.json", save0)
	_put("user://ink_ninja_cutscenes.json", seen0)
	quit()
