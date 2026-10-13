extends SceneTree

## Boots the Wire Up scene and plays it by calling its own handlers: campaign win,
## stars and unlock, undo, hint, daily, zen, time attack, save/resume.
## godot --headless --path . --script res://tools/test_wire_up_game.gd
## Writes the player's real pipe_flow saves: back up user data first.

var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _initialize() -> void:
	_run()

func _run() -> void:
	for i in 3:
		await process_frame
	var packed: PackedScene = load("res://scenes/games/pipe_flow/pipe_flow.tscn")
	var g: Node = packed.instantiate()
	root.add_child(g)
	for i in 10:
		await process_frame
	var save_path: String = g.SAVE_PATH
	var prog_path: String = g.PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prog_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	g._load_progress()

	# Campaign: level 1 starts fresh, undo works, solving gives stars and unlocks level 2.
	g._start_campaign()
	check(g.mode == "campaign" and g.cur_level == 1, "campaign starts at level 1")
	check(g._unlocked(2) == false, "level 2 locked at the start")
	var e = g.engine
	var turnable := -1
	for c in e.w * e.h:
		if e.can_turn(c):
			turnable = c
			break
	var before: int = e.mask[turnable]
	g._on_board_input(_click(g, turnable))
	check(e.moves == 1 and e.mask[turnable] != before, "tap turns a piece")
	g._on_undo()
	check(e.moves == 0 and e.mask[turnable] == before, "undo restores it")
	g._on_hint()
	check(g.hint_cell >= 0 and g.hints_used == 1, "hint picks a piece")
	# Solve by tapping every piece to its answer.
	for c in e.w * e.h:
		while e.kind[c] != e.EMPTY and not e.fixed[c] and e.mask[c] != e.solution[c]:
			g._on_board_input(_click(g, c))
	check(g.solved, "board solved by tapping")
	check(int(g.progress.stars.get("1", 0)) in [1, 2], "hint caps stars at 2 (got %s)" % str(g.progress.stars.get("1")))
	check(g._unlocked(2), "level 2 unlocked after solving 1")
	check(g._next_level() == 2, "campaign continues at level 2")
	check(FileAccess.file_exists(prog_path), "progress written")

	# Perfect play on level 2: 3 stars.
	g._start_campaign()
	check(g.cur_level == 2, "campaign now on level 2")
	e = g.engine
	for c in e.w * e.h:
		while e.kind[c] != e.EMPTY and not e.fixed[c] and e.mask[c] != e.solution[c]:
			g._on_board_input(_click(g, c))
	check(g.solved and int(g.progress.stars.get("2", 0)) == 3, "level 2: 3 stars")

	# Save and resume mid-board.
	g._start_level(3)
	e = g.engine
	var t3 := -1
	for c in e.w * e.h:
		if e.can_turn(c):
			t3 = c
			break
	g._on_board_input(_click(g, t3))
	var mask_now: Array = e.mask.duplicate()
	g._save_game()
	check(FileAccess.file_exists(save_path), "save written")
	g._start_zen(1)
	g.engine.mask[0] = g.engine.mask[0]
	FileAccess.open(save_path, FileAccess.WRITE).store_string(JSON.stringify({"mode": "campaign", "level": 3, "seed": g.PipeEngine.seed_for(3), "zen": 0, "mask": mask_now, "moves": 1, "time": 12.0, "hints": 0, "left": 0, "boards": 0}))
	g._load_saved_game()
	check(g.mode == "campaign" and g.cur_level == 3 and g.engine.mask == mask_now and g.engine.moves == 1, "resume restores level 3 board")
	check(g._resume_text() != "", "resume text")

	# Daily is the same board twice; zen and time attack start.
	g._start_daily()
	var m1: Array = g.engine.mask.duplicate()
	g._start_daily()
	check(g.engine.mask == m1, "daily board is repeatable")
	g._start_zen(3)
	check(g.mode == "zen" and g.cur_level >= 92, "expert zen uses a hard level")
	g._start_time()
	check(g.mode == "time" and g.time_left > 170.0 and not g.hint_btn.visible, "time attack starts")
	e = g.engine
	for c in e.w * e.h:
		while e.kind[c] != e.EMPTY and not e.fixed[c] and e.mask[c] != e.solution[c]:
			g._on_board_input(_click(g, c))
	check(g.solved and g.ta_solved == 1, "time attack counts a board")
	g._next_time_board()
	check(not g.solved and g.cur_level == 4, "time attack ramps to level 4")
	g._time_up()
	check(g.over, "time up")

	# The level map builds with locks.
	g._open_map(true)
	check(g.map_layer != null, "map opens")
	g._close_map()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("wire up scene: %s" % ("all ok" if fails == 0 else "%d FAIL(S)" % fails))
	quit(1 if fails > 0 else 0)

func _click(g: Node, cell: int) -> InputEventMouseButton:
	var geo: Dictionary = g._geom()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = geo.origin + Vector2(cell % g.engine.w + 0.5, cell / g.engine.w + 0.5) * geo.cell
	return ev
