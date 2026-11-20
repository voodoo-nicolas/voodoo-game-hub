extends SceneTree

## Ancient Assassins in a real window: Landing, aiming, a throw in flight, a hit,
## Skull mode, the result card.
##   godot --path . --resolution 1280x720 --script res://tools/shot_ancient_assassins.gd -- <out_dir>
## Starts a fight, so the save is removed afterwards if there was none before.

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://ancient_assassins_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _shot(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	var had_save := FileAccess.file_exists("user://ancient_assassins_save.json")
	await _wait(3)
	change_scene_to_file("res://scenes/games/ancient_assassins/ancient_assassins.tscn")
	await _wait(40)
	game = current_scene
	await _shot("1_landing")
	game.home.play_now(game._new_vs_cpu.bind(1))
	await _wait(20)
	var e = game.engine
	e.reset(4242, {"chars": [0, 1], "style": 2})
	game._make_scenery()
	game._start_turn()
	game.banner_t = 0.0
	game.dragging = true
	e.set_aim(0, 52.0, 74.0)
	game.pull[0] = 1.0
	await _shot("2_aim")
	game.dragging = false
	game._throw()
	await _wait(55)
	await _shot("3_flight")
	# A staged hit: the right one takes a javelin to the head.
	await _wait(200)
	game.phase = "aim"
	e.turn = 0
	game._on_landed({"kind": "hit", "f": 1, "zone": "head", "dmg": 68, "p": Vector2(e.fighters[1].x, e.fighters[1].y - 108)})
	await _wait(8)
	await _shot("4_hit")
	game._set_skin("voodoo")
	await _wait(5)
	await _shot("5_skull_mode")
	game._set_skin("classic")
	e.fighters[1].hp = 0
	e.winner = 0
	game._game_over()
	await _wait(50)
	await _shot("6_result")
	game._see_field()
	await _shot("7_see_field")
	if not had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ancient_assassins_save.json"))
	quit()
