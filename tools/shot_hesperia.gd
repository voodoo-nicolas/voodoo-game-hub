extends SceneTree
## Screenshots of Hesperia in the hub: Landing, new-journey screen, prologue, free play with the Pad.
##   godot --path . --resolution 1280x720 --script res://tools/shot_hesperia.gd -- <out_dir>

var out := "user://shots_hesperia"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)

func _run() -> void:
	var g = load("res://scenes/games/hesperia/hesperia.tscn").instantiate()
	root.add_child(g)
	await _shot("1_landing")
	g.new_journey()
	g.game.ui._pick_body(false)
	g.game.ui._pick_hair("orange")
	await _shot("2_new_journey")
	g.game.ui._begin()
	for i in 30:
		await process_frame
	await _shot("3_prologue")
	# skip the prologue: straight into the cove, Pad visible
	g.game.ui.close()
	g.game.prologue_running = false
	var WS = load("res://scripts/games/hesperia/world_state.gd")
	WS.set_flag("prologue_done")
	WS.add_item("gaff")
	g.game._load_area("b7", Vector2(256, 300))
	Input.action_press("mv_right")
	for i in 20:
		await process_frame
	Input.action_release("mv_right")
	await _shot("4_cove_pad")
	g.game.player._press_a()   # side swing (new attack_side art)
	for i in 3:
		await process_frame
	await _shot("4b_swing")
	g.game._load_area("b7", Vector2(120, 380))   # the shoreline (autotile edges)
	await _shot("4c_shore")
	g.game._load_area("d0_boss", Vector2(160, 150))
	await _shot("5_crab")
	g._save_game()
	print("saved ", FileAccess.file_exists("user://hesperia_save.json"))
	quit()
