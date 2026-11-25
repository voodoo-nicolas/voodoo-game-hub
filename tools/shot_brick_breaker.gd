extends SceneTree
## Brick Breaker look screenshots: Classic + Reloaded mid-game, with an explosion.
## godot --path . --resolution 540x1170 --script res://tools/shot_brick_breaker.gd -- <out_dir> [level]
## Plays a round: shares the real best-score save (only writes it on game over, which this never reaches).

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
	var lvl: int = int(args[1]) if args.size() > 1 else 5
	DirAccess.make_dir_recursive_absolute(out)
	await _wait(3)
	change_scene_to_file("res://scenes/games/brick_breaker/brick_breaker.tscn")
	await _wait(25)
	g = current_scene
	g.home.visible = false
	paused = false
	for mode in [false, true]:
		g._start_mode(mode)
		g.engine.level = lvl
		g.engine._build_level()
		g.engine.launch()
		var tag := "reloaded" if mode else "classic"
		await _shot("%s_start" % tag, 30)
		if mode:
			g.engine.apply_power("wide")
			g.engine.apply_power("fast")
			g.engine.apply_power("laser")
			g.engine.powerups = [{"kind": "multi", "pos": Vector2(150, 600)}, {"kind": "shrink", "pos": Vector2(420, 700)}]
			g.engine._explode(Vector2(300, 300), 110)
			g._on_events(g.engine.events)
			g.engine.combo = 7
		else:
			for b in g.engine.bricks.slice(0, 6):
				g.engine._damage(b, 99)
			g._on_events(g.engine.events)
		await _shot("%s_fx" % tag, 6)
	quit()
