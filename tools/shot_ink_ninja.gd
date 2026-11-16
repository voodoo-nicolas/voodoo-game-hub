extends SceneTree

## Ink Ninja in a real window: Landing, objectives, chapter card, a run on stage 1, water,
## pre-boss haze, a boss arena, crouch, Voodoo skin (+ round-10 extras when the engine has them).
##   godot --path . --resolution 1280x720 --script res://tools/shot_ink_ninja.gd -- <out_dir>
## Cutscenes are skipped so the shots are real gameplay. The save is removed afterwards when there was none before.

var out_dir := ""
var game: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://ink_ninja_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _shot(name: String) -> void:
	await _wait(3)
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _skip_cutscenes() -> void:
	for i in 8:
		if game.cut_on:
			game.cutscene._end()
			await _wait(3)

func _stage(n: int, x: float) -> void:
	game.engine.stage = n
	game.engine.build_stage()
	game.engine.foes.clear()
	game.engine.px = x
	game.engine.py = game.engine.ground_y(x)
	game.engine.vx = 0.0
	game._begin()
	game.card_text = []
	game.set("fade", 0.0)

func _run() -> void:
	var had_save := FileAccess.file_exists("user://ink_ninja_save.json")
	await _wait(3)
	change_scene_to_file("res://scenes/games/ink_ninja/ink_ninja.tscn")
	await _wait(25)
	game = current_scene
	await _shot("00_landing")
	var gc: Control = game._show_goals()
	await _wait(10)
	await _shot("05_objectives")
	game.home.close_card(gc)
	await _wait(5)
	game.home.play_now(game._new_game.bind(1))
	await _wait(20)
	await _skip_cutscenes()
	await _wait(20)
	await _shot("08_chapter")
	game.card_text = []
	game.set("fade", 0.0)
	game.key_r = true
	await _wait(120)
	game.q.slash = true
	await _wait(5)
	await _shot("10_run")
	game.key_r = false
	# Stage 3: water.
	_stage(3, 120.0)
	if not game.engine.pools.is_empty():
		var w: Dictionary = game.engine.pools[0]
		game.engine.px = (w.x0 + w.x1) / 2.0
		game.engine.py = w.level
	await _wait(150)
	await _shot("12_water")
	_stage(4, 120.0)
	game.engine.px = game.engine.arena_x - 500
	game.engine.py = game.engine.ground_y(game.engine.px) - 5
	await _wait(30)
	await _shot("15_haze")
	game.engine.px = game.engine.arena_x + 200
	await _wait(60)
	await _shot("20_boss")
	game.key_d = true
	game.q.slash = true
	await _wait(4)
	await _shot("25_crouch")
	game.key_d = false
	# Round-10 extras: only when the engine has them.
	if "gates" in game.engine:
		game.engine.hp = 3
		_stage(5, 120.0)
		if not game.engine.gates.is_empty():
			var g: Dictionary = game.engine.gates[0]
			game.engine.px = g.rx - 260.0
			game.engine.py = game.engine.ground_y(game.engine.px)
			game.engine.hp = 3
			await _wait(30)
			await _shot("40_gate_rope")
			game.q.throw = true
			await _wait(8)
			await _shot("41_rope_throw")
			game.engine.stars = 5
			game.engine.px = g.rx + 10.0
			await _wait(40)
			await _shot("42_gate_open")
		if not game.engine.traps.is_empty():
			var t: Dictionary = game.engine.traps[0]
			game.engine.px = t.sx - 120.0
			game.engine.py = game.engine.ground_y(game.engine.px)
			await _wait(30)
			await _shot("43_trap")
		# A smoke bomb and a three-cut combo.
		game.engine.foes.clear()
		game.engine.foes.append({"kind": "blade", "x": game.engine.px + 300.0, "y": game.engine.ground_y(game.engine.px + 300.0), "vx": 0.0, "vy": 0.0, "hp": 1, "face": -1, "t": 1.0, "atk": 0.0, "hit": 0.0, "id": 999})
		game.key_d = true
		await _wait(4)
		game.q.throw = true
		await _wait(14)
		game.key_d = false
		await _shot("44_smoke_bomb")
		for sw in 3:
			game.q.slash = true
			await _wait(5)
			await _shot("5%d_swing_%d" % [sw, sw])
			await _wait(14)
		game.engine.hp = 2
		game.engine.drops.append({"x": game.engine.px + 60.0, "y": game.engine.py - 20.0, "vy": 0.0, "kind": "heart", "age": 0.0})
		await _wait(6)
		game._heal_fx("Heal")
		await _wait(4)
		await _shot("60_heal")
	game._set_skin("voodoo")
	await _wait(10)
	await _shot("30_voodoo")
	game.started = false
	if not had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ink_ninja_save.json"))
	quit()
