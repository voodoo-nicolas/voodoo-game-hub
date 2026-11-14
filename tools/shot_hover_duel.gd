extends SceneTree

## Hover Duel in a real window: Landing, a battle on every land, 2 Players, Voodoo skin.
##   godot --path . --resolution 1280x720 --script res://tools/shot_hover_duel.gd -- <out_dir>
## Starts games, so the save is removed afterwards (it never existed before a battle).

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://hover_duel_shots"
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
	var had_save := FileAccess.file_exists("user://hover_duel_save.json")
	await _wait(3)
	change_scene_to_file("res://scenes/games/hover_duel/hover_duel.tscn")
	await _wait(25)
	game = current_scene
	await _shot("00_landing")
	for n in [0, 2, 5, 6, 8, 11]:
		game.home.play_now(game._start_campaign.bind(n))
		await _wait(150)
		await _shot("1%d_battle" % n)
	game.home.play_now(game._new_duo)
	await _wait(90)
	await _shot("20_duo")
	game._set_skin("voodoo")
	await _wait(30)
	await _shot("30_voodoo")
	game.started = false
	if not had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://hover_duel_save.json"))
	quit()
