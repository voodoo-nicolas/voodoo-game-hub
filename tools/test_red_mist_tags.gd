extends SceneTree

## Red Mist look pass 2 smoke test (window needed for drawing): starts a contract,
## tags a guard, a drum and the generator, raises the alarm until the guards
## shoot back, and fires through the FIRE path. Prints errors only via the engine log.
##   godot --path . --resolution 1280x720 --script res://tools/test_red_mist_tags.gd
## Starts a contract (it may leave a Resume save behind).

func _initialize() -> void:
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var game: Control = load("res://scenes/games/red_mist/red_mist.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	game._start_contract(0)
	await _frames(3)
	game._on_begin()
	paused = false
	await _frames(3)
	var tg: Dictionary = game.engine.targets[0]
	game.cam = game.engine.target_pos(tg) + Vector2(0, -1.2 * game.E.upm(float(tg.d)))
	game._set_zoom(6.0)
	game.zoom = 6.0
	await _frames(3)
	game._tag()
	for pr in game.engine.props:
		if pr.kind in ["gen", "drum"]:
			game.tagged[int(pr.id)] = true
	await _frames(10)
	print("tags: ", game.tagged.size(), " score ", game.engine.score)
	game.engine.alarm = 100.0
	for i in 600:
		game.engine.alarm = 100.0
		await process_frame
		if game.engine.over:
			break
	print("playing ", game.playing, " brief ", game.briefing, " coach ", game.coaching, " t ", game.engine.t, " shooters? alarm ", game.engine.alarm)
	print("health ", game.engine.health, " over ", game.engine.over, " reason ", game.engine.reason)
	game._fire()
	await _frames(30)
	print("TAGS TEST DONE")
	quit()
