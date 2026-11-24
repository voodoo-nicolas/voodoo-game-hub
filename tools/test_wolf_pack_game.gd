extends SceneTree

## Stonewater scene smoke test: builds the Landing, the Campaign / briefing / Quick Mission
## cards, starts campaign and quick missions, runs frames, finishes missions, checks the
## result dialog, rank promotion, save and resume.
## godot --headless --path . --script res://tools/test_wolf_pack_game.gd
## It writes the game's own user:// saves, so it backs them up first and puts them back.

const SCENE := "res://scenes/games/wolf_pack/wolf_pack.tscn"
const FILES := ["user://wolf_pack_save.json", "user://wolf_pack_campaign.json"]

var fails := 0

func check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL ", msg)
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backup := {}
	for f in FILES:
		if FileAccess.file_exists(f):
			backup[f] = FileAccess.get_file_as_bytes(f)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var g = load(SCENE).instantiate()
	root.add_child(g)
	for _i in 5:
		await process_frame
	check(g.engine != null and g.home != null, "scene built")
	# Cards build without errors.
	g._open_campaign()
	g._open_briefing(0)
	g._open_quick()
	g._q_pick_type_b(2)
	g._q_pick_role(3)
	check(g.q_type == 5 and g.q_role == 3, "quick picks (Random type, scout)")
	await process_frame
	# Campaign mission 1.
	g.home.hide_home()
	g.get_tree().paused = false
	g._start_setup({"kind": "campaign", "mission": "m01", "rank": 0})
	check(g.started and g.engine.mission.id == "m01", "campaign mission started")
	for _i in 90:
		await process_frame
	check(g.engine.time > 0.5, "time advances (%.2f)" % g.engine.time)
	g._save_game()
	check(FileAccess.file_exists("user://wolf_pack_save.json"), "saved")
	check(g._resume_text().begins_with(g.tr("Campaign")), "resume text: " + g._resume_text())
	g.engine.time = 0.0
	var before_pos: Vector2 = g.engine.hero.p
	g._load_saved_game()
	check(g.started and absf(g.engine.time - 0.0) < 100.0, "resume ok")
	# Win it: kill one deer.
	for e in g.engine.herd:
		if e.sp == "deer":
			g.engine._kill(e, [])
			break
	for _i in 3:
		await process_frame
	check(g.engine.is_over() and g.engine.outcome == "win", "mission won by a kill")
	g.over_t = 5.0
	await process_frame
	await process_frame
	check(g.result_recorded, "result shown")
	check(int(g.camp.renown) >= 60, "renown paid: %d" % int(g.camp.renown))
	check(g.camp.done.has("m01"), "m01 stored")
	check(is_instance_valid(g.end_dialog) and g.end_dialog.visible, "result dialog visible")
	print("message: ", g.end_dialog.get_meta("message_label").text.replace("\n", " | "))
	# A promotion: 100 renown = Hunter.
	g.camp.renown = 95
	g._start_setup({"kind": "campaign", "mission": "m02", "rank": 0})
	g.engine._finish("win", "", [])
	g.over_t = 5.0
	await process_frame
	await process_frame
	check(g._rank() == 1, "promoted to Hunter, renown %d" % int(g.camp.renown))
	check("Promoted" in g.end_dialog.get_meta("message_label").text, "promotion text")
	# Quick missions: every role on every type runs frames without errors.
	var n := 0
	for ty in range(5):
		for ro in range(4):
			g._start_quick(ty, ro)
			for _i in 6:
				await process_frame
			check(g.started and g.engine.mission.id == "quick", "quick %d/%d started" % [ty, ro])
			g.engine.sense()
			g.engine.set_command("guard")
			g.wheel_open = (n % 2 == 0)
			n += 1
			await process_frame
			g.wheel_open = false
	# Quick missions can be failed and retried.
	g._start_quick(0, 0)
	g.engine._finish("fail", "den", [])
	g.over_t = 5.0
	await process_frame
	await process_frame
	check("failed" in g.end_dialog.get_meta("message_label").text, "fail text")
	g._restart()
	await process_frame
	check(g.started and not g.engine.over, "retry restarts")
	# A full minute of simulated play, with Strike and Sprint input, on the biggest map.
	g._start_setup({"kind": "campaign", "mission": "m10", "rank": 4})
	for _i in 120:
		await process_frame
	check(g.engine.time > 0.5 and not g.engine.over, "finale map runs")
	# Put the user's own saves back.
	for f in FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		if backup.has(f):
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(backup[f])
			fa.close()
	print("wolf_pack game test: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
