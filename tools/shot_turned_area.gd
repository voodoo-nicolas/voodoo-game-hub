extends SceneTree

## Screenshots of Turned's two areas without playing the prologue (for art work):
##   godot --path . --resolution 1280x720 --script res://tools/shot_turned_area.gd -- <out_dir> [game hour, e.g. 23] [spot name filter]
## Teleports the player to a list of spots (SPOTS below) and saves one PNG per spot.
## Writes nothing to the player's saves.

const WorldScript = preload("res://scripts/games/turned/turned_world.gd")
const HudScript = preload("res://scripts/games/turned/turned_hud.gd")

## [file name, area, x, y, (her on the storeroom cot: 0 out cold .. 1 come round)]
const SPOTS := [
	["street_porch", "street", 220.0, 219.5],
	["street_road", "street", 327.8, 328.4],
	["street_bakery", "street", 536.8, 245.9],
	["street_tree", "street", 1031.8, 350.4],
	["street_carriage", "street", 1394.8, 306.4],
	["street_alley", "street", 1771.6, 141.4],
	["street_pub", "street", 1032.9, 240.4],
	["street_store", "street", 2290.0, 245.0],
	["street_square", "street", 2830.0, 165.0],
	["street_church", "street", 3080.0, 245.0],
	["street_lane", "street", 710.6, 163.4],
	["harbor_start", "harbor", 100.0, 240.0],
	["harbor_sheds", "harbor", 1640.0, 240.0],
	["harbor_crane", "harbor", 2260.0, 240.0],
	["harbor_shop", "harbor", 2872.0, 240.0],
	["road_gate", "night_road", 940.0, 298.0],
	["road_forest", "night_road", 1440.0, 298.0],
	["road_bridge", "night_road", 1950.0, 252.0],
	["road_shrine", "night_road", 2470.0, 252.0],
	["road_house", "night_road", 3185.0, 298.0],
	["shop_front", "cigar_shop", 110.0, 300.0],
	["shop_storeroom", "cigar_shop", 495.0, 312.0],
	["shop_cot_out", "cigar_shop", 495.0, 312.5, 0.0],
	["shop_cot_waking", "cigar_shop", 495.0, 312.5, 1.0],
	["bakery_shop", "bakery", 100.0, 294.0],
	["bakery_oven", "bakery", 511.0, 300.0],
	["bar_room", "bar", 316.0, 278.0],
	["bar_counter", "bar", 400.0, 205.0],
	["house_calendar", "house", 166.0, 172.0],
	["house_bedroom", "house", 74.0, 304.0],
	["house_bathroom", "house", 370.0, 250.0],
	["house_landing", "house", 244.0, 260.0],
	["house_stairs", "house", 316.0, 262.0],
	["down_parlour", "house_down", 123.0, 232.0],
	["down_kitchen", "house_down", 365.0, 277.0],
	["down_hall", "house_down", 247.0, 222.0],
]

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://turned_area_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 3:
		await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # the hub's stretch would zoom the HUD
	var hud := HudScript.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.z_index = 100    # the world is added after it and would draw over it
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
	if args.size() > 1:
		world.clock.hour = float(args[1])
		world.engine.set_flag("mirror")
	var only: String = args[2] if args.size() > 2 else ""
	world.player.pose = "stand"
	hud.set_revealed("dpad", true)
	hud.set_revealed("a", true)
	hud.set_revealed("bars", true)
	hud.fade = 0.0
	for spot in SPOTS:
		if only != "" and not String(spot[0]).begins_with(only):
			continue
		if world.area.id != spot[1]:
			world._load_area(spot[1])
		if args.size() > 1:
			world.clock.hour = float(args[1])
		if spot[1] == "harbor" or spot[1] == "night_road":
			world.engine.set_flag("senses")        # the glare of a turning vampire's eyes
		world.player.position = Vector2(spot[2], spot[3])
		world.player.cot_t = float(spot[4]) if spot.size() > 4 else -1.0
		world.player.cot_goal = world.player.cot_t
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
