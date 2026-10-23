extends SceneTree

## Plays the Turned slice in a real window and saves screenshots (needs a window, not --headless):
##   godot --path . --resolution 1280x720 --script res://tools/shot_turned.gd -- <out_dir>
## Optional second argument: the text size index (0 Normal, 1 Large, 2 Extra large), not saved.
## For a phone shape use e.g. --resolution 1170x540.
## Writes user://turned_save.json (the game's autosave); the owner's real one is backed up and put back.

const Save = preload("res://scripts/games/turned/turned_save.gd")

var out_dir := ""
var _text_size := -1
var game: Control
var world: Node2D
var hud: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://turned_shots"
	if args.size() > 1:
		_text_size = int(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _until(cond: Callable, max_frames: int = 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	print("TIMEOUT waiting")
	return false

func _walk(target: Vector2, limit: int = 1500) -> void:
	for i in limit:
		var d: Vector2 = target - world.player.position
		if d.length() < 4.0:
			break
		world.test_dir = d.normalized()
		await process_frame
	world.test_dir = Vector2.ZERO

func _run() -> void:
	var backup := ""
	if FileAccess.file_exists(Save.PATH):
		backup = FileAccess.get_file_as_string(Save.PATH)
	Save.clear()
	await _wait(3)
	if _text_size >= 0:
		# only the variable: set_text_size() would save the player's real settings
		var settings := root.get_node_or_null("/root/Settings")
		if settings:
			settings.text_size = _text_size
	change_scene_to_file("res://scenes/games/turned/turned.tscn")
	await _wait(25)
	game = current_scene
	print("SCALE ", root.content_scale_factor, " visible ", root.get_visible_rect().size)
	await _shot("00_landing")
	game.home.start_mode(game.home.cfg["modes"][0])
	await _wait(5)
	if game.info and game.info.overlay and game.info.overlay.visible:
		game.info.close()
	world = game.world
	hud = game.hud
	await _until(func(): return world._pro == "fade_in")
	await _wait(60)
	await _shot("01_fade_in")
	await _until(func(): return world._pro == "wait_sit")
	await _shot("02_wait_sit")
	world.press_a()
	await _wait(50)
	await _shot("03_sitting")
	await _until(func(): return world._pro == "wait_wipe")
	world.press_a()
	await _wait(100)
	await _shot("04_wiping")
	await _until(func(): return world._pro == "felt")
	await _wait(25)
	await _shot("05_felt")
	await _until(func(): return world.mode == "play")
	await _wait(60)
	await _shot("06_free_walk")
	# clues
	world.player.position = Vector2(111, 66)
	await _wait(20)
	world.press_a()
	await _wait(30)
	await _shot("07_clue")
	await _walk(Vector2(135, 250))
	await _walk(Vector2(135, 340))
	await _shot("08_hall")
	await _walk(Vector2(430, 345))
	await _walk(Vector2(430, 280))
	await _walk(Vector2(444, 64))
	await _wait(10)
	await _shot("09_bathroom")
	world.press_a()
	await _wait(120)
	await _shot("10_mirror")
	await _wait(20)
	world.press_a()
	await _wait(60)
	await _shot("11_missions")
	await _walk(Vector2(430, 340))
	await _walk(Vector2(500, 346))
	world.press_a()
	await _wait(20)
	await _walk(Vector2(522, 360))
	world.press_a()
	await _until(func(): return world.area.id == "street" and world.mode == "play", 300)
	await _wait(40)
	await _shot("12_street_porch")
	world.player.position = Vector2(330, 262)
	await _wait(75)
	await _shot("13_sun_burning")
	world.player.position = Vector2(560, 172)
	await _wait(60)
	await _shot("14_awning_shade")
	world.player.position = Vector2(1250, 205)
	await _wait(70)
	world.press_a()
	await _wait(40)
	await _shot("15_watcher")
	world.player.position = Vector2(850, 330)
	await _wait(50)
	await _shot("16_vendor")
	world.player.position = Vector2(1330, 320)
	await _wait(50)
	await _shot("17_carriage")
	world.player.position = Vector2(1785, 170)
	await _wait(5)
	await _walk(Vector2(1785, 100))
	await _wait(40)
	await _shot("18_alley_unlock")
	await _wait(200)
	world.press_b()
	await _wait(40)
	await _shot("19_sneak")
	world.test_dir = Vector2.UP
	await _wait(60)
	world.test_dir = Vector2.ZERO
	await _shot("20_alley")
	world.player.position = Vector2(640, 262)
	world.engine.hp = 2.0
	await _wait(100)
	await _shot("21_dying")
	await _wait(100)
	await _shot("22_respawned")
	hud.open_menu("journal")
	await _wait(5)
	await _shot("23_journal")
	hud.close_menu()
	game.home.pause()
	await _wait(10)
	await _shot("24_pause_menu")
	Save.clear()
	if backup != "":
		var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("done")
	quit()
