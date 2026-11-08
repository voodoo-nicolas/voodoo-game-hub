extends SceneTree

## Crypt Crawler in a real window: screenshots of each stone theme, the new monsters up close and
## the big map (needs a window, not --headless):
##   godot --path . --resolution 720x1280 --script res://tools/shot_crypt_crawler.gd -- <out_dir> [skin]
## Starts a game, so the save in user://crypt_crawler_save.json is backed up and put back.

const SAVE := "user://crypt_crawler_save.json"

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://crypt_crawler_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run(args[1] if args.size() > 1 else "classic")

func _shot(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

## Puts `kind` a few cells in front of the player, in an open line, and turns to face it.
func _stage(kind: String, dist: float) -> void:
	var e = game.engine
	e.monsters = []
	e.bolts = []
	for a in 16:
		var ang := a * TAU / 16.0
		var d := Vector2(cos(ang), sin(ang))
		if e.cast(e.pos, d, 20.0).dist > dist + 0.6:
			e.angle = ang
			var m := {"pos": e.pos + d * dist, "kind": kind, "hp": 9, "cool": 99.0, "hurt": 0.0, "bob": 0.4, "awake": true}
			e.monsters.append(m)
			return

func _run(skin: String) -> void:
	var backup := ""
	if FileAccess.file_exists(SAVE):
		backup = FileAccess.get_file_as_string(SAVE)
	await _wait(3)
	change_scene_to_file("res://scenes/games/crypt_crawler/crypt_crawler.tscn")
	await _wait(25)
	game = current_scene
	await _shot("00_landing")
	game.home.start_mode(game.home.cfg["modes"][1])
	await _wait(10)
	if game.info and "overlay" in game.info and game.info.overlay and game.info.overlay.visible:
		game.info.close()
	game._set_skin(skin)
	var e = game.engine
	for lvl in [1, 3, 5, 7]:
		e.level = lvl
		e.new_level()
		e.hp = 100
		await _wait(4)
		await _shot("01_floor_%d" % lvl)
	e.level = 6
	e.new_level()
	for kind in ["skeleton", "bat", "rat", "specter", "gargoyle", "monk", "skull", "wraith"]:
		_stage(kind, 2.2)
		await _wait(2)
		await _shot("02_" + kind)
	game.big_map = true
	await _shot("03_big_map")
	game.big_map = false
	game.started = false
	if backup != "":
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()
