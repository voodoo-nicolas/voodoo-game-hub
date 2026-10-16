extends SceneTree

## Last Shift in the hub: the Landing kit around the world (last_shift_game.gd).
##   godot --headless --path . --script res://tools/test_last_shift_flow.gd
## Checks: a mode starts a world of that difficulty in its own SubViewport (its camera never moves
## the kit); the pause menu pauses and saves the checkpoint; Restart keeps the difficulty; 🏠 Home
## reloads onto the Landing with ▶ Resume, which continues the saved night; a discarded world
## never writes its night back.
## WRITES the real last_shift save / stats files: back up %APPDATA%\Godot\app_userdata\Voodoo first.

const SCENE := "res://scenes/games/last_shift/last_shift.tscn"
const LsSave = preload("res://scripts/games/last_shift/last_shift_save.gd")

var fails := 0

func check(label: String, ok: bool, detail = "") -> void:
	if not ok:
		fails += 1
		print("FAIL ", label, " ", detail)

func _initialize() -> void:
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _spawn() -> Node:
	paused = false
	var inst: Node = load(SCENE).instantiate()
	root.add_child(inst)
	current_scene = inst
	await _frames(8)
	if inst.info != null and inst.info.get("overlay") and inst.info.overlay.visible:
		inst.info.close()
	return inst

func _despawn(inst: Node) -> void:
	paused = false
	root.remove_child(inst)
	inst.queue_free()
	await _frames(3)


func _run() -> void:
	await _frames(3)
	LsSave.clear()
	var g: Node = await _spawn()
	var kit = g.home
	check("Landing shows first", kit.is_home_visible())
	check("no world under the Landing", g.world == null)
	check("no Resume without a save", not kit.resume_btn.visible)
	# Hard
	kit.start_mode(kit.cfg.modes[2])
	await _frames(30)
	check("world started", g.world != null and is_instance_valid(g.world))
	check("world difficulty Hard", int(g.world.state.difficulty) == 2, g.world.state.difficulty)
	check("world in its own SubViewport", g.world.get_viewport() is SubViewport)
	check("the camera leaves the kit's canvas alone", g.get_viewport().canvas_transform == Transform2D.IDENTITY,
		g.get_viewport().canvas_transform)
	var want: Vector2 = g.size * maxf(1.0, g.MIN_VIEW_HEIGHT / g.size.y)
	check("world view = the game's size in canvas units (min height)", Vector2(g.world.get_viewport_rect().size).distance_to(want) < 2.0,
		[g.world.get_viewport_rect().size, want])
	check("checkpoint written on entering the first room", not LsSave.read().is_empty())
	check("saved difficulty Hard", int(LsSave.read().get("state", {}).get("difficulty", -1)) == 2,
		LsSave.read().get("state", {}).get("difficulty", -1))
	# ⏸ from the world -> the kit's pause menu
	g.world._toggle_pause()
	await _frames(4)
	check("pause menu open", kit.pause_overlay.visible)
	check("tree paused", paused)
	check("world knows the kit is up", g.world.kit_up)
	kit.resume_play()
	await _frames(4)
	check("world knows the kit is gone", not g.world.kit_up)
	check("tree running", not paused)
	# Restart keeps Hard
	var old: Node = g.world
	kit.pause()
	kit._on_restart()
	await _frames(20)
	check("Restart made a new world", g.world != old and g.world != null)
	check("Restart kept Hard", int(g.world.state.difficulty) == 2, g.world.state.difficulty)
	check("old world freed", not is_instance_valid(old))
	# Move the checkpoint on, then 🏠 Home (reload): the Landing offers Resume
	g.world.state.play_time = 125.0
	g.world._save_game()
	await _despawn(g)
	g = await _spawn()
	kit = g.home
	check("Landing after Home", kit.is_home_visible())
	check("Resume offered", kit.resume_btn.visible)
	check("Resume text names Hard", kit.resume_btn.text.contains(tr("Hard")), kit.resume_btn.text)
	check("Resume text has the time", kit.resume_btn.text.contains("2:05"), kit.resume_btn.text)
	kit.resume_btn.pressed.emit()
	await _frames(20)
	check("Resume hides the Landing", not kit.is_home_visible())
	check("Resume continues Hard", g.world != null and int(g.world.state.difficulty) == 2)
	check("Resume keeps the time", g.world != null and float(g.world.state.play_time) >= 125.0, g.world.state.play_time)
	# A new night from the Landing replaces the save; the old world must not write it back
	var w: Node = g.world
	g._new_game(0)
	w._save_game()          # what an app-suspend on the dying world would do
	await _frames(20)
	check("Easy night saved", int(LsSave.read().get("state", {}).get("difficulty", -1)) == 0,
		LsSave.read().get("state", {}).get("difficulty", -1))
	await _despawn(g)
	LsSave.clear()
	print("last_shift flow tests: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
