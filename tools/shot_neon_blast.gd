extends SceneTree
## Neon Blast look screenshots: play (both skins), bomb flash, hit, result.
## godot --path . --resolution 1170x540 --script res://tools/shot_neon_blast.gd -- <out_dir>
## Starts games: back up user://geometry_wars_* first (shares the real saves).

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
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	change_scene_to_file("res://scenes/games/geometry_wars/geometry_wars.tscn")
	await _wait(25)
	g = current_scene
	g._set_skin("voodoo")
	g._start_mode("evolved")
	g.home.visible = false
	paused = false
	await _shot("01_voodoo_play", 240)
	g.bombs = 1
	g._on_bomb_pressed()
	await _shot("02_bomb", 4)
	g._on_player_hit()
	await _shot("03_hit", 3)
	g._set_skin("classic")
	await _shot("04_classic", 120)
	g._end_game(false)
	await _shot("05_result", 150)
	quit()
