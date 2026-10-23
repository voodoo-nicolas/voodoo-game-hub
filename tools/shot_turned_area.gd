extends SceneTree

## Screenshots of Turned's two areas without playing the prologue (for art work):
##   godot --path . --resolution 1280x720 --script res://tools/shot_turned_area.gd -- <out_dir> [text size 0|1|2]
## Teleports the player to a list of spots (SPOTS below) and saves one PNG per spot.
## Writes nothing to the player's saves.

const WorldScript = preload("res://scripts/games/turned/turned_world.gd")
const HudScript = preload("res://scripts/games/turned/turned_hud.gd")

## [file name, area, x, y]
const SPOTS := [
	["street_porch", "street", 232.0, 184.0],
	["street_road", "street", 330.0, 262.0],
	["street_bakery", "street", 640.0, 205.0],
	["street_tree", "street", 980.0, 330.0],
	["street_carriage", "street", 1330.0, 320.0],
	["street_alley", "street", 1785.0, 150.0],
	["house_bedroom", "house", 110.0, 100.0],
	["house_bathroom", "house", 444.0, 70.0],
	["house_landing", "house", 300.0, 350.0],
	["house_study", "house", 280.0, 490.0],
	["down_parlour", "house_down", 160.0, 120.0],
	["down_kitchen", "house_down", 440.0, 220.0],
	["down_hall", "house_down", 200.0, 350.0],
]

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://turned_area_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 3:
		await process_frame
	var hud := HudScript.new()
	root.add_child(hud)
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
	for spot in SPOTS:
		if world.area.id != spot[1]:
			world._load_area(spot[1])
		world.player.position = Vector2(spot[2], spot[3])
		world._snap_camera()
		for i in 12:
			await process_frame
		root.get_texture().get_image().save_png(out_dir.path_join(spot[0] + ".png"))
		# average frame time over 90 frames (about the GPU cost: this PC's Intel UHD 600 is a fair
		# stand-in for a mid-range phone); vsync caps it at 16.7 ms
		var t0 := Time.get_ticks_usec()
		for i in 90:
			await process_frame
		print("SHOT ", spot[0], "  ms/frame ", snappedf(float(Time.get_ticks_usec() - t0) / 90000.0, 0.1))
	quit()
