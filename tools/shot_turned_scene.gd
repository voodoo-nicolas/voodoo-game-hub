extends SceneTree

## Screenshots of Turned's Scene mode (the two dev scenes with placeholders, then the real bedroom) in the real game,
## in a real window (not --headless):
##   godot --path . --resolution 1280x720 --script res://tools/shot_turned_scene.gd -- <out_dir> [text size 0|1|2]
## Run it at 1280x720 (16:9), 1560x720 (19.5:9), 1024x768 (4:3) and 1170x540, and with text size 1 or 2
## (about 1.2 and 1.4), to check the fit, the margins and the chips.
## Writes user://turned_save.json while it runs; the owner's real one is backed up and put back.

const Save = preload("res://scripts/games/turned/turned_save.gd")

var out_dir := ""
var _text_size := -1
var game: Control
var world: Node2D
var hud: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://turned_scene_shots"
	if args.size() > 1:
		_text_size = int(args[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _shot(name: String) -> void:
	await _wait(6)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name, " visible ", root.get_visible_rect().size, " scene view ", game.scene_view.size, " mode ", world.mode, " hour ", snappedf(world.clock.hour, 0.001))

func _run() -> void:
	var backup := ""
	if FileAccess.file_exists(Save.PATH):
		backup = FileAccess.get_file_as_string(Save.PATH)
	Save.clear()
	await _wait(3)
	if _text_size >= 0:
		var settings := root.get_node_or_null("/root/Settings")
		if settings:
			settings.text_size = _text_size      # only the variable: nothing is saved
	change_scene_to_file("res://scenes/games/turned/turned.tscn")
	await _wait(25)
	game = current_scene
	game.home.start_mode(game.home.cfg["modes"][0])
	await _wait(5)
	if game.info and game.info.overlay and game.info.overlay.visible:
		game.info.close()
	world = game.world
	hud = game.hud
	# skip the prologue: free play in the street, bars and the mission shown
	world.engine.set_flag("control")
	world.engine.set_flag("mirror")
	world.engine.dpad = true
	world.engine.show_bars = true
	world.engine.set_mission("find_out")
	world.engine.add_item("watch")
	world.engine.add_item("note")
	world.engine.add_item("matches")            # the nav strip: Inventory, Journal (with its red dot) and, by flags, Map and Shelter
	world.engine.add_journal("coat")
	world.engine.set_flag("nav_map")
	world.engine.set_flag("nav_shelter")
	world.mode = "play"
	world._pro = "done"
	world.player.pose = "stand"
	hud.set_revealed("dpad", true)
	hud.set_revealed("a", true)
	hud.set_revealed("bars", true)
	hud.set_revealed("mission", true)
	hud.fade = 0.0
	world._load_area("street")
	world.player.position = Vector2(330.0, 262.0)
	world._snap_camera()
	await _wait(20)
	await _shot("0_walking")
	world.enter_scene("dev_room")
	await _wait(30)
	await _shot("1_room")
	game.scene_view.keyboard_nav = true
	game.scene_view.move_selection(Vector2.RIGHT)
	await _shot("2_keyboard_highlight")
	world.start_dialogue("dev_demo")
	await _wait(10)
	hud.dialogue_skip()
	await _shot("3_dialogue_over_scene")
	world.press_a()                            # on to the choice: rows in the painting's bottom band
	hud.dialogue_skip()
	await _wait(10)
	hud.dialogue_skip()
	await _shot("3b_choice_over_scene")
	while world.mode == "dialogue":
		hud.dialogue_skip()
		world.press_a()
	world.enter_scene("dev_hall")
	await _wait(8)
	await _shot("4a_crossfade")                # the old painting still half there
	await _wait(40)
	await _shot("4_hall")
	world.enter_scene("dev_room")
	await _wait(10)
	world.show_card("note")                    # a paper card: the game writes the words over the picture
	await _wait(30)
	await _shot("6_card_note")
	world.card_view.close()
	world.show_card("watch")
	await _wait(30)
	await _shot("7_card_watch")
	world.card_view.close()
	world.leave_scene()
	hud.open_menu("items")                     # the Items tab: "Look closer" opens a card over the menu
	await _wait(10)
	await _shot("8_items_tab")
	world.show_card("matches")
	await _wait(30)
	await _shot("9_card_over_menu")
	world.card_view.close()
	hud.close_menu()
	await _wait(20)
	await _shot("5_back_to_walking")
	# S5: the real bedroom (SC-01 / SC-02): walking in after the pockets opens it
	world._load_area("house")
	world.engine.set_flag("pockets")
	world.engine.set_flag("matches_home")
	world.engine.remove_item("matches")
	world.clock.hour = 9.0
	world.player.position = Vector2(200.0, 150.0)
	await _wait(50)
	await _shot("10_bedroom_day")
	world.clock.hour = 21.0
	game.scene_view.refresh()
	await _wait(50)
	await _shot("11_bedroom_night")
	Save.clear()
	if backup != "":
		var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	quit()
