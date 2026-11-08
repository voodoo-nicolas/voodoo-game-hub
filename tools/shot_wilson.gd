extends SceneTree

## Plays Beached (wilson) in a real window and saves screenshots (needs a window, not --headless):
##   godot --path . --resolution 1280x720 --script res://tools/shot_wilson.gd -- <out_dir> [locale]
## For a phone shape use e.g. --resolution 1170x540. Writes user://wilson_save.json and
## user://wilson_debug.json; the owner's real ones are backed up and put back.

const FILES := ["user://wilson_save.json", "user://wilson_debug.json"]

var out_dir := ""
var game: Control
var _locale := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://wilson_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_locale = args[1] if args.size() > 1 else ""
	_run()

func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

## Jumps the island clock forward to local `h` o'clock (as away time, like the debug panel does).
func _hour(h: float) -> void:
	var e = game.engine
	game.clock_offset += e.next_hour(h) - e.t
	game.catch_up(false)
	game._close_panel()
	e.bars = {"hp": 90.0, "food": 70.0, "water": 65.0, "energy": 80.0}
	if game.home.pause_overlay.visible:
		game.home.resume_play()

func _run() -> void:
	var backup := {}
	for f in FILES:
		if FileAccess.file_exists(f):
			backup[f] = FileAccess.get_file_as_string(f)
			DirAccess.remove_absolute(f)
	await _wait(3)
	var lang := root.get_node_or_null("/root/Lang")
	if _locale != "" and lang and lang.has_method("_apply"):
		lang._apply(_locale)   # this session only
	change_scene_to_file("res://scenes/games/wilson/wilson.tscn")
	await _wait(25)
	game = current_scene
	game.auto_pause = false
	await _shot("00_landing")
	game.home.start_mode(game.home.cfg["modes"][0])
	await _wait(10)
	await _shot("00b_look_picker")
	var picker = game.get_node_or_null("LookPicker")
	if picker:
		game._on_look_picked(picker, "female3", game._start_island)
	await _wait(10)
	if game.info and "overlay" in game.info and game.info.overlay and game.info.overlay.visible:
		game.info.close()
	game.engine.hemisphere = "south"
	_hour(10.0)
	game.engine.bars = {"hp": 100.0, "food": 80.0, "water": 70.0, "energy": 90.0}
	await _wait(10)
	await _shot("01_morning_day1")
	var e = game.engine
	e.tap_johnny()
	game._handle_events(e.pop_events())
	game._johnny_menu(Vector2(640, 400))
	await _shot("02_johnny_menu")
	game._close_popup()
	for id in ["crate", "barrel", "sailcloth"]:
		game._try("haul", id)
	await _wait(30)
	await _shot("03_queue_walk")
	game.hurry()
	game.hurry()
	game.hurry()
	await _wait(5)
	for pair in [["stick", 20], ["stone", 20], ["frond", 30], ["dry_frond", 5], ["rope", 12], ["trunk", 2]]:
		e.debug_give(pair[0], pair[1])
	e.add("spark_kit", 1)
	e.fire_fails = 3
	for r in ["campfire", "hammock", "frond_shelter", "crafting_stump"]:
		e.enqueue("craft", r)
		game.hurry()
	e.add("stone_axe", 1)
	e.enqueue("chop", "C")
	game.hurry()
	e.structures.campfire.fuel_until = e.t + 30 * 3600.0
	game.after_change()
	await _wait(10)
	await _shot("04_camp_built")
	game._open_craft()
	await _shot("05_craft")
	game._close_panel()
	for pair in [["fish_small", 2], ["coconut", 2], ["bottle", 1], ["seawater", 1], ["pearl", 1], ["clay_jar", 1]]:
		e.debug_give(pair[0], pair[1])
	e.add("fishing_pole", 1)
	game._open_bag()
	await _shot("06_bag")
	game._item_menu("bottle")
	await _shot("06b_item_card")
	game._combine("bottle", "seawater")
	await _wait(5)
	await _shot("06c_combined")
	game._open_craft()
	game._panel.get_child(0).get_child(1).scroll_vertical = 99999
	await _shot("06d_craft_bottom")
	game._close_panel()
	for r in ["tent", "water_still", "rain_catcher", "drying_rack", "frond_bed"]:
		e.unlocked.append(r)
		e.discovered.append(r)
		e.structures[r] = {"built": e.t}
	game.after_change()
	await _wait(5)
	await _shot("06e_full_camp")
	e.structures.erase("frond_bed")
	e.start_sleep("hammock", 2.0)
	game.after_change()
	await _wait(5)
	await _shot("06f_hammock")
	e.wake()
	game.after_change()
	for h in [17.0, 18.0, 19.0, 21.0, 2.0, 6.5]:
		_hour(h)
		e.structures.campfire.fuel_until = e.t + 30 * 3600.0
		await _wait(20)
		await _shot("07_sky_%02d%02d" % [int(h), int(fmod(h, 1.0) * 60)])
	e.weather = "storm"
	_hour(12.0)
	await _wait(20)
	await _shot("08_storm_noon")
	e.weather = "clear"
	game._open_journal()
	await _shot("09_journal")
	game._close_panel()
	game._toggle_debug()
	await _shot("10_debug")
	for f in FILES:
		if backup.has(f):
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_string(backup[f])
		elif FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	quit()
