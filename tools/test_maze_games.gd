extends SceneTree

## Scene flow of Maze Trail and Tilt Maze: start the campaign from the Landing,
## win maze 1 (Maze Trail by walking its route through the screen's own step
## code, Tilt Maze by a steering bot feeding the engine), check the stars are
## saved and maze 2 opens, then save mid-maze, reload, Resume.
## WRITES the real saves (user://maze_trail_*.json, user://tilt_maze_*.json and
## their GameInfo stats): back up %APPDATA%\Godot\app_userdata\Voodoo first.
## godot --headless --path . --script res://tools/test_maze_games.gd

var fails := 0

func _initialize() -> void:
	_run()

func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: " + msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _close_info(game: Node) -> void:
	if game.get("info") and game.info.has_method("close"):
		game.info.close()

func _run() -> void:
	await _frames(3)
	for f in ["maze_trail_save.json", "maze_trail_progress.json", "tilt_maze_save.json", "tilt_maze_progress.json"]:
		DirAccess.remove_absolute("user://" + f)
	await _maze_trail()
	await _tilt_maze()
	print("maze games: %d failures" % fails)
	quit(1 if fails > 0 else 0)

func _maze_trail() -> void:
	change_scene_to_file("res://scenes/games/maze_trail/maze_trail.tscn")
	await _frames(10)
	var g = current_scene
	_close_info(g)
	g.home.play_now(g._start_campaign)
	await _frames(5)
	if g.cur_level != 1 or not g.started: _fail("maze_trail: campaign did not start at maze 1")
	var way: Array = g.engine.solution_from_here()
	for c in way:
		g._do_step(g.engine.DIRS.find(c - g.engine.player))
	if not g.solved: _fail("maze_trail: walking the route did not win")
	await create_timer(1.6).timeout
	if g.end_card == null: _fail("maze_trail: no result card")
	var prog = JSON.parse_string(FileAccess.get_file_as_string("user://maze_trail_progress.json"))
	if not prog is Dictionary or int(prog.stars.get("1", 0)) != 3: _fail("maze_trail: 3 stars not saved")
	if not g._unlocked(2): _fail("maze_trail: maze 2 not open")
	# Hint costs one, then comes back over time.
	g._start_level(2)
	await _frames(3)
	var before: int = g._hints_now()
	g._on_hint()
	if g._hints_now() != before - 1 or g.hint_path.is_empty(): _fail("maze_trail: hint")
	# A step, save, reload, resume.
	var first: Vector2i = g.engine.solution_from_here()[0]
	g._do_step(g.engine.DIRS.find(first - g.engine.player))
	var at: Vector2i = g.engine.player
	g._save_game()
	change_scene_to_file("res://scenes/games/maze_trail/maze_trail.tscn")
	await _frames(10)
	g = current_scene
	_close_info(g)
	g.home.play_now(g._load_saved_game)
	await _frames(3)
	if g.cur_level != 2 or g.engine.player != at or g.engine.steps != 1: _fail("maze_trail: resume lost the position")
	# Swipe-run moves along a corridor.
	g._restart()
	var d: int = g.engine.DIRS.find(g.engine.solution_from_here()[0] - g.engine.player)
	g._run(d)
	if g.engine.steps < 1: _fail("maze_trail: run did not move")
	# Daily builds.
	g._start_daily()
	await _frames(2)
	if g.mode != "daily" or g.engine.par <= 0: _fail("maze_trail: daily")
	# Level map opens and lists every level.
	g._open_map(false)
	await _frames(3)
	if g.map_layer == null: _fail("maze_trail: map")
	g._close_map()
	g._set_skin("voodoo")
	await _frames(2)
	g._set_skin("classic")
	g.started = false
	DirAccess.remove_absolute("user://maze_trail_save.json")
	print("maze_trail scene ok")

