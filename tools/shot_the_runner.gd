extends SceneTree

## Plays The Runner in a real window and saves screenshots of every screen (needs a window, not
## --headless):
##   godot --path . --resolution 1280x720 --script res://tools/shot_the_runner.gd -- <out_dir> [text size 0/1/2] [skin]
## For a phone shape use e.g. --resolution 1170x540. Writes user://the_runner_save.json (the game's
## autosave); the owner's real one is backed up and put back.

const SAVE := "user://the_runner_save.json"

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://the_runner_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run(int(args[1]) if args.size() > 1 else -1, args[2] if args.size() > 2 else "classic")

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _run(text_size: int, skin: String) -> void:
	var backup := ""
	if FileAccess.file_exists(SAVE):
		backup = FileAccess.get_file_as_string(SAVE)
	await _wait(3)
	if text_size >= 0:
		var settings := root.get_node_or_null("/root/Settings")
		if settings:
			settings.text_size = text_size
	change_scene_to_file("res://scenes/games/the_runner/the_runner.tscn")
	await _wait(25)
	game = current_scene
	await _shot("00_landing")
	game.home.start_mode(game.home.cfg["modes"][0])
	await _wait(10)
	if game.info and "overlay" in game.info and game.info.overlay and game.info.overlay.visible:
		game.info.close()
	if skin != "classic":
		game._set_skin(skin)
	await _shot("01_prologue")
	game._skip_story()
	await _wait(5)
	await _shot("02_dock_luna")
	var e = game.engine
	game.dock.open("market")
	await _shot("03_market")
	game.dock.open("shipyard")
	await _shot("04_shipyard")
	game.dock.open("fixer")
	await _shot("05_fixer")
	game.dock.open("kessel")
	await _shot("06_kessel")
	game.dock.open("")
	game.launch()
	await _wait(5)
	await _shot("07_map_docked")
	game.map.world_tapped.emit("tidewater")
	game.map.selected = "tidewater"
	await _shot("08_map_course_card")
	game._set_course("tidewater")
	e.rng.seed = 12345
	await _wait(40)
	await _shot("09_map_flying")
	# an inspection at the dock
	e.encounter = {"kind": "inspect", "faction": "concord", "bribe": e.bribe_cost(), "fine": 120, "log": []}
	game.show_encounter()
	await _shot("10_inspection")
	e.encounter = {}
	game._close_over()
	# a fight
	e._open_fight("pirate", "A raider ship drops out of the dark and hails you.")
	game.show_encounter()
	await _shot("11_pirates")
	game._choose("fight")
	await _wait(3)
	game._choose("attack")
	await _wait(3)
	await _shot("12_fight")
	while not e.encounter.is_empty():
		game._choose("attack")
		await _wait(2)
	await _shot("13_fight_result")
	game._after_encounter()
	# arrive at Tidewater: M01 hand-over
	if game.map != null:
		game.map._arrive("tidewater")
	else:
		e.loc = "tidewater"
		game.show_dock()
	await _wait(5)
	game._close_over()
	e.encounter = {}
	await _shot("14_dock_tidewater")
	for tab in ["inventory", "skills", "missions", "map", "ship", "stats"]:
		game.open_computer()
		game.computer.tab = tab
		game.computer.rebuild()
		await _shot("20_menu_" + tab)
	game.close_computer()
	# Old Earth, the salvage site
	e.loc = "old_earth"
	game.show_dock()
	await _shot("30_dock_old_earth")
	game.home.pause()
	await _shot("40_pause")
	game.home.resume_play()
	if backup != "":
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()
