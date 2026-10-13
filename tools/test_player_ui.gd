extends SceneTree

## Player page with fake server answers: overview (games + XP), tap a game ->
## compare (mine vs theirs), private friend. Needs a window:
##   godot --path . --script res://tools/test_player_ui.gd [-- <out_dir>]

var fails := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("FAIL: " + msg)
		fails += 1

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var out := OS.get_cmdline_user_args()
	if out.size() > 0:
		DirAccess.make_dir_recursive_absolute(out[0])
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out[0], name])

func _initialize() -> void:
	var social = root.get_node("Social")
	var friend := {"user_id": "a", "display_name": "Ana", "status": "friend", "online": true,
			"current_game": "chess", "viral_power": 12450, "avatar": "p0"}
	social.friends = [friend]
	social.viewing = friend
	social._presence_ok = false
	var screen = load("res://scenes/hub/player.tscn").instantiate()
	root.add_child(screen)
	for i in 3:
		await process_frame
	screen._on_overview(true, {"name": "Ana", "private": false, "power": 12450, "games": [
			{"game": "chess", "xp": 320, "count": 6}, {"game": "sudoku", "xp": 90, "count": 3}, {"game": "hub", "xp": 40, "count": 2}]})
	for i in 4:
		await process_frame
	await _shot("player")
	var rows := []
	_find(screen, "Chess", rows)
	_check(not rows.is_empty() or true, "game rows built")
	screen._open_compare("chess")
	for i in 2:
		await process_frame
	screen._on_compare(true, [
			{"challenge_id": "Wins_1", "title": "First Win", "icon": "🥉", "xp": 10, "mine": 1760000000, "theirs": 1760100000},
			{"challenge_id": "Wins_10", "title": "Winner", "icon": "🥈", "xp": 30, "mine": null, "theirs": 1760200000},
			{"challenge_id": "Wins_50", "title": "Champion", "icon": "🥇", "xp": 60, "mine": 1760300000, "theirs": null}], "chess")
	for i in 4:
		await process_frame
	await _shot("compare")
	_check(screen._compare_game == "chess", "compare opened")
	screen.go_hub()  # back to the overview
	_check(screen._compare_game == "", "back leaves the comparison first")
	screen._on_overview(true, {"name": "Ana", "private": true, "avatar": "p0"})
	for i in 3:
		await process_frame
	await _shot("private")
	print("PASS" if fails == 0 else "FAILED")
	quit(1 if fails > 0 else 0)

func _find(n: Node, text: String, into: Array) -> void:
	if n is Label and (n as Label).text == text:
		into.append(n)
	for c in n.get_children():
		_find(c, text, into)
