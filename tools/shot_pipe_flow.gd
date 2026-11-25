extends SceneTree
## Wire Up look pass screenshots: landing, intro pop, a level, a tap squash, the win flash + confetti,
## the solved card, time-attack low clock.
## godot --path . --resolution 540x1170 --script res://tools/shot_pipe_flow.gd -- <out_dir> [skin]
## Starts games: back up user://pipe_flow_*.json first (shares the real saves).

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
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	change_scene_to_file("res://scenes/games/pipe_flow/pipe_flow.tscn")
	await _wait(25)
	g = current_scene
	g._set_skin(skin)
	await _shot("00_landing")
	g._begin("campaign", 30, g.PipeEngine.seed_for(30))
	g.home.visible = false
	paused = false
	await _shot("01_intro", 4)
	await _shot("02_level", 60)
	for c in g.engine.w * g.engine.h:
		if g.engine.can_turn(c):
			g.pop[c] = 0.09
			break
	await _shot("03_pop", 1)
	g._on_solved()
	await _shot("04_win", 8)
	await _shot("05_card", 140)
	g._start_time()
	g.time_left = 8.0
	await _shot("06_time", 30)
	quit()
