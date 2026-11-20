extends SceneTree

## Beached: close-up shots of the castaway gathering pebbles and of palm C (owner bug list 2026-11-20).
##   godot --path . --resolution 1280x720 --audio-driver Dummy --script res://tools/shot_wilson_spots.gd -- <out_dir>
## Backs up and restores the save + debug files.

const FILES := ["user://wilson_save.json", "user://wilson_debug.json"]
var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://wilson_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _wait(4)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	var backup := {}
	for f in FILES:
		if FileAccess.file_exists(f):
			backup[f] = FileAccess.get_file_as_string(f)
			DirAccess.remove_absolute(f)
	await _wait(3)
	change_scene_to_file("res://scenes/games/wilson/wilson.tscn")
	await _wait(25)
	game = current_scene
	game.auto_pause = false
	game.home.start_mode(game.home.cfg["modes"][0])
	await _wait(10)
	var picker = game.get_node_or_null("LookPicker")
	if picker:
		picker.queue_free()
	var np = game.get_node_or_null("NamePicker")
	if np:
		np.queue_free()
	game._start_island("Robin", "female5")
	await _wait(10)
	if game.info and "overlay" in game.info and game.info.overlay and game.info.overlay.visible:
		game.info.close()
	var e = game.engine
	e.tut = -1
	game.clock_offset += e.next_hour(10.0) - e.t
	game.catch_up(false)
	e.bars = {"hp": 100.0, "food": 80.0, "water": 70.0, "energy": 90.0}
	game.after_change()
	for look in ["female5", "female3", "male1"]:
		e.look = look
		game.world.castaway.set_look(look)
		game._try("gather", "stones", {})
		for i in 400:
			await process_frame
			if not e.active().is_empty() and game.world.castaway.position.distance_to(D_stand()) < 4.0:
				break
		await _wait(20)
		for k in 3:          # the blonde cycles craft / carve / tool every 7 s
			game.world.castaway._t = 1.0 + 7.0 * k
			await _shot("pebble_%s_%d" % [look, k])
		e.cancel(0)
		await _wait(5)
	game._walk_to(Vector2(1400, 480))
	await _wait(400)
	await _shot("palm_c")
	game.world.castaway.position = Vector2(712, 535)
	await _wait(30)
	e.quest = "T04"
	for st in load("res://scripts/games/wilson/wilson_data.gd").INTRO:
		e.stats[str(st.key)] = int(st.need)
	game.after_change()
	await _wait(10)
	await _shot("shallows")
	for f in FILES:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	for f in backup:
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_string(backup[f])
		fa.close()
	quit()

func D_stand() -> Vector2:
	return load("res://scripts/games/wilson/wilson_data.gd").SPOTS.stones.stand
