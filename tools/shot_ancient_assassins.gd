extends SceneTree

## Ancient Assassins (3D, portrait) in a real window: Landing, the assassin
## picker, aiming, a throw in flight, the computer's turn, Skull mode, the kill
## cam, the finishing blow and the winner. "art" renders the Landing picture.
##   godot --path . --resolution 540x1170 --script res://tools/shot_ancient_assassins.gd -- <out_dir> [art]
## Starts fights, so the save is removed afterwards if there was none before.

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://ancient_assassins_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if args.size() > 1 and args[1] == "art":
		_art()
	else:
		_run()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _shot(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _start(level: int) -> void:
	game.home.play_now(game._new_vs_cpu.bind(level))
	await _wait(10)

## The Landing picture: a heroine close up, the lagoon behind, no HUD.
func _art() -> void:
	var had_save := FileAccess.file_exists("user://ancient_assassins_save.json")
	await _wait(3)
	change_scene_to_file("res://scenes/games/ancient_assassins/ancient_assassins.tscn")
	await _wait(30)
	game = current_scene
	await _start(1)
	var e = game.engine
	e.reset(31, {"chars": [0, 1], "style": 1, "dist": 22.0})
	game._reset_fx()
	game._start_turn()
	game.phase = "over"
	game.end_panel.visible = false
	game.hud.visible = false
	game.weapon_row.get_parent().visible = false
	game.pause_btn.visible = false
	game.home.visible = false
	game.set_process(false)
	var w = game.world
	w.chars[0].play("ready", 0.0)
	w.chars[0].set_weapon(0, w.weapon_mesh)
	var f: Vector3 = e.feet(0)
	var fw: Vector3 = e.forward(0)
	var right: Vector3 = fw.cross(Vector3.UP).normalized()
	# The camera off her right side, looking across the lagoon at the cliffs; she turns to it.
	var cam_at: Vector3 = f + right * 2.1 + fw * 1.1 + Vector3(0, 0.72, 0)
	var to_cam: Vector3 = cam_at - f
	w.chars[0].rotation.y = atan2(to_cam.x, to_cam.z) - 0.3
	# Rendered offscreen at phone size (a window can't be taller than the screen).
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1560)
	vp.world_3d = game.view3d.find_world_3d()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 48.0
	vp.add_child(cam)
	# Low and close, so she fills the right of the picture (Monument: title top-left, menu centre-left).
	cam.position = cam_at
	cam.look_at(f + Vector3(0, 1.05, 0) - fw * 0.62 - right * 0.1, Vector3.UP)
	cam.make_current()
	await _wait(40)
	vp.get_texture().get_image().save_jpg(out_dir.path_join("landing_bg.jpg"), 0.88)
	print("SHOT landing_bg")
	if not had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ancient_assassins_save.json"))
	quit()

func _run() -> void:
	var had_save := FileAccess.file_exists("user://ancient_assassins_save.json")
	await _wait(3)
	change_scene_to_file("res://scenes/games/ancient_assassins/ancient_assassins.tscn")
	await _wait(40)
	game = current_scene
	await _shot("1_landing")
	# The setup screens' assassin picker, on its own panel.
	var pc := PanelContainer.new()
	pc.position = Vector2(20, 200)
	pc.custom_minimum_size = Vector2(500, 0)
	pc.process_mode = Node.PROCESS_MODE_ALWAYS
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	game.add_child(pc)
	game._add_char_picker(vb)
	await _wait(20)
	await _shot("1b_picker")
	game._pick_char(4)
	await _wait(20)
	await _shot("1c_picker_livia")
	game._pick_char(0)
	pc.queue_free()
	await _start(1)
	game._start_intro()
	await _wait(45)
	await _shot("1d_intro")
	game.world.skip_intro()
	await _wait(5)
	var e = game.engine
	e.reset(4242, {"chars": [0, 1], "style": 1})
	game._reset_fx()
	game._start_turn()
	game.world.snap_camera(0)
	game.banner_t = 0.0
	await _wait(30)
	await _shot("2_your_turn")
	game.holding = true
	game.world.chars[0].play("aim", 0.0, true)
	e.set_aim(0, 2.0, 18.0)
	await _wait(25)
	await _shot("3_aim")
	game.holding = false
	game._throw()
	await _wait(28)
	await _shot("4_flight")
	for n in 600:
		await process_frame
		if game.phase == "cpu":
			break
	await _wait(10)
	await _shot("5_cpu_turn")
	game._set_skin("voodoo")
	await _wait(20)
	await _shot("6_skull_mode")
	game._set_skin("classic")
	# The kill cam: a finishing throw found with the Expert aim.
	e.reset(777, {"chars": [3, 4], "style": 0, "dist": 24.0})
	game._reset_fx()
	game._start_turn()
	game.world.snap_camera(0)
	game.banner_t = 0.0
	e.fighters[1].hp = 20
	for tries in 40:
		var plan: Dictionary = e.cpu_aim(0, 3)
		var r: Dictionary = e.predict(0, plan.yaw, plan.pitch, 0)
		if r.f == 1:
			e.set_aim(0, plan.yaw, plan.pitch)
			break
	game.phase = "aim"
	e.turn = 0
	game._throw()
	print("kill target ", game.kill_target)
	for n in 900:
		await process_frame
		if game.kill_zoom > 0.6:
			break
	await _shot("7_killcam")
	for n in 900:
		await process_frame
		if e.shot.is_empty():
			break
	await _wait(25)
	await _shot("8_finishing_blow")
	for n in 1500:
		await process_frame
		if game.phase == "over":
			break
	await _wait(150)
	await _shot("9_result")
	game._see_field()
	await _wait(10)
	await _shot("10_winner")
	if not had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ancient_assassins_save.json"))
	quit()
