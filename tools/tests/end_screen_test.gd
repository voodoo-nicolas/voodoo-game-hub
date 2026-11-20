extends SceneTree
## godot --headless --script tools/tests/end_screen_test.gd
## Forces a Hangman win at phone size (720x1560) and checks the end card fits
## the screen and gets "See board" (game_info.gd end-screen safety net, STANDARDS §6b).

func _init() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(720, 1560)
	root.add_child(sv)
	var g: Control = load("res://scenes/games/hangman/hangman.tscn").instantiate()
	sv.add_child(g)
	for i in 3:
		await process_frame
	g.engine.reset()
	g.game_active = true
	g._end_game("You win! The word was REPTILE" + g._record_result("win"), Color.GREEN)
	await create_timer(1.2).timeout
	var vp := Vector2(sv.size)
	var panel: Control = g.info._find_panel(g.end_dialog)
	var r: Rect2 = panel.get_rect()
	var ok_fit: bool = r.position.x >= 0.0 and r.end.x <= vp.x
	var found_peek := false
	for b in panel.find_children("*", "Button", true, false):
		if "See board" in b.text or "Ver tablero" in b.text:
			found_peek = true
			b.pressed.emit()
	await process_frame
	var hidden: bool = not g.end_dialog.visible
	print("panel x %.0f..%.0f on a %.0f screen -> %s" % [r.position.x, r.end.x, vp.x, "OK" if ok_fit else "FAIL"])
	print("peek button: %s, hides card: %s" % [found_peek, hidden])
	quit(0 if ok_fit and found_peek and hidden else 1)
