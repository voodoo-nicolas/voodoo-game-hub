extends SceneTree

## Ink Ninja in a real window: Landing, a run on stage 1, a boss arena, Voodoo skin.
##   godot --path . --resolution 1280x720 --script res://tools/shot_ink_ninja.gd -- <out_dir>
## Starts games, so the save is removed afterwards when there was none before.

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://ink_ninja_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _shot(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _run() -> void:
	var had_save := FileAccess.file_exists("user://ink_ninja_save.json")
	await _wait(3)
	change_scene_to_file("res://scenes/games/ink_ninja/ink_ninja.tscn")
	await _wait(25)
	game = current_scene
	await _shot("00_landing")
	var gc: Control = game._show_goals()
	await _wait(10)
	await _shot("05_objectives")
	game.home.close_card(gc)
	await _wait(5)
	game.home.play_now(game._new_game.bind(1))
	await _wait(20)
	await _shot("08_chapter")
	game.card_text = []
	game.key_r = true
	await _wait(90)
	game.q.slash = true
	await _wait(4)
	await _shot("10_run")
	game.key_r = false
	game.engine.stage = 3
	game.engine.build_stage()
	game.engine.px = game.engine.arena_x + 200
	await _wait(60)
	await _shot("20_boss")
	game._set_skin("voodoo")
	await _wait(10)
	await _shot("30_voodoo")
	game.started = false
	if not had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ink_ninja_save.json"))
	quit()
