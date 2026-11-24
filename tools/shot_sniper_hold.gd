extends SceneTree

## The Hunt (sniper_hold) in a real window: spotting view with the rifle, the scope,
## the kill cam.
##   godot --path . --resolution 1280x720 --script res://tools/shot_sniper_hold.gd -- <out_dir>

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://sniper_hold_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _shot(name: String) -> void:
	await _wait(4)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	await _wait(3)
	change_scene_to_file("res://scenes/games/sniper_hold/sniper_hold.tscn")
	await _wait(30)
	game = current_scene
	await _shot("00_landing")
	game.home.play_now(game._start_season.bind(1))
	await _wait(30)
	await _shot("01_spotting")
	game.zoom = 6.0
	await _wait(10)
	await _shot("02_scope")
	game._start_kill_cam(game.cam + Vector2(0, 20), 4.0)
	await _wait(40)
	await _shot("03_kill_cam")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sniper_hold_save.json"))
	quit()
