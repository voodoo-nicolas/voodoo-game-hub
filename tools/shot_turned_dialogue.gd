extends SceneTree

## Screenshots of Turned's dialogue box (the dev_demo scene: a line, a choice, an item) in a real window:
##   godot --path . --resolution 1280x720 --script res://tools/shot_turned_dialogue.gd -- <out_dir> [scene id]
## Writes nothing to the player's saves.

const WorldScript = preload("res://scripts/games/turned/turned_world.gd")
const HudScript = preload("res://scripts/games/turned/turned_hud.gd")

func _initialize() -> void:
	_run()

func _shot(out_dir: String, name: String) -> void:
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://turned_dialogue_shots"
	var scene: String = args[1] if args.size() > 1 else "dev_demo"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 3:
		await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # the hub's stretch would zoom the HUD
	var hud := HudScript.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.z_index = 100
	var world := WorldScript.new()
	root.add_child(world)
	world.attach_hud(hud)
	world.set_view_size(Vector2(root.get_visible_rect().size))
	world.begin_new()
	world.engine.set_flag("control")
	world.engine.set_flag("mirror")
	world.engine.dpad = true
	world.engine.show_bars = true
	world.mode = "play"
	world._pro = "done"
	world.player.pose = "stand"
	hud.set_revealed("dpad", true)
	hud.set_revealed("a", true)
	hud.set_revealed("bars", true)
	hud.fade = 0.0
	world._load_area("street")
	world.player.position = Vector2(330.0, 262.0)
	world._snap_camera()
	world.clock.hour = 20.0
	for i in 10:
		await process_frame
	world.start_dialogue(scene)
	for i in 10:
		await process_frame
	await _shot(out_dir, "1_typing")
	hud.dialogue_skip()
	await _shot(out_dir, "2_line")
	world.press_a()
	hud.dialogue_skip()
	await _shot(out_dir, "3_choice")
	world.dlg.move(1)
	hud.show_dialogue(world.dlg.view())
	await _shot(out_dir, "4_choice_second")
	quit()
