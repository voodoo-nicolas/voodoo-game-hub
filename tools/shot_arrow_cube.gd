extends SceneTree

## Arrow Cube in a real window: Landing, level 1, a tap, a bump, a late level (wraps, two-way,
## stops, forks), the Safe highlight, and the Voodoo skin.
##   godot --path . --resolution 720x1280 --script res://tools/shot_arrow_cube.gd -- <out_dir>
## Starts games: back up the PC build's user data first (CLAUDE.md). Removes its own save.

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://arrow_cube_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _wait(frames: int) -> void:
	for _i in frames:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)

func _run() -> void:
	await _wait(3)
	change_scene_to_file("res://scenes/games/arrow_cube/arrow_cube.tscn")
	await _wait(30)
	game = current_scene
	if game.info and game.info.has_method("close"):
		game.info.close()
	await _shot("01_landing")
	game.home.play_now(game._start_level.bind(1))
	await _wait(20)
	await _shot("02_level1")
	var free: Array = game.engine.free_arrows()
	print("level 1 arrows=%d free=%d" % [game.engine.arrows.size(), free.size()])
	game._on_arrow_tapped(int(free[0]), 0)
	await _wait(10)
	await _shot("03_flying")
	# a bump: any arrow that is blocked
	for a in game.engine.arrows:
		if game.engine.preview(int(a.id)).result == "blocked":
			game._on_arrow_tapped(int(a.id), 0)
			break
	await _wait(6)
	await _shot("04_bump")
	for lv in [30, 130, 300]:
		game._start_level(lv)
		await _wait(20)
		await _shot("05_level%d" % lv)
	game._safe_now()
	await _wait(5)
	await _shot("06_safe")
	game.world.yaw += 2.4
	await _wait(5)
	await _shot("07_back")
	game._set_skin("voodoo")
	await _wait(10)
	await _shot("08_voodoo")
	game._start_level(506)
	await _wait(20)
	await _shot("09_endless_voodoo")
	# tap through picking: centre of the screen
	var vp := root.get_visible_rect().size
	var hit: Dictionary = game.world.pick(vp * 0.5)
	print("pick centre -> ", hit)
	game.playing = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://arrow_cube_save.json"))
	quit()
