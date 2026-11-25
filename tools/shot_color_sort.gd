extends SceneTree
## Color Sort look screenshots: landing, a level, a lifted vial, a pour mid-stream, a win.
## godot --path . --resolution 540x1170 --script res://tools/shot_color_sort.gd -- <out_dir> [skin] [level]
## Starts games: back up user://color_sort_*.json first (shares the real saves).

var g
var out := ""

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String, frames: int = 12) -> void:
	await _wait(frames)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var skin: String = args[1] if args.size() > 1 else "classic"
	var lvl: int = int(args[2]) if args.size() > 2 else 12
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	change_scene_to_file("res://scenes/games/color_sort/color_sort.tscn")
	await _wait(25)
	g = current_scene
	g._set_skin(skin)
	await _shot("00_landing", 30)
	g._new_level(lvl)
	g.home.visible = false
	paused = false
	await _shot("01_level", 40)
	# find a legal pour
	var from := -1
	var to := -1
	for a in g.engine.tubes.size():
		for b in g.engine.tubes.size():
			if a != b and g.engine.can_move(a, b):
				from = a
				to = b
				break
		if from >= 0:
			break
	g.selected = from
	await _shot("02_lifted", 20)
	if from >= 0:
		g._tap_tube(to)
	await _shot("03_pour", 11)
	await _shot("04_after", 30)
	g._on_solved()
	await _shot("05_win", 20)
	quit()
