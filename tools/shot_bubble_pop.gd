extends SceneTree
## Bubble Pop look screenshots: landing, play, aiming, a pop burst.
## godot --path . --resolution 540x1170 --script res://tools/shot_bubble_pop.gd -- <out_dir>
## Starts games: back up user://bubble_pop_*.json first (shares the real saves).

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
	change_scene_to_file("res://scenes/games/bubble_pop/bubble_pop.tscn")
	await _wait(25)
	g = current_scene
	await _shot("00_landing")
	g._new_game(1)
	g.home.visible = false
	if OS.get_cmdline_user_args().size() > 1:
		g.home._set_retro(false)
	paused = false
	g.aim = Vector2(-0.55, -0.83).normalized()
	g.board.queue_redraw()
	await _shot("01_play", 30)
	g._fire()
	await _shot("02_fly", 6)
	for i in 6:
		g._burst(g.engine.center(3, i), i % 4, i % 2 == 0)
	await _shot("03_burst", 3)
	quit()
