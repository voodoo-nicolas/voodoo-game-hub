extends SceneTree

## Headless checks for Turned running on the shared on-screen controller (the Pad):
##   godot --headless --path . --script res://tools/test_turned_pad.gd
## Builds the real Turned scene, starts the story, and drives the Pad the way a thumb would.
## Backs up and restores the player's Turned save and controller prefs.

const Save = preload("res://scripts/games/turned/turned_save.gd")
const Prefs = preload("res://scripts/common/pad/pad_prefs.gd")

var fails := 0
var game: Control

func check(label: String, got, want) -> void:
	if got != want:
		fails += 1
		print("FAIL ", label, ": got ", got, " want ", want)

func ok(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	_run()

func _start() -> void:
	if game != null:
		game.queue_free()
		await process_frame
	game = (load("res://scenes/games/turned/turned.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	paused = false
	game.size = Vector2(1280, 720)
	game._new_game()
	await process_frame
	paused = false

func _part(id: String) -> Dictionary:
	for el in game.pad.parts():
		if el["id"] == id and el["kind"] != "plate":
			return el
	return {}

func _tap(fid: int, id: String) -> void:
	var el := _part(id)
	var at: Vector2 = el["rect"].get_center() if el["kind"] == "pill" else el["pos"]
	game.pad._press(fid, at, true)
	game.pad._press(fid, Vector2.ZERO, false)

func _run() -> void:
	var save_backup := FileAccess.get_file_as_string(Save.PATH) if FileAccess.file_exists(Save.PATH) else ""
	var had_save := FileAccess.file_exists(Save.PATH)
	var had_prefs := FileAccess.file_exists(Prefs.PATH)
	var prefs_backup := FileAccess.get_file_as_string(Prefs.PATH) if had_prefs else ""
	if had_prefs:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.PATH))
	for i in 3:
		await process_frame

	await _start()
	ok("the app has the pad, so Turned uses it", game.pad != null and game.hud.pad == game.pad)
	check("no Controls section in Options yet", game.has_method("_pad"), false)
	check("Turned is on the stick + 4 buttons layout", game.pad.layout_id(), "stick_4")
	# progressive reveal: nothing but Pause at the very start
	for id in ["move", "a", "b", "info", "x", "y", "aim"]:
		check("%s hidden at the start" % id, game.pad.visibility_of(id), 0.0)
	check("pause is there from the start", game.pad.visibility_of("pause"), 1.0)
	var hud: Control = game.hud
	hud.reveal("dpad")
	hud._process(0.01)
	ok("d-pad starts to pop in", game.pad.visibility_of("move") < 0.5)
	game.pad._process(0.6)
	check("d-pad fully in", game.pad.visibility_of("move"), 1.0)
	check("A still hidden", game.pad.visibility_of("a"), 0.0)
	hud.reveal("a", false)
	hud.reveal("b", false)
	hud.reveal("menu", false)
	check("A shown", game.pad.visibility_of("a"), 1.0)
	check("X never shown", game.pad.visibility_of("x"), 0.0)
	# the stick walks the player (same actions the keyboard presses)
	var dp := _part("move")
	game.pad._press(1, dp["pos"], true)
	game.pad._move(1, dp["pos"] + Vector2(dp["r"], 0))
	ok("walking right", game.world._input_dir().x > 0.9)
	game.pad._press(1, Vector2.ZERO, false)
	check("let go: still", game.world._input_dir(), Vector2.ZERO)
	# A and B reach the world through the HUD's signals
	var got: Array = []
	hud.a_pressed.connect(func(): got.append("a"))
	hud.b_pressed.connect(func(): got.append("b"))
	hud.pause_pressed.connect(func(): got.append("pause"))
	_tap(2, "a")
	_tap(3, "b")
	_tap(4, "pause")
	check("A, B and Pause signals", got, ["a", "b", "pause"])
	# the word under A and its dimming, the sneaking ring on B
	game.world.hud.a_label = "use"
	game.world.hud.a_active = true
	hud._process(0.016)
	check("A says what it does", game.pad._props["a"]["sub"], tr("use") if tr("use") != "" else "use")
	check("A usable", game.pad._props["a"]["enabled"], true)
	hud.a_active = false
	hud._process(0.016)
	check("A dimmed when nothing to do", game.pad._props["a"]["enabled"], false)
	game.world.engine.sneaking = true
	hud._process(0.016)
	check("B ring while sneaking", game.pad._props["b"]["ring"], true)
	game.world.engine.sneaking = false
	# the Menu button opens the Journal and the pad steps aside
	_tap(5, "info")
	check("Menu opens", hud.menu_open, true)
	hud._process(0.016)
	check("pad hidden while the menu is open", game.pad.visible, false)
	hud.close_menu()
	hud._process(0.016)
	check("pad back after the menu", game.pad.visible, true)
	# Missions is still the HUD's own tap
	hud.reveal("mission", false)
	hud._on_press(6, hud._mission_rect().get_center(), true)
	hud._on_press(6, Vector2.ZERO, false)
	check("Missions tap opens the quest log", hud.menu_open, true)
	hud.close_menu()
	# the neck close-up: the pad hides, any tap is A
	hud.closeup = 1.0
	hud._process(0.016)
	check("pad hidden during the close-up", game.pad.visible, false)
	hud.closeup = 0.0
	hud._process(0.016)
	# the pause menu of the kit freezes the pad
	game.pad._press(7, dp["pos"], true)
	game.pad._move(7, dp["pos"] + Vector2(dp["r"], 0))
	paused = true
	await process_frame
	check("kit pause lets go of the d-pad", game.world._input_dir(), Vector2.ZERO)
	paused = false
	# a saved layout (an old test with the Pad Lab) does not change Turned's: no layout choice yet
	var f := FileAccess.open(Prefs.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"layout": "dpad_4", "opacity": 0.5}))
	f.close()
	await _start()
	check("a saved layout does not change Turned's", game.pad.layout_id(), "stick_4")
	check("other saved choices still apply", float(game.pad.prefs["opacity"]), 0.5)
	for id in ["x", "y", "aim"]:
		check("%s stays hidden in any layout" % id, game.pad.visibility_of(id), 0.0)
	# nothing left held
	game.pad.release_all()

	# put the player's files back
	game.queue_free()
	await process_frame
	if had_save:
		var sf := FileAccess.open(Save.PATH, FileAccess.WRITE)
		sf.store_string(save_backup)
	else:
		Save.clear()
	if had_prefs:
		var pf := FileAccess.open(Prefs.PATH, FileAccess.WRITE)
		pf.store_string(prefs_backup)
	elif FileAccess.file_exists(Prefs.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.PATH))
	print("test_turned_pad: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
