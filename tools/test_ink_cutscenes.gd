extends SceneTree

## Ink Ninja cutscenes in the real game scene: a new game plays the intro (no Skip the
## first time), stage 1 starts after it; beating stage 1 plays after-1B, then stage 2.
## Second time round the intro can be skipped. Restores the player's real save files.
##   godot --headless --path . --script res://tools/test_ink_cutscenes.gd

const Cut = preload("res://scripts/games/ink_ninja/cutscene.gd")
const SAVE := "user://ink_ninja_save.json"
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _keep(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _put_back(path: String, text: String) -> void:
	if text == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)

func _initialize() -> void:
	_run()

func _run() -> void:
	var seen0 := _keep(Cut.SEEN_PATH)
	var save0 := _keep(SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Cut.SEEN_PATH))
	change_scene_to_file("res://scenes/games/ink_ninja/ink_ninja.tscn")
	for i in 20:
		await process_frame
	var g = current_scene
	g.home.play_now(g._new_game.bind(1))   # the Landing's Play, as a player starts it
	for i in 5:
		await process_frame
	check(g.cut_on and g.cutscene.playing and g.cutscene.id == "intro", "new game plays the intro")
	check(Cut.for_stage(1) == ["intro"] and Cut.for_stage(3) == ["drip"] and Cut.for_stage(5) == ["after-1B"] and Cut.for_stage(13) == ["after-3B", "act4"] and Cut.for_stage(2) == [], "slots (bible)")
	for sc in Cut.SCENES:
		check(g.cutscene.has_scene(sc), "scene " + sc)
	check(Cut.SCENES.size() == 12, "12 scenes")
	g.cutscene.t = 2.0
	await process_frame
	check(not g.cutscene.skip_btn.visible, "first intro: no Skip")
	check(g.card_text.is_empty(), "no chapter card under the intro")
	g.cutscene.t = 30.0
	await process_frame
	await process_frame
	check(not g.cut_on and g.started and not g.card_text.is_empty(), "intro ends into stage 1 (chapter card)")
	check(g.cutscene.was_seen("intro"), "intro remembered")
	# Beat stage 1.
	g.card_text = []
	g.engine.state = "won"
	g._after_pause()
	await process_frame
	check(g.engine.stage == 2 and not g.cut_on, "stage 1 -> 2: no cutscene")
	g.engine.stage = 4
	g.engine.state = "won"
	g._after_pause()
	await process_frame
	check(g.engine.stage == 5 and g.cut_on and g.cutscene.id == "after-1B", "after 1-B plays before stage 5 (2-1)")
	var sv = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(sv is Dictionary and int(sv.stage) == 5, "run saved at stage 5 before the cutscene")
	g.cutscene.t = 0.5
	await process_frame
	check(not g.cutscene.skip_btn.visible, "no Skip in the first second")
	g.cutscene.t = 1.5
	await process_frame
	check(g.cutscene.skip_btn.visible, "Skip after 1 s")
	g.cutscene.skip_btn.pressed.emit()
	await process_frame
	check(not g.cut_on and g.card_text.size() == 3, "Skip goes straight to stage 5's card")
	# Second new game: the intro can now be skipped.
	g._new_game(1)
	await process_frame
	g.cutscene.t = 1.5
	await process_frame
	check(g.cutscene.skip_btn.visible, "intro skippable once seen")
	g.cutscene._end()
	await process_frame
	# Drip before 1-3.
	g.cut_on = false
	g.card_text = []
	g.engine.stage = 2
	g.engine.state = "won"
	g._after_pause()
	await process_frame
	check(g.cut_on and g.cutscene.id == "drip", "drip before stage 3 (1-3)")
	g.cutscene._end()
	await process_frame
	check(not g.cut_on, "stage 3 starts after the drip")
	# Seal waits for Slash.
	g.cutscene.play("seal")
	g.cutscene.t = 13.5
	for i in 3:
		await process_frame
	check(g.cutscene.t <= 12.6 and g.cutscene.playing, "seal holds on the SLASH prompt")
	var ev := InputEventKey.new()
	ev.keycode = KEY_J
	ev.pressed = true
	g.cutscene._unhandled_input(ev)
	await process_frame
	check(g.cutscene.t >= 14.0, "Slash continues the seal")
	g.cutscene._end()
	# Ending B: no input for 10 s -> the brush leaves on its own.
	g.cutscene.play("ending-b")
	g.cutscene.t = 10.7
	g.cutscene.wait_t = 9.95
	for i in 6:
		await process_frame
	check(g.cutscene.idle and g.cutscene.t > 10.7, "ending-b: idle 10 s, the brush leaves")
	g.cutscene._end()
	# Beating the last stage: seal + ending A (+ B with every scroll).
	g.cut_on = false
	g.engine.stage = 24
	g.engine.state = "won"
	g.all_scrolls = true
	g._after_pause()
	await process_frame
	check(g.cut_on and g.cutscene.id == "seal" and g.cut_queue == ["ending-a", "ending-b"], "final: seal, ending A, ending B")
	g.cutscene._end()
	await process_frame
	check(g.cutscene.id == "ending-a", "ending A follows the seal")
	g.cutscene._end()
	g.cutscene._end()
	await process_frame
	g.cutscene._end()
	await process_frame
	check(not g.cut_on and g.end_dialog.visible, "the end screen after the endings")
	g.started = false
	_put_back(Cut.SEEN_PATH, seen0)
	_put_back(SAVE, save0)
	print("ink_ninja cutscenes: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails else 0)