func _tilt_maze() -> void:
	change_scene_to_file("res://scenes/games/tilt_maze/tilt_maze.tscn")
	await _frames(10)
	var g = current_scene
	_close_info(g)
	g.home.play_now(g._start_campaign)
	await _frames(5)
	if g.cur_level != 1 or not g.started: _fail("tilt_maze: campaign did not start at maze 1")
	# Drive the engine with a steering bot (the screen's own tilt is zero headless).
	var e = g.engine
	var way: Array = e.safe_way(e.pos)
	var idx := 0
	g.ready_t = 0.0
	var guard := 0
	while not g.solved and guard < 60 * 120:
		guard += 1
		var best := 1e9
		for i in range(idx, mini(idx + 40, way.size())):
			var dd: float = (way[i] as Vector2).distance_to(e.pos)
			if dd < best:
				best = dd
				idx = i
		var target: Vector2 = way[mini(idx + 4, way.size() - 1)]
		var tilt: Vector2 = ((target - e.pos).normalized() * 2.4 - e.vel) * 0.8
		for ev in e.update(1.0 / 60.0, tilt):
			g._on_event(ev)
	if not g.solved: _fail("tilt_maze: bot did not reach the goal")
	await create_timer(1.6).timeout
	if g.end_card == null: _fail("tilt_maze: no result card")
	var prog = JSON.parse_string(FileAccess.get_file_as_string("user://tilt_maze_progress.json"))
	if not prog is Dictionary or int(prog.stars.get("1", 0)) < 1: _fail("tilt_maze: stars not saved")
	if not g._unlocked(2): _fail("tilt_maze: maze 2 not open")
	# Coins from the first clear; the shop buys and equips, refuses when short.
	var Shop = load("res://scripts/games/tilt_maze/tilt_maze_shop.gd")
	var c0: int = Shop.coins(g.progress)
	if c0 < Shop.BASE + Shop.PER_STAR: _fail("tilt_maze: first clear paid %d coins" % c0)
	if Shop.pick(g.progress, "marble", "rainbow"): _fail("tilt_maze: bought without enough coins")
	g.progress["coins"] = 1000
	if not Shop.pick(g.progress, "marble", "eye") or Shop.equipped(g.progress, "marble") != "eye": _fail("tilt_maze: buy marble")
	if Shop.coins(g.progress) != 700: _fail("tilt_maze: price not taken (%d)" % Shop.coins(g.progress))
	if not Shop.pick(g.progress, "fx", "comet") or Shop.equipped(g.progress, "fx") != "comet": _fail("tilt_maze: buy effect")
	if not Shop.pick(g.progress, "marble", "steel") or Shop.coins(g.progress) != 400: _fail("tilt_maze: re-equip free marble")
	Shop.pick(g.progress, "marble", "eye")
	if Shop.coins(g.progress) != 400: _fail("tilt_maze: owned marble charged again")
	if Shop.earn_campaign(3, 3, 0) != Shop.REPLAY + Shop.CLEAN or Shop.earn_campaign(1, 3, 1) != 2 * Shop.PER_STAR: _fail("tilt_maze: coin rules")
	g._open_shop()
	await _frames(3)
	if g.shop_body == null or g.shop_body.get_child_count() < Shop.MARBLES.size() + Shop.EFFECTS.size(): _fail("tilt_maze: shop card")
	# Falling into a hole sends the marble back to the start.
	g._start_level(20)
	await _frames(2)
	e = g.engine
	if e.holes.is_empty():
		_fail("tilt_maze: maze 20 has no holes")
	else:
		g.ready_t = 0.0
		e.pos = e.holes[0] + Vector2(0.05, 0.0)
		e.vel = Vector2.ZERO
		var fell := false
		var back := false
		for i in 60:
			for ev in e.update(1.0 / 60.0, Vector2.ZERO):
				g._on_event(ev)
				if ev[0] == "fall": fell = true
				if ev[0] == "back": back = true
		if not fell or not back or e.falls != 1: _fail("tilt_maze: hole did not swallow the marble")
		if e.pos.distance_to(Vector2(e.start) + Vector2(0.5, 0.5)) > 0.01: _fail("tilt_maze: not back at the start")
	# Hint draws a way.
	var before: int = g._hints_now()
	g._on_hint()
	if before > 0 and (g.hint_path.is_empty() or g._hints_now() != before - 1): _fail("tilt_maze: hint")
	# Save and resume.
	e.pos = Vector2(e.start) + Vector2(0.5, 0.2)
	e.time = 12.5
	g._save_game()
	change_scene_to_file("res://scenes/games/tilt_maze/tilt_maze.tscn")
	await _frames(10)
	g = current_scene
	_close_info(g)
	g.home.play_now(g._load_saved_game)
	await _frames(3)
	if g.cur_level != 20 or absf(g.engine.time - 12.5) > 0.2 or g.engine.falls != 1: _fail("tilt_maze: resume")
	g._start_daily()
	await _frames(2)
	if g.mode != "daily": _fail("tilt_maze: daily")
	g._set_skin("voodoo")
	await _frames(2)
	g._set_skin("classic")
	g.started = false
	DirAccess.remove_absolute("user://tilt_maze_save.json")
	print("tilt_maze scene ok")
