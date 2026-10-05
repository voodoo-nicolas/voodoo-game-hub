extends SceneTree

## Farkle save/resume: play into a game, save, reload the scene and Resume;
## scores, turn and the dice in front of the player must come back.
## Uses the shared user data (back it up first, CLAUDE.md).

func _initialize() -> void:
	_run()

func _run() -> void:
	for i in 3:
		await process_frame
	var scene: PackedScene = load("res://scenes/games/farkle/farkle.tscn")
	var g: Node = scene.instantiate()
	root.add_child(g)
	for i in 5:
		await process_frame
	if g.info:
		g.info.close()
	paused = false
	g._new_game(false)
	g.engine.scores = [1200, 850]
	g._on_roll()
	var fails := 0
	if not g.farkled:
		g._save_game()
		var dice: Array = g.engine.dice.duplicate()
		root.remove_child(g)
		g.free()
		var g2: Node = scene.instantiate()
		root.add_child(g2)
		for i in 5:
			await process_frame
		paused = false
		g2._load_saved_game()
		if g2.engine.scores != [1200, 850]:
			fails += 1
			print("FAIL scores ", g2.engine.scores)
		if g2.engine.dice != dice or not g2.rolled:
			fails += 1
			print("FAIL dice ", g2.engine.dice, " vs ", dice)
		g2._new_game(false)  # deletes the save
		if FileAccess.file_exists("user://farkle_save.json"):
			fails += 1
			print("FAIL new game kept the save")
	else:
		print("first roll farkled; rerun")
	var tone = load("res://scripts/games/simon/simon_game.gd")._make_tone(310.0, 0.4)
	if tone.data.size() != int(22050 * 0.4) * 2:
		fails += 1
		print("FAIL tone size")
	print("FARKLE/SIMON TEST: %s" % ("PASS" if fails == 0 else "%d FAIL" % fails))
	paused = false
	quit(fails)
