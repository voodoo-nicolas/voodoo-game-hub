extends SceneTree

## Plays Truco, El 9 and Chinchón through their real scenes (the same handlers a tap calls) until a
## game ends, to catch UI-wiring errors the engine tests cannot.
## godot --headless --path . --script res://tools/test_spanish_games.gd

var fails := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)

func _load(path: String) -> Node:
	var g: Node = load(path).instantiate()
	root.add_child(g)
	return g

func _init() -> void:
	await process_frame
	await _truco()
	await _el9()
	await _chinchon()
	print("spanish games: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _truco() -> void:
	var g := _load("res://scenes/games/truco/truco.tscn")
	await process_frame
	g._new_game(1)
	var guard := 0
	while g.engine.winner == -1 and guard < 3000:
		guard += 1
		g.round_dialog.visible = false
		if g.engine.round_winner != -1:
			g._next_round()
			continue
		var e = g.engine
		if g._cpu_to_move():
			g._cpu_act()
		elif not e.pending.is_empty():
			var a: Dictionary = e.cpu_action(0, 1)
			if a["do"] == "yes" or a["do"] == "no":
				g._h_answer(a["do"] == "yes")
			elif a["do"] == "envido":
				g._h_envido(a["kind"])
			else:
				g._h_truco()
		else:
			var a2: Dictionary = e.cpu_action(0, 1)
			match a2["do"]:
				"envido": g._h_envido(a2["kind"])
				"truco": g._h_truco()
				_: g._h_play(a2["card"])
	ok(g.engine.winner != -1, "truco game finished")
	ok(g.end_dialog.visible, "truco end dialog shown")
	g._save_game()
	g._set_skin("voodoo")
	g.queue_free()
	await process_frame

func _el9() -> void:
	for n in [1, 2, 3]:
		var g := _load("res://scenes/games/el_9/el_9.tscn")
		await process_frame
		g._new_game(n)
		var guard := 0
		while g.engine.winner == -1 and guard < 2000:
			guard += 1
			if g._my_turn():
				g._help_play()
			else:
				g._cpu_turn()
		ok(g.engine.winner != -1, "el 9 game finished (%d cpus)" % n)
		ok(g.end_dialog.visible, "el 9 end dialog shown")
		g._set_skin("voodoo")
		g.queue_free()
		await process_frame

func _chinchon() -> void:
	var g := _load("res://scenes/games/chinchon/chinchon.tscn")
	await process_frame
	g._new_game(1)
	var guard := 0
	while g.engine.winner == -1 and guard < 4000:
		guard += 1
		g.round_dialog.visible = false
		if g.engine.round_over:
			g._next_round()
			continue
		if g.engine.turn == 1:
			g._cpu_turn()
		else:
			g._help_play()
			if g.engine.phase == "discard" and g.engine.turn == 0 and not g.engine.round_over:
				ok(false, "help left a half turn")
				break
	ok(g.engine.winner != -1, "chinchon match finished")
	ok(g.end_dialog.visible, "chinchon end dialog shown")
	g._set_skin("voodoo")
	g.queue_free()
	await process_frame
