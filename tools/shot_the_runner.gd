extends SceneTree

## Plays The Runner in a real window and saves screenshots of every screen (needs a window, not
## --headless):
##   godot --path . --resolution 1280x720 --script res://tools/shot_the_runner.gd -- <out_dir> [text size 0/1/2] [skin] [locale]
## For a phone shape use e.g. --resolution 1170x540. Writes user://the_runner_save.json (the game's
## autosave); the owner's real one is backed up and put back.

const SAVE := "user://the_runner_save.json"

var out_dir := ""
var game: Control
var _locale := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://the_runner_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_locale = args[3] if args.size() > 3 else ""
	_run(int(args[1]) if args.size() > 1 else -1, args[2] if args.size() > 2 else "classic")

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _run(text_size: int, skin: String) -> void:
	var backup := ""
	if FileAccess.file_exists(SAVE):
		backup = FileAccess.get_file_as_string(SAVE)
	await _wait(3)
	if text_size >= 0:
		var settings := root.get_node_or_null("/root/Settings")
		if settings:
			settings.text_size = text_size
	var lang := root.get_node_or_null("/root/Lang")
	if _locale != "" and lang and lang.has_method("_apply"):
		lang._apply(_locale)   # this session only: the player's saved language is not touched
	change_scene_to_file("res://scenes/games/the_runner/the_runner.tscn")
	await _wait(25)
	game = current_scene
	await _shot("00_landing")
	game.home.start_mode(game.home.cfg["modes"][0])
	await _wait(10)
	if game.info and "overlay" in game.info and game.info.overlay and game.info.overlay.visible:
		game.info.close()
	if skin != "classic":
		game._set_skin(skin)
	# character creation
	var c = game.creator
	c.cap.name = "Mira Vale"
	c.rebuild()
	await _shot("01_create_name")
	c._go("race")
	c._pick_race("ssaryn")
	await _shot("02_create_race")
	c._go("home")
	await _shot("03_create_home")
	c._go("perks")
	c._toggle("G07")
	c._toggle("G12")
	await _shot("04_create_perks")
	c._go("summary")
	await _shot("05_create_summary")
	c._finish()
	await _wait(8)
	await _shot("06_prologue")
	game._skip_story()
	await _wait(5)
	await _shot("07_dock_cradle")
	var e = game.engine
	e.clean = 9000
	e.flags["black_market"] = true
	for p in ["market", "shipyard", "fixer", "jobs", "office", "kessel"]:
		game.dock.open(p)
		await _shot("1%d_%s" % [["market", "shipyard", "fixer", "jobs", "office", "kessel"].find(p), p])
	game.dock.open("")
	game.launch()
	await _wait(5)
	await _shot("20_map_docked")
	game.map.world_tapped.emit("brass_garden")
	game.map.selected = "brass_garden"
	await _shot("21_map_course_card")
	game._set_course("brass_garden")
	e.rng.seed = 12345
	await _wait(60)
	await _shot("22_map_flying")
	game._toggle_overview()
	await _shot("23_map_overview")
	game._toggle_overview()
	# an inspection
	e.encounter = {"kind": "inspect", "faction": "accord", "bribe": e.bribe_cost(), "fine": 120, "log": []}
	game.show_encounter()
	await _shot("30_inspection")
	e.encounter = {}
	game._close_over()
	# raiders, then the real-time battle
	e._open_pirates("A raider ship drops out of the dark and hails you.")
	game.show_encounter()
	await _shot("31_pirates")
	game._choose("fight")
	await _wait(3)
	game._close_over()
	game.show_battle()
	await _wait(45)
	await _shot("32_battle")
	var guard := 0
	while game.battle != null and guard < 1800:
		game.battle.sim.pick_target(0)
		await _wait(1)
		guard += 1
	await _shot("33_battle_result")
	game._after_encounter()
	# a quest battle offer with a wing
	e.encounter = {"kind": "battle_offer", "enemy": "ashscale_raider", "why": "Reef Defense", "log": []}
	game.show_encounter()
	await _shot("34_battle_offer")
	e.encounter = {}
	game._close_over()
	# the gate
	if game.map == null:
		game.show_map()
	game.map.target = ""
	e.loc = ""
	e.ship_pos = e.gate_pos()
	game.map._cam = e.ship_pos
	game._on_gate(true)
	await _shot("40_gate")
	game._close_card()
	# menu tabs, with a crew member and some rep
	e.crew = [{"id": "C01", "loyalty": 60}]
	e.rep["sunscale_covenant"] = 520
	e.bars = {"paragon": 12, "outlaw": 4}
	e._invalidate()
	for tab in ["inventory", "skills", "missions", "map", "ship", "stats", "factions", "crew", "captain"]:
		game.open_computer()
		game.computer.tab = tab
		game.computer.rebuild()
		await _shot("50_menu_" + tab)
	game.close_computer()
	# Quest Expansion v2.2: a muster that picks three factions, the endings, the Hollow Deep
	e.bars = {"paragon": 60, "outlaw": 4}
	for f in ["terran_concord", "synthesis", "high_aerie", "sunscale_covenant"]:
		e.rep[f] = 600
	e._invalidate()
	e.crew = [{"id": "C01", "loyalty": 60, "q": 3}, {"id": "C07", "loyalty": 70, "rank": 2}]
	e.quests["M12"] = {"state": "done", "progress": 0}
	e.quests["M13a"] = {"state": "active", "progress": 0}
	e.loc = "sunspire_citadel"
	e.sector = "veil_expanse"
	e.cargo["alloys"] = 8
	game.show_dock()
	game.dock.open("jobs")
	await _shot("80_jobs_loyalty")
	game.dock._handin_open("M13a")
	game.dock._toggle_pick("terran_concord")
	await _shot("81_handin_pick3")
	e.quests["M15"] = {"state": "active", "progress": 1}
	e.nodes = 3
	e.loc = "the_ledger_core"
	e.sector = "hollow_deep"
	e.flags["act3"] = true
	game.show_dock()
	game.dock._handin_open("M15")
	await _shot("82_handin_endings")
	game.dock.open("")
	game.launch()
	await _wait(5)
	game._toggle_overview()
	await _shot("83_map_hollow_deep")
	game._toggle_overview()
	game.open_computer()
	game.computer.tab = "crew"
	game.computer.rebuild()
	await _shot("84_menu_crew_ranks")
	game.close_computer()
	# Scrapyard Gamma, the wreck field
	e.loc = "scrapyard_gamma"
	e.sector = "cradle_reach"
	game.show_dock()
	await _shot("60_dock_scrapyard")
	game.home.pause()
	await _shot("70_pause")
	game.home.resume_play()
	if backup != "":
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()
